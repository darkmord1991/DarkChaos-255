-- ============================================================================
-- Dungeon Enhancement System - World Database Schema
-- ============================================================================
-- Purpose: System configuration and seasonal data for Mythic+ system
-- Prefix: dc_ (DarkChaos)
-- Tables: 9 total
-- ============================================================================
drop table if exists `dc_mythic_seasons`;
drop table if exists `dc_mythic_dungeons_config`;
drop table if exists `dc_mythic_raid_config`;
drop table if exists `dc_mythic_affixes`;
drop table if exists `dc_mythic_affix_rotation`;
drop table if exists `dc_mythic_vault_rewards`;
drop table if exists `dc_mythic_tokens_loot`;
drop table if exists `dc_mythic_achievement_defs`;
drop table if exists `dc_mythic_npc_spawns`;
drop table if exists `dc_mythic_gameobjects`;

-- ============================================================================
-- Table: dc_mythic_seasons
-- Purpose: Season definitions and configuration
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_seasons` (
    `seasonId` INT UNSIGNED NOT NULL,
    `seasonName` VARCHAR(100) NOT NULL,
    `startDate` DATETIME NOT NULL,
    `endDate` DATETIME DEFAULT NULL,
    `isActive` TINYINT(1) NOT NULL DEFAULT 1,
    `maxKeystoneLevel` TINYINT UNSIGNED NOT NULL DEFAULT 10,
    `vaultEnabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`seasonId`),
    INDEX `idx_active` (`isActive`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic+ season definitions';

-- Pre-populate Season 1
INSERT INTO `dc_mythic_seasons` (`seasonId`, `seasonName`, `startDate`, `endDate`, `isActive`, `maxKeystoneLevel`, `vaultEnabled`) VALUES
(1, 'Season 1: The Beginning', '2025-01-01 00:00:00', NULL, 1, 10, 1)
ON DUPLICATE KEY UPDATE seasonName=VALUES(seasonName);

-- ============================================================================
-- Table: dc_mythic_dungeons_config
-- Purpose: Dungeon configuration (which dungeons are M+ enabled)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_dungeons_config` (
    `mapId` SMALLINT UNSIGNED NOT NULL,
    `seasonId` INT UNSIGNED NOT NULL,
    `dungeonName` VARCHAR(100) NOT NULL,
    `isEnabled` TINYINT(1) NOT NULL DEFAULT 1,
    `baseScalingMultiplier` FLOAT NOT NULL DEFAULT 2.0 COMMENT 'M+0 scaling',
    `timerSeconds` INT UNSIGNED NOT NULL DEFAULT 1800 COMMENT 'Timer for completion',
    `requiredBosses` TINYINT UNSIGNED NOT NULL DEFAULT 3,
    PRIMARY KEY (`mapId`, `seasonId`),
    INDEX `idx_season` (`seasonId`),
    INDEX `idx_enabled` (`isEnabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Dungeon configuration for Mythic+';

-- Pre-populate dungeons for Season 1
INSERT INTO `dc_mythic_dungeons_config` (`mapId`, `seasonId`, `dungeonName`, `isEnabled`, `baseScalingMultiplier`, `timerSeconds`, `requiredBosses`) VALUES
-- WotLK Dungeons
(574, 1, 'Utgarde Keep', 1, 2.0, 1800, 3),
(575, 1, 'Utgarde Pinnacle', 1, 2.2, 2100, 4),
(576, 1, 'The Nexus', 1, 2.0, 1800, 4),
(578, 1, 'The Oculus', 1, 2.4, 2400, 4),
-- TBC Dungeons
(542, 1, 'The Blood Furnace', 1, 2.5, 1500, 3),
(543, 1, 'Hellfire Ramparts', 1, 2.3, 1500, 3),
-- Classic Dungeons
(329, 1, 'Stratholme', 1, 3.0, 2700, 5),
(36, 1, 'Deadmines', 1, 1.8, 1500, 5);

-- ============================================================================
-- Table: dc_mythic_raid_config
-- Purpose: Raid configuration for Mythic difficulty
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_raid_config` (
    `mapId` SMALLINT UNSIGNED NOT NULL,
    `raidName` VARCHAR(100) NOT NULL,
    `difficulty` ENUM('Normal', 'Heroic', 'Mythic') NOT NULL DEFAULT 'Mythic',
    `isEnabled` TINYINT(1) NOT NULL DEFAULT 1,
    `scalingMultiplier` FLOAT NOT NULL DEFAULT 2.5,
    `lockoutDays` TINYINT UNSIGNED NOT NULL DEFAULT 7 COMMENT 'Days until reset',
    `requiredBosses` TINYINT UNSIGNED NOT NULL DEFAULT 10,
    PRIMARY KEY (`mapId`, `difficulty`),
    INDEX `idx_enabled` (`isEnabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Raid configuration for Mythic difficulty';

-- Pre-populate raids
INSERT INTO `dc_mythic_raid_config` (`mapId`, `raidName`, `difficulty`, `isEnabled`, `scalingMultiplier`, `lockoutDays`, `requiredBosses`) VALUES
-- WotLK Raids
(249, 'Onyxia\'s Lair', 'Normal', 1, 2.0, 7, 1),
(249, 'Onyxia\'s Lair', 'Heroic', 1, 2.5, 7, 1),
(249, 'Onyxia\'s Lair', 'Mythic', 1, 3.0, 7, 1),
(603, 'Ulduar', 'Normal', 1, 2.0, 7, 14),
(603, 'Ulduar', 'Heroic', 1, 2.5, 7, 14),
(603, 'Ulduar', 'Mythic', 1, 3.0, 7, 14),
(631, 'Icecrown Citadel', 'Normal', 1, 2.0, 7, 12),
(631, 'Icecrown Citadel', 'Heroic', 1, 2.5, 7, 12),
(631, 'Icecrown Citadel', 'Mythic', 1, 3.0, 7, 12),
-- TBC Raids
(532, 'Karazhan', 'Normal', 1, 2.0, 7, 11),
(532, 'Karazhan', 'Heroic', 1, 2.5, 7, 11),
(532, 'Karazhan', 'Mythic', 1, 3.0, 7, 11),
(565, 'Gruul\'s Lair', 'Normal', 1, 2.0, 7, 2),
(565, 'Gruul\'s Lair', 'Heroic', 1, 2.5, 7, 2),
(565, 'Gruul\'s Lair', 'Mythic', 1, 3.0, 7, 2),
-- Classic Raids
(409, 'Molten Core', 'Normal', 1, 2.0, 7, 10),
(409, 'Molten Core', 'Heroic', 1, 2.5, 7, 10),
(409, 'Molten Core', 'Mythic', 1, 3.0, 7, 10);

-- ============================================================================
-- Table: dc_mythic_affixes
-- Purpose: Affix definitions
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_affixes` (
    `affixId` INT UNSIGNED NOT NULL,
    `affixName` VARCHAR(50) NOT NULL,
    `description` TEXT NOT NULL,
    `affixType` ENUM('Boss', 'Trash', 'Environmental', 'Debuff') NOT NULL,
    `minKeystoneLevel` TINYINT UNSIGNED NOT NULL COMMENT 'Minimum M+ level to activate',
    `spellId` INT UNSIGNED DEFAULT 0 COMMENT 'Visual spell ID (optional)',
    PRIMARY KEY (`affixId`),
    INDEX `idx_level` (`minKeystoneLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Affix definitions and mechanics';

-- Pre-populate affixes
INSERT INTO `dc_mythic_affixes` (`affixId`, `affixName`, `description`, `affixType`, `minKeystoneLevel`, `spellId`) VALUES
-- Tier 1 Affixes (M+2)
(1, 'Tyrannical', 'Bosses have 40% more health and deal 15% increased damage.', 'Boss', 2, 0),
(2, 'Fortified', 'Non-boss enemies have 20% more health and deal 30% increased damage.', 'Trash', 2, 0),
-- Tier 2 Affixes (M+4)
(3, 'Bolstering', 'When non-boss enemies die, they empower nearby allies, increasing their damage and health by 20%.', 'Trash', 4, 800010),
(4, 'Raging', 'Non-boss enemies enrage at 30% health remaining, dealing 50% increased damage until defeated.', 'Trash', 4, 0),
(5, 'Sanguine', 'When slain, non-boss enemies leave behind a pool of blood that heals enemies and damages players.', 'Trash', 4, 0),
-- Tier 3 Affixes (M+7)
(6, 'Necrotic', 'Enemy melee attacks apply a stacking debuff that inflicts damage over time and reduces healing received.', 'Debuff', 7, 0),
(7, 'Volcanic', 'Periodically, volcanic plumes erupt beneath distant players\' feet, dealing significant fire damage.', 'Environmental', 7, 0),
(8, 'Grievous', 'Players below 90% health suffer escalating damage over time until healed above 90%.', 'Debuff', 7, 0)
ON DUPLICATE KEY UPDATE affixName=VALUES(affixName), description=VALUES(description);

-- ============================================================================
-- Table: dc_mythic_affix_rotation
-- Purpose: Weekly affix rotation schedule
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_affix_rotation` (
    `seasonId` INT UNSIGNED NOT NULL,
    `weekNumber` TINYINT UNSIGNED NOT NULL COMMENT 'Week 1-12 rotation',
    `tier1AffixId` INT UNSIGNED NOT NULL COMMENT 'M+2 affix',
    `tier2AffixId` INT UNSIGNED NOT NULL COMMENT 'M+4 affix',
    `tier3AffixId` INT UNSIGNED NOT NULL COMMENT 'M+7 affix',
    PRIMARY KEY (`seasonId`, `weekNumber`),
    FOREIGN KEY (`tier1AffixId`) REFERENCES `dc_mythic_affixes`(`affixId`),
    FOREIGN KEY (`tier2AffixId`) REFERENCES `dc_mythic_affixes`(`affixId`),
    FOREIGN KEY (`tier3AffixId`) REFERENCES `dc_mythic_affixes`(`affixId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Weekly affix rotation schedule';

-- Pre-populate 12-week rotation for Season 1
INSERT INTO `dc_mythic_affix_rotation` (`seasonId`, `weekNumber`, `tier1AffixId`, `tier2AffixId`, `tier3AffixId`) VALUES
-- Week 1-6: Tyrannical rotation
(1, 1, 1, 3, 6),  -- Tyrannical + Bolstering + Necrotic
(1, 2, 1, 4, 7),  -- Tyrannical + Raging + Volcanic
(1, 3, 1, 5, 8),  -- Tyrannical + Sanguine + Grievous
(1, 4, 1, 3, 7),  -- Tyrannical + Bolstering + Volcanic
(1, 5, 1, 4, 8),  -- Tyrannical + Raging + Grievous
(1, 6, 1, 5, 6),  -- Tyrannical + Sanguine + Necrotic
-- Week 7-12: Fortified rotation
(1, 7, 2, 3, 6),  -- Fortified + Bolstering + Necrotic
(1, 8, 2, 4, 7),  -- Fortified + Raging + Volcanic
(1, 9, 2, 5, 8),  -- Fortified + Sanguine + Grievous
(1, 10, 2, 3, 7), -- Fortified + Bolstering + Volcanic
(1, 11, 2, 4, 8), -- Fortified + Raging + Grievous
(1, 12, 2, 5, 6); -- Fortified + Sanguine + Necrotic

-- ============================================================================
-- Table: dc_mythic_vault_rewards
-- Purpose: Great Vault reward configuration
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_vault_rewards` (
    `slotId` TINYINT UNSIGNED NOT NULL COMMENT '1, 2, or 3',
    `tier` TINYINT UNSIGNED NOT NULL COMMENT '1=Low, 2=Medium, 3=High',
    `dungeonsRequired` TINYINT UNSIGNED NOT NULL COMMENT 'Number of dungeons needed',
    `tokenAmount` SMALLINT UNSIGNED NOT NULL COMMENT 'Tokens awarded',
    PRIMARY KEY (`slotId`, `tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Great Vault reward tiers';

-- Pre-populate vault rewards
INSERT INTO `dc_mythic_vault_rewards` (`slotId`, `tier`, `dungeonsRequired`, `tokenAmount`) VALUES
-- Slot 1 (1 dungeon)
(1, 1, 1, 50),
(1, 2, 1, 100),
(1, 3, 1, 150),
-- Slot 2 (4 dungeons)
(2, 1, 4, 100),
(2, 2, 4, 200),
(2, 3, 4, 250),
-- Slot 3 (8 dungeons)
(3, 1, 8, 150),
(3, 2, 8, 250),
(3, 3, 8, 300);

-- ============================================================================
-- Table: dc_mythic_tokens_loot
-- Purpose: Token rewards per keystone level
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_tokens_loot` (
    `keystoneLevel` TINYINT UNSIGNED NOT NULL,
    `tokensOnCompletion` SMALLINT UNSIGNED NOT NULL COMMENT 'Tokens for successful completion',
    `tokensOnFailure` SMALLINT UNSIGNED NOT NULL COMMENT 'Tokens for 15-death failure',
    PRIMARY KEY (`keystoneLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Token rewards per keystone level';

-- Pre-populate token rewards
INSERT INTO `dc_mythic_tokens_loot` (`keystoneLevel`, `tokensOnCompletion`, `tokensOnFailure`) VALUES
(0, 30, 15),   -- M+0
(2, 50, 25),   -- M+2
(3, 60, 30),   -- M+3
(4, 70, 35),   -- M+4
(5, 80, 40),   -- M+5
(6, 90, 45),   -- M+6
(7, 100, 50),  -- M+7
(8, 110, 55),  -- M+8
(9, 120, 60),  -- M+9
(10, 130, 65); -- M+10

-- ============================================================================
-- Table: dc_mythic_achievement_defs
-- Purpose: Achievement definitions
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_achievement_defs` (
    `achievementId` INT UNSIGNED NOT NULL,
    `achievementName` VARCHAR(100) NOT NULL,
    `description` TEXT NOT NULL,
    `criteriaType` ENUM('Complete', 'Count', 'Threshold') NOT NULL,
    `criteriaValue` INT UNSIGNED NOT NULL COMMENT 'Required count/threshold',
    `rewardTitle` VARCHAR(100) DEFAULT NULL,
    `rewardItemEntry` INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`achievementId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Achievement definitions';

-- Pre-populate achievements
INSERT INTO `dc_mythic_achievement_defs` (`achievementId`, `achievementName`, `description`, `criteriaType`, `criteriaValue`, `rewardTitle`, `rewardItemEntry`) VALUES
-- Completion Achievements
(60001, 'Keystone Master', 'Complete a Mythic+10 dungeon', 'Threshold', 10, 'Keystone Master', 0),
(60002, 'Keystone Hero', 'Complete all Season 1 dungeons at M+5 or higher', 'Complete', 8, 'Keystone Hero', 0),
(60003, 'Keystone Conqueror', 'Complete all Season 1 dungeons at M+10', 'Complete', 8, 'Keystone Conqueror', 0),
-- Death-Related Achievements
(60004, 'Deathless', 'Complete a M+5 dungeon with 0 deaths', 'Threshold', 5, NULL, 0),
(60005, 'The Deathless', 'Complete a M+10 dungeon with 0 deaths', 'Threshold', 10, 'the Deathless', 0),
-- Speed Achievements
(60006, 'Speed Demon', 'Complete a M+5 dungeon in under 15 minutes', 'Threshold', 5, NULL, 0),
(60007, 'Blazing Fast', 'Complete a M+10 dungeon in under 20 minutes', 'Threshold', 10, NULL, 0),
-- Count Achievements
(60008, '10 Keystones', 'Complete 10 Mythic+ dungeons', 'Count', 10, NULL, 0),
(60009, '50 Keystones', 'Complete 50 Mythic+ dungeons', 'Count', 50, NULL, 0),
(60010, '100 Keystones', 'Complete 100 Mythic+ dungeons', 'Count', 100, NULL, 0),
(60011, '250 Keystones', 'Complete 250 Mythic+ dungeons', 'Count', 250, 'Keystone Legend', 0),
-- Rating Achievements
(60012, 'Novice Rating', 'Reach 500 Mythic+ rating', 'Threshold', 500, NULL, 0),
(60013, 'Advanced Rating', 'Reach 1000 Mythic+ rating', 'Threshold', 1000, NULL, 0),
(60014, 'Heroic Rating', 'Reach 1500 Mythic+ rating', 'Threshold', 1500, NULL, 0),
(60015, 'Mythic Rating', 'Reach 2000 Mythic+ rating', 'Threshold', 2000, 'the Mythic', 0),
-- Seasonal Achievements
(60016, 'Season 1 Champion', 'Complete all Season 1 achievements', 'Complete', 15, 'Season 1 Champion', 0),
(60017, 'Vault Collector', 'Claim all 3 vault slots in a single week', 'Complete', 3, NULL, 0),
(60018, 'Token Hoarder', 'Accumulate 10,000 Dungeon Tokens', 'Threshold', 10000, NULL, 0),
-- Affix-Specific Achievements
(60019, 'Tyrannical Master', 'Complete 10 dungeons with Tyrannical affix', 'Count', 10, NULL, 0),
(60020, 'Fortified Master', 'Complete 10 dungeons with Fortified affix', 'Count', 10, NULL, 0),
(60021, 'Affix Champion', 'Complete dungeons with all 8 affixes', 'Complete', 8, 'Affix Champion', 0),
(60022, 'Perfect Run', 'Complete M+10 with 0 deaths and all affixes active', 'Complete', 1, 'the Perfect', 0)
ON DUPLICATE KEY UPDATE achievementName=VALUES(achievementName), description=VALUES(description);

-- ============================================================================
-- Table: dc_mythic_npc_spawns
-- Purpose: NPC spawn locations (template data)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_npc_spawns` (
    `spawnId` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `npcEntry` INT UNSIGNED NOT NULL COMMENT 'NPC creature entry',
    `npcName` VARCHAR(100) NOT NULL,
    `mapId` SMALLINT UNSIGNED NOT NULL,
    `zoneId` INT UNSIGNED NOT NULL,
    `posX` FLOAT NOT NULL,
    `posY` FLOAT NOT NULL,
    `posZ` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL DEFAULT 0,
    PRIMARY KEY (`spawnId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='NPC spawn locations for M+ system';

-- Pre-populate NPC spawns (template - adjust coordinates as needed)
INSERT INTO `dc_mythic_npc_spawns` (`npcEntry`, `npcName`, `mapId`, `zoneId`, `posX`, `posY`, `posZ`, `orientation`) VALUES
-- Stormwind
(190003, 'Dungeon Teleporter', 0, 1519, -8833.0, 628.0, 94.0, 3.14),
(190004, 'Keystone Master', 0, 1519, -8831.0, 628.0, 94.0, 3.14),
-- Orgrimmar
(190003, 'Dungeon Teleporter', 1, 1637, 1573.0, -4439.0, 16.0, 1.57),
(190004, 'Keystone Master', 1, 1637, 1575.0, -4439.0, 16.0, 1.57),
-- Dalaran
(190003, 'Dungeon Teleporter', 571, 4395, 5809.0, 588.0, 660.0, 0.0),
(190004, 'Keystone Master', 571, 4395, 5811.0, 588.0, 660.0, 0.0);

-- ============================================================================
-- Table: dc_mythic_gameobjects
-- Purpose: GameObject spawn locations
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_gameobjects` (
    `spawnId` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `goEntry` INT UNSIGNED NOT NULL COMMENT 'GameObject entry',
    `goName` VARCHAR(100) NOT NULL,
    `mapId` SMALLINT UNSIGNED NOT NULL,
    `zoneId` INT UNSIGNED NOT NULL,
    `posX` FLOAT NOT NULL,
    `posY` FLOAT NOT NULL,
    `posZ` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL DEFAULT 0,
    PRIMARY KEY (`spawnId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='GameObject spawn locations for M+ system';

-- Pre-populate GameObject spawns
INSERT INTO `dc_mythic_gameobjects` (`goEntry`, `goName`, `mapId`, `zoneId`, `posX`, `posY`, `posZ`, `orientation`) VALUES
-- Great Vault (Stormwind, Orgrimmar, Dalaran)
(700000, 'Great Vault', 0, 1519, -8829.0, 628.0, 94.0, 0.0),
(700000, 'Great Vault', 1, 1637, 1577.0, -4439.0, 16.0, 0.0),
(700000, 'Great Vault', 571, 4395, 5813.0, 588.0, 660.0, 0.0),
-- Font of Power (inside dungeons - placeholder coords)
(700001, 'Font of Power - Utgarde Keep', 574, 4264, 0.0, 0.0, 0.0, 0.0),
(700002, 'Font of Power - Utgarde Pinnacle', 575, 4264, 0.0, 0.0, 0.0, 0.0),
(700003, 'Font of Power - The Nexus', 576, 4120, 0.0, 0.0, 0.0, 0.0),
(700004, 'Font of Power - The Oculus', 578, 4264, 0.0, 0.0, 0.0, 0.0),
(700005, 'Font of Power - Blood Furnace', 542, 3713, 0.0, 0.0, 0.0, 0.0),
(700006, 'Font of Power - Hellfire Ramparts', 543, 3562, 0.0, 0.0, 0.0, 0.0),
(700007, 'Font of Power - Stratholme', 329, 2017, 0.0, 0.0, 0.0, 0.0),
(700008, 'Font of Power - Deadmines', 36, 1581, 0.0, 0.0, 0.0, 0.0);

-- ============================================================================
-- END OF WORLD DATABASE SCHEMA
-- ============================================================================
