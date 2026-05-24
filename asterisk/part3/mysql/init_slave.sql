-- =====================================================
-- Удалить базу если существует
-- =====================================================
DROP DATABASE IF EXISTS asterisk_slave_db;

-- =====================================================
-- Создать базу заново
-- =====================================================
CREATE DATABASE asterisk_slave_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- Использовать базу
-- =====================================================
USE asterisk_slave_db;

-- =====================================================
-- Таблица ps_aors
-- =====================================================
CREATE TABLE `ps_aors` (
  `id` varchar(40) NOT NULL,
  `max_contacts` int(11) DEFAULT NULL,
  `remove_existing` varchar(3) DEFAULT NULL,
  `contact` varchar(255) DEFAULT NULL,
  `qualify_frequency` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Таблица ps_auths
-- =====================================================
CREATE TABLE `ps_auths` (
  `id` varchar(40) NOT NULL,
  `auth_type` varchar(40) DEFAULT NULL,
  `username` varchar(40) DEFAULT NULL,
  `password` varchar(80) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Таблица ps_endpoints
-- =====================================================
CREATE TABLE `ps_endpoints` (
  `id` varchar(40) NOT NULL,
  `transport` varchar(40) DEFAULT NULL,
  `aors` varchar(40) DEFAULT NULL,
  `auth` varchar(40) DEFAULT NULL,
  `context` varchar(40) DEFAULT NULL,
  `disallow` varchar(200) DEFAULT NULL,
  `allow` varchar(200) DEFAULT NULL,
  `direct_media` varchar(3) DEFAULT NULL,
  `rtp_symmetric` varchar(3) DEFAULT NULL,
  `force_rport` varchar(3) DEFAULT NULL,
  `rewrite_contact` varchar(3) DEFAULT NULL,
  `mailboxes` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Таблица cdr (Call Detail Records)
-- =====================================================
CREATE TABLE `cdr` (
  `calldate` datetime DEFAULT NULL,
  `clid` varchar(80) DEFAULT NULL,
  `src` varchar(80) DEFAULT NULL,
  `dst` varchar(80) DEFAULT NULL,
  `dcontext` varchar(80) DEFAULT NULL,
  `channel` varchar(80) DEFAULT NULL,
  `dstchannel` varchar(80) DEFAULT NULL,
  `lastapp` varchar(80) DEFAULT NULL,
  `lastdata` varchar(80) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL,
  `billsec` int(11) DEFAULT NULL,
  `disposition` varchar(45) DEFAULT NULL,
  `amaflags` varchar(45) DEFAULT NULL,
  `accountcode` varchar(20) DEFAULT NULL,
  `uniqueid` varchar(32) DEFAULT NULL,
  `userfield` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Таблица extensions (dialplan)
-- =====================================================
CREATE TABLE `extensions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `context` varchar(80) NOT NULL,
  `exten` varchar(80) NOT NULL,
  `priority` int(11) NOT NULL,
  `app` varchar(80) NOT NULL,
  `appdata` varchar(255) DEFAULT NULL,
  `pattern` varchar(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_exten` (`context`,`exten`,`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Таблица iaxfriends
-- =====================================================
CREATE TABLE `iaxfriends` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(80) NOT NULL,
  `type` varchar(6) NOT NULL,
  `secret` varchar(80) DEFAULT NULL,
  `context` varchar(80) DEFAULT NULL,
  `host` varchar(40) DEFAULT NULL,
  `trunk` varchar(4) DEFAULT NULL,
  `auth` varchar(10) DEFAULT NULL,
  `qualify` varchar(10) DEFAULT NULL,
  `disallow` varchar(200) DEFAULT NULL,
  `allow` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Индексы для оптимизации
-- =====================================================
CREATE INDEX idx_extensions_context ON extensions(context);
CREATE INDEX idx_extensions_exten ON extensions(exten);
CREATE INDEX idx_cdr_calldate ON cdr(calldate);
CREATE INDEX idx_cdr_src ON cdr(src);
CREATE INDEX idx_cdr_dst ON cdr(dst);

-- =====================================================
-- Вставка данных для extensions
-- =====================================================
INSERT INTO `extensions` (`context`, `exten`, `priority`, `app`, `appdata`) VALUES
('default', '_4XXX', 1, 'Dial', 'IAX2/iaxuser1:secret1@127.0.0.1:4569/${EXTEN}'),
('default', '_5XXX', 1, 'Dial', 'PJSIP/${EXTEN}'),
('outcall', '_5XXX', 1, 'Dial', 'PJSIP/${EXTEN}');

-- =====================================================
-- Вставка данных для iaxfriends
-- =====================================================
INSERT INTO `iaxfriends` (`name`, `type`, `secret`, `context`, `host`, `trunk`, `auth`, `qualify`, `disallow`, `allow`) VALUES
('iaxuser2', 'friend', 'secret2', 'outcall', 'dynamic', 'yes', 'md5', 'yes', 'all', 'alaw,ulaw');

-- =====================================================
-- Вставка данных для ps_aors
-- =====================================================
INSERT INTO `ps_aors` (`id`, `max_contacts`) VALUES
('5000', 1),
('5001', 1),
('5002', 1);

-- =====================================================
-- Вставка данных для ps_auths
-- =====================================================
INSERT INTO `ps_auths` (`id`, `auth_type`, `username`, `password`) VALUES
('5000', 'userpass', '5000', '123456'),
('5001', 'userpass', '5001', '123456'),
('5002', 'userpass', '5002', '123456');

-- =====================================================
-- Вставка данных для ps_endpoints
-- =====================================================
INSERT INTO `ps_endpoints` (`id`, `transport`, `aors`, `auth`, `context`, `disallow`, `allow`, `direct_media`) VALUES
('5000', 'transport-udp', '5000', '5000', 'default', 'all', 'alaw,ulaw', '0'),
('5001', 'transport-udp', '5001', '5001', 'default', 'all', 'alaw,ulaw', '0'),
('5002', 'transport-udp', '5002', '5002', 'default', 'all', 'alaw,ulaw', '0');

-- =====================================================
-- Права доступа для пользователя asterisk_user
-- =====================================================
-- Создать пользователя если не существует
CREATE USER IF NOT EXISTS 'asterisk_user'@'%' IDENTIFIED BY 'asterisk_pass';
CREATE USER IF NOT EXISTS 'asterisk_user'@'localhost' IDENTIFIED BY 'asterisk_pass';

-- Дать полные права на базу asterisk_slave_db
GRANT ALL PRIVILEGES ON asterisk_slave_db.* TO 'asterisk_user'@'%';
GRANT ALL PRIVILEGES ON asterisk_slave_db.* TO 'asterisk_user'@'localhost';

-- Дать права на чтение/запись CDR таблицы
GRANT SELECT, INSERT, UPDATE, DELETE ON asterisk_slave_db.cdr TO 'asterisk_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON asterisk_slave_db.cdr TO 'asterisk_user'@'localhost';

-- Применить права
FLUSH PRIVILEGES;

-- =====================================================
-- Проверка прав
-- =====================================================
SELECT '=== USER PRIVILEGES ===' AS '';
SHOW GRANTS FOR 'asterisk_user'@'%';

-- =====================================================
-- Проверка данных
-- =====================================================
SELECT '=== EXTENSIONS ===' AS '';
SELECT * FROM extensions;
SELECT '=== IAXFRIENDS ===' AS '';
SELECT * FROM iaxfriends;
SELECT '=== PS_ENDPOINTS ===' AS '';
SELECT * FROM ps_endpoints;