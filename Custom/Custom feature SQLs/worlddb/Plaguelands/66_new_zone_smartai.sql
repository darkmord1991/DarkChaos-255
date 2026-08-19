-- 66_new_zone_smartai.sql — map 751 Lordaeron extension, DB step 6.
--
-- SmartAI for the imported creatures/gameobjects. REQUIRES 62_ (+63_ for the
-- CREATURE_GUID targets to resolve).
--
-- WHY THIS IS URGENT: 62_ copied AIName verbatim, so **416 imported templates say
-- AIName='SmartAI' and currently have ZERO script rows**. They have no AI at all
-- and the core logs a complaint for each at load. This file is what makes them live.
--
-- FOUR fork-specific traps are handled here. All four were verified against this
-- repo's own headers/consumers, not assumed from upstream docs.
--
-- 1. ACTION-LIST IDS COLLIDE. Timed action lists (source_type 9) are numbered
--    creature_entry*100, so the id space sits at 100x the entry band. **17 of the
--    41 lists these scripts call already exist in acore_world** at their raw ids.
--    Lists are therefore remapped to raw + 410,000,000 (= 100 * the 4,100,000
--    creature offset), which keeps the entry*100 convention intact for the clones.
--    Band verified empty (acore's highest source_type-9 id is 374,825,800).
--    **NEVER range-DELETE source_type 9** — a previous incident wiped 10 stock
--    Icecrown lists that way. This file materialises the exact ids first and
--    deletes only those.
--
-- 2. RANGE EVENTS USE A DIFFERENT PARAM LAYOUT ON THIS CORE. SmartScript.cpp reads
--    the distance from event_param5/6; upstream (and therefore cata_world) puts it
--    in 1/2. Imported unchanged, the rows load silently and then only fire at
--    touching range. 42 event_type 9 rows are shifted to p1=0, p2=0, p3/p4=repeat,
--    p5/p6=distance.
--
-- 3. EVENT 67 IS_BEHIND_TARGET IS NOT A RANGE EVENT even though it shares the
--    minMaxRepeat struct. In cata its p1/p2 are COOLDOWNS; blanket-shifting them
--    once produced an 8000-yard window that never procs. Fork convention (from all
--    15 stock event-67 rows): p1/p2 cooldown, p3/p4 repeat, p5/p6 = 0/5 melee.
--    3 rows. Events 74 and 110 also share the struct and are likewise NOT shifted.
--
-- 4. TARGET TYPE 12 IS `STORED`, NOT A CREATURE REFERENCE. Numbering taken from
--    SmartScriptMgr.h in this repo:
--       9 CREATURE_RANGE(entry)   10 CREATURE_GUID(guid,entry)  11 CREATURE_DISTANCE(entry)
--      12 STORED(id)              13 GO_RANGE(entry)            14 GO_GUID(guid,entry)
--      15 GO_DISTANCE(entry)      19 CLOSEST_CREATURE(entry)    20 CLOSEST_GAMEOBJECT(entry)
--    Only the entity slots are remapped; STORED is left alone.
--    Entry 0 means "any" for the RANGE/DISTANCE/CLOSEST targets and is never remapped.
--
-- acore's smart_scripts has two columns cata lacks — `event_param6` and
-- `target_param4` — which is precisely the fork's range extension.

-- Spawn guids are NOT an offset of the source guid (they are 24-bit and had to be
-- packed into the space under 0xFFFFFF), so CREATURE_GUID / GAMEOBJECT_GUID targets
-- resolve through `dc_map751_spawn_guid`, built by 63_ (or 67_).
-- REQUIRES 63_ to have run, or those targets fall back to the raw source guid.
SET @COFF := 4100000;
SET @GOFF := 4600000;
SET @LOFF := 410000000;   -- 100 * @COFF, the action-list offset

-- ---------------------------------------------------------------------------
-- Materialise the exact action-list ids we touch (see trap 1)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_src_actionlist`;
CREATE TABLE `dc_map751_src_actionlist` (
  `raw` INT UNSIGNED NOT NULL,
  `new` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`raw`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `dc_map751_src_actionlist` (`raw`,`new`)
SELECT DISTINCT s.`action_param1`, s.`action_param1` + @LOFF
FROM `cata_world`.`smart_scripts` s
JOIN `dc_map751_src_creature` m ON m.`id` = s.`entryorguid`
WHERE s.`source_type` = 0 AND s.`action_type` = 80 AND s.`action_param1` > 0;

-- ---------------------------------------------------------------------------
-- Clear only our own rows
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4100000 AND 4199999;
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` BETWEEN 4600000 AND 4899999;
DELETE s FROM `smart_scripts` s
JOIN `dc_map751_src_actionlist` a ON a.`new` = s.`entryorguid`
WHERE s.`source_type` = 9;

-- ---------------------------------------------------------------------------
-- Creature scripts (source_type 0)
-- ---------------------------------------------------------------------------
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT
  s.`entryorguid` + @COFF, 0, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
  s.`event_chance`, s.`event_flags`,
  -- trap 2 / trap 3: range-event param layout
  CASE WHEN s.`event_type` = 9 THEN 0 ELSE s.`event_param1` END,
  CASE WHEN s.`event_type` = 9 THEN 0 ELSE s.`event_param2` END,
  CASE WHEN s.`event_type` IN (9,67) THEN s.`event_param1` ELSE s.`event_param3` END,
  CASE WHEN s.`event_type` IN (9,67) THEN s.`event_param2` ELSE s.`event_param4` END,
  CASE WHEN s.`event_type` = 9 THEN s.`event_param1` WHEN s.`event_type` = 67 THEN 0 ELSE s.`event_param5` END,
  CASE WHEN s.`event_type` = 9 THEN s.`event_param2` WHEN s.`event_type` = 67 THEN 5 ELSE 0 END,
  s.`action_type`,
  -- trap 1 + summon/kill-credit creature ids
  CASE WHEN s.`action_type` = 80 AND s.`action_param1` > 0 THEN s.`action_param1` + @LOFF
       WHEN s.`action_type` IN (12,33) AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m2 WHERE m2.`id` = s.`action_param1`) THEN s.`action_param1` + @COFF
       WHEN s.`action_type` = 50 AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g2 WHERE g2.`id` = s.`action_param1`) THEN s.`action_param1` + @GOFF
       ELSE s.`action_param1` END,
  s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
  s.`target_type`,
  -- trap 4: only real entity slots
  CASE WHEN s.`target_type` IN (9,11,19) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m3 WHERE m3.`id` = s.`target_param1`) THEN s.`target_param1` + @COFF
       WHEN s.`target_type` IN (13,15,20) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g3 WHERE g3.`id` = s.`target_param1`) THEN s.`target_param1` + @GOFF
       WHEN s.`target_type` = 10 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='c' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       WHEN s.`target_type` = 14 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='g' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       ELSE s.`target_param1` END,
  CASE WHEN s.`target_type` = 10 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m4 WHERE m4.`id` = s.`target_param2`) THEN s.`target_param2` + @COFF
       WHEN s.`target_type` = 14 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g4 WHERE g4.`id` = s.`target_param2`) THEN s.`target_param2` + @GOFF
       ELSE s.`target_param2` END,
  s.`target_param3`, 0,
  s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
