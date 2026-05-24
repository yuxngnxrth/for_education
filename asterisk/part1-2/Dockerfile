FROM andrius/asterisk:18

# Копируем конфигурационные файлы
COPY extensions.conf /etc/asterisk/extensions.conf
COPY pjsip.conf /etc/asterisk/pjsip.conf
COPY sounds/. /var/lib/asterisk/sounds/

# Открываем порты
EXPOSE 5060/udp 5060/tcp 10000-20000/udp

# Запускаем Asterisk
CMD ["asterisk", "-f"]
