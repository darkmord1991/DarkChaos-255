-- =====================================================================
-- DUNGEON QUEST SYSTEM v4.0 - WORLD DATABASE COMPLETE
-- =====================================================================
-- Purpose: All world database tables and data for dungeon quest system
-- Version: 4.0 (Complete)
-- Database: acore_world
-- Date: November 3, 2025
-- 
-- This file consolidates:
-- - EXTENSION_01_difficulty_support.sql (world tables only)
-- - EXTENSION_02_expanded_quest_pool.sql (quest mappings)
-- - EXTENSION_03_dungeon_quest_achievements.sql (achievements - DBC only, not SQL)
-- - EXTENSION_04_npc_mapping.sql (dungeon NPC mapping)
-- 
-- Installation Order: Run this FIRST, then chardb file
-- =====================================================================

-- =====================================================================
-- SECTION 0: DROP EXISTING TABLES (CLEAN INSTALL)
-- =====================================================================

DROP TABLE IF EXISTS `dc_quest_difficulty_mapping`;
DROP TABLE IF EXISTS `dc_character_difficulty_completions`;
DROP TABLE IF EXISTS `dc_character_difficulty_streaks`;
DROP TABLE IF EXISTS `dc_difficulty_config`;
DROP TABLE IF EXISTS `dc_dungeon_npc_mapping`;

-- =====================================================================
-- SECTION 1: DIFFICULTY SYSTEM TABLES
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1: Difficulty Configuration Table
-- ---------------------------------------------------------------------

