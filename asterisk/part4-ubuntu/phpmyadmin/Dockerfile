FROM phpmyadmin:5

# Раздел 4: phpMyAdmin перенастроен слушать на порту 8082
# (порт 80 занят Nginx-фронтендом).
# Nginx проксирует HTTPS-запросы на localhost:8082.

RUN sed -i 's/Listen 80/Listen 8082/' /etc/apache2/ports.conf \
    && find /etc/apache2/sites-enabled/ -name "*.conf" \
       -exec sed -i 's/\*:80/*:8082/g' {} \;

EXPOSE 8082
