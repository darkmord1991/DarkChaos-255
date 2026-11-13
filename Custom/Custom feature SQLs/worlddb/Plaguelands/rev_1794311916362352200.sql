-- DarkChaos: map 750 quest rewards - below-band gear, consumables, gold
--
-- GEAR: 25 gear rewards (green or better) sat more than 5 levels under their band. Each
-- now points at an EXISTING 309_ rescaled item (dc_map750_item_clone) of the same class, subclass, slot and
-- quality from the same band (choice slots of one quest never collapse onto the same item). No new items,
-- no client work. Grey/white gear is left as it is, like 309_.
--
-- SCOPE: the quests 234_ (750) / 71_ (751) scaled, the 46 from rev_1794308125336406000 and the 175 clones
-- from rev_1794309353491880400 (applied after both - this file sorts later). Every quest UPDATE re-checks at
-- apply time that no giver or turn-in of the quest spawns on a stock map (< 725, other than 37), so nothing
-- here can change a quest the old world uses. The swaps are kept in dc_quest_reward_swap (old_item ->
-- new_item) and dc_quest_reward_money, which double as the revert record.
--
-- GOLD: RewardMoney = band midpoint x 900 copper x the quest's XP-difficulty ratio from QuestXP.dbc
-- (0 / 0.1 / 0.25 / 0.5 / 0.75 / 1 / 1.25 / 1.5 / 2 for RewardXPDifficulty 0-8), i.e. a standard quest pays
-- about 7.7 gold at Darkshore, 10.8 at Hyjal and 13.9 in Eastern Plaguelands - stock WotLK pays ~7.4 gold at
-- 80. Never lowered, quests that cost money untouched.
-- CONSUMABLES: food / drink / healing / mana / healing+mana rewards become the DC band tier (245_):
-- Emberwood 80, Skyfire 95, Summit 110, Nordrassil 125 (the top tier, also used for 751). Quest tools,
-- elixirs, holiday items and care packages are not touched.

