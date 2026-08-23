-- =====================================================================================
-- Scholomance DC clone -- map 822, step 03: templates
--
-- Requires 02 (the dc_scholo822_* remap tables).
--
-- ---------------------------------------------------------------------------------
-- WHY PARENT AND CHILD TABLES ARE IN ONE FILE
-- ---------------------------------------------------------------------------------
-- The Shadowfang port failed four separate times in the same shape: the parent table
-- imported cleanly and the table that actually governs behaviour was skipped, so nothing
-- errored at apply time and the bug only appeared in game, one log line at a time.
--     creature_template     without creature_template_model   -> ObjectMgr REFUSES to load
--                                                                the creature. Empty dungeon.
--     gameobject_template   without gameobject_template_addon -> flags lost, every door
--                                                                stands open.
-- Both pairs are inserted here, together, and the report fails loudly if either is short.
--
-- ---------------------------------------------------------------------------------
-- HOW THE COPY IS DONE
-- ---------------------------------------------------------------------------------
-- CREATE TEMPORARY TABLE ... LIKE + SELECT * rather than an explicit column list. Source
-- and destination are the SAME table in the SAME database, so this is immune to column
-- set/order drift and needs no change when a core update adds a column.
--
-- ---------------------------------------------------------------------------------
-- WHAT IS DELIBERATELY LEFT POINTING AT STOCK DATA
-- ---------------------------------------------------------------------------------
-- lootid / pickpocketloot / skinloot -- 38 of the 47 entries have loot. Because this is a
--   same-database clone those loot templates already exist and are correct, so the clone
--   REUSES them rather than needing its own.
-- gossip_menu_id, trainer and vendor links -- same reasoning.
--
-- Verified as needing NO remap (checked, not assumed):
--   difficulty_entry_1/2/3   all zero on these entries
--   KillCredit1/2            all zero, so no stock quest credit leaks in from the clone
--   gameobject Data0..Data13 no entry in this set references another entry in this set,
--                            so there are no linked-trap pointers to repoint
--   creature_template_model  all 47 entries already have rows, and every display id is a
--                            stock one already in creature_model_info and the client's
--                            CreatureDisplayInfo.dbc -- so there is NO art work in this port
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature_template  (47 rows)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_ct`;
CREATE TEMPORARY TABLE `tmp_scholo_ct` LIKE `creature_template`;

INSERT INTO `tmp_scholo_ct`
    SELECT * FROM `creature_template`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_scholo822_cmap`);

-- Safe because the source band (1853..16047) and the destination band (5700000+) are
-- disjoint, so no row can collide with another row inside the temporary table.
UPDATE `tmp_scholo_ct` t
    JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`);
INSERT INTO `creature_template` SELECT * FROM `tmp_scholo_ct`;
DROP TEMPORARY TABLE `tmp_scholo_ct`;

-- -------------------------------------------------------------------------------------
-- 2. Rebind the FIVE scripted creatures.
--
-- Scholomance has more C++ bindings than Stratholme did, and three of them sit on entries
-- that are NEVER SPAWNED -- so a scan of "scripted spawns" finds only two of the five:
--
--     1853   Darkmaster Gandling   boss_darkmaster_gandling     (spawned)
--     ?      Occultist             npc_scholomance_occultist    (spawned)
--     10506  Kirtonos the Herald   boss_kirtonos_the_herald     (summoned only)
--     11598  Risen Guardian        npc_risen_guardian           (summoned only)
--     16118  Kormok                boss_kormok                  (summoned only)
--
-- None may keep its stock name: they all resolve their instance through GetScholomanceAI,
-- which asks for the instance script named "instance_scholomance"; on map 822 that returns
-- nothing and the creature comes up with a null instance.
--
-- Driven off the SOURCE row's ScriptName rather than hardcoded entry ids, so it cannot
-- silently rebind nothing if an id is wrong or upstream moves a script to another entry.
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` ct
    JOIN `dc_scholo822_cmap` m   ON m.`dst_entry` = ct.`entry`
    JOIN `creature_template` src ON src.`entry`   = m.`src_entry`
    SET ct.`ScriptName` = CONCAT(src.`ScriptName`, '_dc')
    WHERE src.`ScriptName` IN ('boss_darkmaster_gandling', 'npc_scholomance_occultist',
                               'boss_kirtonos_the_herald', 'npc_risen_guardian',
                               'boss_kormok');

-- Anything else that arrived with a ScriptName is blanked rather than left dangling, so the
-- boot log does not print "assigned in the database, but has no code" once per entry.
UPDATE `creature_template` SET `ScriptName` = ''
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND `ScriptName` NOT IN ('', 'boss_darkmaster_gandling_dc', 'npc_scholomance_occultist_dc',
                               'boss_kirtonos_the_herald_dc', 'npc_risen_guardian_dc',
                               'boss_kormok_dc');

