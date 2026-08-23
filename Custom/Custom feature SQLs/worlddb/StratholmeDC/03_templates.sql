-- =====================================================================================
-- Stratholme DC clone -- map 821, step 03: templates
--
-- Requires 02 (the dc_strat821_* remap tables).
--
-- ---------------------------------------------------------------------------------
-- WHY PARENT AND CHILD TABLES ARE IN ONE FILE
-- ---------------------------------------------------------------------------------
-- The Shadowfang Keep port failed four separate times in the same shape: the parent table
-- imported cleanly and the table that actually governs behaviour was skipped, so nothing
-- errored at apply time and the bug only appeared in game, one log line at a time.
--     creature_template     without creature_template_model   -> ObjectMgr REFUSES to load
--                                                                the creature. Empty dungeon.
--     gameobject_template   without gameobject_template_addon -> flags lost, every door
--                                                                stands open.
-- So both pairs are inserted here, together, and the report at the bottom fails loudly if
-- either child is short.
--
-- ---------------------------------------------------------------------------------
-- HOW THE COPY IS DONE
-- ---------------------------------------------------------------------------------
-- CREATE TEMPORARY TABLE ... LIKE + SELECT * rather than an explicit column list. Source
-- and destination are the SAME table in the SAME database, so this is immune to the column
-- set/order drift that forced hand-maintained column lists on the cross-database Shadowfang
-- import. It also means a future core update that adds a creature_template column needs no
-- change here.
--
-- ---------------------------------------------------------------------------------
-- WHAT IS DELIBERATELY LEFT POINTING AT STOCK DATA
-- ---------------------------------------------------------------------------------
-- lootid / pickpocketloot / skinloot -- 47 of the 66 entries have loot. Because this is a
--   same-database clone, those loot templates already exist and are correct, so the clone
--   REUSES them rather than needing its own. This is the opposite of the Shadowfang port,
--   where loot came from cata_world, did not exist locally, and had to be zeroed.
-- gossip_menu_id, trainer and vendor links -- same reasoning.
--
-- Verified as needing NO remap (checked, not assumed):
--   difficulty_entry_1/2/3   all zero on these entries
--   KillCredit1/2            all zero, so no stock quest credit leaks in from the clone
--   gameobject Data0..Data13 no entry in this set references another entry in this set,
--                            so there are no linked-trap pointers to repoint
--   the 2 runtime-only gameobjects (176747, 181083) both already have template AND addon
--                            rows upstream, so the 114/114 counts below are exact
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature_template  (66 rows)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_strat_ct`;
CREATE TEMPORARY TABLE `tmp_strat_ct` LIKE `creature_template`;

INSERT INTO `tmp_strat_ct`
    SELECT * FROM `creature_template`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_strat821_cmap`);

-- Safe because the source band (10381..351097) and the destination band (5500000+) are
-- disjoint, so no row can collide with another row inside the temporary table.
UPDATE `tmp_strat_ct` t
    JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`);
INSERT INTO `creature_template` SELECT * FROM `tmp_strat_ct`;
DROP TEMPORARY TABLE `tmp_strat_ct`;

-- -------------------------------------------------------------------------------------
-- 2. Rebind the one scripted creature.
--
-- THREE entries carry a C++ ScriptName; the other 63 run on SmartAI and need nothing:
--     10436  Baroness Anastari  boss_baroness_anastari
--     16101  Jarien             boss_jarien
--     16102  Sothos             boss_sothos
--
-- Jarien and Sothos are easy to miss because they are never spawned -- they only exist as
-- the summoned rare event -- so they do not show up in a scan of scripted spawns.
--
-- None of the three may keep its stock name. All of them resolve their instance through
-- GetStratholmeAI, which asks for the instance script named "instance_stratholme"; on map
-- 821 that returns nothing and the boss comes up with a null instance.
--
-- Anything else that arrived with a ScriptName is blanked rather than left dangling, so the
-- boot log does not print "assigned in the database, but has no code" once per entry.
-- -------------------------------------------------------------------------------------
-- Driven off the SOURCE row's ScriptName rather than a hardcoded entry id, so it cannot
-- silently rebind nothing if the id is wrong or upstream moves the script to another entry.
-- (Anastari is 10436, not the 10395 a first draft of this file guessed.)
UPDATE `creature_template` ct
    JOIN `dc_strat821_cmap` m    ON m.`dst_entry` = ct.`entry`
    JOIN `creature_template` src ON src.`entry`   = m.`src_entry`
    SET ct.`ScriptName` = CONCAT(src.`ScriptName`, '_dc')
    WHERE src.`ScriptName` IN ('boss_baroness_anastari', 'boss_jarien', 'boss_sothos');

UPDATE `creature_template` SET `ScriptName` = ''
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
      AND `ScriptName` NOT IN ('', 'boss_baroness_anastari_dc', 'boss_jarien_dc', 'boss_sothos_dc');

-- -------------------------------------------------------------------------------------
-- 3. creature_template_model  (130 rows)
--
-- Every one of the 66 entries already has at least one model row upstream, and the display
-- ids are stock ones that are already present in creature_model_info and in the client's
-- CreatureDisplayInfo.dbc. So unlike the Shadowfang port there is NO art work here and no
-- invisible-NPC gap: nothing new has to be downported.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model`
    WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.`dst_entry`, tm.`Idx`, tm.`CreatureDisplayID`, tm.`DisplayScale`,
       tm.`Probability`, tm.`VerifiedBuild`
    FROM `creature_template_model` tm
    JOIN `dc_strat821_cmap` m ON m.`src_entry` = tm.`CreatureID`;

