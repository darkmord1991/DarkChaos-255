-- ---------------------------------------------------------------------------
-- 113  Hyjal round-14 -- smart_scripts references that never got the +3,600,000
-- ---------------------------------------------------------------------------
-- The clone pipeline offset every `entryorguid` but left a tail of *referenced*
-- ids at their raw Cata values, so those rows point at nothing (or, worse, at
-- an unrelated stock WotLK creature that happens to own the same id).
--
-- AzerothCore only logs the subset where the raw id resolves to nothing at all:
--     SmartAIMgr: Entry 3640031 ... non-existent Creature entry 40000 ...
--     SmartAIMgr: Entry 3640803 ... non-existent Creature entry 40805 / 41632
--     SmartAIMgr: Entry 3641406 ... non-existent Creature entry 41459
--     SmartAIMgr: Entry 3645738 ... non-existent Creature entry 45738
--     SmartAIMgr: Entry 3647459 ... non-existent Creature entry 40719
--     SmartAIMgr: Entry 3675014 ... non-existent Creature entry 41581
--     SmartAIMgr: Entry 3675026/27 ... non-existent GameObject entry 203083/85
--     SmartAIMgr: Entry 3675158 ... non-existent Creature entry 40288
-- A full sweep of the 3,600,000-3,899,999 script block found 9 more of the same
-- shape that AC cannot flag (Keeper Taldros, Hyjal Wisp, Pyrelord, Windcaller
-- Nordrala, Aggra, Tyrus Blackhorn, Captain Saynna Stormrunner, Wondi's Bunny
-- portal targets) -- silently broken instead of loudly broken.
--
-- Every UPDATE below is guarded on the exact current value AND self-verifies
-- that the +3,600,000 target actually exists, so it is idempotent and cannot
-- create a new dangling reference.  Six of the ten "SmartAI enabled but no
-- SmartAI entries" boot warnings disappear as a side effect: those entries had
-- rows, but every row was skipped by the validator above.
--
-- NOT touched (verified correct as-is):
--   3640803 id 9 event_param1 = 40793 -- Ragnaros; DC imported him at the raw
--       Cata id, no 3640793 clone exists, so the reference already resolves.
--   3617238 / 3612596 / 3612617 / 3612636 / 3629480 / 3637888 / 3606547 --
--       these summon or target genuine stock WotLK creatures (Enraged Gryphon
--       9526, Haunting Vision 4472, Scarlet Torturer 4306, ...), not clones.
--   3652988 id 5 kill credit 52177 -- Child of Tortolla; quest 29101 is
--       realigned onto the clone by 116_ instead (see that file).
-- ---------------------------------------------------------------------------

-- --- event_param1 on SMART_EVENT_SUMMONED_UNIT (17) --------------------------
UPDATE `smart_scripts` s SET s.`event_param1` = s.`event_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3640803 AND s.`id` IN (7,8) AND s.`event_param1` IN (40805,41632)
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = s.`event_param1` + 3600000);

-- --- action_param1 on SMART_ACTION_SUMMON_CREATURE (12) ----------------------
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3675158 AND s.`id` = 0 AND s.`action_param1` = 40288
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = s.`action_param1` + 3600000);

-- --- action_param1 on SMART_ACTION_KILL_CREDIT (33) --------------------------
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3645738 AND s.`id` = 0 AND s.`action_param1` = 45738
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = s.`action_param1` + 3600000);

-- --- action_param1 on SMART_ACTION_SUMMON_GO (50) ----------------------------
-- Manipulator's Portal spell effects (Fire / Air / Earth) -- 3675028 was never
-- logged because its whole entry loads after the two that were, but it carries
-- the identical raw id.
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` IN (3675026,3675027,3675028) AND s.`id` = 0
  AND s.`action_param1` IN (203083,203085,203086)
  AND EXISTS (SELECT 1 FROM `gameobject_template` gt WHERE gt.`entry` = s.`action_param1` + 3600000);

-- --- target_param1 on creature-targeting target types (11, 19) ---------------
-- 11 = SMART_TARGET_CREATURE_DISTANCE, 19 = SMART_TARGET_CLOSEST_CREATURE.
-- Self-deriving: only rows whose raw id has no template of its own but whose
-- +3,600,000 clone does are rewritten, which is exactly the broken set and
-- leaves the legitimate stock-creature targets alone.
UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` = 0
  AND s.`entryorguid` BETWEEN 3600000 AND 3899999
  AND s.`target_type` IN (11,19)
  AND s.`target_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`target_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`target_param1` + 3600000);

-- NOTE: 3653355 (Windcaller Nordrala) id 5 targets creature 75183, which has no
-- template at all -- neither raw nor cloned.  It is nelt_world's "Wondi's Bunny
-- - Into the Fire - Player Check", a template 29_ never imported; 118_ clones
-- it and then applies the same +3,600,000 correction, so it is deliberately
-- absent here (this file must stay safe to run before 118_).
