FROM nginx:stable

# openssl — генерация TLS-сертификатов (раздел 4.6)
# apache2-utils — утилита htpasswd для HTTP Basic Auth (раздел 4.7)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssl \
        apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Убираем дефолтный сайт, подключаем phpMyAdmin-конфиг
RUN rm -f /etc/nginx/conf.d/default.conf
COPY phpmyadmin.conf /etc/nginx/conf.d/phpmyadmin.conf

# Entrypoint: генерация сертификатов + .htpasswd + запуск nginx
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