CREATE TABLE `dc_difficulty_config` (
  `difficulty_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `difficulty_name` ENUM('Normal','Heroic','Mythic','Mythic+') NOT NULL,
  `display_name` VARCHAR(50) NOT NULL COMMENT 'Display name for players',
  `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `token_multiplier` DECIMAL(4,2) NOT NULL DEFAULT 1.00 COMMENT 'Token reward multiplier',
  `gold_multiplier` DECIMAL(4,2) NOT NULL DEFAULT 1.00 COMMENT 'Gold reward multiplier',
  `xp_multiplier` DECIMAL(4,2) NOT NULL DEFAULT 1.00 COMMENT 'XP reward multiplier',
  `min_group_size` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Minimum players required',
  `max_group_size` TINYINT UNSIGNED NOT NULL DEFAULT 5 COMMENT 'Maximum group size',
  `time_limit_minutes` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = no limit',
  `deaths_allowed` TINYINT UNSIGNED NOT NULL DEFAULT 255 COMMENT '255 = unlimited',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=active, 0=disabled',
  `sort_order` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`difficulty_id`),
  UNIQUE KEY `difficulty_name` (`difficulty_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='v4.0 - Difficulty tier configuration';

-- Insert difficulty tiers with multipliers
INSERT INTO `dc_difficulty_config` 
(`difficulty_id`, `difficulty_name`, `display_name`, `min_level`, `token_multiplier`, `gold_multiplier`, `xp_multiplier`, `min_group_size`, `max_group_size`, `time_limit_minutes`, `deaths_allowed`, `enabled`, `sort_order`)
VALUES
(0, 'Normal',   'Normal',   1,  1.00, 1.00, 1.00, 1, 5, 0,   255, 1, 0),
(1, 'Heroic',   'Heroic',   70, 1.50, 1.25, 1.25, 1, 5, 60,  10,  1, 1),
(2, 'Mythic',   'Mythic',   80, 2.00, 1.50, 1.50, 3, 5, 45,  5,   1, 2),
(3, 'Mythic+',  'Mythic+',  80, 3.00, 2.00, 2.00, 5, 5, 30,  0,   1, 3)
ON DUPLICATE KEY UPDATE
  `token_multiplier` = VALUES(`token_multiplier`),
  `gold_multiplier` = VALUES(`gold_multiplier`),
  `xp_multiplier` = VALUES(`xp_multiplier`);

-- ---------------------------------------------------------------------
-- 1.2: Quest Difficulty Mapping Table
-- ---------------------------------------------------------------------

CREATE TABLE `dc_quest_difficulty_mapping` (
  `mapping_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `quest_id` INT UNSIGNED NOT NULL COMMENT 'Quest entry from quest_template',
  `dungeon_id` INT UNSIGNED NOT NULL COMMENT 'Map ID or zone ID',
  `difficulty` ENUM('Normal','Heroic','Mythic','Mythic+') NOT NULL DEFAULT 'Normal' COMMENT 'Difficulty tier name',
  `base_token_reward` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `base_gold_reward` INT UNSIGNED NOT NULL DEFAULT 0,
  `requires_group` TINYINT(1) NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`mapping_id`),
  UNIQUE KEY `quest_id` (`quest_id`),
  KEY `dungeon_id` (`dungeon_id`),
  KEY `difficulty` (`difficulty`),
  KEY `is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='v4.0 - Maps quests to dungeons and difficulties';

-- =====================================================================
-- SECTION 2: DUNGEON NPC MAPPING TABLE
-- =====================================================================

CREATE TABLE `dc_dungeon_npc_mapping` (
    `map_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Dungeon map ID from Map.dbc',
    `quest_master_entry` INT UNSIGNED NOT NULL COMMENT 'Quest master NPC creature entry (700000-700052)',
    `dungeon_name` VARCHAR(100) NOT NULL COMMENT 'Human-readable dungeon name',
    `expansion` TINYINT UNSIGNED DEFAULT 0 COMMENT '0=Classic, 1=TBC, 2=WotLK, 3=Cata',
    `min_level` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Recommended minimum level',
    `max_level` TINYINT UNSIGNED DEFAULT 80 COMMENT 'Recommended maximum level',
    `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Is this dungeon quest system enabled?',
    
    INDEX `idx_quest_master` (`quest_master_entry`),
    INDEX `idx_expansion` (`expansion`, `enabled`)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='v4.0 - Maps dungeon map IDs to quest master NPCs';

-- Insert dungeon mappings
INSERT INTO `dc_dungeon_npc_mapping` (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`) VALUES
-- Classic Dungeons
(389, 700000, 'Ragefire Chasm', 0, 13, 18),
(36,  700001, 'The Deadmines', 0, 17, 26),
(48,  700002, 'Blackfathom Deeps', 0, 20, 30),
(34,  700003, 'The Stockade', 0, 22, 30),
(43,  700004, 'Wailing Caverns', 0, 17, 24),
(47,  700005, 'Razorfen Kraul', 0, 30, 40),
(90,  700006, 'Gnomeregan', 0, 24, 34),
(189, 700007, 'Scarlet Monastery', 0, 30, 45),
(129, 700008, 'Razorfen Downs', 0, 40, 50),
(70,  700009, 'Uldaman', 0, 42, 52),
(209, 700010, 'Zul\'Farrak', 0, 44, 54),
(349, 700011, 'Maraudon', 0, 46, 55),
(109, 700012, 'The Temple of Atal\'Hakkar (Sunken Temple)', 0, 50, 60),
(229, 700013, 'Blackrock Depths', 0, 52, 60),
(230, 700014, 'Blackrock Spire', 0, 55, 60),
(329, 700015, 'Stratholme', 0, 58, 60),
(429, 700016, 'Dire Maul', 0, 58, 60),
(33,  700017, 'Shadowfang Keep', 0, 22, 30),
-- TBC Dungeons
(530, 700020, 'Hellfire Citadel: Hellfire Ramparts', 1, 60, 62),
(542, 700021, 'Hellfire Citadel: The Blood Furnace', 1, 61, 63),
(543, 700022, 'Hellfire Citadel: The Shattered Halls', 1, 70, 70),
(540, 700023, 'Coilfang Reservoir: The Slave Pens', 1, 62, 64),
(547, 700024, 'Coilfang Reservoir: The Underbog', 1, 63, 65),
(545, 700025, 'Coilfang Reservoir: The Steamvault', 1, 70, 70),
(546, 700026, 'Tempest Keep: The Mechanar', 1, 69, 70),
(553, 700027, 'Tempest Keep: The Botanica', 1, 70, 70),
(554, 700028, 'Tempest Keep: The Arcatraz', 1, 70, 70),
(555, 700029, 'Auchindoun: Mana-Tombs', 1, 64, 66),
(556, 700030, 'Auchindoun: Auchenai Crypts', 1, 65, 67),
(557, 700031, 'Auchindoun: Sethekk Halls', 1, 67, 69),
(558, 700032, 'Auchindoun: Shadow Labyrinth', 1, 70, 70),
(269, 700033, 'Caverns of Time: Old Hillsbrad Foothills', 1, 66, 68),
(560, 700034, 'Caverns of Time: The Black Morass', 1, 70, 70),
(585, 700035, 'Magisters\' Terrace', 1, 70, 70),
-- WotLK Dungeons
(574, 700040, 'Utgarde Keep', 2, 70, 72),
(575, 700041, 'Utgarde Pinnacle', 2, 80, 80),
(576, 700042, 'The Nexus', 2, 71, 73),
(578, 700043, 'The Oculus', 2, 80, 80),
(599, 700044, 'Halls of Stone', 2, 77, 79),
(600, 700045, 'Halls of Lightning', 2, 80, 80),
(601, 700046, 'Azjol-Nerub', 2, 72, 74),
(602, 700047, 'Ahn\'kahet: The Old Kingdom', 2, 73, 75),
(604, 700048, 'Gundrak', 2, 76, 78),
(608, 700049, 'The Violet Hold', 2, 75, 77),
(619, 700050, 'Drak\'Tharon Keep', 2, 74, 76),
(632, 700051, 'The Forge of Souls', 2, 80, 80),
(658, 700052, 'The Pit of Saron', 2, 80, 80);

-- =====================================================================
-- SECTION 3: QUEST DIFFICULTY MAPPINGS (435 quests)
-- =====================================================================
-- Daily Quests: 700101-700150 (50 quests)
-- Weekly Quests: 700201-700224 (24 quests)
-- Dungeon Quests: 700701-701037 (337 quests)
-- =====================================================================

