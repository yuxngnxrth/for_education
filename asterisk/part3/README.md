# Настройка Asterisk в Docker Часть 3: Realtime конфигурация и IAX2

---

## Содержание

1. [Создание структуры папок](#1-создание-структуры-папок)
2. [Docker Compose для MySQL](#2-docker-compose-для-mysql)
3. [Docker Compose для master и slave](#3-docker-compose-для-master-и-slave)
4. [Настройка ODBC](#4-настройка-odbc)
5. [Инициализация баз данных](#5-инициализация-баз-данных)
6. [Перенос конфигурации PJSIP в БД](#6-перенос-конфигурации-pjsip-в-бд)
7. [Перенос Dialplan в БД](#7-перенос-dialplan-в-бд)
8. [Настройка IAX2 транка между серверами](#8-настройка-iax2-транка-между-серверами)
9. [Перенос IAX2 в БД](#9-перенос-iax2-в-бд)
10. [Запуск всех сервисов](#10-запуск-всех-сервисов)
11. [Проверка работы](#11-проверка-работы)
12. [Полезные команды](#12-полезные-команды)

---

## 1. Создание структуры папок

```bash
mkdir -p /opt/asterisk/mysql
mkdir -p /opt/asterisk/master-asterisk
mkdir -p /opt/asterisk/slave-asterisk
cd /opt/asterisk/mysql
```

---

## 2. Docker Compose для MySQL

### 2.1 Создать docker-compose.yml для MySQL

```yaml
# /opt/asterisk/mysql/docker-compose.yml
name: asterisk_db

services:
  mysql:
    image: mysql:5.7
    container_name: asterisk-mysql
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_USER: asterisk_user
      MYSQL_PASSWORD: asterisk_pass
    ports:
      - "3306:3306"
    network_mode: host
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init_master.sql:/docker-entrypoint-initdb.d/01_init_master.sql
      - ./init_slave.sql:/docker-entrypoint-initdb.d/02_init_slave.sql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    restart: unless-stopped

volumes:
  mysql_data:
```

### 2.2 Запустить MySQL

```bash
cd /opt/asterisk/mysql
docker compose up -d
docker compose ps
```

### 2.3 Проверить создание баз

```bash
docker exec -it asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "SHOW DATABASES;"
```

**Ожидаемый результат:**
```
asterisk_master_db
asterisk_slave_db
```

---

## 3. Docker Compose для master и slave

### 3.1 Docker Compose для master

```yaml
# /opt/asterisk/master-asterisk/docker-compose.yml
services:
  asterisk:
    image: master-asterisk:1.0
    container_name: master-asterisk
    privileged: true
    network_mode: host
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 3.2 Docker Compose для slave

```yaml
# /opt/asterisk/slave-asterisk/docker-compose.yml
services:
  asterisk:
    image: slave-asterisk:1.0
    container_name: slave-asterisk
    privileged: true
    network_mode: host
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## 4. Настройка ODBC

### 4.1 Создать Dockerfile для master

```dockerfile
FROM andrius/asterisk:18

USER root


RUN cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
EOF

RUN apt-get update && \
    apt-get install -y \
        unixodbc \
        odbcinst \
        odbc-mariadb && \
    rm -rf /var/lib/apt/lists/*

USER asterisk

# Копируем конфиги ODBC
COPY odbc.ini /etc/odbc.ini
COPY odbcinst.ini /etc/odbcinst.ini

# Копируем конфигурационные файлы
COPY extensions.conf /etc/asterisk/extensions.conf
COPY pjsip.conf /etc/asterisk/pjsip.conf
COPY iax.conf /etc/asterisk/iax.conf
COPY res_odbc.conf /etc/asterisk/res_odbc.conf
COPY rtp.conf /etc/asterisk/rtp.conf
COPY sorcery.conf /etc/asterisk/sorcery.conf
COPY extconfig.conf /etc/asterisk/extconfig.conf
COPY cdr.conf /etc/asterisk/cdr.conf
COPY cdr_odbc.conf /etc/asterisk/cdr_odbc.conf
COPY sounds/. /var/lib/asterisk/sounds/

RUN  echo "load => res_odbc.so" >> /etc/asterisk/modules.conf && \
     echo "load => cdr_odbc.so" >> /etc/asterisk/modules.conf


# Открываем порты
EXPOSE 5060/udp 5060/tcp 4569/udp 10000-15000/udp

# Запускаем Asterisk
CMD ["asterisk", "-f"]
```

### 4.2 Создать Dockerfile для slave

```dockerfile
# /opt/asterisk/slave-asterisk/Dockerfile
FROM andrius/asterisk:18

USER root


RUN cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
EOF

RUN apt-get update && \
    apt-get install -y \
        unixodbc \
        odbcinst \
	odbc-mariadb && \
    rm -rf /var/lib/apt/lists/*

USER asterisk

# Копируем конфиги ODBC
COPY odbc.ini /etc/odbc.ini
COPY odbcinst.ini /etc/odbcinst.ini

# Копируем конфигурационные файлы
COPY extensions.conf /etc/asterisk/extensions.conf
COPY pjsip.conf /etc/asterisk/pjsip.conf
COPY iax.conf /etc/asterisk/iax.conf
COPY res_odbc.conf /etc/asterisk/res_odbc.conf
COPY rtp.conf /etc/asterisk/rtp.conf
COPY sorcery.conf /etc/asterisk/sorcery.conf
COPY extconfig.conf /etc/asterisk/extconfig.conf
COPY cdr.conf /etc/asterisk/cdr.conf
COPY cdr_odbc.conf /etc/asterisk/cdr_odbc.conf
COPY sounds/. /var/lib/asterisk/sounds/

RUN  echo "load => res_odbc.so" >> /etc/asterisk/modules.conf && \
     echo "load => cdr_odbc.so" >> /etc/asterisk/modules.conf
	

# Открываем порты
EXPOSE 5061/udp 5061/tcp 4570/udp 15001-20000/udp

# Запускаем Asterisk
CMD ["asterisk", "-f"]
```

### 4.3 Создать odbcinst.ini (одинаковый для обоих)

```ini
# /opt/asterisk/master-asterisk/odbcinst.ini
[MySQL]
Description = MySQL ODBC Driver
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
#Setup = /usr/lib/x86_64-linux-gnu/odbc/libodbcmyS.so
FileUsage = 1
```

```bash
cp /opt/asterisk/master-asterisk/odbcinst.ini /opt/asterisk/slave-asterisk/
```

### 4.4 Создать odbc.ini для master

```ini
# /opt/asterisk/master-asterisk/odbc.ini
[asteriskdb]                           # ← это имя DSN
Driver = MySQL
Server = 127.0.01
Port = 3306
Database = asterisk_master_db
User = asterisk_user
Password = asterisk_pass
```

### 4.5 Создать odbc.ini для slave

```ini
# /opt/asterisk/slave-asterisk/odbc.ini
[asteriskdb]                           # ← это имя DSN
Driver = MySQL
Server = 127.0.0.1
Port = 3306
Database = asterisk_slave_db
User = asterisk_user
Password = asterisk_pass
```

### 4.6 Создать res_odbc.conf (одинаковый для обоих)

```ini
# /opt/asterisk/master-asterisk/res_odbc.conf
[asteriskdb]
enabled => yes
dsn => asteriskdb
username => asterisk_user
password => asterisk_pass
pre-connect => yes
```

```bash
cp /opt/asterisk/master-asterisk/res_odbc.conf /opt/asterisk/slave-asterisk/
```

### 4.7 Проверить ODBC после сборки

```bash
docker exec master-asterisk asterisk -rx 'odbc show'
```

**Ожидаемый результат:**
```
ODBC DSN Settings
-----------------
  Name:   asteriskdb
  DSN:    asteriskdb
    Number of active connections: 1 (out of 1)
    Logging: Disabled
```

---

## 5. Инициализация баз данных

Скрипты `init_master.sql` и `init_slave.sql` уже содержат:

- Создание таблиц (`ps_aors`, `ps_auths`, `ps_endpoints`, `extensions`, `iaxfriends`, `cdr`)
- Вставку начальных данных:
  - **master**: номера 4000, 4001; dialplan для 4XXX и 5XXX; iaxuser1
  - **slave**: номера 5000, 5001, 5002; dialplan для 4XXX и 5XXX; iaxuser2
- Настройку прав пользователя `asterisk_user`

### 5.1 Скопировать init скрипты

```bash
cp /path/to/init_master.sql /opt/asterisk/mysql/
cp /path/to/init_slave.sql /opt/asterisk/mysql/
```

### 5.2 Применить скрипты вручную (если нужно)

```bash
# Для master
docker exec -i asterisk-mysql mysql -u root -p < /opt/asterisk/mysql/init_master.sql

# Для slave
docker exec -i asterisk-mysql mysql -u root -p < /opt/asterisk/mysql/init_slave.sql
```

### 5.3 Проверить данные

```bash
# Проверить extensions в master
docker exec asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "USE asterisk_master_db; SELECT * FROM extensions;"

# Проверить extensions в slave
docker exec asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "USE asterisk_slave_db; SELECT * FROM extensions;"

# Проверить iaxfriends в slave
docker exec asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "USE asterisk_slave_db; SELECT * FROM iaxfriends;"
```

---

## 6. Перенос конфигурации PJSIP в БД

### 6.1 Создать sorcery.conf (одинаковый для обоих)

```ini
# /opt/asterisk/master-asterisk/sorcery.conf
[res_pjsip]
endpoint=realtime,ps_endpoints
auth=realtime,ps_auths
aor=realtime,ps_aors
```

```bash
cp /opt/asterisk/master-asterisk/sorcery.conf /opt/asterisk/slave-asterisk/
```

### 6.2 Создать extconfig.conf (одинаковый для обоих)

```ini
# /opt/asterisk/master-asterisk/extconfig.conf
[settings]
ps_endpoints => odbc,asteriskdb,ps_endpoints
ps_auths => odbc,asteriskdb,ps_auths
ps_aors => odbc,asteriskdb,ps_aors
extensions => odbc,asteriskdb,extensions
iaxfriends => odbc,asteriskdb,iaxfriends
```

```bash
cp /opt/asterisk/master-asterisk/extconfig.conf /opt/asterisk/slave-asterisk/
```

### 6.3 Упростить pjsip.conf (только транспорт)

**Для master:**
```ini
# /opt/asterisk/master-asterisk/pjsip.conf
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
```

**Для slave:**
```ini
# /opt/asterisk/slave-asterisk/pjsip.conf
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5061
```

### 6.4 Проверить endpoints

```bash
docker exec master-asterisk asterisk -rx 'pjsip show endpoints'
docker exec slave-asterisk asterisk -rx 'pjsip show endpoints'
```

**Ожидаемый результат:**
- Master: 4000, 4001
- Slave: 5000, 5001, 5002

---

## 7. Перенос Dialplan в БД

### 7.1 Упростить extensions.conf (только switch)

**Для master и slave:**
```ini
# /opt/asterisk/master-asterisk/extensions.conf
[default]
switch => Realtime/default@extensions

[outcall]
switch => Realtime/outcall@extensions
```

```bash
cp /opt/asterisk/master-asterisk/extensions.conf /opt/asterisk/slave-asterisk/
```

### 7.2 Проверить dialplan

```bash
docker exec master-asterisk asterisk -rx 'dialplan show default'
```

**Ожидаемый результат (после 1 звонка):**
```
[ Context 'default' created by 'pbx_config' ]
  '_4XXX' =>  1. Dial(PJSIP/${EXTEN})
  '_5XXX' =>  1. Dial(IAX2/iaxuser2:secret2@127.0.0.1:4570/${EXTEN})
```

---

## 8. Настройка IAX2 транка между серверами

### 8.1 Создать iax.conf для master

```ini
# /opt/asterisk/master-asterisk/iax.conf
[general]
autokill=yes
language=ru
disallow=all
allow=alaw            ; Используем только alaw для IAX2
allow=ulaw            ; Добавил ulaw
bindport=4569
bindaddr=0.0.0.0
rtcachefriends=yes

register => iaxuser2:secret2@127.0.01:4570
```

### 8.2 Создать iax.conf для slave

```ini
# /opt/asterisk/slave-asterisk/iax.conf
[general]
autokill=yes
language=en
disallow=all
allow=alaw
allow=ulaw
bindport=4570
bindaddr=0.0.0.0
rtcachefriends=yes

register => iaxuser1:secret1@127.0.01:4569
```

### 8.3 Проверить IAX2 регистрацию

```bash
docker exec master-asterisk asterisk -rx 'iax2 show registry'
```

**Ожидаемый результат:**
```
Host                     Username    Perceived          State
127.0.0.1:4570           iaxuser2    127.0.0.1:4569     Registered
```

---

## 9. Перенос IAX2 в БД

Данные уже вставлены твоими скриптами:
- `init_master.sql` содержит `iaxuser1`
- `init_slave.sql` содержит `iaxuser2`

### 9.1 Проверить IAX2 из БД

```bash
docker exec slave-asterisk asterisk -rx 'iax2 show peers'
```

**Ожидаемый результат:**
```
Name/Username    Host                 Status
iaxuser2         172.29.0.11          OK
```

---

## 10. Запуск всех сервисов

```bash
# Запустить MySQL
cd /opt/asterisk/mysql
docker compose up -d

# Собрать и запустить master
cd /opt/asterisk/master-asterisk
docker build -t master-asterisk:1.0 .
docker compose up -d

# Собрать и запустить slave
cd /opt/asterisk/slave-asterisk
docker build -t slave-asterisk:1.0 .
docker compose up -d
```

---

## 11. Проверка работы

### 11.1 Проверить ODBC

```bash
docker exec master-asterisk asterisk -rx 'odbc show'
docker exec slave-asterisk asterisk -rx 'odbc show'
```

### 11.2 Проверить PJSIP endpoints

```bash
docker exec master-asterisk asterisk -rx 'pjsip show endpoints'
docker exec slave-asterisk asterisk -rx 'pjsip show endpoints'
```

### 11.3 Проверить IAX2

```bash
docker exec master-asterisk asterisk -rx 'iax2 show registry'
docker exec master-asterisk asterisk -rx 'iax2 show peers'
docker exec slave-asterisk asterisk -rx 'iax2 show peers'
```

### 11.4 Проверить Dialplan

```bash
docker exec master-asterisk asterisk -rx 'dialplan show default'
docker exec slave-asterisk asterisk -rx 'dialplan show default'
```

### 11.5 Тестовый звонок

```bash
# С master на slave (4000 → 5000)
docker exec master-asterisk asterisk -rx 'channel originate PJSIP/4000 application Dial IAX2/iaxuser2:secret2@172.29.0.11:4570/5000'
```

---

## 12. Полезные команды

### 12.1 Работа с MySQL

```bash
# Подключиться к MySQL
docker exec -it asterisk-mysql mysql -u asterisk_user -pasterisk_pass

# Показать все базы
docker exec asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "SHOW DATABASES;"

# Показать содержимое extensions в slave
docker exec asterisk-mysql mysql -u asterisk_user -pasterisk_pass -e "USE asterisk_slave_db; SELECT * FROM extensions;"
```

### 12.2 Полная диагностика master

```bash
echo "=== ODBC ===" && \
docker exec master-asterisk asterisk -rx 'odbc show' && \
echo -e "\n=== PJSIP ENDPOINTS ===" && \
docker exec master-asterisk asterisk -rx 'pjsip show endpoints' && \
echo -e "\n=== IAX2 PEERS ===" && \
docker exec master-asterisk asterisk -rx 'iax2 show peers' && \
echo -e "\n=== IAX2 REGISTRY ===" && \
docker exec master-asterisk asterisk -rx 'iax2 show registry' && \
echo -e "\n=== DIALPLAN ===" && \
docker exec master-asterisk asterisk -rx 'dialplan show default'
```

### 12.3 Перезапуск всех сервисов

```bash
docker restart asterisk-mysql
docker restart master-asterisk
docker restart slave-asterisk
```

---

## Таблица с номерами клиентов

| Сервер | Номера | Транспорт | Пароль |
|--------|--------|-----------|--------|
| Master | 4000, 4001 | transport-udp (5060) | 123456 |
| Slave | 5000, 5001, 5002 | transport-udp (5061) | 123456 |