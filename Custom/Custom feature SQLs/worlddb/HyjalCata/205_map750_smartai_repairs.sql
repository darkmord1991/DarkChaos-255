-- ---------------------------------------------------------------------------
-- 205  Map 750 -- repair the SmartAI layer 204_ imported
-- ---------------------------------------------------------------------------
-- After applying 202_/203_/204_ and restarting, the live Errors.log contains
-- exactly 50 `SmartAIMgr:` rejections, plus a CONTINUOUS runtime stream of
--
--     SmartScript::ProcessAction: Entry 3734046 SourceType 0,
--         Event 0, Link Event 1 not found, skipped.
--
-- that repeats every time a player flies past the creature. That runtime spam
-- is the downstream symptom, not the cause: event 1 is REJECTED AT LOAD, so
-- event 0's `link` points into a hole and complains on every single execution.
-- Fixing the load-time rejections silences the runtime stream with it.
--
-- This file is scoped to what the server itself reported. The rejection list
-- was taken from the log rather than re-derived from AzerothCore's validation
-- rules, because those rules are param-position sensitive (action 45's
-- action_param1 is a data field, NOT a creature entry -- guessing that wrong
-- is how you "fix" a working row into a broken one).
--
-- FIVE DISTINCT DEFECTS, all introduced by 204_:
--
--   A) 2 spells the scripts cast do not exist here (88354, 89282).
--   B) 15 creatures TALK to creature_text rows that were never imported --
--      204_ brought the scripts across but not the dialogue they read.
--   C) 2 waypoint paths (34033, 34103) referenced with their RAW cata ids.
--   D) 7 creature references left at raw cata ids instead of the +3,700,000
--      (or +3,600,000) clone band, so they resolve to nothing.
--   E) 11 rows carry parameters in fields the core requires to be zero.
--      SMART_EVENT_LINK (61) takes no event params and SMART_TARGET_VICTIM (2)
--      takes no target params; 204_ copied them from the source row anyway.
--
-- Apply against acore_world AFTER 204_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) spell_dbc -- the 2 spells 203_ missed
-- ---------------------------------------------------------------------------
-- Same provenance and the same conversion as 203_: K:\UntouchedClients\Cata,
-- Data\enUS\locale-enUS.MPQ, Spell.dbc (48 fields) + SpellEffect.dbc (27).
-- 3.3.5 computes an effect as BasePoints + rand(1..DieSides) while Cata dropped
-- DieSides entirely, so DieSides is written as 1 and BasePoints as (cata - 1)
-- to reproduce the identical final amount.
--
--   88354  Enchanted Imp Sack                 effects: E0=3/aura 0
--   89282  Vomit Slime                        effects: E0=32/aura 0
-- ---------------------------------------------------------------------------
DELETE FROM `spell_dbc` WHERE `ID` IN (88354, 89282);

INSERT INTO `spell_dbc`
    (`ID`,
     `Attributes`,
     `AttributesEx`,
     `AttributesEx2`,
     `AttributesEx3`,
     `AttributesEx4`,
     `AttributesEx5`,
     `AttributesEx6`,
     `AttributesEx7`,
     `CastingTimeIndex`,
     `DurationIndex`,
     `PowerType`,
     `RangeIndex`,
     `Speed`,
     `SpellVisualID_1`,
     `SpellVisualID_2`,
     `SpellIconID`,
     `ActiveIconID`,
     `SchoolMask`,
     `ProcChance`,
     `EquippedItemClass`,
     `Name_Lang_enUS`,
     `Description_Lang_enUS`,
     `Effect_1`,`EffectAura_1`,`EffectBasePoints_1`,`EffectDieSides_1`,`EffectAuraPeriod_1`,`EffectMiscValue_1`,`EffectMiscValueB_1`,`EffectRadiusIndex_1`,`EffectTriggerSpell_1`,`ImplicitTargetA_1`,`ImplicitTargetB_1`,`Effect_2`,`EffectAura_2`,`EffectBasePoints_2`,`EffectDieSides_2`,`EffectAuraPeriod_2`,`EffectMiscValue_2`,`EffectMiscValueB_2`,`EffectRadiusIndex_2`,`EffectTriggerSpell_2`,`ImplicitTargetA_2`,`ImplicitTargetB_2`,`Effect_3`,`EffectAura_3`,`EffectBasePoints_3`,`EffectDieSides_3`,`EffectAuraPeriod_3`,`EffectMiscValue_3`,`EffectMiscValueB_3`,`EffectRadiusIndex_3`,`EffectTriggerSpell_3`,`ImplicitTargetA_3`,`ImplicitTargetB_3`)
VALUES
  (88354, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 141, 0.0000, 17990, 0, 1, 0, 1, 101, -1, 'Enchanted Imp Sack', 'Capture Impsy in the bag once he''s been weakened.', 3, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89282, 134217984, 268435456, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 5.0000, 18967, 0, 1, 0, 1, 101, -1, 'Vomit Slime', '', 32, 0, 0, 0, 0, 0, 0, 8, 89287, 47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- B) creature_text -- the dialogue the TALK actions read