-- Daily Quest Mappings (50 quests, mixed difficulties)
INSERT INTO `dc_quest_difficulty_mapping` 
(`quest_id`, `dungeon_id`, `difficulty`, `base_token_reward`, `base_gold_reward`, `requires_group`, `is_active`)
VALUES
-- Week 1 Rotation
(700101, 389, 'Normal', 1, 500, 0, 1),   -- RFC Normal
(700102, 48,  'Heroic', 1, 600, 0, 1),   -- BFD Heroic
(700103, 90,  'Mythic', 1, 700, 1, 1),   -- Gnomeregan Mythic
(700104, 33,  'Mythic+', 1, 800, 1, 1),   -- SFK Mythic+
(700105, 189, 'Normal', 1, 600, 0, 1),   -- Scarlet Monastery Normal
(700106, 36,  'Heroic', 1, 550, 0, 1),   -- Deadmines Heroic
(700107, 34,  'Normal', 1, 500, 0, 1),   -- Stockade Normal
-- Week 2 Rotation
(700108, 43,  'Mythic', 1, 700, 1, 1),   -- Wailing Caverns Mythic
(700109, 47,  'Normal', 1, 600, 0, 1),   -- RFK Normal
(700110, 129, 'Heroic', 1, 650, 0, 1),   -- RFD Heroic
(700111, 70,  'Mythic', 1, 750, 1, 1),   -- Uldaman Mythic
(700112, 209, 'Mythic+', 1, 850, 1, 1),   -- Zul'Farrak Mythic+
(700113, 349, 'Normal', 1, 700, 0, 1),   -- Maraudon Normal
(700114, 109, 'Heroic', 1, 750, 0, 1),   -- Sunken Temple Heroic
-- Week 3 Rotation
(700115, 229, 'Mythic', 1, 800, 1, 1),   -- BRD Mythic
(700116, 230, 'Mythic+', 1, 900, 1, 1),   -- UBRS Mythic+
(700117, 329, 'Heroic', 1, 750, 0, 1),   -- Stratholme Heroic
(700118, 429, 'Mythic', 1, 800, 1, 1),   -- Dire Maul Mythic
(700119, 389, 'Normal', 1, 500, 0, 1),   -- RFC Normal (repeat)
(700120, 48,  'Heroic', 1, 600, 0, 1),   -- BFD Heroic (repeat)
(700121, 90,  'Normal', 1, 550, 0, 1),   -- Gnomeregan Normal
-- Week 4 Rotation
(700122, 33,  'Mythic', 1, 700, 1, 1),   -- SFK Mythic
(700123, 189, 'Heroic', 1, 650, 0, 1),   -- SM Heroic
(700124, 36,  'Mythic', 1, 700, 1, 1),   -- Deadmines Mythic
(700125, 34,  'Normal', 1, 500, 0, 1),   -- Stockade Normal (repeat)
(700126, 43,  'Heroic', 1, 600, 0, 1),   -- WC Heroic
(700127, 47,  'Mythic', 1, 700, 1, 1),   -- RFK Mythic
(700128, 129, 'Mythic+', 1, 850, 1, 1),   -- RFD Mythic+
-- Week 5 Rotation
(700129, 70,  'Normal', 1, 650, 0, 1),   -- Uldaman Normal
(700130, 209, 'Heroic', 1, 700, 0, 1),   -- ZF Heroic
(700131, 349, 'Mythic', 1, 800, 1, 1),   -- Maraudon Mythic
(700132, 109, 'Mythic+', 1, 900, 1, 1),   -- ST Mythic+
(700133, 229, 'Normal', 1, 700, 0, 1),   -- BRD Normal
(700134, 230, 'Heroic', 1, 800, 0, 1),   -- UBRS Heroic
(700135, 329, 'Mythic', 1, 850, 1, 1),   -- Strat Mythic
-- Week 6 Rotation
(700136, 429, 'Mythic+', 1, 950, 1, 1),   -- DM Mythic+
(700137, 389, 'Heroic', 1, 550, 0, 1),   -- RFC Heroic
(700138, 48,  'Mythic', 1, 700, 1, 1),   -- BFD Mythic
(700139, 90,  'Mythic+', 1, 850, 1, 1),   -- Gnomeregan Mythic+
(700140, 33,  'Normal', 1, 500, 0, 1),   -- SFK Normal
(700141, 189, 'Mythic', 1, 750, 1, 1),   -- SM Mythic
(700142, 36,  'Mythic+', 1, 850, 1, 1),   -- Deadmines Mythic+
-- Week 7 Rotation
(700143, 34,  'Heroic', 1, 550, 0, 1),   -- Stockade Heroic
(700144, 43,  'Mythic+', 1, 850, 1, 1),   -- WC Mythic+
(700145, 47,  'Normal', 1, 600, 0, 1),   -- RFK Normal (repeat)
(700146, 129, 'Heroic', 1, 650, 0, 1),   -- RFD Heroic (repeat)
(700147, 70,  'Mythic+', 1, 900, 1, 1),   -- Uldaman Mythic+
(700148, 209, 'Mythic', 1, 800, 1, 1),   -- ZF Mythic
(700149, 349, 'Heroic', 1, 750, 0, 1),   -- Maraudon Heroic
(700150, 109, 'Normal', 1, 700, 0, 1);   -- ST Normal

