-- =============================================================================
--  Migration 006: Multi-Warehouse-Storage + Order-System (Batch 14b)
-- =============================================================================

-- Stock: Kategorie pro Eintrag (parts/body/paint/fluids)
ALTER TABLE `mechanic_workshop_stock`
    ADD COLUMN IF NOT EXISTS `category` VARCHAR(16) NOT NULL DEFAULT 'parts';

-- Werkstatt: Kapazitaet je Kategorie
ALTER TABLE `mechanic_workshops`
    ADD COLUMN IF NOT EXISTS `cap_parts`  INT NOT NULL DEFAULT 80,
    ADD COLUMN IF NOT EXISTS `cap_body`   INT NOT NULL DEFAULT 50,
    ADD COLUMN IF NOT EXISTS `cap_paint`  INT NOT NULL DEFAULT 40,
    ADD COLUMN IF NOT EXISTS `cap_fluids` INT NOT NULL DEFAULT 60;

-- Bestellsystem: pending -> delivered/cancelled, mit Lieferzeit-Timestamp
CREATE TABLE IF NOT EXISTS `mechanic_workshop_orders` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `workshop_id`  INT          NOT NULL,
    `item`         VARCHAR(64)  NOT NULL,
    `category`     VARCHAR(16)  NOT NULL DEFAULT 'parts',
    `amount`       INT          NOT NULL DEFAULT 1,
    `unit_cost`    INT          NOT NULL DEFAULT 0,
    `total_cost`   INT          NOT NULL DEFAULT 0,
    `ordered_by`   VARCHAR(64)  DEFAULT NULL,
    `ordered_at`   INT          NOT NULL DEFAULT 0,
    `delivers_at`  INT          NOT NULL DEFAULT 0,
    `delivered_at` INT          DEFAULT NULL,
    `status`       VARCHAR(16)  NOT NULL DEFAULT 'pending',
    INDEX `idx_workshop` (`workshop_id`),
    INDEX `idx_status_delivers` (`status`, `delivers_at`),
    FOREIGN KEY (`workshop_id`) REFERENCES `mechanic_workshops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
