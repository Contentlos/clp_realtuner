-- =============================================================================
--  clp_realtuner - Migration 001: Fluids, Wear & Physics toggles
--  Safe / idempotent: IF NOT EXISTS & ALGORITHM=INPLACE
-- =============================================================================

ALTER TABLE `vehicles_data`
    ADD COLUMN IF NOT EXISTS `oil_km`            INT          NOT NULL DEFAULT 0            AFTER `last_service`,
    ADD COLUMN IF NOT EXISTS `oil_quality`       FLOAT        NOT NULL DEFAULT 100          AFTER `oil_km`,
    ADD COLUMN IF NOT EXISTS `fuel_leak`         FLOAT        NOT NULL DEFAULT 0            AFTER `oil_quality`,
    ADD COLUMN IF NOT EXISTS `spark_plug`        FLOAT        NOT NULL DEFAULT 100          AFTER `fuel_leak`,
    ADD COLUMN IF NOT EXISTS `battery`           FLOAT        NOT NULL DEFAULT 100          AFTER `spark_plug`,
    ADD COLUMN IF NOT EXISTS `battery_last_ts`   INT          NOT NULL DEFAULT 0            AFTER `battery`,
    ADD COLUMN IF NOT EXISTS `headlight_state`   FLOAT        NOT NULL DEFAULT 100          AFTER `battery_last_ts`,
    ADD COLUMN IF NOT EXISTS `rearlight_state`   FLOAT        NOT NULL DEFAULT 100          AFTER `headlight_state`,
    ADD COLUMN IF NOT EXISTS `brake_fluid`       FLOAT        NOT NULL DEFAULT 100          AFTER `rearlight_state`,
    ADD COLUMN IF NOT EXISTS `coolant`           FLOAT        NOT NULL DEFAULT 100          AFTER `brake_fluid`,
    ADD COLUMN IF NOT EXISTS `coolant_temp`      FLOAT        NOT NULL DEFAULT 85           AFTER `coolant`,
    ADD COLUMN IF NOT EXISTS `rust`              FLOAT        NOT NULL DEFAULT 0            AFTER `coolant_temp`,
    ADD COLUMN IF NOT EXISTS `windshield_broken` TINYINT(1)   NOT NULL DEFAULT 0            AFTER `rust`,
    ADD COLUMN IF NOT EXISTS `tc_enabled`        TINYINT(1)   NOT NULL DEFAULT 1            AFTER `windshield_broken`,
    ADD COLUMN IF NOT EXISTS `abs_enabled`       TINYINT(1)   NOT NULL DEFAULT 1            AFTER `tc_enabled`,
    ADD COLUMN IF NOT EXISTS `exhaust_flap`      TINYINT(1)   NOT NULL DEFAULT 0            AFTER `abs_enabled`,
    ADD COLUMN IF NOT EXISTS `ecu_map`           VARCHAR(16)  NOT NULL DEFAULT 'stock'      AFTER `exhaust_flap`,
    ADD COLUMN IF NOT EXISTS `tuev_expires`      INT          NOT NULL DEFAULT 0            AFTER `ecu_map`,
    ADD COLUMN IF NOT EXISTS `neon`              LONGTEXT     DEFAULT NULL                  AFTER `tuev_expires`,
    ADD COLUMN IF NOT EXISTS `tint`              FLOAT        NOT NULL DEFAULT 0            AFTER `neon`,
    ADD COLUMN IF NOT EXISTS `wrap`              LONGTEXT     DEFAULT NULL                  AFTER `tint`,
    ADD COLUMN IF NOT EXISTS `interior_mods`     LONGTEXT     DEFAULT NULL                  AFTER `wrap`;

INSERT INTO `_hcm_migrations` (`id`, `applied_at`) VALUES ('001_fluids_and_wear', UNIX_TIMESTAMP())
    ON DUPLICATE KEY UPDATE `applied_at` = UNIX_TIMESTAMP();
