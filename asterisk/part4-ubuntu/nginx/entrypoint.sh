#!/bin/bash
# 1. Создаёт PKI-сертификаты для HTTPS
# 2. Создаёт файл .htpasswd для Basic Auth
# 3. Запускает nginx

set -e

SSL_DIR="/etc/nginx/ssl"
HTPASSWD="/etc/nginx/conf.d/.htpasswd"

mkdir -p "$SSL_DIR"

# 1. Генерация TLS-сертификатов
if [ ! -f "$SSL_DIR/pma.crt" ] || [ ! -f "$SSL_DIR/dhparam.pem" ]; then
    echo "[nginx-entrypoint] Generating TLS certificates..."

    # Корневой CA
    openssl genrsa -out "$SSL_DIR/rootCA.key" 4096 2>/dev/null
    openssl req -new -x509 \
        -key "$SSL_DIR/rootCA.key" -sha256 -days 10000 \
        -out "$SSL_DIR/rootCA.crt" \
        -subj '/C=RU/ST=Moscow/L=Zelenograd/O=MIET/OU=TCS/CN=voip.local CA'

    # Ключ и CSR для сайта phpMyAdmin
    openssl genrsa -out "$SSL_DIR/pma.key" 2048 2>/dev/null
    openssl req -new \
        -key "$SSL_DIR/pma.key" \
        -out "$SSL_DIR/pma.csr" \
        -subj '/C=RU/ST=Moscow/L=Zelenograd/O=MIET/OU=TCS/CN=localhost'

    # Подписываем корневым CA
    openssl x509 -req \
        -in "$SSL_DIR/pma.csr" -days 365 \
        -CA "$SSL_DIR/rootCA.crt" -CAkey "$SSL_DIR/rootCA.key" \
        -CAcreateserial -out "$SSL_DIR/pma.crt"

    # Параметры DH для Forward Secrecy
    echo "[nginx-entrypoint] Generating DH parameters (2048-bit)..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048 2>/dev/null

    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR/dhparam.pem"
    echo "[nginx-entrypoint] TLS certificates ready"
else
    echo "[nginx-entrypoint] TLS certificates already exist, skipping"
fi

# 2. HTTP Basic Auth
if [ ! -f "$HTPASSWD" ]; then
    echo "[nginx-entrypoint] Creating htpasswd..."
    # Логин: developer  Пароль: developer123  (замените в проде!)
    htpasswd -cb "$HTPASSWD" developer developer123
    echo "[nginx-entrypoint] htpasswd created (user: developer / pass: developer123)"
fi

# 3. Запуск Nginx
echo "[nginx-entrypoint] Starting nginx..."
exec nginx -g "daemon off;"
