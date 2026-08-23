-- =====================================================================================
-- Stratholme DC clone -- map 821, step 06: SmartAI and creature text
--
-- Requires 02 (remap tables), 03 (templates) and 04 (spawns).
--
-- This is the file with the most cross-references in it. 51 of the 56 creature entries and
-- 19 of the gameobjects run entirely on SmartAI, so if this file is wrong the clone looks
-- correct at load and then simply does nothing.
--
-- FOUR ROW SETS ARE COPIED, NOT ONE:
--   source_type 0, entryorguid > 0   per-entry creature scripts
--   source_type 0, entryorguid < 0   per-SPAWN creature scripts, keyed on guid (35 rows)
--   source_type 1                    gameobject scripts (54 rows)
--   source_type 9                    timed action lists (47 rows, 13 lists)
--
-- Missing any one of them is silent. The action-list set is the easiest to overlook: those
-- rows are not keyed by a creature id at all, they are keyed by an ACTION LIST id, which on
-- this fork follows the convention list_id = creature_entry * 100. All 13 lists referenced
-- by the 13 SMART_ACTION_CALL_TIMED_ACTIONLIST rows resolve, so none may be dropped.
--
-- The clone's action lists get a dense band of their own (8220000+) instead of
-- clone_entry * 100, which would be 550,000,000+ -- valid but absurdly sparse.
--
-- ---------------------------------------------------------------------------------
-- THE CROSS-MAP TELEPORT TRAP  (section 7)
-- ---------------------------------------------------------------------------------
-- Ten spells cast from this dungeon have rows in `spell_target_position` whose MapID is
-- hardcoded to 329. Spell.cpp:1403-1409 applies that map id ABSOLUTELY for
-- SPELL_EFFECT_TELEPORT_UNITS:
--       dest = SpellDestination(st->target_X, ..., (int32)st->target_mapId);
-- and SpellEffects.cpp then compares it against the target's current map.
--
-- On the clone the caster is on 821 while the row still says 329, so the teleport is
-- cross-map. All of them are cast on SELF (target_type 1) by creatures, so this does NOT throw
-- a player into stock Stratholme -- SpellEffects.cpp:1240 catches it with
--       "spellId {} attempted to teleport creature to a different map."
-- and returns. But the mechanic silently stops working and the error log fills up: Baron
-- Rivendare never repositions around his balcony (6 spells) and the Thuzadin Acolytes never
-- teleport to their ziggurats (3 spells).
--
-- NINE of the ten spells are reached this way. The tenth (17278) has no SmartAI caster in
-- this dungeon at all -- it belongs to gameobject 176211 "Cannonball", which is not spawned
-- in Stratholme, so nothing in the clone can fire it and there is nothing to rewrite.
--
-- The fix is pure DB and needs NO new spells and NO client work. spell_target_position is
-- keyed by spell id alone, so it cannot hold a different map per dungeon -- but SmartAI has
-- a native teleport that takes the map id as a plain parameter:
--       SMART_ACTION_TELEPORT = 62, action_param1 = mapID, coords in target_x/y/z/o
-- and for a creature target its handler (SmartScript.cpp:1714) calls NearTeleportTo, which
-- is exactly what the spell was doing. So each of those casts is rewritten in place into a
-- teleport carrying the coordinates the spell would have used.
--
-- The visual of the original spell is lost. That is the whole cost, and it is worth it
-- against cloning 10 spells into the 234-field fork Spell.dbc and redeploying the client.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Action-list id map (13 lists)
--
-- Built here rather than in 02 because it is derived from smart_scripts, not from the
-- spawn tables the other four maps come from.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_almap`;
CREATE TABLE `dc_strat821_almap` (
    `src_list` INT NOT NULL,
    `dst_list` INT NOT NULL,
    PRIMARY KEY (`src_list`),
    UNIQUE KEY `dst` (`dst_list`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_almap` (`src_list`, `dst_list`)
SELECT s.l, 8220000 + (ROW_NUMBER() OVER (ORDER BY s.l)) - 1
FROM (
    SELECT DISTINCT `entryorguid` AS l
        FROM `smart_scripts`
        WHERE `source_type` = 9
          AND (`entryorguid` DIV 100) IN (SELECT `src_entry` FROM `dc_strat821_cmap`)
) s;

