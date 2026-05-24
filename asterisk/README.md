# Asterisk в Docker

## Описание

Документация по настройке Asterisk в Docker-контейнерах. Разделена на части:

- **Часть 1-2**: Базовая установка и настройка Asterisk, PJSIP, Dialplan, звуковые файлы, подключение клиентов.
- **Часть 3**: Realtime конфигурация, MySQL, ODBC, IAX2 транк между серверами, перенос конфигурации в базу данных.
- **Часть 4**: Безопасность и шифрование — TLS/SRTP, PKI, Nginx HTTPS, fail2ban. Доступна в вариантах для NixOS и Ubuntu 22.04.

---

## Структура проекта

```
Asterisk/
├── part1-2/          # Часть 1-2: Базовая настройка Asterisk
├── part3/            # Часть 3: Realtime конфигурация и IAX2
├── part4-nixos/      # Часть 4: Безопасность и шифрование (NixOS)
└── part4-ubuntu/     # Часть 4: Безопасность и шифрование (Ubuntu 22.04)
```
---

## Документация

- [Часть 1-2: Базовая настройка Asterisk](./part1-2/README.md)
- [Часть 3: Realtime конфигурация и IAX2](./part3/README.md)
- [Часть 4: Безопасность и шифрование (NixOS)](./part4-nixos/README.md)
- [Часть 4: Безопасность и шифрование (Ubuntu 22.04)](./part4-ubuntu/README.md)

---

## Краткое описание частей

### Часть 1-2
- Запуск Asterisk в Docker
- Настройка PJSIP (клиенты 1000, 2000)
- Настройка Dialplan
- Подключение звуковых файлов
- Подключение SIP клиентов
- Dockerfile и Docker Compose

### Часть 3
- Установка MySQL
- Настройка ODBC
- Создание баз данных: `asterisk_master_db` и `asterisk_slave_db`
- Перенос конфигурации PJSIP в БД (номера 4000, 4001 на master; 5000, 5001, 5002 на slave)
- Перенос Dialplan в БД
- Настройка IAX2 транка между серверами
- Перенос IAX2 в БД
- Запуск всех сервисов
- Проверка работы и тестовые звонки

### Часть 4
- Генерация PKI: самоподписанный CA, серверный сертификат с SAN, клиентские сертификаты
- TLS-транспорт (порт 5061) для шифрования SIP-сигнализации
- SRTP (SDES) для шифрования голосового трафика
- Nginx перед phpMyAdmin: HTTPS на порту 8443, Basic Auth, Forward Secrecy (DH 2048)
- fail2ban: защита SSH, SIP и phpMyAdmin от брутфорса через iptables
- Два варианта: **NixOS** (backend=systemd, journald) и **Ubuntu 22.04** (backend=polling, auth.log)

---

## Требования

- Docker
- Docker Compose
- Linux (рекомендуется Ubuntu)

---

## Быстрый старт

### Часть 1-2
```bash
cd part1-2
docker build -t my-asterisk:1.0 .
docker compose up -d
```

### Часть 3
```bash
cd part3/mysql
docker compose up -d

cd ../master-asterisk
docker build -t master-asterisk:1.0 .
docker compose up -d

cd ../slave-asterisk
docker build -t slave-asterisk:1.0 .
docker compose up -d
```

### Часть 4 (NixOS)
```bash
cd part4-nixos
docker compose up --build -d
```

### Часть 4 (Ubuntu 22.04)
```bash
cd part4-ubuntu
docker compose up --build -d
```

---

## Контакты

При возникновении вопросов обращайтесь к документации в соответствующих разделах.