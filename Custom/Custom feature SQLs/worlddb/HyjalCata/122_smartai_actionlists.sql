-- ---------------------------------------------------------------------------
-- 122  Hyjal round-15 -- the 55 MISSING SmartAI timed action lists
-- ---------------------------------------------------------------------------
-- THE BIG ONE.  `29_neltharion_templates.sql` clones smart_scripts with
--     WHERE source_type=0 AND entryorguid>0
-- which imports the creature scripts but silently drops every
-- source_type = 9 row -- the TIMED ACTION LISTS those scripts call.
--
-- Result: 83 SMART_ACTION_CALL_TIMED_ACTIONLIST / _RANDOM_* calls across the
-- map-750 + map-861 clone block point at action lists that do not exist, so
-- essentially every SCRIPTED SEQUENCE in the zone fires its trigger and then
-- does nothing.  Affected, among others:
--     3880600  Ragnaros intro                 4080300-02  Cenarius
--     4140600  Aessina                        3962700-02  Lo'Gosh / Goldrinn
--     5295500  Sira Moonwarden                5296500-06  Keeper Taldros
--     5335500-02 Into the Fire                5330000-01  Trained Fire Hawk
--     5253100-04 Fire Attacker Portal         5391100-03  (random-range set)
--     5331000  the whole Flamewaker Centurion/Molten Lord family (7 entries)
--     5425200  the 6 Elemental Bonds actors   7503200-01/7518200/7518800/7519100
-- AzerothCore never logs this: SmartAIMgr only complains about a missing list
-- when a script actually TRIES to enter it at runtime, so it stayed invisible
-- through 14 audit rounds.
--
-- 54 of the 55 lists (281 rows) come from nelt_world; 1093600 belongs to the
-- Plaguelands side of the same clone block and 2919600 exists only in
-- cata_world (9 rows), so both source DBs are used.
--
-- ID SPACE: action list ids are NOT offset -- nelt numbers them
-- (creature_entry * 100 + n), and the already-imported source_type=0 rows
-- reference those exact ids, so they are inserted verbatim.  Verified free:
-- none of the 55 ids currently exists as a source_type=9 row in acore_world
-- (which does hold 10,223 other rows in that id space, so this was checked
-- rather than assumed).
--
-- Their CONTENTS carry raw Cata ids exactly like the source_type=0 rows did,
-- so the same self-deriving correction 113_ uses is applied afterwards:
-- rewrite a reference to +3,600,000 ONLY when the raw id has no template of
-- its own but the clone does.  That protects the legitimate stock references
-- inside these lists (Joseph Redpath 10936, Ragnaros 40793 which DC imported
-- un-offset, Eject Passengers 50630, Ride Vehicle 46598, ...).
--
-- Idempotent (INSERT IGNORE + guarded UPDATEs).  Apply AFTER 29/30/31.
-- ---------------------------------------------------------------------------
SET @LISTS := '1093600,3880600,3943100,3962700,3962701,3962702,4043400,4080300,4080301,4080302,4085600,4140600,5217700,5253100,5253101,5253102,5253103,5253104,5259500,5259600,5259700,5259701,5268300,5295500,5296500,5296501,5296502,5296503,5296504,5296505,5296506,5301700,5301701,5308300,5313100,5323300,5324300,5329700,5330000,5330001,5331000,5335500,5335501,5335502,5391100,5391101,5391102,5391103,5425200,7503200,7503201,7518200,7518800,7519100';

-- --- 54 lists from nelt_world (old-TC 27-col shape -> acore) -----------------
INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts
WHERE source_type = 9 AND FIND_IN_SET(entryorguid, @LISTS);

-- --- 2919600 exists only in cata_world (TDB 434 shape) ----------------------
INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM cata_world.smart_scripts
WHERE source_type = 9 AND entryorguid = 2919600;

-- ---------------------------------------------------------------------------
-- Offset correction inside the freshly imported lists.
-- Same rule as 113_: only rewrite when the raw id resolves to nothing AND the
-- +3,600,000 clone exists, so stock references are left alone.
-- ---------------------------------------------------------------------------

-- SMART_ACTION_SUMMON_CREATURE (12) / SMART_ACTION_KILL_CREDIT (33)
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 9 AND FIND_IN_SET(s.`entryorguid`, @LISTS)
  AND s.`action_type` IN (12,33)
  AND s.`action_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`action_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`action_param1` + 3600000);

-- SMART_ACTION_SUMMON_GO (50)
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 9 AND FIND_IN_SET(s.`entryorguid`, @LISTS)
  AND s.`action_type` = 50
  AND s.`action_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `gameobject_template` a WHERE a.`entry` = s.`action_param1`)
  AND EXISTS (SELECT 1 FROM `gameobject_template` b WHERE b.`entry` = s.`action_param1` + 3600000);

-- creature-targeting target types (11 = CREATURE_DISTANCE, 19 = CLOSEST_CREATURE)
UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` = 9 AND FIND_IN_SET(s.`entryorguid`, @LISTS)
  AND s.`target_type` IN (11,19)
  AND s.`target_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`target_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`target_param1` + 3600000);

-- SMART_EVENT_SUMMONED_UNIT (17) inside a list
UPDATE `smart_scripts` s SET s.`event_param1` = s.`event_param1` + 3600000
WHERE s.`source_type` = 9 AND FIND_IN_SET(s.`entryorguid`, @LISTS)
  AND s.`event_type` = 17
  AND s.`event_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`event_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`event_param1` + 3600000);

-- ---------------------------------------------------------------------------
-- NOTE: the spells these lists cast are NOT offset (spell ids never are) --
-- they simply have to exist.  123_ downports the remaining Cata + Neltharion
-- custom ids they reference (97664, 97982/84, 98193, 98566, 98590, 98839,
-- 99977, 101529, 151099/100/111/203/204/276, ...).  Apply 123_ alongside this
-- file or those individual actions will be skipped at load.
-- ---------------------------------------------------------------------------
