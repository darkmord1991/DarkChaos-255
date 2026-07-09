-- =====================================================================
-- Plaguelands Downport  --  48  Quest sort ID cleanup
-- ---------------------------------------------------------------------
-- 34 Plaguelands quests carry QuestSortID values (-101, -141, -264, -304,
-- -372, -373) that reference Cata-only QuestSort.dbc rows not present in
-- this 3.3.5 client's QuestSort.dbc, e.g.:
--   Quest 13100 has `ZoneOrSort` = -304 (sort case) but quest sort with
--   this id does not exist.
-- Zeroing falls back to the default (ungrouped in the quest log) --
-- cosmetic only, no gameplay change. A real fix needs a QuestSort.dbc
-- client addition; track separately.
-- =====================================================================

UPDATE `quest_template` SET `QuestSortID` = 0
    WHERE `ID` IN (8414,8415,8416,8418,12958,12959,12960,12961,12962,12963,13041,13100,13101,13102,
                    13103,13107,13112,13113,13114,13115,13116,13148,13165,13166,13188,13189,13272,
                    13830,13832,13833,13834,13836,14151,14160)
    AND `QuestSortID` < 0;
