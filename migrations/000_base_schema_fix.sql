-- =============================================================================
--  clp_realtuner - Migration 000: Basis-Schema-Guard
--  Faengt Faelle ab, in denen `vehicles_data` bereits von einem anderen Script
--  existiert und nicht alle Kern-Spalten besitzt. Idempotent.
-- =============================================================================

ALTER TABLE `vehicles_data`
    ADD COLUMN IF NOT EXISTS `vin`                 VARCHAR(24)  NOT NULL DEFAULT '' AFTER `plate`,
    ADD COLUMN IF NOT EXISTS `model`               VARCHAR(64)  DEFAULT NULL       AFTER `vin`,
    ADD COLUMN IF NOT EXISTS `engine_health`       DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `model`,
    ADD COLUMN IF NOT EXISTS `transmission_health` DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `engine_health`,
    ADD COLUMN IF NOT EXISTS `brake_health`        DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `transmission_health`,
    ADD COLUMN IF NOT EXISTS `turbo_health`        DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `brake_health`,
    ADD COLUMN IF NOT EXISTS `suspension_health`   DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `turbo_health`,
    ADD COLUMN IF NOT EXISTS `ecu_state`           JSON         NULL               AFTER `suspension_health`,
    ADD COLUMN IF NOT EXISTS `installed_parts`     JSON         NULL               AFTER `ecu_state`,
    ADD COLUMN IF NOT EXISTS `tuning_data`         JSON         NULL               AFTER `installed_parts`,
    ADD COLUMN IF NOT EXISTS `last_service`        BIGINT       NOT NULL DEFAULT 0 AFTER `tuning_data`,
    ADD COLUMN IF NOT EXISTS `odometer`            BIGINT       NOT NULL DEFAULT 0 AFTER `last_service`,
    ADD COLUMN IF NOT EXISTS `paint_quality`       DECIMAL(5,2) NOT NULL DEFAULT 100 AFTER `odometer`,
    ADD COLUMN IF NOT EXISTS `updated_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Existierende Reihen ohne VIN mit einem Fallback versehen, damit UNIQUE nicht
-- auf Default='' kollidiert. Erzeugt deterministische Platzhalter-VINs, die
-- anschliessend ueber /hcmadmin setvin korrigiert werden koennen.
UPDATE `vehicles_data`
   SET `vin` = CONCAT('RT', UPPER(SUBSTRING(MD5(plate), 1, 15)))
 WHERE `vin` = '' OR `vin` IS NULL;

ALTER TABLE `vehicles_data`
    ADD UNIQUE INDEX IF NOT EXISTS `vin_unique` (`vin`),
    ADD INDEX        IF NOT EXISTS `idx_last_service` (`last_service`);

INSERT INTO `_hcm_migrations` (`id`, `applied_at`) VALUES ('000_base_schema_fix', UNIX_TIMESTAMP())
    ON DUPLICATE KEY UPDATE `applied_at` = UNIX_TIMESTAMP();
