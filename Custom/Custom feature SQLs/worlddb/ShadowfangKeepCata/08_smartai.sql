-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 8: SmartAI
--
-- 50 smart_scripts rows across 22 creature entries -- the trash behaviour. Without this
-- every non-boss creature in the instance stands still and swings, and each one logs
--     SmartScript: Entry N is using SmartAI but has no scripts assigned
-- at boot, because 03 carried AIName = 'SmartAI' across.
--
-- REQUIRES 03_templates.sql, and 01d_sfk_smartai_spells.sql (see "spells" below).
--
-- ---------------------------------------------------------------------------------
-- VALIDATION PASS -- this was deferred once for a reason that turned out not to apply
-- ---------------------------------------------------------------------------------
-- The stated blocker was that this fork's SmartAI diverges from upstream on the range
-- parameters (distance lives in event_param5/6 here). Checked against the actual rows:
--
--   rows with event_param5 <> 0 ............ 0
--
-- Not one of the 50 rows uses it. Every event is a timer (UPDATE_IC/UPDATE_OOC), a
-- lifecycle hook, or a data/link trigger, so the divergence cannot bite. The two acore
-- columns cata_world lacks (event_param6, target_param4) are likewise unused and fall to
-- their defaults.
--
-- Every opcode was then checked against src/server/game/AI/SmartScripts/SmartScriptMgr.h
-- and all exist here with the SAME numeric value:
--   event  0 UPDATE_IC · 1 UPDATE_OOC · 6 DEATH · 11 RESPAWN · 38 DATA_SET ·
--          54 JUST_SUMMONED · 59 TIMED_EVENT_TRIGGERED · 61 LINK · 62 GOSSIP_SELECT
--   action 5 PLAY_EMOTE · 11 CAST · 45 SET_DATA · 50 SUMMON_GO ·
--          67 CREATE_TIMED_EVENT · 73 TRIGGER_TIMED_EVENT · 87 CALL_RANDOM_TIMED_ACTIONLIST
--   target 0 NONE · 1 SELF · 2 VICTIM · 5 HOSTILE_RANDOM · 6 HOSTILE_RANDOM_NOT_TOP ·
--          7 ACTION_INVOKER · 19 CLOSEST_CREATURE
--
-- SPELLS: the 50 rows cast 40 distinct spells. 18 are stock 3.3.5 and already resolve;
-- 87081 came in with the original 56. The other 21 were absent from the server's
-- Spell.dbc and are supplied by 01d -- without it those casts silently fail.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. smart_scripts, source_type 0 (creature), entryorguid +5,000,000
--
-- TWO EXCLUSIONS, both deliberate:
--
--   * entry 3887 Baron Silverlaine. 06 binds the C++ boss_baron_silverlaine to its clone
--     and clears AIName, so its one SmartAI row ("Cast Veil of Shadow") would be dead
--     weight -- AC picks AIName first, and it is now empty. The Cataclysm encounter casts
--     Cursed Veil from the C++ script instead.
--     NOTE the classic-era trash entries 3873 Tormented Officer and 3877 Wailing Guardsman
--     are NOT excluded: the Cata adds are the separate entries 50615 / 50613, which is
--     what 06 binds, so those two keep their SmartAI and do not conflict.
--
--   * entry 23837 "ELM General Purpose Bunny". A generic world trigger that happens to be
--     spawned here. Its script is global content, not Shadowfang content -- it references
--     Alystros the Verdant Keeper (27249), "You Reap What You Sow", and Scuttle's Mop and
--     Bucket, none of which exist in this instance. Cloning it would produce a copy that
--     hunts for creatures that are not there. Its AIName is cleared below instead.
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 5000000 AND 5099999;
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
     `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
     `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`,
     `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT
     s.entryorguid + 5000000, s.source_type, s.id, s.link, s.event_type, s.event_phase_mask,
     s.event_chance, s.event_flags, s.event_param1, s.event_param2, s.event_param3,
     s.event_param4, s.event_param5, s.action_type, s.action_param1, s.action_param2,
     s.action_param3, s.action_param4, s.action_param5, s.action_param6,
     s.target_type, s.target_param1, s.target_param2, s.target_param3,
     s.target_x, s.target_y, s.target_z, s.target_o, s.comment
FROM `cata_world`.`smart_scripts` s
WHERE s.source_type = 0
  AND s.entryorguid IN (SELECT entry FROM `dc_sfk825_ct_set`)
  AND s.entryorguid NOT IN (3887, 23837);

-- -------------------------------------------------------------------------------------
-- 2. Timed action lists (source_type 9) referenced by SMART_ACTION_CALL_RANDOM_TIMED_ACTIONLIST.
--
-- The only entry using action 87 was the excluded ELM bunny, so there is nothing to bring
-- across. This statement is left in place, scoped and inert, so that if the exclusion list
-- above ever changes the action lists are not silently forgotten -- a call to a missing
-- action list is a silent no-op, not an error, which makes it easy to miss.
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` BETWEEN 5000000 AND 5099999;

-- -------------------------------------------------------------------------------------
-- 3. Clear AIName where no scripts came across, so the boot log stays clean.
--    Covers the ELM bunny and anything else that had AIName = 'SmartAI' upstream but ends
--    up with no rows here.
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` t
SET t.AIName = ''
WHERE t.entry BETWEEN 5000000 AND 5099999
  AND t.AIName = 'SmartAI'
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
                  WHERE s.source_type = 0 AND s.entryorguid = t.entry);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'smart_scripts rows (want 42 = 50 - 1 Silverlaine - 7 bunny)' AS `check`,
       CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'entries covered (want 20)', CAST(COUNT(DISTINCT entryorguid) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'SmartAI templates with no scripts (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` t WHERE t.entry BETWEEN 5000000 AND 5099999 AND t.AIName = 'SmartAI'
      AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.source_type = 0 AND s.entryorguid = t.entry)
UNION ALL SELECT 'rows that are both SmartAI and C++ (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5000000 AND 5099999
      AND `AIName` <> '' AND `ScriptName` <> ''
UNION ALL SELECT 'cast spells still unresolved (want 0)', CAST(COUNT(DISTINCT s.action_param1) AS CHAR)
    FROM `smart_scripts` s
    WHERE s.source_type = 0 AND s.entryorguid BETWEEN 5000000 AND 5099999
      AND s.action_type = 11 AND s.action_param1 >= 87000
      AND s.action_param1 NOT IN (SELECT ID FROM `spell_dbc`)
UNION ALL SELECT 'STOCK smart_scripts on 3887 (want 1, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3887
UNION ALL SELECT 'STOCK smart_scripts on 23837 (unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 23837;