-- -------------------------------------------------------------------------------------
-- 2. Pull every relevant row into one working table
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_strat_ss`;
CREATE TEMPORARY TABLE `tmp_strat_ss` LIKE `smart_scripts`;

INSERT INTO `tmp_strat_ss`
SELECT * FROM `smart_scripts`
WHERE (`source_type` = 0 AND `entryorguid` > 0
       AND `entryorguid` IN (SELECT `src_entry` FROM `dc_strat821_cmap`))
   OR (`source_type` = 0 AND `entryorguid` < 0
       AND -`entryorguid` IN (SELECT `src_guid` FROM `dc_strat821_cguid`))
   OR (`source_type` = 1
       AND `entryorguid` IN (SELECT `src_entry` FROM `dc_strat821_gmap`))
   OR (`source_type` = 9
       AND `entryorguid` IN (SELECT `src_list` FROM `dc_strat821_almap`));

-- -------------------------------------------------------------------------------------
-- 3. Remap entryorguid, per source_type
--
-- The four updates cannot interfere: the destination bands (5.5M creature entries,
-- 5.6M gameobject entries, 16.7M guids, 8.22M action lists) are disjoint from every source
-- band, so no row rewritten by one update can be matched again by a later one.
-- -------------------------------------------------------------------------------------
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`entryorguid`
    SET t.`entryorguid` = m.`dst_entry`
    WHERE t.`source_type` = 0 AND t.`entryorguid` > 0;

-- Per-spawn scripts address ONE creature by guid, negated. Left unmapped these 35 rows
-- would attach to whatever stock spawn holds that guid.
-- CAST AS SIGNED is required, not cosmetic: dst_guid is INT UNSIGNED, and applying unary
-- minus to an unsigned value makes MySQL raise
--     BIGINT UNSIGNED value is out of range in '-(`dst_guid`)'
-- which aborts the whole file. (Negating entryorguid on the left is fine -- that column is
-- signed.)
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cguid` g ON g.`src_guid` = -t.`entryorguid`
    SET t.`entryorguid` = -CAST(g.`dst_guid` AS SIGNED)
    WHERE t.`source_type` = 0 AND t.`entryorguid` < 0;

UPDATE `tmp_strat_ss` t JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`entryorguid`
    SET t.`entryorguid` = m.`dst_entry`
    WHERE t.`source_type` = 1;

UPDATE `tmp_strat_ss` t JOIN `dc_strat821_almap` a ON a.`src_list` = t.`entryorguid`
    SET t.`entryorguid` = a.`dst_list`
    WHERE t.`source_type` = 9;

-- -------------------------------------------------------------------------------------
-- 4. Remap ids carried in ACTION parameters
--
-- Only the action types actually present in this data are touched; each was confirmed
-- against the SMART_ACTION_* enum in SmartScriptMgr.h rather than assumed.
-- -------------------------------------------------------------------------------------
-- SMART_ACTION_SUMMON_CREATURE (12): action_param1 = CreatureID.
-- This is why 02 seeds the template set with runtime-only entries -- 10387 Vengeful Phantom
-- is summoned here and never appears in the `creature` table.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`action_param1`
    SET t.`action_param1` = m.`dst_entry`
    WHERE t.`action_type` = 12;

-- SMART_ACTION_SUMMON_GO (50): action_param1 = GameObjectID.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`action_param1`
    SET t.`action_param1` = m.`dst_entry`
    WHERE t.`action_type` = 50;

-- SMART_ACTION_CALL_TIMED_ACTIONLIST (80): action_param1 = action list id.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_almap` a ON a.`src_list` = t.`action_param1`
    SET t.`action_param1` = a.`dst_list`
    WHERE t.`action_type` = 80;

-- -------------------------------------------------------------------------------------
-- 5. Remap ids carried in TARGET parameters
-- -------------------------------------------------------------------------------------
-- SMART_TARGET_CLOSEST_CREATURE (19) and SMART_TARGET_SUMMONED_CREATURES (204):
-- target_param1 = CreatureEntry. 0 means "any" and must stay 0.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`target_param1`
    SET t.`target_param1` = m.`dst_entry`
    WHERE t.`target_type` IN (19, 204) AND t.`target_param1` > 0;

-- SMART_TARGET_CREATURE_GUID (10): param1 = guid, param2 = entry. BOTH.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cguid` g ON g.`src_guid` = t.`target_param1`
    SET t.`target_param1` = g.`dst_guid`
    WHERE t.`target_type` = 10 AND t.`target_param1` > 0;
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`target_param2`
    SET t.`target_param2` = m.`dst_entry`
    WHERE t.`target_type` = 10 AND t.`target_param2` > 0;

