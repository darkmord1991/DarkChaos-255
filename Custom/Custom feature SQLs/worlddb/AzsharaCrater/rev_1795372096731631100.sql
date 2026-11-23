-- DarkChaos Azshara Crater (map 37), third pass. Re-runnable.
-- After the first two passes, crater bots of level 10-19 still died in 19.6% of their fights (stock maps: ~3%),
-- now mostly to level 23-25 monsters on the edge of the zone-3 camps that reach the level 8-18 quest spots, and on
-- the way to a zone-2 quest giver standing in level 36-46 land. A monster counts as reaching a spot when it is 8+
-- levels above the spot's quest MinLevel and within min(detection + gap, 45) + wander + 10 yd of a target spawn or
-- quest NPC of a QuestLevel <= 20 crater quest. New positions are on flat ground (server map tiles), out of the
-- water, at least 8 yd from other spawns and 5 yd beyond that reach.

-- 1) Thistlefur Pathfinders (300305): 7 of 11 wandered 30 yd within 26-58 yd of the level 18 Fouled Water
--    Spirits (300208, MinLevel 12). Wander 10 yd; five of them move 4-8 yd, two 24-32 yd deeper into the camp.
UPDATE `creature` SET `position_x` = 122.93, `position_y` = 623.83, `position_z` = 265.01, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000644;
UPDATE `creature` SET `position_x` = 133.61, `position_y` = 641.55, `position_z` = 261.2, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000645;
UPDATE `creature` SET `position_x` = 141.6, `position_y` = 645.3, `position_z` = 261.35, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000646;
UPDATE `creature` SET `position_x` = 163.2, `position_y` = 678.96, `position_z` = 262.86, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000647;
UPDATE `creature` SET `position_x` = 165.42, `position_y` = 693.36, `position_z` = 260.7, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000648;
UPDATE `creature` SET `position_x` = 167.23, `position_y` = 701.24, `position_z` = 260.11, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000649;
UPDATE `creature` SET `position_x` = 170.45, `position_y` = 685.94, `position_z` = 261.87, `wander_distance` = 10
    WHERE `id` = 3926 AND `guid` = 9000650;

-- 2) Felmusk Felsworn (no quest): 3 of 5 wandered within 46-64 yd of Pathfinder Gor'nash, where the zone-2 hand-off
--    "To the Eastern Slopes" (300206, MinLevel 16) ends. Wander 10 yd, nudged 4-8 yd.
UPDATE `creature` SET `position_x` = 160.27, `position_y` = 561.44, `position_z` = 270.78, `wander_distance` = 10
    WHERE `id` = 3762 AND `guid` = 16751262;
UPDATE `creature` SET `position_x` = 122.81, `position_y` = 553.71, `position_z` = 281.02, `wander_distance` = 10
    WHERE `id` = 3762 AND `guid` = 16751263;
UPDATE `creature` SET `position_x` = 109.84, `position_y` = 547.15, `position_z` = 283.6, `wander_distance` = 10
    WHERE `id` = 3762 AND `guid` = 16751264;

-- 3) Thistlefur Totemics (300302): 2 of 9 wandered within 60-66 yd of the Webwood Lurkers (300104, MinLevel 3).
UPDATE `creature` SET `position_x` = 232.62, `position_y` = 707.99, `position_z` = 261.57, `wander_distance` = 10
    WHERE `id` = 3922 AND `guid` = 9000687;
UPDATE `creature` SET `position_x` = 214.17, `position_y` = 736.2, `position_z` = 259.06, `wander_distance` = 10
    WHERE `id` = 3922 AND `guid` = 9000688;

-- 4) A lone level 25 Crag Stalker (no quest) wandered 30 yd around (2, 518), 30 yd from Arcanist Melia, the level
--    12-20 hub. It carries a quest-giver npcflag, so it is not even listed as hostile trash anywhere. Removed.
DELETE FROM `creature` WHERE `id` = 4126 AND `guid` = 3111202;

-- 5) Spirit of Kelvenar (300011; gives 300204/300205, ends 300203/300204/300205, all QuestLevel 15-18) stood at
--    (153, 269), inside level 36-46 land, so every level 12-18 player walked through it twice. "A Voice Among the
--    Ruins" sends the player to a ghost in the far ruins of Zin-Azshari's court, which are the zone-2 skeleton and
--    Dreadbone grounds: he now stands there, at (-112, 658), on flat ground 51 yd from the nearest level 17+
--    monster. The three quests' map boxes around his old spot (133..173, 249..289) move with him.
UPDATE `creature` SET `position_x` = -112, `position_y` = 658, `position_z` = 277.03
    WHERE `id` = 300011 AND `guid` = 9000570;
UPDATE `quest_poi_points` SET `X` = `X` - 265, `Y` = `Y` + 389
    WHERE `QuestID` IN (300203, 300204, 300205) AND `X` BETWEEN 133 AND 173 AND `Y` BETWEEN 249 AND 289;
