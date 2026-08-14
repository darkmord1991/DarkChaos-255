-- =====================================================================================
-- Crescent Grove -- achievement_criteria_data for the boss-kill criterion
--
-- Fixes the boot-log error:
--   "Table `achievement_criteria_data` does not have expected data for criteria
--    (Entry: 13512 Type: 0) for achievement 60050."
--
-- See TimbermawHold/17_achievement_criteria_data.sql for the full reasoning. Short version:
-- for KILL_CREATURE this is NOT a cosmetic warning -- AchievementMgr.cpp:1001 reads
-- `if (!data || !data->Meets(...)) continue;`, so a missing row is treated as FAILED and the
-- achievement can never be earned. Type 0 (ACHIEVEMENT_CRITERIA_DATA_TYPE_NONE) satisfies the
-- non-null requirement while imposing no extra condition, which is what "Defeat Master
-- Raxxieth, on any difficulty" wants.
--
-- Criterion id and asset read from the DEPLOYED Achievement_Criteria.dbc:
--   13512 -> achievement 60050, Type 0, Asset_Id 4020007 (Master Raxxieth).
-- Re-runnable.
-- =====================================================================================

DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 13512;
INSERT INTO `achievement_criteria_data` (`criteria_id`, `type`, `value1`, `value2`, `ScriptName`) VALUES
    (13512, 0, 0, 0, '');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'criteria data rows (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `achievement_criteria_data` WHERE `criteria_id` = 13512
UNION ALL SELECT 'rows with a restrictive type (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `achievement_criteria_data` WHERE `criteria_id` = 13512 AND `type` <> 0;
