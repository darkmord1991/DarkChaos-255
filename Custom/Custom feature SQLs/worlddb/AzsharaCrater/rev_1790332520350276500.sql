-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- quest fixes found by the bot questline audit, 2026-09-25
-- ---------------------------------------------------------------------------
-- 1. 300405: the zone 4 -> zone 5 hand-off (Wavemaster Kol'gar -> Demonologist
--    Vex'ara) never existed. The January zones 4-8 file only wrote its quest
--    relations, and those were later dropped as orphans, so players finishing
--    Kol'gar's hub got no lead-in to Vex'ara. Created here in the shape of the
--    other hand-offs (300306, 300505, 300704): no objectives, turned in at the
--    next hub, level 40 / min 36 (top of zone 4), zone 4 reward tier.
--
-- 2. 300407 Rations for the Tide-Guard: Big Bear Meat 3730 only came from the
--    cooking vendors at Thalindra's camp, and the crater has no bears at the
--    quest's level (the only ones are Ironfur Bears, level 41-42, far away). The
--    six Witherbark/Bloodscalp troll entries camped near Kol'gar (16 spawns,
--    level 31-37) now drop it at 50%, quest-only. Nothing else asks for 3730, so
--    the stock spawns of these trolls are unaffected. The vendors still sell it.
--
-- 3. Map markers of the crater's item quests used ObjectiveIndex 0. Stock data
--    (and the client) number item objectives from 4, and index 0 names the empty
--    first creature objective of these quests, so the marker belongs to nothing.
--    Bots matched POIs by index and never worked on any of these nine quests.
--    300407's marker now covers the troll camps instead of the vendors.
--
-- 4. 300820-300822 (Nexus-Prince Haramad) were placeholders: QuestSortID 0, so the
--    2026-07-13 reward sweep (keyed on QuestSortID 268) skipped them, and each
--    killed an elite instance mob with no crater spawn (Skeletal Smith 29837 at 81,
--    Nazan 18432 -- a Ramparts dragon filed as "Temple Guardians" -- and Phantom
--    Valet 16408). They now kill normal zone 8 mobs with crater spawns:
--      300820 Weapons of the Dead     -> Skeletal Craftsman 32164 x8    (10 spawns, 78-79)
--      300821 The Shard Watchers      -> Cultist Shard Watcher 32349 x6 (7 spawns, 80)
--      300822 Raiders out of the Mist -> Kvaldir Invader 35242 x8       (9 spawns, 78-80)
--    Quest levels follow the targets (bots will not attack mobs more than 4 levels
--    above them), and rewards match the rest of zone 8.
--
-- Map markers are literal rectangles from the live spawns on 2026-09-25: objective
-- = spawn bounding box +/- 40 yd, turn-in = quest ender +/- 20 yd, WorldMapAreaId 613.
--
-- Idempotent: safe to apply twice. Restart afterwards -- quest templates, POIs and
-- quest relations are loaded at startup only.
-- ---------------------------------------------------------------------------

-- 1. 300405 Beyond the Tide-Line (Kol'gar -> Vex'ara)
-- The quest_template DELETE is intended: 300405 is a new custom quest id.
DELETE FROM `quest_template` WHERE `ID` = 300405;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoneyDifficulty`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`,
    `RewardItem3`, `RewardAmount3`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300405, 2, 40, 36, 268, 0, 0, 6, 6, 11311, 1, 300311, 12, 300312, 8, 29158, 1, 2951, 1, 13088, 1, 7722, 1, 5079, 1, 2802, 1,
    'Beyond the Tide-Line',
    'Seek out Demonologist Vex''ara beyond the ruins.',
    'The shore holds, $N, and not a little of that is your doing. My tide-guard can keep the Spitelash in the water from here.$B$BBut what festers deeper in this crater is no fight for spears. The further you walk from the sea, the thicker the old magic pools, and things drink of it that should not. There is a blood elf out there, a demonologist called Vex''ara, who studies that sickness the way other folk study the weather. Cold eyes, sharp tongue, but she knows what she is looking at.$B$BGo to her. Tell her the Wavemaster sent you, and that the shore holds. Storm guide your feet.',
    'Azshara Crater',
    'Speak with Demonologist Vex''ara.');

DELETE FROM `quest_offer_reward` WHERE `ID` = 300405;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300405, 'The Wavemaster sends me a soldier. How thoughtful of him.$B$BDo not mistake me, $N. I have every use for a strong arm. The corruption in this crater does not study itself, and its specimens rarely hold still. Stay near my wards and listen well.');

DELETE FROM `creature_queststarter` WHERE `quest` = 300405;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300030, 300405);

DELETE FROM `creature_questender` WHERE `quest` = 300405;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300040, 300405);

