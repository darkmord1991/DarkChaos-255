-- DC AOE Loot Stats Table
-- Tracks player looting statistics for the AoE loot system
-- Date: 2025-11-29

CREATE TABLE IF NOT EXISTS `dc_aoe_loot_stats` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `character_guid` INT UNSIGNED NOT NULL,
    `total_items` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `vendor_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `upgrades_found` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_loot_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_character` (`character_guid`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
