-- ========================================================================
-- DarkChaos Mythic+ System - Add Level Scaling Columns
-- ========================================================================
-- Purpose: Add configurable level scaling columns to existing table
-- Database: acore_world
-- Date: November 2025
-- ========================================================================

USE acore_world;

-- Add level scaling columns (will skip if already exist)
SET @exist := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_SCHEMA = 'acore_world' 
               AND TABLE_NAME = 'dc_dungeon_mythic_profile' 
               AND COLUMN_NAME = 'heroic_level_normal');

SET @sqlstmt := IF(@exist = 0, 
    'ALTER TABLE `dc_dungeon_mythic_profile`
     ADD COLUMN `heroic_level_normal` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Heroic normal mob level (0 = keep original)'' AFTER `base_damage_mult`,
     ADD COLUMN `heroic_level_elite` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Heroic elite mob level (0 = keep original)'' AFTER `heroic_level_normal`,
     ADD COLUMN `heroic_level_boss` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Heroic boss level (0 = keep original)'' AFTER `heroic_level_elite`,
     ADD COLUMN `mythic_level_normal` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Mythic normal mob level (0 = keep original)'' AFTER `heroic_level_boss`,
     ADD COLUMN `mythic_level_elite` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Mythic elite mob level (0 = keep original)'' AFTER `mythic_level_normal`,
     ADD COLUMN `mythic_level_boss` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Mythic boss level (0 = keep original)'' AFTER `mythic_level_elite`',
    'SELECT ''Columns already exist, skipping...'' AS message');

PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Update Vanilla dungeons: Heroic 60-62, Mythic 80-82
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `heroic_level_normal` = 60,
    `heroic_level_elite` = 61,
    `heroic_level_boss` = 62,
    `mythic_level_normal` = 80,
    `mythic_level_elite` = 81,
    `mythic_level_boss` = 82
WHERE `map_id` IN (
    36,  -- Deadmines
    33,  -- Shadowfang Keep
    34,  -- The Stockade
    48,  -- Blackfathom Deeps
    43,  -- Wailing Caverns
    47,  -- Razorfen Kraul
    129, -- Razorfen Downs
    90,  -- Gnomeregan
    109, -- Sunken Temple
    70,  -- Uldaman
    189, -- Scarlet Monastery
    209, -- Zul'Farrak
    349, -- Maraudon
    230, -- Blackrock Depths
    229, -- Lower Blackrock Spire
    329, -- Stratholme
    429, -- Dire Maul
    289  -- Scholomance
);

-- Update TBC dungeons: Heroic keep original (0), Mythic 80-82
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `heroic_level_normal` = 0,
    `heroic_level_elite` = 0,
    `heroic_level_boss` = 0,
    `mythic_level_normal` = 80,
    `mythic_level_elite` = 81,
    `mythic_level_boss` = 82
WHERE `map_id` IN (
    542, -- The Blood Furnace
    543, -- Hellfire Ramparts
    540, -- The Shattered Halls
    545, -- The Steamvault
    546, -- The Underbog
    547, -- The Slave Pens
    555, -- Shadow Labyrinth
    556, -- Sethekk Halls
    557, -- Mana-Tombs
    558, -- Auchenai Crypts
    553, -- The Botanica
    554, -- The Mechanar
    552, -- The Arcatraz
    560, -- Old Hillsbrad Foothills
    269, -- The Black Morass
    585  -- Magisters' Terrace
);

-- Update WotLK dungeons: Heroic keep original (0), Mythic keep original (0)
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `heroic_level_normal` = 0,
    `heroic_level_elite` = 0,
    `heroic_level_boss` = 0,
    `mythic_level_normal` = 0,
    `mythic_level_elite` = 0,
    `mythic_level_boss` = 0
WHERE `map_id` IN (
    574, -- Utgarde Keep
    575, -- Utgarde Pinnacle
    576, -- The Nexus
    578, -- The Oculus
    595, -- The Culling of Stratholme
    599, -- Halls of Stone
    600, -- Drak'Tharon Keep
    601, -- Azjol-Nerub
    602, -- Halls of Lightning
    604, -- Gundrak
    608, -- Violet Hold
    619, -- Ahn'kahet: The Old Kingdom
    632, -- The Forge of Souls
    658, -- Pit of Saron
    668, -- Halls of Reflection
    650  -- Trial of the Champion
);

-- Verify the changes
SELECT 
    `map_id`, 
    `name`, 
    `heroic_level_normal`, 
    `heroic_level_elite`, 
    `heroic_level_boss`,
    `mythic_level_normal`,
    `mythic_level_elite`,
    `mythic_level_boss`,
    CASE 
        WHEN `map_id` < 530 THEN 'Vanilla'
        WHEN `map_id` < 571 THEN 'TBC'
        ELSE 'WotLK'
    END AS expansion
FROM `dc_dungeon_mythic_profile`
ORDER BY `map_id`;
