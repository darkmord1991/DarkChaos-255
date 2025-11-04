-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 1 Schema
-- World Database Tables
-- =========================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- =========================================================================
-- TABLE: dc_item_upgrade_tiers
-- PURPOSE: Define the 5 item upgrade tiers and their properties
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_tiers` (
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Tier ID (1-5)',
  `tier_name` VARCHAR(50) NOT NULL COMMENT 'Tier name (e.g., "Leveling", "Heroic", "Raid", "Mythic", "Artifact")',
  `min_ilvl` SMALLINT UNSIGNED NOT NULL COMMENT 'Minimum item level for tier',
  `max_ilvl` SMALLINT UNSIGNED NOT NULL COMMENT 'Maximum item level for tier',
  `max_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 5 COMMENT 'Maximum upgrade level (0-5)',
  `stat_multiplier_max` FLOAT NOT NULL DEFAULT 1.5 COMMENT 'Max stat multiplier (1.5 for T1-T4, 1.75 for T5)',
  `upgrade_cost_per_level` INT UNSIGNED NOT NULL COMMENT 'Base upgrade token cost per level',
  `source_content` VARCHAR(100) NOT NULL COMMENT 'Primary content source (quest/dungeon/raid)',
  `is_artifact` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Is this an artifact tier (uses essence)',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this tier applies to',
  PRIMARY KEY (`tier_id`, `season`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item upgrade tier definitions';

-- =========================================================================
-- TABLE: dc_item_upgrade_costs
-- PURPOSE: Store the exact token cost for each tier/level combination
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Tier ID (1-5)',
  `upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Upgrade level (1-5)',
  `token_cost` INT UNSIGNED NOT NULL COMMENT 'Upgrade token cost for this level',
  `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Artifact essence cost (T5 only)',
  `ilvl_increase` SMALLINT UNSIGNED NOT NULL COMMENT 'Item level increase for this upgrade',
  `stat_increase_percent` FLOAT NOT NULL COMMENT 'Stat multiplier increase percentage',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this cost applies to',
  PRIMARY KEY (`tier_id`, `upgrade_level`, `season`),
  KEY `idx_tier_level` (`tier_id`, `upgrade_level`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Token costs per tier and upgrade level';

-- =========================================================================
-- TABLE: dc_item_templates_upgrade
-- PURPOSE: Define which items can be upgraded (base info)
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_item_templates_upgrade` (
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID from item_template',
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Item upgrade tier',
  `armor_type` VARCHAR(15) NOT NULL COMMENT 'Armor type (plate/mail/leather/cloth)',
  `item_slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot (1-16)',
  `rarity` TINYINT UNSIGNED NOT NULL COMMENT 'Item rarity (1-4)',
  `source_type` VARCHAR(50) NOT NULL COMMENT 'Source type (quest/dungeon/raid/worldboss/artifact)',
  `source_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Specific source ID (creature/quest/etc)',
  `base_stat_value` INT UNSIGNED NOT NULL COMMENT 'Base stat value without upgrades',
  `cosmetic_variant` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cosmetic variant (0=base, 1+=variant)',
  `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Is this item available',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this item is in',
  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  PRIMARY KEY (`item_id`, `season`),
  KEY `idx_tier` (`tier_id`),
  KEY `idx_source` (`source_type`, `source_id`),
  KEY `idx_armor_slot` (`armor_type`, `item_slot`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Upgradeable item template mappings';

-- =========================================================================
-- TABLE: dc_chaos_artifact_items
-- PURPOSE: Map chaos artifact cosmetic variants and their drop locations
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_chaos_artifact_items` (
  `artifact_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Artifact ID',
  `artifact_name` VARCHAR(100) NOT NULL COMMENT 'Artifact display name',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Base item ID',
  `cosmetic_variant` TINYINT UNSIGNED NOT NULL COMMENT 'Cosmetic variant number',
  `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 4 COMMENT 'Artifact rarity (usually 4=epic)',
  `location_name` VARCHAR(100) NOT NULL COMMENT 'Zone or location name',
  `location_type` VARCHAR(50) NOT NULL COMMENT 'Location type (zone/dungeon/raid/world)',
  `essence_cost` INT UNSIGNED NOT NULL DEFAULT 250 COMMENT 'Essence cost to upgrade to max',
  `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Is this artifact available',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this artifact is in',
  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  PRIMARY KEY (`artifact_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_location_type` (`location_type`),
  KEY `idx_season` (`season`),
  KEY `idx_variant` (`item_id`, `cosmetic_variant`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chaos artifact item definitions (manually spawned by user)';

-- =========================================================================
-- INDEXES AND COMMENTS
-- =========================================================================

-- Summary of tables:
-- 1. dc_item_upgrade_tiers: T1-T5 tier definitions (5 rows per season)
-- 2. dc_item_upgrade_costs: Upgrade costs by tier/level (25 rows per season)
-- 3. dc_item_templates_upgrade: Item template mappings (940 rows per season)
-- 4. dc_chaos_artifact_items: Chaos artifact variants (110 rows per season)

-- Total expected rows: ~1,080 rows per season
-- Estimated storage: ~2-3 MB per season

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
