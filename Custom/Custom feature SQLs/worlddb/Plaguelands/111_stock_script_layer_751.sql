-- 111_stock_script_layer_751.sql -- restore the script layer our own stock entries have, DB step 50.
--
-- WHY THIS FILE EXISTS -- 110_ AUDITED AGAINST THE WRONG ORACLE.
--   110_ compared map 751 against cata_world and reported the port essentially complete.
--   That comparison is not wrong, it is just not the one that matters. Map 751's creatures
--   are OFFSET CLONES of entries that already live in this database, so the question that
--   decides whether content works is not "does cata have a script" but:
--
--       does OUR OWN stock entry (id - 4,100,000 / - 3,600,000) have a script the clone lost?
--
--   Against our own stock, matched on entry AND name:
--       lost a stock ScriptName      4  (all 4.1M band)
--       lost stock SmartAI          28  (27 in 4.1M, 1 in 3.6M)  -- 69 rows
--       lost stock creature_text    24                           -- 31 rows
--
-- nelt_world WAS ALSO CHECKED. It reports 110 entries missing SmartAI and 37 missing
-- ScriptNames -- but acting on that list directly would write 22 DEAD ScriptNames, because
-- only 3 of the 25 distinct names nelt uses exist in our core.
--
--   nelt_world is a **4.3.4 Cataclysm** database (Project-Neltharion), NOT a 3.3.5 one.
--   Its ScriptNames are Cata-core C++ names, so "our core does not have them" is expected,
--   not a defect in the import. Their SOURCE does exist locally though -- see the survey in
--   00_EXTENSION_PLAN section 7p -- so they are a PORTING backlog, not a data gap, and they
--   are out of scope for this file.
--
-- Where nelt and our stock disagree on the NAME, our stock is right: nelt says
-- `npc_halloween_fire` / `npc_halloween_orphan_matron`, AC calls the same behaviour
-- `npc_hallows_end_train_fire` / `npc_costumed_orphan_matron`. This file uses the AC names
-- because they are the ones that resolve.
--
-- ===========================================================================
-- CORRECTION TO 110_: THE OOX ESCORT *IS* FIXABLE IN DATA
-- ===========================================================================
--   110_ recorded 4107806 "Homing Robot OOX-09/HL" as needing a C++ script, because cata
--   drives it with `npc_oox09hl` and no such script exists in our core. That conclusion was
--   wrong. Our OWN stock entry 7806 has:
--       AIName = SmartAI | ScriptName = none | 7 smart rows | 30 waypoints | 5 text rows
--   AzerothCore rebuilt that escort as SmartAI. Cloning the stock layer makes it work --
--   no C++ needed. (nelt's spelling is `npc_00x09hl`, with ZEROS, which is also why a grep
--   for the cata spelling found nothing.)
--
-- ===========================================================================
-- WHY VERBATIM CLONING IS SAFE HERE -- checked, not assumed
-- ===========================================================================
--   Cloning smart_scripts across an offset band is normally dangerous because params can
--   carry creature entries that then point at the wrong band. Every one of the 69 rows was
--   classified first:
--
--     * 24 rows are action_type 11 (CAST). `action_param1` there is a SPELL id, not an
--       entry -- spells are global, so verbatim is correct.
--     * The ONLY row with an entry-shaped target is on 7806, target_type 12 with
--       target_param1 = 1. For that target type param1 is a flag, not a creature entry.
--       There is genuinely nothing to re-home.
--     * 9 rows are action_type 80 (CALL_TIMED_ACTIONLIST) across 6 entries. Those lists
--       ALREADY EXIST at their stock ids and a timed action list executes against its
--       invoker, so the clone calling the stock list behaves correctly and shares nothing.
--       This is the opposite of 110_, where list 1081700 did not exist locally and had to
--       be created -- and there it was re-homed precisely because its id belonged to a
--       stock entry that is live here.
--
--   creature_text is cloned in the same file ON PURPOSE: several of these scripts use
--   action_type 1 (TALK), whose action_param1 is a creature_text GroupID. Clone the script
--   without the text and the NPC plays the whole sequence silently.
--
--   AIName is set LAST and for the same reason 110_ existed: rows without AIName='SmartAI'
--   are inert. None of the 28 carries a ScriptName, so there is no C++ AI to shadow them
--   (FactorySelector::SelectAI resolves ScriptName BEFORE SmartAI).

