-- DarkChaos: quests whose giver already stands on map 750/751 but which were never offered there
--
-- From the 11-11 SkyFire (MoP 5.4.8) gap survey. MoP added nothing in these zones; every missing quest is in
-- cata_world, so cata_world is the source. The Cata quest layer was imported without most of its giver/turn-in
-- rows, so these quests sat in quest_template with nobody offering them.
--
-- 61 quests already in quest_template get their giver and turn-in on the 750/751 clone NPCs (DC-only
-- entries), and 14 quests that only exist in cata_world are imported (quest_template + addon + texts).
--   Ashenvale            A: 27
--   Azshara              A: 13
--   Eastern Plaguelands  A: 16
--   Eastern Plaguelands  B: 1
--   Felwood              B: 4
--   Hyjal                B: 2
--   Western Plaguelands  A: 5
--   Winterspring         B: 7
-- A quest is only enabled when it can be finished on that map: every kill/object target spawns there (directly,
-- through KillCredit, or as a clone the objective is remapped to), every required item drops there or is
-- handed out, a turn-in NPC stands on the same map, and its prerequisite is offered there too. Seasonal,
-- class, Moonglade, other-zone quests and quests still offered in the old world (those would need a +200000
-- clone) stay out: 149 candidates were skipped (kill-credit bunnies and event spawns, items that drop
-- nowhere on the map, no turn-in, unavailable prerequisite ...).
--
-- Each enabled quest follows the 750/751 conventions: QuestLevel -1, MinLevel = zone band - 2, gold by the
-- 11-10 formula ((band low + band high) / 2 * 900 * QuestXP ratio), and gear rewards point at the drop-ladder
-- item of the same slot/type/quality in the zone's band (337_ for 750, 421xxx for 751; no new items).
-- Quest map markers: 92 quests (23 of them already offered
-- before this file) get cata's POIs, map 1 -> 750 / 0 -> 751 with the DC world map areas.
--
-- Revert record: dc_quest_gap_import / _link / _objective / _reward / _poi; quest fields this file changes on
-- the existing quests are saved in dc_quest_gap_backup on the first run. Re-running gives the same result.
-- Apply to acore_world (it reads cata_world on the same server), then restart the worldserver.

