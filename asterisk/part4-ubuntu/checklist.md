# Checklist конфигураций — part4-ubuntu

Каждый файл проекта, его назначение и ключевые параметры.

---

## docker-compose.yml

Оркестрирует все пять сервисов в режиме `network_mode: host` — все контейнеры разделяют сетевой стек хоста.

| Параметр | Значение | Зачем |
|----------|----------|-------|
| `network_mode: host` | все сервисы | Asterisk видит реальные IP клиентов, нет NAT |
| `asterisk: privileged: true` | — | нужен для bind на порты ниже 1024 и управления RTP |
| `fail2ban: cap_add: NET_ADMIN, NET_RAW` | — | управление iptables хоста из контейнера |
| `/var/log:/var/log/host:ro` | fail2ban volume | читает `/var/log/host/auth.log` для SSH jail |

**Volumes:**
- `mysql_data` — данные MySQL (БД, таблицы)
- `asterisk_keys` — PKI-сертификаты Asterisk
- `asterisk_logs` — логи Asterisk (читает fail2ban)
- `nginx_certs` — TLS-сертификаты Nginx
- `nginx_logs` — логи Nginx (читает fail2ban)

---

## asterisk/

### Dockerfile

Сборка Asterisk 18 с поддержкой ODBC и OpenSSL.

Устанавливает: `asterisk`, `unixodbc`, `libmaodbc`, `mariadb-client`, `openssl`.

---

### entrypoint.sh

Точка входа контейнера. Выполняется при каждом старте.

| Шаг | Действие |
|-----|----------|
| 1 | `touch /var/log/asterisk/messages` — создаёт лог-файл до старта Asterisk, чтобы fail2ban не падал |
| 2 | Ждёт MySQL (до 120 сек, проверка `mysqladmin ping`) |
| 3 | Генерирует PKI если `/etc/asterisk/keys/ca.crt` отсутствует: CA → сервер (с SAN) → клиенты 4000/4001 |
| 4 | Обновляет `ps_endpoints` в БД: включает `transport-tls`, `media_encryption=sdes` |
| 5 | Запускает `asterisk -f` |

SAN серверного сертификата содержит `DNS:pbx.example.com`, `DNS:localhost`, `IP:127.0.0.1`, `IP:<IP хоста>`.

---

### pjsip.conf

Транспорты SIP. Абоненты и их параметры хранятся в MySQL (не в этом файле).

```ini
[transport-udp]        # порт 5060, UDP — для совместимости
[transport-tls]        # порт 5061, TLS
  cert_file            # серверный сертификат
  priv_key_file        # приватный ключ сервера
  ca_list_file         # CA-сертификат (обязателен для инициализации TLS-контекста pjproject)
  method = tlsv1_2     # минимальная версия TLS
  verify_client = no   # клиент авторизуется по SIP digest, не по сертификату
```

---

### extensions.conf

Диалплан загружается из MySQL через Realtime:

```ini
[default]
switch => Realtime/default@extensions   # читает таблицу extensions, context=default

[outcall]
switch => Realtime/outcall@extensions   # context=outcall
```

Фактический маршрут в БД: `_4XXX → Dial(PJSIP/${EXTEN})`.

---

### extconfig.conf

Маппинг таблиц MySQL → модули Asterisk. Говорит Asterisk где искать данные для каждого объекта PJSIP.

```ini
ps_endpoints => odbc,asteriskdb,ps_endpoints
ps_auths     => odbc,asteriskdb,ps_auths
ps_aors      => odbc,asteriskdb,ps_aors
ps_contacts  => odbc,asteriskdb,ps_contacts
extensions   => odbc,asteriskdb,extensions
```

---

### sorcery.conf

Говорит модулю `res_pjsip` что его объекты (endpoint, auth, aor, contact) хранятся в Realtime (MySQL).

```ini
[res_pjsip]
endpoint = realtime,ps_endpoints
auth     = realtime,ps_auths
aor      = realtime,ps_aors
contact  = realtime,ps_contacts
```

---

### res_odbc.conf

Настройка ODBC-пула соединений Asterisk → MySQL.

```ini
[asteriskdb]
dsn          = asteriskdb     # имя DSN из odbc.ini
username     = asterisk_user
password     = asterisk_pass
pre-connect  = yes            # соединение открывается при старте
max_connections = 20
```

---

### odbc.ini

DSN-описание для unixODBC. Указывает драйвер, хост, БД.

```ini
[asteriskdb]
Driver   = MySQL
Server   = 127.0.0.1
Port     = 3306
Database = asterisk_master_db
```

---

### odbcinst.ini

Регистрирует MySQL ODBC-драйвер в системе.

```ini
[MySQL]
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
```

---

### logger.conf

Куда и что пишет Asterisk.

```ini
messages => notice,warning,error   # этот файл читает fail2ban для обнаружения атак
full     => notice,warning,error,debug,verbose
console  => notice,warning,error,verbose
```

---

### rtp.conf

Диапазон UDP-портов для медиа (RTP/SRTP).

