-- ---------------------------------------------------------------------------
-- 196  Hyjal round-45 -- the SmartAI the source has and map 750 was missing
-- ---------------------------------------------------------------------------
-- The C++ audit (193_/194_) asked "which SCRIPTS are missing".  This asks the
-- other half: which SmartAI does cata_world define for creatures we actually
-- spawn, that we never imported?
--
-- Of 1,642 creature entries spawned on map 750 we hold smart_scripts for 639.
-- The source has scripts for 635 of them -- and 54 entries where the source has
-- scripts and WE HAVE NONE.  Plus one gameobject (3961927 Bonfire).  That is
-- 93 creature rows, 12 action-list rows and the object's rows.
--
-- THREE ID CLASSES ARE REMAPPED, exactly as the earlier waypoint/SmartAI
-- restore recorded.  Getting any of them wrong silently points a script at the
-- wrong content:
--
--  1. entryorguid -> our cloned entry.  Derived per row as the +3,600,000 or
--     +3,700,000 variant that is ACTUALLY SPAWNED here, not assumed -- these 54
--     span both bands.
--
--  2. Action-list ids (action_type 80/87/88).  Lists follow the entry*100
--     convention, confirmed on both hits: 2164 -> 216400 and 3916 -> 391600.
--     So the new id is old + (our_entry - base) * 100, which yields +370M for
--     the +3.7M band and +360M for the +3.6M band automatically.
--
--  3. Creature-entry parameters.  One target reference (Cenarion Dreamwarden
--     targeting 22902 -> 3722902) and, inside the Rabid Thistle Bear list, a
--     KILL_CREDIT and an UPDATE_TEMPLATE both naming 11836 "Captured Rabid
--     Thistle Bear" -> 3711836.  All three verified to exist here first.
--
-- SPELLS WERE THE REAL RISK.  The 93 rows cast 63 distinct spells and 43 of
-- them do NOT exist in the live Spell.dbc.  Importing as-is would have created
-- 43 fresh "non-existent Spell entry" errors -- precisely what 192_ removes.
-- Those 43 are therefore folded INTO 192_ (now 86 spells), so this file must
-- run AFTER it.  The action-list spell 8736 was checked separately and is
-- present (spell_dbc reports 0 for it, but that table is only the override --
-- the client dbc has it).
--
-- UNSIGNED ARITHMETIC: creature.id is BIGINT UNSIGNED, so `id - 3700000` on a
-- +3.6M-band entry underflows and MySQL aborts with 1690 "value is out of
-- range" (it did, on the first revision).  Every de-offset below is wrapped in
-- CAST(... AS SIGNED), and the 54-id filter now sits INSIDE the derived table so
-- the join only ever evaluates those rows.
--
-- ORDER: after 192_ (spells) and after 180_ (the entries must exist).
-- ---------------------------------------------------------------------------

-- --- scoped wipe: only the entries this file fills, never a range ----------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (
  3603812,3603916,3603932,3606087,3606350,3606352,3606372,3606649,3607458,3608015,
  3611822,3612123,3612903,3617406,3638896,3639445,3639642,3640139,3640150,3640229,
  3640464,3640536,3640573,3640709,3640713,3640767,3640814,3640844,3640998,3641029,
  3641030,3641031,3641502,3641565,3641614,3650055,3650056,3650057,3650058,3702164,
  3702803,3707126,3710197,3710200,3711798,3711800,3711822,3714339,3714344,3715315,
  3722835,3722889,3722902,3747747);

DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (370216400, 360391600);
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` = 3961927;

-- --- 1. creature scripts ---------------------------------------------------
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT m.our_id, 0, cs.`id`, cs.`link`, cs.`event_type`, cs.`event_phase_mask`, cs.`event_chance`, cs.`event_flags`,
       cs.`event_param1`, cs.`event_param2`, cs.`event_param3`, cs.`event_param4`, 0, 0,
       cs.`action_type`,
       CASE WHEN cs.`action_type` IN (80,87,88) THEN cs.`action_param1` + (CAST(m.our_id AS SIGNED) - cs.`entryorguid`) * 100
            ELSE cs.`action_param1` END,
       cs.`action_param2`, cs.`action_param3`, cs.`action_param4`, cs.`action_param5`, cs.`action_param6`,
       cs.`target_type`,
       CASE WHEN cs.`target_type` IN (9,11,19) AND cs.`target_param1` > 0
            THEN cs.`target_param1` + (CAST(m.our_id AS SIGNED) - cs.`entryorguid`)
            ELSE cs.`target_param1` END,
       cs.`target_param2`, cs.`target_param3`, 0,
       cs.`target_x`, cs.`target_y`, cs.`target_z`, cs.`target_o`, cs.`comment`
FROM cata_world.smart_scripts cs
JOIN (SELECT DISTINCT c.`id` AS our_id FROM acore_world.creature c
      WHERE c.`map` = 750 AND c.`id` IN (
   3603812,3603916,3603932,3606087,3606350,3606352,3606372,3606649,3607458,3608015,
   3611822,3612123,3612903,3617406,3638896,3639445,3639642,3640139,3640150,3640229,
   3640464,3640536,3640573,3640709,3640713,3640767,3640814,3640844,3640998,3641029,
   3641030,3641031,3641502,3641565,3641614,3650055,3650056,3650057,3650058,3702164,
   3702803,3707126,3710197,3710200,3711798,3711800,3711822,3714339,3714344,3715315,
   3722835,3722889,3722902,3747747)) m
  ON cs.`entryorguid` IN (CAST(m.our_id AS SIGNED) - 3600000, CAST(m.our_id AS SIGNED) - 3700000)
WHERE cs.`source_type` = 0;

-- --- 2. the two action lists ----------------------------------------------
-- 216400 -> 370216400 (Rabid Thistle Bear, +3.7M band)
-- 391600 -> 360391600 (Shael'dryn, +3.6M band)
-- Inside the bear's list, KILL_CREDIT (33) and UPDATE_TEMPLATE (36) both name
-- 11836 -> 3711836.
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT CASE al.`entryorguid` WHEN 216400 THEN 370216400 ELSE 360391600 END,
       9, al.`id`, al.`link`, al.`event_type`, al.`event_phase_mask`, al.`event_chance`, al.`event_flags`,
       al.`event_param1`, al.`event_param2`, al.`event_param3`, al.`event_param4`, 0, 0,
       al.`action_type`,
       CASE WHEN al.`action_type` IN (33,36) AND al.`action_param1` = 11836 THEN 3711836
            ELSE al.`action_param1` END,
       al.`action_param2`, al.`action_param3`, al.`action_param4`, al.`action_param5`, al.`action_param6`,
       al.`target_type`, al.`target_param1`, al.`target_param2`, al.`target_param3`, 0,
       al.`target_x`, al.`target_y`, al.`target_z`, al.`target_o`, al.`comment`
FROM cata_world.smart_scripts al
WHERE al.`source_type` = 9 AND al.`entryorguid` IN (216400, 391600);

-- --- 3. the one gameobject (3961927 Bonfire, +3.9M band) -------------------
INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT 3961927, 1, gs.`id`, gs.`link`, gs.`event_type`, gs.`event_phase_mask`, gs.`event_chance`, gs.`event_flags`,
       gs.`event_param1`, gs.`event_param2`, gs.`event_param3`, gs.`event_param4`, 0, 0,
       gs.`action_type`, gs.`action_param1`, gs.`action_param2`, gs.`action_param3`,
       gs.`action_param4`, gs.`action_param5`, gs.`action_param6`,
       gs.`target_type`, gs.`target_param1`, gs.`target_param2`, gs.`target_param3`, 0,
       gs.`target_x`, gs.`target_y`, gs.`target_z`, gs.`target_o`, gs.`comment`
FROM cata_world.smart_scripts gs
WHERE gs.`source_type` = 1 AND gs.`entryorguid` = 61927;

-- Verify -- expect 0 entries left where the source has SmartAI and we do not:
--   SELECT COUNT(DISTINCT c.id) FROM `creature` c WHERE c.map = 750
--     AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
--                     WHERE s.entryorguid = c.id AND s.source_type = 0)
--     AND EXISTS (SELECT 1 FROM cata_world.smart_scripts cs WHERE cs.source_type = 0
--                 AND cs.entryorguid IN (CAST(c.id AS SIGNED)-3600000, CAST(c.id AS SIGNED)-3700000));
-- And that no imported row casts a spell we lack (0 expected after 192_):
--   SELECT COUNT(*) FROM `smart_scripts` s WHERE s.action_type = 11
--     AND s.entryorguid IN (370216400, 360391600)
--     AND s.action_param1 NOT IN (SELECT ID FROM `spell_dbc`);
