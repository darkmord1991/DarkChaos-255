-- ============================================================================
-- Clone Creature Spawns for All Difficulties (Heroic/Mythic/Mythic+)
-- ============================================================================
-- Purpose: Update creature spawns to support all difficulty modes
-- This prevents crashes when entering dungeons/raids in new difficulty modes
-- ============================================================================

-- SpawnMask System (from DBCEnums.h):
-- ========================================
-- DUNGEONS:
--   Bit 0 (1 << 0 = 0x01 = 1)   = DUNGEON_DIFFICULTY_NORMAL (0)
--   Bit 1 (1 << 1 = 0x02 = 2)   = DUNGEON_DIFFICULTY_HEROIC (1)
--   Bit 4 (1 << 4 = 0x10 = 16)  = DUNGEON_DIFFICULTY_MYTHIC (4)
--   Bit 5 (1 << 5 = 0x20 = 32)  = DUNGEON_DIFFICULTY_MYTHIC_PLUS (5)
--
-- RAIDS:
--   Bit 0 (1 << 0 = 0x01 = 1)   = RAID_DIFFICULTY_10MAN_NORMAL (0)
--   Bit 1 (1 << 1 = 0x02 = 2)   = RAID_DIFFICULTY_25MAN_NORMAL (1)
--   Bit 2 (1 << 2 = 0x04 = 4)   = RAID_DIFFICULTY_10MAN_HEROIC (2)
--   Bit 3 (1 << 3 = 0x08 = 8)   = RAID_DIFFICULTY_25MAN_HEROIC (3)
--   Bit 4 (1 << 4 = 0x10 = 16)  = RAID_DIFFICULTY_10MAN_MYTHIC (4)
--   Bit 5 (1 << 5 = 0x20 = 32)  = RAID_DIFFICULTY_25MAN_MYTHIC (5)
--
-- Common SpawnMask Values:
--   DUNGEON_ALL = 1 | 2 | 16 | 32 = 51  (Normal + Heroic + Mythic + Mythic+)
--   RAID_ALL = 1 | 2 | 4 | 8 | 16 | 32 = 63  (All raid difficulties)

-- ============================================================================
-- STEP 1: Update Season 1 Mythic+ Dungeons for ALL difficulty modes
-- ============================================================================
-- Add Mythic and Mythic+ support to existing spawnMask values
-- Uses bitwise OR to preserve existing Normal/Heroic configurations
-- Target: spawnMask | 48 = add bits for Mythic (16) + Mythic+ (32)

-- For WotLK dungeons that already have Normal+Heroic (spawnMask=3):
--   3 | 48 = 51 (Normal + Heroic + Mythic + Mythic+)
-- For Classic/TBC dungeons with Normal only (spawnMask=1):
--   1 | 48 = 49 (Normal + Mythic + Mythic+) - preserves original design

UPDATE `creature` SET `spawnMask` = `spawnMask` | 48
WHERE `map` IN (
    -- Season 1 Active Mythic+ Dungeons ONLY
    574,  -- Utgarde Keep (WotLK - likely has 3)
    575,  -- Utgarde Pinnacle (WotLK - likely has 3)
    576,  -- The Nexus (WotLK - likely has 3)
    578,  -- The Oculus (WotLK - likely has 3)
    542,  -- The Blood Furnace (TBC - may have 1)
    543,  -- Hellfire Ramparts (TBC - may have 1)
    329,  -- Stratholme (Classic - may have 1)
    36    -- Deadmines (Classic - may have 1)
);

-- ============================================================================
-- STEP 1B: Update OTHER dungeons for Mythic difficulty only
-- ============================================================================
-- Add Mythic support to existing spawnMask values
-- Uses bitwise OR to preserve existing Normal/Heroic configurations
-- Target: spawnMask | 16 = add bit for Mythic (16) only

UPDATE `creature` SET `spawnMask` = `spawnMask` | 16
WHERE `map` IN (
    -- WotLK Dungeons (not in Season 1)
    595,  -- The Culling of Stratholme
    599,  -- Halls of Stone
    600,  -- Drak'Tharon Keep
    601,  -- Azjol-Nerub
    602,  -- Halls of Lightning
    604,  -- Gundrak
    608,  -- Violet Hold
    619,  -- Ahn'kahet: The Old Kingdom
    632,  -- Forge of Souls
    658,  -- Pit of Saron
    668,  -- Halls of Reflection
    
    -- TBC Dungeons (not in Season 1)
    540,  -- The Shattered Halls
    545,  -- The Steamvault
    546,  -- The Underbog
    547,  -- The Slave Pens
    552,  -- The Arcatraz
    553,  -- The Botanica
    554,  -- The Mechanar
    555,  -- Shadow Labyrinth
    556,  -- Sethekk Halls
    557,  -- Mana-Tombs
    558,  -- Auchenai Crypts
    560,  -- Old Hillsbrad Foothills
    568,  -- Zul'Aman
    585,  -- Magisters' Terrace
    
    -- Classic Dungeons (not in Season 1)
    33,   -- Shadowfang Keep
    34,   -- The Stockade
    43,   -- Wailing Caverns
    47,   -- Razorfen Kraul
    48,   -- Blackfathom Deeps
    70,   -- Uldaman
    90,   -- Gnomeregan
    109,  -- Sunken Temple
    129,  -- Razorfen Downs
    189,  -- Scarlet Monastery
    209,  -- Zul'Farrak
    229,  -- Blackrock Spire
    230,  -- Blackrock Depths
    289,  -- Scholomance
    349,  -- Maraudon
    389   -- Ragefire Chasm
);

