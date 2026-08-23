-- =====================================================================================
-- Scholomance DC clone -- map 822, step 06: SmartAI and creature text
--
-- Requires 02 (remap tables), 03 (templates) and 04 (spawns).
--
-- THREE ROW SETS ARE COPIED:
--   source_type 0, entryorguid > 0   per-entry creature scripts   (172 rows)
--   source_type 1                    gameobject scripts           (5 rows)
--   source_type 9                    timed action lists           (8 rows, 1 list)
--
-- There are NO guid-keyed creature rows here (source_type 0 with a negative entryorguid) --
-- 0 of them, unlike Stratholme's 35. The set is still enumerated explicitly rather than
-- assumed, because missing a whole row set is silent.
--
-- The action-list set is the easiest to overlook: those rows are not keyed by a creature id
-- at all, they are keyed by an ACTION LIST id following the convention
-- list_id = creature_entry * 100. The clone's list gets a dense band of its own (8240000+).
--
-- ---------------------------------------------------------------------------------
-- NO TELEPORT REWRITE IS NEEDED IN THIS FILE
-- ---------------------------------------------------------------------------------
-- Scholomance has six spells whose `spell_target_position` rows hardcode MapID 289 -- the
-- Darkmaster Gandling room-shuffle (17863, 17939, 17943, 17944, 17946, 17948). Left alone on
-- a clone those would teleport a PLAYER out of map 822 and into stock Scholomance, which is
-- a genuine cross-instance leak and worse than the Stratholme case (there the equivalent
-- spells were creature-targeted, so the core caught them and merely logged).
--
-- But NONE of the six is cast from SmartAI -- verified: zero smart_scripts rows reference
-- them. They are cast from C++, in boss_darkmaster_gandling.cpp, via GandlingPortalSpells[]
-- inside SpellHitTarget. So the fix belongs in the cloned boss script, not here: the clone
-- replaces those casts with a direct same-map teleport. That is why this file has no
-- equivalent of Stratholme's step 7.
--
-- The 125 SMART_ACTION_CAST rows in this data are therefore all safe and copied verbatim.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Action-list id map (1 list, 8 rows)
--
-- Built here rather than in 02 because it is derived from smart_scripts, not from the
-- spawn tables the other maps come from.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_almap`;
CREATE TABLE `dc_scholo822_almap` (
    `src_list` INT NOT NULL,
    `dst_list` INT NOT NULL,
    PRIMARY KEY (`src_list`),
    UNIQUE KEY `dst` (`dst_list`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_almap` (`src_list`, `dst_list`)
SELECT s.l, 8240000 + (ROW_NUMBER() OVER (ORDER BY s.l)) - 1
FROM (
    SELECT DISTINCT `entryorguid` AS l
        FROM `smart_scripts`
        WHERE `source_type` = 9
          AND (`entryorguid` DIV 100) IN (SELECT `src_entry` FROM `dc_scholo822_cmap`)
) s;

-- -------------------------------------------------------------------------------------
-- 2. Pull every relevant row into one working table
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_ss`;
CREATE TEMPORARY TABLE `tmp_scholo_ss` LIKE `smart_scripts`;

INSERT INTO `tmp_scholo_ss`
SELECT * FROM `smart_scripts`
WHERE (`source_type` = 0 AND `entryorguid` > 0
       AND `entryorguid` IN (SELECT `src_entry` FROM `dc_scholo822_cmap`))
   OR (`source_type` = 0 AND `entryorguid` < 0
       AND -`entryorguid` IN (SELECT `src_guid` FROM `dc_scholo822_cguid`))
   OR (`source_type` = 1
       AND `entryorguid` IN (SELECT `src_entry` FROM `dc_scholo822_gmap`))
   OR (`source_type` = 9
       AND `entryorguid` IN (SELECT `src_list` FROM `dc_scholo822_almap`));

-- -------------------------------------------------------------------------------------
-- 3. Remap entryorguid, per source_type
--
-- The destination bands (5.7M creature entries, 5.8M gameobject entries, 16.75M guids,
-- 8.24M action lists) are disjoint from every source band, so no row rewritten by one
-- update can be matched again by a later one.
-- -------------------------------------------------------------------------------------
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`entryorguid`
    SET t.`entryorguid` = m.`dst_entry`
    WHERE t.`source_type` = 0 AND t.`entryorguid` > 0;

-- Expected to affect 0 rows here (Scholomance has no guid-keyed scripts), but kept so the
-- two ports stay identical and a future data change cannot slip past unnoticed.
-- CAST AS SIGNED is required: dst_guid is INT UNSIGNED and applying unary minus to an
-- unsigned value makes MySQL raise "BIGINT UNSIGNED value is out of range".
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cguid` g ON g.`src_guid` = -t.`entryorguid`
    SET t.`entryorguid` = -CAST(g.`dst_guid` AS SIGNED)
    WHERE t.`source_type` = 0 AND t.`entryorguid` < 0;

UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`entryorguid`
    SET t.`entryorguid` = m.`dst_entry`
    WHERE t.`source_type` = 1;

UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_almap` a ON a.`src_list` = t.`entryorguid`
    SET t.`entryorguid` = a.`dst_list`
    WHERE t.`source_type` = 9;

-- -------------------------------------------------------------------------------------
-- 4. Remap ids carried in ACTION parameters
--
-- Only the action types actually present in this data are touched; each was confirmed
-- against the SMART_ACTION_* enum in SmartScriptMgr.h rather than assumed.
-- -------------------------------------------------------------------------------------
-- SMART_ACTION_SUMMON_CREATURE (12): action_param1 = CreatureID. This is the row that
-- summons Kormok, and it is exactly why 02 seeds the template set with runtime-only entries.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`action_param1`
    SET t.`action_param1` = m.`dst_entry`
    WHERE t.`action_type` = 12;

-- SMART_ACTION_SUMMON_GO (50): action_param1 = GameObjectID.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`action_param1`
    SET t.`action_param1` = m.`dst_entry`
    WHERE t.`action_type` = 50;

-- SMART_ACTION_CALL_TIMED_ACTIONLIST (80): action_param1 = action list id.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_almap` a ON a.`src_list` = t.`action_param1`
    SET t.`action_param1` = a.`dst_list`
    WHERE t.`action_type` = 80;

-- SMART_ACTION_TELEPORT (62): action_param1 = mapID. None present in this data, but a
-- stray one left naming 289 would throw players into stock Scholomance.
UPDATE `tmp_scholo_ss` SET `action_param1` = 822
    WHERE `action_type` = 62 AND `action_param1` = 289;

-- -------------------------------------------------------------------------------------
-- 5. Remap ids carried in TARGET parameters
--
-- NOTE target_type 11 is present here and was NOT in the Stratholme data -- it carries a
-- creature entry just like 19 and 204 do, and missing it would leave those three rows
-- searching for a STOCK creature that is not on this map.
-- -------------------------------------------------------------------------------------
-- SMART_TARGET_CREATURE_DISTANCE (11), CLOSEST_CREATURE (19), SUMMONED_CREATURES (204):
-- target_param1 = CreatureEntry. 0 means "any" and must stay 0.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`target_param1`
    SET t.`target_param1` = m.`dst_entry`
    WHERE t.`target_type` IN (11, 19, 204) AND t.`target_param1` > 0;

-- SMART_TARGET_CREATURE_RANGE (9): same shape. Not present, included for completeness.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`target_param1`
    SET t.`target_param1` = m.`dst_entry`
    WHERE t.`target_type` = 9 AND t.`target_param1` > 0;

-- SMART_TARGET_CREATURE_GUID (10): param1 = guid, param2 = entry. BOTH.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cguid` g ON g.`src_guid` = t.`target_param1`
    SET t.`target_param1` = g.`dst_guid`
    WHERE t.`target_type` = 10 AND t.`target_param1` > 0;
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`target_param2`
    SET t.`target_param2` = m.`dst_entry`
    WHERE t.`target_type` = 10 AND t.`target_param2` > 0;

-- SMART_TARGET_GAMEOBJECT_RANGE (13), GAMEOBJECT_DISTANCE (15), CLOSEST_GAMEOBJECT (20):
-- target_param1 = gameobject entry.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`target_param1`
    SET t.`target_param1` = m.`dst_entry`
    WHERE t.`target_type` IN (13, 15, 20) AND t.`target_param1` > 0;

-- SMART_TARGET_GAMEOBJECT_GUID (14): param1 = guid, param2 = entry. BOTH.
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_gguid` g ON g.`src_guid` = t.`target_param1`
    SET t.`target_param1` = g.`dst_guid`
    WHERE t.`target_type` = 14 AND t.`target_param1` > 0;
