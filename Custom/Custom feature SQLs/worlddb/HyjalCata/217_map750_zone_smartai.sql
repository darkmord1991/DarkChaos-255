-- ---------------------------------------------------------------------------
-- 217  Map 750 -- SmartAI for the Ashenvale/Winterspring creatures
-- ---------------------------------------------------------------------------
-- APPLY 216_ FIRST (the 33 spells these scripts cast).
--
-- 212_ imported 190 creature templates with AIName deliberately cleared, so
-- they have been fighting with default AI. This restores the scripted layer:
-- 280 smart_scripts rows across 108 entries, 85 creature_text rows, and the
-- AIName flag switched back on only where rows actually exist.
--
-- THIS IMPORT IS MUCH SIMPLER THAN 204_ WAS, and it is worth saying why,
-- because 204_ produced 50 rejections and a runtime log flood. Every one of the
-- five failure classes 205_ had to repair was checked for here and does not
-- occur in this set:
--     action 53 waypoint paths referenced .......... 0
--     action 33 KILL_CREDIT rows ................... 0
--     event 61 LINK rows carrying event params ..... 0
--     rows needing creature-id remapping ........... 5  (handled below)
--     spells missing after 216_ .................... 0
-- So the only real work is the id arithmetic and the schema mapping.
--
-- SCHEMA DRIFT -- checked before writing, which is the lesson from 212_:
--     ours: ... event_param5, event_param6, action_*, target_param1..4, ...
--     cata: ... event_param5,               action_*, target_param1..3, ...
-- cata has no `event_param6` and no `target_param4`. SELECT * or a copied
-- column list would fail, and because `mysql source` continues past an error a
-- preceding DELETE would land while the INSERT did not. Both are written as 0.
--
-- ID ARITHMETIC:
--   source_type 0  entryorguid          -> + 3,700,000
--   source_type 9  entryorguid          -> (FLOOR(e/100) + 3,700,000)*100 + (e MOD 100)
--                                          e.g. 2010206 -> 372,010,206
--   action 80      action_param1        -> same action-list transform
--   action 12      action_param1        -> + 3,700,000  (summoned creature)
--   target 9/10/11/19  target_param1    -> + 3,700,000  (targeted creature)
-- Left raw, each of those points at a stock creature or a non-existent list.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Three extra creature templates the scripts reference
-- ---------------------------------------------------------------------------
-- Instant Boulder (49149) and Kilram's Tree (49191) are summoned by action 12;
-- Heretic Emissary (25951) is the target of two say-text actions. None is in
-- 212_'s port set because none of them has a spawn -- they only ever exist as
-- summons -- so without this the five remapped rows would point at nothing.
-- Same column mapping as 212_, including the five columns cata does not have.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3749149, 3749191, 3725951);
DELETE FROM `creature_template` WHERE `entry` IN (3749149, 3749191, 3725951);

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,
     `DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,
     `unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,
     `skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,
     `RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT c.`entry`+3700000, 0, 0, 0, 0, 0,
       c.`name`, c.`subname`, c.`IconName`, c.`gossip_menu_id`, c.`minlevel`, c.`maxlevel`, 0,
       c.`faction`, c.`npcflag`, c.`speed_walk`, c.`speed_run`, 1, 1, 18, c.`rank`, c.`dmgschool`,
       c.`DamageModifier`, c.`BaseAttackTime`, c.`RangeAttackTime`, c.`BaseVariance`, c.`RangeVariance`,
       c.`unit_class`, c.`unit_flags`, c.`unit_flags2`, 0, c.`family`, c.`type`, c.`type_flags`,
       0, 0, 0, c.`PetSpellDataId`, 0, c.`mingold`, c.`maxgold`, '', c.`MovementType`, c.`HoverHeight`,
       c.`HealthModifier`, c.`ManaModifier`, c.`ArmorModifier`, c.`ExperienceModifier`,
       c.`RacialLeader`, c.`movementId`, c.`RegenHealth`, 0, c.`flags_extra`, '', 0
FROM `cata_world`.`creature_template` c
WHERE c.`entry` IN (49149, 49191, 25951);

INSERT IGNORE INTO `creature_template_model`
    (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.`CreatureID`+3700000, m.`Idx`, m.`CreatureDisplayID`, 1, m.`Probability`, 0
FROM `cata_world`.`creature_template_model` m
WHERE m.`CreatureID` IN (49149, 49191, 25951) AND m.`CreatureDisplayID` > 0;

-- ---------------------------------------------------------------------------
-- B) creature_text -- the dialogue the TALK actions read
-- ---------------------------------------------------------------------------
-- Imported before the scripts on purpose: a TALK action whose text is absent is
-- rejected at load, which is how 205_ and 210_ each ended up chasing a second
-- round of cascaded errors.
--
-- cata_world.creature_text carries an extra `SoundType` column, hence the
-- explicit list.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (
  SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport`) x);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`CreatureID`+3700000, t.`GroupID`, t.`ID`, t.`Text`, t.`Type`, t.`Language`,
       t.`Probability`, t.`Emote`, t.`Duration`, t.`Sound`, t.`BroadcastTextId`,
       t.`TextRange`, t.`comment`
FROM `cata_world`.`creature_text` t
WHERE t.`CreatureID` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`);