JOIN `dc_map751_src_creature` m ON m.`id` = s.`entryorguid`
WHERE s.`source_type` = 0;

-- ---------------------------------------------------------------------------
-- Gameobject scripts (source_type 1)
-- ---------------------------------------------------------------------------
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT
  s.`entryorguid` + @GOFF, 1, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
  s.`event_chance`, s.`event_flags`,
  CASE WHEN s.`event_type` = 9 THEN 0 ELSE s.`event_param1` END,
  CASE WHEN s.`event_type` = 9 THEN 0 ELSE s.`event_param2` END,
  CASE WHEN s.`event_type` IN (9,67) THEN s.`event_param1` ELSE s.`event_param3` END,
  CASE WHEN s.`event_type` IN (9,67) THEN s.`event_param2` ELSE s.`event_param4` END,
  CASE WHEN s.`event_type` = 9 THEN s.`event_param1` WHEN s.`event_type` = 67 THEN 0 ELSE s.`event_param5` END,
  CASE WHEN s.`event_type` = 9 THEN s.`event_param2` WHEN s.`event_type` = 67 THEN 5 ELSE 0 END,
  s.`action_type`,
  CASE WHEN s.`action_type` = 80 AND s.`action_param1` > 0 THEN s.`action_param1` + @LOFF
       WHEN s.`action_type` IN (12,33) AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m2 WHERE m2.`id` = s.`action_param1`) THEN s.`action_param1` + @COFF
       WHEN s.`action_type` = 50 AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g2 WHERE g2.`id` = s.`action_param1`) THEN s.`action_param1` + @GOFF
       ELSE s.`action_param1` END,
  s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
  s.`target_type`,
  CASE WHEN s.`target_type` IN (9,11,19) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m3 WHERE m3.`id` = s.`target_param1`) THEN s.`target_param1` + @COFF
       WHEN s.`target_type` IN (13,15,20) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g3 WHERE g3.`id` = s.`target_param1`) THEN s.`target_param1` + @GOFF
       WHEN s.`target_type` = 10 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='c' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       WHEN s.`target_type` = 14 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='g' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       ELSE s.`target_param1` END,
  CASE WHEN s.`target_type` = 10 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m4 WHERE m4.`id` = s.`target_param2`) THEN s.`target_param2` + @COFF
       WHEN s.`target_type` = 14 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g4 WHERE g4.`id` = s.`target_param2`) THEN s.`target_param2` + @GOFF
       ELSE s.`target_param2` END,
  s.`target_param3`, 0,
  s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
