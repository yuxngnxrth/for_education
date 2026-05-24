#!/usr/bin/env bash

SSH_CMD="ssh welzewl@192.168.1.99"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DETAIL_LOG="detailed_${TIMESTAMP}.csv"
PEAK_LOG="peak_${TIMESTAMP}.csv"

echo "timestamp,calls,elapsed_sec,channels,cpu_percent,mem_mb" > $DETAIL_LOG
echo "calls,peak_channels,peak_cpu,peak_mem,test_duration" > $PEAK_LOG

echo "=== НАГРУЗОЧНОЕ ТЕСТИРОВАНИЕ ASTERISK (500 ЗВОНКОВ) ==="
echo "Дата: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for calls in 100; do
    echo "--- Тест: $calls звонков ---"

    # Очищаем старые контакты
    $SSH_CMD "docker exec master-asterisk asterisk -rx 'module reload res_pjsip.so'" 2>/dev/null
    sleep 3

    # Запускаем звонки с задержкой 0.05 сек (быстрее)
    for i in $(seq 1 $calls); do
        PORT=$((10000 + i))
        (
            expect -c "
            set timeout 120
            spawn pjsua --id \"sip:sipp@192.168.1.99\" --registrar \"sip:192.168.1.99\" --realm asterisk --username sipp --password 123456 --no-tcp --local-port $PORT
            expect \"registration success\"
            send \"m\r\"
            expect \"Make call:\"
            send \"sip:9999@192.168.1.99\r\"
            sleep 25
            send \"q\r\"
            expect eof
            " 2>/dev/null
        ) &

        # Задержка 0.05 секунды между запусками
        sleep 0.05
    done

    echo "  Мониторинг в реальном времени..."

    MAX_CHANS=0
    MAX_CPU=0
    MAX_MEM=0
    ZERO_COUNT=0
    ELAPSED=0

    while true; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        CURRENT_TIME=$(date '+%H:%M:%S')

        CHANS=$($SSH_CMD "docker exec master-asterisk asterisk -rx 'core show channels' 2>/dev/null | grep 'active channel' | awk '{print \$1}'")
        CPU=$($SSH_CMD "docker stats master-asterisk --no-stream --format '{{.CPUPerc}}' 2>/dev/null | tr -d '%'")
        MEM=$($SSH_CMD "docker stats master-asterisk --no-stream --format '{{.MemUsage}}' 2>/dev/null | awk '{print \$1}' | sed 's/MiB//'")

        [ -z "$CHANS" ] && CHANS=0
        [ -z "$CPU" ] && CPU=0
        [ -z "$MEM" ] && MEM=0

        echo "$CURRENT_TIME,$calls,$ELAPSED,$CHANS,$CPU,$MEM" >> $DETAIL_LOG

        if [ $CHANS -gt $MAX_CHANS ]; then
            MAX_CHANS=$CHANS
            MAX_CPU=$CPU
            MAX_MEM=$MEM
        fi

        if [ $CHANS -eq 0 ]; then
            ZERO_COUNT=$((ZERO_COUNT + 1))
        else
            ZERO_COUNT=0
        fi

        if [ $((ELAPSED % 10)) -eq 0 ]; then
            echo "    [${ELAPSED}s] Каналов: $CHANS | CPU: ${CPU}% | RAM: ${MEM} MB"
        fi

        # Выход после 10 секунд без каналов
        if [ $ZERO_COUNT -ge 10 ] && [ $ELAPSED -gt 60 ]; then
            echo "    [${ELAPSED}s] Все звонки завершены"
            break
        fi

        # Защита от бесконечного цикла (максимум 10 минут)
        if [ $ELAPSED -ge 600 ]; then
            echo "    Достигнут лимит времени (600 сек)"
            break
        fi
    done

    pkill -f pjsua 2>/dev/null

    DURATION=$ELAPSED
    echo ""
    echo "  ПИКОВЫЕ ЗНАЧЕНИЯ:"
    echo "    Активных каналов: $MAX_CHANS"
    echo "    CPU: ${MAX_CPU}%"
    echo "    RAM: ${MAX_MEM} MB"
    echo "    Длительность теста: ${DURATION} сек"
    echo "$calls,$MAX_CHANS,$MAX_CPU,$MAX_MEM,$DURATION" >> $PEAK_LOG

    sleep 5
done

echo ""
echo "=== РЕЗУЛЬТАТЫ ==="
cat $PEAK_LOG
