-- 77_cauldron_lord_smartai.sql -- map 751 Lordaeron extension, DB step 16.
--
-- Fixes a defect introduced by 74_cauldron_lords.sql.
--
-- 74_ cloned stock Cauldron Lords 11075/11076/11077 into the +3,600,000 band with
-- `SELECT *`, which copied `AIName` along with everything else. Stock 11076 is the
-- only one of the three that uses SmartAI, and its four `smart_scripts` rows were
-- NOT cloned -- so 3611076 Cauldron Lord Razarch boots with SmartAI enabled and no
-- script, which both loses his entire combat behaviour and logs
--   "Creature entry (3611076) has SmartAI enabled but no SmartAI entries in the
--    database."
-- on every startup. 3611075 and 3611077 carry an empty AIName (stock has no SmartAI
-- for them either), so they are correctly left alone.
--
-- The four rows are cloned verbatim. Two things were checked rather than assumed:
--
--   * All three spells exist in this client's Spell.dbc -- 12471 (Shadow Bolt),
--     17204 (Summon Skeleton), 17173 (Drain Life). Nothing here is a Cata-only id.
--   * The "On Aggro - Say Line 0" row keeps `target_type = 7` (ACTION_INVOKER)
--     exactly as stock ships it. The usual porting rule is to force TALK rows to
--     SELF, because SMART_ACTION_TALK makes the TARGET talk and a creature target
--     sends the core hunting creature_text under the wrong entry. That rule does
--     NOT apply here: this fork sets `talker = me` when the resolved target is a
--     PLAYER (SmartScript.cpp:239-243, "xinef: added"), and the invoker on aggro is
--     the player. Rewriting it to SELF would be a change with no benefit.
--
-- creature_text is keyed by CreatureID, so the clone needs its own row or the TALK
-- action finds no text for entry 3611076.
--
-- There is no action-list involved (no SMART_ACTION_CALL_TIMED_ACTIONLIST), so the
-- entry*100 action-list id convention does not come into play.

-- ---------------------------------------------------------------------------
-- 1. creature_text for the clone
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 3611076;

INSERT INTO `creature_text`
  (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
   `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT 3611076, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
       `Duration`, `Sound`, `BroadcastTextId`, `TextRange`,
       'Cauldron Lord Razarch (DC map 751 clone)'
FROM `creature_text` WHERE `CreatureID` = 11076;

-- ---------------------------------------------------------------------------
-- 2. smart_scripts for the clone
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3611076 AND `source_type` = 0;

-- Every column is carried across explicitly, including `event_param5`/`event_param6`
-- and `target_param4` -- this fork's smart_scripts is 31 columns, wider than the
-- upstream table most examples are written against, and letting the extras fall back
-- to their defaults would silently alter the cloned behaviour.
INSERT INTO `smart_scripts`
  (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
   `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
   `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`,
   `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
   `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
   `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 3611076, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
       `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
       `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`,
       `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
       `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
       `target_x`, `target_y`, `target_z`, `target_o`,
       REPLACE(`comment`, 'Cauldron Lord Razarch', 'Cauldron Lord Razarch (DC 751)')
FROM `smart_scripts` WHERE `entryorguid` = 11076 AND `source_type` = 0;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'smart_scripts rows for 3611076 (want 4)' AS what, COUNT(*) AS n
FROM `smart_scripts` WHERE `entryorguid` = 3611076 AND `source_type` = 0
UNION ALL SELECT 'creature_text rows for 3611076 (want 1)', COUNT(*)
FROM `creature_text` WHERE `CreatureID` = 3611076
UNION ALL SELECT 'stock 11076 untouched (want 4)', COUNT(*)
FROM `smart_scripts` WHERE `entryorguid` = 11076 AND `source_type` = 0;

-- must be empty: any creature in the DC bands with SmartAI enabled and no script
SELECT 'PROBLEM: SmartAI enabled but no script' AS problem, t.`entry`, t.`name`
FROM `creature_template` t
WHERE (t.`entry` BETWEEN 4100000 AND 4199999 OR t.`entry` BETWEEN 3600000 AND 3699999)
  AND t.`AIName` = 'SmartAI'
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
                  WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 0);

-- must be empty: a TALK action on the clone with no matching creature_text group
SELECT 'PROBLEM: TALK with no creature_text' AS problem, s.`entryorguid`, s.`id`, s.`action_param1`
FROM `smart_scripts` s
WHERE s.`entryorguid` = 3611076 AND s.`source_type` = 0 AND s.`action_type` = 1
  AND NOT EXISTS (SELECT 1 FROM `creature_text` c
                  WHERE c.`CreatureID` = s.`entryorguid` AND c.`GroupID` = s.`action_param1`);