-- ============================================================================
-- STEP 2: Update RAIDS for ALL difficulty modes
-- ============================================================================
-- Add Mythic support (both 10-man and 25-man) to existing raid spawnMasks
-- Uses bitwise OR to preserve existing Normal/Heroic configurations
-- Target: spawnMask | 48 = add bits for 10M Mythic (16) + 25M Mythic (32)

-- For raids with 10N+25N+10H+25H (spawnMask=15):
--   15 | 48 = 63 (all 6 difficulties)
-- For raids with only 10N (spawnMask=1):
--   1 | 48 = 49 (10N + 10M + 25M)
-- Preserves whatever difficulty configuration already exists

UPDATE `creature` SET `spawnMask` = `spawnMask` | 48
WHERE `map` IN (
    -- WotLK Raids
    249,  -- Onyxia's Lair
    603,  -- Ulduar
    615,  -- The Obsidian Sanctum
    616,  -- The Eye of Eternity
    624,  -- Vault of Archavon
    631,  -- Icecrown Citadel
    649,  -- Trial of the Crusader
    724,  -- The Ruby Sanctum
    
    -- TBC Raids
    532,  -- Karazhan
    544,  -- Magtheridon's Lair
    548,  -- Coilfang: Serpentshrine Cavern
    550,  -- Tempest Keep
    564,  -- Black Temple
    565,  -- Gruul's Lair
    580,  -- Sunwell Plateau
    
    -- Classic Raids
    309,  -- Zul'Gurub
    409,  -- Molten Core
    469,  -- Blackwing Lair
    509,  -- Ruins of Ahn'Qiraj
    531,  -- Ahn'Qiraj Temple
    533   -- Naxxramas
);

-- ============================================================================
-- STEP 3: Update GAMEOBJECTS for Season 1 dungeons
-- ============================================================================
-- Add Mythic and Mythic+ support to gameobjects (doors, levers, etc.)
-- ONLY update gameobjects with spawnMask 1, 2, or 3 to avoid invalid combinations
UPDATE `gameobject` SET `spawnMask` = `spawnMask` | 48
WHERE `map` IN (
    -- Season 1 Active Mythic+ Dungeons
    574, 575, 576, 578, 542, 543, 329, 36
)
AND `spawnMask` IN (1, 2, 3);  -- Only update Normal/Heroic spawns

-- ============================================================================
-- STEP 3B: Update GAMEOBJECTS for other dungeons
-- ============================================================================
-- Add Mythic support only to other dungeons
-- ONLY update gameobjects with spawnMask 1, 2, or 3 to avoid invalid combinations
UPDATE `gameobject` SET `spawnMask` = `spawnMask` | 16
WHERE `map` IN (
    -- WotLK Dungeons (not in Season 1)
    595, 599, 600, 601, 602, 604, 608, 619, 632, 658, 668,
    -- TBC Dungeons (not in Season 1)
    540, 545, 546, 547, 552, 553, 554, 555, 556, 557, 558, 560, 568, 585,
    -- Classic Dungeons (not in Season 1)
    33, 34, 43, 47, 48, 70, 90, 109, 129, 189, 209, 229, 230, 289, 349, 389
)
AND `spawnMask` IN (1, 2, 3);  -- Only update Normal/Heroic spawns

-- ============================================================================
-- STEP 4: Update GAMEOBJECTS for raids
-- ============================================================================
-- SKIPPED: Raids have complex difficulty requirements that vary by expansion
-- Manual review required for raid gameobjects to avoid invalid spawnMask values
-- Classic raids: 40-man only (spawnMask should be 1)
-- TBC raids: 10/25-man (spawnMask should be 1, 2, or 3)
-- WotLK raids: 10N/25N/10H/25H (spawnMask varies by raid)
-- Adding Mythic blindly creates invalid combinations

-- UPDATE `gameobject` SET `spawnMask` = `spawnMask` | 48
-- WHERE `map` IN (
--     -- WotLK Raids
--     249, 603, 615, 616, 624, 631, 649, 724,
--     -- TBC Raids
--     532, 544, 548, 550, 564, 565, 580,
--     -- Classic Raids
--     309, 409, 469, 509, 531, 533
-- );

-- ============================================================================
-- VERIFICATION QUERIES (Run these to check the updates)
-- ============================================================================
-- Check dungeon creature spawns:
-- SELECT map, spawnMask, COUNT(*) as count FROM creature WHERE map IN (36, 574, 575) GROUP BY map, spawnMask;

-- Check raid creature spawns:
-- SELECT map, spawnMask, COUNT(*) as count FROM creature WHERE map IN (249, 603, 631) GROUP BY map, spawnMask;

-- Expected results:
--   Dungeons should have spawnMask = 51
--   Raids should have spawnMask = 63

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. Uses bitwise OR (|) to ADD difficulty support without removing existing configs
-- 2. This preserves existing Normal/Heroic separation if it exists in WotLK content
-- 3. For WotLK dungeons with spawnMask=3 (N+H): 3 | 48 = 51 (N+H+M+M+)
-- 4. For Classic dungeons with spawnMask=1 (N only): 1 | 48 = 49 (N+M+M+)
-- 5. The actual scaling (health, damage) is handled by C++ DungeonEnhancement code
-- 6. For Mythic+, the system uses Heroic as base, then applies keystone scaling
-- 7. This approach respects any existing difficulty-specific spawn configurations
-- 8. Run check_wotlk_spawnmasks.sql FIRST to verify existing values if concerned
-- ============================================================================
