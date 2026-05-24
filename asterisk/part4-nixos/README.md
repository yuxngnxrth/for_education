# Asterisk в Docker — Часть 4: Безопасность и шифрование (NixOS)

Защищённое окружение Asterisk с TLS/SRTP-шифрованием, HTTPS-доступом к phpMyAdmin через Nginx и защитой от брутфорса через fail2ban.

> Если вы на Ubuntu 22.04 — используйте `part4-ubuntu`. Эта директория только для NixOS.

---

## Содержание

1. [Что добавляется в этой части](#1-что-добавляется-в-этой-части)
2. [Требования к хосту](#2-требования-к-хосту)
3. [Структура проекта](#3-структура-проекта)
4. [Запуск](#4-запуск)
5. [PKI и сертификаты](#5-pki-и-сертификаты)
6. [Asterisk — TLS и SRTP](#6-asterisk--tls-и-srtp)
7. [MySQL — схема базы данных](#7-mysql--схема-базы-данных)
8. [Nginx — HTTPS и Basic Auth](#8-nginx--https-и-basic-auth)
9. [fail2ban — защита от брутфорса](#9-fail2ban--защита-от-брутфорса)
10. [Настройка SIP-клиента — PortSIP](#10-настройка-sip-клиента--portsip)
11. [Проверка работоспособности](#11-проверка-работоспособности)
12. [Устранение проблем](#12-устранение-проблем)
13. [Полезные команды](#13-полезные-команды)

---

## 1. Что добавляется в этой части

В части 3 Asterisk работал по незашифрованному UDP. В части 4 добавляется:

| Компонент | Что делает |
|-----------|------------|
| **TLS (порт 5061)** | Шифрует SIP-сигнализацию между телефоном и сервером |
| **SRTP** | Шифрует голосовой трафик (RTP → SRTP) |
| **PKI** | Самоподписанный CA, сертификат сервера с SAN, клиентские сертификаты |
| **Nginx** | Выставляет phpMyAdmin наружу по HTTPS с Basic Auth вместо прямого доступа |
| **fail2ban** | Блокирует IP после 4 неудачных попыток входа в SSH, SIP, phpMyAdmin |

**Почему network_mode: host:** Asterisk должен видеть реальные IP-адреса клиентов для корректной работы RTP и fail2ban. При bridge-сети все подключения приходят с IP контейнера, а не клиента.

---

## 2. Требования к хосту

### 2.1 Убедиться что journald работает

fail2ban читает SSH-логи через systemd journal (`backend = systemd`). На NixOS journald работает по умолчанию — `/var/log/auth.log` не требуется.

```bash
journalctl -u sshd --no-pager -n 5
```

Если вывод пустой, но SSH-демон работает — журнал собирается, просто подключений ещё не было.

### 2.2 Проверить firewall

NixOS по умолчанию включает nftables-firewall. Убедитесь что нужные порты открыты в `configuration.nix`:

```nix
networking.firewall.allowedTCPPorts = [ 5061 8090 8443 ];
networking.firewall.allowedUDPPorts = [ 5060 ];
networking.firewall.allowedUDPPortRanges = [
  { from = 10000; to = 15000; }
];
```

После изменения применить конфигурацию:

```bash
sudo nixos-rebuild switch
```

### 2.3 Проверить что порты 5060, 5061 свободны

```bash
ss -tlnp | grep -E ':5060|:5061'
ss -ulnp | grep ':5060'
```

Вывод должен быть пустым — порты займёт Asterisk.

### 2.4 Проверить что порты 8090, 8443 свободны

```bash
ss -tlnp | grep -E ':8090|:8443'
```

### 2.5 Установить Docker (если не установлен)

На NixOS Docker устанавливается через `configuration.nix`:

```nix
virtualisation.docker.enable = true;
users.users.<ваш_пользователь>.extraGroups = [ "docker" ];
```

```bash
sudo nixos-rebuild switch
```

После перелогиниться или выполнить:

```bash
newgrp docker
```

---

## 3. Структура проекта

```
part4-nixos/
├── docker-compose.yml          ← оркестрация 5 сервисов в host-режиме
├── asterisk/
│   ├── Dockerfile              ← Asterisk 18 + ODBC + OpenSSL
│   ├── entrypoint.sh           ← генерация PKI, обновление БД, запуск
│   ├── pjsip.conf              ← транспорты UDP (5060) и TLS (5061)
│   ├── extensions.conf         ← диалплан: switch → Realtime (MySQL)
│   ├── res_odbc.conf           ← ODBC-пул соединений к MySQL
│   ├── sorcery.conf            ← PJSIP-объекты хранятся в Realtime
│   ├── extconfig.conf          ← маппинг таблиц MySQL → модули
│   ├── logger.conf             ← /var/log/asterisk/messages для fail2ban
│   ├── rtp.conf                ← диапазон RTP-портов 10000–15000
│   ├── cdr.conf / cdr_odbc.conf← запись истории звонков в MySQL
│   ├── odbc.ini / odbcinst.ini ← DSN asteriskdb → MySQL 127.0.0.1:3306
│   └── manager.conf            ← AMI (порт 5038)
├── nginx/
│   ├── Dockerfile
│   ├── entrypoint.sh           ← генерация rootCA, pma.crt, dhparam, htpasswd
│   └── phpmyadmin.conf         ← HTTPS 8443, Basic Auth → proxy :8082
├── phpmyadmin/
│   └── Dockerfile              ← phpMyAdmin на Apache, порт 8082 (localhost only)
├── mysql/
│   └── init.sql                ← схема БД + данные абонентов 4000/4001
└── fail2ban/
    ├── Dockerfile              ← fail2ban + iptables + python3-systemd
    ├── jail.d/
    │   ├── defaults.conf       ← maxretry=4, bantime=10m
    │   ├── defaults-debian.conf← отключает дефолтный [sshd] от пакета
    │   ├── ssh.conf            ← backend=systemd (journald), port=40000
    │   ├── asterisk.conf       ← iptables-allports, protocol=all
    │   └── phpmyadmin.conf     ← nginx-phpmyadmin + nginx-http-auth
    └── filter.d/
        └── nginx-phpmyadmin.conf← regex для ошибок входа в phpMyAdmin
```

---

## 4. Запуск

### 4.1 Первый запуск

```bash
cd part4-nixos
docker compose up --build -d
```

`--build` пересобирает образы из Dockerfile. При повторных запусках без изменений Dockerfile можно использовать просто `docker compose up -d`.

### 4.2 Проверить статус контейнеров

```bash
docker compose ps
```

**Ожидаемый результат — все пять контейнеров Up:**

```
NAME                    STATUS
asterisk-mysql-secure   Up
asterisk-secure         Up (healthy)
phpmyadmin-secure       Up
nginx-secure            Up
fail2ban-secure         Up
```

### 4.3 Следить за инициализацией Asterisk

При первом запуске `entrypoint.sh` генерирует PKI-сертификаты (~30 сек) и ждёт MySQL:

```bash
docker compose logs -f asterisk
```

**Ожидаемый результат:**

```
[entrypoint] Waiting for MySQL at 127.0.0.1:3306...
[entrypoint] MySQL is ready (attempt 1)
[entrypoint] Generating PKI certificates...
[entrypoint] Certificates generated in /etc/asterisk/keys
[entrypoint] Updating database endpoints for TLS/SRTP...
[entrypoint] Database updated
[entrypoint] Starting Asterisk...
Asterisk Ready.
```

### 4.4 Полный пересброс (если нужно начать с нуля)

Удаляет все volumes включая БД и сертификаты:

```bash
docker compose down -v
docker compose up --build -d
```

---

## 5. PKI и сертификаты

### 5.1 Зачем нужен собственный CA

TLS требует цепочки доверия. Поскольку сертификат самоподписанный, клиент не знает о нашем CA. Есть два пути:
- Установить CA-сертификат на клиента (строгая проверка)
- Отключить проверку сертификата в клиенте (PortSIP поддерживает этот режим)

### 5.2 Что генерирует entrypoint.sh

```
ca.key / ca.crt                       ← корневой CA (доверенный якорь)
    └── asterisk.key / asterisk.crt   ← сертификат сервера Asterisk
            ├── client4000.key / client4000.crt / client4000.pem
            └── client4001.key / client4001.crt / client4001.pem
```

`client*.pem` — объединённые cert+key, нужны некоторым клиентам.

### 5.3 SAN (Subject Alternative Name)

Серверный сертификат содержит SAN — без него современные клиенты отвергают сертификат при подключении по IP-адресу:

```
DNS:pbx.example.com, DNS:localhost, IP:127.0.0.1, IP:<IP хоста>
```

IP хоста определяется автоматически: `hostname -I | awk '{print $1}'`.

### 5.4 Проверить сертификат

```bash
# Список файлов в volume
docker exec asterisk-secure ls -la /etc/asterisk/keys/

# Что записано в SAN
docker exec asterisk-secure openssl x509 -noout -text \
  -in /etc/asterisk/keys/asterisk.crt | grep -A1 'Subject Alt'

# Проверить цепочку
docker exec asterisk-secure \
  openssl verify -CAfile /etc/asterisk/keys/ca.crt \
                 /etc/asterisk/keys/client4000.crt
```

**Ожидаемый результат последней команды:** `client4000.crt: OK`

### 5.5 Пересоздать сертификаты (при смене IP)

```bash
docker compose down
docker volume rm asterisk_secure_asterisk_keys
docker compose up -d
```

### 5.6 Скопировать сертификаты на хост

```bash
docker cp asterisk-secure:/etc/asterisk/keys/ca.crt       ./ca.crt
docker cp asterisk-secure:/etc/asterisk/keys/client4000.pem ./client4000.pem
docker cp asterisk-secure:/etc/asterisk/keys/client4001.pem ./client4001.pem
```

### 5.7 Добавить CA в системное хранилище NixOS (опционально)

Позволяет браузеру и другим приложениям доверять самоподписанному сертификату:

```nix
security.pki.certificateFiles = [ /path/to/ca.crt ];
```

```bash
sudo nixos-rebuild switch
```

---

## 6. Asterisk — TLS и SRTP

### 6.1 pjsip.conf — транспорты

```ini
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060   ← оставлен для обратной совместимости

[transport-tls]
type = transport
protocol = tls
bind = 0.0.0.0:5061
cert_file     = /etc/asterisk/keys/asterisk.crt
priv_key_file = /etc/asterisk/keys/asterisk.key
ca_list_file  = /etc/asterisk/keys/ca.crt   ← обязателен: без него pjproject не инициализирует TLS
method        = tlsv1_2                      ← минимальная версия TLS
verify_client = no                           ← клиент авторизуется по SIP digest (логин/пароль)
```

### 6.2 SRTP — шифрование голоса

Абоненты в БД настроены с `media_encryption = sdes`. SDES (Security Descriptions) — обмен ключами SRTP через SDP в SIP-сигнализации. Поскольку SIP уже зашифрован TLS, ключи SRTP передаются безопасно.

### 6.3 Проверить транспорты

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
```

**Ожидаемый результат:**

```
Transport:  transport-tls    tls    0    0    0.0.0.0:5061
Transport:  transport-udp    udp    0    0    0.0.0.0:5060
```

### 6.4 Проверить абонентов

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

### 6.5 TLS-рукопожатие

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

## 7. MySQL — схема базы данных

### 7.1 Таблицы и их назначение

| Таблица | Назначение |
|---------|------------|
| `ps_endpoints` | параметры абонентов: транспорт, шифрование, SRTP |
| `ps_auths` | логин и пароль каждого абонента |
| `ps_aors` | адресные записи: `max_contacts=1` (один активный контакт) |
| `ps_contacts` | текущие регистрации — заполняется Asterisk автоматически |
| `extensions` | диалплан: `_4XXX → Dial(PJSIP/${EXTEN})` |
| `cdr` | история звонков |

### 7.2 Почему PRIMARY KEY в ps_contacts важен

Без первичного ключа Asterisk не может корректно обновлять контакты при перерегистрации — вместо обновления существующей записи вставляет новую. Это приводит к накоплению дублей и нарушению `max_contacts`.

### 7.3 Проверить TLS-параметры абонентов

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db;
      SELECT id, transport, media_encryption, dtls_cert_file
      FROM ps_endpoints;" 2>/dev/null
```

**Ожидаемый результат** (после инициализации entrypoint.sh):

```
id    transport      media_encryption  dtls_cert_file
4000  transport-tls  sdes              /etc/asterisk/keys/client4000.crt
4001  transport-tls  sdes              /etc/asterisk/keys/client4001.crt
```

Если поля NULL — Asterisk ещё не завершил инициализацию. Подождите и проверьте логи:

```bash
docker compose logs -f asterisk
```

### 7.4 Сброс базы данных

```bash
docker compose down
docker volume rm asterisk_secure_mysql_data
docker compose up -d
```

---

## 8. Nginx — HTTPS и Basic Auth

### 8.1 Зачем Nginx перед phpMyAdmin

phpMyAdmin слушает на `127.0.0.1:8082` и снаружи недоступен напрямую. Nginx:
- Терминирует TLS (HTTPS на порту 8443)
- Проверяет Basic Auth перед проксированием
- Добавляет Forward Secrecy через DH-параметры

### 8.2 Что генерирует entrypoint.sh при первом старте

| Файл | Назначение |
|------|------------|
| `rootCA.key / rootCA.crt` | самоподписанный CA для nginx |
| `pma.key / pma.crt` | сертификат сайта (CN=localhost) |
| `dhparam.pem` | параметры DH 2048-бит (генерация ~30 сек) |
| `.htpasswd` | файл паролей для Basic Auth |

### 8.3 Конфигурация phpmyadmin.conf

```nginx
server {
    listen 8090;                             # HTTP → редирект на HTTPS
    return 301 https://$host:8443$request_uri;
}

server {
    listen 8443 ssl;
    ssl_certificate     /etc/nginx/ssl/pma.crt;
    ssl_certificate_key /etc/nginx/ssl/pma.key;
    ssl_dhparam         /etc/nginx/ssl/dhparam.pem;  # Forward Secrecy
    ssl_protocols       TLSv1.2 TLSv1.3;

    auth_basic           "Restricted Access!";        # Basic Auth
    auth_basic_user_file /etc/nginx/conf.d/.htpasswd;

    proxy_pass http://127.0.0.1:8082;               # phpMyAdmin
}
```

### 8.4 Проверить Nginx

```bash
# Конфиг корректен
docker exec nginx-secure nginx -t

# Без пароля — 401
curl -sk -o /dev/null -w "%{http_code}\n" https://localhost:8443/

# С паролем — 200
curl -sk -o /dev/null -w "%{http_code}\n" -u developer:developer123 https://localhost:8443/
```

**Ожидаемый результат:** `401`, затем `200`

### 8.5 Открыть в браузере

```
https://<IP сервера>:8443
```

Логин: `developer`, пароль: `developer123`

---

## 9. fail2ban — защита от брутфорса

### 9.1 Как работает fail2ban

1. Читает лог-файлы через volumes
2. Применяет regex-фильтры к строкам
3. Считает совпадения за `findtime` (10 мин)
4. При превышении `maxretry` (4) добавляет правило iptables → бан на `bantime` (10 мин)

### 9.2 Отличие от part4-ubuntu

На Ubuntu существует `/var/log/auth.log` от rsyslog — поэтому SSH jail использует `backend = polling` (файловый). NixOS использует journald без rsyslog, поэтому SSH jail использует `backend = systemd`. Для этого в Dockerfile устанавливается `python3-systemd`, а в volume монтируется `/var/log/journal`.

### 9.3 Активные jail'ы

| Jail | Порты | Лог | Что блокирует |
|------|-------|-----|---------------|
| `ssh` | 40000 | systemd journal (`_SYSTEMD_UNIT=sshd.service`) | брутфорс SSH |
| `asterisk` | 5060, 5061 | `/var/log/asterisk/messages` | брутфорс SIP |
| `phpmyadmin` | 8090, 8443 | `/var/log/nginx/access.log` | брутфорс phpMyAdmin |
| `nginx-http-auth` | 8090, 8443 | `/var/log/nginx/error.log` | неверный Basic Auth |

### 9.4 Volumes fail2ban

```yaml
- asterisk_logs:/var/log/asterisk:ro
- nginx_logs:/var/log/nginx:ro
- /var/log:/var/log/host:ro
- /var/log/journal:/var/log/journal:ro   # для backend=systemd (journald)
```

### 9.5 Проверить статус jail'ов

```bash
docker exec fail2ban-secure fail2ban-client status
```

**Ожидаемый результат:**

```
Number of jail: 4
Jail list: asterisk, nginx-http-auth, phpmyadmin, ssh
```

### 9.6 Детали конкретного jail'а

```bash
docker exec fail2ban-secure fail2ban-client status asterisk
docker exec fail2ban-secure fail2ban-client status ssh
```

### 9.7 Тест бана вручную

```bash
# Забанить IP
docker exec fail2ban-secure fail2ban-client set asterisk banip 192.168.1.200

# Убедиться что появился в iptables
docker exec fail2ban-secure iptables -L -n | grep 192.168.1.200

# Разбанить
docker exec fail2ban-secure fail2ban-client set asterisk unbanip 192.168.1.200
```

---

## 10. Настройка SIP-клиента — PortSIP

Рекомендуемый клиент: **PortSIP Softphone** (бесплатный, Android и iOS, поддерживает TLS + SRTP).

### 10.1 Параметры подключения

| Параметр | Значение |
|----------|----------|
| SIP-сервер | `<IP машины>` |
| Порт | `5061` |
| Транспорт | `TLS` |
| Шифрование медиа | `SRTP` |
| Логин / Пароль | `4000` / `123456` или `4001` / `123456` |

### 10.2 Шаг 1 — добавить аккаунт в PortSIP

1. Открыть PortSIP → **Add Account**
2. Username: `4000`, Password: `123456`
3. Domain: `<IP машины>:5061`
4. **Transport: TLS**
5. Сохранить

### 10.3 Шаг 2 — включить SRTP

**Settings → Preferences → RTP → SRTP → Prefer**

### 10.4 Шаг 3 — отключить проверку сертификата

В настройках PortSIP отключить верификацию TLS-сертификата (сервер использует самоподписанный CA).

### 10.5 Проверить регистрацию

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'
```

**Ожидаемый результат:**

```
Contact:  4000/sip:4000@192.168.x.x:xxxxx;transport=tls  ... NonQual  -nan
```

---

## 11. Проверка работоспособности

### 11.1 Полная диагностика одной командой

```bash
echo "=== CONTAINERS ===" && docker compose ps && \
echo -e "\n=== ODBC ===" && \
  docker exec asterisk-secure asterisk -rx 'odbc show' && \
echo -e "\n=== TRANSPORTS ===" && \
  docker exec asterisk-secure asterisk -rx 'pjsip show transports' && \
echo -e "\n=== ENDPOINTS ===" && \
  docker exec asterisk-secure asterisk -rx 'pjsip show endpoints' && \
echo -e "\n=== DB TLS PARAMS ===" && \
  docker exec asterisk-mysql-secure mysql -u asterisk_user -pasterisk_pass \
    -e "USE asterisk_master_db; SELECT id,transport,media_encryption FROM ps_endpoints;" 2>/dev/null && \
echo -e "\n=== NGINX ===" && \
  docker exec nginx-secure nginx -t && \
echo -e "\n=== FAIL2BAN ===" && \
  docker exec fail2ban-secure fail2ban-client status
```

### 11.2 ODBC-соединение

```bash
docker exec asterisk-secure asterisk -rx 'odbc show'
```

**Ожидаемый результат:**

```
Name:   asteriskdb
  Number of active connections: 1 (out of 20)
```

Если `0 active connections` — MySQL не поднялся или неверные учётные данные.

---

## 12. Устранение проблем

### max contacts exceeded

Старый контакт завис в БД (абонент переподключился с другого порта):

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; DELETE FROM ps_contacts WHERE endpoint='4000';" 2>/dev/null
docker exec asterisk-secure asterisk -rx 'module reload res_pjsip.so'
```

### fail2ban забанил IP телефона

После 4 неверных паролей SIP:

```bash
docker exec fail2ban-secure fail2ban-client set asterisk unbanip <IP телефона>
```

### fail2ban не видит SSH-события

Убедиться что volume `/var/log/journal` смонтирован и journal доступен внутри контейнера:

```bash
docker exec fail2ban-secure ls /var/log/journal/
docker exec fail2ban-secure journalctl -u sshd --no-pager -n 5
```

Если директория пуста — на NixOS journal может храниться в `/run/log/journal`. Проверить:

```bash
ls /run/log/journal/
```

И при необходимости скорректировать volume в `docker-compose.yml`:

```yaml
- /run/log/journal:/var/log/journal:ro
```

### Nginx не стартует — dhparam отсутствует

Если volume `nginx_certs` был создан частично (pma.crt есть, dhparam.pem нет):

```bash
docker compose down
docker volume rm asterisk_secure_nginx_certs
docker compose up -d nginx
```

### MySQL отказывает в подключении

Stale volume от предыдущего запуска с другими настройками — init.sql не перезапускается:

```bash
docker compose down -v
docker compose up --build -d
```

### Включить отладку SIP в реальном времени

```bash
docker exec asterisk-secure asterisk -rx 'pjsip set logger on'
docker exec asterisk-secure tail -f /var/log/asterisk/full
```

---

## 13. Полезные команды

### Контейнеры

```bash
# Статус
docker compose ps

# Логи конкретного сервиса
docker compose logs -f asterisk
docker compose logs -f nginx
docker compose logs -f fail2ban

# Консоль Asterisk
docker exec -it asterisk-secure asterisk -r
```

### Asterisk

```bash
# Транспорты и абоненты
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
docker exec asterisk-secure asterisk -rx 'pjsip show endpoints'
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'

# ODBC
docker exec asterisk-secure asterisk -rx 'odbc show'

# Диалплан
docker exec asterisk-secure asterisk -rx 'dialplan show default'
```

### fail2ban

```bash
docker exec fail2ban-secure fail2ban-client status
docker exec fail2ban-secure fail2ban-client status asterisk
docker exec fail2ban-secure fail2ban-client set asterisk unbanip <IP>
```

### Nginx

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://localhost:8443/
curl -sk -o /dev/null -w "%{http_code}\n" -u developer:developer123 https://localhost:8443/
```

### MySQL

```bash
# Подключиться к MySQL
docker exec -it asterisk-mysql-secure mysql -u asterisk_user -pasterisk_pass

# TLS-параметры абонентов
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; SELECT id,transport,media_encryption FROM ps_endpoints;" 2>/dev/null

# Зарегистрированные контакты
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