CREATE TABLE IF NOT EXISTS `dc_quest_reward_swap` (
    `map` SMALLINT UNSIGNED NOT NULL,
    `kind` CHAR(1) NOT NULL,
    `quest` INT UNSIGNED NOT NULL,
    `col` TINYINT UNSIGNED NOT NULL,
    `old_item` INT UNSIGNED NOT NULL,
    `new_item` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`quest`, `col`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_quest_reward_money` (
    `map` SMALLINT UNSIGNED NOT NULL,
    `quest` INT UNSIGNED NOT NULL,
    `money` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELETE FROM `dc_quest_reward_swap` WHERE `map` = 750;
INSERT INTO `dc_quest_reward_swap` (`map`, `kind`, `quest`, `col`, `old_item`, `new_item`) VALUES
(750, 'G', 201046, 1, 1116, 503181),
(750, 'G', 201046, 5, 5815, 500018),
(750, 'G', 201046, 6, 17046, 503292),
(750, 'G', 24449, 8, 53415, 503109),
(750, 'G', 25272, 5, 57376, 503231),
(750, 'G', 25272, 7, 57374, 503272),
(750, 'G', 25273, 5, 57379, 503231),
(750, 'G', 25273, 7, 57377, 503260),
(750, 'G', 25428, 5, 57321, 503216),
(750, 'G', 25428, 7, 57322, 503289),
(750, 'G', 25502, 5, 57349, 503208),
(750, 'G', 25502, 7, 57350, 503223),
(750, 'G', 25555, 5, 57299, 503272),
(750, 'G', 25664, 5, 57341, 503271),
(750, 'G', 25664, 7, 57339, 503372),
(750, 'G', 25807, 5, 57336, 503213),
(750, 'G', 25807, 7, 57335, 503289),
(750, 'G', 105063, 1, 12752, 500167),
(750, 'G', 105067, 1, 12756, 500592),
(750, 'G', 105068, 1, 12757, 501097),
(750, 'G', 105526, 5, 18535, 503136),
(750, 'G', 105526, 6, 18536, 503103),
(750, 'G', 106845, 5, 18400, 503113),
(750, 'G', 106845, 6, 18402, 503112),
(750, 'G', 108447, 1, 20600, 503113),
(750, 'C', 201025, 1, 4542, 400800),
(750, 'C', 201025, 2, 1205, 400801),
(750, 'C', 201054, 1, 1970, 400803),
(750, 'C', 28639, 1, 67270, 400806),
(750, 'C', 28782, 1, 67271, 400806);

DELETE FROM `dc_quest_reward_money` WHERE `map` = 750;
INSERT INTO `dc_quest_reward_money` (`map`, `quest`, `money`) VALUES
(750, 200216, 83700),
(750, 200247, 104620),
(750, 200824, 83700),
(750, 200990, 19120),
(750, 200991, 83700),
(750, 201010, 41850),
(750, 201016, 83700),
(750, 201017, 104620),
(750, 201020, 104620),
(750, 201021, 83700),
(750, 201022, 83700),
(750, 201023, 62780),
(750, 201024, 41850),
(750, 201025, 83700),
(750, 201026, 83700),
(750, 201027, 83700),
(750, 201028, 62780),
(750, 201029, 8370),
(750, 201030, 62780),
(750, 201031, 83700),
(750, 201032, 83700),
(750, 201033, 83700),
(750, 201034, 83700),
(750, 201035, 104620),
(750, 201045, 83700),
(750, 201046, 104620),
(750, 201054, 83700),
(750, 201055, 8370),
(750, 205126, 9860),
(750, 205127, 147820),
(750, 205713, 76500),
(750, 206441, 83700),
(750, 206442, 83700),
(750, 206462, 83700),
(750, 206482, 104620),
(750, 206503, 83700),
(750, 206544, 104620),
(750, 206571, 104620),
(750, 206621, 104620),
(750, 207863, 8370),
(750, 207864, 8370),
(750, 207865, 8370),
(750, 209516, 83700),
(750, 209517, 83700),
(750, 209518, 83700),
(750, 209519, 83700),
(750, 209522, 104620),
(750, 209533, 41850),
(750, 209534, 83700),
(750, 209536, 104620),
(750, 13504, 76500),
(750, 13505, 76500),
(750, 13507, 76500),
(750, 13508, 76500),
(750, 13509, 76500),
(750, 13510, 76500),
(750, 13511, 76500),
(750, 13512, 76500),
(750, 13513, 76500),
(750, 13514, 95620),
(750, 13515, 95620),
(750, 13518, 76500),
(750, 13519, 76500),
(750, 13520, 76500),
(750, 13521, 76500),
(750, 13522, 76500),
(750, 13523, 76500),
(750, 13525, 7650),
(750, 13526, 76500),
(750, 13527, 76500),
(750, 13528, 76500),
(750, 13529, 76500),
(750, 13537, 76500),
(750, 13542, 76500),
(750, 13543, 76500),
(750, 13544, 76500),
(750, 13545, 76500),
(750, 13546, 76500),
(750, 13547, 76500),
(750, 13554, 76500),
(750, 13558, 95620),
(750, 13560, 76500),
(750, 13561, 76500),
(750, 13562, 76500),
(750, 13564, 76500),
(750, 13565, 76500),
(750, 13566, 76500),
(750, 13569, 76500),
(750, 13572, 76500),
(750, 13573, 7650),
(750, 13575, 19120),
(750, 13576, 76500),
(750, 13577, 38250),
(750, 13578, 76500),
(750, 13579, 7650),
(750, 13580, 76500),
(750, 13581, 19120),
(750, 13582, 76500),
(750, 13583, 38250),
(750, 13584, 76500),
(750, 13585, 7650),
(750, 13586, 76500),
(750, 13588, 76500),
(750, 13589, 57380),
(750, 13590, 76500),
(750, 13595, 83700),
(750, 13596, 76500),
(750, 13598, 76500),
(750, 13599, 57380),
(750, 13601, 19120),
(750, 13605, 95620),
(750, 13623, 20920),
(750, 13624, 83700),
(750, 13626, 83700),
(750, 13628, 83700),
(750, 13630, 83700),
(750, 13632, 83700),
(750, 13640, 83700),
(750, 13642, 83700),
(750, 13644, 104620),
(750, 13645, 20920),
(750, 13646, 8370),
(750, 13651, 83700),
(750, 13683, 83700),
(750, 13730, 83700),
(750, 13751, 20920),
(750, 13796, 104620),
(750, 13797, 62780),
(750, 13831, 76500),
(750, 13844, 76500),
(750, 13848, 62780),
(750, 13873, 62780),
(750, 13874, 83700),
(750, 13875, 83700),
(750, 13877, 8370),
(750, 13880, 83700),
(750, 13881, 76500),
(750, 13882, 76500),
(750, 13883, 83700),
(750, 13884, 83700),
(750, 13885, 76500),
(750, 13886, 104620),
(750, 13890, 83700),
(750, 13891, 95620),
(750, 13892, 76500),
(750, 13893, 19120),
(750, 13896, 38250),
(750, 13898, 76500),
(750, 13900, 114750),
(750, 13901, 83700),
(750, 13902, 7650),
(750, 13907, 76500),
(750, 13909, 38250),
(750, 13910, 76500),
(750, 13911, 76500),
(750, 13912, 76500),
(750, 13913, 83700),
(750, 13918, 76500),
(750, 13920, 83700),
(750, 13922, 83700),
(750, 13923, 8370),
(750, 13925, 57380),
(750, 13928, 83700),
(750, 13935, 104620),
(750, 13936, 8370),
(750, 13940, 38250),
(750, 13942, 83700),
(750, 13943, 83700),
(750, 13944, 20920),
(750, 13947, 83700),
(750, 13948, 57380),
(750, 13953, 38250),
(750, 13958, 41850),
(750, 13962, 83700),
(750, 13974, 62780),
(750, 13977, 8370),
(750, 13979, 83700),
(750, 13980, 83700),
(750, 13983, 83700),
(750, 14130, 57380),
(750, 14131, 76500),
(750, 14132, 76500),
(750, 14155, 95620),
(750, 14226, 76500),
(750, 14230, 76500),
(750, 14249, 76500),
(750, 14250, 76500),
(750, 14258, 76500),
(750, 14261, 76500),
(750, 14262, 76500),
(750, 14263, 76500),
(750, 14267, 57380),
(750, 14270, 76500),
(750, 14271, 57380),
(750, 14295, 95620),
(750, 14297, 76500),
(750, 14299, 57380),
(750, 14308, 76500),
(750, 14322, 76500),
(750, 14323, 76500),
(750, 14324, 95620),
(750, 14340, 57380),
(750, 14345, 57380),
(750, 14370, 76500),
(750, 14371, 76500),
(750, 14377, 57380),
(750, 14383, 76500),
(750, 14385, 76500),
(750, 14388, 76500),
(750, 14407, 38250),
(750, 14424, 57380),
(750, 14428, 76500),
(750, 14429, 76500),
(750, 14430, 57380),
(750, 14462, 7650),
(750, 14464, 76500),
(750, 14468, 38250),
(750, 14469, 76500),
(750, 14470, 76500),
(750, 14471, 76500),
(750, 14472, 76500),
(750, 14478, 38250),
(750, 14479, 57380),
(750, 14480, 76500),
(750, 14484, 76500),
(750, 14485, 76500),
(750, 14486, 76500),
(750, 24430, 76500),
(750, 24433, 76500),
(750, 24434, 76500),
(750, 24435, 76500),
(750, 24439, 95620),
(750, 24449, 114750),
(750, 24452, 76500),
(750, 24453, 38250),
(750, 24455, 38250),
(750, 24458, 57380),
(750, 24463, 38250),
(750, 24467, 95620),
(750, 24497, 38250),
(750, 25223, 108450),
(750, 25224, 108450),
(750, 25233, 108450),
(750, 25234, 108450),
(750, 25255, 108450),
(750, 25268, 54220),
(750, 25269, 10840),
(750, 25270, 108450),
(750, 25271, 108450),
(750, 25272, 108450),
(750, 25273, 108450),
(750, 25274, 108450),
(750, 25276, 54220),
(750, 25277, 108450),
(750, 25278, 108450),
(750, 25291, 54220),
(750, 25294, 108450),
(750, 25297, 81340),
(750, 25299, 108450),
(750, 25300, 54220),
(750, 25301, 54220),
(750, 25309, 108450),
(750, 25311, 108450),
(750, 25316, 81340),
(750, 25317, 27110),
(750, 25319, 108450),
(750, 25320, 54220),
(750, 25321, 81340),
(750, 25323, 108450),
(750, 25324, 54220),
(750, 25325, 81340),
(750, 25330, 81340),
(750, 25352, 108450),
(750, 25353, 108450),
(750, 25354, 108450),
(750, 25355, 108450),
(750, 25370, 108450),
(750, 25372, 10840),
(750, 25381, 108450),
(750, 25382, 108450),
(750, 25385, 108450),
(750, 25392, 108450),
(750, 25404, 81340),
(750, 25408, 108450),
(750, 25424, 81340),
(750, 25428, 108450),
(750, 25430, 54220),
(750, 25460, 108450),
(750, 25462, 108450),
(750, 25472, 108450),
(750, 25490, 108450),
(750, 25491, 108450),
(750, 25492, 108450),
(750, 25493, 108450),
(750, 25494, 108450),
(750, 25499, 108450),
(750, 25502, 108450),
(750, 25507, 108450),
(750, 25509, 108450),
(750, 25510, 10840),
(750, 25514, 108450),
(750, 25519, 108450),
(750, 25523, 81340),
(750, 25525, 108450),
(750, 25531, 108450),
(750, 25544, 108450),
(750, 25548, 108450),
(750, 25549, 108450),
(750, 25551, 108450),
(750, 25552, 108450),
(750, 25554, 108450),
(750, 25560, 108450),
(750, 25574, 108450),
(750, 25575, 108450),
(750, 25576, 108450),
(750, 25577, 108450),
(750, 25578, 108450),
(750, 25584, 54220),
(750, 25597, 81340),
(750, 25599, 108450),
(750, 25601, 54220),
(750, 25607, 83700),
(750, 25611, 10840),
(750, 25612, 10840),
(750, 25617, 10840),
(750, 25618, 10840),
(750, 25621, 20920),
(750, 25622, 83700),
(750, 25623, 10840),
(750, 25624, 10840),
(750, 25630, 10840),
(750, 25644, 108450),
(750, 25653, 10840),
(750, 25655, 108450),
(750, 25656, 108450),
(750, 25664, 108450),
(750, 25731, 108450),
(750, 25740, 27110),
(750, 25746, 108450),
(750, 25758, 108450),
(750, 25761, 108450),
(750, 25763, 10840),
(750, 25764, 108450),
(750, 25776, 108450),
(750, 25795, 10840),
(750, 25807, 10840),
(750, 25810, 10840),
(750, 25830, 10840),
(750, 25832, 10840),
(750, 25842, 108450),
(750, 25843, 10840),
(750, 25881, 108450),
(750, 25886, 108450),
(750, 25899, 108450),
(750, 25901, 108450),
(750, 25904, 108450),
(750, 25906, 10840),
(750, 25910, 108450),
(750, 25915, 108450),
(750, 25923, 108450),
(750, 25928, 10840),
(750, 25940, 10840),
(750, 25985, 10840),
(750, 26335, 7650),
(750, 26372, 7650),
(750, 26383, 19120),
(750, 26385, 19120),
(750, 26446, 83700),
(750, 26463, 83700),
(750, 26464, 83700),
(750, 26472, 104620),
(750, 26474, 104620),
(750, 26890, 62780),
(750, 26894, 20920),
(750, 27874, 54220),
(750, 27997, 90900),
(750, 28000, 90900),
(750, 28044, 90900),
(750, 28049, 90900),
(750, 28100, 45450),
(750, 28102, 90900),
(750, 28113, 113620),
(750, 28116, 90900),
(750, 28119, 90900),
(750, 28121, 90900),
(750, 28126, 113620),
(750, 28128, 113620),
(750, 28148, 90900),
(750, 28150, 9090),
(750, 28152, 9090),
(750, 28155, 136350),
(750, 28190, 90900),
(750, 28207, 90900),
(750, 28208, 90900),
(750, 28213, 113620),
(750, 28214, 90900),
(750, 28217, 90900),
(750, 28218, 90900),
(750, 28256, 90900),
(750, 28257, 113620),
(750, 28261, 90900),
(750, 28264, 136350),
(750, 28288, 90900),
(750, 28305, 22720),
(750, 28306, 22720),
(750, 28333, 90900),
(750, 28334, 90900),
(750, 28335, 90900),
(750, 28336, 90900),
(750, 28337, 90900),
(750, 28338, 113620),
(750, 28339, 90900),
(750, 28340, 113620),
(750, 28341, 90900),
(750, 28342, 90900),
(750, 28357, 90900),
(750, 28358, 90900),
(750, 28359, 113620),
(750, 28360, 90900),
(750, 28361, 90900),
(750, 28362, 90900),
(750, 28364, 113620),
(750, 28366, 90900),
(750, 28370, 90900),
(750, 28372, 45450),
(750, 28373, 22720),
(750, 28374, 113620),
(750, 28380, 45450),
(750, 28381, 45450),
(750, 28382, 90900),
(750, 28383, 90900),
(750, 28384, 45450),
(750, 28385, 90900),
(750, 28386, 113620),
(750, 28387, 90900),
(750, 28388, 90900),
(750, 28389, 113620),
(750, 28392, 22720),
(750, 28472, 49280),
(750, 28490, 7650),
(750, 28536, 45450),
(750, 28537, 136350),
(750, 28542, 9090),
(750, 28543, 9090),
(750, 28609, 49280),
(750, 28610, 123190),
(750, 28614, 123190),
(750, 28615, 98550),
(750, 28618, 49280),
(750, 28624, 49280),
(750, 28625, 123190),
(750, 28626, 49280),
(750, 28627, 49280),
(750, 28628, 49280),
(750, 28632, 123190),
(750, 28639, 147820),
(750, 28640, 123190),
(750, 28641, 123190),
(750, 28674, 49280),
(750, 28676, 49280),
(750, 28701, 123190),
(750, 28703, 123190),
(750, 28706, 49280),
(750, 28707, 49280),
(750, 28710, 49280),
(750, 28718, 49280),
(750, 28719, 123190),
(750, 28742, 147820),
(750, 28782, 147820),
(750, 28829, 123190),
(750, 28830, 123190),
(750, 28831, 123190),
(750, 28847, 9860),
(750, 28848, 9090),
(750, 29066, 10840),
(750, 29101, 81340),
(750, 29122, 108450),
(750, 29123, 108450),
(750, 29125, 81340),
(750, 29126, 108450),
(750, 29127, 108450),
(750, 29145, 10840),
(750, 29147, 81340),
(750, 29148, 108450),
(750, 29149, 108450),
(750, 29161, 81340),
(750, 29162, 108450),
(750, 29163, 108450),
(750, 29164, 81340),
(750, 29165, 108450),
(750, 29166, 108450),
(750, 29177, 108450),
(750, 29182, 27110),
(750, 29195, 108450),
(750, 29196, 10840),
(750, 29197, 108450),
(750, 29198, 108450),
(750, 29200, 108450),
(750, 29215, 27110),
(750, 29280, 27110),
(750, 29282, 27110),
(750, 100965, 38250),
(750, 100966, 76500),
(750, 100969, 98550),
(750, 100977, 73910),
(750, 101143, 76500),
(750, 101185, 38250),
(750, 102078, 57380),
(750, 102098, 76500),
(750, 103783, 73910),
(750, 103909, 98550),
(750, 104084, 90900),
(750, 104101, 90900),
(750, 104102, 90900),
(750, 104103, 68180),
(750, 104421, 90900),
(750, 104441, 90900),
(750, 104442, 90900),
(750, 104809, 98550),
(750, 104842, 98550),
(750, 104861, 49280),
(750, 104863, 49280),
(750, 104864, 98550),
(750, 104906, 90900),
(750, 105054, 98550),
(750, 105055, 98550),
(750, 105056, 123190),
(750, 105057, 49280),
(750, 105082, 98550),
(750, 105086, 98550),
(750, 105087, 98550),
(750, 105121, 123190),
(750, 105124, 123190),
(750, 105128, 98550),
(750, 105155, 90900),
(750, 105156, 113620),
(750, 105157, 68180),
(750, 105161, 9860),
(750, 105165, 90900),
(750, 105204, 68180),
(750, 105242, 136350),
(750, 105244, 9860),
(750, 105249, 9090),
(750, 105252, 73910),
(750, 105305, 147820),
(750, 105306, 147820),
(750, 105307, 147820),
(750, 105385, 113620),
(750, 105526, 114750),
(750, 105527, 76500),
(750, 105882, 68180),
(750, 105883, 68180),
(750, 105884, 68180),
(750, 105885, 68180),
(750, 105886, 68180),
(750, 105888, 68180),
(750, 105889, 68180),
(750, 105890, 68180),
(750, 105891, 68180),
(750, 106031, 90900),
(750, 106032, 90900),
(750, 106603, 9860),
(750, 106604, 9860),
(750, 106606, 9860),
(750, 106845, 95620),
(750, 107602, 90900),
(750, 107603, 113620),
(750, 107634, 136350),
(750, 107635, 136350),
(750, 107636, 136350),
(750, 108419, 68180),
(750, 108420, 68180),
(750, 108421, 90900),
(750, 108422, 136350),
(750, 108460, 90900),
(750, 108461, 90900),
(750, 108462, 9090),
(750, 108464, 90900),
(750, 108465, 9090),
(750, 108481, 90900),
(750, 108735, 76500),
(750, 108736, 114750),
(750, 110965, 76500),
(750, 113074, 76500);

-- one statement per reward column; only rows still holding the old item change (idempotent)
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 1 AND `q`.`RewardItem1` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem1` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 2 AND `q`.`RewardItem2` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem2` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 3 AND `q`.`RewardItem3` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem3` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 4 AND `q`.`RewardItem4` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem4` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 5 AND `q`.`RewardChoiceItemID1` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID1` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 6 AND `q`.`RewardChoiceItemID2` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID2` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 7 AND `q`.`RewardChoiceItemID3` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID3` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 8 AND `q`.`RewardChoiceItemID4` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID4` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 9 AND `q`.`RewardChoiceItemID5` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID5` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 750 AND `w`.`col` = 10 AND `q`.`RewardChoiceItemID6` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID6` = `w`.`new_item`;

-- quest money: raised to the band formula, never lowered; quests that cost money are left alone
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_money` AS `r`
    ON `r`.`quest` = `q`.`ID` AND `r`.`map` = 750 AND `q`.`RewardMoney` >= 0
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardMoney` = IF(`q`.`RewardMoney` > `r`.`money`, `q`.`RewardMoney`, `r`.`money`);

-- below-band 750 gear with no same-slot 309_ item (left unchanged):
--   quest 25555 item 57297 Azralon's Twisted Rune