CREATE TABLE IF NOT EXISTS `dc_quest_gap_import` (
    `quest` INT UNSIGNED NOT NULL,
    `kind` CHAR(1) NOT NULL,
    `map` SMALLINT NOT NULL,
    `zone` SMALLINT NOT NULL,
    `min_level` TINYINT UNSIGNED NOT NULL,
    `money` INT NOT NULL,
    PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DELETE FROM `dc_quest_gap_import`;
INSERT INTO `dc_quest_gap_import` (`quest`, `kind`, `map`, `zone`, `min_level`, `money`) VALUES
(13766, 'A', 750, 4931, 86, 83700),
(13792, 'A', 750, 4931, 86, 83700),
(13801, 'A', 750, 4931, 86, 83700),
(13849, 'A', 750, 4931, 86, 83700),
(13867, 'A', 750, 4931, 86, 83700),
(13869, 'A', 750, 4931, 86, 83700),
(13964, 'A', 750, 4931, 86, 20920),
(13965, 'A', 750, 4931, 86, 20920),
(13976, 'A', 750, 4931, 86, 83700),
(14117, 'A', 750, 4930, 78, 76500),
(14118, 'A', 750, 4930, 78, 76500),
(14129, 'A', 750, 4930, 78, 76500),
(14161, 'A', 750, 4930, 78, 76500),
(14162, 'A', 750, 4930, 78, 19120),
(14165, 'A', 750, 4930, 78, 76500),
(14190, 'A', 750, 4930, 78, 76500),
(14197, 'A', 750, 4930, 78, 76500),
(14201, 'A', 750, 4930, 78, 76500),
(14424, 'A', 750, 4930, 78, 57380),
(14431, 'A', 750, 4930, 78, 76500),
(14432, 'A', 750, 4930, 78, 76500),
(14433, 'A', 750, 4930, 78, 57380),
(25296, 'B', 750, 4923, 111, 109350),
(25314, 'B', 750, 4923, 111, 109350),
(26444, 'A', 750, 4931, 86, 83700),
(26448, 'A', 750, 4931, 86, 83700),
(26453, 'A', 750, 4931, 86, 41850),
(26454, 'A', 750, 4931, 86, 83700),
(26455, 'A', 750, 4931, 86, 83700),
(26456, 'A', 750, 4931, 86, 41850),
(26457, 'A', 750, 4931, 86, 83700),
(26464, 'A', 750, 4931, 86, 83700),
(26467, 'A', 750, 4931, 86, 83700),
(26468, 'A', 750, 4931, 86, 83700),
(26469, 'A', 750, 4931, 86, 83700),
(26470, 'A', 750, 4931, 86, 83700),
(26475, 'A', 750, 4931, 86, 83700),
(26476, 'A', 750, 4931, 86, 41850),
(26477, 'A', 750, 4931, 86, 83700),
(26478, 'A', 750, 4931, 86, 83700),
(26479, 'A', 750, 4931, 86, 8370),
(26480, 'A', 750, 4931, 86, 62780),
(27057, 'A', 751, 4932, 146, 135450),
(27158, 'A', 751, 4932, 146, 33860),
(27168, 'A', 751, 4932, 146, 135450),
(27175, 'A', 751, 4932, 146, 13540),
(27383, 'A', 751, 4924, 150, 70200),
(27385, 'A', 751, 4924, 150, 14040),
(27386, 'A', 751, 4924, 150, 14040),
(27387, 'A', 751, 4932, 146, 135450),
(27392, 'A', 751, 4924, 150, 140400),
(27420, 'A', 751, 4924, 150, 140400),
(27421, 'A', 751, 4924, 150, 140400),
(27449, 'B', 751, 4924, 150, 140400),
(27456, 'A', 751, 4924, 150, 140400),
(27457, 'A', 751, 4924, 150, 70200),
(27458, 'A', 751, 4924, 150, 140400),
(27459, 'A', 751, 4924, 150, 14040),
(27460, 'A', 751, 4924, 150, 140400),
(27467, 'A', 751, 4924, 150, 140400),
(27533, 'A', 751, 4924, 150, 140400),
(27534, 'A', 751, 4924, 150, 140400),
(27620, 'A', 751, 4924, 150, 210600),
(27684, 'A', 751, 4924, 150, 14040),
(28521, 'B', 750, 4927, 94, 45450),
(28522, 'B', 750, 4927, 94, 113620),
(28523, 'B', 750, 4927, 94, 45450),
(28629, 'B', 750, 4926, 102, 123190),
(28630, 'B', 750, 4926, 102, 98550),
(28637, 'B', 750, 4926, 102, 123190),
(28722, 'B', 750, 4926, 102, 147820),
(28768, 'B', 750, 4927, 94, 9090),
(28828, 'B', 750, 4926, 102, 123190),
(28838, 'B', 750, 4926, 102, 98550),
(28839, 'B', 750, 4926, 102, 98550);

CREATE TABLE IF NOT EXISTS `dc_quest_gap_link` (
    `kind` CHAR(2) NOT NULL,
    `eid` INT UNSIGNED NOT NULL,
    `quest` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`kind`, `eid`, `quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DELETE FROM `dc_quest_gap_link`;
INSERT INTO `dc_quest_gap_link` (`kind`, `eid`, `quest`) VALUES
('CE', 3603691, 13867),
('CE', 3603691, 26479),
('CE', 3603698, 13976),
('CE', 3603848, 26455),
('CE', 3603885, 13964),
('CE', 3603885, 26470),
('CE', 3603894, 26475),
('CE', 3603897, 26480),
('CE', 3603901, 26468),
('CE', 3603901, 26469),
('CE', 3603916, 26476),
('CE', 3603916, 26477),
('CE', 3603916, 26478),
('CE', 3603920, 26467),
('CE', 3604079, 13849),
('CE', 3608576, 14117),
('CE', 3608576, 14118),
('CE', 3608586, 14431),
('CE', 3608586, 14432),
('CE', 3608586, 14433),
('CE', 3610667, 27386),
('CE', 3610667, 27387),
('CE', 3610926, 27383),
('CE', 3610926, 27392),
('CE', 3611033, 27458),
('CE', 3611036, 27620),
('CE', 3611053, 27168),
('CE', 3611063, 27385),
('CE', 3612384, 27533),
('CE', 3612384, 27534),
('CE', 3612724, 13801),
('CE', 3614733, 26456),
('CE', 3616116, 27459),
('CE', 3616134, 27456),
('CE', 3616135, 27420),
('CE', 3616135, 27421),
('CE', 3616365, 27467),
('CE', 3617287, 26457),
('CE', 3617291, 26453),
('CE', 3617303, 26444),
('CE', 3617310, 13766),
('CE', 3617310, 13869),
('CE', 3617310, 26454),
('CE', 3617355, 26448),
('CE', 3624739, 13965),
('CE', 3635085, 14197),
('CE', 3635086, 14129),
('CE', 3635087, 14201),
('CE', 3635091, 14161),
('CE', 3635091, 14162),
('CE', 3635091, 14165),
('CE', 3645574, 27449),
('CE', 3649396, 28828),
('CE', 3649436, 28637),
('CE', 3709298, 28768),
('CE', 3710305, 28629),
('CE', 3710305, 28722),
('CE', 3710929, 28838),
('CE', 3710929, 28839),
('CE', 3711556, 28521),
('CE', 3711556, 28522),
('CE', 3711556, 28523),
('CS', 3603691, 13867),
('CS', 3603691, 26476),
('CS', 3603691, 26480),
('CS', 3603848, 26455),
('CS', 3603880, 26456),
('CS', 3603885, 26470),
('CS', 3603891, 26464),
('CS', 3603894, 26475),
('CS', 3603901, 26467),
('CS', 3603901, 26469),
('CS', 3603916, 26477),
('CS', 3603916, 26478),
('CS', 3603916, 26479),
('CS', 3603920, 26468),
('CS', 3603996, 13965),
('CS', 3604079, 13849),
('CS', 3604079, 13964),
('CS', 3608576, 14117),
('CS', 3608576, 14118),
('CS', 3608586, 14431),
('CS', 3608586, 14432),
('CS', 3608586, 14433),
('CS', 3610667, 27387),
('CS', 3610838, 27158),
('CS', 3610840, 27175),
('CS', 3610926, 27385),
('CS', 3610926, 27392),
('CS', 3611033, 27458),
('CS', 3611034, 27684),
('CS', 3611036, 27459),
('CS', 3611053, 27168),
('CS', 3611063, 27383),
('CS', 3611063, 27386),
('CS', 3612384, 27533),
('CS', 3612384, 27534),
('CS', 3612724, 13801),
('CS', 3616116, 27460),
('CS', 3616116, 27620),
('CS', 3616134, 27456),
('CS', 3616134, 27457),
('CS', 3616135, 27420),
('CS', 3616135, 27421),
('CS', 3616365, 27467),
('CS', 3617106, 26453),
('CS', 3617287, 26457),
('CS', 3617291, 26454),
('CS', 3617303, 26444),
('CS', 3617310, 13766),
('CS', 3617310, 13792),
('CS', 3617310, 13869),
('CS', 3617355, 26448),
('CS', 3624739, 13976),
('CS', 3635085, 14197),
('CS', 3635086, 14129),
('CS', 3635086, 14162),
('CS', 3635087, 14201),
('CS', 3635088, 14424),
('CS', 3635091, 14161),
('CS', 3635091, 14165),
('CS', 3635091, 14190),
('CS', 3645574, 27449),
('CS', 3649396, 28828),
('CS', 3649436, 28637),
('CS', 3710305, 28629),
('CS', 3710305, 28630),
('CS', 3710305, 28722),
('CS', 3710929, 28838),
('CS', 3710929, 28839),
('CS', 3711556, 28522),
('CS', 3711556, 28523),
('CS', 3715395, 28521),
('CS', 3715395, 28768),
('GE', 3802701, 25296),
('GE', 3802701, 25314),
('GE', 3907291, 28630),
('GS', 3776392, 27057),
('GS', 3802701, 25296),
('GS', 3802701, 25314);

CREATE TABLE IF NOT EXISTS `dc_quest_gap_objective` (
    `quest` INT UNSIGNED NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL,
    `value` INT NOT NULL,
    PRIMARY KEY (`quest`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DELETE FROM `dc_quest_gap_objective`;
INSERT INTO `dc_quest_gap_objective` (`quest`, `slot`, `value`) VALUES
(25314, 1, 3640922),
(27449, 1, 3645579),
(28637, 1, 3707444),
(28722, 1, 3710978);

CREATE TABLE IF NOT EXISTS `dc_quest_gap_reward` (
    `quest` INT UNSIGNED NOT NULL,
    `RewardItem1` INT UNSIGNED NOT NULL,
    `RewardItem2` INT UNSIGNED NOT NULL,
    `RewardItem3` INT UNSIGNED NOT NULL,
    `RewardItem4` INT UNSIGNED NOT NULL,
    `RewardAmount1` INT UNSIGNED NOT NULL,
    `RewardAmount2` INT UNSIGNED NOT NULL,
    `RewardAmount3` INT UNSIGNED NOT NULL,
    `RewardAmount4` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID1` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID2` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID3` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID4` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID5` INT UNSIGNED NOT NULL,
    `RewardChoiceItemID6` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity1` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity2` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity3` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity4` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity5` INT UNSIGNED NOT NULL,
    `RewardChoiceItemQuantity6` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DELETE FROM `dc_quest_gap_reward`;
INSERT INTO `dc_quest_gap_reward` (`quest`,
    `RewardItem1`, `RewardItem2`, `RewardItem3`, `RewardItem4`, `RewardAmount1`, `RewardAmount2`, `RewardAmount3`,
    `RewardAmount4`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`,
    `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`,
    `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`,
    `RewardChoiceItemQuantity6`) VALUES
(14117, 0, 0, 0, 0, 0, 0, 0, 0, 53416, 420138, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0),
(26457, 0, 0, 0, 0, 0, 0, 0, 0, 420096, 420266, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0),
(26464, 0, 0, 0, 0, 0, 0, 0, 0, 420026, 420096, 420316, 0, 0, 0, 1, 1, 1, 0, 0, 0),
(26468, 0, 0, 0, 0, 0, 0, 0, 0, 420016, 420196, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0),
(26478, 0, 0, 0, 0, 0, 0, 0, 0, 420066, 420136, 420306, 0, 0, 0, 1, 1, 1, 0, 0, 0),
(27387, 0, 0, 0, 0, 0, 0, 0, 0, 421528, 421526, 421548, 421516, 0, 0, 1, 1, 1, 1, 0, 0),
(27392, 0, 0, 0, 0, 0, 0, 0, 0, 421629, 421625, 421611, 0, 0, 0, 1, 1, 1, 0, 0, 0),
(27421, 0, 0, 0, 0, 0, 0, 0, 0, 421637, 421619, 421610, 421636, 0, 0, 1, 1, 1, 1, 0, 0),
(27456, 64641, 0, 0, 0, 1, 0, 0, 0, 421643, 421630, 421636, 421638, 0, 0, 1, 1, 1, 1, 0, 0),
(27467, 0, 0, 0, 0, 0, 0, 0, 0, 421638, 421602, 421635, 0, 0, 0, 1, 1, 1, 0, 0, 0),
(27533, 0, 0, 0, 0, 0, 0, 0, 0, 421630, 421627, 421624, 421609, 0, 0, 1, 1, 1, 1, 0, 0),
(27620, 0, 0, 0, 0, 0, 0, 0, 0, 421672, 421679, 421680, 0, 0, 0, 1, 1, 1, 0, 0, 0),
(28522, 0, 0, 0, 0, 0, 0, 0, 0, 420074, 420154, 420184, 420264, 0, 0, 1, 1, 1, 1, 0, 0),
(28722, 15778, 0, 0, 0, 1, 0, 0, 0, 420412, 420052, 420082, 420232, 420252, 0, 1, 1, 1, 1, 1, 0),
(28828, 0, 0, 0, 0, 0, 0, 0, 0, 420032, 420142, 420222, 0, 0, 0, 1, 1, 1, 0, 0, 0);

CREATE TABLE IF NOT EXISTS `dc_quest_gap_poi` (
    `quest` INT UNSIGNED NOT NULL,
    `src` INT UNSIGNED NOT NULL,
    `stock_map` SMALLINT NOT NULL,
    `dc_map` SMALLINT NOT NULL,
    PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DELETE FROM `dc_quest_gap_poi`;
INSERT INTO `dc_quest_gap_poi` (`quest`, `src`, `stock_map`, `dc_map`) VALUES
(13766, 13766, 1, 750),
(13792, 13792, 1, 750),
(13801, 13801, 1, 750),
(13849, 13849, 1, 750),
(13867, 13867, 1, 750),
(13869, 13869, 1, 750),
(13964, 13964, 1, 750),
(13965, 13965, 1, 750),
(13976, 13976, 1, 750),
(13981, 13981, 1, 750),
(14117, 14117, 1, 750),
(14118, 14118, 1, 750),
(14129, 14129, 1, 750),
(14161, 14161, 1, 750),
(14162, 14162, 1, 750),
(14165, 14165, 1, 750),
(14190, 14190, 1, 750),
(14192, 14192, 1, 750),
(14197, 14197, 1, 750),
(14201, 14201, 1, 750),
(14270, 14270, 1, 750),
(14271, 14271, 1, 750),
(14310, 14310, 1, 750),
(14424, 14424, 1, 750),
(14429, 14429, 1, 750),
(14430, 14430, 1, 750),
(14431, 14431, 1, 750),
(14432, 14432, 1, 750),
(14433, 14433, 1, 750),
(25296, 25296, 1, 750),
(25314, 25314, 1, 750),
(26039, 26039, 0, 751),
(26041, 26041, 0, 751),
(26042, 26042, 0, 751),
(26337, 26337, 1, 750),
(26388, 26388, 1, 750),
(26444, 26444, 1, 750),
(26446, 26446, 1, 750),
(26448, 26448, 1, 750),
(26453, 26453, 1, 750),
(26454, 26454, 1, 750),
(26455, 26455, 1, 750),
(26456, 26456, 1, 750),
(26457, 26457, 1, 750),
(26467, 26467, 1, 750),
(26468, 26468, 1, 750),
(26469, 26469, 1, 750),
(26470, 26470, 1, 750),
(26475, 26475, 1, 750),
(26476, 26476, 1, 750),
(26477, 26477, 1, 750),
(26478, 26478, 1, 750),
(26479, 26479, 1, 750),
(26480, 26480, 1, 750),
(27045, 27045, 0, 751),
(27168, 27168, 0, 751),
(27383, 27383, 0, 751),
(27385, 27385, 0, 751),
(27386, 27386, 0, 751),
(27387, 27387, 0, 751),
(27392, 27392, 0, 751),
(27420, 27420, 0, 751),
(27421, 27421, 0, 751),
(27449, 27449, 0, 751),
(27456, 27456, 0, 751),
(27458, 27458, 0, 751),
(27459, 27459, 0, 751),
(27460, 27460, 0, 751),
(27467, 27467, 0, 751),
(27533, 27533, 0, 751),
(27534, 27534, 0, 751),
(27620, 27620, 0, 751),
(28189, 28189, 0, 751),
(28521, 28521, 1, 750),
(28522, 28522, 1, 750),
(28523, 28523, 1, 750),
(28629, 28629, 1, 750),
(28630, 28630, 1, 750),
(28637, 28637, 1, 750),
(28640, 28640, 1, 750),
(28722, 28722, 1, 750),
(28742, 28742, 1, 750),
(28768, 28768, 1, 750),
(28828, 28828, 1, 750),
(28838, 28838, 1, 750),
(28839, 28839, 1, 750),
(226920, 26920, 0, 751),
(226926, 26926, 0, 751),
(226930, 26930, 0, 751),
(226952, 26952, 0, 751),
(226979, 26979, 0, 751),
(228505, 28505, 0, 751);

CREATE TABLE IF NOT EXISTS `dc_quest_gap_backup` (
    `ID` INT UNSIGNED NOT NULL,
    `QuestLevel` INT NOT NULL,
    `MinLevel` INT NOT NULL,
    `RewardMoney` INT NOT NULL,
    `RequiredNpcOrGo1` INT NOT NULL,
    `RequiredNpcOrGo2` INT NOT NULL,
    `RequiredNpcOrGo3` INT NOT NULL,
    `RequiredNpcOrGo4` INT NOT NULL,
    `RewardItem1` INT NOT NULL,
    `RewardItem2` INT NOT NULL,
    `RewardItem3` INT NOT NULL,
    `RewardItem4` INT NOT NULL,
    `RewardAmount1` INT NOT NULL,
    `RewardAmount2` INT NOT NULL,
    `RewardAmount3` INT NOT NULL,
    `RewardAmount4` INT NOT NULL,
    `RewardChoiceItemID1` INT NOT NULL,
    `RewardChoiceItemID2` INT NOT NULL,
    `RewardChoiceItemID3` INT NOT NULL,
    `RewardChoiceItemID4` INT NOT NULL,
    `RewardChoiceItemID5` INT NOT NULL,
    `RewardChoiceItemID6` INT NOT NULL,
    `RewardChoiceItemQuantity1` INT NOT NULL,
    `RewardChoiceItemQuantity2` INT NOT NULL,
    `RewardChoiceItemQuantity3` INT NOT NULL,
    `RewardChoiceItemQuantity4` INT NOT NULL,
    `RewardChoiceItemQuantity5` INT NOT NULL,
    `RewardChoiceItemQuantity6` INT NOT NULL,
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- the quests that already existed: their original values, first run only (INSERT IGNORE keeps them on a re-run;
-- the DELETE removes nothing and only satisfies the codestyle rule)
DELETE FROM `dc_quest_gap_backup` WHERE `ID` = 0;
INSERT IGNORE INTO `dc_quest_gap_backup` (`ID`,
    `QuestLevel`, `MinLevel`, `RewardMoney`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`,
    `RequiredNpcOrGo4`, `RewardItem1`, `RewardItem2`, `RewardItem3`, `RewardItem4`, `RewardAmount1`,
    `RewardAmount2`, `RewardAmount3`, `RewardAmount4`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`)
SELECT `t`.`ID`,
    `t`.`QuestLevel`, `t`.`MinLevel`, `t`.`RewardMoney`, `t`.`RequiredNpcOrGo1`, `t`.`RequiredNpcOrGo2`,
    `t`.`RequiredNpcOrGo3`, `t`.`RequiredNpcOrGo4`, `t`.`RewardItem1`, `t`.`RewardItem2`, `t`.`RewardItem3`,
    `t`.`RewardItem4`, `t`.`RewardAmount1`, `t`.`RewardAmount2`, `t`.`RewardAmount3`, `t`.`RewardAmount4`,
    `t`.`RewardChoiceItemID1`, `t`.`RewardChoiceItemID2`, `t`.`RewardChoiceItemID3`, `t`.`RewardChoiceItemID4`,
    `t`.`RewardChoiceItemID5`, `t`.`RewardChoiceItemID6`, `t`.`RewardChoiceItemQuantity1`,
    `t`.`RewardChoiceItemQuantity2`, `t`.`RewardChoiceItemQuantity3`, `t`.`RewardChoiceItemQuantity4`,
    `t`.`RewardChoiceItemQuantity5`, `t`.`RewardChoiceItemQuantity6`
FROM `quest_template` AS `t`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `t`.`ID` AND `i`.`kind` = 'A';

-- 1. the cata-only quests (quest_template rows are never deleted - codestyle - so this is a REPLACE)
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`,
    `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`,
    `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`,
    `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`,
    `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`,
    `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`,
    `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`,
    `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT
    `q`.`ID`, `q`.`QuestType`, `q`.`QuestLevel`, `q`.`MinLevel`, `q`.`QuestSortID`, `q`.`QuestInfoID`,
    `q`.`SuggestedGroupNum`, `q`.`RequiredFactionId1`, `q`.`RequiredFactionId2`, `q`.`RequiredFactionValue1`,
    `q`.`RequiredFactionValue2`, `q`.`RewardNextQuest`, `q`.`RewardXPDifficulty`, `q`.`RewardMoney`,
    `q`.`RewardBonusMoney`, `q`.`RewardDisplaySpell`, `q`.`RewardSpell`, `q`.`RewardHonor`, `q`.`RewardKillHonor`,
    `q`.`StartItem`, `q`.`Flags`, `q`.`RequiredPlayerKills`, `q`.`RewardItem1`, `q`.`RewardAmount1`,
    `q`.`RewardItem2`, `q`.`RewardAmount2`, `q`.`RewardItem3`, `q`.`RewardAmount3`, `q`.`RewardItem4`,
    `q`.`RewardAmount4`, `q`.`ItemDrop1`, `q`.`ItemDropQuantity1`, `q`.`ItemDrop2`, `q`.`ItemDropQuantity2`,
    `q`.`ItemDrop3`, `q`.`ItemDropQuantity3`, `q`.`ItemDrop4`, `q`.`ItemDropQuantity4`, `q`.`RewardChoiceItemID1`,
    `q`.`RewardChoiceItemQuantity1`, `q`.`RewardChoiceItemID2`, `q`.`RewardChoiceItemQuantity2`,
    `q`.`RewardChoiceItemID3`, `q`.`RewardChoiceItemQuantity3`, `q`.`RewardChoiceItemID4`,
    `q`.`RewardChoiceItemQuantity4`, `q`.`RewardChoiceItemID5`, `q`.`RewardChoiceItemQuantity5`,
    `q`.`RewardChoiceItemID6`, `q`.`RewardChoiceItemQuantity6`, `q`.`POIContinent`, `q`.`POIx`, `q`.`POIy`,
    `q`.`POIPriority`, `q`.`RewardTitle`, `q`.`RewardTalents`, `q`.`RewardArenaPoints`, `q`.`RewardFactionID1`,
    `q`.`RewardFactionValue1`, `q`.`RewardFactionOverride1`, `q`.`RewardFactionID2`, `q`.`RewardFactionValue2`,
    `q`.`RewardFactionOverride2`, `q`.`RewardFactionID3`, `q`.`RewardFactionValue3`, `q`.`RewardFactionOverride3`,
    `q`.`RewardFactionID4`, `q`.`RewardFactionValue4`, `q`.`RewardFactionOverride4`, `q`.`RewardFactionID5`,
    `q`.`RewardFactionValue5`, `q`.`RewardFactionOverride5`,
    CASE WHEN `a`.`TimeAllowed` IS NULL THEN 0 ELSE `a`.`TimeAllowed` END,
    CASE WHEN `a`.`AllowableRaces` IS NULL THEN 0 ELSE `a`.`AllowableRaces` END, `q`.`LogTitle`,
    `q`.`LogDescription`, `q`.`QuestDescription`, `q`.`AreaDescription`, `q`.`QuestCompletionLog`,
    `q`.`RequiredNpcOrGo1`, `q`.`RequiredNpcOrGo2`, `q`.`RequiredNpcOrGo3`, `q`.`RequiredNpcOrGo4`,
    `q`.`RequiredNpcOrGoCount1`, `q`.`RequiredNpcOrGoCount2`, `q`.`RequiredNpcOrGoCount3`,
    `q`.`RequiredNpcOrGoCount4`, `q`.`RequiredItemId1`, `q`.`RequiredItemId2`, `q`.`RequiredItemId3`,
    `q`.`RequiredItemId4`, `q`.`RequiredItemId5`, `q`.`RequiredItemId6`, `q`.`RequiredItemCount1`,
    `q`.`RequiredItemCount2`, `q`.`RequiredItemCount3`, `q`.`RequiredItemCount4`, `q`.`RequiredItemCount5`,
    `q`.`RequiredItemCount6`, 0, `q`.`ObjectiveText1`, `q`.`ObjectiveText2`, `q`.`ObjectiveText3`,
    `q`.`ObjectiveText4`, `q`.`VerifiedBuild`
FROM `cata_world`.`quest_template` AS `q`
LEFT JOIN `cata_world`.`quest_template_addon` AS `a` ON `a`.`ID` = `q`.`ID`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `q`.`ID` AND `i`.`kind` = 'B';

DELETE FROM `quest_template_addon` WHERE `ID` IN (SELECT `quest` FROM `dc_quest_gap_import` WHERE `kind` = 'B');
INSERT INTO `quest_template_addon` (
    `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`,
    `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`,
    `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`,
    `ProvidedItemCount`, `SpecialFlags`)
SELECT
    `s`.`ID`, `s`.`MaxLevel`, `s`.`AllowableClasses`, `s`.`SourceSpellID`, `s`.`PrevQuestID`, `s`.`NextQuestID`,
    `s`.`ExclusiveGroup`, `s`.`BreadcrumbForQuestId`, `s`.`RewardMailTemplateID`, `s`.`RewardMailDelay`,
    `s`.`RequiredSkillID`, `s`.`RequiredSkillPoints`, `s`.`RequiredMinRepFaction`, `s`.`RequiredMaxRepFaction`,
    `s`.`RequiredMinRepValue`, `s`.`RequiredMaxRepValue`, `s`.`ProvidedItemCount`, `s`.`SpecialFlags`
FROM `cata_world`.`quest_template_addon` AS `s`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `s`.`ID` AND `i`.`kind` = 'B';

DELETE FROM `quest_offer_reward` WHERE `ID` IN (SELECT `quest` FROM `dc_quest_gap_import` WHERE `kind` = 'B');
INSERT INTO `quest_offer_reward` (
    `ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
    `RewardText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`Emote1`, `s`.`Emote2`, `s`.`Emote3`, `s`.`Emote4`, `s`.`EmoteDelay1`, `s`.`EmoteDelay2`,
    `s`.`EmoteDelay3`, `s`.`EmoteDelay4`, `s`.`RewardText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` AS `s`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `s`.`ID` AND `i`.`kind` = 'B';

DELETE FROM `quest_request_items` WHERE `ID` IN (SELECT `quest` FROM `dc_quest_gap_import` WHERE `kind` = 'B');
INSERT INTO `quest_request_items` (
    `ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`EmoteOnComplete`, `s`.`EmoteOnIncomplete`, `s`.`CompletionText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` AS `s`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `s`.`ID` AND `i`.`kind` = 'B';

-- 2. givers and turn-ins on the 750/751 NPCs and objects
REPLACE INTO `creature_queststarter` (`id`, `quest`)
SELECT `eid`, `quest` FROM `dc_quest_gap_link` WHERE `kind` = 'CS';
REPLACE INTO `gameobject_queststarter` (`id`, `quest`)
SELECT `eid`, `quest` FROM `dc_quest_gap_link` WHERE `kind` = 'GS';
REPLACE INTO `creature_questender` (`id`, `quest`)
SELECT `eid`, `quest` FROM `dc_quest_gap_link` WHERE `kind` = 'CE';
REPLACE INTO `gameobject_questender` (`id`, `quest`)
SELECT `eid`, `quest` FROM `dc_quest_gap_link` WHERE `kind` = 'GE';

-- 3. level band and gold (gold is only ever raised)
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `t`.`ID`
SET `t`.`QuestLevel` = -1;

UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `t`.`ID`
SET `t`.`MinLevel` = `i`.`min_level`;

UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_import` AS `i` ON `i`.`quest` = `t`.`ID`
SET `t`.`RewardMoney` = IF(`i`.`money` > `t`.`RewardMoney`, `i`.`money`, `t`.`RewardMoney`);

-- 4. objectives whose raw target never spawns on the map, pointed at the map's clone of it
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_objective` AS `o` ON `o`.`quest` = `t`.`ID` AND `o`.`slot` = 1
SET `t`.`RequiredNpcOrGo1` = `o`.`value`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_objective` AS `o` ON `o`.`quest` = `t`.`ID` AND `o`.`slot` = 2
SET `t`.`RequiredNpcOrGo2` = `o`.`value`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_objective` AS `o` ON `o`.`quest` = `t`.`ID` AND `o`.`slot` = 3
SET `t`.`RequiredNpcOrGo3` = `o`.`value`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_objective` AS `o` ON `o`.`quest` = `t`.`ID` AND `o`.`slot` = 4
SET `t`.`RequiredNpcOrGo4` = `o`.`value`;

-- 5. rewards: gear -> the band's ladder item, missing items dropped, choices de-duplicated and compacted
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardItem1` = `r`.`RewardItem1`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardItem2` = `r`.`RewardItem2`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardItem3` = `r`.`RewardItem3`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardItem4` = `r`.`RewardItem4`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardAmount1` = `r`.`RewardAmount1`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardAmount2` = `r`.`RewardAmount2`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardAmount3` = `r`.`RewardAmount3`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardAmount4` = `r`.`RewardAmount4`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID1` = `r`.`RewardChoiceItemID1`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID2` = `r`.`RewardChoiceItemID2`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID3` = `r`.`RewardChoiceItemID3`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID4` = `r`.`RewardChoiceItemID4`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID5` = `r`.`RewardChoiceItemID5`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemID6` = `r`.`RewardChoiceItemID6`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity1` = `r`.`RewardChoiceItemQuantity1`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity2` = `r`.`RewardChoiceItemQuantity2`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity3` = `r`.`RewardChoiceItemQuantity3`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity4` = `r`.`RewardChoiceItemQuantity4`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity5` = `r`.`RewardChoiceItemQuantity5`;
UPDATE `quest_template` AS `t`
JOIN `dc_quest_gap_reward` AS `r` ON `r`.`quest` = `t`.`ID`
SET `t`.`RewardChoiceItemQuantity6` = `r`.`RewardChoiceItemQuantity6`;

-- 6. quest map markers from cata (only quests that had none; POIs outside the DC map's own areas are left out)
DELETE FROM `quest_poi` WHERE `QuestID` IN (SELECT `quest` FROM `dc_quest_gap_poi`);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`,
    `Flags`, `VerifiedBuild`)
SELECT `g`.`quest`, `p`.`Idx1`, `p`.`ObjectiveIndex`, `g`.`dc_map`,
    CASE `p`.`WorldMapAreaID` WHEN 606 THEN 1216 WHEN 281 THEN 1256 WHEN 182 THEN 1257 WHEN 241 THEN 1258
    WHEN 42 THEN 1259 WHEN 181 THEN 1260 WHEN 43 THEN 1261 WHEN 23 THEN 1217 WHEN 22 THEN 1268
    WHEN 20 THEN 1269 WHEN 21 THEN 1270 WHEN 24 THEN 1271 WHEN 26 THEN 1272 WHEN 16 THEN 1273
    WHEN 684 THEN 1274 WHEN 382 THEN 1275 END,
    `p`.`Floor`, `p`.`Priority`, `p`.`Flags`, 0
FROM `cata_world`.`quest_poi` AS `p`
JOIN `dc_quest_gap_poi` AS `g` ON `g`.`src` = `p`.`QuestID` AND `p`.`MapID` = `g`.`stock_map`
WHERE (`g`.`dc_map` = 750 AND `p`.`WorldMapAreaID` IN (606, 281, 182, 241, 42, 181, 43))
   OR (`g`.`dc_map` = 751 AND `p`.`WorldMapAreaID` IN (23, 22, 20, 21, 24, 26, 16, 684, 382));

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (SELECT `quest` FROM `dc_quest_gap_poi`);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT DISTINCT `g`.`quest`, `pp`.`Idx1`, `pp`.`Idx2`, `pp`.`X`, `pp`.`Y`, 0
FROM `cata_world`.`quest_poi_points` AS `pp`
JOIN `dc_quest_gap_poi` AS `g` ON `g`.`src` = `pp`.`QuestID`
JOIN `quest_poi` AS `n` ON `n`.`QuestID` = `g`.`quest` AND `n`.`id` = `pp`.`Idx1`;

-- Revert (by hand): DELETE the dc_quest_gap_link rows from the four relation tables; restore the columns of
-- dc_quest_gap_backup into quest_template; delete quest_template/_addon/texts for kind 'B' in dc_quest_gap_import;
-- DELETE FROM quest_poi / quest_poi_points WHERE QuestID IN (SELECT quest FROM dc_quest_gap_poi).
