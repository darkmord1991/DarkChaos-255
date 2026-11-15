-- DarkChaos: put the turn-in marker of 750/751 quests on the NPC that takes the turn-in (2026-11-14)
--
-- 103 turn-in POIs (`quest_poi` ObjectiveIndex -1) on maps 750/751 sat more than 70 yd from every
-- spawn of the quest's ender, many of them hundreds of yards off: the NPCs were moved when the content was
-- transplanted onto 750/751, the markers were not. Players got a map marker in the wrong place, and
-- playerbots walk to the marker and only look for the ender within 80 yd of it
-- (QUEST_GIVER_SEARCH_DISTANCE), so they waited 5 minutes and gave up (`cannot_turn_in` in
-- playerbots_quest_stats.json; 25810 had 42 characters holding it complete and 1 turn-in).
-- Each marker becomes one point on the ender spawn nearest to the old marker. WorldMapAreaId is set to the
-- world map zone (WorldMapArea.csv) that holds that spawn, so the client still draws it.
-- 13899/13900 are handled by the Darkshore chain repair, not here. Fiona's caravan quests (27373, 27448,
-- 27522, 27527) keep their markers: the logs name the tower she should stand at, and those stops were not ported.
-- The 10 Felwood "Salve via ..." quests also get their log line fixed: the Alliance set (104108-104112) ends at
-- Arathandris Silversky and the Horde set (105882-105886) at Maybess Riverbreeze, as in Cata 4101/4102, but the
-- text (and the marker that followed it) named the other NPC.
--
-- quest   poi map  dist  old marker      new point       zone         ender
-- 13520   1   750    87  (7415, -250)    (7444, -332)    1259         3732972 Serendia Oakwhisper
-- 13599   0   750    75  (7420, -261)    (7444, -332)    1259         3732972 Serendia Oakwhisper
-- 25810   0   750   108  (4540, -2596)   (4605, -2509)   1216         3640578 Farden Talonshrike
-- 26385   0   750    77  (7414, -261)    (7447, -331)    1259         3732973 Dentaria Silverglade
-- 26937   1   751   476  (1851, -1323)   (1487, -1629)   1268         3644466 Lindsay Ravensun
-- 26938   2   751   489  (1876, -1333)   (1487, -1629)   1268         3644466 Lindsay Ravensun
-- 27086   1   751    70  (1568, -1640)   (1498, -1637)   1268         3644452 Koltira Deathweaver
-- 27087   0   751    77  (1557, -1662)   (1487, -1629)   1268         3644466 Lindsay Ravensun
-- 27096   0   751   730  (1381, 1041)    (1290, 316)     1270         4110181 Lady Sylvanas Windrunner
-- 27172   0   751   755  (1524, -1917)   (956, -1420)    1268         3645165 Thurman Grant
-- 27173   1   751   764  (1535, -1917)   (956, -1420)    1268         3645165 Thurman Grant
-- 27174   1   751   753  (1524, -1914)   (956, -1420)    1268         3645165 Thurman Grant
-- 27202   1   751   441  (1382, -1309)   (956, -1420)    1268         3645165 Thurman Grant
-- 27226   1   751   582  (493, 1528)     (1071, 1602)    1270         4144917 Warlord Torok
-- 27232   0   751   580  (497, 1503)     (1069, 1601)    1270         4144916 Admiral Hatchet
-- 27381   1   751   683  (1868, -3690)   (1693, -3030)   1217         3645429 Tarenar Sunstrike
-- 27405   0   751   542  (-1165, 1144)   (-928, 1632)    1274         4145312 Deathstalker Commander Belmont
-- 27455   0   751    88  (2281, -5346)   (2302, -5261)   1217         3645730 Gidwin Goldbraids (+1 more spawns)
-- 27488   1   751   533  (2571, -4800)   (2307, -5262)   1217         3645729 Tarenar Sunstrike
-- 27489   0   751  1264  (3155, -4325)   (2307, -5262)   1217         3645729 Tarenar Sunstrike
-- 27512   0   751    76  (-333, 948)     (-291, 1011)    1271->1270   4145752 Ambermill Dimensional Portal
-- 27524   0   751  2039  (3131, -3397)   (2307, -5262)   1217         3645729 Tarenar Sunstrike
-- 27525   2   751  2041  (3134, -3397)   (2307, -5262)   1217         3645729 Tarenar Sunstrike
-- 27551   0   751  2046  (3131, -3390)   (2307, -5262)   1217         3645729 Tarenar Sunstrike
-- 27995   0   750   117  (3987, -1319)   (3875, -1287)   1257         3711554 Grazle
-- 28102   1   750   650  (4336, -749)    (4009, -1311)   1257         3709116 Eridan Bluewind
-- 28113   2   750  1145  (5425, -419)    (4327, -742)    1257         3747341 Arcanist Delaris
-- 28126   0   750   870  (4739, -868)    (3986, -1303)   1257         3710922 Greta Mosshoof
-- 28128   5   750   860  (4731, -876)    (3990, -1311)   1257         3711019 Jessir Moonbow
-- 28150   1   750  1145  (5425, -419)    (4327, -742)    1257         3747341 Arcanist Delaris
-- 28152   0   750   865  (4733, -868)    (3986, -1303)   1257         3710922 Greta Mosshoof
-- 28362   0   750  3051  (3853, -1322)   (6853, -1874)   1257         3747556 Drizle
-- 28579   0   751    75  (2280, -5335)   (2278, -5260)   1217         3648704 Gek Nozzlerocket
-- 28580   0   751    75  (2271, -5335)   (2278, -5260)   1217         3648704 Gek Nozzlerocket
-- 28838   0   750   376  (6179, -4559)   (6110, -4189)   1256         3710929 Haleh
-- 28839   3   750   376  (6179, -4559)   (6110, -4189)   1256         3710929 Haleh
-- 28847   0   750   376  (6179, -4559)   (6110, -4189)   1256         3710929 Haleh
-- 29197   2   750   235  (4418, -2083)   (4653, -2079)   1216         3652838 Arch Druid Hamuul Runetotem
-- 29377   1   751    80  (1806, 147)     (1794, 226)     1268->1269   4115197 Darkcaller Yanka
-- 100028  1   750   422  (7747, -2626)   (7874, -2224)   1216->1258   3711799 Tajarri
-- 102523  0   750   537  (4233, -1133)   (3767, -1400)   1216->1257   4064886 Corrupted Songflower
-- 102878  0   750  2600  (6267, -2000)   (3867, -1000)   1216->1257   4071939 Corrupted Songflower
-- 103363  0   750  2814  (6900, -2033)   (4233, -1133)   1216->1257   4071942 Corrupted Songflower
-- 104108  0   750   449  (3949, -1047)   (3805, -1472)   1216->1257   3709528 Arathandris Silversky
-- 104109  0   750   449  (3949, -1047)   (3805, -1472)   1216->1257   3709528 Arathandris Silversky
-- 104110  0   750   449  (3949, -1047)   (3805, -1472)   1216->1257   3709528 Arathandris Silversky
-- 104111  0   750   449  (3949, -1047)   (3805, -1472)   1216->1257   3709528 Arathandris Silversky
-- 104112  0   750   449  (3949, -1047)   (3805, -1472)   1216->1257   3709528 Arathandris Silversky
-- 104114  0   750   495  (6733, -1567)   (6900, -2033)   1216->1257   4074595 Corrupted Songflower
-- 104221  0   750  1609  (4867, -600)    (6433, -967)    1216->1257   4074601 Corrupted Windblossom
-- 104222  0   750  1056  (5267, -333)    (6292, -589)    1216->1257   4074602 Corrupted Windblossom
-- 104403  0   750  1609  (6433, -967)    (4867, -600)    1216->1257   4074604 Corrupted Windblossom
-- 104448  0   750   787  (6600, -800)    (5967, -1267)   1216->1257   4073324 Corrupted Night Dragon
-- 104462  0   750  1777  (4874, -377)    (6600, -800)    1216->1257   4074608 Corrupted Night Dragon
-- 105882  0   750   450  (3805, -1473)   (3947, -1046)   1216->1257   3709529 Maybess Riverbreeze
-- 105883  0   750   450  (3805, -1473)   (3947, -1046)   1216->1257   3709529 Maybess Riverbreeze
-- 105884  0   750   450  (3805, -1473)   (3947, -1046)   1216->1257   3709529 Maybess Riverbreeze
-- 105885  0   750   450  (3805, -1473)   (3947, -1046)   1216->1257   3709529 Maybess Riverbreeze
-- 105886  0   750   450  (3805, -1473)   (3947, -1046)   1216->1257   3709529 Maybess Riverbreeze
-- 107632  0   750    86  (6206, -1173)   (6265, -1111)   1216->1257   3714525 Stoma the Ancient (+2 more spawns)
-- 107633  0   750   107  (6206, -1173)   (6227, -1068)   1216->1257   3714524 Vartrus the Ancient
-- 107636  4   750   107  (6206, -1173)   (6227, -1068)   1216->1257   3714524 Vartrus the Ancient
-- 200216  3   750  1531  (3345, 1014)    (3001, -478)    1261         3612757 Karang Amakkar
-- 200247  0   750  1393  (2311, -2555)   (2172, -1169)   1261         3612696 Senani Thunderheart
-- 200991  0   750   137  (3046, 529)     (3183, 532)     1261         3603891 Teronis' Corpse
-- 201010  1   750    78  (3190, 175)     (3265, 152)     1261         3703847 Orendil Broadleaf
-- 201016  1   750   834  (2089, -1172)   (1925, -354)    1261         3603885 Sentinel Velene Starstrike
-- 201017  1   750   834  (2089, -1172)   (1925, -354)    1261         3603885 Sentinel Velene Starstrike
-- 201022  1   750  1657  (2977, -3261)   (2415, -1702)   1261         3603880 Sentinel Melyria Frostshadow
-- 201024  1   750   610  (2894, -1386)   (2377, -1710)   1261         3603916 Shael'dryn
-- 201026  2   750   610  (2894, -1386)   (2377, -1710)   1261         3603916 Shael'dryn
-- 201027  0   750   610  (2894, -1386)   (2377, -1710)   1261         3603916 Shael'dryn
-- 201055  0   750   610  (2894, -1386)   (2377, -1710)   1261         3603916 Shael'dryn
-- 205126  0   750   156  (5041, -4848)   (5183, -4784)   1256         3710918 Lorax
-- 205127  0   750   156  (5041, -4848)   (5183, -4784)   1256         3710918 Lorax
-- 205407  0   751  1069  (1775, -726)    (972, -1431)    1268         3610840 Argent Officer Pureheart
-- 205408  0   751  1069  (1775, -726)    (972, -1431)    1268         3610840 Argent Officer Pureheart
-- 206146  0   751   139  (1571, -5605)   (1651, -5492)   1217         3611898 Crusader Lord Valdelmar
-- 206383  0   750  1393  (2311, -2555)   (2172, -1169)   1261         3612696 Senani Thunderheart
-- 206462  1   750  1597  (3333, 1028)    (3044, -542)    1261         3612721 Mitsuwa
-- 206503  1   750   313  (2055, -2400)   (2334, -2542)   1261         3612867 Kuray'bin
-- 206571  4   750   270  (2073, -2417)   (2305, -2554)   1261         3611820 Locke Okarr
-- 206621  0   750  1531  (3345, 1014)    (3001, -478)    1261         3612757 Karang Amakkar
-- 209033  2   751   623  (2300, -5342)   (1691, -5212)   1217         3616115 Commander Eligor Dawnbringer
-- 209045  2   751   623  (2300, -5342)   (1691, -5212)   1217         3616115 Commander Eligor Dawnbringer
-- 209121  0   751   615  (2295, -5340)   (1693, -5216)   1217         3616116 Archmage Angela Dosantos
-- 209122  0   751   615  (2295, -5340)   (1693, -5216)   1217         3616116 Archmage Angela Dosantos
-- 209123  0   751   615  (2295, -5340)   (1693, -5216)   1217         3616116 Archmage Angela Dosantos
-- 209128  0   751   615  (2295, -5340)   (1693, -5216)   1217         3616116 Archmage Angela Dosantos
-- 209129  0   751   615  (2295, -5340)   (1693, -5216)   1217         3616116 Archmage Angela Dosantos
-- 209131  0   751   623  (2301, -5352)   (1694, -5211)   1217         3616112 Korfax, Champion of the Light
-- 209132  0   751   623  (2301, -5352)   (1694, -5211)   1217         3616112 Korfax, Champion of the Light
-- 209516  3   750   746  (2995, -3286)   (2262, -3149)   1261         3617303 Vindicator Vedaar
-- 209517  2   750   758  (2994, -3261)   (2248, -3130)   1261         3617310 Gnarl
-- 209518  5   750   714  (2968, -3260)   (2265, -3138)   1261         3617287 Sentinel Luciel Starwhisper
-- 209522  2   750   746  (2995, -3286)   (2262, -3149)   1261         3617303 Vindicator Vedaar
-- 226979  0   751   477  (1863, -1335)   (1487, -1629)   1268         3644466 Lindsay Ravensun
-- 700800  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
-- 700801  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
-- 700802  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
-- 700803  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
-- 700804  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
-- 700805  0   750   333  (4833, -1732)   (5160, -1792)   1216         3999007 Emerald Sanctum Gatekeeper
--
-- The original rows are copied to dc_backup_20261114_turnin_poi{,_points} first; the NOT EXISTS guard keeps a
-- re-run from overwriting them with the moved points. Re-running the file is a no-op.
-- Apply to acore_world, then restart the worldserver.