-- Weekly Quest Mappings (24 quests, higher difficulties)
INSERT INTO `dc_quest_difficulty_mapping` 
(`quest_id`, `dungeon_id`, `difficulty`, `base_token_reward`, `base_gold_reward`, `requires_group`, `is_active`)
VALUES
-- Week 1-4 Rotation (Mythic+ focus)
(700201, 229, 'Mythic+', 3, 1200, 1, 1),  -- BRD Mythic+
(700202, 230, 'Mythic+', 3, 1300, 1, 1),  -- UBRS Mythic+
(700203, 329, 'Mythic+', 3, 1200, 1, 1),  -- Strat Mythic+
(700204, 429, 'Mythic+', 3, 1400, 1, 1),  -- DM Mythic+
(700205, 389, 'Mythic', 2, 900, 1, 1),   -- RFC Mythic
(700206, 48,  'Mythic+', 3, 1100, 1, 1),  -- BFD Mythic+
-- Week 5-8 Rotation
(700207, 90,  'Mythic', 2, 950, 1, 1),   -- Gnomeregan Mythic
(700208, 33,  'Mythic+', 3, 1100, 1, 1),  -- SFK Mythic+
(700209, 189, 'Mythic', 2, 1000, 1, 1),  -- SM Mythic
(700210, 36,  'Mythic+', 3, 1050, 1, 1),  -- Deadmines Mythic+
(700211, 34,  'Mythic', 2, 850, 1, 1),   -- Stockade Mythic
(700212, 43,  'Mythic+', 3, 1100, 1, 1),  -- WC Mythic+
-- Week 9-12 Rotation
(700213, 47,  'Mythic', 2, 950, 1, 1),   -- RFK Mythic
(700214, 129, 'Mythic+', 3, 1150, 1, 1),  -- RFD Mythic+
(700215, 70,  'Mythic', 2, 1000, 1, 1),  -- Uldaman Mythic
(700216, 209, 'Mythic+', 3, 1200, 1, 1),  -- ZF Mythic+
(700217, 349, 'Mythic', 2, 1050, 1, 1),  -- Maraudon Mythic
(700218, 109, 'Mythic+', 3, 1250, 1, 1),  -- ST Mythic+
-- Bonus rotation quests
(700219, 229, 'Mythic', 2, 1100, 1, 1),  -- BRD Mythic
(700220, 230, 'Mythic', 2, 1150, 1, 1),  -- UBRS Mythic
(700221, 329, 'Mythic', 2, 1100, 1, 1),  -- Strat Mythic
(700222, 429, 'Mythic', 2, 1200, 1, 1),  -- DM Mythic
(700223, 389, 'Mythic+', 3, 1000, 1, 1),  -- RFC Mythic+
(700224, 48,  'Mythic', 2, 950, 1, 1);   -- BFD Mythic

-- Dungeon Quest Mappings (337 quests across all dungeons and difficulties)
-- Format: Quest ranges per dungeon, 4 difficulties each (Normal, Heroic, Mythic, Mythic+)

INSERT INTO `dc_quest_difficulty_mapping`
(`quest_id`, `dungeon_id`, `difficulty`, `base_token_reward`, `base_gold_reward`, `requires_group`, `is_active`)
VALUES
-- Ragefire Chasm (700701-700718) - 18 quests
(700701, 389, 'Normal', 1, 300, 0, 1), (700702, 389, 'Normal', 1, 300, 0, 1), (700703, 389, 'Normal', 1, 300, 0, 1), (700704, 389, 'Normal', 1, 300, 0, 1), (700705, 389, 'Heroic', 1, 450, 0, 1), (700706, 389, 'Heroic', 1, 450, 0, 1), (700707, 389, 'Heroic', 1, 450, 0, 1), (700708, 389, 'Heroic', 1, 450, 0, 1), (700709, 389, 'Mythic', 2, 600, 1, 1), (700710, 389, 'Mythic', 2, 600, 1, 1), (700711, 389, 'Mythic', 2, 600, 1, 1), (700712, 389, 'Mythic', 2, 600, 1, 1), (700713, 389, 'Mythic+', 3, 900, 1, 1), (700714, 389, 'Mythic+', 3, 900, 1, 1), (700715, 389, 'Mythic+', 3, 900, 1, 1), (700716, 389, 'Mythic+', 3, 900, 1, 1), (700717, 389, 'Normal', 1, 300, 0, 1), (700718, 389, 'Heroic', 1, 450, 0, 1),

-- Deadmines (700719-700736) - 18 quests
(700719, 36, 'Normal', 1, 350, 0, 1), (700720, 36, 'Normal', 1, 350, 0, 1), (700721, 36, 'Normal', 1, 350, 0, 1), (700722, 36, 'Normal', 1, 350, 0, 1), (700723, 36, 'Heroic', 1, 500, 0, 1), (700724, 36, 'Heroic', 1, 500, 0, 1), (700725, 36, 'Heroic', 1, 500, 0, 1), (700726, 36, 'Heroic', 1, 500, 0, 1), (700727, 36, 'Mythic', 2, 700, 1, 1), (700728, 36, 'Mythic', 2, 700, 1, 1), (700729, 36, 'Mythic', 2, 700, 1, 1), (700730, 36, 'Mythic', 2, 700, 1, 1), (700731, 36, 'Mythic+', 3, 1000, 1, 1), (700732, 36, 'Mythic+', 3, 1000, 1, 1), (700733, 36, 'Mythic+', 3, 1000, 1, 1), (700734, 36, 'Mythic+', 3, 1000, 1, 1), (700735, 36, 'Normal', 1, 350, 0, 1), (700736, 36, 'Heroic', 1, 500, 0, 1),

-- Blackfathom Deeps (700737-700754) - 18 quests
(700737, 48, 'Normal', 1, 400, 0, 1), (700738, 48, 'Normal', 1, 400, 0, 1), (700739, 48, 'Normal', 1, 400, 0, 1), (700740, 48, 'Normal', 1, 400, 0, 1), (700741, 48, 'Heroic', 1, 550, 0, 1), (700742, 48, 'Heroic', 1, 550, 0, 1), (700743, 48, 'Heroic', 1, 550, 0, 1), (700744, 48, 'Heroic', 1, 550, 0, 1), (700745, 48, 'Mythic', 2, 750, 1, 1), (700746, 48, 'Mythic', 2, 750, 1, 1), (700747, 48, 'Mythic', 2, 750, 1, 1), (700748, 48, 'Mythic', 2, 750, 1, 1), (700749, 48, 'Mythic+', 3, 1100, 1, 1), (700750, 48, 'Mythic+', 3, 1100, 1, 1), (700751, 48, 'Mythic+', 3, 1100, 1, 1), (700752, 48, 'Mythic+', 3, 1100, 1, 1), (700753, 48, 'Normal', 1, 400, 0, 1), (700754, 48, 'Heroic', 1, 550, 0, 1),

