-- ---------------------------------------------------------------------------
-- 133  Hyjal round-16 -- the last un-offset references, now that their
--                        targets exist
-- ---------------------------------------------------------------------------
-- Every UPDATE keeps the house rule: rewrite to +3,600,000 ONLY when the raw id
-- resolves to nothing AND the clone exists.  That makes each one idempotent and
-- leaves genuine stock references untouched.
-- Apply AFTER 122_, 126_ and 132_ (which create the targets).

-- --- (1) SMART_ACTION_KILL_CREDIT (33) on source_type 0 ---------------------
--     SmartAIMgr: Entry 3653190/91/92 ... Action 33 uses non-existent Creature
--     entry 53190/53191/53192, skipped.
-- 113_ only corrected the single instance the log showed at the time; this is
-- the general sweep over the whole clone block, so it also covers 3653249 (the
-- one 127_ fixed by hand) and anything a future import re-introduces.
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` IN (0,9)
  AND (s.`entryorguid` BETWEEN 3600000 AND 3899999 OR s.`entryorguid` BETWEEN 1000000 AND 7600000)
  AND s.`action_type` IN (12,33)
  AND s.`action_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`action_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`action_param1` + 3600000);

-- --- (2) SMART_ACTION_SUMMON_GO (50) + GO target_param1 ---------------------
--     Entry 4085600 ... Action 50 uses non-existent GameObject entry 203065 (x8)
--     Entry 7518200 ... Action 9 uses non-existent GameObject entry 208427 as
--                       target_param1 (x2)
-- 122_'s sweep could not fix these: 3803065 did not exist yet (132_ imports it)
-- and target_param1 was only swept for creature target types, not GO ones.
--
-- CORRECTED (round 20): the GO entry-bearing target types are 13
-- (GAMEOBJECT_RANGE), 15 (GAMEOBJECT_DISTANCE) and 20 (CLOSEST_GAMEOBJECT).
-- **14 is GAMEOBJECT_GUID, whose target_param1 is a SPAWN GUID, not an entry**
-- -- offsetting it would corrupt the reference.  An earlier revision of this
-- file listed (14,15); verified after the fact that it damaged nothing (no
-- tt14 row's guid satisfied the "raw missing / clone present" guard), but the
-- list is corrected here so a re-run stays safe.  Creature side likewise gains
-- 9 (CREATURE_RANGE) and keeps excluding 10 (CREATURE_GUID).
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` IN (0,9)
  AND s.`action_type` = 50
  AND s.`action_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `gameobject_template` a WHERE a.`entry` = s.`action_param1`)
  AND EXISTS (SELECT 1 FROM `gameobject_template` b WHERE b.`entry` = s.`action_param1` + 3600000);

UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` IN (0,9)
  AND s.`target_type` IN (13,15,20)
  AND s.`target_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `gameobject_template` a WHERE a.`entry` = s.`target_param1`)
  AND EXISTS (SELECT 1 FROM `gameobject_template` b WHERE b.`entry` = s.`target_param1` + 3600000);

-- --- (3) creature target_param1 inside action lists -------------------------
--     Entry 4080301 SourceType 9 ... non-existent Creature entry 75034 / 75035
--     as target_param1
-- Same rule as 122_, re-run now that 132_ has imported 3675034 / 3675035.
UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` IN (0,9)
  AND s.`target_type` IN (9,11,19)
  AND s.`target_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`target_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`target_param1` + 3600000);

-- --- (4) quest objectives still on the raw Cata credit id -------------------
--     Quest 29211 has `RequiredNpcOrGo1` = 52950 but creature ... does not exist
--     (also 29243 / 29305 = 54230, 29249 = 53084, 29297 = 53251, 29299 = 53263)
-- Second wave of what 116_ fixed for map 750; these are the Molten Front chain.
UPDATE `quest_template` q SET q.`RequiredNpcOrGo1` = q.`RequiredNpcOrGo1` + 3600000
WHERE q.`ID` IN (29211,29243,29249,29297,29299,29305)
  AND q.`RequiredNpcOrGo1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = q.`RequiredNpcOrGo1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = q.`RequiredNpcOrGo1` + 3600000);

-- --- (5) SmartAI param validation -------------------------------------------
--     SmartAIMgr: entryorguid 3654025 / 3654070 source_type 0 id 2 / 4
--     action_type 44 has unused action_param2 with value 1, it must be 0.
-- SMART_ACTION_SET_SHEATH takes only action_param1; the extra value is leftover
-- from the 4.3.4 row shape and makes the core skip the whole row.
UPDATE `smart_scripts` SET `action_param2` = 0
WHERE `source_type` = 0 AND `entryorguid` IN (3654025,3654070)
  AND `action_type` = 44 AND `action_param2` <> 0;
