-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 11: the creature DISPLAY layer
--
-- THIS IS THE FIX FOR "the dungeon is completely empty on normal and heroic".
--
-- Symptom in Errors.log, once per spawn attempt:
--     Creature (Entry: 5023837) has no model defined in table `creature_template_model`,
--     can't load.
--
-- AzerothCore does not read the display id off creature_template -- it lives in the
-- separate `creature_template_model` table, and ObjectMgr REFUSES TO LOAD a creature that
-- has no row there. 03_templates.sql imported the templates but not their models, so all
-- 505 spawns failed at load and the instance came up empty. The spawn data was fine the
-- whole time, which is exactly why nothing else looked wrong.
--
-- REQUIRES 03_templates.sql. Independent of 04-10; apply and restart the worldserver.
--
-- ---------------------------------------------------------------------------------
-- THREE LAYERS, AND ONLY TWO OF THEM ARE SQL
-- ---------------------------------------------------------------------------------
-- A creature display on this fork needs all three of:
--   1. `creature_template_model`  CreatureID -> CreatureDisplayID   <- THIS FILE
--   2. `creature_model_info`      DisplayID  -> bounding box/gender <- THIS FILE
--   3. `CreatureDisplayInfo.dbc`  DisplayID  -> the actual model     <- NOT THIS FILE
--
-- Counts for this import: 152 model rows across all 97 entries (no gaps), using 76
-- distinct display ids. 32 of those already exist here -- they are stock 3.3.5 creatures
-- the Cataclysm revamp reused. The other **44 are Cataclysm-only and are missing from
-- BOTH `creature_model_info` and the client's CreatureDisplayInfo.dbc**.
--
-- This file supplies layers 1 and 2 for all 76. That is enough to make every creature
-- LOAD and the 32 stock-display ones render normally. The 44 Cata-only ones will spawn,
-- be targetable and fight, but the client has no model for their display id, so they will
-- be INVISIBLE until layer 3 is downported. That is a separate art job:
--     30054 30056 30057 30210 30211 30212 33986 33987 33988 33989 34162 34610 34611 34612
--     34713 34714 34728 35574 35868 36256 36329 36374 36837 36848 36849 36850 36851 37287
--     37288 37289 37290 37291 37292 37294 37296 37297 37298 37299 37300 37301 37302 37358
--     37373 37374
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature_template_model
--
-- CreatureID is offset; CreatureDisplayID is NOT -- display ids are global and point at
-- CreatureDisplayInfo.dbc, which the clone shares with everything else.
--
-- `DisplayScale` exists here but not in cata_world. It is the per-model scale multiplier
-- and 0 would make the creature invisibly small, so it is written as 1 rather than left
-- to a default.
-- `Probability` picks between multiple models for one creature; the source values here are
-- only 0 and 1, carried through as-is.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5000000 AND 5099999;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.CreatureID + 5000000, m.Idx, m.CreatureDisplayID, 1, m.Probability, m.VerifiedBuild
FROM `cata_world`.`creature_template_model` m
WHERE m.CreatureID IN (SELECT `entry` FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- 2. creature_model_info -- the 44 display ids this fork does not have yet.
--
-- Keyed on the GLOBAL DisplayID, so NOTHING is offset and existing rows must not be
-- touched: INSERT IGNORE, so the 32 display ids already present keep whatever bounding
-- box and gender they were tuned with. A blanket DELETE+INSERT here would reach outside
-- this dungeon and rewrite stock creatures that happen to share a display.
--
-- `VerifiedBuild` exists here but not in cata_world; left to its default.
-- -------------------------------------------------------------------------------------
INSERT IGNORE INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
SELECT i.DisplayID, i.BoundingRadius, i.CombatReach, i.Gender, i.DisplayID_Other_Gender
FROM `cata_world`.`creature_model_info` i
WHERE i.DisplayID IN (
    SELECT DISTINCT m.CreatureDisplayID
    FROM `cata_world`.`creature_template_model` m
    WHERE m.CreatureID IN (SELECT `entry` FROM `dc_sfk825_ct_set`));

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_template_model rows (want 152)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'clone entries WITH a model (want 97)', CAST(COUNT(DISTINCT `CreatureID`) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
-- The one that actually decides whether the dungeon is populated.
UNION ALL SELECT 'clone templates with NO model - blocks loading (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` t WHERE t.entry BETWEEN 5000000 AND 5099999
      AND NOT EXISTS (SELECT 1 FROM `creature_template_model` m WHERE m.CreatureID = t.entry)
UNION ALL SELECT 'display ids used (want 76)', CAST(COUNT(DISTINCT `CreatureDisplayID`) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'display ids missing from creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT DISTINCT `CreatureDisplayID` d FROM `creature_template_model`
          WHERE `CreatureID` BETWEEN 5000000 AND 5099999) x
    WHERE x.d NOT IN (SELECT `DisplayID` FROM `creature_model_info`)
UNION ALL SELECT 'DisplayScale 0 - would be invisible (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
      AND `DisplayScale` <= 0
-- Stock must be untouched: these are the shared entries, and model_info is keyed globally.
UNION ALL SELECT 'STOCK 3887/4278 model rows (want 2, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (3887, 4278);
