-- 82_creature_text.sql -- map 751 Lordaeron extension, DB step 21.
--
-- The import never brought `creature_text` across. The band has **4** rows (the
-- Horde Engineer's, added by 79_) against **353** in cata_world for the same
-- creatures -- so all **171** SmartAI TALK actions in the band are mute, and each
-- one logs "using non-existent Text id" when it fires.
--
-- 99 creatures gain dialogue. Verified clean before writing:
--   * 0 rows reference a BroadcastTextId this DB does not have
--   * 0 rows reference a Sound id at all
--   * 5 distinct Type values, all stock chat types
--
-- Cross-schema INSERT..SELECT on purpose: the text contains apostrophes and other
-- punctuation, and copying it through the server rather than through a generated
-- literal removes the whole escaping class of bug.
--
-- Column note: cata_world.creature_text has 14 columns, ours has 13 -- Cata added
-- `SoundType` between `Sound` and `BroadcastTextId`. It is dropped here; the columns
-- are listed explicitly on both sides so the mismatch cannot shift a value.
--
-- creature_text is keyed by CreatureID, so the +4,100,000 remap is the only
-- transform needed. GroupID/ID are preserved exactly, which matters because
-- smart_scripts TALK actions address a text by GroupID.

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4100000 AND 4199999
  AND `CreatureID` <> 4144734;   -- keep the Horde Engineer rows 79_ authored

INSERT INTO `creature_text`
  (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`,
   `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT ct.`CreatureID` + 4100000, ct.`GroupID`, ct.`ID`, ct.`Text`, ct.`Type`,
       ct.`Language`, ct.`Probability`, ct.`Emote`, ct.`Duration`, ct.`Sound`,
       ct.`BroadcastTextId`, ct.`TextRange`, ct.`comment`
FROM `cata_world`.`creature_text` ct
JOIN `creature_template` t ON t.`entry` = ct.`CreatureID` + 4100000
WHERE t.`entry` BETWEEN 4100000 AND 4199999
  AND ct.`CreatureID` + 4100000 <> 4144734;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'creature_text rows in band (want 357 = 353 + the 4 from 79_)' AS what, COUNT(*) AS n
FROM `creature_text` WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creatures with dialogue (want 100)', COUNT(DISTINCT `CreatureID`)
FROM `creature_text` WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'engineer rows preserved (want 4)', COUNT(*)
FROM `creature_text` WHERE `CreatureID` = 4144734;

-- Was 171 before this file. Whatever remains is a TALK action whose creature has
-- no dialogue in cata_world either -- a genuine upstream gap, not an import loss.
SELECT 'SmartAI TALK actions still without any creature_text' AS what, COUNT(*) AS n
FROM `smart_scripts` s
WHERE s.`action_type` = 1
  AND ((s.`entryorguid` BETWEEN 4100000 AND 4199999) OR (s.`entryorguid` BETWEEN 410000000 AND 419999999))
  AND NOT EXISTS (SELECT 1 FROM `creature_text` c
                  WHERE c.`CreatureID` = IF(s.`source_type` = 9, s.`entryorguid` DIV 100, s.`entryorguid`));

-- must be empty: a TALK action pointing at a GroupID its creature does not have
SELECT 'PROBLEM: TALK references a missing text group' AS problem,
       s.`entryorguid`, s.`id`, s.`action_param1` AS group_id, s.`comment`
FROM `smart_scripts` s
WHERE s.`action_type` = 1
  AND ((s.`entryorguid` BETWEEN 4100000 AND 4199999) OR (s.`entryorguid` BETWEEN 410000000 AND 419999999))
  AND EXISTS (SELECT 1 FROM `creature_text` c
              WHERE c.`CreatureID` = IF(s.`source_type` = 9, s.`entryorguid` DIV 100, s.`entryorguid`))
  AND NOT EXISTS (SELECT 1 FROM `creature_text` c
                  WHERE c.`CreatureID` = IF(s.`source_type` = 9, s.`entryorguid` DIV 100, s.`entryorguid`)
                    AND c.`GroupID` = s.`action_param1`);
