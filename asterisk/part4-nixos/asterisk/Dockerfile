FROM andrius/asterisk:18

USER root

# Debian bookworm sources
RUN cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        unixodbc \
        odbcinst \
        odbc-mariadb \
        openssl \
        default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# ODBC
COPY odbc.ini     /etc/odbc.ini
COPY odbcinst.ini /etc/odbcinst.ini

# Asterisk configs
COPY extensions.conf  /etc/asterisk/extensions.conf
COPY pjsip.conf       /etc/asterisk/pjsip.conf
COPY res_odbc.conf    /etc/asterisk/res_odbc.conf
COPY rtp.conf         /etc/asterisk/rtp.conf
COPY sorcery.conf     /etc/asterisk/sorcery.conf
COPY extconfig.conf   /etc/asterisk/extconfig.conf
COPY cdr.conf         /etc/asterisk/cdr.conf
COPY cdr_odbc.conf    /etc/asterisk/cdr_odbc.conf
COPY manager.conf     /etc/asterisk/manager.conf
COPY logger.conf      /etc/asterisk/logger.conf

# Включаем необходимые модули
RUN echo "load => res_odbc.so"   >> /etc/asterisk/modules.conf && \
    echo "load => cdr_odbc.so"   >> /etc/asterisk/modules.conf && \
    echo "load => res_crypto.so" >> /etc/asterisk/modules.conf && \
    echo "load => res_srtp.so"   >> /etc/asterisk/modules.conf

# Entrypoint: генерация сертификатов + обновление БД + запуск Asterisk
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Директория для ключей (будет перекрыта volume)
RUN mkdir -p /etc/asterisk/keys && chown asterisk:asterisk /etc/asterisk/keys

# SIP/UDP, SIP/TCP, SIPS/TLS, IAX2, RTP, AMI
EXPOSE 5060/udp 5060/tcp 5061/tcp 4569/udp 10000-15000/udp 5038/tcp

CMD ["/entrypoint.sh"]