-- Stockade (700755-700772) - 18 quests
(700755, 34, 'Normal', 1, 350, 0, 1), (700756, 34, 'Normal', 1, 350, 0, 1), (700757, 34, 'Normal', 1, 350, 0, 1), (700758, 34, 'Normal', 1, 350, 0, 1), (700759, 34, 'Heroic', 1, 500, 0, 1), (700760, 34, 'Heroic', 1, 500, 0, 1), (700761, 34, 'Heroic', 1, 500, 0, 1), (700762, 34, 'Heroic', 1, 500, 0, 1), (700763, 34, 'Mythic', 2, 700, 1, 1), (700764, 34, 'Mythic', 2, 700, 1, 1), (700765, 34, 'Mythic', 2, 700, 1, 1), (700766, 34, 'Mythic', 2, 700, 1, 1), (700767, 34, 'Mythic+', 3, 1000, 1, 1), (700768, 34, 'Mythic+', 3, 1000, 1, 1), (700769, 34, 'Mythic+', 3, 1000, 1, 1), (700770, 34, 'Mythic+', 3, 1000, 1, 1), (700771, 34, 'Normal', 1, 350, 0, 1), (700772, 34, 'Heroic', 1, 500, 0, 1),

-- Wailing Caverns (700773-700790) - 18 quests
(700773, 43, 'Normal', 1, 350, 0, 1), (700774, 43, 'Normal', 1, 350, 0, 1), (700775, 43, 'Normal', 1, 350, 0, 1), (700776, 43, 'Normal', 1, 350, 0, 1), (700777, 43, 'Heroic', 1, 500, 0, 1), (700778, 43, 'Heroic', 1, 500, 0, 1), (700779, 43, 'Heroic', 1, 500, 0, 1), (700780, 43, 'Heroic', 1, 500, 0, 1), (700781, 43, 'Mythic', 2, 700, 1, 1), (700782, 43, 'Mythic', 2, 700, 1, 1), (700783, 43, 'Mythic', 2, 700, 1, 1), (700784, 43, 'Mythic', 2, 700, 1, 1), (700785, 43, 'Mythic+', 3, 1000, 1, 1), (700786, 43, 'Mythic+', 3, 1000, 1, 1), (700787, 43, 'Mythic+', 3, 1000, 1, 1), (700788, 43, 'Mythic+', 3, 1000, 1, 1), (700789, 43, 'Normal', 1, 350, 0, 1), (700790, 43, 'Heroic', 1, 500, 0, 1),

-- Razorfen Kraul (700791-700808) - 18 quests
(700791, 47, 'Normal', 1, 450, 0, 1), (700792, 47, 'Normal', 1, 450, 0, 1), (700793, 47, 'Normal', 1, 450, 0, 1), (700794, 47, 'Normal', 1, 450, 0, 1), (700795, 47, 'Heroic', 1, 600, 0, 1), (700796, 47, 'Heroic', 1, 600, 0, 1), (700797, 47, 'Heroic', 1, 600, 0, 1), (700798, 47, 'Heroic', 1, 600, 0, 1), (700799, 47, 'Mythic', 2, 850, 1, 1), (700800, 47, 'Mythic', 2, 850, 1, 1), (700801, 47, 'Mythic', 2, 850, 1, 1), (700802, 47, 'Mythic', 2, 850, 1, 1), (700803, 47, 'Mythic+', 3, 1200, 1, 1), (700804, 47, 'Mythic+', 3, 1200, 1, 1), (700805, 47, 'Mythic+', 3, 1200, 1, 1), (700806, 47, 'Mythic+', 3, 1200, 1, 1), (700807, 47, 'Normal', 1, 450, 0, 1), (700808, 47, 'Heroic', 1, 600, 0, 1),

-- Gnomeregan (700809-700826) - 18 quests
(700809, 90, 'Normal', 1, 400, 0, 1), (700810, 90, 'Normal', 1, 400, 0, 1), (700811, 90, 'Normal', 1, 400, 0, 1), (700812, 90, 'Normal', 1, 400, 0, 1), (700813, 90, 'Heroic', 1, 550, 0, 1), (700814, 90, 'Heroic', 1, 550, 0, 1), (700815, 90, 'Heroic', 1, 550, 0, 1), (700816, 90, 'Heroic', 1, 550, 0, 1), (700817, 90, 'Mythic', 2, 750, 1, 1), (700818, 90, 'Mythic', 2, 750, 1, 1), (700819, 90, 'Mythic', 2, 750, 1, 1), (700820, 90, 'Mythic', 2, 750, 1, 1), (700821, 90, 'Mythic+', 3, 1100, 1, 1), (700822, 90, 'Mythic+', 3, 1100, 1, 1), (700823, 90, 'Mythic+', 3, 1100, 1, 1), (700824, 90, 'Mythic+', 3, 1100, 1, 1), (700825, 90, 'Normal', 1, 400, 0, 1), (700826, 90, 'Heroic', 1, 550, 0, 1),