-- ---------------------------------------------------------------------------
-- C) smart_scripts -- 245 creature rows
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (
  SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport`) x);

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT s.`entryorguid`+3700000, 0, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
       s.`event_chance`, s.`event_flags`,
       s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`, s.`event_param5`, 0,
       s.`action_type`,
       CASE WHEN s.`action_type` = 12 AND s.`action_param1` > 0 THEN s.`action_param1`+3700000
            WHEN s.`action_type` = 80 AND s.`action_param1` > 0
                 THEN (FLOOR(s.`action_param1`/100)+3700000)*100 + (s.`action_param1` MOD 100)
            ELSE s.`action_param1` END,
       s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
       s.`target_type`,
       CASE WHEN s.`target_type` IN (9,10,11,19) AND s.`target_param1` > 0
            THEN s.`target_param1`+3700000 ELSE s.`target_param1` END,
       s.`target_param2`, s.`target_param3`, 0,
       s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
WHERE s.`source_type` = 0
  AND s.`entryorguid` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`);

-- ---------------------------------------------------------------------------
-- D) smart_scripts -- the 15 action lists (35 rows)
-- ---------------------------------------------------------------------------
-- Action-list ids are entry*100 + index on both sides, so the transform has to
-- split the id, offset the entry half and reassemble: 2010206 -> 372,010,206.
-- Naively adding 3,700,000 to the whole id would land on a different creature's
-- list. This matches the convention 204_ established (373410304 -> 3734103).
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (
  SELECT * FROM (
    SELECT DISTINCT (FLOOR(s.`entryorguid`/100)+3700000)*100 + (s.`entryorguid` MOD 100)
    FROM `cata_world`.`smart_scripts` s
    WHERE s.`source_type` = 9
      AND FLOOR(s.`entryorguid`/100) IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
  ) x);

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT (FLOOR(s.`entryorguid`/100)+3700000)*100 + (s.`entryorguid` MOD 100), 9, s.`id`, s.`link`,
       s.`event_type`, s.`event_phase_mask`, s.`event_chance`, s.`event_flags`,
       s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`, s.`event_param5`, 0,
       s.`action_type`,
       CASE WHEN s.`action_type` = 12 AND s.`action_param1` > 0 THEN s.`action_param1`+3700000
            WHEN s.`action_type` = 80 AND s.`action_param1` > 0
                 THEN (FLOOR(s.`action_param1`/100)+3700000)*100 + (s.`action_param1` MOD 100)
            ELSE s.`action_param1` END,
       s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
       s.`target_type`,
       CASE WHEN s.`target_type` IN (9,10,11,19) AND s.`target_param1` > 0
            THEN s.`target_param1`+3700000 ELSE s.`target_param1` END,
       s.`target_param2`, s.`target_param3`, 0,
       s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
WHERE s.`source_type` = 9
  AND FLOOR(s.`entryorguid`/100) IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`);

-- ---------------------------------------------------------------------------
-- E) Turn AIName back on -- ONLY where rows landed
-- ---------------------------------------------------------------------------
-- Guarded on smart_scripts actually having rows, so this cannot recreate the
-- "has SmartAI enabled but no SmartAI entries" class that 205_/210_/215_ spent
-- three files clearing. Creatures whose scripts did not import keep default AI.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` ct
   SET ct.`AIName` = 'SmartAI'
 WHERE ct.`entry` IN (SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport`) x)
   AND ct.`AIName` = ''
   AND EXISTS (SELECT 1 FROM `smart_scripts` s
               WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM smart_scripts WHERE source_type=0
--     AND entryorguid IN (SELECT DISTINCT src_id+3700000 FROM dc_map750_zoneport);   -- 245
--   SELECT COUNT(*) FROM smart_scripts WHERE source_type=9
--     AND entryorguid BETWEEN 370000000 AND 379999999;                               -- 35+
--   SELECT COUNT(*) FROM creature_text
--     WHERE CreatureID IN (SELECT DISTINCT src_id+3700000 FROM dc_map750_zoneport);  -- 85
--
--   -- no creature claims SmartAI without rows (expect 0):
--   SELECT COUNT(*) FROM creature_template ct
--    WHERE ct.entry IN (SELECT DISTINCT src_id+3700000 FROM dc_map750_zoneport)
--      AND ct.AIName='SmartAI'
--      AND NOT EXISTS (SELECT 1 FROM smart_scripts s
--                      WHERE s.entryorguid=ct.entry AND s.source_type=0);
--
--   -- every RUN_SCRIPT points at a list that exists (expect 0):
--   SELECT COUNT(*) FROM smart_scripts a WHERE a.action_type=80
--     AND a.entryorguid BETWEEN 3700000 AND 379999999
--     AND NOT EXISTS (SELECT 1 FROM smart_scripts b
--                     WHERE b.source_type=9 AND b.entryorguid=a.action_param1);
--
-- Watch Errors.log for `SmartAIMgr:` lines naming 37xxxxx entries. If any
-- appear, they are the authoritative list of what still needs fixing -- read
-- them rather than re-deriving the rules, which is what made 205_ tractable.
-- ---------------------------------------------------------------------------
