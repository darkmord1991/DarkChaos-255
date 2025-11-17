-- ========================================================================
-- DarkChaos Mythic+ System - World Database Schema
-- ========================================================================
-- Purpose: Core tables for Mythic/Mythic+ dungeon system
-- Database: acore_world
-- Author: DarkChaos Development Team
-- Date: November 2025
-- ========================================================================

USE acore_world;

-- ========================================================================
-- Table: dc_dungeon_mythic_profile
-- Purpose: Stores Mythic baseline configuration for every dungeon
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_dungeon_mythic_profile` (
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Map ID from Map.dbc',
  `name` VARCHAR(80) NOT NULL COMMENT 'Dungeon display name',
  `heroic_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Enable Heroic difficulty (difficulty 2)',
  `mythic_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Enable Mythic difficulty (difficulty 3)',
  `base_health_mult` FLOAT NOT NULL DEFAULT 1.25 COMMENT 'Mythic HP multiplier (1.25 = +25%)',
  `base_damage_mult` FLOAT NOT NULL DEFAULT 1.15 COMMENT 'Mythic damage multiplier (1.15 = +15%)',
  `heroic_level_normal` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Heroic normal mob level (0 = keep original)',
  `heroic_level_elite` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Heroic elite mob level (0 = keep original)',
  `heroic_level_boss` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Heroic boss level (0 = keep original)',
  `mythic_level_normal` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Mythic normal mob level (0 = keep original)',
  `mythic_level_elite` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Mythic elite mob level (0 = keep original)',
  `mythic_level_boss` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Mythic boss level (0 = keep original)',
  `death_budget` TINYINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'Max deaths allowed in Mythic',
  `wipe_budget` TINYINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'Max wipes allowed in Mythic',
  `loot_ilvl` INT UNSIGNED NOT NULL DEFAULT 219 COMMENT 'Base item level for Mythic loot',
  `token_reward` INT UNSIGNED NOT NULL DEFAULT 101000 COMMENT 'Mythic token item ID',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`map_id`),
  INDEX `idx_enabled` (`mythic_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic difficulty profiles for dungeons';