-- ---------------------------------------------------------------------------
-- 18 TALK actions across 15 creatures were rejected with "using non-existent
-- Text id N". All 15 have their text in cata_world (30 rows total), none of it
-- is present here, and every one of the 13 BroadcastTextIds those rows carry
-- already resolves against our `broadcast_text` -- verified, so the ids come
-- across as-is rather than being zeroed. No row references a Sound, so there
-- is no WotLK SoundEntries gap to work around.
--
-- cata_world.creature_text has one extra column (`SoundType`) that we do not,
-- hence the explicit column list.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (
  3703841, 3732859, 3732860, 3732863, 3732868, 3732989, 3733079, 3734033,
  3734413, 3747339, 3747369, 3747679, 3747696, 3748332, 3748344);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`CreatureID` + 3700000, t.`GroupID`, t.`ID`, t.`Text`, t.`Type`, t.`Language`,
       t.`Probability`, t.`Emote`, t.`Duration`, t.`Sound`, t.`BroadcastTextId`,
       t.`TextRange`, t.`comment`
FROM `cata_world`.`creature_text` t
WHERE t.`CreatureID` IN (
  3841, 32859, 32860, 32863, 32868, 32989, 33079, 34033,
  34413, 47339, 47369, 47679, 47696, 48332, 48344);

-- ---------------------------------------------------------------------------
-- C) waypoints -- Teegan Holloway (34033) and Keynira Owlwing (34103)
-- ---------------------------------------------------------------------------
-- Both patrol Darkshore and both were imported pointing at their raw cata path
-- id, which does not exist here: "Action 53 uses non-existent WaypointPath id
-- 34033". The paths themselves are in cata_world (14 and 26 points), and their
-- coordinates already sit inside map 750's Darkshore footprint (x 7184-7376,
-- y -804..-733), so only the path id is offset -- positions copy unchanged.
--
-- THE SECOND HALF MATTERS AS MUCH AS THE FIRST: the path id also appears in
-- `event_param2` of every SMART_EVENT_WAYPOINT_REACHED (40) row -- 4 rows for
-- Teegan, 6 for Keynira. Repointing only action_param2 would start the walk but
-- leave every "on waypoint N reached" trigger dead, so both are updated.
--
-- cata_world.waypoints has `velocity` and `smoothTransition`, which our table
-- does not, hence the explicit column list.
-- ---------------------------------------------------------------------------
DELETE FROM `waypoints` WHERE `entry` IN (3734033, 3734103);

INSERT INTO `waypoints`
    (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT w.`entry` + 3700000, w.`pointid`, w.`position_x`, w.`position_y`, w.`position_z`,
       w.`orientation`, w.`delay`, w.`point_comment`
FROM `cata_world`.`waypoints` w
WHERE w.`entry` IN (34033, 34103);

UPDATE `smart_scripts`
   SET `action_param2` = `action_param2` + 3700000
 WHERE `source_type` = 0 AND `entryorguid` IN (3734033, 3734103)
   AND `action_type` = 53 AND `action_param2` IN (34033, 34103);

UPDATE `smart_scripts`
   SET `event_param2` = `event_param2` + 3700000
 WHERE `source_type` = 0 AND `entryorguid` IN (3734033, 3734103)
   AND `event_type` = 40 AND `event_param2` IN (34033, 34103);

-- ---------------------------------------------------------------------------
-- D) raw creature ids -> the clone band
-- ---------------------------------------------------------------------------
-- Every one of these was verified to exist at the offset before being written:
--   75191 -> 3675191  Wondi's Bunny (blue arrow target)      +3,600,000
--   53131 -> 3653131  Lava Bubbles                           +3,600,000
--   47366 -> 3747366  Impsy                                  +3,700,000
--   48573 -> 3748573  Chaewel                                +3,700,000
--   48577 -> 3748577  Ciana                                  +3,700,000
--   34041 -> 3734041  Mathas Wildwood (5 rows in one list)   +3,700,000
--   47692 -> 3747692  Altsoba Ragetotem                      +3,700,000
--
-- Each UPDATE re-states the old value in its WHERE clause, so re-running the
-- file cannot touch an already-corrected row or a row that meant something else.
-- ---------------------------------------------------------------------------
UPDATE `smart_scripts` SET `target_param1` = 3675191
 WHERE `source_type` = 0 AND `entryorguid` = 3653112 AND `id` = 6 AND `target_param1` = 75191;

UPDATE `smart_scripts` SET `target_param1` = 3653131
 WHERE `source_type` = 0 AND `entryorguid` = 3653112 AND `id` = 9 AND `target_param1` = 53131;

UPDATE `smart_scripts` SET `target_param1` = 3747366
 WHERE `source_type` = 0 AND `entryorguid` = 3747341 AND `id` = 1 AND `target_param1` = 47366;