-- 0. backups
CREATE TABLE IF NOT EXISTS `dc_backup_20261114_turnin_poi` LIKE `quest_poi`;
CREATE TABLE IF NOT EXISTS `dc_backup_20261114_turnin_poi_points` LIKE `quest_poi_points`;
REPLACE INTO `dc_backup_20261114_turnin_poi` SELECT * FROM `quest_poi` WHERE `ObjectiveIndex` = -1 AND `QuestID` IN (
    13520, 13599, 25810, 26385, 26937, 26938, 27086, 27087, 27096, 27172, 27173, 27174, 27202, 27226, 27232, 27381,
    27405, 27455, 27488, 27489, 27512, 27524, 27525, 27551, 27995, 28102, 28113, 28126, 28128, 28150, 28152, 28362,
    28579, 28580, 28838, 28839, 28847, 29197, 29377, 100028, 102523, 102878, 103363, 104108, 104109, 104110, 104111,
    104112, 104114, 104221, 104222, 104403, 104448, 104462, 105882, 105883, 105884, 105885, 105886, 107632, 107633,
    107636, 200216, 200247, 200991, 201010, 201016, 201017, 201022, 201024, 201026, 201027, 201055, 205126, 205127,
    205407, 205408, 206146, 206383, 206462, 206503, 206571, 206621, 209033, 209045, 209121, 209122, 209123, 209128,
    209129, 209131, 209132, 209516, 209517, 209518, 209522, 226979, 700800, 700801, 700802, 700803, 700804, 700805)
    AND NOT EXISTS (SELECT 1 FROM `dc_backup_20261114_turnin_poi` AS `b` WHERE `b`.`QuestID` = `quest_poi`.`QuestID`);
