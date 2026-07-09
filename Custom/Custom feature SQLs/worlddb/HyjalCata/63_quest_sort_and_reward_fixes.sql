-- =====================================================================
-- Mount Hyjal / Molten Front Downport  --  63  Quest data cleanup
-- ---------------------------------------------------------------------
-- A) QuestSortID (`ZoneOrSort` in the boot log) references Cata-only
--    QuestSort.dbc rows (-379 "Mount Hyjal", -381 "Molten Front") that do
--    not exist in this 3.3.5 client's QuestSort.dbc, so every quest below
--    logged "Quest N has `ZoneOrSort` = M (sort case) but quest sort with
--    this id does not exist." at boot. Zeroing falls back to the default
--    (ungrouped in the quest log) -- cosmetic only, no gameplay change.
--    A real fix needs a QuestSort.dbc client addition; track separately.
-- B) RewardSpell 87477 (quests 25491/25502/25520) and 87523 (quest 25807)
--    do not exist even in the source Cata 4.3.4 Spell.dbc dump (build
--    15601, k:/tmp/cata-dbc/Spell.dbc) so they can't be downported from
--    data. The server already no-ops the reward at runtime ("quest will
--    not have a spell reward") -- zeroing just matches that and silences
--    the boot warning; no behavior change.
-- =====================================================================

UPDATE `quest_template` SET `QuestSortID` = 0
    WHERE `ID` IN (29101,29122,29123,29125,29126,29127,29145,29147,29148,29149,29161,29162,29163,29164,
                    29165,29166,29182,29195,29196,29197,29198,29199,29200,29201,29202,29214,29215,29279,
                    29280,29281,29282,29283,29284,29326,29387,29388,29389,29439,29440);

UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` IN (25491,25502,25520) AND `RewardSpell` = 87477;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 25807 AND `RewardSpell` = 87523;

-- C) Pre-offset Magronos stub (entry 8297): 52_smartai_error_fixes.sql fix B
--    rekeyed smart_scripts.entryorguid 8297 -> 3608297 (the live spawn), but
--    the leftover creature_template row 8297 itself (never spawned, map=0)
--    still carries AIName='SmartAI' with zero smart_scripts rows, firing
--    "Creature entry (8297) has SmartAI enabled but no SmartAI entries in
--    the database." at every boot. Cosmetic only -- blank the AI name.
UPDATE `creature_template` SET `AIName` = '' WHERE `entry` = 8297;
