-- =====================================================================================
-- Stratholme DC clone -- map 821, step 07: walk-through portals
--
-- Requires a worldserver carrying src/server/scripts/DC/StratholmeDC/.
--
-- Three ways in and one way out, matching stock Stratholme exactly:
--     5520000  front right gate   map 751 -> 821
--     5520001  front left gate    map 751 -> 821
--     5520002  back entrance      map 751 -> 821
--     5520003  the exit           map 821 -> 751
--
-- ---------------------------------------------------------------------------------
-- WHY TRIGGER NPCs AND NOT AREATRIGGERS
-- ---------------------------------------------------------------------------------
-- Areatriggers were built end-to-end for the Shadowfang clone -- rows in `areatrigger` and
-- `areatrigger_teleport`, ids appended to AreaTrigger.dbc, deployed to patch-4,
-- patch-enGB-3 and all three WarcraftXLHost candidate directories -- and they never fire.
-- Standing 2.01 yards from the centre of a radius-7 trigger on custom map 751, with the
-- server-side row present and correct, the client sends no CMSG_AREATRIGGER at all, while
-- stock triggers on maps 0 and 33 fire normally from the same client and the same DBC.
--
-- An invisible creature with a ScriptName does the same job with no client involvement.
--
-- ---------------------------------------------------------------------------------
-- THE SCRIPTNAME IS LOAD-BEARING, NOT DECORATION
-- ---------------------------------------------------------------------------------
-- Creature::UpdateMoveInLineOfSightState (Creature.cpp:2631) disables MoveInLineOfSight for
-- anything carrying CREATURE_FLAG_EXTRA_TRIGGER -- but the check above it returns first:
--       if (IsPet() || ... || GetScriptId() || GetAIName() == "SmartAI") { ...; return; }
-- A non-zero GetScriptId() keeps the hook alive. Strip the ScriptName and all four portals
-- go dead silently, with the flags alone switching them off.
--
-- ---------------------------------------------------------------------------------
-- COORDINATES AND RADII
-- ---------------------------------------------------------------------------------
-- Every position and destination below is copied from the stock areatrigger it replaces
-- (6823, 6824, 6822 and 2221), so the clone's doors are exactly where players already
-- expect them. The one substitution is the exit's destination map: stock 2221 sends players
-- to map 0, and the clone sends them to 751 instead -- which is the whole reason this
-- dungeon needed its own map id.
--
-- The RADII are per-portal and live in npc_stratholme_dc_portal_trigger.cpp, not here.
-- They are sized from the stock areatrigger box each portal replaces:
--
--     portal        stock box L/W/H        half-extents       radius
--     front right   22.83 / 20   / 34.69   11.4 x 10 x 17.3    11.0
--     front left    27.94 / 20   / 35.19   14.0 x 10 x 17.6    11.0
--     back          10    / 10   / 10       5.0 x  5 x  5.0     5.0
--     exit           9.78 / 17.94 / 27.92   4.9 x  9 x 14.0     5.0
--
-- The front gates are large because stock's volume is: a 5.0 sphere there would let anyone
-- walking through the main gate more than 5 yards off-centre pass through nothing at all.
-- At 20.2 yd apart and radius 11.0 the two front spheres overlap by 1.8 yd, deliberately --
-- a gap would be a dead strip down the centre of the gate.
--
-- A trigger must NOT reach the point another one drops players at, or players bounce
-- straight back. Verified clearances (trigger vs every arrival point on its OWN map):
--     front gates <-> exit drop on 751        : 680.7 / 700.3 yd   margin +669.7 / +689.3
--     back        <-> exit drop on 751        :  10.80 yd          margin  +5.80
--     exit        <-> back arrival in 821     :  13.23 yd          margin  +8.23
--     exit        <-> front arrivals in 821   : 307.1 / 327.2 yd   margin +302.1 / +322.2
-- The Shadowfang portals ship on a 3.72 yd margin and work, so the two tight ones are
-- comfortable. The front pair is unconstrained -- nothing lands within 680 yd of it.
--
-- IDS (bands verified empty first)
--   creature_template  5520000 - 5520003
--   creature guids    16741000 - 16741003   (clear of the 16740000-16740467 spawn block)
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
DELETE FROM `creature_template` WHERE `entry` BETWEEN 5520000 AND 5520003;
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
     `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`,
     `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`, `MovementType`)