UPDATE `tmp_scholo_ss` t JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`target_param2`
    SET t.`target_param2` = m.`dst_entry`
    WHERE t.`target_type` = 14 AND t.`target_param2` > 0;

-- SMART_TARGET_STORED (12) carries a script-local slot id, NOT an entry -- left alone.

-- -------------------------------------------------------------------------------------
-- 6. Write the rows out
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts`
    WHERE (`source_type` = 0 AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`))
       OR (`source_type` = 0 AND `entryorguid` < 0
           AND -`entryorguid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`))
       OR (`source_type` = 1 AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`))
       OR (`source_type` = 9 AND `entryorguid` IN (SELECT `dst_list` FROM `dc_scholo822_almap`));

INSERT INTO `smart_scripts` SELECT * FROM `tmp_scholo_ss`;
DROP TEMPORARY TABLE `tmp_scholo_ss`;

-- -------------------------------------------------------------------------------------
-- 7. creature_text  (30 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_ctext`;
CREATE TEMPORARY TABLE `tmp_scholo_ctext` LIKE `creature_text`;
INSERT INTO `tmp_scholo_ctext`
    SELECT * FROM `creature_text`
    WHERE `CreatureID` IN (SELECT `src_entry` FROM `dc_scholo822_cmap`);
UPDATE `tmp_scholo_ctext` t JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`CreatureID`
    SET t.`CreatureID` = m.`dst_entry`;
INSERT INTO `creature_text` SELECT * FROM `tmp_scholo_ctext`;
DROP TEMPORARY TABLE `tmp_scholo_ctext`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'clone SmartAI rows, per-entry creature (want 172)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 0
      AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'clone SmartAI rows, gameobject (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 1
      AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
UNION ALL SELECT 'clone SmartAI rows, timed action lists (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 9
      AND `entryorguid` IN (SELECT `dst_list` FROM `dc_scholo822_almap`)
UNION ALL SELECT 'clone action lists (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_almap`
-- Every actionlist call must resolve, or the creature stalls mid-script.
UNION ALL SELECT 'clone action-list calls resolving to nothing (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 80
      AND ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND ss.`action_param1` NOT IN
          (SELECT `entryorguid` FROM `smart_scripts` WHERE `source_type` = 9)
-- Summons must point into the clone band, or a boss summons a stock creature.
UNION ALL SELECT 'clone summons still naming a stock creature (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 12
      AND (ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
        OR ss.`entryorguid` IN (SELECT `dst_list` FROM `dc_scholo822_almap`))
      AND ss.`action_param1` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'clone GO summons still naming a stock GO (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 50
      AND ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND ss.`action_param1` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
-- The target_type 11 rows Stratholme did not have.
UNION ALL SELECT 'clone creature-targeting rows still naming stock (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`target_type` IN (9, 11, 19, 204) AND ss.`target_param1` > 0
      AND ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND ss.`target_param1` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'clone GO-targeting rows still naming stock (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`target_type` IN (13, 15, 20) AND ss.`target_param1` > 0
      AND (ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
        OR ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`))
      AND ss.`target_param1` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
-- Confirms the Gandling leak really is C++-only, so this file was right not to touch it.
UNION ALL SELECT 'clone SmartAI casts using a map-289 teleport spell (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 11
      AND ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
      AND ss.`action_param1` IN (SELECT `ID` FROM `spell_target_position` WHERE `MapID` = 289)
UNION ALL SELECT 'creature_text clone rows (want 30)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
-- Stock untouched.
UNION ALL SELECT 'stock per-entry SmartAI rows (want 172)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0
      AND `entryorguid` IN (SELECT `src_entry` FROM `dc_scholo822_cmap`);
