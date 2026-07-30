--
-- DC Wardrobe: per-character appearance tables.
--
-- `dc_character_transmog` previously existed only as a runtime CREATE TABLE inside
-- dc_addon_wardrobe.cpp. It is declared here so a fresh database has it before the
-- worldserver starts; IF NOT EXISTS keeps this a no-op on realms where the runtime
-- path already created it.
--
-- `dc_character_enchant_visual` backs the cosmetic weapon enchant glow. The chosen
-- SpellItemEnchantment id only replaces the permanent half of the visible-item
-- enchantment field for observers -- the item's real enchantment is never modified,
-- so no stats, procs or charges are granted.
--

CREATE TABLE IF NOT EXISTS `dc_character_transmog` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID (low)',
  `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot (0-18)',
  `fake_entry` INT UNSIGNED NOT NULL COMMENT 'Item entry used for appearance (0 = hide slot)',
  `real_entry` INT UNSIGNED NOT NULL COMMENT 'Real equipped item entry',
  PRIMARY KEY (`guid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Applied transmog per character';

CREATE TABLE IF NOT EXISTS `dc_character_enchant_visual` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID (low)',
  `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot (weapon slots only: 15 main hand, 16 off hand, 17 ranged)',
  `enchant_id` INT UNSIGNED NOT NULL COMMENT 'SpellItemEnchantment.ID shown as the glow',
  PRIMARY KEY (`guid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Cosmetic weapon enchant visual per character';
