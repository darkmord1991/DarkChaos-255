-- 110_smartai_activation_751.sql -- dead SmartAI + one missing action list, DB step 49.
--
-- FROM A FULL C++ / SmartAI PORT AUDIT OF MAP 751. The headline is that the port is in
-- good shape -- this file closes the three real gaps it found.
--
-- WHAT THE AUDIT SHOWED (both offset bands, all 8 zones, against cata_world):
--
--   band 4.1M (1,121 entries, the extension import)
--     smart_scripts rows 412 | AIName='SmartAI' 412 | DEAD 0 | missing vs source 0
--     creature_text       99 | missing vs source   0
--     C++ ScriptName      25 | missing vs source   1
--
--   band 3.6M (359 entries, the older 751 content)
--     smart_scripts rows 162 | AIName='SmartAI' 134 | DEAD 28 | missing vs source 0
--     creature_text       35 | missing vs source   0
--     C++ ScriptName       7 | missing vs source   0
--
--   All 10 creature ScriptNames and both GO ScriptNames resolve in our core -- checked
--   for RegisterCreatureAI/RegisterGameObjectAI registration, not just a quoted literal,
--   because RegisterCreatureAI(x) stringifies the class name and leaves no string to grep.
--   DC/Plaguelands/zone_western_plaguelands_dc.cpp is compiled and loaded (the boot log
--   shows ">> Plaguelands Downport (map 751) / [OK] AddSC_dc_western_plaguelands").
--
-- ===========================================================================
-- 1. TWENTY-EIGHT CREATURES WHOSE SmartAI NEVER RUNS
-- ===========================================================================
--   They have smart_scripts rows but `AIName` is EMPTY, so FactorySelector never builds a
--   SmartAI and all 52 rows are inert. Every one is in the older 3.6M band; the new 4.1M
--   import got this right (0 dead). Same defect class map 750 fixed in its file 248.
--
--   NONE of the 28 carries a ScriptName (verified: 0), so setting AIName is unambiguous --
--   there is no C++ AI to lose. That matters, because FactorySelector::SelectAI resolves
--   ScriptName BEFORE SmartAI: on a template carrying both, the smart rows stay dead and
--   setting AIName would be a silent no-op.
--
--   3601839 3601849 3601885 3608537 3610819 3611078 3611194 3612425 3628488 3644318
--   3644326 3644328 3644432 3644433 3644447 3644473 3644474 3644481 3644482 3644486
--   3644551 3645155 3645156 3645166 3645444 3645867 3645868 3650089

UPDATE `creature_template` t
SET t.`AIName` = 'SmartAI'
WHERE t.`AIName` <> 'SmartAI'
  AND t.`ScriptName` = ''
  AND t.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751)
  AND EXISTS (SELECT 1 FROM `smart_scripts` s
               WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 0);

-- ===========================================================================
-- 2. EIGHT GAMEOBJECTS WITH THE SAME PROBLEM
-- ===========================================================================
--   10 smart rows, all inert for the same reason. None carries a ScriptName either.
--     4600375 Tirisfal Pumpkin        4601557 Lillith's Dinner Table
--     4602688 Keystone                4701852 Lever
--     4701853 Lever                   4713531 Cannon
--     4780437 Wickerman Ashes         4780666 Draconic for Dummies

UPDATE `gameobject_template` t
SET t.`AIName` = 'SmartAI'
WHERE t.`AIName` <> 'SmartAI'
  AND t.`ScriptName` = ''
  AND t.`entry` IN (SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 751)
  AND EXISTS (SELECT 1 FROM `smart_scripts` s
               WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 1);

-- ===========================================================================
-- 3. A TIMED ACTION LIST THAT WAS CALLED BUT NEVER IMPORTED
-- ===========================================================================
--   Creature 3610817 "Duggan Wildhammer" (Hinterlands) runs SMART_ACTION_CALL_TIMED_ACTIONLIST
--   against list 1081700, and that list does not exist here -- so the branch silently does
--   nothing. cata_world has its 9 rows; the import took the creature's script and left the
--   list it calls behind. It is the only one of the 48 action lists map 751 calls that is
--   missing; the other 47 resolve.
--
--   RE-HOMED TO 361081700 RATHER THAN IMPORTED AT 1081700, and this is the load-bearing
--   part. Action-list ids follow the entry*100 convention, so 1081700 belongs to STOCK
--   entry 10817 -- which exists here, is spawned 4 times, and has 13 smart_scripts rows of
--   its own. Writing a Cata action list into that id would hand stock Duggan a script he
--   never had. 3610817 * 100 = 361081700 keeps it inside our band, and the caller is
--   repointed to match. Nothing outside map 751 references 1081700 (verified: 1 caller,
--   ours).
--
--   Column lists are explicit: our smart_scripts has `event_param6` and `target_param4`,
--   cata_world has neither, so SELECT * would misalign every column after event_param5.

