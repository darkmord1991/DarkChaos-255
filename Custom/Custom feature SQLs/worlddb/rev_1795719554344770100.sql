-- Poison Water chain (Mull Thunderhorn, Mulgore): AC 2026_11_25_00 made 748/756/759 Tauren-only (AllowableRaces 32).
-- DarkChaos opens race-restricted Horde quests to every Horde race, custom races included: 2,205 quests use the DC
-- Horde mask 1237320626 and none keep a stock single-race mask (e.g. the Tauren starter quest The Hunt Begins, 747).
-- Re-runnable.
UPDATE `quest_template` SET `AllowableRaces` = 1237320626 WHERE `ID` IN (748, 756, 759);