-- Scarlet Monastery (700827-700844) - 18 quests
(700827, 189, 'Normal', 1, 500, 0, 1), (700828, 189, 'Normal', 1, 500, 0, 1), (700829, 189, 'Normal', 1, 500, 0, 1), (700830, 189, 'Normal', 1, 500, 0, 1), (700831, 189, 'Heroic', 1, 650, 0, 1), (700832, 189, 'Heroic', 1, 650, 0, 1), (700833, 189, 'Heroic', 1, 650, 0, 1), (700834, 189, 'Heroic', 1, 650, 0, 1), (700835, 189, 'Mythic', 2, 900, 1, 1), (700836, 189, 'Mythic', 2, 900, 1, 1), (700837, 189, 'Mythic', 2, 900, 1, 1), (700838, 189, 'Mythic', 2, 900, 1, 1), (700839, 189, 'Mythic+', 3, 1300, 1, 1), (700840, 189, 'Mythic+', 3, 1300, 1, 1), (700841, 189, 'Mythic+', 3, 1300, 1, 1), (700842, 189, 'Mythic+', 3, 1300, 1, 1), (700843, 189, 'Normal', 1, 500, 0, 1), (700844, 189, 'Heroic', 1, 650, 0, 1),

-- Razorfen Downs (700845-700862) - 18 quests
(700845, 129, 'Normal', 1, 550, 0, 1), (700846, 129, 'Normal', 1, 550, 0, 1), (700847, 129, 'Normal', 1, 550, 0, 1), (700848, 129, 'Normal', 1, 550, 0, 1), (700849, 129, 'Heroic', 1, 700, 0, 1), (700850, 129, 'Heroic', 1, 700, 0, 1), (700851, 129, 'Heroic', 1, 700, 0, 1), (700852, 129, 'Heroic', 1, 700, 0, 1), (700853, 129, 'Mythic', 2, 950, 1, 1), (700854, 129, 'Mythic', 2, 950, 1, 1), (700855, 129, 'Mythic', 2, 950, 1, 1), (700856, 129, 'Mythic', 2, 950, 1, 1), (700857, 129, 'Mythic+', 3, 1400, 1, 1), (700858, 129, 'Mythic+', 3, 1400, 1, 1), (700859, 129, 'Mythic+', 3, 1400, 1, 1), (700860, 129, 'Mythic+', 3, 1400, 1, 1), (700861, 129, 'Normal', 1, 550, 0, 1), (700862, 129, 'Heroic', 1, 700, 0, 1),

-- Uldaman (700863-700880) - 18 quests
(700863, 70, 'Normal', 1, 600, 0, 1), (700864, 70, 'Normal', 1, 600, 0, 1), (700865, 70, 'Normal', 1, 600, 0, 1), (700866, 70, 'Normal', 1, 600, 0, 1), (700867, 70, 'Heroic', 1, 750, 0, 1), (700868, 70, 'Heroic', 1, 750, 0, 1), (700869, 70, 'Heroic', 1, 750, 0, 1), (700870, 70, 'Heroic', 1, 750, 0, 1), (700871, 70, 'Mythic', 2, 1000, 1, 1), (700872, 70, 'Mythic', 2, 1000, 1, 1), (700873, 70, 'Mythic', 2, 1000, 1, 1), (700874, 70, 'Mythic', 2, 1000, 1, 1), (700875, 70, 'Mythic+', 3, 1500, 1, 1), (700876, 70, 'Mythic+', 3, 1500, 1, 1), (700877, 70, 'Mythic+', 3, 1500, 1, 1), (700878, 70, 'Mythic+', 3, 1500, 1, 1), (700879, 70, 'Normal', 1, 600, 0, 1), (700880, 70, 'Heroic', 1, 750, 0, 1),

-- Zul'Farrak (700881-700898) - 18 quests
(700881, 209, 'Normal', 1, 650, 0, 1), (700882, 209, 'Normal', 1, 650, 0, 1), (700883, 209, 'Normal', 1, 650, 0, 1), (700884, 209, 'Normal', 1, 650, 0, 1), (700885, 209, 'Heroic', 1, 800, 0, 1), (700886, 209, 'Heroic', 1, 800, 0, 1), (700887, 209, 'Heroic', 1, 800, 0, 1), (700888, 209, 'Heroic', 1, 800, 0, 1), (700889, 209, 'Mythic', 2, 1100, 1, 1), (700890, 209, 'Mythic', 2, 1100, 1, 1), (700891, 209, 'Mythic', 2, 1100, 1, 1), (700892, 209, 'Mythic', 2, 1100, 1, 1), (700893, 209, 'Mythic+', 3, 1600, 1, 1), (700894, 209, 'Mythic+', 3, 1600, 1, 1), (700895, 209, 'Mythic+', 3, 1600, 1, 1), (700896, 209, 'Mythic+', 3, 1600, 1, 1), (700897, 209, 'Normal', 1, 650, 0, 1), (700898, 209, 'Heroic', 1, 800, 0, 1),