-- ========================================================================
-- Table: dc_mplus_seasons
-- Purpose: Defines seasonal rotation for Mythic+ dungeons
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_seasons` (
  `season_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique season identifier',
  `label` VARCHAR(40) NOT NULL COMMENT 'Season display name (e.g., "Season 1: Wrath of Winter")',
  `start_ts` BIGINT UNSIGNED NOT NULL COMMENT 'Season start timestamp (Unix)',
  `end_ts` BIGINT UNSIGNED NOT NULL COMMENT 'Season end timestamp (Unix)',
  `featured_dungeons` JSON NOT NULL COMMENT 'Array of featured dungeon map IDs for this season',
  `affix_schedule` JSON NOT NULL COMMENT 'Weekly affix rotation: [{week: 1, affixPairId: 1}, ...]',
  `reward_curve` JSON NOT NULL COMMENT 'Reward scaling per keystone level: {1: {ilvl: 216, tokens: 30}, ...}',
  `is_active` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Only one season can be active at a time',
  PRIMARY KEY (`season_id`),
  INDEX `idx_active` (`is_active`),
  INDEX `idx_time_range` (`start_ts`, `end_ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Seasonal Mythic+ rotation and configuration';

-- ========================================================================
-- Table: dc_mplus_affix_pairs
-- Purpose: Defines affix combinations for Mythic+
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_affix_pairs` (
  `pair_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique affix pair identifier',
  `name` VARCHAR(60) NOT NULL COMMENT 'Pair display name (e.g., "Tyrannical + Bolstering")',
  `boss_affix_id` INT UNSIGNED NOT NULL COMMENT 'Boss-focused affix spell ID',
  `trash_affix_id` INT UNSIGNED NOT NULL COMMENT 'Trash-focused affix spell ID',
  `description` TEXT COMMENT 'Player-facing description of combined effects',
  PRIMARY KEY (`pair_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Affix pair definitions for weekly rotation';

-- ========================================================================
-- Table: dc_mplus_affixes
-- Purpose: Individual affix spell definitions
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_affixes` (
  `affix_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique affix identifier',
  `name` VARCHAR(40) NOT NULL COMMENT 'Affix name (e.g., "Tyrannical-Lite")',
  `type` ENUM('boss', 'trash') NOT NULL COMMENT 'Target type: boss or trash',
  `spell_id` INT UNSIGNED NOT NULL COMMENT 'Spell ID to apply',
  `description` TEXT COMMENT 'Player-facing description',
  `enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Enable/disable affix',
  PRIMARY KEY (`affix_id`),
  INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Individual affix definitions';

-- ========================================================================
-- Seed data: Example affixes
-- ========================================================================
INSERT INTO `dc_mplus_affixes` (`affix_id`, `name`, `type`, `spell_id`, `description`, `enabled`) VALUES
(1, 'Tyrannical-Lite', 'boss', 800101, 'Bosses have +15% HP and deal +10% damage', 1),
(2, 'Brutal Aura', 'boss', 800102, 'Bosses periodically deal raid-wide damage', 1),
(3, 'Fortified-Lite', 'trash', 800103, 'Non-boss enemies have +12% HP', 1),
(4, 'Bolstering-Lite', 'trash', 800104, 'Nearby enemies gain +5% damage when an ally dies', 1)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Seed data: Example affix pairs
-- ========================================================================
INSERT INTO `dc_mplus_affix_pairs` (`pair_id`, `name`, `boss_affix_id`, `trash_affix_id`, `description`) VALUES
(1, 'Tyrannical + Fortified', 1, 3, 'Bosses hit harder, trash is tankier'),
(2, 'Brutal + Bolstering', 2, 4, 'Boss AoE pressure plus trash scaling on death')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Table: dc_mplus_teleporter_npcs
-- Purpose: NPC spawn data for Mythic+ teleporter hub
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_teleporter_npcs` (
  `entry` INT UNSIGNED NOT NULL COMMENT 'NPC entry from creature_template',
  `name` VARCHAR(60) NOT NULL COMMENT 'NPC display name',
  `subname` VARCHAR(60) DEFAULT NULL COMMENT 'NPC subtitle',
  `purpose` VARCHAR(100) COMMENT 'NPC function description',
  `gossip_menu_id` INT UNSIGNED DEFAULT NULL COMMENT 'Gossip menu ID',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic+ hub NPC definitions';

-- ========================================================================
-- Seed data: Core NPCs
-- ========================================================================
INSERT INTO `dc_mplus_teleporter_npcs` (`entry`, `name`, `subname`, `purpose`, `gossip_menu_id`) VALUES
(99001, 'Mythic Steward Alendra', 'Dungeon Access', 'Main teleporter for Normal/Heroic/Mythic dungeons', 99001),
(100050, 'Vault Curator Lyra', 'Great Vault Keeper', 'Weekly vault reward NPC', 100050),
(100060, 'Archivist Serah', 'Statistics Keeper', 'Mythic+ performance and leaderboard NPC', 100060),
(120345, 'Seasonal Quartermaster', 'Token Vendor', 'Mythic+ currency vendor', 120345)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Creature templates: bind scripts for Great Vault + Token Vendor
-- ========================================================================
DELETE FROM `creature_template` WHERE `entry` IN (100050, 120345);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(100050, 0, 0, 0, 0, 0, 'Vault Curator Lyra', 'Great Vault Keeper', '', 0, 80, 80, 0, 35, 4097, 1, 1.14286, 1, 1, 0, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'npc_mythic_plus_great_vault', 0),
(100051, 0, 0, 0, 0, 0, 'Seasonal Quartermaster', 'Mythic+ Token Vendor', '', 0, 80, 80, 0, 35, 4097, 1, 1.14286, 1, 1, 0, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'npc_mythic_token_vendor', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (100050, 100051);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(100050, 0, 30259, 1, 1, 0),
(100051, 0, 30259, 1, 1, 0);

-- ========================================================================
-- Table: dc_mplus_final_bosses
-- Purpose: Maps each dungeon to its final boss entries for token payouts
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_final_bosses` (
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `boss_entry` INT UNSIGNED NOT NULL COMMENT 'Creature entry for the final boss variant',
  PRIMARY KEY (`map_id`, `boss_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Final boss lookups for Mythic+ token rewards';

INSERT INTO `dc_mplus_final_bosses` (`map_id`, `boss_entry`) VALUES
(574, 23954), -- Ingvar the Plunderer (Normal)
(574, 31673), -- Ingvar the Plunderer (Heroic)
(575, 26861), -- King Ymiron (Normal)
(575, 30788), -- King Ymiron (Heroic)
(576, 26723), -- Keristrasza (Normal)
(576, 30540), -- Keristrasza (Heroic)
(578, 27656), -- Ley-Guardian Eregos
(595, 26533), -- Mal'Ganis
(599, 27978), -- Sjonnir the Ironshaper
(600, 26632), -- The Prophet Tharon'ja
(601, 29120), -- Anub'arak
(602, 28923), -- Loken
(604, 29306), -- Gal'darah
(608, 31134), -- Cyanigosa
(619, 29311), -- Herald Volazj
(632, 36502), -- Devourer of Souls
(650, 35451), -- The Black Knight
(658, 36658), -- Scourgelord Tyrannus
(668, 36954)  -- The Lich King (Escape event)
ON DUPLICATE KEY UPDATE `boss_entry` = VALUES(`boss_entry`);

-- ========================================================================
-- Seed data: Vanilla Dungeons (Expansion 0)
-- ========================================================================
INSERT INTO `dc_dungeon_mythic_profile` (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`, `base_health_mult`, `base_damage_mult`, `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
-- Eastern Kingdoms Vanilla Dungeons (Mythic: 3x HP, 2x Damage for level 80-82)
(36, 'Deadmines', 1, 1, 3.0, 2.0, 10, 3, 200, 101000),
(33, 'Shadowfang Keep', 1, 1, 3.0, 2.0, 10, 3, 202, 101000),
(34, 'The Stockade', 1, 1, 3.0, 2.0, 10, 3, 198, 101000),
(48, 'Blackfathom Deeps', 1, 1, 3.0, 2.0, 12, 3, 204, 101000),
(43, 'Wailing Caverns', 1, 1, 3.0, 2.0, 12, 3, 202, 101000),
(47, 'Razorfen Kraul', 1, 1, 3.0, 2.0, 12, 3, 206, 101000),
(129, 'Razorfen Downs', 1, 1, 3.0, 2.0, 12, 3, 208, 101000),
(90, 'Gnomeregan', 1, 1, 3.0, 2.0, 15, 3, 210, 101000),
(109, 'Sunken Temple', 1, 1, 3.0, 2.0, 15, 3, 212, 101000),
(70, 'Uldaman', 1, 1, 3.0, 2.0, 15, 3, 214, 101000),
(189, 'Scarlet Monastery', 1, 1, 3.0, 2.0, 12, 3, 206, 101000),
(209, 'Zul\'Farrak', 1, 1, 3.0, 2.0, 15, 3, 212, 101000),
(349, 'Maraudon', 1, 1, 3.0, 2.0, 18, 4, 214, 101000),
-- High-level Vanilla Dungeons
(230, 'Blackrock Depths', 1, 1, 3.0, 2.0, 20, 4, 219, 101000),
(229, 'Lower Blackrock Spire', 1, 1, 3.0, 2.0, 18, 4, 219, 101000),
(329, 'Stratholme', 1, 1, 3.0, 2.0, 20, 4, 219, 101000),
(429, 'Dire Maul', 1, 1, 3.0, 2.0, 18, 4, 217, 101000),
(289, 'Scholomance', 1, 1, 3.0, 2.0, 18, 4, 219, 101000)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Seed data: TBC Dungeons (Expansion 1)
-- ========================================================================
INSERT INTO `dc_dungeon_mythic_profile` (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`, `base_health_mult`, `base_damage_mult`, `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
-- Hellfire Citadel wing dungeons (Mythic: 3x HP, 2x Damage for level 80-82)
(542, 'The Blood Furnace', 1, 1, 3.0, 2.0, 12, 3, 219, 101001),
(543, 'Hellfire Ramparts', 1, 1, 3.0, 2.0, 12, 3, 219, 101001),
(540, 'The Shattered Halls', 1, 1, 3.0, 2.0, 15, 3, 226, 101001),
-- Coilfang Reservoir
(545, 'The Steamvault', 1, 1, 3.0, 2.0, 15, 3, 226, 101001),
(546, 'The Underbog', 1, 1, 3.0, 2.0, 12, 3, 219, 101001),
(547, 'The Slave Pens', 1, 1, 3.0, 2.0, 12, 3, 219, 101001),
-- Auchindoun
(555, 'Shadow Labyrinth', 1, 1, 3.0, 2.0, 18, 4, 232, 101001),
(556, 'Sethekk Halls', 1, 1, 3.0, 2.0, 15, 3, 226, 101001),
(557, 'Mana-Tombs', 1, 1, 3.0, 2.0, 15, 3, 226, 101001),
(558, 'Auchenai Crypts', 1, 1, 3.0, 2.0, 12, 3, 219, 101001),
-- Tempest Keep dungeons
(553, 'The Botanica', 1, 1, 3.0, 2.0, 15, 3, 232, 101001),
(554, 'The Mechanar', 1, 1, 3.0, 2.0, 15, 3, 232, 101001),
(552, 'The Arcatraz', 1, 1, 3.0, 2.0, 18, 4, 232, 101001),
-- Caverns of Time
(560, 'Old Hillsbrad Foothills', 1, 1, 3.0, 2.0, 15, 3, 226, 101001),
(269, 'The Black Morass', 1, 1, 3.0, 2.0, 18, 4, 232, 101001),
-- Standalone TBC dungeons
(585, 'Magisters\' Terrace', 1, 1, 3.0, 2.0, 15, 3, 239, 101001)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Seed data: WotLK Dungeons (Expansion 2)
-- ========================================================================
INSERT INTO `dc_dungeon_mythic_profile` (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`, `base_health_mult`, `base_damage_mult`, `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
-- WotLK 5-man dungeons (Mythic: 1.35x HP, 1.20x Damage - modest boost from Heroic)
(574, 'Utgarde Keep', 1, 1, 1.35, 1.20, 12, 3, 200, 101002),
(575, 'Utgarde Pinnacle', 1, 1, 1.35, 1.20, 15, 3, 219, 101002),
(576, 'The Nexus', 1, 1, 1.35, 1.20, 12, 3, 200, 101002),
(578, 'The Oculus', 1, 1, 1.35, 1.20, 18, 4, 200, 101002),
(595, 'The Culling of Stratholme', 1, 1, 1.35, 1.20, 15, 3, 200, 101002),
(599, 'Halls of Stone', 1, 1, 1.35, 1.20, 15, 3, 200, 101002),
(600, 'Drak\'Tharon Keep', 1, 1, 1.35, 1.20, 15, 3, 200, 101002),
(601, 'Azjol-Nerub', 1, 1, 1.35, 1.20, 12, 3, 200, 101002),
(602, 'Halls of Lightning', 1, 1, 1.35, 1.20, 15, 3, 219, 101002),
(604, 'Gundrak', 1, 1, 1.35, 1.20, 15, 3, 200, 101002),
(608, 'Violet Hold', 1, 1, 1.35, 1.20, 12, 3, 200, 101002),
(619, 'Ahn\'kahet: The Old Kingdom', 1, 1, 1.35, 1.20, 15, 3, 200, 101002),
-- ICC 5-mans (higher tuning)
(632, 'The Forge of Souls', 1, 1, 1.35, 1.20, 10, 3, 219, 101002),
(658, 'Pit of Saron', 1, 1, 1.35, 1.20, 15, 3, 219, 101002),
(668, 'Halls of Reflection', 1, 1, 1.35, 1.20, 18, 4, 219, 101002),
-- Trial of the Champion
(650, 'Trial of the Champion', 1, 1, 1.35, 1.20, 12, 3, 200, 101002)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- ========================================================================
-- Complete
-- ========================================================================
