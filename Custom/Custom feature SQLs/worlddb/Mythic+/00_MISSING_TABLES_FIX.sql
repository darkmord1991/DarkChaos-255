-- ========================================================================
-- CRITICAL FIX: Missing Mythic+ Tables
-- ========================================================================
-- Purpose: Create all missing tables referenced in code but not in schema
-- Date: November 15, 2025
-- Issue: 4 tables missing from implementation causing system failures
-- ========================================================================

USE acore_world;

-- ========================================================================
-- Table: dc_dungeon_entrances
-- Purpose: Store entrance coordinates for portal teleportation
-- Referenced: npc_dungeon_portal_selector.cpp (line 130-169)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_dungeon_entrances` (
  `dungeon_map` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID (same as in dc_dungeon_mythic_profile)',
  `entrance_map` INT UNSIGNED NOT NULL COMMENT 'Map where the entrance is located',
  `entrance_x` FLOAT NOT NULL COMMENT 'X coordinate of entrance',
  `entrance_y` FLOAT NOT NULL COMMENT 'Y coordinate of entrance',
  `entrance_z` FLOAT NOT NULL COMMENT 'Z coordinate of entrance',
  `entrance_o` FLOAT NOT NULL COMMENT 'Orientation at entrance',
  PRIMARY KEY (`dungeon_map`),
  FOREIGN KEY (`dungeon_map`) REFERENCES `dc_dungeon_mythic_profile`(`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Dungeon entrance coordinates for portal teleportation';