-- ---------------------------------------------------------------------------
-- 0. The clone -> stock mapping, name-verified
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `_dc_stockmap_751`;

CREATE TABLE `_dc_stockmap_751` (
  `clone` INT UNSIGNED NOT NULL,
  `stock` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`clone`),
  KEY `stock` (`stock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_dc_stockmap_751` (`clone`, `stock`)
SELECT c.`id`, st.`entry`
FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751 AND `id` >= 3600000) c
JOIN `creature_template` t ON t.`entry` = c.`id`
JOIN `creature_template` st
  ON st.`entry` = CAST(c.`id` AS SIGNED) - (CASE WHEN c.`id` >= 4100000 THEN 4100000 ELSE 3600000 END)
 AND st.`name` = t.`name`
WHERE EXISTS (SELECT 1 FROM `smart_scripts` x WHERE x.`entryorguid` = st.`entry` AND x.`source_type` = 0)
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` y WHERE y.`entryorguid` = c.`id` AND y.`source_type` = 0);

-- ---------------------------------------------------------------------------
-- 1. Four lost ScriptNames -- names taken from OUR stock, so they are AC-correct
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_hallows_end_train_fire'
 WHERE `entry` = 4123537 AND `ScriptName` = '';   -- Headless Horseman - Fire (DND)
UPDATE `creature_template` SET `ScriptName` = 'npc_professor_phizzlethorpe'
 WHERE `entry` = 4102768 AND `ScriptName` = '';   -- Professor Phizzlethorpe
UPDATE `creature_template` SET `ScriptName` = 'npc_locksmith'
 WHERE `entry` = 4129728 AND `ScriptName` = '';   -- Walter Soref
UPDATE `creature_template` SET `ScriptName` = 'npc_costumed_orphan_matron'
 WHERE `entry` = 4123973 AND `ScriptName` = '';   -- Masked Orphan Matron

-- ---------------------------------------------------------------------------
-- 2. creature_text -- before the scripts, so TALK has something to say
-- ---------------------------------------------------------------------------
DELETE ct FROM `creature_text` ct JOIN `_dc_stockmap_751` m ON m.`clone` = ct.`CreatureID`;

INSERT INTO `creature_text`
 (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
  `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT m.`clone`, ct.`GroupID`, ct.`ID`, ct.`Text`, ct.`Type`, ct.`Language`, ct.`Probability`,
       ct.`Emote`, ct.`Duration`, ct.`Sound`, ct.`BroadcastTextId`, ct.`TextRange`,
       CONCAT('map751 clone of ', m.`stock`, ' - ', IFNULL(ct.`comment`, ''))
FROM `_dc_stockmap_751` m
JOIN `creature_text` ct ON ct.`CreatureID` = m.`stock`;

-- ---------------------------------------------------------------------------
-- 3. waypoints -- only one entry in the set has a path (the OOX robot, 30 points)
-- ---------------------------------------------------------------------------
DELETE w FROM `waypoints` w JOIN `_dc_stockmap_751` m ON m.`clone` = w.`entry`;

INSERT INTO `waypoints`
 (`entry`, `pointid`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `point_comment`)
SELECT m.`clone`, w.`pointid`, w.`position_x`, w.`position_y`, w.`position_z`,
       w.`orientation`, w.`delay`, w.`point_comment`
FROM `_dc_stockmap_751` m
JOIN `waypoints` w ON w.`entry` = m.`stock`;

-- ---------------------------------------------------------------------------
-- 4. smart_scripts -- verbatim except entryorguid, per the classification above
-- ---------------------------------------------------------------------------
DELETE s FROM `smart_scripts` s
JOIN `_dc_stockmap_751` m ON m.`clone` = s.`entryorguid`
WHERE s.`source_type` = 0;