DELETE FROM `quest_poi` WHERE `QuestID` = 300405;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300405, 0, -1, 37, 613, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` = 300405;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300405, 0, 0, 636, 82, 0),
(300405, 0, 1, 636, 122, 0),
(300405, 0, 2, 676, 122, 0),
(300405, 0, 3, 676, 82, 0);

-- 2. 300407 Rations for the Tide-Guard: Big Bear Meat from the troll war-bands
DELETE FROM `creature_loot_template` WHERE `Entry` IN (587, 701, 702, 2553, 2555, 2558) AND `Item` = 3730;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(587, 3730, 0, 50, 1, 1, 0, 1, 1, 'Bloodscalp Warrior - Big Bear Meat (Azshara Crater quest 300407)'),
(701, 3730, 0, 50, 1, 1, 0, 1, 1, 'Bloodscalp Mystic - Big Bear Meat (Azshara Crater quest 300407)'),
(702, 3730, 0, 50, 1, 1, 0, 1, 1, 'Bloodscalp Scavenger - Big Bear Meat (Azshara Crater quest 300407)'),
(2553, 3730, 0, 50, 1, 1, 0, 1, 1, 'Witherbark Shadowcaster - Big Bear Meat (Azshara Crater quest 300407)'),
(2555, 3730, 0, 50, 1, 1, 0, 1, 1, 'Witherbark Witch Doctor - Big Bear Meat (Azshara Crater quest 300407)'),
(2558, 3730, 0, 50, 1, 1, 0, 1, 1, 'Witherbark Berserker - Big Bear Meat (Azshara Crater quest 300407)');

UPDATE `quest_template` SET `QuestDescription` = 'An army marches on its belly, $N, and mine is sick to death of salt-fish and hard bread.$B$BThe Witherbark and Bloodscalp war-bands camped near my shore have hunted the crater''s bears near to nothing, and they sit on the meat like dragons on gold. Take it from them. Ten cuts of Big Bear Meat, and my tide-guard eats like it earned it tonight.$B$BIf you would rather spend coin than blood, the cooks at Scout Thalindra''s camp keep a little in stock. Kol''gar does not care where it comes from, only that it comes.'
WHERE `ID` = 300407 AND `RequiredItemId1` = 3730;

DELETE FROM `quest_poi` WHERE `QuestID` = 300407;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300407, 0, 4, 37, 613, 0, 0, 3, 0),
(300407, 1, -1, 37, 613, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` = 300407;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300407, 0, 0, -205, 148, 0),
(300407, 0, 1, -205, 390, 0),
(300407, 0, 2, 40, 390, 0),
(300407, 0, 3, 40, 148, 0),
(300407, 1, 0, -71, 493, 0),
(300407, 1, 1, -71, 533, 0),
(300407, 1, 2, -31, 533, 0),
(300407, 1, 3, -31, 493, 0);

-- 3. Item-objective markers: ObjectiveIndex 0 -> 4 for the single-item crater quests
--    (300107 300207 300301 300307 300507 300706 300804 300805; 300407 is rebuilt above)
UPDATE `quest_poi` INNER JOIN `quest_template` ON `quest_template`.`ID` = `quest_poi`.`QuestID` SET `quest_poi`.`ObjectiveIndex` = 4
WHERE `quest_poi`.`QuestID` BETWEEN 300100 AND 300999
  AND `quest_poi`.`ObjectiveIndex` = 0
  AND `quest_template`.`RequiredNpcOrGo1` = 0 AND `quest_template`.`RequiredNpcOrGo2` = 0
  AND `quest_template`.`RequiredNpcOrGo3` = 0 AND `quest_template`.`RequiredNpcOrGo4` = 0
  AND `quest_template`.`RequiredItemId1` <> 0 AND `quest_template`.`RequiredItemId2` = 0;

-- 4. 300820-300822 (Nexus-Prince Haramad): crater sort, crater targets, zone 8 rewards
UPDATE `quest_template` SET `QuestSortID` = 268, `QuestLevel` = 78, `MinLevel` = 75,
    `RequiredNpcOrGo1` = 32164, `RequiredNpcOrGoCount1` = 8,
    `LogTitle` = 'Weapons of the Dead',
    `LogDescription` = 'Destroy 8 Skeletal Craftsmen.',
    `QuestDescription` = 'A word of business, friend. The Consortium came to this crater for the relics of the Highborne, and the Scourge has come for the same, though with far less taste.$B$BTheir skeletal craftsmen are melting down ancient Highborne arms and hammering them into blades for the dead. Every piece they ruin is a fortune lost, and every blade they finish is one more pointed at us. I would call that a poor exchange.$B$BDestroy eight of the Skeletal Craftsmen and put out their forges. The Consortium pays well for services rendered.',
    `AreaDescription` = 'Azshara Crater',
    `QuestCompletionLog` = 'Return to Nexus-Prince Haramad.'
WHERE `ID` = 300820;

