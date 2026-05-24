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
COPY manager.conf /etc/asterisk/manager.conf
COPY sounds/. /var/lib/asterisk/sounds/

RUN  echo "load => res_odbc.so" >> /etc/asterisk/modules.conf && \
     echo "load => cdr_odbc.so" >> /etc/asterisk/modules.conf
	

# Открываем порты
EXPOSE 5061/udp 5061/tcp 4570/udp 15001-20000/udp 5039/tcp

# Запускаем Asterisk
CMD ["asterisk", "-f"]
