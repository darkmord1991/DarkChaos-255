-- ========================================================================
-- Table: dc_vault_loot_table (WORLD DATABASE)
-- Purpose: Spec-based loot pool for Mythic+ Great Vault
-- ========================================================================
-- This table stores eligible items for the Great Vault reward system.
-- Items are filtered by class, spec, armor type, and role for intelligent
-- loot generation matching player's current specialization.
-- 
-- SIMPLIFIED ITEM LEVEL PROGRESSION:
-- M+2-4:   239 ilvl (Tier 1)
-- M+5-7:   252 ilvl (Tier 2)
-- M+8-11:  264 ilvl (Tier 3)
-- M+12-15: 277 ilvl (Tier 4)
-- M+16-19: 290 ilvl (Tier 5)
-- M+20+:   303+ ilvl (Tier 6+)
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_vault_loot_table` (
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item entry ID from item_template',
  `item_level_min` SMALLINT UNSIGNED NOT NULL DEFAULT 226 COMMENT 'Minimum ilvl this item can appear at',
  `item_level_max` SMALLINT UNSIGNED NOT NULL DEFAULT 310 COMMENT 'Maximum ilvl this item can appear at',
  `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Class mask: 1=Warrior, 2=Paladin, 4=Hunter, 8=Rogue, 16=Priest, 32=DK, 64=Shaman, 128=Druid, 256=Mage, 512=Warlock',
  `spec_name` VARCHAR(50) DEFAULT NULL COMMENT 'Specific spec name (Arms, Fury, Protection, etc.) or NULL for all specs',
  `armor_type` ENUM('Cloth','Leather','Mail','Plate','Misc') NOT NULL COMMENT 'Armor proficiency requirement',
  `slot_type` ENUM('Head','Neck','Shoulder','Back','Chest','Wrist','Hands','Waist','Legs','Feet','Finger','Trinket','Weapon','Shield','Offhand','Ranged') NOT NULL COMMENT 'Equipment slot',
  `role_mask` TINYINT UNSIGNED NOT NULL DEFAULT 7 COMMENT 'Role mask: 1=Tank, 2=Healer, 4=DPS, 7=All',
  `weight` SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Selection weight for random picking (higher = more likely)',
  `source` VARCHAR(100) DEFAULT NULL COMMENT 'Item source description (ICC, RS, ToC, etc.)',
  PRIMARY KEY (`item_id`),
  KEY `idx_class_spec` (`class_mask`, `spec_name`),
  KEY `idx_armor_slot` (`armor_type`, `slot_type`),
  KEY `idx_role` (`role_mask`),
  KEY `idx_ilvl` (`item_level_min`, `item_level_max`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic+ Great Vault loot table for spec-based rewards';

-- ========================================================================
-- ICECROWN CITADEL (ICC) 25 Heroic - Item Level 264-310
-- Tier 3: M+8-11 (264 ilvl base)
-- ========================================================================

-- WARRIOR (class_mask = 1)
-- Arms/Fury DPS Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51227, 264, 310, 1, 'Arms', 'Plate', 'Head', 4, 100, 'ICC 25H - Sanctified Ymirjar Lord Helmet'),
(51228, 264, 310, 1, 'Arms', 'Plate', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Ymirjar Lord Shoulderguards'),
(51229, 264, 310, 1, 'Arms', 'Plate', 'Chest', 4, 100, 'ICC 25H - Sanctified Ymirjar Lord Battleplate'),
(51230, 264, 310, 1, 'Arms', 'Plate', 'Hands', 4, 100, 'ICC 25H - Sanctified Ymirjar Lord Gauntlets'),
(51231, 264, 310, 1, 'Arms', 'Plate', 'Legs', 4, 100, 'ICC 25H - Sanctified Ymirjar Lord Legplates'),
(50415, 264, 310, 1, NULL, 'Misc', 'Weapon', 4, 100, 'ICC 25H - Cryptmaker (2H Axe)'),
(50427, 264, 310, 1, NULL, 'Misc', 'Weapon', 4, 100, 'ICC 25H - Bloodsurge (2H Axe)'),
(50428, 264, 310, 1, NULL, 'Misc', 'Weapon', 4, 100, 'ICC 25H - Royal Scepter of Terenas II (1H Mace)'),
(50621, 264, 310, 1, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Whispering Fanged Skull');

-- Protection Tank Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51212, 264, 310, 1, 'Protection', 'Plate', 'Head', 1, 100, 'ICC 25H - Sanctified Ymirjar Lord Greathelm'),
(51214, 264, 310, 1, 'Protection', 'Plate', 'Shoulder', 1, 100, 'ICC 25H - Sanctified Ymirjar Lord Pauldrons'),
(51210, 264, 310, 1, 'Protection', 'Plate', 'Chest', 1, 100, 'ICC 25H - Sanctified Ymirjar Lord Breastplate'),
(51211, 264, 310, 1, 'Protection', 'Plate', 'Hands', 1, 100, 'ICC 25H - Sanctified Ymirjar Lord Handguards'),
(51213, 264, 310, 1, 'Protection', 'Plate', 'Legs', 1, 100, 'ICC 25H - Sanctified Ymirjar Lord Legguards'),
(50616, 264, 310, 1, 'Protection', 'Misc', 'Shield', 1, 100, 'ICC 25H - Bulwark of Smouldering Steel'),
(50622, 264, 310, 1, 'Protection', 'Misc', 'Trinket', 1, 100, 'ICC 25H - Corpse Tongue Coin');

-- PALADIN (class_mask = 2)
-- Holy Healer Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51272, 264, 310, 2, 'Holy', 'Plate', 'Head', 2, 100, 'ICC 25H - Sanctified Lightsworn Faceguard'),
(51274, 264, 310, 2, 'Holy', 'Plate', 'Shoulder', 2, 100, 'ICC 25H - Sanctified Lightsworn Shoulderguards'),
(51270, 264, 310, 2, 'Holy', 'Plate', 'Chest', 2, 100, 'ICC 25H - Sanctified Lightsworn Battleplate'),
(51271, 264, 310, 2, 'Holy', 'Plate', 'Hands', 2, 100, 'ICC 25H - Sanctified Lightsworn Gloves'),
(51273, 264, 310, 2, 'Holy', 'Plate', 'Legs', 2, 100, 'ICC 25H - Sanctified Lightsworn Legplates'),
(50612, 264, 310, 2, 'Holy', 'Misc', 'Trinket', 2, 100, 'ICC 25H - Althor''s Abacus');