-- Maraudon (700899-700916) - 18 quests
(700899, 349, 'Normal', 1, 700, 0, 1), (700900, 349, 'Normal', 1, 700, 0, 1), (700901, 349, 'Normal', 1, 700, 0, 1), (700902, 349, 'Normal', 1, 700, 0, 1), (700903, 349, 'Heroic', 1, 850, 0, 1), (700904, 349, 'Heroic', 1, 850, 0, 1), (700905, 349, 'Heroic', 1, 850, 0, 1), (700906, 349, 'Heroic', 1, 850, 0, 1), (700907, 349, 'Mythic', 2, 1150, 1, 1), (700908, 349, 'Mythic', 2, 1150, 1, 1), (700909, 349, 'Mythic', 2, 1150, 1, 1), (700910, 349, 'Mythic', 2, 1150, 1, 1), (700911, 349, 'Mythic+', 3, 1700, 1, 1), (700912, 349, 'Mythic+', 3, 1700, 1, 1), (700913, 349, 'Mythic+', 3, 1700, 1, 1), (700914, 349, 'Mythic+', 3, 1700, 1, 1), (700915, 349, 'Normal', 1, 700, 0, 1), (700916, 349, 'Heroic', 1, 850, 0, 1),

-- Sunken Temple (700917-700934) - 18 quests
(700917, 109, 'Normal', 1, 750, 0, 1), (700918, 109, 'Normal', 1, 750, 0, 1), (700919, 109, 'Normal', 1, 750, 0, 1), (700920, 109, 'Normal', 1, 750, 0, 1), (700921, 109, 'Heroic', 1, 900, 0, 1), (700922, 109, 'Heroic', 1, 900, 0, 1), (700923, 109, 'Heroic', 1, 900, 0, 1), (700924, 109, 'Heroic', 1, 900, 0, 1), (700925, 109, 'Mythic', 2, 1200, 1, 1), (700926, 109, 'Mythic', 2, 1200, 1, 1), (700927, 109, 'Mythic', 2, 1200, 1, 1), (700928, 109, 'Mythic', 2, 1200, 1, 1), (700929, 109, 'Mythic+', 3, 1800, 1, 1), (700930, 109, 'Mythic+', 3, 1800, 1, 1), (700931, 109, 'Mythic+', 3, 1800, 1, 1), (700932, 109, 'Mythic+', 3, 1800, 1, 1), (700933, 109, 'Normal', 1, 750, 0, 1), (700934, 109, 'Heroic', 1, 900, 0, 1),

-- Blackrock Depths (700935-700952) - 18 quests
(700935, 229, 'Normal', 1, 800, 0, 1), (700936, 229, 'Normal', 1, 800, 0, 1), (700937, 229, 'Normal', 1, 800, 0, 1), (700938, 229, 'Normal', 1, 800, 0, 1), (700939, 229, 'Heroic', 1, 1000, 0, 1), (700940, 229, 'Heroic', 1, 1000, 0, 1), (700941, 229, 'Heroic', 1, 1000, 0, 1), (700942, 229, 'Heroic', 1, 1000, 0, 1), (700943, 229, 'Mythic', 2, 1300, 1, 1), (700944, 229, 'Mythic', 2, 1300, 1, 1), (700945, 229, 'Mythic', 2, 1300, 1, 1), (700946, 229, 'Mythic', 2, 1300, 1, 1), (700947, 229, 'Mythic+', 3, 1900, 1, 1), (700948, 229, 'Mythic+', 3, 1900, 1, 1), (700949, 229, 'Mythic+', 3, 1900, 1, 1), (700950, 229, 'Mythic+', 3, 1900, 1, 1), (700951, 229, 'Normal', 1, 800, 0, 1), (700952, 229, 'Heroic', 1, 1000, 0, 1),

-- Blackrock Spire (700953-700970) - 18 quests
(700953, 230, 'Normal', 1, 850, 0, 1), (700954, 230, 'Normal', 1, 850, 0, 1), (700955, 230, 'Normal', 1, 850, 0, 1), (700956, 230, 'Normal', 1, 850, 0, 1), (700957, 230, 'Heroic', 1, 1100, 0, 1), (700958, 230, 'Heroic', 1, 1100, 0, 1), (700959, 230, 'Heroic', 1, 1100, 0, 1), (700960, 230, 'Heroic', 1, 1100, 0, 1), (700961, 230, 'Mythic', 2, 1400, 1, 1), (700962, 230, 'Mythic', 2, 1400, 1, 1), (700963, 230, 'Mythic', 2, 1400, 1, 1), (700964, 230, 'Mythic', 2, 1400, 1, 1), (700965, 230, 'Mythic+', 3, 2000, 1, 1), (700966, 230, 'Mythic+', 3, 2000, 1, 1), (700967, 230, 'Mythic+', 3, 2000, 1, 1), (700968, 230, 'Mythic+', 3, 2000, 1, 1), (700969, 230, 'Normal', 1, 850, 0, 1), (700970, 230, 'Heroic', 1, 1100, 0, 1),

-- Stratholme (700971-700988) - 18 quests
(700971, 329, 'Normal', 1, 900, 0, 1), (700972, 329, 'Normal', 1, 900, 0, 1), (700973, 329, 'Normal', 1, 900, 0, 1), (700974, 329, 'Normal', 1, 900, 0, 1), (700975, 329, 'Heroic', 1, 1150, 0, 1), (700976, 329, 'Heroic', 1, 1150, 0, 1), (700977, 329, 'Heroic', 1, 1150, 0, 1), (700978, 329, 'Heroic', 1, 1150, 0, 1), (700979, 329, 'Mythic', 2, 1450, 1, 1), (700980, 329, 'Mythic', 2, 1450, 1, 1), (700981, 329, 'Mythic', 2, 1450, 1, 1), (700982, 329, 'Mythic', 2, 1450, 1, 1), (700983, 329, 'Mythic+', 3, 2100, 1, 1), (700984, 329, 'Mythic+', 3, 2100, 1, 1), (700985, 329, 'Mythic+', 3, 2100, 1, 1), (700986, 329, 'Mythic+', 3, 2100, 1, 1), (700987, 329, 'Normal', 1, 900, 0, 1), (700988, 329, 'Heroic', 1, 1150, 0, 1),