-- SMART_TARGET_GAMEOBJECT_DISTANCE (15) and SMART_TARGET_CLOSEST_GAMEOBJECT (20):
-- target_param1 = gameobject entry.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`target_param1`
    SET t.`target_param1` = m.`dst_entry`
    WHERE t.`target_type` IN (15, 20) AND t.`target_param1` > 0;

-- SMART_TARGET_GAMEOBJECT_GUID (14): param1 = guid, param2 = entry. BOTH.
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_gguid` g ON g.`src_guid` = t.`target_param1`
    SET t.`target_param1` = g.`dst_guid`
    WHERE t.`target_type` = 14 AND t.`target_param1` > 0;
UPDATE `tmp_strat_ss` t JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`target_param2`
    SET t.`target_param2` = m.`dst_entry`
    WHERE t.`target_type` = 14 AND t.`target_param2` > 0;

-- SMART_TARGET_STORED (12) carries a script-local slot id, NOT an entry -- left alone.

-- -------------------------------------------------------------------------------------
-- 6. Any existing SMART_ACTION_TELEPORT that names map 329
-- -------------------------------------------------------------------------------------
UPDATE `tmp_strat_ss` SET `action_param1` = 821
    WHERE `action_type` = 62 AND `action_param1` = 329;

-- -------------------------------------------------------------------------------------
-- 7. Rewrite the nine cross-map spell casts as native SmartAI teleports
--
-- See the header. Matching is done by joining the cast's spell id to spell_target_position
-- on MapID = 329, so only casts that really carry a stale map id are touched -- the other
-- 175 SMART_ACTION_CAST rows in this data are untouched.
--
-- target_type is forced to 1 (SELF) because that is what all nine rows already use, and the
-- SMART_ACTION_TELEPORT handler reads its destination from target_x/y/z/o regardless of
-- target type.
-- -------------------------------------------------------------------------------------
UPDATE `tmp_strat_ss` t
    JOIN `spell_target_position` s
      ON s.`ID` = t.`action_param1` AND s.`EffectIndex` = 0 AND s.`MapID` = 329
    SET t.`action_type`   = 62,
        t.`action_param1` = 821,
        t.`action_param2` = 0, t.`action_param3` = 0, t.`action_param4` = 0,
        t.`action_param5` = 0, t.`action_param6` = 0,
        t.`target_type`   = 1,
        t.`target_param1` = 0, t.`target_param2` = 0,
        t.`target_param3` = 0, t.`target_param4` = 0,
        t.`target_x` = s.`PositionX`,
        t.`target_y` = s.`PositionY`,
        t.`target_z` = s.`PositionZ`,
        t.`target_o` = s.`Orientation`,
        t.`comment`  = CONCAT(IFNULL(t.`comment`, ''), ' [DC821: was CAST ', s.`ID`,
                              ', rewritten to a native teleport; spell_target_position hardcodes map 329]')
    WHERE t.`action_type` = 11;

-- -------------------------------------------------------------------------------------
-- 8. Write the rows out
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts`
    WHERE (`source_type` = 0 AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`))
       OR (`source_type` = 0 AND `entryorguid` < 0
           AND -`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`))
       OR (`source_type` = 1 AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`))
       OR (`source_type` = 9 AND `entryorguid` IN (SELECT `dst_list` FROM `dc_strat821_almap`));

INSERT INTO `smart_scripts` SELECT * FROM `tmp_strat_ss`;
DROP TEMPORARY TABLE `tmp_strat_ss`;

