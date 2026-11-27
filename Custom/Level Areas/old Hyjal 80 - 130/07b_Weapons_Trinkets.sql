-- Hyjal Frontier - Weapons, Shields, Relics, Trinkets and Tabard (levels 80-125)
-- Weapon entries 400824-400883 (15 archetypes x 4 tiers)
-- Trinket entries 400884-400907 (6 roles x 4 tiers)
-- Tabard entry 400908
-- Item.csv entries and Spell.collection_additions.csv (Well Fed spells 300580-300587)
-- also added for these items.

DELETE FROM `item_template` WHERE `entry` BETWEEN 400824 AND 400908;

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`dmg_min1`,`dmg_max1`,`dmg_type1`,`delay`,`stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,`stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,`armor`,`block`,`description`,`VerifiedBuild`)
VALUES
(400824,2,0,-1,'Emberscorch Axe',64480,3,0,0,1,54000,10800,13,-1,-1,300,80,0,1,1,494,918,0,2600,4,125,7,93,37,74,32,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400825,2,4,-1,'Moonward Mace',64514,3,0,0,1,54000,10800,21,-1,-1,300,80,0,1,1,258,479,0,1800,45,477,7,85,5,70,6,63,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400826,2,7,-1,'Cinderblade',64535,3,0,0,1,54000,10800,13,-1,-1,300,80,0,1,1,494,918,0,2600,3,125,7,93,32,74,31,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400827,2,15,-1,'Runeshard Dagger',64669,3,0,0,1,54000,10800,13,-1,-1,300,80,0,1,1,286,532,0,1800,45,477,7,85,5,70,36,63,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400828,2,6,-1,'Thornspire Polearm',64379,3,0,0,1,54000,10800,17,-1,-1,300,80,0,1,1,891,1654,0,3600,3,199,7,222,38,173,32,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400829,2,1,-1,'Doomcleave Axe',65153,3,0,0,1,54000,10800,17,-1,-1,300,80,0,1,1,891,1654,0,3600,4,199,7,222,32,173,37,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400830,2,10,-1,'Rootwood Staff',64342,3,0,0,1,54000,10800,17,-1,-1,300,80,0,1,1,332,617,0,2100,45,477,7,176,5,148,6,108,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400831,2,8,-1,'Emberthorn Greatsword',64557,3,0,0,1,54000,10800,17,-1,-1,300,80,0,1,1,891,1654,0,3600,4,199,7,222,32,173,37,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400832,2,2,-1,'Embervine Bow',65744,3,0,0,1,54000,10800,15,-1,-1,300,80,0,1,1,568,1055,0,2800,3,119,7,90,38,70,32,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400833,2,18,-1,'Starfire Wand',64371,3,0,0,1,54000,10800,26,-1,-1,300,80,0,1,1,651,1210,0,3000,45,119,7,90,5,70,36,1,0,0,'Level 80 Hyjal Frontier weapon.',0),
(400834,4,6,-1,'Rootplate Bulwark',65030,3,0,0,1,54000,10800,14,-1,-1,300,80,0,1,1,0,0,0,0,7,140,12,100,13,90,14,0,4800,180,'Level 80 Hyjal Frontier shield.',0),
(400835,4,0,-1,'Hyjal Codex',62936,3,0,0,1,54000,10800,23,-1,-1,300,80,0,1,1,0,0,0,0,45,682,7,176,5,136,36,1,0,0,'Level 80 Hyjal Frontier off-hand codex.',0),
(400836,4,9,-1,'Embercoil Totem',64629,3,0,0,1,54000,10800,28,-1,-1,300,80,0,1,1,0,0,0,0,45,80,7,59,3,1,0,0,0,0,'Level 80 Hyjal Frontier relic.',0),
(400837,4,8,-1,'Glyph of Ancient Growth',58200,3,0,0,1,54000,10800,28,-1,-1,300,80,0,1,1,0,0,0,0,45,80,7,59,3,1,0,0,0,0,'Level 80 Hyjal Frontier relic.',0),
(400838,4,7,-1,'Libram of the Frontier',54524,3,0,0,1,54000,10800,28,-1,-1,300,80,0,1,1,0,0,0,0,45,80,7,59,3,1,0,0,0,0,'Level 80 Hyjal Frontier relic.',0),
(400839,2,0,-1,'Skyfire Hacker',64480,3,0,0,1,59760,11952,13,-1,-1,332,95,0,1,1,547,1016,0,2600,4,138,7,103,37,82,32,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400840,2,4,-1,'Skyfire Lifemace',64514,3,0,0,1,59760,11952,21,-1,-1,332,95,0,1,1,285,530,0,1800,45,528,7,94,5,78,6,69,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400841,2,7,-1,'Skyfire Saber',64535,3,0,0,1,59760,11952,13,-1,-1,332,95,0,1,1,547,1016,0,2600,3,138,7,103,32,82,31,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400842,2,15,-1,'Skyfire Shiv',64669,3,0,0,1,59760,11952,13,-1,-1,332,95,0,1,1,317,589,0,1800,45,528,7,94,5,78,36,69,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400843,2,6,-1,'Skyfire Warspear',64379,3,0,0,1,59760,11952,17,-1,-1,332,95,0,1,1,986,1830,0,3600,3,220,7,245,38,191,32,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400844,2,1,-1,'Skyfire Cleaver',65153,3,0,0,1,59760,11952,17,-1,-1,332,95,0,1,1,986,1830,0,3600,4,220,7,245,32,191,37,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400845,2,10,-1,'Skyfire Staff',64342,3,0,0,1,59760,11952,17,-1,-1,332,95,0,1,1,368,683,0,2100,45,528,7,195,5,163,6,119,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400846,2,8,-1,'Skyfire Longblade',64557,3,0,0,1,59760,11952,17,-1,-1,332,95,0,1,1,986,1830,0,3600,4,220,7,245,32,191,37,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400847,2,2,-1,'Skyfire Shortbow',65744,3,0,0,1,59760,11952,15,-1,-1,332,95,0,1,1,629,1167,0,2800,3,132,7,99,38,78,32,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400848,2,18,-1,'Skyfire Wand',64371,3,0,0,1,59760,11952,26,-1,-1,332,95,0,1,1,721,1339,0,3000,45,132,7,99,5,78,36,1,0,0,'Level 95 Hyjal Frontier weapon.',0),
(400849,4,6,-1,'Skyfire Aegis',65030,3,0,0,1,59760,11952,14,-1,-1,332,95,0,1,1,0,0,0,0,7,210,12,150,13,135,14,0,7200,280,'Level 95 Hyjal Frontier shield.',0),
(400850,4,0,-1,'Skyfire Codex',62936,3,0,0,1,59760,11952,23,-1,-1,332,95,0,1,1,0,0,0,0,45,755,7,195,5,151,36,1,0,0,'Level 95 Hyjal Frontier off-hand codex.',0),
(400851,4,9,-1,'Skyfire Totem',64629,3,0,0,1,59760,11952,28,-1,-1,332,95,0,1,1,0,0,0,0,45,88,7,65,3,1,0,0,0,0,'Level 95 Hyjal Frontier relic.',0),
(400852,4,8,-1,'Skyfire Idol',58200,3,0,0,1,59760,11952,28,-1,-1,332,95,0,1,1,0,0,0,0,45,88,7,65,3,1,0,0,0,0,'Level 95 Hyjal Frontier relic.',0),
(400853,4,7,-1,'Skyfire Libram',54524,3,0,0,1,59760,11952,28,-1,-1,332,95,0,1,1,0,0,0,0,45,88,7,65,3,1,0,0,0,0,'Level 95 Hyjal Frontier relic.',0),
(400854,2,0,-1,'Summit Waraxe',64480,3,0,0,1,66960,13392,13,-1,-1,372,110,0,1,1,613,1138,0,2600,4,155,7,116,37,92,32,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400855,2,4,-1,'Summit Healermace',64514,3,0,0,1,66960,13392,21,-1,-1,372,110,0,1,1,320,594,0,1800,45,592,7,106,5,87,6,78,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400856,2,7,-1,'Summit Saber',64535,3,0,0,1,66960,13392,13,-1,-1,372,110,0,1,1,613,1138,0,2600,3,155,7,116,32,92,31,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400857,2,15,-1,'Summit Fang',64669,3,0,0,1,66960,13392,13,-1,-1,372,110,0,1,1,355,659,0,1800,45,592,7,106,5,87,36,78,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400858,2,6,-1,'Summit Spear',64379,3,0,0,1,66960,13392,17,-1,-1,372,110,0,1,1,1104,2051,0,3600,3,247,7,275,38,214,32,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400859,2,1,-1,'Summit Greataxe',65153,3,0,0,1,66960,13392,17,-1,-1,372,110,0,1,1,1104,2051,0,3600,4,247,7,275,32,214,37,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400860,2,10,-1,'Summit Staff',64342,3,0,0,1,66960,13392,17,-1,-1,372,110,0,1,1,412,766,0,2100,45,592,7,218,5,183,6,134,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400861,2,8,-1,'Summit Greatsword',64557,3,0,0,1,66960,13392,17,-1,-1,372,110,0,1,1,1104,2051,0,3600,4,247,7,275,32,214,37,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400862,2,2,-1,'Summit Longbow',65744,3,0,0,1,66960,13392,15,-1,-1,372,110,0,1,1,704,1308,0,2800,3,148,7,111,38,87,32,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400863,2,18,-1,'Summit Wand',64371,3,0,0,1,66960,13392,26,-1,-1,372,110,0,1,1,808,1500,0,3000,45,148,7,111,5,87,36,1,0,0,'Level 110 Hyjal Frontier weapon.',0),
(400864,4,6,-1,'Summit Bulwark',65030,3,0,0,1,66960,13392,14,-1,-1,372,110,0,1,1,0,0,0,0,7,290,12,210,13,185,14,0,10000,400,'Level 110 Hyjal Frontier shield.',0),
(400865,4,0,-1,'Summit Grimoire',62936,3,0,0,1,66960,13392,23,-1,-1,372,110,0,1,1,0,0,0,0,45,845,7,218,5,169,36,1,0,0,'Level 110 Hyjal Frontier off-hand codex.',0),
(400866,4,9,-1,'Summit Totem',64629,3,0,0,1,66960,13392,28,-1,-1,372,110,0,1,1,0,0,0,0,45,99,7,73,3,1,0,0,0,0,'Level 110 Hyjal Frontier relic.',0),
(400867,4,8,-1,'Summit Idol',58200,3,0,0,1,66960,13392,28,-1,-1,372,110,0,1,1,0,0,0,0,45,99,7,73,3,1,0,0,0,0,'Level 110 Hyjal Frontier relic.',0),
(400868,4,7,-1,'Summit Libram',54524,3,0,0,1,66960,13392,28,-1,-1,372,110,0,1,1,0,0,0,0,45,99,7,73,3,1,0,0,0,0,'Level 110 Hyjal Frontier relic.',0),
(400869,2,0,-1,'Nordrassil Waraxe',64480,4,0,0,1,71640,14328,13,-1,-1,398,125,0,1,1,656,1218,0,2600,4,166,7,124,37,98,32,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400870,2,4,-1,'Nordrassil Lifemace',64514,4,0,0,1,71640,14328,21,-1,-1,398,125,0,1,1,342,635,0,1800,45,633,7,113,5,93,6,83,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400871,2,7,-1,'Nordrassil Blade',64535,4,0,0,1,71640,14328,13,-1,-1,398,125,0,1,1,656,1218,0,2600,3,166,7,124,32,98,31,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400872,2,15,-1,'Nordrassil Kris',64669,4,0,0,1,71640,14328,13,-1,-1,398,125,0,1,1,380,706,0,1800,45,633,7,113,5,93,36,83,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400873,2,6,-1,'Nordrassil Warspear',64379,4,0,0,1,71640,14328,17,-1,-1,398,125,0,1,1,1182,2194,0,3600,3,264,7,294,38,229,32,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400874,2,1,-1,'Nordrassil Greataxe',65153,4,0,0,1,71640,14328,17,-1,-1,398,125,0,1,1,1182,2194,0,3600,4,264,7,294,32,229,37,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400875,2,10,-1,'Nordrassil Staff',64342,4,0,0,1,71640,14328,17,-1,-1,398,125,0,1,1,441,819,0,2100,45,633,7,234,5,196,6,143,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400876,2,8,-1,'Nordrassil Greatsword',64557,4,0,0,1,71640,14328,17,-1,-1,398,125,0,1,1,1182,2194,0,3600,4,264,7,294,32,229,37,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400877,2,2,-1,'Nordrassil Warbow',65744,4,0,0,1,71640,14328,15,-1,-1,398,125,0,1,1,753,1399,0,2800,3,158,7,119,38,93,32,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400878,2,18,-1,'Nordrassil Wand',64371,4,0,0,1,71640,14328,26,-1,-1,398,125,0,1,1,864,1605,0,3000,45,158,7,119,5,93,36,1,0,0,'Level 125 Hyjal Frontier weapon.',0),
(400879,4,6,-1,'Nordrassil Aegis',65030,4,0,0,1,71640,14328,14,-1,-1,398,125,0,1,1,0,0,0,0,7,370,12,265,13,230,14,0,13000,540,'Level 125 Hyjal Frontier shield.',0),
(400880,4,0,-1,'Nordrassil Tome',62936,4,0,0,1,71640,14328,23,-1,-1,398,125,0,1,1,0,0,0,0,45,905,7,234,5,181,36,1,0,0,'Level 125 Hyjal Frontier off-hand codex.',0),
(400881,4,9,-1,'Nordrassil Totem',64629,4,0,0,1,71640,14328,28,-1,-1,398,125,0,1,1,0,0,0,0,45,106,7,78,3,1,0,0,0,0,'Level 125 Hyjal Frontier relic.',0),
(400882,4,8,-1,'Nordrassil Idol',58200,4,0,0,1,71640,14328,28,-1,-1,398,125,0,1,1,0,0,0,0,45,106,7,78,3,1,0,0,0,0,'Level 125 Hyjal Frontier relic.',0),
(400883,4,7,-1,'Nordrassil Libram',54524,4,0,0,1,71640,14328,28,-1,-1,398,125,0,1,1,0,0,0,0,45,106,7,78,3,1,0,0,0,0,'Level 125 Hyjal Frontier relic.',0),
(400884,4,0,-1,'Embershard Prism',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,45,284,7,188,0,0,0,0,0,0,'Increases Spell Power and Stamina.',0),
(400885,4,0,-1,'Embervein Fragment',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,4,284,38,188,0,0,0,0,0,0,'Increases Strength and Attack Power.',0),
(400886,4,0,-1,'Ashen Talon',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,3,284,32,188,0,0,0,0,0,0,'Increases Agility and Critical Strike Rating.',0),
(400887,4,0,-1,'Thornweave Charm',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,45,284,6,188,0,0,0,0,0,0,'Increases Spell Power and Spirit.',0),
(400888,4,0,-1,'Rootplate Core',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,7,284,12,188,0,0,0,0,0,0,'Increases Stamina and Defense Rating.',0),
(400889,4,0,-1,'Emberwood Shard',62936,3,0,0,1,63000,12600,12,-1,-1,300,80,0,1,1,0,0,0,0,7,284,49,188,0,0,0,0,0,0,'Increases Stamina and Resilience Rating.',0),
(400890,4,0,-1,'Skyfire Lens',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,45,314,7,208,0,0,0,0,0,0,'Increases Spell Power and Stamina.',0),
(400891,4,0,-1,'Skyfire Signet',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,4,314,38,208,0,0,0,0,0,0,'Increases Strength and Attack Power.',0),
(400892,4,0,-1,'Felscorch Chip',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,3,314,32,208,0,0,0,0,0,0,'Increases Agility and Critical Strike Rating.',0),
(400893,4,0,-1,'Pyrestone Charm',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,45,314,6,208,0,0,0,0,0,0,'Increases Spell Power and Spirit.',0),
(400894,4,0,-1,'Ironbark Seal',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,7,314,12,208,0,0,0,0,0,0,'Increases Stamina and Defense Rating.',0),
(400895,4,0,-1,'Skyfire Fragment',62936,3,0,0,1,69720,13944,12,-1,-1,332,95,0,1,1,0,0,0,0,7,314,49,208,0,0,0,0,0,0,'Increases Stamina and Resilience Rating.',0),
(400896,4,0,-1,'Summit Starstone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,45,352,7,232,0,0,0,0,0,0,'Increases Spell Power and Stamina.',0),
(400897,4,0,-1,'Summit Warstone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,4,352,38,232,0,0,0,0,0,0,'Increases Strength and Attack Power.',0),
(400898,4,0,-1,'Summit Clawstone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,3,352,32,232,0,0,0,0,0,0,'Increases Agility and Critical Strike Rating.',0),
(400899,4,0,-1,'Summit Lifestone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,45,352,6,232,0,0,0,0,0,0,'Increases Spell Power and Spirit.',0),
(400900,4,0,-1,'Summit Bulwarkstone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,7,352,12,232,0,0,0,0,0,0,'Increases Stamina and Defense Rating.',0),
(400901,4,0,-1,'Summit Clearstone',62936,3,0,0,1,78120,15624,12,-1,-1,372,110,0,1,1,0,0,0,0,7,352,49,232,0,0,0,0,0,0,'Increases Stamina and Resilience Rating.',0),
(400902,4,0,-1,'Nordrassil Prism',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,45,377,7,249,0,0,0,0,0,0,'Increases Spell Power and Stamina.',0),
(400903,4,0,-1,'Nordrassil Warstone',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,4,377,38,249,0,0,0,0,0,0,'Increases Strength and Attack Power.',0),
(400904,4,0,-1,'Nordrassil Razorstone',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,3,377,32,249,0,0,0,0,0,0,'Increases Agility and Critical Strike Rating.',0),
(400905,4,0,-1,'Nordrassil Lifestone',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,45,377,6,249,0,0,0,0,0,0,'Increases Spell Power and Spirit.',0),
(400906,4,0,-1,'Nordrassil Aegis',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,7,377,12,249,0,0,0,0,0,0,'Increases Stamina and Defense Rating.',0),
(400907,4,0,-1,'Nordrassil Clarity',62936,4,0,0,1,83580,16716,12,-1,-1,398,125,0,1,1,0,0,0,0,7,377,49,249,0,0,0,0,0,0,'Increases Stamina and Resilience Rating.',0),
(400908,4,0,-1,'Hyjal Frontier Tabard',49625,3,0,0,1,100000,25000,19,-1,-1,1,1,0,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'Hyjal Frontier defender tabard.',0);

-- Wire tabard into both tabard vendors
DELETE FROM `npc_vendor` WHERE `entry` IN (830144,830157) AND `item`=400908;
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`) VALUES
(830144,1,400908,0,0,0,0),
(830157,1,400908,0,0,0,0);

-- Stat-food items: eating spell (spellid_1) + Well Fed buff direct on-use (spellid_2).
-- spellid_2 guarantees the buff is applied without relying on DBC trigger compilation.
UPDATE `item_template`
SET `spellid_1`=300584, `spelltrigger_1`=0, `spellcategory_1`=11, `spellcategorycooldown_1`=1000,
    `spellid_2`=300580, `spelltrigger_2`=0, `spellcharges_2`=-1, `spellcategory_2`=0, `spellcategorycooldown_2`=-1
WHERE `entry`=400802;

UPDATE `item_template`
SET `spellid_1`=300585, `spelltrigger_1`=0, `spellcategory_1`=11, `spellcategorycooldown_1`=1000,
    `spellid_2`=300581, `spelltrigger_2`=0, `spellcharges_2`=-1, `spellcategory_2`=0, `spellcategorycooldown_2`=-1
WHERE `entry`=400808;

UPDATE `item_template`
SET `spellid_1`=300586, `spelltrigger_1`=0, `spellcategory_1`=11, `spellcategorycooldown_1`=1000,
    `spellid_2`=300582, `spelltrigger_2`=0, `spellcharges_2`=-1, `spellcategory_2`=0, `spellcategorycooldown_2`=-1
WHERE `entry`=400814;

UPDATE `item_template`
SET `spellid_1`=300587, `spelltrigger_1`=0, `spellcategory_1`=11, `spellcategorycooldown_1`=1000,
    `spellid_2`=300583, `spelltrigger_2`=0, `spellcharges_2`=-1, `spellcategory_2`=0, `spellcategorycooldown_2`=-1
WHERE `entry`=400820;

-- Fix material and sheath fields (omitted from INSERT, defaulted to 0).
-- Weapons (class=2): material=1 (metal)
UPDATE `item_template` SET `material`=1
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=2;

-- Shields (class=4, subclass=6): material=6 (chain/mail exterior)
UPDATE `item_template` SET `material`=6
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=4 AND `subclass`=6;

-- Off-hands and relics (class=4, not shield, not trinket/tabard): material=1
UPDATE `item_template` SET `material`=1
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=4 AND `subclass` != 6;

-- Trinkets and tabard have no material
UPDATE `item_template` SET `material`=-1
WHERE `entry` BETWEEN 400884 AND 400908;

-- Sheath by weapon subclass
-- 1H axe(0), 1H mace(4), 1H sword(7), dagger(15) → hip
UPDATE `item_template` SET `sheath`=3
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=2 AND `subclass` IN (0,4,7,15);

-- Polearm(6), 2H axe(1), 2H sword(8) → back
UPDATE `item_template` SET `sheath`=1
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=2 AND `subclass` IN (1,6,8);

-- Staff(10) → side
UPDATE `item_template` SET `sheath`=2
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=2 AND `subclass`=10;

-- Bow(2), wand(18) → ranged back
UPDATE `item_template` SET `sheath`=5
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=2 AND `subclass` IN (2,18);

-- Shield → offhand slot
UPDATE `item_template` SET `sheath`=4
WHERE `entry` BETWEEN 400824 AND 400883 AND `class`=4 AND `subclass`=6;

-- stat_type 49 does not exist in WotLK 3.3.5; resilience = 35
UPDATE `item_template` SET `stat_type2`=35
WHERE `entry` IN (400889,400895,400901,400907);
