-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 19: walk-through portal triggers
--
-- Two invisible trigger creatures that teleport you when you walk into them. No click.
-- This is the behaviour an areatrigger would have given, done the way that actually works
-- on this fork's custom maps.
--
-- REQUIRES 17_portals.sql (the visible portal objects) and a worldserver carrying
-- npc_sfk_cata_portal_trigger.cpp -- already built.
--
-- ---------------------------------------------------------------------------------
-- HOW THIS WORKS
-- ---------------------------------------------------------------------------------
-- The gameobject from 17 supplies the visual and stays clickable as a fallback; these
-- NPCs stand inside it and poll every 500ms for players within 3 yards. The radius is
-- deliberately tighter than the areatriggers it replaces (7 in / 5 out) so you are moved
-- when you walk THROUGH the doorway rather than when you pass near it, and so each
-- destination lands clear of the opposite trigger -- which is what stops the pair bouncing
-- a player back and forth.
--
-- ---------------------------------------------------------------------------------
-- WHY THE FLAGS LOOK LIKE THIS
-- ---------------------------------------------------------------------------------
-- Copied from stock "World Trigger (Not Immune PC)" (21252) rather than invented:
--     unit_flags  33554432 = UNIT_FLAG_NOT_SELECTABLE  -- no nameplate, no tab-target
--     flags_extra 130      = TRIGGER (0x80) | NO_XP (0x02)
--     faction     114      -- the standard trigger faction, hostile to nobody
--     type        10       -- not a creature type that counts for anything
-- Display 11686 is the invisible stalker model, already present in creature_model_info.
--
-- IDS (bands verified empty first)
--   creature_template  5420000 entrance / 5420001 exit
--   creature guids     16731000 / 16731001
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Templates
--
-- RegenHealth 1 and a real health modifier are kept from the stock trigger so the pair
-- behave like every other world trigger; they are unattackable regardless.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (5420000, 5420001);
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
     `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`,
     `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`, `MovementType`)
VALUES
    (5420000, 'Shadowfang Keep Entrance', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_sfk_cata_portal_trigger', 0),
    (5420001, 'Shadowfang Keep Exit', '', 80, 80, 114, 0,
     1, 1.14286, 0, 1, 33554432, 10, 0, 1, 130, '', 'npc_sfk_cata_portal_trigger', 0);

-- -------------------------------------------------------------------------------------
-- 2. The display layer -- BOTH tables, or the creature refuses to load.
--
-- This is the mistake that made the whole instance come up empty the first time (see 11):
-- ObjectMgr will not load a creature that has no creature_template_model row, and the
-- error it prints names only that table. Display 11686 already exists in
-- creature_model_info, so only the template_model rows are new.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (5420000, 5420001);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
    (5420000, 0, 11686, 1, 1, 0),
    (5420001, 0, 11686, 1, 1, 0);

-- -------------------------------------------------------------------------------------
-- 3. Spawns -- inside the portal objects from 17.
--
--   entrance  map 751, the Shadowfang Keep door in Silverpine (verified in game:
--             Map 751 / Area 236, terrain present)
--   exit      map 825, beside the arrival point
--
-- spawnMask 7 on the exit so it exists on normal, heroic and mythic alike; the entrance is
-- on a continent, so 1.
--
-- Explicit guids -- the counters on this fork sit above 0xFFFFFF and a guid-less INSERT
-- bricks startup with TCE00007.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` IN (16731000, 16731001);
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `ScriptName`, `VerifiedBuild`)
VALUES
    (16731000, 5420000, 751, 0, 0, 1, 1, 0,
     -229.49, 1576.35, 76.8834, 4.327, 300, 0, 0, 1, 0, 0, 0, 0, '', 0),
    (16731001, 5420001, 825, 0, 0, 7, 1, 0,
     -230.953, 2105.06, 76.8906, 4.361, 300, 0, 0, 1, 0, 0, 0, 0, '', 0);

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'trigger templates (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (5420000, 5420001)
UNION ALL SELECT 'both carry the script (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (5420000, 5420001)
      AND `ScriptName` = 'npc_sfk_cata_portal_trigger'
-- Without a model row the creature never loads at all -- the failure mode from step 11.
UNION ALL SELECT 'creature_template_model rows (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (5420000, 5420001)
UNION ALL SELECT 'their display present in creature_model_info (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_model_info` WHERE `DisplayID` = 11686
UNION ALL SELECT 'spawns (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (16731000, 16731001)
UNION ALL SELECT 'entrance on 751 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16731000 AND `map` = 751
UNION ALL SELECT 'exit on 825, all difficulties (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16731001 AND `map` = 825 AND `spawnMask` = 7
UNION ALL SELECT 'both flagged unselectable + trigger (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (5420000, 5420001)
      AND (`unit_flags` & 33554432) AND (`flags_extra` & 128)
UNION ALL SELECT 'guids below the 0xFFFFFF cap (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (16731000, 16731001) AND `guid` < 16777215;