-- -------------------------------------------------------------------------------------
-- 9. creature_text  (37 rows)
--
-- Copied wholesale with the CreatureID remapped. Group ids are per-creature, so the
-- SMART_ACTION_TALK rows that reference them need no change.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_ctext`;
CREATE TEMPORARY TABLE `tmp_strat_ctext` LIKE `creature_text`;
INSERT INTO `tmp_strat_ctext`
    SELECT * FROM `creature_text`
    WHERE `CreatureID` IN (SELECT `src_entry` FROM `dc_strat821_cmap`);
UPDATE `tmp_strat_ctext` t JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`CreatureID`
    SET t.`CreatureID` = m.`dst_entry`;
INSERT INTO `creature_text` SELECT * FROM `tmp_strat_ctext`;
DROP TEMPORARY TABLE `tmp_strat_ctext`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'clone SmartAI rows, per-entry creature (want 304)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 0
      AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
UNION ALL SELECT 'clone SmartAI rows, per-spawn creature (want 35)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` < 0
      AND -`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
UNION ALL SELECT 'clone SmartAI rows, gameobject (want 54)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 1
      AND `entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
UNION ALL SELECT 'clone SmartAI rows, timed action lists (want 47)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 9
      AND `entryorguid` IN (SELECT `dst_list` FROM `dc_strat821_almap`)
UNION ALL SELECT 'clone action lists (want 13)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_almap`
-- Every actionlist call must resolve, or the creature stalls mid-script.
UNION ALL SELECT 'clone action-list calls that resolve to nothing (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 80
      AND (ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
        OR (ss.`entryorguid` < 0 AND -ss.`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)))
      AND ss.`action_param1` NOT IN
          (SELECT `entryorguid` FROM `smart_scripts` WHERE `source_type` = 9)
-- The teleport fix.
UNION ALL SELECT 'clone rows rewritten to native teleport (want 9)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts`
    WHERE `action_type` = 62 AND `action_param1` = 821
      AND (`entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
        OR (`entryorguid` < 0 AND -`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)))
-- No clone cast may still point at a spell whose destination map is hardcoded to 329.
UNION ALL SELECT 'clone casts still using a map-329 teleport spell (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 11
      AND (ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
        OR (ss.`entryorguid` < 0 AND -ss.`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)))
      AND ss.`action_param1` IN (SELECT `ID` FROM `spell_target_position` WHERE `MapID` = 329)
-- No clone teleport may still name another map.
UNION ALL SELECT 'clone teleports not pointing at 821 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts`
    WHERE `action_type` = 62 AND `action_param1` <> 821
      AND (`entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
        OR (`entryorguid` < 0 AND -`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)))
-- Summons must point into the clone band, or a boss summons a stock creature.
UNION ALL SELECT 'clone summons still naming a stock creature (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 12
      AND (ss.`entryorguid` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
        OR (ss.`entryorguid` < 0 AND -ss.`entryorguid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`))
        OR ss.`entryorguid` IN (SELECT `dst_list` FROM `dc_strat821_almap`))
      AND ss.`action_param1` NOT IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
-- Every summoned entry must have a template, or the summon silently fails.
UNION ALL SELECT 'clone summons with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` ss
    WHERE ss.`action_type` = 12
      AND ss.`action_param1` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
      AND ss.`action_param1` NOT IN (SELECT `entry` FROM `creature_template`)
UNION ALL SELECT 'creature_text clone rows (want 37)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
-- Pre-existing STOCK defect, inherited by the clone, NOT introduced here: one
-- SMART_ACTION_SUMMON_CREATURE_GROUP row references a creature_summon_groups entry that
-- does not exist upstream either. Recorded so it is not mistaken for import damage.
UNION ALL SELECT 'summon-group rows upstream (known 0 - stock gap, informational)', CAST(COUNT(*) AS CHAR)
    FROM `creature_summon_groups`
    WHERE `summonerId` IN (SELECT `src_entry` FROM `dc_strat821_cmap`)
-- Stock untouched.
UNION ALL SELECT 'stock per-entry SmartAI rows (want 282)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0
      AND `entryorguid` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 329)
UNION ALL SELECT 'stock creature_text rows (want 37)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` IN (SELECT `src_entry` FROM `dc_strat821_cmap`);
