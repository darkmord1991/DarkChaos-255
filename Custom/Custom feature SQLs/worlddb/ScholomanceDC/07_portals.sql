-- =====================================================================================
-- Scholomance DC clone -- map 822, step 07: walk-through portals
--
-- Requires a worldserver carrying src/server/scripts/DC/ScholomanceDC/.
--
-- One way in and four ways out, matching stock Scholomance exactly:
--     5720000  entrance          map 751 -> 822   (from areatrigger 6828)
--     5720001  exit porch A      map 822 -> 751   (from areatrigger 2547)
--     5720002  exit porch B      map 822 -> 751   (from areatrigger 2548)
--     5720003  exit porch C      map 822 -> 751   (from areatrigger 2549)
--     5720004  exit, main door   map 822 -> 751   (from areatrigger 2568)
--
-- The three porch triggers all share one destination -- that is stock's own arrangement, a
-- wide porch covered by three overlapping boxes feeding a single spot outside.
--
-- ---------------------------------------------------------------------------------
-- WHY TRIGGER NPCs AND NOT AREATRIGGERS
-- ---------------------------------------------------------------------------------
-- Areatriggers were built end-to-end for the Shadowfang clone -- rows in `areatrigger` and
-- `areatrigger_teleport`, ids appended to AreaTrigger.dbc, deployed to patch-4,
-- patch-enGB-3 and all three WarcraftXLHost candidate directories -- and they never fire on
-- this fork's custom maps. An invisible creature with a ScriptName does the same job with
-- no client involvement.
--
-- THE SCRIPTNAME IS LOAD-BEARING. Creature::UpdateMoveInLineOfSightState (Creature.cpp:2631)
-- disables MoveInLineOfSight for anything carrying CREATURE_FLAG_EXTRA_TRIGGER, but the
-- check above it returns first when GetScriptId() is non-zero. Strip the ScriptName and all
-- five portals go dead silently.
--
-- ---------------------------------------------------------------------------------
-- RADII -- PER PORTAL, and the ENTRANCE is the tight one here
-- ---------------------------------------------------------------------------------
-- Sized from the stock areatrigger box each portal replaces, then capped by the requirement
-- that no trigger may reach the point another one drops players at:
--
--   portal        stock box L/W/H       half-extents        radius   nearest arrival   margin
--   entrance      10.6 / 13   / 21.7    5.3 x 6.5 x 10.85    5.5      9.21 yd          +3.71
--   exit porch A   8.2 / 38.4 / 60.4    4.1 x 19.2 x 30.2   12.0    144.17 yd      +132.2
--   exit porch B  11.2 / 37.4 / 44      5.6 x 18.7 x 22     12.0    129.94 yd      +117.9
--   exit porch C   9.7 / 31.4 / 54.2    4.85 x 15.7 x 27.1  12.0    141.98 yd      +130.0
--   exit main     12.3 /  8.9 / 16.4    6.15 x 4.45 x 8.2    6.0     18.43 yd        +12.43
--
-- THE ENTRANCE IS THE CONSTRAINED ONE, which is the reverse of Stratholme. The main-door
-- exit drops players on 751 only 9.21 yards from the entrance trigger, so the entrance
-- cannot be widened toward stock's 6.5 half-width without risking a bounce. 5.5 leaves a
-- 3.71 yd margin -- exactly the margin the Shadowfang portals ship on and work with.
--
-- The three porch exits are unconstrained (the nearest arrival point on their own map is
-- 130+ yd away), so they are sized purely for coverage. Stock used very wide boxes there
-- (half-widths 15.7-19.2) and a sphere cannot reproduce that shape, so the three are sized
-- to form a CONTINUOUS chain instead: B and C sit 36.9 yd apart at opposite ends of the
-- porch with A between them (A-B 21.4, A-C 20.3). At radius 12.0 the chain B-A-C overlaps
-- at both joints (2.6 and 3.7 yd) with no gap to walk through. At 10.0 it does not -- that
-- leaves 1.4 and 0.3 yd dead strips, which is why this is 12.0 and not 10.0.
--
-- IDS (bands verified empty first)
--   creature_template  5720000 - 5720004
--   creature guids    16751000 - 16751004   (clear of the 16750000-16750398 spawn block)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Templates
--
-- Flags copied from stock "World Trigger (Not Immune PC)" (21252) rather than invented:
--     unit_flags  33554432 = UNIT_FLAG_NOT_SELECTABLE  -- no nameplate, no tab-target
--     flags_extra 130      = TRIGGER (0x80) | NO_XP (0x02)
--     faction     114      -- the standard trigger faction, hostile to nobody
--     type        10       -- not a creature type that counts for anything
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` BETWEEN 5720000 AND 5720004;
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
     `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`,
     `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`, `MovementType`)
VALUES
    (5720000, 'Scholomance Entrance', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_scholomance_dc_portal_trigger', 0),
    (5720001, 'Scholomance Exit (Porch A)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_scholomance_dc_portal_trigger', 0),
    (5720002, 'Scholomance Exit (Porch B)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_scholomance_dc_portal_trigger', 0),
    (5720003, 'Scholomance Exit (Porch C)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_scholomance_dc_portal_trigger', 0),
    (5720004, 'Scholomance Exit (Main Door)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_scholomance_dc_portal_trigger', 0);

-- -------------------------------------------------------------------------------------
-- 2. The display layer -- required, or the creature never loads.
--
-- ObjectMgr refuses to load a creature with no creature_template_model row, and the error
-- names only that table. This is what left the whole Shadowfang clone empty on first boot.
-- Display 11686 is the standard invisible stalker and is already in creature_model_info.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5720000 AND 5720004;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
    (5720000, 0, 11686, 1, 1, 0),
    (5720001, 0, 11686, 1, 1, 0),
    (5720002, 0, 11686, 1, 1, 0),
    (5720003, 0, 11686, 1, 1, 0),
    (5720004, 0, 11686, 1, 1, 0);

-- -------------------------------------------------------------------------------------
-- 3. Spawns -- at the stock areatrigger centres.
--
-- Orientation is 0 throughout: these are invisible, unselectable and never interacted with,
-- so facing has no effect on anything.
--
-- Guids are explicit. The AUTO_INCREMENT counters on this realm sit above 0xFFFFFF and
-- ObjectMgr.cpp:7669 rejects anything at or above it -- one guid-less INSERT here bricks
-- startup with TCE00007.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 16751000 AND 16751004;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `ScriptName`, `VerifiedBuild`)
VALUES
    -- entrance, from areatrigger 6828, in Western Plaguelands on 751
    (16751000, 5720000, 751, 0, 0, 1, 1, 0,
     1282.05, -2548.73, 85.40, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    -- exit porch A/B/C, from areatriggers 2547 / 2548 / 2549
    (16751001, 5720001, 822, 0, 0, 7, 1, 0,
     332.87, 94.31, 92.22, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    (16751002, 5720002, 822, 0, 0, 7, 1, 0,
     322.88, 112.14, 98.67, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    (16751003, 5720003, 822, 0, 0, 7, 1, 0,
     325.18, 75.62, 93.87, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    -- exit at the main door, from areatrigger 2568
    (16751004, 5720004, 822, 0, 0, 7, 1, 0,
     182.26, 126.45, 143.71, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0);

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'portal templates (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 5720000 AND 5720004
UNION ALL SELECT 'all five carry the script (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5720000 AND 5720004
      AND `ScriptName` = 'npc_scholomance_dc_portal_trigger'
UNION ALL SELECT 'creature_template_model rows (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5720000 AND 5720004
UNION ALL SELECT 'their display exists in creature_model_info (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_model_info` WHERE `DisplayID` = 11686
UNION ALL SELECT 'portal spawns (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16751000 AND 16751004
UNION ALL SELECT 'one entrance on map 751 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16751000 AND `map` = 751
UNION ALL SELECT 'four exits inside the clone (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16751001 AND 16751004 AND `map` = 822
UNION ALL SELECT 'exits on all three difficulties (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16751001 AND 16751004 AND `spawnMask` = 7
UNION ALL SELECT 'all flagged unselectable + trigger (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5720000 AND 5720004
      AND (`unit_flags` & 33554432) AND (`flags_extra` & 128)
UNION ALL SELECT 'guids below the 0xFFFFFF cap (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16751000 AND 16751004 AND `guid` < 16777215
-- Must not collide with the 399 cloned spawns.
UNION ALL SELECT 'portal guids clashing with cloned spawns (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cguid` WHERE `dst_guid` BETWEEN 16751000 AND 16751004
-- Stock Scholomance keeps its own entrance and its four exits, all unchanged.
UNION ALL SELECT 'stock entrance trigger still aimed at map 289 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 6828 AND `target_map` = 289
UNION ALL SELECT 'stock exit triggers still aimed at map 0 (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` IN (2547, 2548, 2549, 2568) AND `target_map` = 0;
