FROM debian:bookworm-slim

# Раздел 4.3: fail2ban защищает SSH, Asterisk и phpMyAdmin
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        fail2ban \
        iptables \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# Конфиги jail.d и filter.d
COPY jail.d/   /etc/fail2ban/jail.d/
COPY filter.d/ /etc/fail2ban/filter.d/

# Создаём директории для монтируемых логов
RUN mkdir -p /var/log/asterisk /var/log/nginx

CMD ["fail2ban-server", "-f", "--logtarget", "STDERR", "--loglevel", "NOTICE"]
