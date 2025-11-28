-- =====================================================
-- Item Upgrade System - Proc Spell Tracking
-- =====================================================
-- This table maps spell IDs to item entries for proc identification
-- Used by the proc scaling system to determine if a spell is an item proc
--
-- Date: November 8, 2025
-- =====================================================

CREATE TABLE IF NOT EXISTS `dc_item_proc_spells` (
  `spell_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Spell ID of the proc effect',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item entry that triggers this proc',
  `proc_type` VARCHAR(50) DEFAULT 'damage' COMMENT 'Type: damage/healing/buff/other',
  `description` VARCHAR(255) COMMENT 'Human-readable description',
  INDEX `idx_item` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Item proc spell mappings for upgrade scaling';

-- Note: This table will be auto-populated at runtime from hardcoded fallbacks
-- You can manually add entries for custom items:
-- INSERT INTO dc_item_proc_spells (spell_id, item_id, proc_type, description) VALUES
-- (12345, 67890, 'damage', 'Custom Trinket Fire Blast');