REPLACE INTO `dc_backup_20261114_turnin_poi_points` SELECT * FROM `quest_poi_points` WHERE `QuestID` IN (
    13520, 13599, 25810, 26385, 26937, 26938, 27086, 27087, 27096, 27172, 27173, 27174, 27202, 27226, 27232, 27381,
    27405, 27455, 27488, 27489, 27512, 27524, 27525, 27551, 27995, 28102, 28113, 28126, 28128, 28150, 28152, 28362,
    28579, 28580, 28838, 28839, 28847, 29197, 29377, 100028, 102523, 102878, 103363, 104108, 104109, 104110, 104111,
    104112, 104114, 104221, 104222, 104403, 104448, 104462, 105882, 105883, 105884, 105885, 105886, 107632, 107633,
    107636, 200216, 200247, 200991, 201010, 201016, 201017, 201022, 201024, 201026, 201027, 201055, 205126, 205127,
    205407, 205408, 206146, 206383, 206462, 206503, 206571, 206621, 209033, 209045, 209121, 209122, 209123, 209128,
    209129, 209131, 209132, 209516, 209517, 209518, 209522, 226979, 700800, 700801, 700802, 700803, 700804, 700805)
    AND NOT EXISTS (SELECT 1 FROM `dc_backup_20261114_turnin_poi_points` AS `b`
    WHERE `b`.`QuestID` = `quest_poi_points`.`QuestID`);

