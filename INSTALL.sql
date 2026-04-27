-- =============================================================================
--  clp_hardcore_mechanic - SQL Schema
--  Voraussetzung: MariaDB 10.4+ / MySQL 8+
-- =============================================================================

CREATE TABLE IF NOT EXISTS `vehicles_data` (
    `plate`                VARCHAR(16)  NOT NULL,
    `vin`                  VARCHAR(24)  NOT NULL,
    `model`                VARCHAR(64)  DEFAULT NULL,
    `engine_health`        DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `transmission_health`  DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `brake_health`         DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `turbo_health`         DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `suspension_health`    DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `ecu_state`            JSON         NULL,
    `installed_parts`      JSON         NULL,
    `tuning_data`          JSON         NULL,
    `last_service`         BIGINT       NOT NULL DEFAULT 0,
    `odometer`             BIGINT       NOT NULL DEFAULT 0,
    `paint_quality`        DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    `updated_at`           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`),
    UNIQUE KEY `vin_unique` (`vin`),
    KEY `idx_last_service` (`last_service`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_logs` (
    `id`         BIGINT       NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL,
    `charname`   VARCHAR(64)  DEFAULT NULL,
    `action`     VARCHAR(64)  NOT NULL,
    `plate`      VARCHAR(16)  DEFAULT NULL,
    `vin`        VARCHAR(24)  DEFAULT NULL,
    `detail`     JSON         NULL,
    `timestamp`  BIGINT       NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_plate` (`plate`),
    KEY `idx_time` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_skill` (
    `identifier` VARCHAR(64) NOT NULL,
    `xp`         INT         NOT NULL DEFAULT 0,
    `level`      INT         NOT NULL DEFAULT 1,
    `repairs`    INT         NOT NULL DEFAULT 0,
    `installs`   INT         NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