-- Dire Maul (700989-701006) - 18 quests
(700989, 429, 'Normal', 1, 950, 0, 1), (700990, 429, 'Normal', 1, 950, 0, 1), (700991, 429, 'Normal', 1, 950, 0, 1), (700992, 429, 'Normal', 1, 950, 0, 1), (700993, 429, 'Heroic', 1, 1200, 0, 1), (700994, 429, 'Heroic', 1, 1200, 0, 1), (700995, 429, 'Heroic', 1, 1200, 0, 1), (700996, 429, 'Heroic', 1, 1200, 0, 1), (700997, 429, 'Mythic', 2, 1500, 1, 1), (700998, 429, 'Mythic', 2, 1500, 1, 1), (700999, 429, 'Mythic', 2, 1500, 1, 1), (701000, 429, 'Mythic', 2, 1500, 1, 1), (701001, 429, 'Mythic+', 3, 2200, 1, 1), (701002, 429, 'Mythic+', 3, 2200, 1, 1), (701003, 429, 'Mythic+', 3, 2200, 1, 1), (701004, 429, 'Mythic+', 3, 2200, 1, 1), (701005, 429, 'Normal', 1, 950, 0, 1), (701006, 429, 'Heroic', 1, 1200, 0, 1),

-- Shadowfang Keep (701007-701024) - 18 quests
(701007, 33, 'Normal', 1, 400, 0, 1), (701008, 33, 'Normal', 1, 400, 0, 1), (701009, 33, 'Normal', 1, 400, 0, 1), (701010, 33, 'Normal', 1, 400, 0, 1), (701011, 33, 'Heroic', 1, 550, 0, 1), (701012, 33, 'Heroic', 1, 550, 0, 1), (701013, 33, 'Heroic', 1, 550, 0, 1), (701014, 33, 'Heroic', 1, 550, 0, 1), (701015, 33, 'Mythic', 2, 750, 1, 1), (701016, 33, 'Mythic', 2, 750, 1, 1), (701017, 33, 'Mythic', 2, 750, 1, 1), (701018, 33, 'Mythic', 2, 750, 1, 1), (701019, 33, 'Mythic+', 3, 1100, 1, 1), (701020, 33, 'Mythic+', 3, 1100, 1, 1), (701021, 33, 'Mythic+', 3, 1100, 1, 1), (701022, 33, 'Mythic+', 3, 1100, 1, 1), (701023, 33, 'Normal', 1, 400, 0, 1), (701024, 33, 'Heroic', 1, 550, 0, 1),

-- Additional 13 quests to reach 337 total (701025-701037)
(701025, 389, 'Mythic', 2, 600, 1, 1), (701026, 36, 'Mythic', 2, 700, 1, 1), (701027, 48, 'Mythic+', 3, 1100, 1, 1), (701028, 34, 'Mythic+', 3, 1000, 1, 1), (701029, 43, 'Mythic', 2, 700, 1, 1), (701030, 47, 'Mythic+', 3, 1200, 1, 1), (701031, 90, 'Mythic', 2, 750, 1, 1), (701032, 189, 'Mythic+', 3, 1300, 1, 1), (701033, 129, 'Mythic', 2, 950, 1, 1), (701034, 70, 'Mythic+', 3, 1500, 1, 1), (701035, 209, 'Mythic', 2, 1100, 1, 1), (701036, 349, 'Mythic+', 3, 1700, 1, 1), (701037, 109, 'Mythic', 2, 1200, 1, 1);

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Verify difficulty config
SELECT * FROM dc_difficulty_config ORDER BY difficulty_id;

-- Count total quest mappings
SELECT 
    COUNT(*) AS total_quests,
    SUM(CASE WHEN quest_id BETWEEN 700101 AND 700150 THEN 1 ELSE 0 END) AS daily_quests,
    SUM(CASE WHEN quest_id BETWEEN 700201 AND 700224 THEN 1 ELSE 0 END) AS weekly_quests,
    SUM(CASE WHEN quest_id BETWEEN 700701 AND 701037 THEN 1 ELSE 0 END) AS dungeon_quests
FROM dc_quest_difficulty_mapping;

-- Count by difficulty
SELECT 
    difficulty,
    CASE difficulty
        WHEN 'Normal' THEN 'Normal'
        WHEN 'Heroic' THEN 'Heroic'
        WHEN 'Mythic' THEN 'Mythic'
        WHEN 'Mythic+' THEN 'Mythic+'
    END AS difficulty_name,
    COUNT(*) AS quest_count
FROM dc_quest_difficulty_mapping
GROUP BY difficulty
ORDER BY difficulty;

-- Verify dungeon NPC mappings
SELECT expansion, COUNT(*) AS dungeon_count 
FROM dc_dungeon_npc_mapping 
GROUP BY expansion;

-- =====================================================================
-- COMPLETION MESSAGE
-- =====================================================================

SELECT 'World Database v4.0 Installation Complete!' AS Status,
       (SELECT COUNT(*) FROM dc_difficulty_config) AS difficulty_tiers,
       (SELECT COUNT(*) FROM dc_quest_difficulty_mapping) AS total_quests,
       (SELECT COUNT(*) FROM dc_dungeon_npc_mapping) AS dungeon_mappings;

-- =====================================================================
-- NEXT STEP: Import character database file
-- =====================================================================
