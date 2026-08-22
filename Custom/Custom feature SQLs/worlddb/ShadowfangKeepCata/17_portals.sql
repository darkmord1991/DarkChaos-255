-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 17: the entrance and exit portals
--
-- Replaces the areatrigger approach, which does not work on this fork's custom maps.
--
-- ---------------------------------------------------------------------------------
-- WHY GAMEOBJECTS AND NOT AREATRIGGERS
-- ---------------------------------------------------------------------------------
-- The areatrigger route was built first and fully: rows in `areatrigger` and
-- `areatrigger_teleport` (14), ids 6960/6961 added to AreaTrigger.dbc and deployed to
-- patch-4, patch-enGB-3 and all three WarcraftXLHost candidate dirs. It never fired.
--
-- The proof it cannot: standing at (-229.49, 1576.35, 76.883) on map 751 -- 2.01 yards
-- from the centre of a radius-7 trigger, terrain present, server-side row loaded and
-- correct -- the client sends no CMSG_AREATRIGGER at all. The same client fires stock
-- triggers 145 and 194 on maps 0 and 33 from the same DBC. New areatriggers cannot be
-- made to fire on these maps without client edits beyond the DBC.
--
-- DarkChaos already works this way everywhere else: 178 GameObject templates carry a
-- ScriptName across maps 750/751, and Naxxramas-40's entrance is GO 361001 with script
-- `gobject_naxx40_tele`. This is the same shape.
--
-- 14 and 16 are still worth keeping -- 16 repairs 32 genuinely corrupt areatrigger rows,
-- and 14's rows are correct even if inert.
--
-- REQUIRES a worldserver carrying gobject_sfk_cata_portal.cpp -- already built.
--
-- IDS (bands verified empty first)
--   gameobject_template  5410000 entrance / 5410001 exit
--   gameobject guids     16511000 / 16511001
--   displayId 7786 -- the same runestone visual the Naxx-40 portal uses
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Templates. type 10 = GAMEOBJECT_TYPE_GOOBER, which is what makes the object
--    clickable and routes the click to GameObjectScript::OnGossipHello.
--
--    Data0 = 0 (no lock), Data1 = 0 (no quest), Data2 = 0 (no cooldown). The level gate
--    lives in the script rather than in a lock id so it can share one constant with
--    dungeon_access_template instead of being a second number to keep in step.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001);
INSERT INTO `gameobject_template`
    (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
     `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`,
     `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`,
     `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`,
     `AIName`, `ScriptName`, `VerifiedBuild`)
VALUES
    (5410000, 10, 7786, 'Shadowfang Keep (Cataclysm)', 'Speak', '', '', 1.5,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, '', 'gobject_sfk_cata_enter', 0),
    (5410001, 10, 7786, 'Leave Shadowfang Keep', 'Speak', '', '', 1.5,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, '', 'gobject_sfk_cata_exit', 0);

-- -------------------------------------------------------------------------------------
-- 2. gameobject_template_addon -- flags 0, faction 0: freely clickable by anyone.
--    Skipping this is what left the imported doors unlocked and open (see 12), so the
--    rows are written explicitly rather than left absent.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_template_addon` WHERE `entry` IN (5410000, 5410001);
INSERT INTO `gameobject_template_addon`
    (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
VALUES
    (5410000, 0, 0, 0, 0, 0, 0, 0, 0),
    (5410001, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------------------
-- 3. Spawns.
--
--   entrance  map 751, at the Shadowfang Keep door in Silverpine -- the coordinates stock
--             areatrigger 145 occupies on map 0, which 751's Silverpine shares because it
--             is a clone of stock zone 130. Verified in game: standing there reports
--             Map 751 / Area 236 (Shadowfang Keep), with terrain present.
--   exit      map 825, beside the arrival point, where stock trigger 194 sits.
--
-- Explicit guids -- never let these auto-increment. The counters on this fork sit above
-- 0xFFFFFF and a guid-less INSERT bricks startup with TCE00007.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` IN (16511000, 16511001);
INSERT INTO `gameobject`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
     `position_x`, `position_y`, `position_z`, `orientation`,
     `rotation0`, `rotation1`, `rotation2`, `rotation3`,
     `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`)
VALUES
    (16511000, 5410000, 751, 0, 0, 1, 1,
     -229.49, 1576.35, 76.8834, 4.327,  0, 0, 0, 1, 120, 100, 1, '', 0),
    (16511001, 5410001, 825, 0, 0, 7, 1,
     -230.953, 2105.06, 76.8906, 4.361, 0, 0, 0, 1, 120, 100, 1, '', 0);

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'portal templates (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001)
UNION ALL SELECT 'both are type 10 GOOBER / clickable (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001) AND `type` = 10
UNION ALL SELECT 'both carry a ScriptName (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001) AND `ScriptName` <> ''
UNION ALL SELECT 'addon rows (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template_addon` WHERE `entry` IN (5410000, 5410001)
UNION ALL SELECT 'spawns (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` IN (16511000, 16511001)
UNION ALL SELECT 'entrance on map 751 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` = 16511000 AND `map` = 751
UNION ALL SELECT 'exit on map 825, all difficulties (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` = 16511001 AND `map` = 825 AND `spawnMask` = 7
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` g WHERE g.guid IN (16511000, 16511001)
      AND g.id NOT IN (SELECT `entry` FROM `gameobject_template`)
UNION ALL SELECT 'guid below the 0xFFFFFF cap (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` IN (16511000, 16511001) AND `guid` < 16777215;
