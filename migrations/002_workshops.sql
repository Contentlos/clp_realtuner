-- =============================================================================
--  Migration 002: Workshop Ownership, Stock, Employees, Prices, Customer-Jobs
-- =============================================================================

CREATE TABLE IF NOT EXISTS `mechanic_workshops` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `name`         VARCHAR(64)  NOT NULL,
    `owner`        VARCHAR(64)  DEFAULT NULL,
    `bank`         BIGINT       NOT NULL DEFAULT 0,
    `coords`       LONGTEXT     DEFAULT NULL,
    `tool_tier`    INT          NOT NULL DEFAULT 1,
    `created_at`   INT          NOT NULL DEFAULT 0,
    `updated_at`   INT          NOT NULL DEFAULT 0,
    INDEX `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_workshop_stock` (
    `workshop_id`  INT          NOT NULL,
    `item`         VARCHAR(64)  NOT NULL,
    `amount`       INT          NOT NULL DEFAULT 0,
    `min_stock`    INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`workshop_id`, `item`),
    FOREIGN KEY (`workshop_id`) REFERENCES `mechanic_workshops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_workshop_employees` (
    `workshop_id`  INT          NOT NULL,
    `identifier`   VARCHAR(64)  NOT NULL,
    `role`         VARCHAR(32)  NOT NULL DEFAULT 'employee',
    `perms`        LONGTEXT     DEFAULT NULL,
    PRIMARY KEY (`workshop_id`, `identifier`),
    FOREIGN KEY (`workshop_id`) REFERENCES `mechanic_workshops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_workshop_prices` (
    `workshop_id`  INT          NOT NULL,
    `service`      VARCHAR(64)  NOT NULL,
    `price`        INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`workshop_id`, `service`),
    FOREIGN KEY (`workshop_id`) REFERENCES `mechanic_workshops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_customer_jobs` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `workshop_id` INT          DEFAULT NULL,
    `plate`       VARCHAR(12)  NOT NULL,
    `vin`         VARCHAR(17)  DEFAULT NULL,
    `customer`    VARCHAR(64)  DEFAULT NULL,
    `problem`     VARCHAR(255) DEFAULT NULL,
    `quote`       INT          DEFAULT 0,
    `status`      VARCHAR(16)  NOT NULL DEFAULT 'open',
    `assigned`    VARCHAR(64)  DEFAULT NULL,
    `rating`      INT          DEFAULT 0,
    `tip`         INT          DEFAULT 0,
    `created_at`  INT          NOT NULL DEFAULT 0,
    `closed_at`   INT          DEFAULT NULL,
    INDEX `idx_status` (`status`),
    INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_hcm_migrations` (`id`, `applied_at`) VALUES ('002_workshops', UNIX_TIMESTAMP())
    ON DUPLICATE KEY UPDATE `applied_at` = UNIX_TIMESTAMP();