-- -------------------------------------------------------------------------------------
-- 3. creature_template_model  (85 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model`
    WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.`dst_entry`, tm.`Idx`, tm.`CreatureDisplayID`, tm.`DisplayScale`,
       tm.`Probability`, tm.`VerifiedBuild`
    FROM `creature_template_model` tm
    JOIN `dc_scholo822_cmap` m ON m.`src_entry` = tm.`CreatureID`;

-- -------------------------------------------------------------------------------------
-- 4. creature_equip_template  (24 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_equip_template`
    WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_eq`;
CREATE TEMPORARY TABLE `tmp_scholo_eq` LIKE `creature_equip_template`;
INSERT INTO `tmp_scholo_eq`
    SELECT * FROM `creature_equip_template`
    WHERE `CreatureID` IN (SELECT `src_entry` FROM `dc_scholo822_cmap`);
UPDATE `tmp_scholo_eq` t
    JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`CreatureID`
    SET t.`CreatureID` = m.`dst_entry`;
INSERT INTO `creature_equip_template` SELECT * FROM `tmp_scholo_eq`;
DROP TEMPORARY TABLE `tmp_scholo_eq`;

-- -------------------------------------------------------------------------------------
-- 5. gameobject_template  (62 rows)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_gt`;
CREATE TEMPORARY TABLE `tmp_scholo_gt` LIKE `gameobject_template`;

INSERT INTO `tmp_scholo_gt`
    SELECT * FROM `gameobject_template`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_scholo822_gmap`);

UPDATE `tmp_scholo_gt` t
    JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;

DELETE FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`);
INSERT INTO `gameobject_template` SELECT * FROM `tmp_scholo_gt`;
DROP TEMPORARY TABLE `tmp_scholo_gt`;

-- -------------------------------------------------------------------------------------
-- 6. gameobject_template_addon  (62 rows)
--
-- This is the table whose absence left every Shadowfang door standing open: the door flags
-- (LOCKED | NODESPAWN) live here, not in gameobject_template, and a missing row simply
-- means "no flags" with no error anywhere. It matters more here than usual -- Scholomance's
-- seven Gandling room gates and the Kirtonos gate are the encounter.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_template_addon`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_gta`;
CREATE TEMPORARY TABLE `tmp_scholo_gta` LIKE `gameobject_template_addon`;
INSERT INTO `tmp_scholo_gta`
    SELECT * FROM `gameobject_template_addon`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_scholo822_gmap`);
UPDATE `tmp_scholo_gta` t
    JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;
INSERT INTO `gameobject_template_addon` SELECT * FROM `tmp_scholo_gta`;
DROP TEMPORARY TABLE `tmp_scholo_gta`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature_template clones (want 47)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
-- The empty-dungeon check. Any entry missing here will not load at all.
UNION ALL SELECT 'clone entries with NO creature_template_model (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cmap` m
    WHERE m.`dst_entry` NOT IN (SELECT `CreatureID` FROM `creature_template_model`)
UNION ALL SELECT 'creature_template_model clone rows (want 85)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
-- Displays must already exist in creature_model_info or the model is dropped at load.
UNION ALL SELECT 'clone displays missing from creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` tm
    WHERE tm.`CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND tm.`CreatureDisplayID` NOT IN (SELECT `DisplayID` FROM `creature_model_info`)
UNION ALL SELECT 'creature_equip_template clone rows (want 24)', CAST(COUNT(*) AS CHAR)
    FROM `creature_equip_template` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'gameobject_template clones (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
-- The doors-stand-open check.
UNION ALL SELECT 'gameobject_template_addon clone rows (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template_addon` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
-- A GO AIName with no registered factory segfaults the worldserver on grid load
-- (CreatureAISelector.cpp:108 dereferences the null factory). Only '' and
-- 'SmartGameObjectAI' are legal -- 'SmartAI' is the CREATURE registry and crashes.
UNION ALL SELECT 'clone GOs with a crashing AIName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
      AND `AIName` <> '' AND `AIName` <> 'SmartGameObjectAI'
-- All five bindings, including the three on never-spawned entries.
UNION ALL SELECT 'clone creatures bound to DC scripts (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND `ScriptName` IN ('boss_darkmaster_gandling_dc', 'npc_scholomance_occultist_dc',
                           'boss_kirtonos_the_herald_dc', 'npc_risen_guardian_dc',
                           'boss_kormok_dc')
-- No clone may still name a stock Scholomance script; it would never resolve its instance.
UNION ALL SELECT 'clones still naming a stock script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND `ScriptName` IN ('boss_darkmaster_gandling', 'npc_scholomance_occultist',
                           'boss_kirtonos_the_herald', 'npc_risen_guardian', 'boss_kormok')
UNION ALL SELECT 'clone entries that kept their loot (expect 38)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`) AND `lootid` <> 0
-- Reused loot ids must resolve, or every one of those kills drops nothing.
UNION ALL SELECT 'reused lootids with no loot template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` ct
    WHERE ct.`entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`) AND ct.`lootid` <> 0
      AND ct.`lootid` NOT IN (SELECT DISTINCT `Entry` FROM `creature_loot_template`)
-- Stock must be untouched.
UNION ALL SELECT 'stock Gandling still on the stock script (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = 1853 AND `ScriptName` = 'boss_darkmaster_gandling'
UNION ALL SELECT 'stock Kirtonos/Kormok/Guardian still stock (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (10506, 11598, 16118)
      AND `ScriptName` IN ('boss_kirtonos_the_herald', 'npc_risen_guardian', 'boss_kormok');
