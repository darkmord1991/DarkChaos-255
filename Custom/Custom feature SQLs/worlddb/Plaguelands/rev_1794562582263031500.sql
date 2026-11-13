-- DarkChaos: three small map 751 quest fixes found with the 2026-11-13 bot quest stats
--
-- 1. Andorhal (Western Plaguelands): 27162 Scholomancer, 27163 Brute Strength and 27164 Araj the Summoner share
--    the positive ExclusiveGroup 27162 (as in the cata source), so only one of the three can ever be done and the
--    other two disappear. The Tyr's Hand quests had the same Cata leftover and were set to 0 on 11-11. With 0, any
--    one of them still opens 27165 Victory, For Now (each keeps NextQuestID 27165), and all three can be done.
--    Their givers 3644453/3644467 stand only on map 751.
-- 2. 200564 Costly Menace (kill 10 Foothill Stalkers): 6 completions for 33 bots holding it. The 22 stalkers
--    4102385 respawn every 300 s, too few kills an hour for that many bots. The Gilneas quests on 120 s finished
--    77-90%, so these go to 120 s like the other quest pools in rev_1794562272268504400.sql.
-- 3. 751018 The Blackhowl Pack (Gilneas City): 19 of its 22 Bloodhound targets stand among the city's 249 elite
--    Blackhowl, so it was an elite fight posing as a solo quest (bots 26 taken, 0 done). The owner made it a group
--    quest like its city neighbours 751020/751021: QuestInfoID 1, 3 players suggested, and their XP difficulty 8
--    and gold (239400). Bots leave group quests alone by themselves (TravelMgr checks SuggestedGroupNum).
--
-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.

UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0
WHERE `ID` IN (27162, 27163, 27164) AND `ExclusiveGroup` = 27162;

UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102385 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716840, 16716841, 16716902,
    16716927, 16717015, 16717019, 16717020, 16717022, 16717036, 16717043, 16717092, 16717093, 16717100, 16717199,
    16717213, 16717217, 16717309, 16717310, 16717311, 16717519, 16717533, 16717822);

UPDATE `quest_template` SET `QuestInfoID` = 1, `SuggestedGroupNum` = 3, `RewardXPDifficulty` = 8, `RewardMoney` = 239400
WHERE `ID` = 751018 AND `QuestInfoID` = 0 AND `RewardMoney` <= 239400;
