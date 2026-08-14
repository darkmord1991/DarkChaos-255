-- =====================================================================================
-- Emerald Sanctum -- achievement_criteria_data for the five boss-kill criteria
--
-- Fixes the boot-log errors:
--   "Table `achievement_criteria_data` does not have expected data for criteria
--    (Entry: 13513..13517 Type: 0) for achievement 60051..60055."
--
-- See TimbermawHold/17_achievement_criteria_data.sql for the full reasoning. Short version:
-- for KILL_CREATURE this is NOT cosmetic -- AchievementMgr.cpp:1001 reads
-- `if (!data || !data->Meets(...)) continue;`, so a missing row is treated as FAILED and the
-- achievement can never be earned.
--
-- THIS ONE MATTERED MOST HERE. 60052-60055 are the four Wakener kills, and they are the
-- children of the meta 60056 "Wakener of the Emerald Dream" -- the month-long goal that pays
-- out the Sylverian Dreamer mount and the title <the Dreamwalker> via dc_collection_rewards
-- (13_meta_reward.sql). With no criteria data the four children could never complete, so the
-- meta could never fire, so the mount and title were unreachable. The rotation would have
-- looked broken -- a player killing a different Wakener each week and seeing no progress --
-- when the actual fault was seven missing rows.
--
-- The meta's OWN criteria (13518-13521) need nothing: they are Type 8 COMPLETE_ACHIEVEMENT,
-- which falls to `default: continue` in the validator (AchievementMgr.cpp:2960) and requires
-- no db data. Verified in the deployed DBC: 13518 -> achievement 60056, Type 8, Asset 60052.
--
-- Criterion ids and assets read from the DEPLOYED Achievement_Criteria.dbc, not assumed:
--   13513 -> 60051, Asset 4030001 (Erennius)
--   13514 -> 60052, Asset 4030002 (Ysondre the Wakener)
--   13515 -> 60053, Asset 4030003 (Lethon the Wakener)
--   13516 -> 60054, Asset 4030004 (Emeriss the Wakener)
--   13517 -> 60055, Asset 4030005 (Taerar the Wakener)
-- Re-runnable.
-- =====================================================================================

DELETE FROM `achievement_criteria_data` WHERE `criteria_id` BETWEEN 13513 AND 13517;
INSERT INTO `achievement_criteria_data` (`criteria_id`, `type`, `value1`, `value2`, `ScriptName`) VALUES
    (13513, 0, 0, 0, ''),
    (13514, 0, 0, 0, ''),
    (13515, 0, 0, 0, ''),
    (13516, 0, 0, 0, ''),
    (13517, 0, 0, 0, '');

-- -------------------------------------------------------------------------------------
-- Report -- covers all three dungeons, since the achievement set was authored as one unit
-- -------------------------------------------------------------------------------------
SELECT 'Sanctum criteria data rows (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `achievement_criteria_data` WHERE `criteria_id` BETWEEN 13513 AND 13517
UNION ALL SELECT 'ALL seven kill criteria covered (want 7)', CAST(COUNT(*) AS CHAR)
    FROM `achievement_criteria_data` WHERE `criteria_id` BETWEEN 13511 AND 13517
UNION ALL SELECT 'rows with a restrictive type (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `achievement_criteria_data` WHERE `criteria_id` BETWEEN 13511 AND 13517 AND `type` <> 0
UNION ALL SELECT 'meta criteria wrongly given data (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `achievement_criteria_data` WHERE `criteria_id` BETWEEN 13518 AND 13521;
