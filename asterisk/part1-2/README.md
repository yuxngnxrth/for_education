# Конспект: Настройка Asterisk в Docker

---

## Содержание

1. [Запуск Asterisk в Docker](#1-запуск-asterisk-в-docker)
2. [Базовая конфигурация](#2-базовая-конфигурация)
3. [Настройка PJSIP (клиенты)](#3-настройка-pjsip-клиенты)
4. [Настройка Dialplan (план набора)](#4-настройка-dialplan-план-набора)
5. [Звуковые файлы](#5-звуковые-файлы)
6. [Подключение клиентов](#6-подключение-клиентов)
7. [Отладка и проверка](#7-отладка-и-проверка)
8. [Dockerfile для автоматизации](#8-dockerfile-для-автоматизации)
9. [Сборка и запуск Docker образа](#9-сборка-и-запуск-docker-образа)
10. [Docker Compose](#10-docker-compose)
11. [Безопасность](#11-безопасность)
12. [Полезные команды (шпаргалка)](#12-полезные-команды-шпаргалка)

---

## **1. Запуск Asterisk в Docker**

### 1.1 Скачать образ
```bash
docker pull andrius/asterisk:18
```

### 1.2 Создать структуру папок
```bash
mkdir -p ~/containers/asterisk/sounds
cd ~/containers/asterisk
```

### 1.3 Запустить контейнер (временный, для теста)
```bash
sudo docker run -d \
  --name asterisk18 \
  --privileged \
  --network host \
  --restart unless-stopped \
  andrius/asterisk:18
```

### 1.4 Подключиться к консоли Asterisk
```bash
sudo docker exec -it asterisk18 asterisk -rvvv
```

---

## **2. Базовая конфигурация**

### 2.1 Создать конфигурационные файлы на хосте
В папке `~/containers/asterisk/` создайте:

**extensions.conf** - план набора
**pjsip.conf** - настройки клиентов

### 2.2 Основные команды в консоли Asterisk
```bash
# Перезагрузить конфигурацию
module reload

# Показать endpoints
pjsip show endpoints

# Показать контакты (зарегистрированные клиенты)
pjsip show contacts

# Показать план набора
dialplan show default

# Включить логирование SIP
pjsip set logger on
core set verbose 5
```

---

## **3. Настройка PJSIP (клиенты)**

### 3.1 Структура pjsip.conf
```ini
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0

[1000]
type = endpoint
context = default
disallow = all
allow = alaw        ; G.711 A-law
allow = opus        ; Opus кодек
auth = 1000
aors = 1000

[1000]
type = auth
auth_type = userpass
password = 123456
username = 1000

[1000]
type = aor
max_contacts = 1

[2000]
type = endpoint
context = default
disallow = all
allow = alaw        ; G.711 A-law
allow = opus        ; Opus кодек
auth = 2000
aors = 2000

[2000]
type = auth
auth_type = userpass
password = 123456
username = 2000

[2000]
type = aor
max_contacts = 1
```

### 3.2 Проверка
```bash
pjsip show endpoints
pjsip show transports
```

---

## **4. Настройка Dialplan (план набора)**

### 4.1 Структура extensions.conf
```ini
[default]

; Внутренние номера
exten => 1000,1,Answer()
same => n,Playback(hello)
same => n,Hangup()

exten => 2000,1,Dial(PJSIP/2000)

; Специальный номер с записью
exten => 5000,1,Answer()
same => n,Playback(num-was-successfully)
same => n,Hangup()

; Шаблон для всех 4-значных номеров
exten => _XXXX,1,Dial(PJSIP/${EXTEN})
```

### 4.2 Проверка
```bash
dialplan show default
```

---

## **5. Звуковые файлы**

### Скачать стандартные звуковые файлы Asterisk
```bash
# Перейти в папку со звуками
cd ~/containers/asterisk/sounds

# Скачать архивы со звуками (английские)
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-ulaw-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-alaw-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-gsm-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz

# Распаковать все архивы
tar xzf asterisk-core-sounds-en-ulaw-current.tar.gz
tar xzf asterisk-core-sounds-en-alaw-current.tar.gz
tar xzf asterisk-core-sounds-en-gsm-current.tar.gz
tar xzf asterisk-core-sounds-en-wav-current.tar.gz

# Удалить архивы (опционально)
rm *.tar.gz

# Посмотреть распакованные файлы
ls -la
```

---

## **6. Подключение клиентов**

### 6.1 Настройка Blink/Linphone/PhonerLite/PortSip UC(iPhone, Android)

**Для пользователя 1000:**
- **Display name**: `1000`
- **SIP address**: `1000@IP-адрес-сервера`
- **Password**: `123456`

**Для пользователя 2000:**
- **Display name**: `2000`
- **SIP address**: `2000@IP-адрес-сервера`
- **Password**: `123456`

### 6.2 Проверка регистрации
```bash
pjsip show contacts
```
Должны увидеть:
```
Contact: 1000/sip:1000@192.168.x.x:... Status: Avail
Contact: 2000/sip:2000@192.168.x.x:... Status: Avail
```

---

## **7. Отладка и проверка**

### 7.1 Основные команды
```bash
# Проверить endpoints
pjsip show endpoints

# Проверить контакты
pjsip show contacts

# Проверить план набора
dialplan show default

# Проверить кодеки
core show codecs

# Проверить активные каналы (звонки)
core show channels

# Проверить порты (на хосте)
ss -ulpn | grep 5060
```

### 7.2 Логирование
```bash
# Включить логи SIP
pjsip set logger on
core set verbose 5

# Посмотреть историю
pjsip show history
```

### 7.3 Тестовые звонки
- **1000** - автоответчик (hello)
- **2000** - вызов второго абонента
- **5000** - специальный номер (num-was-successfully)

---

## **8. Dockerfile для автоматизации**

### 8.1 Структура проекта
```
~/containers/asterisk/
├── Dockerfile
├── extensions.conf
├── pjsip.conf
└── sounds/
    ├── hello.ulaw
    ├── hello.alaw
    ├── num-was-successfully.ulaw
    ├── num-was-successfully.alaw
    └── ... (остальные звуковые файлы)
```

### 8.2 Подготовка звуковых файлов для Dockerfile
```bash
# Перейти в папку проекта
cd ~/containers/asterisk

# Скачать и распаковать звуковые файлы прямо в папку sounds
cd sounds
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-ulaw-current.tar.gz
tar xzf asterisk-core-sounds-en-ulaw-current.tar.gz
rm asterisk-core-sounds-en-ulaw-current.tar.gz

# Также можно скачать другие форматы
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-alaw-current.tar.gz
tar xzf asterisk-core-sounds-en-alaw-current.tar.gz
rm asterisk-core-sounds-en-alaw-current.tar.gz

# Вернуться в папку проекта
cd ..
```

### 8.3 Dockerfile (минимальная версия)
```dockerfile
FROM andrius/asterisk:18

# Копируем конфигурационные файлы
COPY extensions.conf /etc/asterisk/extensions.conf
COPY pjsip.conf /etc/asterisk/pjsip.conf

# Копируем звуковые файлы
COPY sounds/. /var/lib/asterisk/sounds/

# Открываем порты
EXPOSE 5060/udp 5060/tcp 10000-20000/udp

# Запускаем Asterisk
CMD ["asterisk", "-f"]
```

---

## **9. Сборка и запуск Docker образа**

### 9.1 Сборка образа
```bash
# Перейти в папку с Dockerfile
cd ~/containers/asterisk

# Собрать образ с тегом my-asterisk:1.0
sudo docker build -t my-asterisk:1.0 .

# Собрать образ без использования кэша (чистая сборка)
sudo docker build --no-cache -t my-asterisk:1.0 .

# Собрать образ с другим тегом
sudo docker build -t my-asterisk:latest .
```

### 9.2 Просмотр собранных образов
```bash
# Посмотреть все образы
sudo docker images

# Фильтр по имени
sudo docker images | grep my-asterisk
```

### 9.3 Запуск контейнера из своего образа
```bash
# Остановить и удалить старый контейнер (если есть)
sudo docker stop asterisk18 2>/dev/null
sudo docker rm asterisk18 2>/dev/null

# Запустить новый контейнер из своего образа
sudo docker run -d \
  --name asterisk18 \
  --privileged \
  --network host \
  --restart unless-stopped \
  my-asterisk:1.0
```

### 9.4 Проверка запущенного контейнера
```bash
# Проверить, что контейнер запустился
sudo docker ps

# Посмотреть логи
sudo docker logs asterisk18

# Подключиться к консоли Asterisk
sudo docker exec -it asterisk18 asterisk -rvvv
```

### 9.5 Проверка конфигурации в новом контейнере
```bash
# В консоли Asterisk проверить:
pjsip show endpoints
dialplan show default

# Проверить звуковые файлы
file list playback hello
file list playback num-was-successfully

# Проверить, что порты слушаются
core show settings | grep -i port
```

### 9.6 Обновление образа при изменении конфигурации
```bash
# После изменений в конфигах пересобрать образ
cd ~/containers/asterisk
sudo docker build --no-cache -t my-asterisk:2.0 .

# Остановить старый контейнер
sudo docker stop asterisk18
sudo docker rm asterisk18

# Запустить новый
sudo docker run -d \
  --name asterisk18 \
  --privileged \
  --network host \
  --restart unless-stopped \
  my-asterisk:2.0
```

### 9.7 Удаление старых образов
```bash
# Удалить конкретный образ
sudo docker rmi my-asterisk:1.0

# Удалить все неиспользуемые образы
sudo docker image prune

# Удалить все образы, кроме используемых
sudo docker image prune -a
```

---

## **10. Docker Compose**

### 10.1 Структура docker-compose.yml
```yaml
services:
  asterisk:
    image: my-asterisk:1.0
    container_name: asterisk18
    privileged: true
    network_mode: host
    restart: unless-stopped
    volumes:
      # Опционально: можно монтировать конфиги для live-редактирования
      - ./extensions.conf:/etc/asterisk/extensions.conf
      - ./pjsip.conf:/etc/asterisk/pjsip.conf
      - ./sounds:/var/lib/asterisk/sounds
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 10.2 Расширенная версия с volume для логов
```yaml
services:
  asterisk:
    image: my-asterisk:1.0
    container_name: asterisk18
    privileged: true
    network_mode: host
    restart: unless-stopped
    volumes:
      # Конфиги
      - ./extensions.conf:/etc/asterisk/extensions.conf
      - ./pjsip.conf:/etc/asterisk/pjsip.conf
      # Звуки
      - ./sounds:/var/lib/asterisk/sounds
      # Логи (чтобы не терять при перезапуске)
      - ./logs:/var/log/asterisk
    environment:
      - TZ=Europe/Moscow  # Часовой пояс
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 10.3 Команды Docker Compose

#### Основные команды
```bash
# Запустить в фоне
sudo docker compose up -d

# Запустить с логами в реальном времени
sudo docker compose up

# Остановить контейнер
sudo docker compose down

# Остановить и удалить volumes
sudo docker compose down -v

# Перезапустить
sudo docker compose restart

# Посмотреть логи
sudo docker compose logs -f

# Посмотреть статус
sudo docker compose ps
```

#### Работа с контейнером
```bash
# Подключиться к консоли Asterisk
sudo docker compose exec asterisk asterisk -rvvv

# Подключиться к bash
sudo docker compose exec asterisk bash

# Выполнить команду в контейнере
sudo docker compose exec asterisk ls -la /etc/asterisk/
```

#### Сборка и обновление
```bash
# Пересобрать образ перед запуском
sudo docker-compose up -d --build

# Пересобрать без кэша
sudo docker-compose build --no-cache

# Обновить конфигурацию (после изменений в файлах)
sudo docker-compose restart
```

### 10.4 Полезные комбинации команд

```bash
# Полный цикл: пересобрать, запустить, посмотреть логи
sudo docker-compose down && \
sudo docker-compose build --no-cache && \
sudo docker-compose up -d && \
sudo docker-compose logs -f

# Остановить всё и удалить
sudo docker-compose down -v

# Зайти в консоль Asterisk одной командой
sudo docker-compose exec asterisk asterisk -rvvv

# Сделать резервную копию конфигов
sudo docker-compose exec asterisk tar -czf /tmp/asterisk-backup.tar.gz /etc/asterisk/
sudo docker cp asterisk18:/tmp/asterisk-backup.tar.gz ./
```

---

## **11. Безопасность**

### 11.1 Ограничение доступа к локальной сети (UFW)
```bash
# Разрешить только локальную сеть
sudo ufw allow from 192.168.1.0/24 to any port 5060 proto udp
sudo ufw allow from 192.168.1.0/24 to any port 5060 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 10000:20000 proto udp

# Проверить правила
sudo ufw status numbered
```

### 11.2 Проверка доступности
```bash
# С другой машины в локальной сети
nc -zuv 192.168.1.107 5060
# Должно работать

# Из внешней сети - должно быть заблокировано
```

---

## **12. Полезные команды (шпаргалка)**

### Работа с контейнером
```bash
# Подключиться к консоли Asterisk
sudo docker exec -it asterisk18 asterisk -rvvv

# Подключиться к bash контейнера
sudo docker exec -it --user root asterisk18 bash

# Посмотреть логи
sudo docker logs asterisk18
sudo docker logs -f asterisk18  # в реальном времени

# Перезапустить контейнер
sudo docker restart asterisk18

# Остановить контейнер
sudo docker stop asterisk18

# Запустить остановленный контейнер
sudo docker start asterisk18

# Удалить контейнер
sudo docker rm asterisk18

# Посмотреть все контейнеры (включая остановленные)
sudo docker ps -a
```

### Работа с образами
```bash
# Собрать образ
sudo docker build -t my-asterisk:1.0 .

# Собрать без кэша
sudo docker build --no-cache -t my-asterisk:1.0 .

# Посмотреть все образы
sudo docker images

# Удалить образ
sudo docker rmi my-asterisk:1.0

# Очистить неиспользуемые образы
sudo docker image prune
sudo docker image prune -a  # все неиспользуемые
```

### Работа с файлами
```bash
# Скопировать файлы в контейнер
sudo docker cp extensions.conf asterisk18:/etc/asterisk/
sudo docker cp pjsip.conf asterisk18:/etc/asterisk/
sudo docker cp sounds/. asterisk18:/var/lib/asterisk/sounds/

# Скопировать файлы из контейнера
sudo docker cp asterisk18:/etc/asterisk/extensions.conf ./
sudo docker cp asterisk18:/var/lib/asterisk/sounds/hello.ulaw ./
```

### Консоль Asterisk
```bash
# Перезагрузить конфигурацию
module reload

# Показать endpoints
pjsip show endpoints

# Показать контакты
pjsip show contacts

# Показать план набора
dialplan show default

# Показать кодеки
core show codecs

# Показать активные каналы
core show channels

# Показать версию
core show version

# Включить логирование
pjsip set logger on
core set verbose 5

# Отключить CDR ошибки
module unload cdr_csv.so
```

### Диагностика сети
```bash
# На хосте: проверить слушающие порты
ss -ulpn | grep 5060
ss -tlnp | grep 5060

# Проверить firewall
sudo ufw status

# Проверить доступность с другого компьютера
nc -zv 192.168.1.107 5060
```

---

## **Примечания**

- Все команды `docker` требуют `sudo` на Ubuntu
- IP адрес сервера: `192.168.1.107` (замените на свой)
- Номера абонентов: 1000 и 2000
- Пароль: 123456
- Порт SIP: 5060 (UDP)
- Диапазон RTP портов: 10000-20000 (UDP)
- Звуковые файлы должны быть в форматах ulaw, alaw, gsm для совместимости
- При изменении конфигурации используйте `--no-cache` при сборке для гарантии свежих файлов

## **Возможные проблемы и решения**

### Клиенты не регистрируются
```bash
# Проверить транспорт
pjsip show transports

# Проверить firewall
sudo ufw status

# Проверить, что Asterisk слушает порт
ss -ulpn | grep 5060

# Проверить логи SIP
pjsip set logger on
core set verbose 5
```

### Нет звука
```bash
# Проверить наличие звуковых файлов
file list playback hello

# Проверить права на папку sounds
ls -la /var/lib/asterisk/sounds/

# Проверить кодеки у клиента
core show codecs
```

### CDR ошибки
```bash
# Отключить CDR модуль
module unload cdr_csv.so

# Или создать директорию
sudo docker exec -it --user root asterisk18 bash
mkdir -p /var/log/asterisk/cdr-csv
chown asterisk:asterisk /var/log/asterisk/cdr-csv
exit
```

### Конфигурация не применяется
```bash
# Перезагрузить модули
module reload

# Или перезапустить контейнер
sudo docker restart asterisk18

# При пересборке образа использовать --no-cache
sudo docker build --no-cache -t my-asterisk:1.0 .
```

### Docker Compose не видит образ
```bash
# Убедитесь, что образ собран
sudo docker images | grep my-asterisk

# Если образа нет, соберите его
sudo docker build -t my-asterisk:1.0 .

# Или используйте build в docker-compose.yml
# Добавьте в сервис:
#   build: .
# вместо image: my-asterisk:1.0
```