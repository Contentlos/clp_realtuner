-- =============================================================================
--  Migration 003: Progression, Racing, Police, Insurance
-- =============================================================================

ALTER TABLE `mechanic_skill`
    ADD COLUMN IF NOT EXISTS `specialization` VARCHAR(32) NOT NULL DEFAULT '' AFTER `installs`,
    ADD COLUMN IF NOT EXISTS `tier`           VARCHAR(16) NOT NULL DEFAULT 'lehrling' AFTER `specialization`,
    ADD COLUMN IF NOT EXISTS `exam_passed`    LONGTEXT DEFAULT NULL AFTER `tier`;

CREATE TABLE IF NOT EXISTS `mechanic_certificates` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `identifier`  VARCHAR(64) NOT NULL,
    `kind`        VARCHAR(32) NOT NULL,
    `issued_at`   INT NOT NULL,
    `issuer`      VARCHAR(64),
    INDEX `idx_ident` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vehicle_dyno_runs` (
    `id`        INT AUTO_INCREMENT PRIMARY KEY,
    `vin`       VARCHAR(17) NOT NULL,
    `plate`     VARCHAR(12) NOT NULL,
    `identifier`VARCHAR(64) NOT NULL,
    `type`      VARCHAR(16) NOT NULL, -- 0_100 / quarter / top_speed
    `value_ms`  INT NOT NULL DEFAULT 0,
    `top_kmh`   FLOAT NOT NULL DEFAULT 0,
    `hp_est`    FLOAT NOT NULL DEFAULT 0,
    `points`    LONGTEXT DEFAULT NULL,
    `timestamp` INT NOT NULL,
    INDEX `idx_vin` (`vin`),
    INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vehicle_trip_log` (
    `id`        INT AUTO_INCREMENT PRIMARY KEY,
    `vin`       VARCHAR(17) NOT NULL,
    `plate`     VARCHAR(12) NOT NULL,
    `identifier`VARCHAR(64) NOT NULL,
    `start_ts`  INT NOT NULL,
    `end_ts`    INT NOT NULL,
    `start_pos` LONGTEXT,
    `end_pos`   LONGTEXT,
    `distance`  FLOAT NOT NULL DEFAULT 0,
    `top_kmh`   FLOAT NOT NULL DEFAULT 0,
    `avg_kmh`   FLOAT NOT NULL DEFAULT 0,
    INDEX `idx_vin` (`vin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `insurance_policies` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `plate`       VARCHAR(12) NOT NULL UNIQUE,
    `identifier`  VARCHAR(64) NOT NULL,
    `provider`    VARCHAR(32) DEFAULT 'default',
    `coverage`    VARCHAR(16) NOT NULL DEFAULT 'basic', -- basic / full
    `deductible`  INT NOT NULL DEFAULT 500,
    `sum_insured` INT NOT NULL DEFAULT 10000,
    `starts_at`   INT NOT NULL,
    `expires_at`  INT NOT NULL,
    INDEX `idx_ident` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `insurance_claims` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `policy_id`   INT NOT NULL,
    `plate`       VARCHAR(12) NOT NULL,
    `filed_at`    INT NOT NULL,
    `amount`      INT NOT NULL,
    `status`      VARCHAR(16) NOT NULL DEFAULT 'pending',
    `detail`      LONGTEXT,
    INDEX `idx_policy` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_hcm_migrations` (`id`, `applied_at`) VALUES ('003_progression_racing_police', UNIX_TIMESTAMP())
    ON DUPLICATE KEY UPDATE `applied_at` = UNIX_TIMESTAMP();
