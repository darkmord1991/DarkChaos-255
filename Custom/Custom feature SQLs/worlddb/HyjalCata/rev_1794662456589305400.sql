-- DarkChaos: Eastern Plaguelands (map 751, zone 4924) - the Cata 4.3.4 quests that were never offered there
--
-- Why: EPL (band 152-160) gives about 65% of the XP its eight levels need, and its quests average 61k XP against
-- 81k for a normal quest. cata_world (TDB 4.3.4) has 24 EPL solo quests that 751 does not offer as raw, +100000 or
-- +200000. Twelve of them can work on 751 and are enabled here; at level 156 (Rate.XP.Quest 2) they are worth
-- about 995k XP together. The two related quests 27368/27372, offered already but impossible (no item
-- source in any reference DB; 61 characters hold 27372 incomplete), get their drops as well.
--
-- Enabled (giver -> turn-in, all DC-only 751 copies):
--   27369 Greasing the Wheel       Gidwin 3645428 -> Fiona 3645417. The Banshee's Bells GO 3805423 (28 spawns) had
--                                  Data1 = 0, so it dropped nothing: Data1 = entry + the cata loot row.
--   27389 Marauders of Darrowshire Chromie 3610667 -> Chromie. Works as is (Mystic Crystal 17271 + its C++ spell
--                                  script, Fetid Skulls from Scourge Champion 3608529).
--   27390 The Battle of Darrowshire Chromie -> Pamela 3610926. The Relic Bundle (18987) needs spell focus 944, whose
--                                  GO 177528 stood only on map 0: spawned on 751 at the same spot. The battle is the
--                                  stock SmartAI (absolute coordinates, no GUID targets), so it runs on 751 too; the
--                                  classic clone 205721, offered by the same Chromie, was blocked the same way.
--   27391 Hidden Treasures         Pamela -> GO Joseph's Chest 3777544 (key is the quest's start item).
--   27451-27454 Betina's chain     Betina Bigglezink 3611035 -> Betina. 27452: the Death Cultist garb never had a
--                                  drop in any DB; it now drops from the Corin's Crossing cultists. 27453/27454 used
--                                  Cata spells (85144 flasks, 85141 disguise) that the 3.3.5 client lacks: 27453 now
--                                  collects the agents as a drop from the lake elementals, 27454 becomes 'use the
--                                  Mereldar Plague Cauldron' (GO 3805485, type 2 -> goober for this quest).
--   27463 A Boyhood Dream          Gidwin 3645730 (Light's Hope) -> Lord Maxwell Tyrosus 3611034; follows 27455.
--   27464 Trial of the Crypt       Tyrosus -> Tyrosus: kill Lord Raymond George 3645707 in the crypt (the Argent
--                                  Scroll, Cata spell 85308, is dropped). Cata gave him two NPC companions, which
--                                  751 does not have, so he becomes a rare (5x HP) at 154 instead of an elite.
--   27465 The Noxious Glade        Tyrosus -> Tyrosus. Kill credit names Dread Weaver 3608528 (in every cluster;
--                                  bots only chase the named entry); Flayer, Death Singer and Golem credit it, as
--                                  Cata's three credited the Golem. The companion sentence is dropped from the log.
--   27612 Victory From Within      Commander Eligor 3616115 -> Eligor. Cata opened the portals by script (credit
--                                  bunnies 46102/46103, portals never spawned). Here two Argent Portal goobers
--                                  (3805876/3805877, copies of cata 205876/205877 with the 3.3.5 mage-portal model
--                                  4396) stand in the Hall of Arms and the Library Wing; using each gives its credit.
-- Each quest: QuestLevel -1, MinLevel 152, gold by the 11-10 formula (only raised), gear rewards -> band-152 ladder
-- (421xxx, same slot/type/quality; the statless wand of 27391 has no ladder twin and is dropped), Sweet Tea ->
-- Nordrassil Moonwater, cata offer/request texts where ours had none, POIs (small polygons over the spawn
-- clusters, none inside the crypt or the abbey, turn-in markers on the ender spawns, WorldMapArea 1217).
-- ExclusiveGroup 0 for 27369/27372, 27387-27389 and 27451/27452, as skyfire_world has them (a positive group makes
-- them one-of-N, the same fix the Tyr's Hand file made for 27612-27619).
--
-- Not enabled: 27384 (duplicates 205149 from the same Pamela, and its row has no objective), 27388 (no source for
-- the Extended Annals 13202 in the Cata chain), 27481 (item 61315 has no Item.dbc row), 28578 (needs a new Hero's
-- Call Board; Cata's model 10016 is not in the 3.3.5 client, and 27683 already leads both factions to Fiona),
-- 27555-27562 (Fiona's caravan collectibles: 0 XP, the caravan and its tower stops were not ported).
--
-- Mob levels: 751 had every target here at 158 (classic levels), out of reach for 152-153 players and bots (+4
-- rule). Cata has them at 40-42, which the zone band (40-48 -> 152-158) makes 152-154, the same mapping as the Tyr's
-- Hand relevel. 16 templates (all spawned only on 751) move there with 751's 332_ stat model (normal 2.5x / 4.5%,
-- rare 5x / 6% of a same-level player), their gear drop moves from the 156 ladder band (752218) to 152 (752217),
-- and their spawns respawn in 120 s. Not relevelled: the Terrorweb nerubians and plaguehounds of 27368/27372 (158).
-- Also fixed: rev_1794562112338710100 (Tyr's Hand) meant the 152 band but wrote 752216, which is the 148 band.
--
-- Revert: the first run saves the touched quest and creature columns in dc_epl_cata_port_backup_quest / _creature.
-- Before this file: GO 3805485 type 2, Data2 4, Data3 12043, Data1 0; GO 3805423 Data1 0; KillCredit1 0 on
-- 3608532/3608542/3608545; respawn 500 s (300 s for 3608545, 3645707 and the bells); Tyr's Hand refs 752216.
-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.

CREATE TABLE IF NOT EXISTS `dc_epl_cata_port_backup_quest` (
    `ID` INT UNSIGNED NOT NULL,
    `QuestLevel` INT NOT NULL, `MinLevel` INT NOT NULL, `RewardMoney` INT NOT NULL, `RewardSpell` INT NOT NULL,
    `StartItem` INT NOT NULL, `RequiredNpcOrGo1` INT NOT NULL, `RequiredNpcOrGo2` INT NOT NULL,
    `RequiredItemId1` INT NOT NULL, `RequiredItemId2` INT NOT NULL, `RequiredItemCount1` INT NOT NULL,
    `RequiredItemCount2` INT NOT NULL, `ItemDrop1` INT NOT NULL, `ItemDrop2` INT NOT NULL,
    `ItemDropQuantity1` INT NOT NULL, `ItemDropQuantity2` INT NOT NULL, `RequiredNpcOrGoCount1` INT NOT NULL,
    `RewardItem1` INT NOT NULL, `RewardItem2` INT NOT NULL, `RewardItem3` INT NOT NULL, `RewardItem4` INT NOT NULL,
    `RewardAmount1` INT NOT NULL, `RewardAmount2` INT NOT NULL, `RewardAmount3` INT NOT NULL,
    `RewardAmount4` INT NOT NULL, `RewardChoiceItemID1` INT NOT NULL, `RewardChoiceItemID2` INT NOT NULL,
    `RewardChoiceItemID3` INT NOT NULL, `RewardChoiceItemID4` INT NOT NULL, `RewardChoiceItemID5` INT NOT NULL,
    `RewardChoiceItemID6` INT NOT NULL, `RewardChoiceItemQuantity1` INT NOT NULL,
    `RewardChoiceItemQuantity2` INT NOT NULL, `RewardChoiceItemQuantity3` INT NOT NULL,
    `RewardChoiceItemQuantity4` INT NOT NULL, `RewardChoiceItemQuantity5` INT NOT NULL,
    `RewardChoiceItemQuantity6` INT NOT NULL,
    `LogDescription` TEXT, `QuestDescription` TEXT, `ObjectiveText1` TEXT, `AreaDescription` TEXT,
    `ExclusiveGroup` INT NOT NULL,
    `ProvidedItemCount` INT NOT NULL,
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- First run only: INSERT IGNORE keeps the originals on a re-run (the DELETE removes nothing; codestyle)
DELETE FROM `dc_epl_cata_port_backup_quest` WHERE `ID` = 0;
INSERT IGNORE INTO `dc_epl_cata_port_backup_quest` (`ID`, `QuestLevel`, `MinLevel`, `RewardMoney`, `RewardSpell`,
    `StartItem`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemCount1`,
    `RequiredItemCount2`, `ItemDrop1`, `ItemDrop2`, `ItemDropQuantity1`, `ItemDropQuantity2`, `RequiredNpcOrGoCount1`,
    `RewardItem1`, `RewardItem2`, `RewardItem3`, `RewardItem4`, `RewardAmount1`, `RewardAmount2`, `RewardAmount3`,
    `RewardAmount4`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`,
    `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`,
    `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`,
    `RewardChoiceItemQuantity6`, `LogDescription`, `QuestDescription`, `ObjectiveText1`, `AreaDescription`,
    `ExclusiveGroup`, `ProvidedItemCount`)
SELECT `t`.`ID`, `t`.`QuestLevel`, `t`.`MinLevel`, `t`.`RewardMoney`, `t`.`RewardSpell`, `t`.`StartItem`,
    `t`.`RequiredNpcOrGo1`, `t`.`RequiredNpcOrGo2`, `t`.`RequiredItemId1`, `t`.`RequiredItemId2`,
    `t`.`RequiredItemCount1`, `t`.`RequiredItemCount2`, `t`.`ItemDrop1`, `t`.`ItemDrop2`, `t`.`ItemDropQuantity1`,
    `t`.`ItemDropQuantity2`, `t`.`RequiredNpcOrGoCount1`, `t`.`RewardItem1`, `t`.`RewardItem2`, `t`.`RewardItem3`,
    `t`.`RewardItem4`, `t`.`RewardAmount1`, `t`.`RewardAmount2`, `t`.`RewardAmount3`, `t`.`RewardAmount4`,
    `t`.`RewardChoiceItemID1`, `t`.`RewardChoiceItemID2`, `t`.`RewardChoiceItemID3`, `t`.`RewardChoiceItemID4`,
    `t`.`RewardChoiceItemID5`, `t`.`RewardChoiceItemID6`, `t`.`RewardChoiceItemQuantity1`,
    `t`.`RewardChoiceItemQuantity2`, `t`.`RewardChoiceItemQuantity3`, `t`.`RewardChoiceItemQuantity4`,
    `t`.`RewardChoiceItemQuantity5`, `t`.`RewardChoiceItemQuantity6`, `t`.`LogDescription`, `t`.`QuestDescription`,
    `t`.`ObjectiveText1`, `t`.`AreaDescription`, `a`.`ExclusiveGroup`, `a`.`ProvidedItemCount`
FROM `quest_template` AS `t`
JOIN `quest_template_addon` AS `a` ON `a`.`ID` = `t`.`ID`
WHERE `t`.`ID` IN (27369, 27389, 27390, 27391, 27451, 27452, 27453, 27454, 27463, 27464, 27465, 27612,
    27372, 27387, 27388);

CREATE TABLE IF NOT EXISTS `dc_epl_cata_port_backup_creature` (
    `entry` INT UNSIGNED NOT NULL,
    `minlevel` TINYINT UNSIGNED NOT NULL,
    `maxlevel` TINYINT UNSIGNED NOT NULL,
    `rank` TINYINT UNSIGNED NOT NULL,
    `HealthModifier` FLOAT NOT NULL,
    `DamageModifier` FLOAT NOT NULL,
    `KillCredit1` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELETE FROM `dc_epl_cata_port_backup_creature` WHERE `entry` = 0;
INSERT IGNORE INTO `dc_epl_cata_port_backup_creature` (`entry`, `minlevel`, `maxlevel`, `rank`, `HealthModifier`,
    `DamageModifier`, `KillCredit1`)
SELECT `entry`, `minlevel`, `maxlevel`, `rank`, `HealthModifier`, `DamageModifier`, `KillCredit1`
FROM `creature_template`
WHERE `entry` IN (3608525, 3608526, 3608531, 3608538, 3608541, 3608543, 3608548, 3608551, 3608519, 3608520, 3608528,
    3608532, 3608542, 3608545, 3608529, 3645707);

-- 1. Quest targets to their Cata level on the 751 band, stats on 751's model (re-checked: spawned only on 751)
-- Scourge Warder (27451)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.778 WHERE `entry` = 3608525
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Dark Caster (27451/27452)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 1.1365,
    `DamageModifier` = 0.7811 WHERE `entry` = 3608526
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Gibbering Ghoul (27451)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608531
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Unseen Servant (27451)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608538
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Hate Shrieker (27451)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608541
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Stitched Horror (27451)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608543
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Vile Tutor (27452/27454)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.778 WHERE `entry` = 3608548
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Dark Summoner (27452/27454)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 1.1365,
    `DamageModifier` = 0.7811 WHERE `entry` = 3608551
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Blighted Surge (27453)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608519
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Plague Ravager (27453)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608520
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Dread Weaver (27465)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 1.1365,
    `DamageModifier` = 0.7811 WHERE `entry` = 3608528
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Diseased Flayer (27465)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608532
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Death Singer (27465)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608542
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Stitched Golem (27465)
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.793 WHERE `entry` = 3608545
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scourge Champion (27389)
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 153, `rank` = 0, `HealthModifier` = 0.9104,
    `DamageModifier` = 0.7919 WHERE `entry` = 3608529
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Lord Raymond George (27464)
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 154, `rank` = 4, `HealthModifier` = 1.8215,
    `DamageModifier` = 1.0386 WHERE `entry` = 3645707
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);

-- their map-751 gear drop: the 152 band instead of 156 (rare chance for Lord Raymond George)
UPDATE `creature_loot_template` SET `Reference` = 752217 WHERE `Entry` IN (3608525, 3608526, 3608531, 3608538,
    3608541, 3608543, 3608548, 3608551, 3608519, 3608520, 3608528, 3608532, 3608542, 3608545, 3608529)
  AND `Reference` = 752218;
UPDATE `creature_loot_template` SET `Reference` = 752217, `Chance` = 20
WHERE `Entry` = 3645707 AND `Reference` = 752218;

-- Tyr's Hand (rev_1794562112338710100): 752216 is the 148 band, the file's header asks for 152
UPDATE `creature_loot_template` SET `Reference` = 752217 WHERE `Entry` IN (3609447, 3609448, 3609449, 3609450,
    3609451, 3609452, 3611898, 3615162, 3610828)
  AND `Reference` = 752216;

-- 27465: the glade's Scourge credit Dread Weaver, as Cata's credited its Stitched Golem
UPDATE `creature_template` SET `KillCredit1` = 3608528 WHERE `entry` IN (3608532, 3608542, 3608545)
  AND `KillCredit1` = 0 AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);

-- quest-mob respawn 120 s (751 spawns of the templates above)
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608525 AND `guid` IN (13061963, 13061964, 13061965,
    13061966, 13061967, 13061968, 13061969, 13061970, 13061971, 13061972, 13061973, 13061974)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608526 AND `guid` IN (13061976, 13061978, 13061981,
    13061982, 13061985, 13061986, 13061987, 13061988)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608531 AND `guid` IN (13062115, 13062117, 13062118,
    13062119, 13062120, 13062121, 13062122, 13062125, 13062126)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608538 AND `guid` IN (13062235, 13062236, 13062237,
    13062238, 13062239)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608541 AND `guid` IN (13062279, 13062281, 13062283,
    13062284, 13062289, 13062291, 13062292, 13062293, 13062297, 13062298, 13062299, 13062300, 13062301, 13062305,
    13062306, 13062314, 13062315, 13062317, 13062320, 13062323, 13062324, 13062326)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608543 AND `guid` IN (13062367, 13062368, 13062369,
    13062370, 13062371, 13062372, 13062373, 13062374, 13062375, 13062376, 13062378, 13062379, 13062380, 13062381,
    13062382, 13062384, 13062385, 13062386, 13062387, 13062388, 13062389, 13062390, 13062391, 13062392, 13062394,
    13062395, 13062396, 13062397, 13062398, 13062399, 13062400, 13062401, 13062402, 13062403, 13062404, 13062406,
    13062407, 13062408, 13062409)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608548 AND `guid` IN (13062462, 13062464, 13062468,
    13062469, 13062475, 13062478, 13062479, 13062480, 13062482, 13062483, 13062484, 13062486, 13062487, 13062488)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608551 AND `guid` IN (13062507, 13062509, 13062510,
    13062511, 13062512, 13062513, 13062515, 13062517, 13062518, 13062519, 13062520, 13062521)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608519 AND `guid` IN (13061805, 13061806, 13061807,
    13061810, 13061812, 13061813, 13061814, 13061816, 13061819, 13061820)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608520 AND `guid` IN (13061821, 13061825, 13061828,
    13061830, 13061833, 13061835, 13061836, 13061837, 13061841)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608528 AND `guid` IN (13062008, 13062009, 13062010,
    13062011, 13062012, 13062013, 13062014, 13062015, 13062016, 13062017, 13062018, 13062019, 13062021, 13062022,
    13062023, 13062025, 13062027, 13062028, 13062029, 13062030)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608532 AND `guid` IN (13062128, 13062129, 13062130,
    13062131, 13062132, 13062133, 13062135, 13062136, 13062137, 13062138, 13062139, 13062140, 13062141, 13062142,
    13062144, 13062145, 13062146, 13062148, 13062149, 13062150, 13062151, 13062152, 13062155, 13062156, 13062157,
    13062158)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608542 AND `guid` IN (13062328, 13062329, 13062330,
    13062331, 13062332, 13062333, 13062335, 13062336, 13062337, 13062338, 13062339, 13062341, 13062342, 13062343,
    13062344, 13062345, 13062346, 13062347, 13062349, 13062351, 13062352, 13062356, 13062357, 13062358, 13062359,
    13062361, 13062362, 13062363, 13062364, 13062365, 13062366)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608545 AND `guid` IN (13062427, 13062428, 13062429,
    13062430, 13062431, 13062432, 13062433, 13062434)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3608529 AND `guid` IN (13062031, 13062033, 13062034,
    13062036, 13062037, 13062038, 13062039, 13062040, 13062041, 13062042, 13062043, 13062044, 13062045, 13062046,
    13062047, 13062050, 13062051, 13062052, 13062053, 13062054, 13062055, 13062056, 13062058, 13062059, 13062060)
  AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3645707 AND `guid` IN (13222453)
  AND `spawntimesecs` > 120;

-- 2. Gameobjects
-- Banshee's Bells (27369): loot id = entry, as cata (34661: 60984 100%, quest item); 120 s respawn
UPDATE `gameobject_template` SET `Data1` = 3805423 WHERE `entry` = 3805423 AND `type` = 3 AND `Data1` = 0
  AND `entry` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` <> 751);
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805423 AND `Item` = 60984;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(3805423, 60984, 0, 100, 1, 1, 0, 1, 1, 'DC EPL quest item 27369 (cata_world)');
UPDATE `gameobject` SET `spawntimesecs` = 120 WHERE `id` = 3805423 AND `guid` IN (12627966, 12627970, 12627976,
    12627978, 12627979, 12627981, 12627985, 12627986)
  AND `spawntimesecs` > 120;

-- Mereldar Plague Cauldron (27454): goober gated on the quest (Data1 = questId); using it gives the GO credit.
-- It was a type-2 object with no quest relation; Data2 (event 4) and Data3 (gossip 12043) are cleared.
UPDATE `gameobject_template` SET `type` = 10, `Data0` = 0, `Data1` = 27454, `Data2` = 0, `Data3` = 0,
    `Data4` = 0, `Data5` = 0, `Data6` = 0, `Data7` = 0, `Data8` = 0, `Data9` = 0, `Data10` = 0, `Data11` = 0,
    `Data12` = 0, `Data13` = 0, `Data14` = 0, `Data15` = 0, `Data16` = 0, `Data17` = 0, `Data18` = 0, `Data19` = 0,
    `Data20` = 0, `Data21` = 0, `Data22` = 0, `Data23` = 0
WHERE `entry` = 3805485 AND `entry` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` <> 751)
  AND `entry` NOT IN (SELECT `id` FROM `gameobject_queststarter`)
  AND `entry` NOT IN (SELECT `id` FROM `gameobject_questender`);

-- Argent Portals (27612): goobers gated on the quest, mage-portal model (cata display 9381 is Cata-only)
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`,
    `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`,
    `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`,
    `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
VALUES (3805876, 10, 4396, 'Argent Portal', '', '', '', 1, 0, 27612, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, '', '', 0);
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`,
    `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`,
    `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`,
    `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
VALUES (3805877, 10, 4396, 'Argent Portal', '', '', '', 1, 0, 27612, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, '', '', 0);

-- Spawns. 177528 is the stock focus object (type 8, no quest relation), placed as on map 0; the portals stand
-- on the ground floor of the abbey next to a Scarlet spawn, 3 yd toward the cata POI. Check them with .gps.
DELETE FROM `gameobject` WHERE `guid` IN (9032000, 9032001, 9032002) AND `id` IN (177528, 3805876, 3805877);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`,
    `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`,
    `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`)
SELECT 9032000, 177528, 751, 4924, 4924, 1, 1, 1439.7, -3701.6, 77.1, 0.0,
    0, 0, 0.0, 1.0, 180, 0, 1, '', 0, 'DC EPL 27390 focus' UNION ALL
SELECT 9032001, 3805876, 751, 4924, 4924, 1, 1, 1747.8, -5460.04, 82.39, 2.2,
    0, 0, 0.8912, 0.4536, 120, 100, 1, '', 0, 'DC EPL 27612 hall' UNION ALL
SELECT 9032002, 3805877, 751, 4924, 4924, 1, 1, 1797.49, -5425.35, 82.39, 3.6,
    0, 0, 0.9738, -0.2272, 120, 100, 1, '', 0, 'DC EPL 27612 library';

-- 3. Quest-item drops (QuestRequired: only while a quest needs them; Entry = the creature's lootid = entry)
--   27452 Death Cultist Headwear 61280 / Robes 61281: Dark Caster, Vile Tutor, Dark Summoner (Corin's Crossing)
--   27453 Active Liquid Plague Agent 61285: Blighted Surge, Plague Ravager (Lake Mereldar)
--   27368 Crypt Bile 60983: the Terrorweb Tunnel nerubians (Crypt Stalker/Walker/Horror/Slayer)
--   27372 Plaguehound Blood 60986: Plaguehound Runt, Plaguehound, Frenzied Plaguehound
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608526 AND `Item` = 61280 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608526 AND `Item` = 61281 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608548 AND `Item` = 61280 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608548 AND `Item` = 61281 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608551 AND `Item` = 61280 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608551 AND `Item` = 61281 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608519 AND `Item` = 61285 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608520 AND `Item` = 61285 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608555 AND `Item` = 60983 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608556 AND `Item` = 60983 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608557 AND `Item` = 60983 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608558 AND `Item` = 60983 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608596 AND `Item` = 60986 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608597 AND `Item` = 60986 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3608598 AND `Item` = 60986 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(3608526, 61280, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608526, 61281, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608548, 61280, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608548, 61281, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608551, 61280, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608551, 61281, 0, 35, 1, 1, 0, 1, 1, 'DC EPL quest item 27452'),
(3608519, 61285, 0, 80, 1, 1, 0, 1, 1, 'DC EPL quest item 27453'),
(3608520, 61285, 0, 80, 1, 1, 0, 1, 1, 'DC EPL quest item 27453'),
(3608555, 60983, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27368'),
(3608556, 60983, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27368'),
(3608557, 60983, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27368'),
(3608558, 60983, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27368'),
(3608596, 60986, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27372'),
(3608597, 60986, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27372'),
(3608598, 60986, 0, 60, 1, 1, 0, 1, 1, 'DC EPL quest item 27372');

-- 4. Givers and turn-ins (re-checked: the NPC/GO is spawned on 751 and on no stock map)
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3645428, 27369), (3610667, 27389), (3610667, 27390));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3610926, 27391), (3611035, 27451), (3611035, 27452));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3611035, 27453), (3611035, 27454), (3645730, 27463));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3611034, 27464), (3611034, 27465), (3616115, 27612));
INSERT INTO `creature_queststarter` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (
    SELECT 3645428 AS `id`, 27369 AS `quest` UNION ALL
    SELECT 3610667, 27389 UNION ALL
    SELECT 3610667, 27390 UNION ALL
    SELECT 3610926, 27391 UNION ALL
    SELECT 3611035, 27451 UNION ALL
    SELECT 3611035, 27452 UNION ALL
    SELECT 3611035, 27453 UNION ALL
    SELECT 3611035, 27454 UNION ALL
    SELECT 3645730, 27463 UNION ALL
    SELECT 3611034, 27464 UNION ALL
    SELECT 3611034, 27465 UNION ALL
    SELECT 3616115, 27612
) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3610667, 27389), (3610926, 27390), (3611035, 27451));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3611035, 27452), (3611035, 27453), (3611035, 27454));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3611034, 27463), (3611034, 27464), (3611034, 27465));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3616115, 27612));
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (
    SELECT 3610667 AS `id`, 27389 AS `quest` UNION ALL
    SELECT 3610926, 27390 UNION ALL
    SELECT 3611035, 27451 UNION ALL
    SELECT 3611035, 27452 UNION ALL
    SELECT 3611035, 27453 UNION ALL
    SELECT 3611035, 27454 UNION ALL
    SELECT 3611034, 27463 UNION ALL
    SELECT 3611034, 27464 UNION ALL
    SELECT 3611034, 27465 UNION ALL
    SELECT 3616115, 27612
) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

DELETE FROM `gameobject_questender` WHERE `id` = 3777544 AND `quest` = 27391;
INSERT INTO `gameobject_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 3777544 AS `id`, 27391 AS `quest`) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37);

UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` IN (3610667, 3610926, 3611034, 3611035,
    3616115, 3645428, 3645730)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- 5. Quest data
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 152 WHERE `ID` IN (27369, 27389, 27390, 27391, 27451,
    27452, 27453, 27454, 27463, 27464, 27465, 27612);
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27369 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27389 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 175500 WHERE `ID` = 27390 AND `RewardMoney` < 175500;
UPDATE `quest_template` SET `RewardMoney` = 210600 WHERE `ID` = 27391 AND `RewardMoney` < 210600;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27451 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27452 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27453 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27454 AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 14040 WHERE `ID` = 27463 AND `RewardMoney` < 14040;
UPDATE `quest_template` SET `RewardMoney` = 175500 WHERE `ID` = 27464 AND `RewardMoney` < 175500;
UPDATE `quest_template` SET `RewardMoney` = 175500 WHERE `ID` = 27465 AND `RewardMoney` < 175500;
UPDATE `quest_template` SET `RewardMoney` = 140400 WHERE `ID` = 27612 AND `RewardMoney` < 140400;

-- one-of-N exclusive groups -> 0 (skyfire_world); only where the row still has its cata group
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27369 AND `ExclusiveGroup` = 27369;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27372 AND `ExclusiveGroup` = 27369;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27387 AND `ExclusiveGroup` = 27387;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27388 AND `ExclusiveGroup` = 27387;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27389 AND `ExclusiveGroup` = 27387;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27451 AND `ExclusiveGroup` = 27451;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 27452 AND `ExclusiveGroup` = 27451;

-- 27451: required item compacted into slot 1 (cata had slot 1 empty, slot 2 = Coagulated Rot)
UPDATE `quest_template` SET `RequiredItemId1` = 15448, `RequiredItemCount1` = 1, `RequiredItemId2` = 0,
    `RequiredItemCount2` = 0 WHERE `ID` = 27451;
-- 27453 / 27454 / 27464: their start items only carried Cata spells; the client has none of them
UPDATE `quest_template` SET `StartItem` = 0, `ItemDrop2` = 0, `ItemDropQuantity2` = 0 WHERE `ID` = 27453;
UPDATE `quest_template` SET `StartItem` = 0, `ItemDrop1` = 0, `ItemDropQuantity1` = 0, `RequiredNpcOrGo1` = -3805485,
    `RequiredNpcOrGoCount1` = 1 WHERE `ID` = 27454;
UPDATE `quest_template` SET `StartItem` = 0, `ItemDrop1` = 0, `ItemDropQuantity1` = 0, `RequiredNpcOrGo1` = 3645707,
    `RewardSpell` = 0 WHERE `ID` = 27464;
UPDATE `quest_template_addon` SET `ProvidedItemCount` = 0 WHERE `ID` IN (27453, 27454, 27464);
-- 27465: credit entry Dread Weaver; 27612: the two portal goobers (Hall of Arms first, as cata's objective order)
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3608528 WHERE `ID` = 27465;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = -3805876, `RequiredNpcOrGo2` = -3805877 WHERE `ID` = 27612;

-- texts of the adapted quests
UPDATE `quest_template` SET
    `LogDescription` = CONCAT(
        'Slay the living water elementals within Lake Mereldar and collect 8 Active Liquid Plague Agents ',
        'from their remains.'),
    `QuestDescription` = CONCAT(
        'Coagulated rot is potent on its own, but we need something to activate its concealed powers... a ',
        'catalyst.  You can find just such a catalyst to the south, in Lake Mereldar.$b$bDestroy the ',
        'water elementals in the lake and bottle what remains of them.  The living, corrupted water that ',
        'flows through their bodies will be the perfect catalyst!')
WHERE `ID` = 27453;
UPDATE `quest_template` SET
    `LogDescription` = CONCAT(
        'Fight your way into the Death Cultist Base Camp, then put Betina''s mixture into the Mereldar ',
        'Plague Cauldron.'),
    `QuestDescription` = CONCAT(
        'Now, mix a tiny amount of rot into the water, and mix thoroughly.  There, that''s it.  This ',
        'solution will still be very powerful, and we only need a little bit of it.$b$bOn the lake''s ',
        'southeastern border, you will find a plague cauldron with several cultists nearby.  Get past ',
        'them, then approach the cauldron and put in ONE DROP of the solution you made.  No more, or you ',
        'may risk your very life!'),
    `ObjectiveText1` = 'Disturb Mereldar Plague Cauldron',
    `AreaDescription` = ''
WHERE `ID` = 27454;
UPDATE `quest_template` SET
    `LogDescription` = CONCAT(
        'Enter the Crypt behind Light''s Hope Chapel and complete the test of Lord Raymond George.'),
    `QuestDescription` = CONCAT(
        'Behind our chapel, you will find a small crypt.  Interred within are the bodies of our fallen ',
        'heroes, those who gave their lives in the war against the Scourge.$b$bTheir spirits are at ',
        'peace, but they return intermittently to test new members of the order.$b$bEnter the crypt and ',
        'face Lord Raymond George - my predecessor.  He will preside over your test.')
WHERE `ID` = 27464;
UPDATE `quest_template` SET
    `LogDescription` = 'Slay 16 Scourge and 8 Cultists within Browman Mill and the Noxious Glade.'
WHERE `ID` = 27465;
UPDATE `quest_template` SET
    `QuestDescription` = CONCAT(
        'A few of our men didn''t make it through portals which were supposed to open inside this very ',
        'abbey.  You''ve already proven your elusiveness and battlehardiness... now I need you to do so ',
        'again.$b$bThe abbey has two wings: a library, and a hall of arms.  In each wing, you should find ',
        'a portal.$b$bForce these portals open.  That should allow our remaining shock troopers to take ',
        'this abbey.')
WHERE `ID` = 27612;

-- rewards: gear -> band-152 ladder, Sweet Tea -> Nordrassil Moonwater; slots stay contiguous
-- 27369: 62938->421633, 62937->421623, 62936->421615, 62935->421609
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421633, `RewardChoiceItemID2` = 421623, `RewardChoiceItemID3` = 421615,
    `RewardChoiceItemID4` = 421609, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0,
    `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1,
    `RewardChoiceItemQuantity4` = 1, `RewardChoiceItemQuantity5` = 0,
    `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27369;
-- 27390: 63023->400819, 62957->421636, 62956->421620, 62955->421619
UPDATE `quest_template` SET `RewardItem1` = 400819, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 1, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421636, `RewardChoiceItemID2` = 421620, `RewardChoiceItemID3` = 421619,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27390;
-- 27391: 62961->421675, 62960 dropped, 62959->421680, 62958->421682
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421675, `RewardChoiceItemID2` = 421680, `RewardChoiceItemID3` = 421682,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27391;
-- 27454: 62977->421634, 62976->421628, 62975->421643
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421634, `RewardChoiceItemID2` = 421628, `RewardChoiceItemID3` = 421643,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27454;

-- offer / request texts from cata_world (ours had none for these)
DELETE FROM `quest_offer_reward` WHERE `ID` IN (27368, 27369, 27372, 27451, 27452, 27453, 27454);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT `ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
    `RewardText`, 0 FROM `cata_world`.`quest_offer_reward`
WHERE `ID` IN (27368, 27369, 27372, 27451, 27452, 27453, 27454);
DELETE FROM `quest_request_items` WHERE `ID` IN (27368, 27369, 27372, 27389, 27390, 27451, 27452, 27453, 27454);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT `ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, 0 FROM `cata_world`.`quest_request_items`
WHERE `ID` IN (27368, 27369, 27372, 27389, 27390, 27451, 27452, 27453, 27454);

-- 6. Quest map markers (27369's old 640 yd shore polygon is replaced by the two bell clusters)
DELETE FROM `quest_poi` WHERE `QuestID` IN (27369, 27389, 27390, 27391, 27451, 27452);
DELETE FROM `quest_poi` WHERE `QuestID` IN (27453, 27454, 27463, 27464, 27465, 27612);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(27369, 0, 4, 751, 1217, 0, 0, 1, 0),
(27369, 1, 4, 751, 1217, 0, 0, 1, 0),
(27369, 2, -1, 751, 1217, 0, 0, 1, 0),
(27389, 0, 4, 751, 1217, 0, 0, 1, 0),
(27389, 1, -1, 751, 1217, 0, 0, 1, 0),
(27390, 0, 0, 751, 1217, 0, 0, 1, 0),
(27390, 1, -1, 751, 1217, 0, 0, 1, 0),
(27391, 0, -1, 751, 1217, 0, 0, 1, 0),
(27451, 0, 4, 751, 1217, 0, 0, 1, 0),
(27451, 1, -1, 751, 1217, 0, 0, 1, 0),
(27452, 0, 4, 751, 1217, 0, 0, 1, 0),
(27452, 1, 5, 751, 1217, 0, 0, 1, 0),
(27452, 2, -1, 751, 1217, 0, 0, 1, 0),
(27453, 0, 4, 751, 1217, 0, 0, 1, 0),
(27453, 1, -1, 751, 1217, 0, 0, 1, 0),
(27454, 0, 0, 751, 1217, 0, 0, 1, 0),
(27454, 1, -1, 751, 1217, 0, 0, 1, 0),
(27463, 0, -1, 751, 1217, 0, 0, 1, 0),
(27464, 0, -1, 751, 1217, 0, 0, 1, 0),
(27465, 0, 0, 751, 1217, 0, 0, 1, 0),
(27465, 1, 0, 751, 1217, 0, 0, 1, 0),
(27465, 2, 1, 751, 1217, 0, 0, 1, 0),
(27465, 3, -1, 751, 1217, 0, 0, 1, 0),
(27612, 0, -1, 751, 1217, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27369, 27389, 27390, 27391, 27451, 27452);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27453, 27454, 27463, 27464, 27465, 27612);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27369, 0, 0, 2424, -2424, 0),
(27369, 0, 1, 2460, -2458, 0),
(27369, 0, 2, 2559, -2488, 0),
(27369, 0, 3, 2622, -2484, 0),
(27369, 0, 4, 2598, -2395, 0),
(27369, 0, 5, 2459, -2411, 0),
(27369, 1, 0, 2646, -2399, 0),
(27369, 1, 1, 2673, -2429, 0),
(27369, 1, 2, 2712, -2459, 0),
(27369, 1, 3, 2783, -2421, 0),
(27369, 1, 4, 2806, -2359, 0),
(27369, 2, 0, 1916, -2651, 0),
(27389, 0, 0, 2305, -3577, 0),
(27389, 0, 1, 2361, -3680, 0),
(27389, 0, 2, 2455, -3784, 0),
(27389, 0, 3, 2456, -3726, 0),
(27389, 0, 4, 2439, -3672, 0),
(27389, 0, 5, 2397, -3639, 0),
(27389, 1, 0, 1874, -3709, 0),
(27390, 0, 0, 1461, -3703, 0),
(27390, 0, 1, 1456, -3690, 0),
(27390, 0, 2, 1443, -3685, 0),
(27390, 0, 3, 1430, -3690, 0),
(27390, 0, 4, 1425, -3703, 0),
(27390, 0, 5, 1430, -3716, 0),
(27390, 0, 6, 1443, -3721, 0),
(27390, 0, 7, 1456, -3716, 0),
(27390, 1, 0, 1456, -3596, 0),
(27391, 0, 0, 1462, -3587, 0),
(27451, 0, 0, 1911, -4553, 0),
(27451, 0, 1, 1940, -4593, 0),
(27451, 0, 2, 2054, -4642, 0),
(27451, 0, 3, 2105, -4611, 0),
(27451, 0, 4, 2126, -4576, 0),
(27451, 0, 5, 2149, -4494, 0),
(27451, 0, 6, 2135, -4454, 0),
(27451, 0, 7, 2047, -4381, 0),
(27451, 0, 8, 1978, -4405, 0),
(27451, 0, 9, 1914, -4436, 0),
(27451, 1, 0, 2237, -4433, 0),
(27452, 0, 0, 1941, -4455, 0),
(27452, 0, 1, 1955, -4518, 0),
(27452, 0, 2, 1963, -4530, 0),
(27452, 0, 3, 1977, -4540, 0),
(27452, 0, 4, 2087, -4468, 0),
(27452, 0, 5, 2035, -4411, 0),
(27452, 1, 0, 1941, -4455, 0),
(27452, 1, 1, 1955, -4518, 0),
(27452, 1, 2, 1963, -4530, 0),
(27452, 1, 3, 1977, -4540, 0),
(27452, 1, 4, 2087, -4468, 0),
(27452, 1, 5, 2035, -4411, 0),
(27452, 2, 0, 2237, -4433, 0),
(27453, 0, 0, 1635, -4546, 0),
(27453, 0, 1, 1666, -4588, 0),
(27453, 0, 2, 1755, -4591, 0),
(27453, 0, 3, 1781, -4475, 0),
(27453, 0, 4, 1744, -4449, 0),
(27453, 0, 5, 1666, -4506, 0),
(27453, 1, 0, 2237, -4433, 0),
(27454, 0, 0, 1664, -4808, 0),
(27454, 0, 1, 1660, -4798, 0),
(27454, 0, 2, 1650, -4794, 0),
(27454, 0, 3, 1640, -4798, 0),
(27454, 0, 4, 1636, -4808, 0),
(27454, 0, 5, 1640, -4818, 0),
(27454, 0, 6, 1650, -4822, 0),
(27454, 0, 7, 1660, -4818, 0),
(27454, 1, 0, 2237, -4433, 0),
(27463, 0, 0, 2308, -5346, 0),
(27464, 0, 0, 2308, -5346, 0),
(27465, 0, 0, 2608, -5421, 0),
(27465, 0, 1, 2619, -5483, 0),
(27465, 0, 2, 2741, -5508, 0),
(27465, 0, 3, 2841, -5457, 0),
(27465, 0, 4, 2828, -5380, 0),
(27465, 0, 5, 2801, -5365, 0),
(27465, 0, 6, 2726, -5329, 0),
(27465, 0, 7, 2692, -5336, 0),
(27465, 0, 8, 2660, -5349, 0),
(27465, 0, 9, 2620, -5386, 0),
(27465, 1, 0, 2395, -5192, 0),
(27465, 1, 1, 2437, -5221, 0),
(27465, 1, 2, 2626, -5227, 0),
(27465, 1, 3, 2524, -5105, 0),
(27465, 1, 4, 2401, -5097, 0),
(27465, 2, 0, 2659, -5410, 0),
(27465, 2, 1, 2717, -5462, 0),
(27465, 2, 2, 2771, -5422, 0),
(27465, 2, 3, 2779, -5381, 0),
(27465, 2, 4, 2678, -5396, 0),
(27465, 3, 0, 2308, -5346, 0),
(27612, 0, 0, 1691, -5212, 0);

-- Verify after apply (expected values in brackets):
--   SELECT COUNT(*) FROM `creature_queststarter` WHERE `quest` IN (<the 12 quests above>);  [12]
--   SELECT COUNT(*) FROM `creature_template` WHERE `entry` IN (3608525, 3608526, 3608531, 3608538, ...)
--     AND `minlevel` > 154;                                                         [0]
--   SELECT `type`, `Data1` FROM `gameobject_template` WHERE `entry` = 3805485;      [10, 27454]
--   SELECT COUNT(*) FROM `gameobject` WHERE `guid` BETWEEN 9032000 AND 9032002;     [3]
--   SELECT COUNT(*) FROM `quest_template` WHERE (`RewardChoiceItemID1` = 0 AND `RewardChoiceItemID2` <> 0)
--     OR (`RewardItem1` = 0 AND `RewardItem2` <> 0);                                [0]
