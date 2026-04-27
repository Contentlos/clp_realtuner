-- =============================================================================
-- Migration 004: Portfolio + Tutorial-Flag (Batch 6)
-- =============================================================================

ALTER TABLE `mechanic_skill`
    ADD COLUMN IF NOT EXISTS `tutorial_done`  TINYINT(1)  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `spec_engine`    INT         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `spec_brakes`    INT         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `spec_paint`     INT         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `spec_electrics` INT         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `spec_chassis`   INT         NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `mechanic_portfolio` (
    `id`          BIGINT      NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(64) NOT NULL,
    `plate`       VARCHAR(16) NOT NULL,
    `vin`         VARCHAR(24) DEFAULT NULL,
    `action`      VARCHAR(64) NOT NULL,
    `detail`      TEXT        NULL,
    `timestamp`   BIGINT      NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_hcm_migrations` (`id`, `applied_at`) VALUES ('004_portfolio', UNIX_TIMESTAMP())
    ON DUPLICATE KEY UPDATE `applied_at` = UNIX_TIMESTAMP();
