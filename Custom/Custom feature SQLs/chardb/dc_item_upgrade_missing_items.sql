-- =====================================================
-- DC Item Upgrade: Missing Items Log Table
-- =====================================================
-- Logs items that fail upgrade queries due to missing
-- templates, tiers, or clone mappings.
-- 
-- Created: November 29, 2025
-- =====================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_missing_items` (
  `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry ID',
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player who triggered the query',
  `player_name` VARCHAR(50) DEFAULT NULL COMMENT 'Player name for easy reference',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID that failed',
  `item_guid` INT UNSIGNED DEFAULT NULL COMMENT 'Item instance GUID if available',
  `item_name` VARCHAR(255) DEFAULT NULL COMMENT 'Item name if template exists',
  `error_type` ENUM('ITEM_NOT_FOUND', 'TEMPLATE_MISSING', 'TIER_INVALID', 'CLONE_MISSING', 'SLOT_INVALID', 'OTHER') NOT NULL COMMENT 'Type of failure',
  `error_detail` VARCHAR(512) DEFAULT NULL COMMENT 'Additional error details',
  `bag_slot` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Bag slot requested',
  `item_slot` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Item slot requested',
  `timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When error occurred',
  `resolved` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Whether issue has been resolved',
  `resolution_notes` TEXT DEFAULT NULL COMMENT 'Notes on how issue was fixed',
  PRIMARY KEY (`log_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_error_type` (`error_type`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_unresolved` (`resolved`, `timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci 
COMMENT='DarkChaos: Log of items that failed upgrade queries for analysis';

-- View: Summary of missing items by frequency
CREATE OR REPLACE VIEW `dc_item_upgrade_missing_items_summary` AS
SELECT 
    `item_id`,
    MAX(`item_name`) as `item_name`,
    `error_type`,
    COUNT(*) as `occurrence_count`,
    MAX(`timestamp`) as `last_occurrence`,
    MIN(`timestamp`) as `first_occurrence`,
    GROUP_CONCAT(DISTINCT `player_name` ORDER BY `player_name` SEPARATOR ', ') as `affected_players`
FROM `dc_item_upgrade_missing_items`
WHERE `resolved` = 0
GROUP BY `item_id`, `error_type`
ORDER BY `occurrence_count` DESC, `last_occurrence` DESC;