VALUES
    (5520000, 'Stratholme Entrance (Front Right)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_stratholme_dc_portal_trigger', 0),
    (5520001, 'Stratholme Entrance (Front Left)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_stratholme_dc_portal_trigger', 0),
    (5520002, 'Stratholme Entrance (Back)', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_stratholme_dc_portal_trigger', 0),
    (5520003, 'Stratholme Exit', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_stratholme_dc_portal_trigger', 0);

-- -------------------------------------------------------------------------------------
-- 2. The display layer -- required, or the creature never loads.
--
-- ObjectMgr refuses to load a creature with no creature_template_model row, and the error
-- names only that table. This is what left the whole Shadowfang clone empty on first boot.
-- Display 11686 is the standard invisible stalker and is already in creature_model_info.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5520000 AND 5520003;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
    (5520000, 0, 11686, 1, 1, 0),
    (5520001, 0, 11686, 1, 1, 0),
    (5520002, 0, 11686, 1, 1, 0),
    (5520003, 0, 11686, 1, 1, 0);

-- -------------------------------------------------------------------------------------
-- 3. Spawns
--
-- Positions are the stock areatrigger centres: 6823, 6824 and 6822 on map 751, and 2221
-- inside the dungeon.
--
-- Guids are explicit. The AUTO_INCREMENT counters on this realm sit above 0xFFFFFF and
-- ObjectMgr.cpp:7669 rejects anything at or above it -- one guid-less INSERT here bricks
-- startup with TCE00007.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 16741000 AND 16741003;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `ScriptName`, `VerifiedBuild`)
VALUES
    -- front right gate, from areatrigger 6823
    (16741000, 5520000, 751, 0, 0, 1, 1, 0,
     3392.46, -3389.2, 143.073, 1.571, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    -- front left gate, from areatrigger 6824
    (16741001, 5520001, 751, 0, 0, 1, 1, 0,
     3392.56, -3369, 142.802, 4.712, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    -- back entrance, from areatrigger 6822
    (16741002, 5520002, 751, 0, 0, 1, 1, 0,
     3237.46, -4060.6, 112.01, 5.498, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    -- the exit, from areatrigger 2221, now standing inside the CLONE
    (16741003, 5520003, 821, 0, 0, 1, 1, 0,
     3584.78, -3632.05, 142.12, 1.935, 300, 0, 0, 1, 0, 0, 0, 0, '', 0);

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'portal templates (want 4)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 5520000 AND 5520003
-- Without the ScriptName the trigger flag silently disables MoveInLineOfSight.
UNION ALL SELECT 'all four carry the script (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5520000 AND 5520003
      AND `ScriptName` = 'npc_stratholme_dc_portal_trigger'
UNION ALL SELECT 'creature_template_model rows (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5520000 AND 5520003
UNION ALL SELECT 'their display exists in creature_model_info (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_model_info` WHERE `DisplayID` = 11686
UNION ALL SELECT 'portal spawns (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16741000 AND 16741003
UNION ALL SELECT 'three entrances on map 751 (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16741000 AND 16741002 AND `map` = 751
UNION ALL SELECT 'one exit inside the clone (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16741003 AND `map` = 821
UNION ALL SELECT 'all flagged unselectable + trigger (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5520000 AND 5520003
      AND (`unit_flags` & 33554432) AND (`flags_extra` & 128)
UNION ALL SELECT 'guids below the 0xFFFFFF cap (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16741000 AND 16741003 AND `guid` < 16777215
-- Must not collide with the 468 cloned spawns.
UNION ALL SELECT 'portal guids clashing with cloned spawns (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cguid` WHERE `dst_guid` BETWEEN 16741000 AND 16741003
-- Stock Stratholme keeps its own three entrances and its own exit, all unchanged.
UNION ALL SELECT 'stock entrance triggers still aimed at map 329 (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` IN (6822, 6823, 6824) AND `target_map` = 329
UNION ALL SELECT 'stock exit trigger still aimed at map 0 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 2221 AND `target_map` = 0;
