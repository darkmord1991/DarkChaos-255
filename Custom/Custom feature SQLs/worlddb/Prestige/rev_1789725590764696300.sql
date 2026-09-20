-- DarkChaos-255 Prestige Talents: challenges (a second account-wide point source) and the reward track.
-- Read at startup by src/server/scripts/DC/Progression/Prestige/dc_prestige_talents.cpp.

-- Achievements that add prestige talent points to the account pool.
-- Each achievement counts once per account, however many characters earn it.
CREATE TABLE IF NOT EXISTS `dc_prestige_talent_challenges` (
  `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Achievement.dbc ID',
  `points` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Prestige talent points granted to the account',
  `category` VARCHAR(32) NOT NULL DEFAULT 'General' COMMENT 'Challenges tab grouping',
  `sort_order` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prestige talent point sources (achievements)';

-- Cosmetic rewards unlocked by the account's total prestige talent points (spent or not).
CREATE TABLE IF NOT EXISTS `dc_prestige_talent_rewards` (
  `threshold` SMALLINT UNSIGNED NOT NULL COMMENT 'Account points needed',
  `item_entry` INT UNSIGNED NOT NULL,
  `item_count` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `reward_type` VARCHAR(16) NOT NULL DEFAULT 'item' COMMENT 'mount / pet / tabard / item (display only)',
  PRIMARY KEY (`threshold`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prestige talent reward track';

DELETE FROM `dc_prestige_talent_challenges`;
INSERT INTO `dc_prestige_talent_challenges` (`achievement_id`, `points`, `category`, `sort_order`) VALUES
-- Progression
(10701, 1, 'Progression', 101), -- Level 150
(10702, 1, 'Progression', 102), -- Level 200
(10703, 2, 'Progression', 103), -- Level 255
(10601, 2, 'Progression', 104), -- Hardcore Legend
(10603, 2, 'Progression', 105), -- Iron Legend
-- Mythic+ (granted by dc_mythicplus_run_manager.cpp)
(60001, 1, 'Mythic+', 201),     -- Mythic Initiate: first Mythic+2
(60005, 2, 'Mythic+', 202),     -- Flawless Victory: Mythic+5 without deaths
(60006, 3, 'Mythic+', 203),     -- Deathless Ascent: Mythic+10 without deaths
-- Raids
(4396, 1, 'Raids', 301),        -- Onyxia's Lair (10 player)
(4397, 1, 'Raids', 302),        -- Onyxia's Lair (25 player)
(576, 1, 'Raids', 303),         -- The Fall of Naxxramas (10 player)
(577, 1, 'Raids', 304),         -- The Fall of Naxxramas (25 player)
(1876, 1, 'Raids', 305),        -- Besting the Black Dragonflight (10 player)
(625, 1, 'Raids', 306),         -- Besting the Black Dragonflight (25 player)
(622, 1, 'Raids', 307),         -- The Spellweaver's Downfall (10 player)
(623, 1, 'Raids', 308),         -- The Spellweaver's Downfall (25 player)
(2894, 1, 'Raids', 309),        -- The Secrets of Ulduar (10 player)
(2895, 1, 'Raids', 310),        -- The Secrets of Ulduar (25 player)
(3917, 1, 'Raids', 311),        -- Call of the Crusade (10 player)
(3916, 1, 'Raids', 312),        -- Call of the Crusade (25 player)
(4530, 1, 'Raids', 313),        -- The Frozen Throne (10 player)
(4597, 1, 'Raids', 314),        -- The Frozen Throne (25 player)
(4817, 1, 'Raids', 315),        -- The Twilight Destroyer (10 player)
(4815, 1, 'Raids', 316),        -- The Twilight Destroyer (25 player)
-- Dungeons & Quests
(10101, 2, 'Dungeons & Quests', 401), -- Custom Dungeon Master
(10802, 2, 'Dungeons & Quests', 402), -- Custom Quest Master
(10002, 1, 'Dungeons & Quests', 403), -- Azshara Crater Quests
(10004, 1, 'Dungeons & Quests', 404), -- Hyjal Quests
-- PvP
(10202, 2, 'PvP', 501),         -- Hinterlands Hero
(10204, 1, 'PvP', 502),         -- Flag Master
-- Collections
(10401, 1, 'Collections', 601), -- Mount Master
(10403, 1, 'Collections', 602), -- Pet Master
(10405, 1, 'Collections', 603); -- The Titled

DELETE FROM `dc_prestige_talent_rewards`;
INSERT INTO `dc_prestige_talent_rewards` (`threshold`, `item_entry`, `item_count`, `reward_type`) VALUES
(10, 49343, 1, 'pet'),    -- Spectral Tiger Cub
(20, 38310, 1, 'tabard'), -- Tabard of the Arcane
(35, 49283, 1, 'mount'),  -- Reins of the Spectral Tiger
(50, 49284, 1, 'mount'),  -- Reins of the Swift Spectral Tiger
(75, 38312, 1, 'tabard'); -- Tabard of Brilliance