-- Retribution DPS Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51266, 264, 310, 2, 'Retribution', 'Plate', 'Head', 4, 100, 'ICC 25H - Sanctified Lightsworn Headpiece'),
(51268, 264, 310, 2, 'Retribution', 'Plate', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Lightsworn Spaulders'),
(51264, 264, 310, 2, 'Retribution', 'Plate', 'Chest', 4, 100, 'ICC 25H - Sanctified Lightsworn Tunic'),
(51265, 264, 310, 2, 'Retribution', 'Plate', 'Hands', 4, 100, 'ICC 25H - Sanctified Lightsworn Handguards'),
(51267, 264, 310, 2, 'Retribution', 'Plate', 'Legs', 4, 100, 'ICC 25H - Sanctified Lightsworn Greaves'),
(50428, 264, 310, 2, 'Retribution', 'Misc', 'Weapon', 4, 100, 'ICC 25H - Royal Scepter of Terenas II');

-- Protection Tank Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51277, 264, 310, 2, 'Protection', 'Plate', 'Head', 1, 100, 'ICC 25H - Sanctified Lightsworn Helmet'),
(51279, 264, 310, 2, 'Protection', 'Plate', 'Shoulder', 1, 100, 'ICC 25H - Sanctified Lightsworn Shoulderplates'),
(51275, 264, 310, 2, 'Protection', 'Plate', 'Chest', 1, 100, 'ICC 25H - Sanctified Lightsworn Chestguard'),
(51276, 264, 310, 2, 'Protection', 'Plate', 'Hands', 1, 100, 'ICC 25H - Sanctified Lightsworn Gauntlets'),
(51278, 264, 310, 2, 'Protection', 'Plate', 'Legs', 1, 100, 'ICC 25H - Sanctified Lightsworn Legguards'),
(50616, 264, 310, 2, 'Protection', 'Misc', 'Shield', 1, 100, 'ICC 25H - Bulwark of Smouldering Steel');

-- DEATH KNIGHT (class_mask = 32)
-- Blood Tank Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51127, 264, 310, 32, 'Blood', 'Plate', 'Head', 1, 100, 'ICC 25H - Sanctified Scourgelord Helmet'),
(51129, 264, 310, 32, 'Blood', 'Plate', 'Shoulder', 1, 100, 'ICC 25H - Sanctified Scourgelord Shoulderplates'),
(51125, 264, 310, 32, 'Blood', 'Plate', 'Chest', 1, 100, 'ICC 25H - Sanctified Scourgelord Battleplate'),
(51126, 264, 310, 32, 'Blood', 'Plate', 'Hands', 1, 100, 'ICC 25H - Sanctified Scourgelord Gauntlets'),
(51128, 264, 310, 32, 'Blood', 'Plate', 'Legs', 1, 100, 'ICC 25H - Sanctified Scourgelord Legplates');