UPDATE `smart_scripts` SET `target_param1` = 3748573
 WHERE `source_type` = 0 AND `entryorguid` = 3748574 AND `id` = 1 AND `target_param1` = 48573;

UPDATE `smart_scripts` SET `target_param1` = 3748577
 WHERE `source_type` = 0 AND `entryorguid` = 3748574 AND `id` = 2 AND `target_param1` = 48577;

UPDATE `smart_scripts` SET `target_param1` = 3734041
 WHERE `source_type` = 9 AND `entryorguid` = 373410304 AND `target_param1` = 34041;

-- Kelnir Leafsong is the odd one out. Its row uses target_type 10
-- (SMART_TARGET_CREATURE_GUID), where target_param1 is a cata SPAWN GUID
-- (361152) and target_param2 the entry. That guid cannot be translated -- our
-- import assigned fresh guids and the link back is gone. Rather than invent a
-- guid, the row is converted to target_type 19 (CLOSEST_CREATURE) on the
-- correct entry within 30y, which is what the original was reaching for: the
-- single Altsoba Ragetotem standing next to him.
UPDATE `smart_scripts`
   SET `target_type` = 19, `target_param1` = 3747692, `target_param2` = 30
 WHERE `source_type` = 0 AND `entryorguid` = 3747696 AND `id` = 1
   AND `target_type` = 10 AND `target_param2` = 47692;

-- ---------------------------------------------------------------------------
-- E) parameters in fields that must be zero
-- ---------------------------------------------------------------------------
-- These two are core invariants, not judgement calls:
--   * SMART_EVENT_LINK (61) is triggered purely by another event's `link` and
--     reads no event params. 204_ copied the timers from the source row it was
--     chained to, so the core rejected it.
--   * SMART_TARGET_VICTIM (2) is "whoever I am fighting" and reads no target
--     params. 204_ carried a stray radius across.
--
-- Written as rules rather than a pinned id list ON PURPOSE: both conditions are
-- unconditionally illegal, an UPDATE that zeroes them cannot remove content,
-- and a rule also catches rows that only start failing once an earlier fix lets
-- them load. Both statements are scoped to the map-750 import bands so nothing
-- outside this downport is touched -- source_type 0 for creature entries and
-- source_type 9 for their action lists (entry x 100), which is what keeps the
-- stock action lists in the same numeric window out of range.
-- ---------------------------------------------------------------------------
UPDATE `smart_scripts`
   SET `event_param1` = 0, `event_param2` = 0, `event_param3` = 0, `event_param4` = 0
 WHERE `event_type` = 61
   AND ((`source_type` = 0 AND `entryorguid` BETWEEN 3600000 AND 3899999)
     OR (`source_type` = 9 AND `entryorguid` BETWEEN 360000000 AND 389999999))
   AND (`event_param1` <> 0 OR `event_param2` <> 0 OR `event_param3` <> 0 OR `event_param4` <> 0);

UPDATE `smart_scripts`
   SET `target_param1` = 0, `target_param2` = 0
 WHERE `target_type` = 2
   AND ((`source_type` = 0 AND `entryorguid` BETWEEN 3600000 AND 3899999)
     OR (`source_type` = 9 AND `entryorguid` BETWEEN 360000000 AND 389999999))
   AND (`target_param1` <> 0 OR `target_param2` <> 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM spell_dbc WHERE ID IN (88354,89282);            -- 2
--   SELECT COUNT(*) FROM creature_text WHERE CreatureID BETWEEN 3700000
--     AND 3799999 AND CreatureID IN (3703841,3732859,3747339);           -- 5
--   SELECT COUNT(*) FROM waypoints WHERE entry IN (3734033,3734103);     -- 40
--
--   -- nothing in the import bands still breaks the two zero-field rules:
--   SELECT COUNT(*) FROM smart_scripts WHERE event_type=61
--     AND (event_param1<>0 OR event_param2<>0 OR event_param3<>0 OR event_param4<>0)
--     AND ((source_type=0 AND entryorguid BETWEEN 3600000 AND 3899999)
--       OR (source_type=9 AND entryorguid BETWEEN 360000000 AND 389999999));  -- 0
--
-- Errors.log should lose ALL 50 `SmartAIMgr:` lines for the 3.6M-3.8M band and
-- the whole `SmartScript::ProcessAction ... Link Event ... not found` runtime
-- stream. Teegan Holloway and Keynira Owlwing should walk their Darkshore
-- patrols and stop at their scripted points, and the five creatures previously
-- reported as "has SmartAI enabled but no SmartAI entries" (3733020 Zenn
-- Foulhoof, 3747696 Kelnir Leafsong, 3748038 Ironwood Buzzer, 3748332, 3748456
-- Rabid Screecher) get their behaviour back, since each had only the one event.
--
-- NOT addressed here -- pre-existing, unrelated to map 750, left alone:
--   Creature 16256 / 17238 / 5391201 waypoint-path warnings (stock content).
-- ---------------------------------------------------------------------------
