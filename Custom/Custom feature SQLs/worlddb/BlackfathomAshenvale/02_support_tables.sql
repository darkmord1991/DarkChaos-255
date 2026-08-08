-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 2: per-template support tables
--
-- Everything keyed by creature entry or gameobject entry that the clone needs in order to
-- look and behave like the original: models, equipment, addons, spells, texts, SmartAI and
-- the summon groups that drive the Aku'mai gate event.
--
-- Run AFTER 01_templates.sql. Re-runnable.
-- =====================================================================================

SET @C_OFF := 3900000;
SET @G_OFF := 4400000;
SET @GUID_OFF := 16700000;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
CREATE TEMPORARY TABLE tmp_bfd_src_cre (entry INT UNSIGNED PRIMARY KEY);
INSERT IGNORE INTO tmp_bfd_src_cre (entry) SELECT DISTINCT `id` FROM `creature` WHERE `map` = 48;
INSERT IGNORE INTO tmp_bfd_src_cre (entry) VALUES (4977),(4978),(6047),(6729),(12736),(12876),(53488);

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_go;
CREATE TEMPORARY TABLE tmp_bfd_src_go (entry INT UNSIGNED PRIMARY KEY);
INSERT IGNORE INTO tmp_bfd_src_go (entry) SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 48;

-- -------------------------------------------------------------------------------------
-- creature_template_model  (display ids -- without these every clone is an invisible blob)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ctm;
CREATE TEMPORARY TABLE tmp_bfd_ctm LIKE `creature_template_model`;
INSERT INTO tmp_bfd_ctm SELECT * FROM `creature_template_model`
    WHERE `CreatureID` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_ctm SET `CreatureID` = `CreatureID` + @C_OFF, `VerifiedBuild` = 0;
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (SELECT `CreatureID` FROM tmp_bfd_ctm);
INSERT INTO `creature_template_model` SELECT * FROM tmp_bfd_ctm;

-- -------------------------------------------------------------------------------------
-- creature_equip_template  (visible weapons)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cet;
CREATE TEMPORARY TABLE tmp_bfd_cet LIKE `creature_equip_template`;
INSERT INTO tmp_bfd_cet SELECT * FROM `creature_equip_template`
    WHERE `CreatureID` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_cet SET `CreatureID` = `CreatureID` + @C_OFF, `VerifiedBuild` = 0;
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (SELECT `CreatureID` FROM tmp_bfd_cet);
INSERT INTO `creature_equip_template` SELECT * FROM tmp_bfd_cet;

-- -------------------------------------------------------------------------------------
-- creature_template_addon  (auras, mount, bytes)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cta;
CREATE TEMPORARY TABLE tmp_bfd_cta LIKE `creature_template_addon`;
INSERT INTO tmp_bfd_cta SELECT * FROM `creature_template_addon`
    WHERE `entry` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_cta SET `entry` = `entry` + @C_OFF;
DELETE FROM `creature_template_addon` WHERE `entry` IN (SELECT `entry` FROM tmp_bfd_cta);
INSERT INTO `creature_template_addon` SELECT * FROM tmp_bfd_cta;

-- -------------------------------------------------------------------------------------
-- creature_template_spell
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cts;
CREATE TEMPORARY TABLE tmp_bfd_cts LIKE `creature_template_spell`;
INSERT INTO tmp_bfd_cts SELECT * FROM `creature_template_spell`
    WHERE `CreatureID` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_cts SET `CreatureID` = `CreatureID` + @C_OFF, `VerifiedBuild` = 0;
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (SELECT `CreatureID` FROM tmp_bfd_cts);
INSERT INTO `creature_template_spell` SELECT * FROM tmp_bfd_cts;

-- -------------------------------------------------------------------------------------
-- creature_text  (boss yells)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ctx;
CREATE TEMPORARY TABLE tmp_bfd_ctx LIKE `creature_text`;
INSERT INTO tmp_bfd_ctx SELECT * FROM `creature_text`
    WHERE `CreatureID` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_ctx SET `CreatureID` = `CreatureID` + @C_OFF;
DELETE FROM `creature_text` WHERE `CreatureID` IN (SELECT `CreatureID` FROM tmp_bfd_ctx);
INSERT INTO `creature_text` SELECT * FROM tmp_bfd_ctx;