CREATE TABLE IF NOT EXISTS `dc_dungeon_setup` (
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `dungeon_name` VARCHAR(80) NOT NULL COMMENT 'Display name',
  `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT 'Expansion identifier (0=Vanilla, 1=TBC, 2=WotLK, ...)',
  `is_unlocked` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Global unlock gate',
  `normal_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Allow Normal queue/teleport',
  `heroic_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Allow Heroic difficulty',
  `heroic_scaling_mode` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Profile default, 1=Custom scaling, 2=No scaling overrides',
  `mythic_enabled` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Allow Mythic (non keystone)',
  `mythic_plus_enabled` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Allow Mythic+ keystones',
  `season_lock` INT UNSIGNED DEFAULT NULL COMMENT 'Optional season requirement (NULL = always)',
  `notes` VARCHAR(255) DEFAULT NULL COMMENT 'Optional admin notes',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`map_id`),
  FOREIGN KEY (`map_id`) REFERENCES `dc_dungeon_mythic_profile`(`map_id`) ON DELETE CASCADE,
  FOREIGN KEY (`season_lock`) REFERENCES `dc_mplus_seasons`(`season_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Unified dungeon availability toggles for Normal/Heroic/Mythic/Mythic+';

-- ========================================================================
-- Cleanup: legacy featured-dungeon table (replaced by dc_dungeon_setup)
-- ========================================================================
DROP TABLE IF EXISTS `dc_mplus_featured_dungeons`;

-- Referenced: MythicPlusRunManager.cpp (GetWeeklyAffixes)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_affix_schedule` (
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season from dc_mplus_seasons',
  `week_number` TINYINT UNSIGNED NOT NULL COMMENT 'Week of the season (0-51)',
  `affix1` TINYINT UNSIGNED NOT NULL COMMENT 'First affix ID (boss-focused)',
  `affix2` TINYINT UNSIGNED NOT NULL COMMENT 'Second affix ID (trash-focused)',
  PRIMARY KEY (`season_id`, `week_number`),
  FOREIGN KEY (`season_id`) REFERENCES `dc_mplus_seasons`(`season_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Weekly affix rotation schedule for Mythic+ seasons';

-- ========================================================================
-- Table: dc_mplus_final_bosses
-- Purpose: Define which creature entries are final bosses per dungeon
-- Referenced: MythicPlusRunManager.cpp (IsFinalBoss check)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_final_bosses` (
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `boss_entry` INT UNSIGNED NOT NULL COMMENT 'Creature entry of final boss',
  PRIMARY KEY (`map_id`, `boss_entry`),
  FOREIGN KEY (`map_id`) REFERENCES `dc_dungeon_mythic_profile`(`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Final boss definitions for dungeon completion tracking';

-- ========================================================================
-- SEED DATA: Sample entrances for WotLK dungeons
-- ========================================================================
INSERT INTO `dc_dungeon_entrances` (`dungeon_map`, `entrance_map`, `entrance_x`, `entrance_y`, `entrance_z`, `entrance_o`) VALUES
-- WotLK Dungeons - Updated coordinates from game data
(574, 571, 1206.940, -4868.050, 41.249, 0.280), -- Utgarde Keep
(575, 571, 1256.960, -4852.940, 215.550, 3.447), -- Utgarde Pinnacle (Utgarde Tower)
(576, 571, 5705.190, 517.960, 649.780, 4.031), -- The Nexus (Violet Citadel)
(578, 571, 3782.89, 6965.23, 105.088, 6.14), -- The Oculus (using old coordinates - not in update)
(595, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Culling of Stratholme (using old coordinates - not in update)
(599, 571, 8922.450, -1012.960, 1039.590, 1.563), -- Halls of Stone
(600, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Drak'Tharon Keep (using old coordinates - not in update)
(601, 571, 3700.870, 2152.580, 36.044, 3.596), -- Azjol-Nerub
(602, 571, 9105.720, -1319.860, 1058.390, 5.650), -- Halls of Lightning
(604, 571, 3707.86, 2150.23, 36.76, 3.22), -- Gundrak (using old coordinates - not in update)
(608, 571, 1267.24, -4857.3, 215.76, 3.22), -- Violet Hold (using old coordinates - not in update)
(619, 571, 3700.870, 2152.580, 36.044, 3.596), -- Ahn'kahet: The Old Kingdom
(632, 571, 5663.56, 2008.66, 798.05, 4.60), -- Forge of Souls
(658, 571, 5663.56, 2008.66, 798.05, 4.60), -- Pit of Saron
(668, 571, 5663.56, 2008.66, 798.05, 4.60)  -- Halls of Reflection
ON DUPLICATE KEY UPDATE `entrance_map`=`entrance_map`;

INSERT INTO `dc_dungeon_setup` (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`, `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
(36, 'Deadmines', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(33, 'Shadowfang Keep', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(34, 'The Stockade', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(48, 'Blackfathom Deeps', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(43, 'Wailing Caverns', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(47, 'Razorfen Kraul', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(129, 'Razorfen Downs', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(90, 'Gnomeregan', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(109, 'Sunken Temple', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(70, 'Uldaman', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(189, 'Scarlet Monastery', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(209, 'Zul''Farrak', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(349, 'Maraudon', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(230, 'Blackrock Depths', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(229, 'Lower Blackrock Spire', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(329, 'Stratholme', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(429, 'Dire Maul', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline'),
(289, 'Scholomance', 0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline')
ON DUPLICATE KEY UPDATE `is_unlocked`=VALUES(`is_unlocked`),
  `normal_enabled`=VALUES(`normal_enabled`),
  `heroic_enabled`=VALUES(`heroic_enabled`),
  `heroic_scaling_mode`=VALUES(`heroic_scaling_mode`),
  `mythic_enabled`=VALUES(`mythic_enabled`),
  `mythic_plus_enabled`=VALUES(`mythic_plus_enabled`),
  `season_lock`=VALUES(`season_lock`),
  `notes`=VALUES(`notes`);

-- ========================================================================
-- SEED DATA: TBC dungeon setup defaults
-- ========================================================================
INSERT INTO `dc_dungeon_setup` (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`, `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
(542, 'The Blood Furnace', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(543, 'Hellfire Ramparts', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(540, 'The Shattered Halls', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(545, 'The Steamvault', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(546, 'The Underbog', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(547, 'The Slave Pens', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(555, 'Shadow Labyrinth', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(556, 'Sethekk Halls', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(557, 'Mana-Tombs', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(558, 'Auchenai Crypts', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(553, 'The Botanica', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(554, 'The Mechanar', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(552, 'The Arcatraz', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(560, 'Old Hillsbrad Foothills', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(269, 'The Black Morass', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline'),
(585, 'Magisters'' Terrace', 1, 1, 1, 1, 0, 1, 0, NULL, 'Burning Crusade baseline')
ON DUPLICATE KEY UPDATE `is_unlocked`=VALUES(`is_unlocked`),
  `normal_enabled`=VALUES(`normal_enabled`),
  `heroic_enabled`=VALUES(`heroic_enabled`),
  `heroic_scaling_mode`=VALUES(`heroic_scaling_mode`),
  `mythic_enabled`=VALUES(`mythic_enabled`),
  `mythic_plus_enabled`=VALUES(`mythic_plus_enabled`),
  `season_lock`=VALUES(`season_lock`),
  `notes`=VALUES(`notes`);

-- ========================================================================
-- SEED DATA: WotLK dungeon setup defaults (heroic scaling disabled)
-- ========================================================================
INSERT INTO `dc_dungeon_setup` (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`, `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
(574, 'Utgarde Keep', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(575, 'Utgarde Pinnacle', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(576, 'The Nexus', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(578, 'The Oculus', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(595, 'The Culling of Stratholme', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(599, 'Halls of Stone', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(600, 'Drak''Tharon Keep', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(601, 'Azjol-Nerub', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(602, 'Halls of Lightning', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(604, 'Gundrak', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(608, 'The Violet Hold', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(619, 'Ahn''kahet: The Old Kingdom', 2, 1, 1, 1, 2, 1, 1, 1, 'Wrath launch lineup'),
(632, 'The Forge of Souls', 2, 1, 1, 1, 2, 1, 1, 1, 'ICC 5-player wing'),
(650, 'Trial of the Champion', 2, 1, 1, 1, 2, 1, 1, 1, 'Argent Tournament ground'),
(658, 'Pit of Saron', 2, 1, 1, 1, 2, 1, 1, 1, 'ICC 5-player wing'),
(668, 'Halls of Reflection', 2, 1, 1, 1, 2, 1, 1, 1, 'ICC 5-player wing')
ON DUPLICATE KEY UPDATE `heroic_scaling_mode`=VALUES(`heroic_scaling_mode`),
  `mythic_plus_enabled`=VALUES(`mythic_plus_enabled`),
  `season_lock`=VALUES(`season_lock`),
  `notes`=VALUES(`notes`);

-- ========================================================================
-- SEED DATA: Final boss entries for WotLK dungeons
-- ========================================================================
INSERT INTO `dc_mplus_final_bosses` (`map_id`, `boss_entry`) VALUES
-- Utgarde Keep
(574, 24201), -- Ingvar the Plunderer
-- Utgarde Pinnacle
(575, 26861), -- King Ymiron
-- The Nexus
(576, 26731), -- Keristrasza
-- The Oculus
(578, 27656), -- Ley-Guardian Eregos
-- Culling of Stratholme
(595, 26533), -- Mal'Ganis
-- Halls of Stone
(599, 27977), -- Sjonnir The Ironshaper
-- Drak'Tharon Keep
(600, 26632), -- The Prophet Tharon'ja
-- Azjol-Nerub
(601, 29120), -- Anub'arak (Azjol-Nerub)
-- Halls of Lightning
(602, 28923), -- Loken
-- Gundrak
(604, 29932), -- Gal'darah
-- Violet Hold
(608, 31134), -- Cyanigosa
-- Ahn'kahet: The Old Kingdom
(619, 30258), -- Herald Volazj
-- Forge of Souls
(632, 36502), -- Devourer of Souls
-- Pit of Saron
(658, 36494), -- Scourgelord Tyrannus
-- Halls of Reflection
(668, 38112)  -- The Lich King (Halls of Reflection encounter)
ON DUPLICATE KEY UPDATE `map_id`=`map_id`;

-- ========================================================================
-- SEED DATA: 12-week affix rotation for Season 1
-- ========================================================================
-- Note: Affixes reference dc_mplus_affixes: 1=Tyrannical-Lite, 2=Brutal Aura, 3=Fortified-Lite, 4=Bolstering-Lite
INSERT INTO `dc_mplus_affix_schedule` (`season_id`, `week_number`, `affix1`, `affix2`) VALUES
-- Week 0-3: Tyrannical + Bolstering
(1, 0, 1, 4),
(1, 1, 1, 4),
(1, 2, 1, 4),
(1, 3, 1, 4),
-- Week 4-7: Brutal + Fortified
(1, 4, 2, 3),
(1, 5, 2, 3),
(1, 6, 2, 3),
(1, 7, 2, 3),
-- Week 8-11: Tyrannical + Fortified
(1, 8, 1, 3),
(1, 9, 1, 3),
(1, 10, 1, 3),
(1, 11, 1, 3)
ON DUPLICATE KEY UPDATE `week_number`=`week_number`;

SELECT 
    'dc_dungeon_entrances' AS table_name, 
    COUNT(*) AS row_count 
FROM dc_dungeon_entrances
UNION ALL
SELECT 
    'dc_mplus_affix_schedule', 
    COUNT(*) 
FROM dc_mplus_affix_schedule
UNION ALL
SELECT 
    'dc_mplus_final_bosses', 
    COUNT(*) 
FROM dc_mplus_final_bosses;