DELETE FROM `smart_scripts` WHERE `entryorguid` = 361081700 AND `source_type` = 9;

INSERT INTO `smart_scripts`
 (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
  `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
  `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`,
  `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`,
  `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`,
  `target_o`, `comment`)
SELECT 361081700, 9, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`, s.`event_chance`,
       s.`event_flags`, s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`,
       s.`event_param5`, 0, s.`action_type`, s.`action_param1`, s.`action_param2`,
       s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
       s.`target_type`, s.`target_param1`, s.`target_param2`, s.`target_param3`, 0,
       s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`,
       CONCAT('Duggan Wildhammer (map 751) - ', IFNULL(s.`comment`, ''))
FROM `cata_world`.`smart_scripts` s
WHERE s.`entryorguid` = 1081700 AND s.`source_type` = 9;

UPDATE `smart_scripts`
SET `action_param1` = 361081700
WHERE `source_type` = 0 AND `entryorguid` = 3610817
  AND `action_type` = 80 AND `action_param1` = 1081700;

-- ===========================================================================
-- CORRECTED -- see 111_. THE OOX ESCORT *IS* FIXABLE IN DATA.
-- ===========================================================================
--   This section previously said 4107806 "Homing Robot OOX-09/HL" needed a C++ script,
--   because cata drives it with `npc_oox09hl` and no such script exists in our core.
--   THAT WAS WRONG, and the reason is worth keeping: the comparison was against cata_world
--   when the oracle that matters is OUR OWN STOCK ENTRY. Stock 7806 here has
--       AIName = SmartAI | ScriptName = none | 7 smart rows | 30 waypoints | 5 text rows
--   AzerothCore rebuilt that escort as SmartAI, so cloning the stock layer makes it work
--   with no C++ at all. 111_ does exactly that.
--
--   (nelt spells it `npc_00x09hl` with ZEROS, cata `npc_oox09hl` with letter O -- which is
--   also why a grep for the cata spelling found nothing and looked conclusive.)

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'creature templates activated (want 28)' AS what, COUNT(*) AS n
  FROM `creature_template` t
  WHERE t.`AIName` = 'SmartAI' AND t.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751)
    AND t.`entry` IN (3601839,3601849,3601885,3608537,3610819,3611078,3611194,3612425,3628488,
                      3644318,3644326,3644328,3644432,3644433,3644447,3644473,3644474,3644481,
                      3644482,3644486,3644551,3645155,3645156,3645166,3645444,3645867,3645868,3650089)
UNION ALL SELECT 'creatures still dead (want 0)', COUNT(*)
  FROM `creature_template` t
  WHERE t.`AIName` <> 'SmartAI' AND t.`ScriptName` = ''
    AND t.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751)
    AND EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 0)
UNION ALL SELECT 'gameobjects still dead (want 0)', COUNT(*)
  FROM `gameobject_template` t
  WHERE t.`AIName` <> 'SmartAI' AND t.`ScriptName` = ''
    AND t.`entry` IN (SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 751)
    AND EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 1)
UNION ALL SELECT 'action list 361081700 imported (want 9)', COUNT(*)
  FROM `smart_scripts` WHERE `entryorguid` = 361081700 AND `source_type` = 9
UNION ALL SELECT 'caller repointed, still on 1081700 (want 0)', COUNT(*)
  FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3610817
    AND `action_type` = 80 AND `action_param1` = 1081700
UNION ALL SELECT 'stock 10817 untouched, still has its own 13 rows (want 13)', COUNT(*)
  FROM `smart_scripts` WHERE `entryorguid` = 10817 AND `source_type` = 0
UNION ALL SELECT 'nothing written into stock id 1081700 (want 0)', COUNT(*)
  FROM `smart_scripts` WHERE `entryorguid` = 1081700
UNION ALL SELECT 'map-751 action list calls still unresolved (want 0)', COUNT(*)
  FROM (SELECT DISTINCT s.`action_param1` AS al FROM `smart_scripts` s
        WHERE s.`source_type` = 0 AND s.`action_type` = 80
          AND s.`entryorguid` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751)) q
  WHERE NOT EXISTS (SELECT 1 FROM `smart_scripts` s2
                     WHERE s2.`source_type` = 9 AND s2.`entryorguid` = q.`al`);
