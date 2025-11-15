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

-- ========================================================================
-- Table: dc_mplus_featured_dungeons
-- Purpose: Define which dungeons are active in each season's rotation
-- Referenced: MythicPlusRunManager.cpp (seasonal validation)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_featured_dungeons` (
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season from dc_mplus_seasons',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `sort_order` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Display order in UI',
  PRIMARY KEY (`season_id`, `map_id`),
  FOREIGN KEY (`season_id`) REFERENCES `dc_mplus_seasons`(`season_id`) ON DELETE CASCADE,
  FOREIGN KEY (`map_id`) REFERENCES `dc_dungeon_mythic_profile`(`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Featured dungeons per season for Mythic+ rotation';

-- ========================================================================
-- Table: dc_mplus_affix_schedule
-- Purpose: Weekly affix rotation per season
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
-- WotLK Dungeons
(574, 571, 3707.86, 2150.23, 36.76, 3.22), -- Utgarde Keep
(575, 571, 1267.24, -4857.3, 215.76, 3.22), -- Utgarde Pinnacle
(576, 571, 3782.89, 6965.23, 105.088, 6.14), -- The Nexus
(578, 571, 3782.89, 6965.23, 105.088, 6.14), -- The Oculus
(595, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Culling of Stratholme
(599, 571, 3707.86, 2150.23, 36.76, 3.22), -- Halls of Stone
(600, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Drak'Tharon Keep
(601, 571, 1267.24, -4857.3, 215.76, 3.22), -- Azjol-Nerub
(602, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Halls of Lightning
(604, 571, 3707.86, 2150.23, 36.76, 3.22), -- Gundrak
(608, 571, 1267.24, -4857.3, 215.76, 3.22), -- Violet Hold
(619, 571, 8922.12, -1005.4, 1039.02, 1.57), -- Ahn'kahet: The Old Kingdom
(632, 571, 5663.56, 2008.66, 798.05, 4.60), -- Forge of Souls
(658, 571, 5663.56, 2008.66, 798.05, 4.60), -- Pit of Saron
(668, 571, 5663.56, 2008.66, 798.05, 4.60)  -- Halls of Reflection
ON DUPLICATE KEY UPDATE `entrance_map`=`entrance_map`;

-- ========================================================================
-- SEED DATA: Season 1 featured dungeons (10 random WotLK dungeons)
-- ========================================================================
INSERT INTO `dc_mplus_featured_dungeons` (`season_id`, `map_id`, `sort_order`) VALUES
(1, 574, 1),  -- Utgarde Keep
(1, 575, 2),  -- Utgarde Pinnacle
(1, 576, 3),  -- The Nexus
(1, 578, 4),  -- The Oculus
(1, 599, 5),  -- Halls of Stone
(1, 600, 6),  -- Drak'Tharon Keep
(1, 601, 7),  -- Azjol-Nerub
(1, 602, 8),  -- Halls of Lightning
(1, 608, 9),  -- Violet Hold
(1, 619, 10)  -- Ahn'kahet: The Old Kingdom
ON DUPLICATE KEY UPDATE `season_id`=`season_id`;

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

-- ========================================================================
-- VERIFICATION QUERY
-- ========================================================================
SELECT 
    'dc_dungeon_entrances' AS table_name, 
    COUNT(*) AS row_count 
FROM dc_dungeon_entrances
UNION ALL
SELECT 
    'dc_mplus_featured_dungeons', 
    COUNT(*) 
FROM dc_mplus_featured_dungeons
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