```ini
rtpstart = 10000
rtpend   = 15000
```

---

### cdr.conf

Включает запись истории звонков (CDR).

```ini
enable    = yes
unanswered = yes   # записывать и неотвеченные вызовы
```

---

### cdr_odbc.conf

Куда писать CDR — в таблицу `cdr` через ODBC.

```ini
connection = asteriskdb
table      = cdr
```

---

### manager.conf

AMI (Asterisk Manager Interface) — интерфейс управления по TCP.

```ini
enabled  = yes
port     = 5038
bindaddr = 0.0.0.0   # в продакшене рекомендуется 127.0.0.1
```

---

## mysql/

### init.sql

Инициализация БД при первом запуске контейнера.

| Таблица | Назначение |
|---------|------------|
| `ps_endpoints` | параметры абонентов: транспорт, шифрование, SRTP, DTLS |
| `ps_auths` | логин/пароль каждого абонента |
| `ps_aors` | адресные записи: `max_contacts=1` — один активный контакт |
| `ps_contacts` | текущие регистрации (заполняется Asterisk автоматически), `PRIMARY KEY (id)` |
| `extensions` | диалплан: `_4XXX → Dial(PJSIP/${EXTEN})` |
| `cdr` | история звонков |

Абоненты 4000 и 4001 создаются с `transport-udp` — `entrypoint.sh` переключает на `transport-tls` после генерации сертификатов.

---

## nginx/

### Dockerfile

Сборка Nginx с утилитами `openssl` и `apache2-utils` (для `htpasswd`).

---

### entrypoint.sh

Генерирует TLS-инфраструктуру и Basic Auth при первом старте.

| Шаг | Действие |
|-----|----------|
| 1 | Проверяет наличие `pma.crt` **и** `dhparam.pem` (оба обязательны) |
| 2 | Генерирует self-signed CA (`rootCA.crt`) |
| 3 | Генерирует сертификат сайта `pma.crt` (CN=localhost), подписанный rootCA |
| 4 | Генерирует `dhparam.pem` 2048-бит (Forward Secrecy) |
| 5 | Создаёт `.htpasswd` с пользователем `developer` |
| 6 | Запускает `nginx` |

---

### phpmyadmin.conf

Конфигурация виртуального хоста Nginx.

```nginx
server { listen 8090; }        # HTTP → редирект на https://$host:8443
server { listen 8443 ssl; }    # HTTPS
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_dhparam   dhparam.pem;   # Forward Secrecy
  auth_basic    "Restricted";  # Basic Auth (developer/developer123)
  proxy_pass    127.0.0.1:8082 # phpMyAdmin
```

---

## phpmyadmin/

### Dockerfile

Образ phpMyAdmin на Apache. Слушает на порту `8082` (только localhost).

Переменные окружения из `docker-compose.yml`:
- `PMA_HOST=127.0.0.1` — адрес MySQL
- `PMA_USER`, `PMA_PASSWORD` — учётные данные
- `APACHE_PORT=8082`

---

## fail2ban/

### Dockerfile

Устанавливает `fail2ban`, `iptables`, `python3`. Без `python3-systemd` (Ubuntu использует файловый backend).

Loglevel: `NOTICE` — показывает баны, скрывает INFO-спам.

---

### jail.d/defaults.conf

Глобальные параметры для всех jail'ов.

```ini
maxretry  = 4       # 4 неудачных попытки → бан
findtime  = 10m     # окно поиска
bantime   = 10m     # длительность бана
ignoreip  = 127.0.0.1/8 ::1
```

---

### jail.d/defaults-debian.conf

Отключает стандартный `[sshd]` jail из Debian-пакета (он ищет `/var/log/auth.log` по умолчанию и конфликтует с кастомным ssh.conf).

```ini
[sshd]
enabled = false
```

---

### jail.d/ssh.conf

Защита SSH.

```ini
port    = 40000          # нестандартный SSH-порт
backend = polling        # файловый backend (Ubuntu имеет rsyslog)
logpath = /var/log/host/auth.log   # хостовый auth.log, смонтирован как /var/log/host
```

---

### jail.d/asterisk.conf

Защита SIP от брутфорса паролей.

```ini
action  = iptables-allports[protocol=all]   # блокирует все порты (iptables-multiport не поддерживает protocol=all)
logpath = /var/log/asterisk/messages
```

---

### jail.d/phpmyadmin.conf

Два jail'а для phpMyAdmin:

| Jail | Лог | Что ловит |
|------|-----|-----------|
| `phpmyadmin` | `access.log` | ошибки входа phpMyAdmin (`error=1`, `login_failed`) |
| `nginx-http-auth` | `error.log` | неверный Basic Auth пароль (401/403) |

Оба блокируют порты `8090, 8443`.

---

### filter.d/nginx-phpmyadmin.conf

Regex-фильтр для jail'а `phpmyadmin`.

```
failregex: ищет в access.log запросы к /phpmyadmin с ошибками входа
           или HTTP-ответы 401/403
```
