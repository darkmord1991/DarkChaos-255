-- ============================================================================
-- DC AOE Loot Tables Consolidation
-- ============================================================================
-- This script consolidates the various AOE loot tables:
--
-- Tables in use:
--   dc_aoeloot_detailed_stats  - Main stats table (leaderboards query this)
--   dc_aoeloot_preferences     - Player settings (dc_aoeloot_extensions.cpp)
--   dc_aoeloot_accumulated     - Legacy gold accumulator (ac_aoeloot.cpp)
--
-- Tables to deprecate/migrate:
--   dc_aoe_loot_settings       - Duplicate of dc_aoeloot_preferences
--   dc_aoe_loot_stats          - Empty, never populated
-- ============================================================================

-- 1. Ensure dc_aoeloot_detailed_stats has proper structure
CREATE TABLE IF NOT EXISTS `dc_aoeloot_detailed_stats` (
    `player_guid` INT UNSIGNED NOT NULL PRIMARY KEY,
    `total_items` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In copper',
    `poor_vendored` INT UNSIGNED NOT NULL DEFAULT 0,
    `vendor_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `skinned` INT UNSIGNED NOT NULL DEFAULT 0,
    `mined` INT UNSIGNED NOT NULL DEFAULT 0,
    `herbed` INT UNSIGNED NOT NULL DEFAULT 0,
    `upgrades` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Detailed Stats (Leaderboards)';

-- 2. Migrate data from dc_aoeloot_accumulated to dc_aoeloot_detailed_stats
-- This ensures existing gold data appears in leaderboards
INSERT INTO dc_aoeloot_detailed_stats (player_guid, total_gold)
SELECT player_guid, accumulated_gold
FROM dc_aoeloot_accumulated
WHERE player_guid NOT IN (SELECT player_guid FROM dc_aoeloot_detailed_stats)
ON DUPLICATE KEY UPDATE total_gold = GREATEST(total_gold, VALUES(total_gold));

-- 3. Migrate settings from dc_aoe_loot_settings to dc_aoeloot_preferences
-- dc_aoeloot_preferences has the correct structure used by dc_aoeloot_extensions.cpp
INSERT IGNORE INTO dc_aoeloot_preferences (player_guid, aoe_enabled, min_quality, auto_skin, smart_loot, show_messages)
SELECT character_guid, enabled, min_quality, auto_skin, smart_loot, show_messages
FROM dc_aoe_loot_settings
WHERE character_guid NOT IN (SELECT player_guid FROM dc_aoeloot_preferences);

-- 4. Show current state
SELECT 'dc_aoeloot_detailed_stats' AS table_name, COUNT(*) AS row_count FROM dc_aoeloot_detailed_stats
UNION ALL
SELECT 'dc_aoeloot_preferences', COUNT(*) FROM dc_aoeloot_preferences
UNION ALL
SELECT 'dc_aoeloot_accumulated', COUNT(*) FROM dc_aoeloot_accumulated
UNION ALL
SELECT 'dc_aoe_loot_settings (deprecated)', COUNT(*) FROM dc_aoe_loot_settings
UNION ALL
SELECT 'dc_aoe_loot_stats (deprecated)', COUNT(*) FROM dc_aoe_loot_stats;

-- ============================================================================
-- NOTE: After running this and confirming data is migrated:
-- You can optionally drop the deprecated tables:
-- DROP TABLE IF EXISTS dc_aoe_loot_stats;
-- DROP TABLE IF EXISTS dc_aoe_loot_settings;
-- ============================================================================
