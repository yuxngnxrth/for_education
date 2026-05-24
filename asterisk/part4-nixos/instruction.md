# Проверка работоспособности — part4

Все сервисы работают в `network_mode: host`, поэтому команды выполняются прямо с хоста.

---

## 0. Быстрый старт

```bash
cd part4
docker compose up --build -d
docker compose ps
```

Ожидаемый результат — все контейнеры `Up`, ни один не в состоянии `(restarting)`:

```
NAME                    STATUS
asterisk-mysql-secure   Up
asterisk-secure         Up (healthy)
phpmyadmin-secure       Up
nginx-secure            Up
fail2ban-secure         Up
```

---

## 1. MySQL

### Подключение и схема

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db; DESCRIBE ps_endpoints;"
```

### Проверить TLS-параметры абонентов

```bash
docker exec asterisk-mysql-secure \
  mysql -u asterisk_user -pasterisk_pass \
  -e "USE asterisk_master_db;
      SELECT id, transport, media_encryption, dtls_cert_file
      FROM ps_endpoints;"
```

Ожидаемый результат (заполняется `entrypoint.sh` Asterisk при первом старте):

```
id    transport      media_encryption  dtls_cert_file
4000  transport-tls  sdes              /etc/asterisk/keys/client4000.crt
4001  transport-tls  sdes              /etc/asterisk/keys/client4001.crt
```

Если поля `NULL` — Asterisk ещё не завершил инициализацию. Подожди и проверь:

```bash
docker compose logs -f asterisk
```

---

## 2. Asterisk

### ODBC-соединение с MySQL

```bash
docker exec asterisk-secure asterisk -rx 'odbc show'
```

Ожидаемый результат:

```
ODBC DSN Settings
  Name:   asteriskdb
    Number of active connections: 1 (out of 20)
```

Если `0 active connections` — MySQL не поднялся или неверные учётные данные в `res_odbc.conf`.

### Транспорты PJSIP

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show transports'
```

Ожидаемый результат:

```
Transport:  transport-tls    tls    0    0    0.0.0.0:5061
Transport:  transport-udp    udp    0    0    0.0.0.0:5060
```

### Абоненты

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show endpoints'
```

Ожидаемый результат (без клиента — `Unavailable`, после регистрации — `Available`):

```
Endpoint:  4000    Unavailable    0 of inf
  Transport:  transport-tls    tls    0.0.0.0:5061

Endpoint:  4001    Unavailable    0 of inf
  Transport:  transport-tls    tls    0.0.0.0:5061
```

### Активные регистрации (после подключения клиента)

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'
```

### Сертификаты

```bash
# Список файлов — должны быть ca.crt, asterisk.crt, client4000.pem, client4001.pem
docker exec asterisk-secure ls -la /etc/asterisk/keys/

# Срок действия серверного сертификата
docker exec asterisk-secure \
  openssl x509 -noout -subject -issuer -dates \
  -in /etc/asterisk/keys/asterisk.crt

# Проверить цепочку: клиентский сертификат подписан CA
docker exec asterisk-secure \
  openssl verify -CAfile /etc/asterisk/keys/ca.crt \
                 /etc/asterisk/keys/client4000.crt
```

Ожидаемый результат последней команды: `client4000.crt: OK`

### TLS-рукопожатие на порту 5061

```bash
openssl s_client -connect 127.0.0.1:5061 \
  -CAfile <(docker exec asterisk-secure cat /etc/asterisk/keys/ca.crt) 2>&1 \
  | grep -E 'CONNECTED|subject|issuer|Protocol|Verify return'
```

Ожидаемый результат:

```
CONNECTED(00000003)
subject=CN=pbx.example.com ...
issuer=CN=My-CA ...
Protocol: TLSv1.3
Verify return code: 0 (ok)
```

---

## 3. Nginx

### HTTP → HTTPS редирект

```bash
curl -v http://localhost:8090/ 2>&1 | grep -E 'HTTP|Location'
```

Ожидаемый результат:

```
< HTTP/1.1 301 Moved Permanently
< Location: https://localhost:8443/
```

### TLS на порту 443

```bash
openssl s_client -connect localhost:8443 \
  -CAfile <(docker exec nginx-secure cat /etc/nginx/ssl/rootCA.crt) 2>&1 \
  | grep -E 'CONNECTED|subject|Protocol|Verify return'
```

Ожидаемый результат:

```
CONNECTED(00000003)
subject=CN=localhost ...
Protocol: TLSv1.3
Verify return code: 0 (ok)
```

### phpMyAdmin через Basic Auth

```bash
# Учётные данные по умолчанию: developer / developer123
curl -sk -u developer:developer123 https://localhost:8443/ | grep -i '<title>'
```

Ожидаемый результат: `<title>phpMyAdmin</title>`

```bash
# Проверить что без пароля возвращает 401
curl -sk -o /dev/null -w "%{http_code}" https://localhost:8443/
```

Ожидаемый результат: `401`

### Конфигурация Nginx

```bash
docker exec nginx-secure nginx -t
```

Ожидаемый результат: `syntax is ok` + `test is successful`

---

## 4. fail2ban

### Список активных jail'ов

```bash
docker exec fail2ban-secure fail2ban-client status
```

Ожидаемый результат:

```
Number of jail: 4
Jail list: asterisk, nginx-http-auth, phpmyadmin, ssh
```

### Детали каждого jail'а

```bash
docker exec fail2ban-secure fail2ban-client status ssh
docker exec fail2ban-secure fail2ban-client status asterisk
docker exec fail2ban-secure fail2ban-client status phpmyadmin
docker exec fail2ban-secure fail2ban-client status nginx-http-auth
```

Смотреть на `Currently banned` и `Total banned`.

### Симуляция бана (тест Asterisk jail)

```bash
# Добавить IP вручную
docker exec fail2ban-secure fail2ban-client set asterisk banip 192.168.1.200

# Убедиться что появился в iptables
docker exec fail2ban-secure iptables -L -n | grep 192.168.1.200

# Разбанить
docker exec fail2ban-secure fail2ban-client set asterisk unbanip 192.168.1.200
```

---

## 5. Настройка SIP-клиента — PortSIP Softphone

Рекомендуемый клиент: **PortSIP Softphone** (бесплатный, Android и iOS).

| Параметр | Значение |
|----------|----------|
| SIP-сервер | `<IP машины>` |
| Порт | `5061` |
| Транспорт | `TLS` |
| Шифрование медиа | `SRTP` |
| Логин / Пароль | `4000` / `123456` или `4001` / `123456` |

**Шаг 1 — добавить аккаунт в PortSIP**

1. Открыть PortSIP → **Add Account**
2. Username: `4000`, Password: `123456`
3. Domain: `<IP машины>:5061`
4. **Transport: TLS**
5. Сохранить

**Шаг 2 — включить SRTP**

**Settings → Preferences → RTP → SRTP → Prefer**

**Шаг 3 — отключить проверку сертификата**

В настройках PortSIP отключить верификацию TLS-сертификата (сервер использует самоподписанный CA).

После регистрации проверить:

```bash
docker exec asterisk-secure asterisk -rx 'pjsip show contacts'
```

---

## 6. Полная диагностика одной командой

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

---

## 7. Логи при проблемах

```bash
# Asterisk (инициализация PKI, подключения)
docker compose logs -f asterisk

# Nginx (TLS-ошибки, доступ)
docker compose logs -f nginx
docker exec nginx-secure tail -f /var/log/nginx/error.log

# fail2ban (баны, ошибки jail)
docker compose logs -f fail2ban

# MySQL
docker compose logs -f mysql
```
