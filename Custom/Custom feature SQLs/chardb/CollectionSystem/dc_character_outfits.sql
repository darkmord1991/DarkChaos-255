CREATE TABLE IF NOT EXISTS `dc_character_outfits` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `outfit_id` TINYINT UNSIGNED NOT NULL COMMENT 'Outfit Slot ID (0-N)',
  `name` VARCHAR(50) NOT NULL DEFAULT 'New Outfit',
  `icon` VARCHAR(100) NOT NULL DEFAULT 'Interface\\Icons\\INV_Misc_QuestionMark',
  `items` TEXT COMMENT 'JSON string of slot->appearance',
  PRIMARY KEY (`guid`, `outfit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player saved outfits for Wardrobe';