-- -------------------------------------------------------------------------------------
-- 4. creature_equip_template  (25 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_equip_template`
    WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_eq`;
CREATE TEMPORARY TABLE `tmp_strat_eq` LIKE `creature_equip_template`;
INSERT INTO `tmp_strat_eq`
    SELECT * FROM `creature_equip_template`
    WHERE `CreatureID` IN (SELECT `src_entry` FROM `dc_strat821_cmap`);
UPDATE `tmp_strat_eq` t
    JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`CreatureID`
    SET t.`CreatureID` = m.`dst_entry`;
INSERT INTO `creature_equip_template` SELECT * FROM `tmp_strat_eq`;
DROP TEMPORARY TABLE `tmp_strat_eq`;

-- -------------------------------------------------------------------------------------
-- 5. gameobject_template  (114 rows)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_strat_gt`;
CREATE TEMPORARY TABLE `tmp_strat_gt` LIKE `gameobject_template`;

INSERT INTO `tmp_strat_gt`
    SELECT * FROM `gameobject_template`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_strat821_gmap`);

UPDATE `tmp_strat_gt` t
    JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;

DELETE FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`);
INSERT INTO `gameobject_template` SELECT * FROM `tmp_strat_gt`;
DROP TEMPORARY TABLE `tmp_strat_gt`;

-- -------------------------------------------------------------------------------------
-- 6. gameobject_template_addon  (114 rows)
--
-- This is the table whose absence left every Shadowfang door standing open: the door flags
-- (LOCKED | NODESPAWN) live here, not in gameobject_template, and a missing row simply
-- means "no flags" with no error anywhere.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_template_addon`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_gta`;
CREATE TEMPORARY TABLE `tmp_strat_gta` LIKE `gameobject_template_addon`;
INSERT INTO `tmp_strat_gta`
    SELECT * FROM `gameobject_template_addon`
    WHERE `entry` IN (SELECT `src_entry` FROM `dc_strat821_gmap`);
UPDATE `tmp_strat_gta` t
    JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`entry`
    SET t.`entry` = m.`dst_entry`;
INSERT INTO `gameobject_template_addon` SELECT * FROM `tmp_strat_gta`;
DROP TEMPORARY TABLE `tmp_strat_gta`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature_template clones (want 66)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
-- The empty-dungeon check. Any entry missing here will not load at all.
UNION ALL SELECT 'clone entries with NO creature_template_model (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cmap` m
    WHERE m.`dst_entry` NOT IN (SELECT `CreatureID` FROM `creature_template_model`)
UNION ALL SELECT 'creature_template_model clone rows (want 130)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
-- Displays must already exist in creature_model_info or the model is dropped at load.
UNION ALL SELECT 'clone displays missing from creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` tm
    WHERE tm.`CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
      AND tm.`CreatureDisplayID` NOT IN (SELECT `DisplayID` FROM `creature_model_info`)
UNION ALL SELECT 'creature_equip_template clone rows (want 25)', CAST(COUNT(*) AS CHAR)
    FROM `creature_equip_template` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
UNION ALL SELECT 'gameobject_template clones (want 114)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
-- The doors-stand-open check.
UNION ALL SELECT 'gameobject_template_addon clone rows (want 114)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template_addon` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
-- A GO AIName with no registered factory segfaults the worldserver on grid load
-- (CreatureAISelector.cpp:108 dereferences the null factory). The only legal values are
-- '' and 'SmartGameObjectAI' -- 'SmartAI' is the CREATURE registry and crashes.
UNION ALL SELECT 'clone GOs with a crashing AIName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
      AND `AIName` <> '' AND `AIName` <> 'SmartGameObjectAI'
UNION ALL SELECT 'clone bosses bound to DC scripts (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
      AND `ScriptName` IN ('boss_baroness_anastari_dc', 'boss_jarien_dc', 'boss_sothos_dc')
-- No clone may still name a stock Stratholme script; it would never resolve its instance.
UNION ALL SELECT 'clones still naming a stock script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
      AND `ScriptName` IN ('boss_baroness_anastari', 'boss_jarien', 'boss_sothos',
                           'npc_naxx40_area_trigger')
UNION ALL SELECT 'clone entries that kept their loot (expect 47)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`) AND `lootid` <> 0
-- Reused loot ids must resolve, or every one of those kills drops nothing.
UNION ALL SELECT 'reused lootids with no loot template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` ct
    WHERE ct.`entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`) AND ct.`lootid` <> 0
      AND ct.`lootid` NOT IN (SELECT DISTINCT `Entry` FROM `creature_loot_template`)
-- Stock must be untouched.
UNION ALL SELECT 'stock creature_template rows still present (want 56)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 329)
UNION ALL SELECT 'stock Anastari still on the stock script (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = 10436 AND `ScriptName` = 'boss_baroness_anastari';
