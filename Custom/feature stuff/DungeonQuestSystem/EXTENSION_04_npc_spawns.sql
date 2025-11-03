-- ============================================================================
-- DC DUNGEON QUEST SYSTEM - NPC SPAWNS v4.0
-- Daily/Weekly Quest Herald (NPC 700003) - Major City Spawns
-- ============================================================================
-- Purpose: Spawn Quest Herald NPC in Stormwind, Orgrimmar, Dalaran, and Shattrath
-- Method: Standard AzerothCore creature spawn using spawnMask=1, phaseMask=1
-- Coordinates: Taken from major city center points near banks/flight masters
-- ============================================================================

-- ============================================================================
-- CLEANUP: Remove existing spawns
-- ============================================================================

DELETE FROM `creature` WHERE `id1` = 700003;

-- ============================================================================
-- SPAWN 1: STORMWIND CITY (Alliance Hub)
-- Location: Trade District, near the bank
-- Map: 0 (Eastern Kingdoms), Zone: 1519 (Stormwind City), Area: 5390 (Trade District)
-- Coordinates: x=-8844.95, y=626.358, z=94.122, o=3.94
-- ============================================================================

INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
((SELECT MAX(guid)+1 FROM creature), 700003, 0, 0, 0, 1519, 5390, 1, 1, 0, -8844.95, 626.358, 94.122, 3.94, 300, 0, 0, 10000, 10000, 0, 3, 0, 0, 'npc_dungeon_quest_daily_weekly', 0);

-- ============================================================================
-- SPAWN 2: ORGRIMMAR (Horde Hub)
-- Location: Valley of Strength, near the bank
-- Map: 1 (Kalimdor), Zone: 1637 (Orgrimmar), Area: 1638 (Valley of Strength)
-- Coordinates: x=1574.59, y=-4439.23, z=15.44, o=1.74
-- ============================================================================

INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
((SELECT MAX(guid)+2 FROM creature), 700003, 0, 0, 1, 1637, 1638, 1, 1, 0, 1574.59, -4439.23, 15.44, 1.74, 300, 0, 0, 10000, 10000, 0, 3, 0, 0, 'npc_dungeon_quest_daily_weekly', 0);

-- ============================================================================
-- SPAWN 3: DALARAN (Neutral - WotLK Hub)
-- Location: Runeweaver Square, near the bank
-- Map: 571 (Northrend), Zone: 4395 (Dalaran), Area: 4560 (Runeweaver Square)
-- Coordinates: x=5809.55, y=588.347, z=660.139, o=1.692
-- ============================================================================

INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
((SELECT MAX(guid)+3 FROM creature), 700003, 0, 0, 571, 4395, 4560, 1, 1, 0, 5809.55, 588.347, 660.139, 1.692, 300, 0, 0, 10000, 10000, 0, 3, 0, 0, 'npc_dungeon_quest_daily_weekly', 0);

-- ============================================================================
-- SPAWN 4: SHATTRATH CITY (Neutral - TBC Hub)
-- Location: Center of Terrace of Light, near the bank
-- Map: 530 (Outland), Zone: 3703 (Shattrath City), Area: 3703 (Shattrath City)
-- Coordinates: x=-1838.16, y=5301.79, z=-12.428, o=5.5
-- ============================================================================

INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
((SELECT MAX(guid)+4 FROM creature), 700003, 0, 0, 530, 3703, 3703, 1, 1, 0, -1838.16, 5301.79, -12.428, 5.5, 300, 0, 0, 10000, 10000, 0, 3, 0, 0, 'npc_dungeon_quest_daily_weekly', 0);

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================

-- Check if NPC 700003 spawned correctly
SELECT 
    guid,
    id1 AS npc_id,
    map,
    CASE
        WHEN map = 0 AND zoneId = 1519 THEN 'Stormwind City'
        WHEN map = 1 AND zoneId = 1637 THEN 'Orgrimmar'
        WHEN map = 571 AND zoneId = 4395 THEN 'Dalaran'
        WHEN map = 530 AND zoneId = 3703 THEN 'Shattrath City'
        ELSE 'Unknown'
    END AS location,
    position_x,
    position_y,
    position_z,
    spawntimesecs,
    spawnMask,
    phaseMask
FROM creature
WHERE id1 = 700003
ORDER BY guid;

-- ============================================================================
-- NOTES
-- ============================================================================
-- • NPC 700003 (Quest Herald) offers all daily and weekly dungeon quests
-- • Spawned in 4 major cities for easy access by both factions
-- • spawnMask = 1 (normal difficulty only, standard for world NPCs)
-- • phaseMask = 1 (default phase, visible to all players)
-- • spawntimesecs = 300 (5 minutes respawn time)
-- • MovementType = 0 (stationary)
-- • npcflag = 3 (gossip + quest giver)
-- • ScriptName links to npc_dungeon_quest_daily_weekly C++ script
--
-- GUID CALCULATION:
-- • Uses (SELECT MAX(guid)+X FROM creature) to auto-increment safely
-- • Each spawn gets +1, +2, +3, +4 respectively
-- • Prevents GUID conflicts with existing creatures
--
-- COORDINATES SOURCE:
-- • Stormwind: Trade District near the bank (Alliance main hub)
-- • Orgrimmar: Valley of Strength near the bank (Horde main hub)
-- • Dalaran: Runeweaver Square near the bank (WotLK neutral hub)
-- • Shattrath: Terrace of Light center (TBC neutral hub)
-- ============================================================================
