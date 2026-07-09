-- =====================================================================
-- Deepholm Downport  --  38  Quest sort ID cleanup
-- ---------------------------------------------------------------------
-- Quest 29337 (Therazane, questender 42465) carries QuestSortID = -381
-- ("Molten Front" Cata-only QuestSort.dbc row), which doesn't exist in
-- this 3.3.5 client's QuestSort.dbc:
--   Quest 29337 has `ZoneOrSort` = -381 (sort case) but quest sort with
--   this id does not exist.
-- Zeroing falls back to the default (ungrouped in the quest log) --
-- cosmetic only, no gameplay change. A real fix needs a QuestSort.dbc
-- client addition; track separately.
-- =====================================================================

UPDATE `quest_template` SET `QuestSortID` = 0 WHERE `ID` = 29337 AND `QuestSortID` = -381;