UPDATE `quest_template` SET `QuestSortID` = 268, `QuestLevel` = 79, `MinLevel` = 76,
    `RequiredNpcOrGo1` = 32349, `RequiredNpcOrGoCount1` = 6,
    `LogTitle` = 'The Shard Watchers',
    `LogDescription` = 'Slay 6 Cultist Shard Watchers.',
    `QuestDescription` = 'The Cult of the Damned has found something here that I very much want, $N: shards of crystallized arcane power, shed from the old Highborne workings like scales from a dragon.$B$BThe cult sets a watcher over every shard it unearths. They mean to feed that power to their masters in the north. The Consortium means to catalogue it, and to sell it to more deserving buyers.$B$BSlay six of these Shard Watchers. What they guard will find its way to me soon enough.',
    `AreaDescription` = 'Azshara Crater',
    `QuestCompletionLog` = 'Return to Nexus-Prince Haramad.'
WHERE `ID` = 300821;

UPDATE `quest_template` SET `QuestSortID` = 268, `QuestLevel` = 79, `MinLevel` = 76,
    `RequiredNpcOrGo1` = 35242, `RequiredNpcOrGoCount1` = 8,
    `LogTitle` = 'Raiders out of the Mist',
    `LogDescription` = 'Slay 8 Kvaldir Invaders.',
    `QuestDescription` = 'Trade depends on safe roads, $N, and mine are anything but. Kvaldir raiders have come out of the mist and made camp at the edge of the crater. They take what they can carry and burn the rest, and three of my caravans have gone into their longboats this week alone.$B$BI do not ask you to love the Consortium. I ask you to make robbing it expensive. Slay eight of the Kvaldir Invaders, and perhaps my next caravan will arrive with its cargo.',
    `AreaDescription` = 'Azshara Crater',
    `QuestCompletionLog` = 'Return to Nexus-Prince Haramad.'
WHERE `ID` = 300822;

UPDATE `quest_template` SET `RewardXPDifficulty` = 6, `RewardMoneyDifficulty` = 6,
    `RewardItem1` = 50668, `RewardAmount1` = 1,
    `RewardItem2` = 300311, `RewardAmount2` = 40,
    `RewardItem3` = 300312, `RewardAmount3` = 28,
    `RewardItem4` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 37151, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemID2` = 37232, `RewardChoiceItemQuantity2` = 1,
    `RewardChoiceItemID3` = 45206, `RewardChoiceItemQuantity3` = 1,
    `RewardChoiceItemID4` = 43404, `RewardChoiceItemQuantity4` = 1,
    `RewardChoiceItemID5` = 37723, `RewardChoiceItemQuantity5` = 1,
    `RewardChoiceItemID6` = 37264, `RewardChoiceItemQuantity6` = 1
WHERE `ID` IN (300820, 300821, 300822);

DELETE FROM `quest_request_items` WHERE `ID` IN (300820, 300821, 300822);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`) VALUES
(300820, 0, 0, 'Are their forges still burning, friend? Every hour costs us.'),
(300821, 0, 0, 'The shards remain under guard, I take it? Patience is a virtue, but not an infinite one.'),
(300822, 0, 0, 'Do the Kvaldir still prowl my roads?');

DELETE FROM `quest_offer_reward` WHERE `ID` IN (300820, 300821, 300822);
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300820, 'Their forges are cold, and what remains of the Highborne arms can now be... properly appraised. A most profitable arrangement, $N. Your payment, as agreed.'),
(300821, 'Six watchers fewer, and the shards unguarded. My agents are already on their way. You have a gift for this line of work, $N.'),
(300822, 'The raiders will think twice before they touch my caravans again. Consider this payment, and the start of a long and prosperous acquaintance.');

DELETE FROM `quest_poi` WHERE `QuestID` IN (300820, 300821, 300822);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300820, 0, 0, 37, 613, 0, 0, 3, 0),
(300820, 1, -1, 37, 613, 0, 0, 1, 0),
(300821, 0, 0, 37, 613, 0, 0, 3, 0),
(300821, 1, -1, 37, 613, 0, 0, 1, 0),
(300822, 0, 0, 37, 613, 0, 0, 3, 0),
(300822, 1, -1, 37, 613, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (300820, 300821, 300822);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300820, 0, 0, -579, -278, 0),
(300820, 0, 1, -579, -125, 0),
(300820, 0, 2, -383, -125, 0),
(300820, 0, 3, -383, -278, 0),
(300820, 1, 0, -51, 3, 0),
(300820, 1, 1, -51, 43, 0),
(300820, 1, 2, -11, 43, 0),
(300820, 1, 3, -11, 3, 0),
(300821, 0, 0, -611, -117, 0),
(300821, 0, 1, -611, 23, 0),
(300821, 0, 2, -440, 23, 0),
(300821, 0, 3, -440, -117, 0),
(300821, 1, 0, -51, 3, 0),
(300821, 1, 1, -51, 43, 0),
(300821, 1, 2, -11, 43, 0),
(300821, 1, 3, -11, 3, 0),
(300822, 0, 0, -346, -394, 0),
(300822, 0, 1, -346, -37, 0),
(300822, 0, 2, -192, -37, 0),
(300822, 0, 3, -192, -394, 0),
(300822, 1, 0, -51, 3, 0),
(300822, 1, 1, -51, 43, 0),
(300822, 1, 2, -11, 43, 0),
(300822, 1, 3, -11, 3, 0);