JOIN `dc_map751_src_gameobject` m ON m.`id` = s.`entryorguid`
WHERE s.`source_type` = 1;

-- ---------------------------------------------------------------------------
-- Timed action lists (source_type 9), remapped ids
-- ---------------------------------------------------------------------------
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT
  al.`new`, 9, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
  s.`event_chance`, s.`event_flags`,
  s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`, s.`event_param5`, 0,
  s.`action_type`,
  CASE WHEN s.`action_type` = 80 AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_actionlist` a2 WHERE a2.`raw` = s.`action_param1`) THEN s.`action_param1` + @LOFF
       WHEN s.`action_type` IN (12,33) AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m2 WHERE m2.`id` = s.`action_param1`) THEN s.`action_param1` + @COFF
       WHEN s.`action_type` = 50 AND s.`action_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g2 WHERE g2.`id` = s.`action_param1`) THEN s.`action_param1` + @GOFF
       ELSE s.`action_param1` END,
  s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
  s.`target_type`,
  CASE WHEN s.`target_type` IN (9,11,19) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m3 WHERE m3.`id` = s.`target_param1`) THEN s.`target_param1` + @COFF
       WHEN s.`target_type` IN (13,15,20) AND s.`target_param1` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g3 WHERE g3.`id` = s.`target_param1`) THEN s.`target_param1` + @GOFF
       WHEN s.`target_type` = 10 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='c' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       WHEN s.`target_type` = 14 AND s.`target_param1` > 0 THEN COALESCE((SELECT gg.`new_guid` FROM `dc_map751_spawn_guid` gg WHERE gg.`kind`='g' AND gg.`src_guid` = s.`target_param1`), s.`target_param1`)
       ELSE s.`target_param1` END,
  CASE WHEN s.`target_type` = 10 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m4 WHERE m4.`id` = s.`target_param2`) THEN s.`target_param2` + @COFF
       WHEN s.`target_type` = 14 AND s.`target_param2` > 0
            AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` g4 WHERE g4.`id` = s.`target_param2`) THEN s.`target_param2` + @GOFF
       ELSE s.`target_param2` END,
  s.`target_param3`, 0,
  s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
JOIN `dc_map751_src_actionlist` al ON al.`raw` = s.`entryorguid`
WHERE s.`source_type` = 9;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'creature scripts'  AS what, COUNT(*) AS n FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'gameobject scripts', COUNT(*) FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` BETWEEN 4600000 AND 4899999
UNION ALL SELECT 'action list rows',   COUNT(*) FROM `smart_scripts` s JOIN `dc_map751_src_actionlist` a ON a.`new` = s.`entryorguid` WHERE s.`source_type` = 9
UNION ALL SELECT 'distinct action lists', COUNT(*) FROM `dc_map751_src_actionlist`;

-- the 416 dead AINames should now be 0
SELECT 'PROBLEM: AIName=SmartAI with no scripts' AS problem, COUNT(*) AS n
FROM `creature_template` t
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND t.`AIName` = 'SmartAI'
  AND NOT EXISTS(SELECT 1 FROM `smart_scripts` s WHERE s.`source_type` = 0 AND s.`entryorguid` = t.`entry`);

-- the inverse: script rows whose template does not say SmartAI (they never run)
SELECT 'PROBLEM: scripts but AIName not SmartAI' AS problem, COUNT(DISTINCT s.`entryorguid`) AS n
FROM `smart_scripts` s JOIN `creature_template` t ON t.`entry` = s.`entryorguid`
WHERE s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4100000 AND 4199999 AND t.`AIName` <> 'SmartAI';

-- every CALL_TIMED_ACTIONLIST must point at a list that exists
SELECT 'PROBLEM: actionlist call with no list' AS problem, COUNT(*) AS n
FROM `smart_scripts` s
WHERE s.`action_type` = 80 AND s.`action_param1` > 0
  AND (   (s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4100000 AND 4199999)
       OR (s.`source_type` = 9 AND EXISTS(SELECT 1 FROM `dc_map751_src_actionlist` a WHERE a.`new` = s.`entryorguid`)))
  AND NOT EXISTS(SELECT 1 FROM `smart_scripts` l WHERE l.`source_type` = 9 AND l.`entryorguid` = s.`action_param1`);

-- range events must carry their distance in 5/6, never in 1/2
SELECT 'PROBLEM: event 9 distance left in p1/p2' AS problem, COUNT(*) AS n
FROM `smart_scripts`
WHERE `source_type` IN (0,1) AND `entryorguid` BETWEEN 4100000 AND 4899999
  AND `event_type` = 9 AND (`event_param1` <> 0 OR `event_param2` <> 0);

-- and must actually have a usable max distance
SELECT 'event 9 rows with rangeMax = 0 (fires only at contact)' AS note, COUNT(*) AS n
FROM `smart_scripts`
WHERE `source_type` IN (0,1) AND `entryorguid` BETWEEN 4100000 AND 4899999
  AND `event_type` = 9 AND `event_param6` = 0;
