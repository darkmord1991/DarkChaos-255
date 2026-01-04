-- ============================================================
-- DC Account Outfits (Account-Wide Outfit Storage)
-- ============================================================
-- Replaces dc_character_outfits for account-wide outfit sharing
-- ============================================================

CREATE TABLE IF NOT EXISTS `dc_account_outfits` (
  `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID',
  `outfit_id` TINYINT UNSIGNED NOT NULL COMMENT 'Outfit Slot (0-49)',
  `name` VARCHAR(50) NOT NULL DEFAULT 'New Outfit',
  `icon` VARCHAR(100) NOT NULL DEFAULT 'Interface/Icons/INV_Misc_QuestionMark',
  `items` TEXT COMMENT 'JSON {SlotKey: itemId}',
  `source_community_id` INT UNSIGNED DEFAULT NULL COMMENT 'If copied from community outfit',
  `source_author` VARCHAR(50) DEFAULT NULL COMMENT 'Original author name if copied from community',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `outfit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Account-wide saved outfits';

-- ============================================================
-- Migration: Copy existing character outfits to account outfits
-- ============================================================
-- Run this ONCE after creating the new table
-- ============================================================

INSERT IGNORE INTO dc_account_outfits (account_id, outfit_id, name, icon, items)
SELECT 
    c.account AS account_id,
    o.outfit_id,
    o.name,
    o.icon,
    o.items
FROM dc_character_outfits o
INNER JOIN characters c ON o.guid = c.guid;
