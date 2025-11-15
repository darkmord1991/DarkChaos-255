-- ========================================================================
-- DarkChaos Mythic+ System - Fix Multipliers
-- ========================================================================
-- Purpose: Update base_health_mult and base_damage_mult to proper values
-- Database: acore_world
-- Date: November 2025
-- ========================================================================

USE acore_world;

-- Fix Vanilla dungeons (map_id 33-429) - Mythic scaling 3x HP, 2x Damage
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `base_health_mult` = 3.0,
    `base_damage_mult` = 2.0
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

-- Fix TBC dungeons (map_id 269, 540-585) - Mythic scaling 3x HP, 2x Damage
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `base_health_mult` = 3.0,
    `base_damage_mult` = 2.0
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

-- Fix WotLK dungeons (map_id 574-650) - Mythic scaling 1.35x HP, 1.20x Damage
UPDATE `dc_dungeon_mythic_profile` 
SET 
    `base_health_mult` = 1.35,
    `base_damage_mult` = 1.20
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
    668  -- Halls of Reflection
);

-- Verify the changes
SELECT 
    `map_id`, 
    `name`, 
    `base_health_mult`, 
    `base_damage_mult`,
    CASE 
        WHEN `map_id` < 530 THEN 'Vanilla'
        WHEN `map_id` < 571 THEN 'TBC'
        ELSE 'WotLK'
    END AS expansion
FROM `dc_dungeon_mythic_profile`
ORDER BY `map_id`;
