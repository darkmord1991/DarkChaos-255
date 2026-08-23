-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 20: drop the clickable portal objects
--
-- Reverts 17_portals.sql. The walk-through trigger NPCs from 19 are now the only way in
-- and out, which is what was actually wanted -- two mechanisms meant two places to keep
-- the destination coordinates and the level gate in step, and the gameobject added a
-- click to something that should just work when you walk through a doorway.
--
-- The C++ side is gone too: gobject_sfk_cata_portal.cpp is deleted and unwired from the
-- loader, so leaving these rows would only produce
--     Script named 'gobject_sfk_cata_enter' is assigned in the database, but has no code!
-- at every boot.
--
-- 17_portals.sql is superseded and should not be re-applied.
-- =====================================================================================

DELETE FROM `gameobject` WHERE `guid` IN (16511000, 16511001);
DELETE FROM `gameobject_template_addon` WHERE `entry` IN (5410000, 5410001);
DELETE FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001);

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'portal GO spawns left (want 0)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `gameobject` WHERE `guid` IN (16511000, 16511001)
UNION ALL SELECT 'portal GO templates left (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (5410000, 5410001)
UNION ALL SELECT 'portal GO addon rows left (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template_addon` WHERE `entry` IN (5410000, 5410001)
-- Nothing may still reference the deleted scripts, or the boot log complains every start.
UNION ALL SELECT 'templates still naming the removed GO scripts (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template`
    WHERE `ScriptName` IN ('gobject_sfk_cata_enter', 'gobject_sfk_cata_exit')
-- The trigger NPCs must survive -- they are now the whole mechanism.
UNION ALL SELECT 'trigger NPC spawns intact (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (16731000, 16731001)
UNION ALL SELECT 'trigger NPC templates intact (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (5420000, 5420001)
      AND `ScriptName` = 'npc_sfk_cata_portal_trigger';
