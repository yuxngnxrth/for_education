#!/bin/bash
# 1. Ждём MySQL
# 2. Генерируем PKI-сертификаты (CA → сервер → клиенты)
# 3. Прописываем TLS/SRTP в ps_endpoints
# 4. Запускаем Asterisk

set -e

# Создаём лог заранее, чтобы fail2ban не ждал первого запуска Asterisk
mkdir -p /var/log/asterisk
touch /var/log/asterisk/messages

KEYS_DIR="/etc/asterisk/keys"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="asterisk_master_db"
DB_USER="asterisk_user"
DB_PASS="asterisk_pass"

# 1. Ждём MySQL
echo "[entrypoint] Ждём MySQL на $DB_HOST:$DB_PORT..."
for i in $(seq 1 60); do
    if mysqladmin -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
           ping --silent 2>/dev/null; then
        echo "[entrypoint] MySQL готов (попытка $i)"
        break
    fi
    [ "$i" -eq 60 ] && { echo "[entrypoint] ОШИБКА: MySQL недоступен после 120с"; exit 1; }
    sleep 2
done

# 2. Генерация сертификатов
if [ ! -f "$KEYS_DIR/ca.crt" ]; then
    echo "[entrypoint] Генерируем PKI-сертификаты..."
    mkdir -p "$KEYS_DIR"
    cd "$KEYS_DIR"
    umask 077

    # 2a. Корневой CA
    openssl genrsa -out ca.key 2048 2>/dev/null
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
        -subj "/C=RU/ST=Moscow/L=Zelenograd/O=MIET/OU=TCS/CN=My-CA" \
        -out ca.crt

    # 2b. Сертификат сервера Asterisk
    # SAN включает localhost, 127.0.0.1 и реальный IP хоста — без этого
    # клиенты (Linphone и др.) отвергают сертификат при подключении по IP.
    HOST_IP=$(hostname -I | awk '{print $1}')
    cat > asterisk_ext.cnf << EXTEOF
[SAN]
subjectAltName=DNS:pbx.example.com,DNS:localhost,IP:127.0.0.1,IP:${HOST_IP}
EXTEOF

    openssl genrsa -out asterisk.key 2048 2>/dev/null
    openssl req -new -key asterisk.key \
        -subj "/C=RU/ST=Moscow/L=Zelenograd/O=MIET/OU=TCS/CN=pbx.example.com" \
        -out asterisk.csr
    openssl x509 -req -in asterisk.csr \
        -CA ca.crt -CAkey ca.key -CAcreateserial \
        -out asterisk.crt -days 365 -sha256 \
        -extfile asterisk_ext.cnf -extensions SAN

    # 2c. Клиентские сертификаты (подписаны сертификатом сервера, не корневым CA)
    for EXT in 4000 4001; do
        openssl genrsa -out "client${EXT}.key" 2048 2>/dev/null
        openssl req -new -key "client${EXT}.key" \
            -subj "/C=RU/ST=Moscow/L=Zelenograd/O=MIET/OU=TCS/CN=${EXT}" \
            -out "client${EXT}.csr"
        openssl x509 -req -in "client${EXT}.csr" \
            -CA asterisk.crt -CAkey asterisk.key -CAcreateserial \
            -out "client${EXT}.crt" -days 365 -sha256
        # PEM = cert + key в одном файле (нужен PhonerLite)
        cat "client${EXT}.crt" "client${EXT}.key" > "client${EXT}.pem"
    done

    chown -R asterisk:asterisk "$KEYS_DIR"
    chmod 600 "$KEYS_DIR"/*.key
    chmod 644 "$KEYS_DIR"/*.crt "$KEYS_DIR"/*.pem 2>/dev/null || true
    echo "[entrypoint] Сертификаты готовы в $KEYS_DIR"
else
    echo "[entrypoint] Сертификаты уже есть, пропускаем"
fi

# 3. Прописываем TLS/SRTP в ps_endpoints
echo "[entrypoint] Обновляем настройки абонентов в БД..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" << 'SQL'
UPDATE ps_endpoints SET
    transport        = 'transport-tls',
    media_encryption = 'sdes',
    dtls_verify      = 'fingerprint',
    dtls_cert_file   = '/etc/asterisk/keys/client4000.crt',
    dtls_private_key = '/etc/asterisk/keys/client4000.key',
    dtls_setup       = 'actpass',
    dtls_rekey       = 0
WHERE id = '4000';

UPDATE ps_endpoints SET
    transport        = 'transport-tls',
    media_encryption = 'sdes',
    dtls_verify      = 'fingerprint',
    dtls_cert_file   = '/etc/asterisk/keys/client4001.crt',
    dtls_private_key = '/etc/asterisk/keys/client4001.key',
    dtls_setup       = 'actpass',
    dtls_rekey       = 0
WHERE id = '4001';
SQL
echo "[entrypoint] БД обновлена"

# 4. Запускаем Asterisk
echo "[entrypoint] Запускаем Asterisk..."
exec asterisk -f