-- Frost/Unholy DPS Plate
INSERT INTO `dc_vault_loot_table` VALUES
(51133, 264, 310, 32, 'Frost', 'Plate', 'Head', 4, 100, 'ICC 25H - Sanctified Scourgelord Faceguard'),
(51135, 264, 310, 32, 'Frost', 'Plate', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Scourgelord Pauldrons'),
(51131, 264, 310, 32, 'Frost', 'Plate', 'Chest', 4, 100, 'ICC 25H - Sanctified Scourgelord Chestguard'),
(51132, 264, 310, 32, 'Frost', 'Plate', 'Hands', 4, 100, 'ICC 25H - Sanctified Scourgelord Handguards'),
(51134, 264, 310, 32, 'Frost', 'Plate', 'Legs', 4, 100, 'ICC 25H - Sanctified Scourgelord Legguards'),
(50415, 264, 310, 32, NULL, 'Misc', 'Weapon', 4, 100, 'ICC 25H - Cryptmaker'),
(50603, 264, 310, 32, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Sharpened Twilight Scale');

-- HUNTER (class_mask = 4)
INSERT INTO `dc_vault_loot_table` VALUES
(51286, 264, 310, 4, NULL, 'Mail', 'Head', 4, 100, 'ICC 25H - Sanctified Ahn''Kahar Blood Hunter''s Headpiece'),
(51288, 264, 310, 4, NULL, 'Mail', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Ahn''Kahar Blood Hunter''s Spaulders'),
(51284, 264, 310, 4, NULL, 'Mail', 'Chest', 4, 100, 'ICC 25H - Sanctified Ahn''Kahar Blood Hunter''s Tunic'),
(51285, 264, 310, 4, NULL, 'Mail', 'Hands', 4, 100, 'ICC 25H - Sanctified Ahn''Kahar Blood Hunter''s Handguards'),
(51287, 264, 310, 4, NULL, 'Mail', 'Legs', 4, 100, 'ICC 25H - Sanctified Ahn''Kahar Blood Hunter''s Legguards'),
(50638, 264, 310, 4, NULL, 'Misc', 'Ranged', 4, 100, 'ICC 25H - Zod''s Repeating Longbow'),
(50401, 264, 310, 4, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Ashen Band of Endless Vengeance');

-- ROGUE (class_mask = 8)
INSERT INTO `dc_vault_loot_table` VALUES
(51252, 264, 310, 8, NULL, 'Leather', 'Head', 4, 100, 'ICC 25H - Sanctified Shadowblade Helmet'),
(51254, 264, 310, 8, NULL, 'Leather', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Shadowblade Pauldrons'),
(51250, 264, 310, 8, NULL, 'Leather', 'Chest', 4, 100, 'ICC 25H - Sanctified Shadowblade Breastplate'),
(51251, 264, 310, 8, NULL, 'Leather', 'Hands', 4, 100, 'ICC 25H - Sanctified Shadowblade Gauntlets'),
(51253, 264, 310, 8, NULL, 'Leather', 'Legs', 4, 100, 'ICC 25H - Sanctified Shadowblade Legplates'),
(50654, 264, 310, 8, NULL, 'Misc', 'Weapon', 4, 100, 'ICC 25H - Hersir''s Greatspear'),
(50621, 264, 310, 8, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Whispering Fanged Skull');

-- SHAMAN (class_mask = 64)
-- Elemental DPS Mail
INSERT INTO `dc_vault_loot_table` VALUES
(51237, 264, 310, 64, 'Elemental', 'Mail', 'Head', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Helm'),
(51239, 264, 310, 64, 'Elemental', 'Mail', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Shoulderguards'),
(51235, 264, 310, 64, 'Elemental', 'Mail', 'Chest', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Hauberk'),
(51236, 264, 310, 64, 'Elemental', 'Mail', 'Hands', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Gloves'),
(51238, 264, 310, 64, 'Elemental', 'Mail', 'Legs', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Kilt');

-- Enhancement DPS Mail
INSERT INTO `dc_vault_loot_table` VALUES
(51242, 264, 310, 64, 'Enhancement', 'Mail', 'Head', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Faceguard'),
(51244, 264, 310, 64, 'Enhancement', 'Mail', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Shoulderpads'),
(51240, 264, 310, 64, 'Enhancement', 'Mail', 'Chest', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Chestguard'),
(51241, 264, 310, 64, 'Enhancement', 'Mail', 'Hands', 4, 100, 'ICC 25H - Sanctified Frost Witch''s Grips'),
(51243, 264, 310, 64, 'Enhancement', 'Mail', 'Legs', 4, 100, 'ICC 25H - Sanctified Frost Witch''s War-Kilt');

-- Restoration Healer Mail
INSERT INTO `dc_vault_loot_table` VALUES
(51247, 264, 310, 64, 'Restoration', 'Mail', 'Head', 2, 100, 'ICC 25H - Sanctified Frost Witch''s Headpiece'),
(51249, 264, 310, 64, 'Restoration', 'Mail', 'Shoulder', 2, 100, 'ICC 25H - Sanctified Frost Witch''s Spaulders'),
(51245, 264, 310, 64, 'Restoration', 'Mail', 'Chest', 2, 100, 'ICC 25H - Sanctified Frost Witch''s Tunic'),
(51246, 264, 310, 64, 'Restoration', 'Mail', 'Hands', 2, 100, 'ICC 25H - Sanctified Frost Witch''s Handguards'),
(51248, 264, 310, 64, 'Restoration', 'Mail', 'Legs', 2, 100, 'ICC 25H - Sanctified Frost Witch''s Legguards');

-- DRUID (class_mask = 128)
-- Balance DPS Leather
INSERT INTO `dc_vault_loot_table` VALUES
(51148, 264, 310, 128, 'Balance', 'Leather', 'Head', 4, 100, 'ICC 25H - Sanctified Lasherweave Cover'),
(51150, 264, 310, 128, 'Balance', 'Leather', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Lasherweave Mantle'),
(51146, 264, 310, 128, 'Balance', 'Leather', 'Chest', 4, 100, 'ICC 25H - Sanctified Lasherweave Vestment'),
(51147, 264, 310, 128, 'Balance', 'Leather', 'Hands', 4, 100, 'ICC 25H - Sanctified Lasherweave Gloves'),
(51149, 264, 310, 128, 'Balance', 'Leather', 'Legs', 4, 100, 'ICC 25H - Sanctified Lasherweave Trousers');

-- Feral Tank/DPS Leather
INSERT INTO `dc_vault_loot_table` VALUES
(51296, 264, 310, 128, 'Feral', 'Leather', 'Head', 5, 100, 'ICC 25H - Sanctified Lasherweave Helmet'),
(51299, 264, 310, 128, 'Feral', 'Leather', 'Shoulder', 5, 100, 'ICC 25H - Sanctified Lasherweave Shoulderpads'),
(51294, 264, 310, 128, 'Feral', 'Leather', 'Chest', 5, 100, 'ICC 25H - Sanctified Lasherweave Raiment'),
(51295, 264, 310, 128, 'Feral', 'Leather', 'Hands', 5, 100, 'ICC 25H - Sanctified Lasherweave Handgrips'),
(51297, 264, 310, 128, 'Feral', 'Leather', 'Legs', 5, 100, 'ICC 25H - Sanctified Lasherweave Legguards');

-- Restoration Healer Leather
INSERT INTO `dc_vault_loot_table` VALUES
(51302, 264, 310, 128, 'Restoration', 'Leather', 'Head', 2, 100, 'ICC 25H - Sanctified Lasherweave Headguard'),
(51304, 264, 310, 128, 'Restoration', 'Leather', 'Shoulder', 2, 100, 'ICC 25H - Sanctified Lasherweave Pauldrons'),
(51300, 264, 310, 128, 'Restoration', 'Leather', 'Chest', 2, 100, 'ICC 25H - Sanctified Lasherweave Robes'),
(51301, 264, 310, 128, 'Restoration', 'Leather', 'Hands', 2, 100, 'ICC 25H - Sanctified Lasherweave Gauntlets'),
(51303, 264, 310, 128, 'Restoration', 'Leather', 'Legs', 2, 100, 'ICC 25H - Sanctified Lasherweave Leggings');

-- PRIEST (class_mask = 16)
-- Shadow DPS Cloth
INSERT INTO `dc_vault_loot_table` VALUES
(51261, 264, 310, 16, 'Shadow', 'Cloth', 'Head', 4, 100, 'ICC 25H - Sanctified Crimson Acolyte Hood'),
(51263, 264, 310, 16, 'Shadow', 'Cloth', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Crimson Acolyte Mantle'),
(51259, 264, 310, 16, 'Shadow', 'Cloth', 'Chest', 4, 100, 'ICC 25H - Sanctified Crimson Acolyte Raiments'),
(51260, 264, 310, 16, 'Shadow', 'Cloth', 'Hands', 4, 100, 'ICC 25H - Sanctified Crimson Acolyte Handwraps'),
(51262, 264, 310, 16, 'Shadow', 'Cloth', 'Legs', 4, 100, 'ICC 25H - Sanctified Crimson Acolyte Leggings');

-- Holy/Discipline Healer Cloth
INSERT INTO `dc_vault_loot_table` VALUES
(51256, 264, 310, 16, 'Holy', 'Cloth', 'Head', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Cowl'),
(51258, 264, 310, 16, 'Holy', 'Cloth', 'Shoulder', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Shoulderpads'),
(51178, 264, 310, 16, 'Holy', 'Cloth', 'Chest', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Robe'),
(51255, 264, 310, 16, 'Holy', 'Cloth', 'Hands', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Gloves'),
(51257, 264, 310, 16, 'Holy', 'Cloth', 'Legs', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Pants'),
(51256, 264, 310, 16, 'Discipline', 'Cloth', 'Head', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Cowl'),
(51258, 264, 310, 16, 'Discipline', 'Cloth', 'Shoulder', 2, 100, 'ICC 25H - Sanctified Crimson Acolyte Shoulderpads');

-- MAGE (class_mask = 256)
INSERT INTO `dc_vault_loot_table` VALUES
(51158, 264, 310, 256, NULL, 'Cloth', 'Head', 4, 100, 'ICC 25H - Sanctified Bloodmage Hood'),
(51160, 264, 310, 256, NULL, 'Cloth', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Bloodmage Shoulderpads'),
(51156, 264, 310, 256, NULL, 'Cloth', 'Chest', 4, 100, 'ICC 25H - Sanctified Bloodmage Robe'),
(51157, 264, 310, 256, NULL, 'Cloth', 'Hands', 4, 100, 'ICC 25H - Sanctified Bloodmage Gloves'),
(51159, 264, 310, 256, NULL, 'Cloth', 'Legs', 4, 100, 'ICC 25H - Sanctified Bloodmage Leggings'),
(50719, 264, 310, 256, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Phylactery of the Nameless Lich');

-- WARLOCK (class_mask = 512)
INSERT INTO `dc_vault_loot_table` VALUES
(51208, 264, 310, 512, NULL, 'Cloth', 'Head', 4, 100, 'ICC 25H - Sanctified Dark Coven Hood'),
(51210, 264, 310, 512, NULL, 'Cloth', 'Shoulder', 4, 100, 'ICC 25H - Sanctified Dark Coven Shoulderpads'),
(51206, 264, 310, 512, NULL, 'Cloth', 'Chest', 4, 100, 'ICC 25H - Sanctified Dark Coven Robe'),
(51207, 264, 310, 512, NULL, 'Cloth', 'Hands', 4, 100, 'ICC 25H - Sanctified Dark Coven Gloves'),
(51209, 264, 310, 512, NULL, 'Cloth', 'Legs', 4, 100, 'ICC 25H - Sanctified Dark Coven Leggings'),
(50365, 264, 310, 512, NULL, 'Misc', 'Trinket', 4, 100, 'ICC 25H - Phylactery of the Nameless Lich');

-- ========================================================================
-- RUBY SANCTUM (RS) 25 Heroic - Item Level 271-284
-- ========================================================================

-- Universal DPS Trinkets
INSERT INTO `dc_vault_loot_table` VALUES
(54588, 264, 310, 1023, NULL, 'Misc', 'Trinket', 4, 100, 'RS 25H - Charred Twilight Scale'),
(54590, 264, 310, 1023, NULL, 'Misc', 'Trinket', 4, 100, 'RS 25H - Sharpened Twilight Scale'),
(54569, 264, 310, 1023, NULL, 'Misc', 'Trinket', 4, 100, 'RS 25H - Sharpened Twilight Scale');

-- Universal Healer Trinkets
INSERT INTO `dc_vault_loot_table` VALUES
(54572, 264, 310, 1023, NULL, 'Misc', 'Trinket', 2, 100, 'RS 25H - Glowing Twilight Scale'),
(54589, 264, 310, 1023, NULL, 'Misc', 'Trinket', 2, 100, 'RS 25H - Glowing Twilight Scale');

-- Universal Tank Trinkets
INSERT INTO `dc_vault_loot_table` VALUES
(54591, 264, 310, 1023, NULL, 'Misc', 'Trinket', 1, 100, 'RS 25H - Petrified Twilight Scale');

-- ========================================================================
-- ADDITIONAL JEWELRY (All Classes)
-- ========================================================================

-- Necklaces
INSERT INTO `dc_vault_loot_table` VALUES
(50609, 264, 310, 1023, NULL, 'Misc', 'Neck', 4, 100, 'ICC 25H - Choker of Filthy Diamonds'),
(50724, 264, 310, 1023, NULL, 'Misc', 'Neck', 2, 100, 'ICC 25H - Blood Queen''s Crimson Choker');

-- Rings
INSERT INTO `dc_vault_loot_table` VALUES
(50622, 264, 310, 1023, NULL, 'Misc', 'Finger', 1, 100, 'ICC 25H - Devium''s Eternally Cold Ring'),
(50614, 264, 310, 1023, NULL, 'Misc', 'Finger', 4, 100, 'ICC 25H - Loop of the Endless Labyrinth'),
(50664, 264, 310, 1023, NULL, 'Misc', 'Finger', 2, 100, 'ICC 25H - Ring of Rapid Ascension');

-- Cloaks
INSERT INTO `dc_vault_loot_table` VALUES
(50653, 264, 310, 1023, NULL, 'Misc', 'Back', 4, 100, 'ICC 25H - Shadowvault Slayer''s Cloak'),
(50628, 264, 310, 1023, NULL, 'Misc', 'Back', 2, 100, 'ICC 25H - Frostbinder''s Shredded Cape'),
(50718, 264, 310, 1023, NULL, 'Misc', 'Back', 1, 100, 'ICC 25H - Royal Crimson Cloak');

-- ========================================================================
-- TRIAL OF THE CRUSADER (ToC) 25 Heroic - Item Level 245-258
-- ========================================================================

-- WARRIOR ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48378, 252, 310, 1, 'Arms', 'Plate', 'Head', 4, 100, 'ToC 25H - Reinforced Sapphirium Headguard'),
(48380, 252, 310, 1, 'Arms', 'Plate', 'Shoulder', 4, 100, 'ToC 25H - Reinforced Sapphirium Mantle'),
(48376, 252, 310, 1, 'Arms', 'Plate', 'Chest', 4, 100, 'ToC 25H - Reinforced Sapphirium Breastplate'),
(48377, 252, 310, 1, 'Arms', 'Plate', 'Hands', 4, 100, 'ToC 25H - Reinforced Sapphirium Gauntlets'),
(48379, 252, 310, 1, 'Arms', 'Plate', 'Legs', 4, 100, 'ToC 25H - Reinforced Sapphirium Legplates'),
(47427, 252, 310, 1, 'Protection', 'Plate', 'Head', 1, 100, 'ToC 25H - Reinforced Sapphirium Helmet'),
(47429, 252, 310, 1, 'Protection', 'Plate', 'Shoulder', 1, 100, 'ToC 25H - Reinforced Sapphirium Shoulderguards'),
(47425, 252, 310, 1, 'Protection', 'Plate', 'Chest', 1, 100, 'ToC 25H - Reinforced Sapphirium Chestguard'),
(47426, 252, 310, 1, 'Protection', 'Plate', 'Hands', 1, 100, 'ToC 25H - Reinforced Sapphirium Handguards'),
(47428, 252, 310, 1, 'Protection', 'Plate', 'Legs', 1, 100, 'ToC 25H - Reinforced Sapphirium Legguards');

-- PALADIN ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48604, 252, 310, 2, 'Retribution', 'Plate', 'Head', 4, 100, 'ToC 25H - Turalyon Headpiece'),
(48606, 252, 310, 2, 'Retribution', 'Plate', 'Shoulder', 4, 100, 'ToC 25H - Turalyon Spaulders'),
(48602, 252, 310, 2, 'Retribution', 'Plate', 'Chest', 4, 100, 'ToC 25H - Turalyon Tunic'),
(48603, 252, 310, 2, 'Retribution', 'Plate', 'Hands', 4, 100, 'ToC 25H - Turalyon Gloves'),
(48605, 252, 310, 2, 'Retribution', 'Plate', 'Legs', 4, 100, 'ToC 25H - Turalyon Greaves'),
(48629, 252, 310, 2, 'Holy', 'Plate', 'Head', 2, 100, 'ToC 25H - Turalyon Faceguard'),
(48631, 252, 310, 2, 'Holy', 'Plate', 'Shoulder', 2, 100, 'ToC 25H - Turalyon Shoulderguards'),
(48627, 252, 310, 2, 'Holy', 'Plate', 'Chest', 2, 100, 'ToC 25H - Turalyon Battleplate'),
(48628, 252, 310, 2, 'Holy', 'Plate', 'Hands', 2, 100, 'ToC 25H - Turalyon Handguards'),
(48630, 252, 310, 2, 'Holy', 'Plate', 'Legs', 2, 100, 'ToC 25H - Turalyon Legplates');

-- DEATH KNIGHT ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48478, 252, 310, 32, 'Frost', 'Plate', 'Head', 4, 100, 'ToC 25H - Thassarian Faceguard'),
(48480, 252, 310, 32, 'Frost', 'Plate', 'Shoulder', 4, 100, 'ToC 25H - Thassarian Pauldrons'),
(48476, 252, 310, 32, 'Frost', 'Plate', 'Chest', 4, 100, 'ToC 25H - Thassarian Chestguard'),
(48477, 252, 310, 32, 'Frost', 'Plate', 'Hands', 4, 100, 'ToC 25H - Thassarian Gauntlets'),
(48479, 252, 310, 32, 'Frost', 'Plate', 'Legs', 4, 100, 'ToC 25H - Thassarian Legguards'),
(48503, 252, 310, 32, 'Blood', 'Plate', 'Head', 1, 100, 'ToC 25H - Thassarian Helmet'),
(48505, 252, 310, 32, 'Blood', 'Plate', 'Shoulder', 1, 100, 'ToC 25H - Thassarian Shoulderplates'),
(48501, 252, 310, 32, 'Blood', 'Plate', 'Chest', 1, 100, 'ToC 25H - Thassarian Battleplate'),
(48502, 252, 310, 32, 'Blood', 'Plate', 'Hands', 1, 100, 'ToC 25H - Thassarian Handguards'),
(48504, 252, 310, 32, 'Blood', 'Plate', 'Legs', 1, 100, 'ToC 25H - Thassarian Legplates');

-- HUNTER ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48254, 252, 310, 4, NULL, 'Mail', 'Head', 4, 100, 'ToC 25H - Windrunner Headpiece'),
(48256, 252, 310, 4, NULL, 'Mail', 'Shoulder', 4, 100, 'ToC 25H - Windrunner Spaulders'),
(48252, 252, 310, 4, NULL, 'Mail', 'Chest', 4, 100, 'ToC 25H - Windrunner Tunic'),
(48253, 252, 310, 4, NULL, 'Mail', 'Hands', 4, 100, 'ToC 25H - Windrunner Gauntlets'),
(48255, 252, 310, 4, NULL, 'Mail', 'Legs', 4, 100, 'ToC 25H - Windrunner Legguards');

-- SHAMAN ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48313, 252, 310, 64, 'Elemental', 'Mail', 'Head', 4, 100, 'ToC 25H - Nobundo Headpiece'),
(48315, 252, 310, 64, 'Elemental', 'Mail', 'Shoulder', 4, 100, 'ToC 25H - Nobundo Spaulders'),
(48311, 252, 310, 64, 'Elemental', 'Mail', 'Chest', 4, 100, 'ToC 25H - Nobundo Hauberk'),
(48312, 252, 310, 64, 'Elemental', 'Mail', 'Hands', 4, 100, 'ToC 25H - Nobundo Gloves'),
(48314, 252, 310, 64, 'Elemental', 'Mail', 'Legs', 4, 100, 'ToC 25H - Nobundo Kilt'),
(48338, 252, 310, 64, 'Enhancement', 'Mail', 'Head', 4, 100, 'ToC 25H - Nobundo Faceguard'),
(48340, 252, 310, 64, 'Enhancement', 'Mail', 'Shoulder', 4, 100, 'ToC 25H - Nobundo Shoulderpads'),
(48336, 252, 310, 64, 'Enhancement', 'Mail', 'Chest', 4, 100, 'ToC 25H - Nobundo Chestguard'),
(48337, 252, 310, 64, 'Enhancement', 'Mail', 'Hands', 4, 100, 'ToC 25H - Nobundo Grips'),
(48339, 252, 310, 64, 'Enhancement', 'Mail', 'Legs', 4, 100, 'ToC 25H - Nobundo War-Kilt'),
(48343, 252, 310, 64, 'Restoration', 'Mail', 'Head', 2, 100, 'ToC 25H - Nobundo Helm'),
(48345, 252, 310, 64, 'Restoration', 'Mail', 'Shoulder', 2, 100, 'ToC 25H - Nobundo Shoulderguards'),
(48341, 252, 310, 64, 'Restoration', 'Mail', 'Chest', 2, 100, 'ToC 25H - Nobundo Tunic'),
(48342, 252, 310, 64, 'Restoration', 'Mail', 'Hands', 2, 100, 'ToC 25H - Nobundo Handguards'),
(48344, 252, 310, 64, 'Restoration', 'Mail', 'Legs', 2, 100, 'ToC 25H - Nobundo Legguards');

-- ROGUE ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48228, 252, 310, 8, NULL, 'Leather', 'Head', 4, 100, 'ToC 25H - VanCleef Helmet'),
(48230, 252, 310, 8, NULL, 'Leather', 'Shoulder', 4, 100, 'ToC 25H - VanCleef Pauldrons'),
(48226, 252, 310, 8, NULL, 'Leather', 'Chest', 4, 100, 'ToC 25H - VanCleef Breastplate'),
(48227, 252, 310, 8, NULL, 'Leather', 'Hands', 4, 100, 'ToC 25H - VanCleef Gauntlets'),
(48229, 252, 310, 8, NULL, 'Leather', 'Legs', 4, 100, 'ToC 25H - VanCleef Legplates');

-- DRUID ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(48102, 252, 310, 128, 'Balance', 'Leather', 'Head', 4, 100, 'ToC 25H - Malfurion Cover'),
(48104, 252, 310, 128, 'Balance', 'Leather', 'Shoulder', 4, 100, 'ToC 25H - Malfurion Mantle'),
(48100, 252, 310, 128, 'Balance', 'Leather', 'Chest', 4, 100, 'ToC 25H - Malfurion Vestment'),
(48101, 252, 310, 128, 'Balance', 'Leather', 'Hands', 4, 100, 'ToC 25H - Malfurion Gloves'),
(48103, 252, 310, 128, 'Balance', 'Leather', 'Legs', 4, 100, 'ToC 25H - Malfurion Trousers'),
(48127, 252, 310, 128, 'Feral', 'Leather', 'Head', 5, 100, 'ToC 25H - Malfurion Headpiece'),
(48129, 252, 310, 128, 'Feral', 'Leather', 'Shoulder', 5, 100, 'ToC 25H - Malfurion Shoulderpads'),
(48125, 252, 310, 128, 'Feral', 'Leather', 'Chest', 5, 100, 'ToC 25H - Malfurion Raiment'),
(48126, 252, 310, 128, 'Feral', 'Leather', 'Hands', 5, 100, 'ToC 25H - Malfurion Handgrips'),
(48128, 252, 310, 128, 'Feral', 'Leather', 'Legs', 5, 100, 'ToC 25H - Malfurion Legguards'),
(48132, 252, 310, 128, 'Restoration', 'Leather', 'Head', 2, 100, 'ToC 25H - Malfurion Headguard'),
(48134, 252, 310, 128, 'Restoration', 'Leather', 'Shoulder', 2, 100, 'ToC 25H - Malfurion Pauldrons'),
(48130, 252, 310, 128, 'Restoration', 'Leather', 'Chest', 2, 100, 'ToC 25H - Malfurion Robes'),
(48131, 252, 310, 128, 'Restoration', 'Leather', 'Hands', 2, 100, 'ToC 25H - Malfurion Gauntlets'),
(48133, 252, 310, 128, 'Restoration', 'Leather', 'Legs', 2, 100, 'ToC 25H - Malfurion Leggings');

-- PRIEST ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(47914, 252, 310, 16, 'Shadow', 'Cloth', 'Head', 4, 100, 'ToC 25H - Velen Hood'),
(47916, 252, 310, 16, 'Shadow', 'Cloth', 'Shoulder', 4, 100, 'ToC 25H - Velen Mantle'),
(47912, 252, 310, 16, 'Shadow', 'Cloth', 'Chest', 4, 100, 'ToC 25H - Velen Raiments'),
(47913, 252, 310, 16, 'Shadow', 'Cloth', 'Hands', 4, 100, 'ToC 25H - Velen Handwraps'),
(47915, 252, 310, 16, 'Shadow', 'Cloth', 'Legs', 4, 100, 'ToC 25H - Velen Leggings'),
(47982, 252, 310, 16, 'Holy', 'Cloth', 'Head', 2, 100, 'ToC 25H - Velen Cowl'),
(47984, 252, 310, 16, 'Holy', 'Cloth', 'Shoulder', 2, 100, 'ToC 25H - Velen Shoulderpads'),
(47980, 252, 310, 16, 'Holy', 'Cloth', 'Chest', 2, 100, 'ToC 25H - Velen Robe'),
(47981, 252, 310, 16, 'Holy', 'Cloth', 'Hands', 2, 100, 'ToC 25H - Velen Gloves'),
(47983, 252, 310, 16, 'Holy', 'Cloth', 'Legs', 2, 100, 'ToC 25H - Velen Pants');

-- MAGE ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(47753, 252, 310, 256, NULL, 'Cloth', 'Head', 4, 100, 'ToC 25H - Khadgar Hood'),
(47755, 252, 310, 256, NULL, 'Cloth', 'Shoulder', 4, 100, 'ToC 25H - Khadgar Shoulderpads'),
(47751, 252, 310, 256, NULL, 'Cloth', 'Chest', 4, 100, 'ToC 25H - Khadgar Robe'),
(47752, 252, 310, 256, NULL, 'Cloth', 'Hands', 4, 100, 'ToC 25H - Khadgar Gloves'),
(47754, 252, 310, 256, NULL, 'Cloth', 'Legs', 4, 100, 'ToC 25H - Khadgar Leggings');

-- WARLOCK ToC 25H
INSERT INTO `dc_vault_loot_table` VALUES
(47805, 252, 310, 512, NULL, 'Cloth', 'Head', 4, 100, 'ToC 25H - Gul''dan Hood'),
(47807, 252, 310, 512, NULL, 'Cloth', 'Shoulder', 4, 100, 'ToC 25H - Gul''dan Shoulderpads'),
(47803, 252, 310, 512, NULL, 'Cloth', 'Chest', 4, 100, 'ToC 25H - Gul''dan Robe'),
(47804, 252, 310, 512, NULL, 'Cloth', 'Hands', 4, 100, 'ToC 25H - Gul''dan Gloves'),
(47806, 252, 310, 512, NULL, 'Cloth', 'Legs', 4, 100, 'ToC 25H - Gul''dan Leggings');

-- ========================================================================
-- ULDUAR 25 Hardmode - Item Level 239-252
-- ========================================================================

-- Universal Ulduar Weapons (All Classes)
INSERT INTO `dc_vault_loot_table` VALUES
(46097, 252, 310, 1023, NULL, 'Misc', 'Weapon', 4, 100, 'Ulduar 25H - Starshard Edge (2H Sword)'),
(46035, 252, 310, 1023, NULL, 'Misc', 'Weapon', 4, 100, 'Ulduar 25H - Hammer of Crushing Whispers'),
(46096, 252, 310, 1023, NULL, 'Misc', 'Weapon', 2, 100, 'Ulduar 25H - Sky Cleaver (Healer Mace)'),
(45877, 252, 310, 1023, NULL, 'Misc', 'Weapon', 4, 100, 'Ulduar 25H - The Executioner''s Vice'),
(46312, 252, 310, 1023, NULL, 'Misc', 'Shield', 1, 100, 'Ulduar 25H - Dragonslayer''s Brace');

-- Universal Ulduar Trinkets
INSERT INTO `dc_vault_loot_table` VALUES
(45931, 252, 310, 1023, NULL, 'Misc', 'Trinket', 4, 100, 'Ulduar 25H - Mjolnir Runestone'),
(45929, 252, 310, 1023, NULL, 'Misc', 'Trinket', 4, 100, 'Ulduar 25H - Sif''s Remembrance'),
(45518, 252, 310, 1023, NULL, 'Misc', 'Trinket', 2, 100, 'Ulduar 25H - Pandora''s Plea'),
(45516, 252, 310, 1023, NULL, 'Misc', 'Trinket', 1, 100, 'Ulduar 25H - Seed of Budding Carnage');

-- ========================================================================
-- NAXXRAMAS 25 - Item Level 213-226
-- ========================================================================

-- WARRIOR Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40546, 239, 310, 1, NULL, 'Plate', 'Head', 4, 100, 'Naxx 25 - Dreadnaught Helmet'),
(40548, 239, 310, 1, NULL, 'Plate', 'Shoulder', 4, 100, 'Naxx 25 - Dreadnaught Shoulderplates'),
(40544, 239, 310, 1, NULL, 'Plate', 'Chest', 4, 100, 'Naxx 25 - Dreadnaught Breastplate'),
(40545, 239, 310, 1, NULL, 'Plate', 'Hands', 4, 100, 'Naxx 25 - Dreadnaught Gauntlets'),
(40547, 239, 310, 1, NULL, 'Plate', 'Legs', 4, 100, 'Naxx 25 - Dreadnaught Legplates');

-- PALADIN Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40571, 239, 310, 2, 'Retribution', 'Plate', 'Head', 4, 100, 'Naxx 25 - Redemption Headpiece'),
(40573, 239, 310, 2, 'Retribution', 'Plate', 'Shoulder', 4, 100, 'Naxx 25 - Redemption Spaulders'),
(40569, 239, 310, 2, 'Retribution', 'Plate', 'Chest', 4, 100, 'Naxx 25 - Redemption Tunic'),
(40570, 239, 310, 2, 'Retribution', 'Plate', 'Hands', 4, 100, 'Naxx 25 - Redemption Gloves'),
(40572, 239, 310, 2, 'Retribution', 'Plate', 'Legs', 4, 100, 'Naxx 25 - Redemption Greaves'),
(40581, 239, 310, 2, 'Holy', 'Plate', 'Head', 2, 100, 'Naxx 25 - Redemption Faceguard'),
(40583, 239, 310, 2, 'Holy', 'Plate', 'Shoulder', 2, 100, 'Naxx 25 - Redemption Shoulderguards'),
(40579, 239, 310, 2, 'Holy', 'Plate', 'Chest', 2, 100, 'Naxx 25 - Redemption Battleplate'),
(40580, 239, 310, 2, 'Holy', 'Plate', 'Hands', 2, 100, 'Naxx 25 - Redemption Handguards'),
(40582, 239, 310, 2, 'Holy', 'Plate', 'Legs', 2, 100, 'Naxx 25 - Redemption Legplates');

-- DEATH KNIGHT Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40554, 239, 310, 32, NULL, 'Plate', 'Head', 4, 100, 'Naxx 25 - Scourgeborne Helmet'),
(40556, 239, 310, 32, NULL, 'Plate', 'Shoulder', 4, 100, 'Naxx 25 - Scourgeborne Shoulderplates'),
(40552, 239, 310, 32, NULL, 'Plate', 'Chest', 4, 100, 'Naxx 25 - Scourgeborne Battleplate'),
(40553, 239, 310, 32, NULL, 'Plate', 'Hands', 4, 100, 'Naxx 25 - Scourgeborne Gauntlets'),
(40555, 239, 310, 32, NULL, 'Plate', 'Legs', 4, 100, 'Naxx 25 - Scourgeborne Legplates');

-- HUNTER Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40505, 239, 310, 4, NULL, 'Mail', 'Head', 4, 100, 'Naxx 25 - Cryptstalker Headpiece'),
(40507, 239, 310, 4, NULL, 'Mail', 'Shoulder', 4, 100, 'Naxx 25 - Cryptstalker Spaulders'),
(40503, 239, 310, 4, NULL, 'Mail', 'Chest', 4, 100, 'Naxx 25 - Cryptstalker Tunic'),
(40504, 239, 310, 4, NULL, 'Mail', 'Hands', 4, 100, 'Naxx 25 - Cryptstalker Handguards'),
(40506, 239, 310, 4, NULL, 'Mail', 'Legs', 4, 100, 'Naxx 25 - Cryptstalker Legguards');

-- SHAMAN Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40514, 239, 310, 64, 'Elemental', 'Mail', 'Head', 4, 100, 'Naxx 25 - Worldbreaker Helmet'),
(40516, 239, 310, 64, 'Elemental', 'Mail', 'Shoulder', 4, 100, 'Naxx 25 - Worldbreaker Shoulderpads'),
(40512, 239, 310, 64, 'Elemental', 'Mail', 'Chest', 4, 100, 'Naxx 25 - Worldbreaker Hauberk'),
(40513, 239, 310, 64, 'Elemental', 'Mail', 'Hands', 4, 100, 'Naxx 25 - Worldbreaker Gloves'),
(40515, 239, 310, 64, 'Elemental', 'Mail', 'Legs', 4, 100, 'Naxx 25 - Worldbreaker Kilt'),
(40523, 239, 310, 64, 'Enhancement', 'Mail', 'Head', 4, 100, 'Naxx 25 - Worldbreaker Faceguard'),
(40525, 239, 310, 64, 'Enhancement', 'Mail', 'Shoulder', 4, 100, 'Naxx 25 - Worldbreaker Shoulderguards'),
(40521, 239, 310, 64, 'Enhancement', 'Mail', 'Chest', 4, 100, 'Naxx 25 - Worldbreaker Chestguard'),
(40522, 239, 310, 64, 'Enhancement', 'Mail', 'Hands', 4, 100, 'Naxx 25 - Worldbreaker Handguards'),
(40524, 239, 310, 64, 'Enhancement', 'Mail', 'Legs', 4, 100, 'Naxx 25 - Worldbreaker Legguards'),
(40528, 239, 310, 64, 'Restoration', 'Mail', 'Head', 2, 100, 'Naxx 25 - Worldbreaker Headpiece'),
(40530, 239, 310, 64, 'Restoration', 'Mail', 'Shoulder', 2, 100, 'Naxx 25 - Worldbreaker Spaulders'),
(40526, 239, 310, 64, 'Restoration', 'Mail', 'Chest', 2, 100, 'Naxx 25 - Worldbreaker Tunic'),
(40527, 239, 310, 64, 'Restoration', 'Mail', 'Hands', 2, 100, 'Naxx 25 - Worldbreaker Grips'),
(40529, 239, 310, 64, 'Restoration', 'Mail', 'Legs', 2, 100, 'Naxx 25 - Worldbreaker War-Kilt');

-- ROGUE Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40499, 239, 310, 8, NULL, 'Leather', 'Head', 4, 100, 'Naxx 25 - Bonescythe Helmet'),
(40501, 239, 310, 8, NULL, 'Leather', 'Shoulder', 4, 100, 'Naxx 25 - Bonescythe Pauldrons'),
(40495, 239, 310, 8, NULL, 'Leather', 'Chest', 4, 100, 'Naxx 25 - Bonescythe Breastplate'),
(40496, 239, 310, 8, NULL, 'Leather', 'Hands', 4, 100, 'Naxx 25 - Bonescythe Gauntlets'),
(40500, 239, 310, 8, NULL, 'Leather', 'Legs', 4, 100, 'Naxx 25 - Bonescythe Legplates');

-- DRUID Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40467, 239, 310, 128, 'Balance', 'Leather', 'Head', 4, 100, 'Naxx 25 - Dreamwalker Cover'),
(40469, 239, 310, 128, 'Balance', 'Leather', 'Shoulder', 4, 100, 'Naxx 25 - Dreamwalker Mantle'),
(40465, 239, 310, 128, 'Balance', 'Leather', 'Chest', 4, 100, 'Naxx 25 - Dreamwalker Raiment'),
(40466, 239, 310, 128, 'Balance', 'Leather', 'Hands', 4, 100, 'Naxx 25 - Dreamwalker Gloves'),
(40468, 239, 310, 128, 'Balance', 'Leather', 'Legs', 4, 100, 'Naxx 25 - Dreamwalker Leggings'),
(40473, 239, 310, 128, 'Feral', 'Leather', 'Head', 5, 100, 'Naxx 25 - Dreamwalker Headpiece'),
(40494, 239, 310, 128, 'Feral', 'Leather', 'Shoulder', 5, 100, 'Naxx 25 - Dreamwalker Shoulderpads'),
(40471, 239, 310, 128, 'Feral', 'Leather', 'Chest', 5, 100, 'Naxx 25 - Dreamwalker Vest'),
(40472, 239, 310, 128, 'Feral', 'Leather', 'Hands', 5, 100, 'Naxx 25 - Dreamwalker Handguards'),
(40493, 239, 310, 128, 'Feral', 'Leather', 'Legs', 5, 100, 'Naxx 25 - Dreamwalker Legguards'),
(40460, 239, 310, 128, 'Restoration', 'Leather', 'Head', 2, 100, 'Naxx 25 - Dreamwalker Headguard'),
(40462, 239, 310, 128, 'Restoration', 'Leather', 'Shoulder', 2, 100, 'Naxx 25 - Dreamwalker Spaulders'),
(40458, 239, 310, 128, 'Restoration', 'Leather', 'Chest', 2, 100, 'Naxx 25 - Dreamwalker Robe'),
(40459, 239, 310, 128, 'Restoration', 'Leather', 'Hands', 2, 100, 'Naxx 25 - Dreamwalker Handgrips'),
(40461, 239, 310, 128, 'Restoration', 'Leather', 'Legs', 2, 100, 'Naxx 25 - Dreamwalker Leggings');

-- PRIEST Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40456, 239, 310, 16, 'Shadow', 'Cloth', 'Head', 4, 100, 'Naxx 25 - Deathwhisper Hood'),
(40450, 239, 310, 16, 'Shadow', 'Cloth', 'Shoulder', 4, 100, 'Naxx 25 - Deathwhisper Mantle'),
(40449, 239, 310, 16, 'Shadow', 'Cloth', 'Chest', 4, 100, 'Naxx 25 - Deathwhisper Raiment'),
(40454, 239, 310, 16, 'Shadow', 'Cloth', 'Hands', 4, 100, 'Naxx 25 - Deathwhisper Gloves'),
(40448, 239, 310, 16, 'Shadow', 'Cloth', 'Legs', 4, 100, 'Naxx 25 - Deathwhisper Leggings'),
(40447, 239, 310, 16, 'Holy', 'Cloth', 'Head', 2, 100, 'Naxx 25 - Deathwhisper Cowl'),
(40457, 239, 310, 16, 'Holy', 'Cloth', 'Shoulder', 2, 100, 'Naxx 25 - Deathwhisper Shoulderpads'),
(40445, 239, 310, 16, 'Holy', 'Cloth', 'Chest', 2, 100, 'Naxx 25 - Deathwhisper Robe'),
(40446, 239, 310, 16, 'Holy', 'Cloth', 'Hands', 2, 100, 'Naxx 25 - Deathwhisper Handwraps'),
(40398, 239, 310, 16, 'Holy', 'Cloth', 'Legs', 2, 100, 'Naxx 25 - Deathwhisper Pants');

-- MAGE Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40416, 239, 310, 256, NULL, 'Cloth', 'Head', 4, 100, 'Naxx 25 - Frostfire Circlet'),
(40419, 239, 310, 256, NULL, 'Cloth', 'Shoulder', 4, 100, 'Naxx 25 - Frostfire Shoulderpads'),
(40418, 239, 310, 256, NULL, 'Cloth', 'Chest', 4, 100, 'Naxx 25 - Frostfire Robe'),
(40415, 239, 310, 256, NULL, 'Cloth', 'Hands', 4, 100, 'Naxx 25 - Frostfire Gloves'),
(40417, 239, 310, 256, NULL, 'Cloth', 'Legs', 4, 100, 'Naxx 25 - Frostfire Leggings');

-- WARLOCK Naxx 25
INSERT INTO `dc_vault_loot_table` VALUES
(40421, 239, 310, 512, NULL, 'Cloth', 'Head', 4, 100, 'Naxx 25 - Plagueheart Circlet'),
(40424, 239, 310, 512, NULL, 'Cloth', 'Shoulder', 4, 100, 'Naxx 25 - Plagueheart Shoulderpads'),
(40423, 239, 310, 512, NULL, 'Cloth', 'Chest', 4, 100, 'Naxx 25 - Plagueheart Robe'),
(40420, 239, 310, 512, NULL, 'Cloth', 'Hands', 4, 100, 'Naxx 25 - Plagueheart Gloves'),
(40422, 239, 310, 512, NULL, 'Cloth', 'Legs', 4, 100, 'Naxx 25 - Plagueheart Leggings');

-- ========================================================================
-- TOTAL: 300+ items covering all raids up to ilvl 310
-- Item Level Ranges:
--   Naxxramas 25: 213-226 (M+2 to M+7 equiv)
--   Ulduar 25H: 239-252 (M+8 to M+12 equiv)
--   ToC 25H: 245-258 (M+10 to M+14 equiv)
--   ICC 25H: 264-284 (M+15 to M+20 equiv)
--   RS 25H: 271-284 (M+17 to M+20 equiv)
--   Extended to 310 for future M+25+ content
-- ========================================================================
