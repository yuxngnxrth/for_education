# Asterisk в Docker — Часть 4: TLS/SRTP, Nginx, fail2ban (Ubuntu 22.04)

Asterisk с шифрованием звонков, phpMyAdmin за Nginx+HTTPS и защитой от брутфорса через fail2ban.

> Если вы на NixOS — используйте `part4`. Эта директория только для Ubuntu 22.04.

---

## Содержание

1. [Требования к хосту](#1-требования-к-хосту)
2. [Структура проекта](#2-структура-проекта)
3. [Запуск](#3-запуск)
4. [PKI и сертификаты](#4-pki-и-сертификаты)
5. [Asterisk — TLS и SRTP](#5-asterisk--tls-и-srtp)
6. [MySQL — схема базы данных](#6-mysql--схема-базы-данных)
7. [Nginx — HTTPS и Basic Auth](#7-nginx--https-и-basic-auth)
8. [fail2ban](#8-fail2ban)
9. [Настройка SIP-клиента — PortSIP](#9-настройка-sip-клиента--portsip)
10. [Проверка работоспособности](#10-проверка-работоспособности)
11. [Устранение проблем](#11-устранение-проблем)
12. [Полезные команды](#12-полезные-команды)

---

## 1. Требования к хосту

### 1.1 Проверить наличие auth.log

fail2ban читает `/var/log/auth.log` для SSH jail. На Ubuntu он есть по умолчанию (rsyslog).

```bash
ls -la /var/log/auth.log
```

Если файл отсутствует:

```bash
sudo apt install rsyslog -y
sudo systemctl enable --now rsyslog
```

### 1.2 Отключить ufw

ufw конфликтует с iptables-правилами fail2ban — при обновлении ufw может сбросить баны.

```bash
sudo ufw status
sudo ufw disable    # если active
```

### 1.3 Проверить что порты свободны

```bash
ss -tlnp | grep -E ':5060|:5061'
ss -ulnp | grep ':5060'
ss -tlnp | grep -E ':8090|:8443'
```

Вывод должен быть пустым.

> Nginx использует 8090/8443, а не 80/443 — те могут быть заняты другими сервисами.

### 1.4 Установить Docker (если не установлен)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

---

## 2. Структура проекта

```
part4-ubuntu/
├── docker-compose.yml
├── asterisk/
│   ├── Dockerfile              ← Asterisk 18 + ODBC + OpenSSL
│   ├── entrypoint.sh           ← генерация PKI, обновление БД, запуск
│   ├── pjsip.conf              ← транспорты UDP (5060) и TLS (5061)
│   ├── extensions.conf         ← диалплан: switch → Realtime (MySQL)
│   ├── res_odbc.conf / sorcery.conf / extconfig.conf
│   ├── logger.conf             ← /var/log/asterisk/messages для fail2ban
│   ├── rtp.conf                ← диапазон RTP-портов 10000–15000
│   ├── cdr.conf / cdr_odbc.conf
│   ├── odbc.ini / odbcinst.ini ← DSN asteriskdb → MySQL 127.0.0.1:3306
│   └── manager.conf
├── nginx/
│   ├── Dockerfile
│   ├── entrypoint.sh           ← генерация rootCA, сертификата, dhparam, htpasswd
│   └── phpmyadmin.conf         ← HTTPS 8443, Basic Auth → proxy :8082
├── phpmyadmin/
│   └── Dockerfile              ← phpMyAdmin на Apache, порт 8082 (localhost only)
├── mysql/
│   └── init.sql                ← схема БД + абоненты 4000/4001
└── fail2ban/
    ├── Dockerfile
    ├── jail.d/
    │   ├── defaults.conf       ← maxretry=4, bantime=10m
    │   ├── defaults-debian.conf← отключает дефолтный [sshd] от пакета
    │   ├── ssh.conf            ← backend=polling, /var/log/host/auth.log
    │   ├── asterisk.conf       ← iptables-allports, protocol=all
    │   └── phpmyadmin.conf     ← nginx-phpmyadmin + nginx-http-auth
    └── filter.d/
        └── nginx-phpmyadmin.conf
```

---

## 3. Запуск

### 3.1 Первый запуск

```bash
cd part4-ubuntu
docker compose up --build -d
```

### 3.2 Проверить статус контейнеров

```bash
docker compose ps
```

**Ожидаемый результат:**

```
NAME                    STATUS
asterisk-mysql-secure   Up
asterisk-secure         Up
phpmyadmin-secure       Up
nginx-secure            Up
fail2ban-secure         Up
```

### 3.3 Следить за инициализацией Asterisk

При первом запуске генерируются PKI-сертификаты (~30 сек):

```bash
docker compose logs -f asterisk
```

**Ожидаемый результат:**

```
[entrypoint] Ждём MySQL на 127.0.0.1:3306...
[entrypoint] MySQL готов (попытка 1)
[entrypoint] Генерируем PKI-сертификаты...
[entrypoint] Сертификаты готовы в /etc/asterisk/keys
[entrypoint] Обновляем настройки абонентов в БД...
[entrypoint] БД обновлена
[entrypoint] Запускаем Asterisk...
Asterisk Ready.
```

### 3.4 Полный пересброс

```bash
docker compose down -v
docker compose up --build -d
```

---

## 4. PKI и сертификаты

### 4.1 Что генерирует entrypoint.sh

```
ca.key / ca.crt                       ← корневой CA
    └── asterisk.key / asterisk.crt   ← сертификат сервера (с SAN)
            ├── client4000.key / client4000.crt / client4000.pem
            └── client4001.key / client4001.crt / client4001.pem
```

`client*.pem` — cert+key в одном файле, нужен некоторым клиентам (PhonerLite и др.).

Серверный сертификат содержит SAN с реальным IP хоста — без этого клиенты отвергают сертификат при подключении по IP-адресу.

### 4.2 Проверить сертификат

```bash
# Список файлов
docker exec asterisk-secure ls -la /etc/asterisk/keys/

# SAN сервера
docker exec asterisk-secure openssl x509 -noout -text \
  -in /etc/asterisk/keys/asterisk.crt | grep -A1 'Subject Alt'

# Цепочка доверия
docker exec asterisk-secure \
  openssl verify -CAfile /etc/asterisk/keys/ca.crt \
                 /etc/asterisk/keys/client4000.crt
```

**Ожидаемый результат последней команды:** `client4000.crt: OK`

### 4.3 Пересоздать сертификаты (например, при смене IP)

```bash
docker compose down
docker volume rm asterisk_secure_asterisk_keys
docker compose up -d
```

### 4.4 Скопировать сертификаты на хост

```bash
docker cp asterisk-secure:/etc/asterisk/keys/ca.crt       ./ca.crt
docker cp asterisk-secure:/etc/asterisk/keys/client4000.pem ./client4000.pem
docker cp asterisk-secure:/etc/asterisk/keys/client4001.pem ./client4001.pem
```

---

## 5. Asterisk — TLS и SRTP

### 5.1 Транспорты

UDP на 5060 оставлен для совместимости, TLS на 5061 — основной для абонентов.

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
```

**Ожидаемый результат:**

```
Transport:  transport-tls    tls    0    0    0.0.0.0:5061
Transport:  transport-udp    udp    0    0    0.0.0.0:5060
```

### 5.2 Абоненты

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show endpoints'
```

**Ожидаемый результат (до подключения клиента):**

```
Endpoint:  4000    Not in use    0 of inf
  Transport:  transport-tls    tls    0.0.0.0:5061

Endpoint:  4001    Not in use    0 of inf
  Transport:  transport-tls    tls    0.0.0.0:5061
```

### 5.3 Проверить TLS-рукопожатие

```bash
openssl s_client -connect 127.0.0.1:5061 \
  -CAfile <(docker exec asterisk-secure cat /etc/asterisk/keys/ca.crt) 2>&1 \
  | grep -E 'CONNECTED|subject|Protocol|Verify return'
```

**Ожидаемый результат:**

```
CONNECTED(00000003)
subject=CN=pbx.example.com ...
Protocol: TLSv1.3
Verify return code: 0 (ok)
```

---

## 6. MySQL — схема базы данных

### 6.1 Таблицы

| Таблица | Назначение |
|---------|------------|
| `ps_endpoints` | параметры абонентов: транспорт, шифрование, SRTP |
| `ps_auths` | логин и пароль |
| `ps_aors` | `max_contacts=1` (один активный контакт) |
| `ps_contacts` | текущие регистрации (заполняет Asterisk) |
| `extensions` | диалплан: `_4XXX → Dial(PJSIP/${EXTEN})` |
| `cdr` | история звонков |

### 6.2 Проверить TLS-параметры абонентов

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db;
      SELECT id, transport, media_encryption, dtls_cert_file
      FROM ps_endpoints;" 2>/dev/null
```

**Ожидаемый результат:**

```
id    transport      media_encryption  dtls_cert_file
4000  transport-tls  sdes              /etc/asterisk/keys/client4000.crt
4001  transport-tls  sdes              /etc/asterisk/keys/client4001.crt
```

Если поля NULL — Asterisk ещё не завершил инициализацию, подождите и проверьте логи.

### 6.3 Сброс базы данных

```bash
docker compose down
docker volume rm asterisk_secure_mysql_data
docker compose up -d
```

---

## 7. Nginx — HTTPS и Basic Auth

phpMyAdmin слушает на `127.0.0.1:8082` и снаружи недоступен напрямую. Nginx терминирует TLS и проверяет Basic Auth перед проксированием.

### 7.1 Проверить Nginx

```bash
# Конфиг корректен
docker exec nginx-secure nginx -t

# Без пароля — 401
curl -sk -o /dev/null -w "%{http_code}\n" https://localhost:8443/

# С паролем — 200
curl -sk -o /dev/null -w "%{http_code}\n" -u developer:developer123 https://localhost:8443/
```

### 7.2 Открыть в браузере

```
https://<IP сервера>:8443
```

Логин: `developer`, пароль: `developer123`

---

## 8. fail2ban

### 8.1 Активные jail'ы

| Jail | Порт | Лог | Что блокирует |
|------|------|-----|---------------|
| `ssh` | 40000 | `/var/log/host/auth.log` | брутфорс SSH |
| `asterisk` | 5060, 5061 | `/var/log/asterisk/messages` | брутфорс SIP |
| `phpmyadmin` | 8090, 8443 | `/var/log/nginx/access.log` | брутфорс phpMyAdmin |
| `nginx-http-auth` | 8090, 8443 | `/var/log/nginx/error.log` | неверный Basic Auth |

### 8.2 Проверить статус

```bash
docker exec fail2ban-secure fail2ban-client status
```

**Ожидаемый результат:**

```
Number of jail: 4
Jail list: asterisk, nginx-http-auth, phpmyadmin, ssh
```

### 8.3 Детали конкретного jail'а

```bash
docker exec fail2ban-secure fail2ban-client status asterisk
docker exec fail2ban-secure fail2ban-client status ssh
```

### 8.4 Тест бана вручную

```bash
docker exec fail2ban-secure fail2ban-client set asterisk banip 192.168.1.200
docker exec fail2ban-secure iptables -L -n | grep 192.168.1.200
docker exec fail2ban-secure fail2ban-client set asterisk unbanip 192.168.1.200
```

---

## 9. Настройка SIP-клиента — PortSIP

Рекомендуемый клиент: **PortSIP Softphone** (бесплатный, Android/iOS, поддерживает TLS + SRTP).

### 9.1 Параметры подключения

| Параметр | Значение |
|----------|----------|
| SIP-сервер | `<IP машины>` |
| Порт | `5061` |
| Транспорт | `TLS` |
| Шифрование медиа | `SRTP` |
| Логин / Пароль | `4000` / `123456` или `4001` / `123456` |

### 9.2 Добавить аккаунт

1. PortSIP → **Add Account**
2. Username: `4000`, Password: `123456`
3. Domain: `<IP машины>:5061`, Transport: **TLS**

### 9.3 Включить SRTP

**Settings → Preferences → RTP → SRTP → Prefer**

### 9.4 Отключить проверку сертификата

В настройках PortSIP отключить верификацию TLS — сервер использует самоподписанный CA.

### 9.5 Проверить регистрацию

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'
```

**Ожидаемый результат:**

```
Contact:  4000/sip:4000@192.168.x.x:xxxxx;transport=tls  ... NonQual  -nan
```

---

## 10. Проверка работоспособности

### 10.1 ODBC-соединение

```bash
docker exec asterisk-secure asterisk -rx 'odbc show'
```

**Ожидаемый результат:**

```
Name:   asteriskdb
  Number of active connections: 1 (out of 20)
```

Если `0 active connections` — MySQL не поднялся или неверные учётные данные.

### 10.2 Полная диагностика

```bash
docker compose ps
docker exec asterisk-secure asterisk -rx 'odbc show'
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
docker exec asterisk-secure asterisk -rx 'pjsip show endpoints'
docker exec nginx-secure nginx -t
docker exec fail2ban-secure fail2ban-client status
```

---

## 11. Устранение проблем

### max contacts exceeded

Старый контакт завис в БД — абонент переподключился с другого порта:

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; DELETE FROM ps_contacts WHERE endpoint='4000';" 2>/dev/null
docker exec asterisk-secure asterisk -rx 'module reload res_pjsip.so'
```

### fail2ban забанил IP телефона

```bash
docker exec fail2ban-secure fail2ban-client set asterisk unbanip <IP телефона>
```

### Nginx не стартует — dhparam отсутствует

Volume `nginx_certs` создался частично:

```bash
docker compose down
docker volume rm asterisk_secure_nginx_certs
docker compose up -d nginx
```

### MySQL не принимает подключения

Stale volume от предыдущего запуска с другими настройками (init.sql не перезапускается):

```bash
docker compose down -v
docker compose up --build -d
```

### Включить отладку SIP

```bash
docker exec asterisk-secure asterisk -rx 'pjsip set logger on'
docker exec asterisk-secure tail -f /var/log/asterisk/full
```

---

## 12. Полезные команды

```bash
# Статус контейнеров
docker compose ps

# Логи сервиса
docker compose logs -f asterisk
docker compose logs -f nginx
docker compose logs -f fail2ban

# Консоль Asterisk
docker exec -it asterisk-secure asterisk -r

# Транспорты, абоненты, контакты
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
docker exec asterisk-secure asterisk -rx 'pjsip show endpoints'
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'
docker exec asterisk-secure asterisk -rx 'dialplan show default'

# fail2ban
docker exec fail2ban-secure fail2ban-client status
docker exec fail2ban-secure fail2ban-client status asterisk
docker exec fail2ban-secure fail2ban-client set asterisk unbanip <IP>

# Nginx
curl -sk -o /dev/null -w "%{http_code}\n" https://localhost:8443/
curl -sk -o /dev/null -w "%{http_code}\n" -u developer:developer123 https://localhost:8443/

# MySQL
docker exec -it asterisk-mysql-secure mysql -u asterisk_user -pasterisk_pass
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; SELECT id,transport,media_encryption FROM ps_endpoints;" 2>/dev/null
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; SELECT id,endpoint,uri FROM ps_contacts;" 2>/dev/null
```

---

## Учётные данные

| Что | Логин | Пароль |
|-----|-------|--------|
| MySQL root | root | `root_password` |
| MySQL пользователь | asterisk_user | `asterisk_pass` |
| Asterisk SIP 4000 | 4000 | `123456` |
| Asterisk SIP 4001 | 4001 | `123456` |
| phpMyAdmin (Basic Auth) | developer | `developer123` |

## Сервисы и порты

| Сервис | Контейнер | Порты | Доступность |
|--------|-----------|-------|-------------|
| MySQL 5.7 | `asterisk-mysql-secure` | 3306 | только localhost |
| Asterisk 18 | `asterisk-secure` | 5060/udp, 5061/tcp, 10000–15000/udp | публично |
| phpMyAdmin | `phpmyadmin-secure` | 8082 | только localhost |
| Nginx | `nginx-secure` | 8090 (→8443), 8443 | публично |
| fail2ban | `fail2ban-secure` | — | управляет iptables |
