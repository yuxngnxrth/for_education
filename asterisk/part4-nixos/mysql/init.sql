-- =====================================================
-- Раздел 4: инициализация БД с поддержкой TLS-параметров
-- База данных: asterisk_master_db
-- =====================================================

DROP DATABASE IF EXISTS asterisk_master_db;

CREATE DATABASE asterisk_master_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE asterisk_master_db;

-- =====================================================
-- ps_aors
-- =====================================================
CREATE TABLE `ps_aors` (
  `id`              varchar(40)  NOT NULL,
  `max_contacts`    int(11)      DEFAULT NULL,
  `remove_existing` varchar(3)   DEFAULT NULL,
  `contact`         varchar(255) DEFAULT NULL,
  `qualify_frequency` int(11)    DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- ps_auths
-- =====================================================
CREATE TABLE `ps_auths` (
  `id`        varchar(40) NOT NULL,
  `auth_type` varchar(40) DEFAULT NULL,
  `username`  varchar(40) DEFAULT NULL,
  `password`  varchar(80) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- ps_endpoints (расширена TLS/SRTP полями — раздел 4.8)
-- Поля dtls_cert_file / dtls_private_key заполняются
-- entrypoint.sh после генерации сертификатов.
-- =====================================================
CREATE TABLE `ps_endpoints` (
  `id`               varchar(40)  NOT NULL,
  `transport`        varchar(40)  DEFAULT NULL,
  `aors`             varchar(40)  DEFAULT NULL,
  `auth`             varchar(40)  DEFAULT NULL,
  `context`          varchar(40)  DEFAULT NULL,
  `disallow`         varchar(200) DEFAULT NULL,
  `allow`            varchar(200) DEFAULT NULL,
  `direct_media`     varchar(3)   DEFAULT NULL,
  `rtp_symmetric`    varchar(3)   DEFAULT NULL,
  `force_rport`      varchar(3)   DEFAULT NULL,
  `rewrite_contact`  varchar(3)   DEFAULT NULL,
  `mailboxes`        varchar(255) DEFAULT NULL,
  -- TLS/SRTP параметры (раздел 4.8)
  `media_encryption` varchar(20)  DEFAULT NULL,
  `dtls_verify`      varchar(20)  DEFAULT NULL,
  `dtls_cert_file`   varchar(200) DEFAULT NULL,
  `dtls_private_key` varchar(200) DEFAULT NULL,
  `dtls_ca_file`     varchar(200) DEFAULT NULL,
  `dtls_setup`       varchar(20)  DEFAULT NULL,
  `dtls_rekey`       int(11)      DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- ps_contacts
-- =====================================================
CREATE TABLE `ps_contacts` (
  `id`                  varchar(255) NOT NULL,
  `uri`                 varchar(255) DEFAULT NULL,
  `expiration_time`     bigint(20)   DEFAULT NULL,
  `qualify_frequency`   int(11)      DEFAULT NULL,
  `outbound_proxy`      varchar(40)  DEFAULT NULL,
  `path`                text         DEFAULT NULL,
  `user_agent`          varchar(255) DEFAULT NULL,
  `qualify_timeout`     float        DEFAULT NULL,
  `reg_server`          varchar(20)  DEFAULT NULL,
  `authenticate_qualify` enum('yes','no') DEFAULT NULL,
  `via_addr`            varchar(40)  DEFAULT NULL,
  `via_port`            int(11)      DEFAULT NULL,
  `call_id`             varchar(255) DEFAULT NULL,
  `endpoint`            varchar(40)  DEFAULT NULL,
  `prune_on_boot`       enum('yes','no') DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- CDR
-- =====================================================
CREATE TABLE `cdr` (
  `id`          int(11)      NOT NULL AUTO_INCREMENT,
  `calldate`    datetime     DEFAULT NULL,
  `clid`        varchar(80)  DEFAULT NULL,
  `src`         varchar(80)  DEFAULT NULL,
  `dst`         varchar(80)  DEFAULT NULL,
  `dcontext`    varchar(80)  DEFAULT NULL,
  `channel`     varchar(80)  DEFAULT NULL,
  `dstchannel`  varchar(80)  DEFAULT NULL,
  `lastapp`     varchar(80)  DEFAULT NULL,
  `lastdata`    varchar(80)  DEFAULT NULL,
  `duration`    int(11)      DEFAULT NULL,
  `billsec`     int(11)      DEFAULT NULL,
  `disposition` varchar(45)  DEFAULT NULL,
  `amaflags`    varchar(45)  DEFAULT NULL,
  `accountcode` varchar(20)  DEFAULT NULL,
  `uniqueid`    varchar(32)  DEFAULT NULL,
  `userfield`   varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- dialplan (extensions)
-- =====================================================
CREATE TABLE `extensions` (
  `id`       int(11)     NOT NULL AUTO_INCREMENT,
  `context`  varchar(80) NOT NULL,
  `exten`    varchar(80) NOT NULL,
  `priority` int(11)     NOT NULL,
  `app`      varchar(80) NOT NULL,
  `appdata`  varchar(255) DEFAULT NULL,
  `pattern`  varchar(1)  DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_exten` (`context`, `exten`, `priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_extensions_context ON extensions(context);
CREATE INDEX idx_extensions_exten   ON extensions(exten);
CREATE INDEX idx_cdr_calldate       ON cdr(calldate);
CREATE INDEX idx_cdr_src            ON cdr(src);
CREATE INDEX idx_cdr_dst            ON cdr(dst);

-- =====================================================
-- Данные: dialplan
-- =====================================================
INSERT INTO `extensions` (`context`, `exten`, `priority`, `app`, `appdata`) VALUES
('default', '_4XXX', 1, 'Dial', 'PJSIP/${EXTEN}'),
('outcall', '_4XXX', 1, 'Dial', 'PJSIP/${EXTEN}');

-- =====================================================
-- Данные: абоненты 4000, 4001
-- transport изначально udp; entrypoint.sh переключит на tls
-- после генерации сертификатов.
-- =====================================================
INSERT INTO `ps_aors` (`id`, `max_contacts`) VALUES
('4000', 1),
('4001', 1);

INSERT INTO `ps_auths` (`id`, `auth_type`, `username`, `password`) VALUES
('4000', 'userpass', '4000', '123456'),
('4001', 'userpass', '4001', '123456');

INSERT INTO `ps_endpoints`
    (`id`, `transport`, `aors`, `auth`, `context`, `disallow`, `allow`, `direct_media`)
VALUES
('4000', 'transport-udp', '4000', '4000', 'default', 'all', 'alaw,ulaw', '0'),
('4001', 'transport-udp', '4001', '4001', 'default', 'all', 'alaw,ulaw', '0');

-- =====================================================
-- Права доступа
-- =====================================================
CREATE USER IF NOT EXISTS 'asterisk_user'@'%'         IDENTIFIED BY 'asterisk_pass';
CREATE USER IF NOT EXISTS 'asterisk_user'@'localhost'  IDENTIFIED BY 'asterisk_pass';

GRANT ALL PRIVILEGES ON asterisk_master_db.* TO 'asterisk_user'@'%';
GRANT ALL PRIVILEGES ON asterisk_master_db.* TO 'asterisk_user'@'localhost';

FLUSH PRIVILEGES;
