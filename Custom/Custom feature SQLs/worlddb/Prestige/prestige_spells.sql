-- =====================================================================
-- PART 2: Prestige Title Rewards (Configured in CharTitles.dbc)
-- =====================================================================
-- NOTE: Titles in WoW 3.3.5a are stored in CharTitles.dbc
-- The following title IDs have been added to the DBC:
-- =====================================================================

-- Prestige Title IDs (added to CharTitles.dbc):
-- ID 178: "Prestige I %s"
-- ID 179: "Prestige II %s"
-- ID 180: "Prestige III %s"
-- ID 181: "Prestige IV %s"
-- ID 182: "Prestige V %s"
-- ID 183: "Prestige VI %s"
-- ID 184: "Prestige VII %s"
-- ID 185: "Prestige VIII %s"
-- ID 186: "Prestige IX %s"
-- ID 187: "Prestige X %s"

-- These titles are automatically granted by the prestige system
-- when a player reaches each prestige level.

-- =====================================================================
-- PART 3: Optional Prestige Achievements (requires achievement_dbc.sql)
-- =====================================================================
-- These achievements can be created to track prestige milestones
-- =====================================================================

-- DELETE FROM `achievement_dbc` WHERE `ID` BETWEEN 10000 AND 10010;
-- INSERT INTO `achievement_dbc` (`ID`, `faction`, `mapID`, `previous`, `name_lang_1`, `description_lang_1`, `category`, `points`, `orderInGroup`, `flags`, `iconID`, `rewardTitle_lang_1`, `minCriteria`) VALUES
-- (10000, -1, -1, 0, 'Prestige I', 'Reach Prestige Level 1', 1, 10, 0, 0, 1506, '', 1),
-- (10001, -1, -1, 10000, 'Prestige II', 'Reach Prestige Level 2', 1, 10, 1, 0, 1506, '', 1),
-- (10002, -1, -1, 10001, 'Prestige III', 'Reach Prestige Level 3', 1, 10, 2, 0, 1506, '', 1),
-- (10003, -1, -1, 10002, 'Prestige IV', 'Reach Prestige Level 4', 1, 10, 3, 0, 1506, '', 1),
-- (10004, -1, -1, 10003, 'Prestige V', 'Reach Prestige Level 5', 1, 10, 4, 0, 1506, '', 1),
-- (10005, -1, -1, 10004, 'Prestige VI', 'Reach Prestige Level 6', 1, 10, 5, 0, 1506, '', 1),
-- (10006, -1, -1, 10005, 'Prestige VII', 'Reach Prestige Level 7', 1, 10, 6, 0, 1506, '', 1),
-- (10007, -1, -1, 10006, 'Prestige VIII', 'Reach Prestige Level 8', 1, 10, 7, 0, 1506, '', 1),
-- (10008, -1, -1, 10007, 'Prestige IX', 'Reach Prestige Level 9', 1, 10, 8, 0, 1506, '', 1),
-- (10009, -1, -1, 10008, 'Prestige X', 'Reach Prestige Level 10', 1, 25, 9, 0, 1506, '', 1);

-- =====================================================================
-- End of prestige spells and titles
-- =====================================================================
