-- DarkChaos: fixes for four startup errors (Errors.log, 2026-11-12) caused by the 11-11 map 750/751 files
--
-- 1. Map 751 drop ladder (rev_1794428606734586200): the band references 752210-752218 carry Chance 100 for
--    greens and 25 for blues, 337_'s file text. LootGroup::Roll returns the first entry whose Chance is >= 100,
--    so each band dropped only its first item ("group 1 has total chance > 100% (5375)"). Set to the values the
--    live map 750 references 752200-752204 already hold: 1.86 per green, 0.465 per blue, 99.975% per group.
-- 2. SkyFire quest batch (rev_1794429413835942600): six DC clone NPCs got quests but lack
--    UNIT_NPC_FLAG_QUESTGIVER (2). Cata gives it to all six; the clones were copied from stock 3.3.5 rows. Without
--    the flag they offer nothing, so 14161, 14165, 14190, 14197, 14201, 14424, 13976 and 27467 could not be taken.
-- 3. Same batch: four imported cata quests point at follow-ups or a spell that were not imported. The core
--    already ignores them at load; this only removes the errors.
-- 4. Vorsha (rev_1794431585842896900): the naga 3703712/3703715 now use their map-750 kin's loot, which left
--    their old level-19 loot tables unused ("isn't creature entry and not referenced"). Deleted only while still
--    unused.
--
-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.

-- 1. map 751 band references: chances instead of weights
UPDATE `reference_loot_template` SET `Chance` = IF(`Chance` = 100, 1.86, 0.465)
WHERE `Entry` BETWEEN 752210 AND 752218 AND `GroupId` = 1 AND `Chance` IN (100, 25);

-- 2. quest givers / turn-ins without the quest giver flag
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2
WHERE `entry` IN (3616365, 3624739, 3635085, 3635087, 3635088, 3635091);

-- 3. dead pointers on imported quests (follow-ups 25308, 28460, 28840 and spell 91183 exist only in cata)
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 25296 AND `RewardNextQuest` = 25308;
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 28768 AND `RewardNextQuest` = 28460;
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 28839 AND `RewardNextQuest` = 28840;
UPDATE `quest_template_addon` SET `NextQuestID` = 0 WHERE `ID` = 28768 AND `NextQuestID` = 28460;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 28630 AND `RewardSpell` = 91183;

-- 4. the naga's old loot tables, only while no creature uses them
DELETE FROM `creature_loot_template`
WHERE `Entry` IN (3703712, 3703715)
  AND NOT EXISTS (SELECT 1 FROM `creature_template` WHERE `lootid` IN (3703712, 3703715));