-- 1. world map zone of the markers that move into another zone
UPDATE `quest_poi` SET `WorldMapAreaId` = 1270, `Floor` = 0 WHERE `QuestID` = 27512 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1269, `Floor` = 0 WHERE `QuestID` = 29377 AND `id` = 1;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1258, `Floor` = 0 WHERE `QuestID` = 100028 AND `id` = 1;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 102523 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 102878 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 103363 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104108 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104109 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104110 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104111 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104112 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104114 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104221 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104222 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104403 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104448 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 104462 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 105882 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 105883 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 105884 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 105885 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 105886 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 107632 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 107633 AND `id` = 0;
UPDATE `quest_poi` SET `WorldMapAreaId` = 1257, `Floor` = 0 WHERE `QuestID` = 107636 AND `id` = 4;

-- 2. Felwood salve quests: the log names the NPC that really takes the turn-in
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Arathandris Silversky in Felwood.' WHERE `ID` = 104108;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Arathandris Silversky in Felwood.' WHERE `ID` = 104109;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Arathandris Silversky in Felwood.' WHERE `ID` = 104110;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Arathandris Silversky in Felwood.' WHERE `ID` = 104111;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Arathandris Silversky in Felwood.' WHERE `ID` = 104112;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Maybess Riverbreeze in Felwood.' WHERE `ID` = 105882;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Maybess Riverbreeze in Felwood.' WHERE `ID` = 105883;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Maybess Riverbreeze in Felwood.' WHERE `ID` = 105884;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Maybess Riverbreeze in Felwood.' WHERE `ID` = 105885;
UPDATE `quest_template` SET `QuestCompletionLog` = 'Return to Maybess Riverbreeze in Felwood.' WHERE `ID` = 105886;

