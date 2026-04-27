-- =============================================================================
--  005_police.sql - Polizei Batch 10: VIN-Etching
-- =============================================================================

ALTER TABLE `vehicles_data`
    ADD COLUMN IF NOT EXISTS `etched_vin` VARCHAR(24) DEFAULT NULL AFTER `vin`;