INSERT INTO `smart_scripts`
 (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
  `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
  `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`,
  `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`,
  `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`,
  `target_o`, `comment`)
SELECT m.`clone`, s.`source_type`, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
       s.`event_chance`, s.`event_flags`, s.`event_param1`, s.`event_param2`, s.`event_param3`,
       s.`event_param4`, s.`event_param5`, s.`event_param6`, s.`action_type`, s.`action_param1`,
       s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`,
       s.`action_param6`, s.`target_type`, s.`target_param1`, s.`target_param2`,
       s.`target_param3`, s.`target_param4`, s.`target_x`, s.`target_y`, s.`target_z`,
       s.`target_o`, CONCAT('map751 - ', IFNULL(s.`comment`, ''))
FROM `_dc_stockmap_751` m
JOIN `smart_scripts` s ON s.`entryorguid` = m.`stock` AND s.`source_type` = 0;

-- ---------------------------------------------------------------------------
-- 5. Activate -- without this every row above is inert
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
JOIN `_dc_stockmap_751` m ON m.`clone` = t.`entry`
SET t.`AIName` = 'SmartAI'
WHERE t.`ScriptName` = '';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'entries in the clone map (want 28)' AS what, COUNT(*) AS n FROM `_dc_stockmap_751`
UNION ALL SELECT 'smart_scripts rows cloned (want 69)', COUNT(*)
  FROM `smart_scripts` s JOIN `_dc_stockmap_751` m ON m.`clone` = s.`entryorguid` WHERE s.`source_type` = 0
UNION ALL SELECT 'creature_text rows cloned (want 31)', COUNT(*)
  FROM `creature_text` ct JOIN `_dc_stockmap_751` m ON m.`clone` = ct.`CreatureID`
UNION ALL SELECT 'waypoint rows cloned (want 30)', COUNT(*)
  FROM `waypoints` w JOIN `_dc_stockmap_751` m ON m.`clone` = w.`entry`
UNION ALL SELECT '  ...all on the OOX robot 4107806 (want 30)', COUNT(*)
  FROM `waypoints` WHERE `entry` = 4107806
UNION ALL SELECT 'the 4 ScriptNames set (want 4)', COUNT(*)
  FROM `creature_template` WHERE `entry` IN (4123537, 4102768, 4129728, 4123973) AND `ScriptName` <> ''
UNION ALL SELECT 'clones now AIName=SmartAI (want 28)', COUNT(*)
  FROM `creature_template` t JOIN `_dc_stockmap_751` m ON m.`clone` = t.`entry`
  WHERE t.`AIName` = 'SmartAI'
UNION ALL SELECT 'TALK rows whose text is now present (want all of them)', COUNT(*)
  FROM `smart_scripts` s JOIN `_dc_stockmap_751` m ON m.`clone` = s.`entryorguid`
  WHERE s.`source_type` = 0 AND s.`action_type` = 1
    AND EXISTS (SELECT 1 FROM `creature_text` ct
                 WHERE ct.`CreatureID` = s.`entryorguid` AND ct.`GroupID` = s.`action_param1`)
UNION ALL SELECT '  ...TALK rows still with NO matching text (want 0)', COUNT(*)
  FROM `smart_scripts` s JOIN `_dc_stockmap_751` m ON m.`clone` = s.`entryorguid`
  WHERE s.`source_type` = 0 AND s.`action_type` = 1
    AND NOT EXISTS (SELECT 1 FROM `creature_text` ct
                     WHERE ct.`CreatureID` = s.`entryorguid` AND ct.`GroupID` = s.`action_param1`)
UNION ALL SELECT 'action lists they call that do not exist (want 0)', COUNT(*)
  FROM (SELECT DISTINCT s.`action_param1` AS al FROM `smart_scripts` s
        JOIN `_dc_stockmap_751` m ON m.`clone` = s.`entryorguid`
        WHERE s.`source_type` = 0 AND s.`action_type` = 80) q
  WHERE NOT EXISTS (SELECT 1 FROM `smart_scripts` s2
                     WHERE s2.`source_type` = 9 AND s2.`entryorguid` = q.`al`)
UNION ALL SELECT 'stock entries left untouched (want 0 changed)', COUNT(*)
  FROM `smart_scripts` s JOIN `_dc_stockmap_751` m ON m.`stock` = s.`entryorguid`
  WHERE s.`source_type` = 0 AND s.`comment` LIKE 'map751 -%';

DROP TABLE `_dc_stockmap_751`;