-- 3. one point on the ender
DELETE FROM `quest_poi_points` WHERE `QuestID` = 13520 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(13520, 1, 0, 7444, -332, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 13599 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(13599, 0, 0, 7444, -332, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 25810 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(25810, 0, 0, 4605, -2509, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 26385 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(26385, 0, 0, 7447, -331, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 26937 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(26937, 1, 0, 1487, -1629, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 26938 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(26938, 2, 0, 1487, -1629, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27086 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27086, 1, 0, 1498, -1637, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27087 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27087, 0, 0, 1487, -1629, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27096 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27096, 0, 0, 1290, 316, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27172 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27172, 0, 0, 956, -1420, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27173 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27173, 1, 0, 956, -1420, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27174 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27174, 1, 0, 956, -1420, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27202 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27202, 1, 0, 956, -1420, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27226 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27226, 1, 0, 1071, 1602, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27232 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27232, 0, 0, 1069, 1601, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27381 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27381, 1, 0, 1693, -3030, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27405 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27405, 0, 0, -928, 1632, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27455 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27455, 0, 0, 2302, -5261, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27488 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27488, 1, 0, 2307, -5262, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27489 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27489, 0, 0, 2307, -5262, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27512 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27512, 0, 0, -291, 1011, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27524 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27524, 0, 0, 2307, -5262, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27525 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27525, 2, 0, 2307, -5262, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27551 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27551, 0, 0, 2307, -5262, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 27995 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27995, 0, 0, 3875, -1287, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28102 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28102, 1, 0, 4009, -1311, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28113 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28113, 2, 0, 4327, -742, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28126 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28126, 0, 0, 3986, -1303, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28128 AND `Idx1` = 5;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28128, 5, 0, 3990, -1311, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28150 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28150, 1, 0, 4327, -742, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28152 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28152, 0, 0, 3986, -1303, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28362 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28362, 0, 0, 6853, -1874, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28579 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28579, 0, 0, 2278, -5260, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28580 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28580, 0, 0, 2278, -5260, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28838 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28838, 0, 0, 6110, -4189, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28839 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28839, 3, 0, 6110, -4189, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 28847 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28847, 0, 0, 6110, -4189, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 29197 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(29197, 2, 0, 4653, -2079, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 29377 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(29377, 1, 0, 1794, 226, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 100028 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(100028, 1, 0, 7874, -2224, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 102523 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(102523, 0, 0, 3767, -1400, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 102878 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(102878, 0, 0, 3867, -1000, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 103363 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(103363, 0, 0, 4233, -1133, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104108 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104108, 0, 0, 3805, -1472, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104109 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104109, 0, 0, 3805, -1472, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104110 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104110, 0, 0, 3805, -1472, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104111 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104111, 0, 0, 3805, -1472, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104112 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104112, 0, 0, 3805, -1472, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104114 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104114, 0, 0, 6900, -2033, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104221 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104221, 0, 0, 6433, -967, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104222 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104222, 0, 0, 6292, -589, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104403 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104403, 0, 0, 4867, -600, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104448 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104448, 0, 0, 5967, -1267, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 104462 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(104462, 0, 0, 6600, -800, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 105882 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(105882, 0, 0, 3947, -1046, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 105883 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(105883, 0, 0, 3947, -1046, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 105884 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(105884, 0, 0, 3947, -1046, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 105885 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(105885, 0, 0, 3947, -1046, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 105886 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(105886, 0, 0, 3947, -1046, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 107632 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(107632, 0, 0, 6265, -1111, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 107633 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(107633, 0, 0, 6227, -1068, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 107636 AND `Idx1` = 4;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(107636, 4, 0, 6227, -1068, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 200216 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(200216, 3, 0, 3001, -478, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 200247 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(200247, 0, 0, 2172, -1169, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 200991 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(200991, 0, 0, 3183, 532, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201010 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201010, 1, 0, 3265, 152, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201016 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201016, 1, 0, 1925, -354, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201017 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201017, 1, 0, 1925, -354, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201022 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201022, 1, 0, 2415, -1702, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201024 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201024, 1, 0, 2377, -1710, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201026 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201026, 2, 0, 2377, -1710, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201027 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201027, 0, 0, 2377, -1710, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 201055 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(201055, 0, 0, 2377, -1710, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 205126 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(205126, 0, 0, 5183, -4784, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 205127 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(205127, 0, 0, 5183, -4784, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 205407 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(205407, 0, 0, 972, -1431, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 205408 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(205408, 0, 0, 972, -1431, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206146 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206146, 0, 0, 1651, -5492, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206383 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206383, 0, 0, 2172, -1169, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206462 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206462, 1, 0, 3044, -542, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206503 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206503, 1, 0, 2334, -2542, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206571 AND `Idx1` = 4;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206571, 4, 0, 2305, -2554, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206621 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(206621, 0, 0, 3001, -478, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209033 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209033, 2, 0, 1691, -5212, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209045 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209045, 2, 0, 1691, -5212, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209121 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209121, 0, 0, 1693, -5216, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209122 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209122, 0, 0, 1693, -5216, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209123 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209123, 0, 0, 1693, -5216, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209128 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209128, 0, 0, 1693, -5216, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209129 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209129, 0, 0, 1693, -5216, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209131 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209131, 0, 0, 1694, -5211, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209132 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209132, 0, 0, 1694, -5211, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209516 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209516, 3, 0, 2262, -3149, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209517 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209517, 2, 0, 2248, -3130, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209518 AND `Idx1` = 5;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209518, 5, 0, 2265, -3138, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 209522 AND `Idx1` = 2;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(209522, 2, 0, 2262, -3149, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 226979 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(226979, 0, 0, 1487, -1629, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700800 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700800, 0, 0, 5160, -1792, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700801 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700801, 0, 0, 5160, -1792, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700802 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700802, 0, 0, 5160, -1792, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700803 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700803, 0, 0, 5160, -1792, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700804 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700804, 0, 0, 5160, -1792, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 700805 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(700805, 0, 0, 5160, -1792, 0);

-- Verify (expect 103): every moved marker has exactly one point
-- SELECT COUNT(*) FROM (SELECT `QuestID`, `Idx1` FROM `quest_poi_points` WHERE `QuestID` IN (...)
--     GROUP BY `QuestID`, `Idx1` HAVING COUNT(*) = 1) AS `t`;
