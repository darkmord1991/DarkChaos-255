-- =====================================================================================
-- Timbermaw Hold -- achievement_criteria_data for the boss-kill criterion
--
-- Fixes the boot-log error:
--   "Table `achievement_criteria_data` does not have expected data for criteria
--    (Entry: 13511 Type: 0) for achievement 60049."
--
-- THIS IS NOT COSMETIC. It reads like a warning, but for KILL_CREATURE the missing row makes
-- the achievement IMPOSSIBLE to earn:
--
--   AchievementMgr.cpp:990   case ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE:
--   AchievementMgr.cpp:1000      AchievementCriteriaDataSet const* data = GetCriteriaDataSet(...);
--   AchievementMgr.cpp:1001      if (!data || !data->Meets(GetPlayer(), unit))
--   AchievementMgr.cpp:1002          continue;          <-- no row => never progresses
--
-- Note the `!data ||`: absent data is treated as FAILED, not as "no extra condition". The
-- validator at AchievementMgr.cpp:2903 lists ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE under
-- "achievement requires db data" precisely because of this, which is why it complains at boot.
--
-- WHY TYPE 0 (ACHIEVEMENT_CRITERIA_DATA_TYPE_NONE). The kill criterion already names its
-- creature in the DBC (Asset_Id 4010007), so no further condition is wanted -- the achievement
-- is simply "Defeat Ursoc", on any difficulty. Type 0 returns true from both IsValid()
-- (AchievementMgr.cpp:105) and Meets() (AchievementMgr.cpp:309), so it satisfies the
-- non-null requirement while imposing nothing. 471 live rows already use it this way.
-- Type 12 MAP_DIFFICULTY would have been the choice if the achievement were Heroic-only.
--
-- Criterion id and asset were read from the DEPLOYED Achievement_Criteria.dbc, not assumed:
--   13511 -> achievement 60049, Type 0, Asset_Id 4010007 (Ursoc).
-- Re-runnable.
-- =====================================================================================

DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 13511;
INSERT INTO `achievement_criteria_data` (`criteria_id`, `type`, `value1`, `value2`, `ScriptName`) VALUES
    (13511, 0, 0, 0, '');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'criteria data rows (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `achievement_criteria_data` WHERE `criteria_id` = 13511
UNION ALL SELECT 'rows with a restrictive type (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `achievement_criteria_data` WHERE `criteria_id` = 13511 AND `type` <> 0;