-- -------------------------------------------------------------------------------------
-- smart_scripts, creature side (source_type 0)
--
-- Audited before writing: BFD's creature SmartAI is 65 rows and uses ONLY action_type 11
-- (cast). There are no summons, no timed action lists (source_type 9) and no creature-entry
-- references, so nothing inside the rows needs remapping EXCEPT two target_type 14 rows.
--
-- target_type 14 = SMART_TARGET_GAMEOBJECT_GUID: param1 is a SPAWN GUID and param2 the
-- gameobject entry. Both are map-48 values (guid 32610 -> Shrine of Gelihast 103015,
-- guid 32935 -> Altar of the Deeps 103016) and would silently target the ORIGINAL dungeon's
-- objects from inside the clone. They are remapped with the same offsets used for the
-- cloned spawns in 03_spawns.sql.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ss;
CREATE TEMPORARY TABLE tmp_bfd_ss LIKE `smart_scripts`;
INSERT INTO tmp_bfd_ss SELECT * FROM `smart_scripts`
    WHERE `source_type` = 0 AND `entryorguid` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_ss SET
    `entryorguid`   = `entryorguid` + @C_OFF,
    `target_param1` = IF(`target_type` = 14, `target_param1` + @GUID_OFF, `target_param1`),
    `target_param2` = IF(`target_type` = 14, `target_param2` + @G_OFF,    `target_param2`);
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (SELECT `entryorguid` FROM tmp_bfd_ss);
INSERT INTO `smart_scripts` SELECT * FROM tmp_bfd_ss;

-- -------------------------------------------------------------------------------------
-- smart_scripts, gameobject side (source_type 1)
--
-- These 10 rows ARE the Aku'mai gate event:
--   21118-21121 Fire of Aku'mai - action 34 (set instance data 1..4 = DONE)
--                               + action 107 (summon creature group 1)
--   103016 Altar of the Deeps   - action 12, summons 6729 Morridune (the exit portal)
--   177964 Fathom Stone         - action 12, summons 12876 Baron Aquanis
-- action_type 12 = SMART_ACTION_SUMMON_CREATURE, so action_param1 is a creature entry and
-- MUST be offset or the clone summons the level-24 originals.
-- action_type 34 sets instance data by index -- index values are NOT ids, leave them alone.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ssg;
CREATE TEMPORARY TABLE tmp_bfd_ssg LIKE `smart_scripts`;
INSERT INTO tmp_bfd_ssg SELECT * FROM `smart_scripts`
    WHERE `source_type` = 1 AND `entryorguid` IN (SELECT entry FROM tmp_bfd_src_go);
UPDATE tmp_bfd_ssg SET
    `entryorguid`   = `entryorguid` + @G_OFF,
    `action_param1` = IF(`action_type` = 12, `action_param1` + @C_OFF, `action_param1`);
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` IN (SELECT `entryorguid` FROM tmp_bfd_ssg);
INSERT INTO `smart_scripts` SELECT * FROM tmp_bfd_ssg;

-- -------------------------------------------------------------------------------------
-- creature_summon_groups  (the 14 adds the four fires spawn)
-- summonerType 1 = gameobject, so summonerId takes the GO offset and entry the creature one.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_csg;
CREATE TEMPORARY TABLE tmp_bfd_csg LIKE `creature_summon_groups`;
INSERT INTO tmp_bfd_csg SELECT * FROM `creature_summon_groups`
    WHERE `summonerType` = 1 AND `summonerId` IN (SELECT entry FROM tmp_bfd_src_go);
UPDATE tmp_bfd_csg SET `summonerId` = `summonerId` + @G_OFF, `entry` = `entry` + @C_OFF;
DELETE FROM `creature_summon_groups`
    WHERE `summonerType` = 1 AND `summonerId` IN (SELECT `summonerId` FROM tmp_bfd_csg);
INSERT INTO `creature_summon_groups` SELECT * FROM tmp_bfd_csg;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_template_model' AS `table`, COUNT(*) AS cloned FROM `creature_template_model` WHERE `CreatureID` >= @C_OFF
UNION ALL SELECT 'creature_equip_template', COUNT(*) FROM `creature_equip_template` WHERE `CreatureID` >= @C_OFF
UNION ALL SELECT 'creature_template_addon', COUNT(*) FROM `creature_template_addon` WHERE `entry` >= @C_OFF AND `entry` < @C_OFF + 1000000
UNION ALL SELECT 'creature_template_spell', COUNT(*) FROM `creature_template_spell` WHERE `CreatureID` >= @C_OFF AND `CreatureID` < @C_OFF + 1000000
UNION ALL SELECT 'creature_text', COUNT(*) FROM `creature_text` WHERE `CreatureID` >= @C_OFF AND `CreatureID` < @C_OFF + 1000000
UNION ALL SELECT 'smart_scripts (creature)', COUNT(*) FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` >= @C_OFF AND `entryorguid` < @C_OFF + 1000000
UNION ALL SELECT 'smart_scripts (gameobject)', COUNT(*) FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` >= @G_OFF
UNION ALL SELECT 'creature_summon_groups', COUNT(*) FROM `creature_summon_groups` WHERE `summonerId` >= @G_OFF;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ctm;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cet;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cta;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cts;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ctx;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ss;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ssg;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_csg;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_go;
