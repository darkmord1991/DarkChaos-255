-- DarkChaos: map 750 - the seven Winterspring Cata quests that waited on their quest items (2026-11-14)
--
-- Why: rev_1794662427930924200 (Winterspring / Hyjal port) skipped these because their quest items had neither an
-- item_template nor an Item.dbc row. The owner chose to add the items and port the quests as Cata designed them.
-- Together 493,100 XP at level 109 (QuestXP x2), all races.
--
-- 1. Items 64441 64449 64465 64664 65903 66052 66060 (class 12 quest items, bind 4, Cata 4.3.4 client data:
--    Item.db2 for class / material / display, Item-sparse for name / description / stack). Only the party-loot
--    flag 0x800 of the Cata flags is kept. maxcount = the amount the quest asks for. Display stand-ins where the
--    Cata display or its icon is not in the client: 64441 -> 37755 (Nexus Crystal, same icon), 64664 -> 8237402
--    (same icon inv_misc_monsterhorn_07), 66052 -> 10923 (stock brain icon; Cata's meat icon has no BLP here).
--    66060's Cata use spell 93392 Close Tesseract is in no DBC here, so the item has no use spell (see 6.).
--    NEEDS the new Item.dbc on the server (Server/data/dbc) before the restart: without the DBC row the core
--    drops these item_template rows silently. The client needs the same Item.dbc for the icons.
-- 2. Quests imported from cata_world: 28518 Legacy of the High Elves (Quel'dorei Spirit), 28530 Scalding Signs
--    (Donova Snowden), 28540 Doin' De E'ko Magic (Witch Doctor Mau'ari), 28631 The Perfect Horns (Umi
--    Rumplesnicker), 28837 Altered Beasts, 28840 Winterwater, 28841 The Arcane Storm Within (Haleh).
-- 3. Chains as in Cata: 28534 -> 28518 -> 28535 (the Kel'Theril chain gets its missing step back; this undoes
--    rev_1794662427930924200's 28534 -> 28535 shortcut), 28847 -> 28837 and 28839 -> 28840 (RewardNextQuest
--    restored, were 0; Winterwater keeps its Cata auto-accept flag). 28631 keeps NextQuestID 28722 but not Cata's
--    ExclusiveGroup 28629: a positive group makes it exclusive with Are We There, Yeti? (28629), so everyone who
--    already did 28629 could never take it. Either quest now opens Yetiphobia.
-- 4. Quest-only drops (QuestRequired 1) on the map-750 copies: Archmage Maenius 3748740, Scalding Springsurge
--    3748767 / Boiling Springbubble 3748768 (75%), Rimepelt 3748765, Icewhomp 3749235, Altered Beast 3749161
--    (75%), Ice Avatar 3750250, Frostilicus 3750251 (2). Their spawns and the Arcane Tesseracts respawn in 120 s.
-- 5. Map markers: turn-in on the ender spawn, small objective polygons (ObjectiveIndex 4 = first item) over
--    the spawn clusters that have no elite within 45 yd (Cobalt dragonkin at Mazthoril, Frostmaul giants in
--    Frostwhisper Gorge); none in the caves (Icewhomp, Mazthoril), so bots walk to the spawns there.
-- 6. 28841: without 93392 the Empowered Dreamcatcher cannot be used, so an Arcane Tesseract (3750291, now
--    SmartAI) closes when a player on the quest who carries the Dreamcatcher comes within 10 yd: credit, then
--    despawn (120 s). Same pattern as the DC q5097 beacon credit. The quest log line says so. The objective names
--    3750291 itself. The tesseracts sit among elite Cobalt dragonkin, as in Cata: bots should skip 28841.
--
-- Conventions (rev_1794662427930924200): QuestLevel -1, MinLevel 104 (106 for 28837 / 28840 / 28841, whose
-- targets are level 109-110 and must stay within 4 levels), Cata RewardXPDifficulty, Cata reputation kept
-- (Timbermaw Hold 576, Everlook 577), gold by the 11-10 formula, gear through the 750 ladder. 28540 loses Cata's
-- 'Group' tag: Rimepelt is a normal mob, and bots never take a quest with a type tag.
--
-- Apply AFTER rev_1794662427930924200 (now in Custom/Custom feature SQLs/worlddb/HyjalCata/): it creates the
-- Quel'dorei Spirit 3748659 and the 28534 / 28535 rows this file re-links. Re-running that file afterwards puts
-- its 28534 -> 28535 shortcut back. Apply to acore_world (reads cata_world on the same server), then restart.
-- Revert notes: 28839 / 28847 RewardNextQuest were 0, 3750291 AIName was '', the spawns below had 300 s.

-- 1. quest items (Item.dbc rows: Custom/CSV DBC/Item.csv; the other columns keep their table defaults;
-- item_template rows are never deleted - codestyle - so this is a REPLACE)
REPLACE INTO `item_template` (
    `entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`, `FlagsExtra`,
    `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`,
    `RequiredLevel`, `maxcount`, `stackable`, `bonding`, `description`, `startquest`, `Material`, `sheath`,
    `VerifiedBuild`) VALUES
(64441, 12, 0, -1, 'Memory of Zin-Malor', 37755, 1, 2048, 0, 1, 0, 0, 0, -1, -1, 1, 1, 1, 1, 4,
    'A spectral and wispy image of a crystal shard.', 0, 4, 0, 15595),
(64449, 12, 0, -1, 'Suspicious Green Sludge', 6703, 1, 0, 0, 1, 0, 0, 0, -1, -1, 1, 1, 7, 20, 4,
    'Tingly to the touch.', 0, 4, 0, 15595),
(64465, 12, 0, -1, 'Rimepelt''s Heart', 3422, 1, 2048, 0, 1, 0, 0, 0, -1, -1, 1, 1, 1, 1, 4, '', 0, 4, 0, 15595),
(64664, 12, 0, -1, 'Icewhomp''s Pristine Horns', 8237402, 1, 2048, 0, 1, 0, 0, 0, -1, -1, 1, 1, 1, 1, 4, '', 0,
    4, 0, 15595),
(65903, 12, 0, -1, 'Winterwater', 2357, 1, 0, 0, 1, 0, 0, 0, -1, -1, 1, 1, 7, 20, 4,
    'It''s freezing cold! You must resist the temptation to put your tongue on it.', 0, 4, 0, 15595),
(66052, 12, 0, -1, 'Mana-Addled Brain', 10923, 1, 0, 0, 1, 0, 0, 0, -1, -1, 1, 1, 5, 20, 4,
    'Arcane in the membrane... arcane in the brain!', 0, 4, 0, 15595),
(66060, 12, 0, -1, 'Empowered Dreamcatcher', 21207, 1, 0, 0, 1, 0, 0, 0, -1, -1, 1, 1, 1, 1, 4, '', 0, 4, 0,
    15595);

-- 2. the quests (quest_template rows are never deleted - codestyle - so this is a REPLACE)
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`,
    `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`,
    `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`,
    `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`,
    `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`,
    `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`,
    `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`,
    `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT
    `q`.`ID`, `q`.`QuestType`, `q`.`QuestLevel`, `q`.`MinLevel`, `q`.`QuestSortID`, `q`.`QuestInfoID`,
    `q`.`SuggestedGroupNum`, `q`.`RequiredFactionId1`, `q`.`RequiredFactionId2`, `q`.`RequiredFactionValue1`,
    `q`.`RequiredFactionValue2`, `q`.`RewardNextQuest`, `q`.`RewardXPDifficulty`, `q`.`RewardMoney`, 0,
    `q`.`RewardDisplaySpell`, `q`.`RewardSpell`, `q`.`RewardHonor`, `q`.`RewardKillHonor`, `q`.`StartItem`,
    `q`.`Flags`, `q`.`RequiredPlayerKills`, `q`.`RewardItem1`, `q`.`RewardAmount1`, `q`.`RewardItem2`,
    `q`.`RewardAmount2`, `q`.`RewardItem3`, `q`.`RewardAmount3`, `q`.`RewardItem4`, `q`.`RewardAmount4`,
    `q`.`ItemDrop1`, `q`.`ItemDropQuantity1`, `q`.`ItemDrop2`, `q`.`ItemDropQuantity2`, `q`.`ItemDrop3`,
    `q`.`ItemDropQuantity3`, `q`.`ItemDrop4`, `q`.`ItemDropQuantity4`, `q`.`RewardChoiceItemID1`,
    `q`.`RewardChoiceItemQuantity1`, `q`.`RewardChoiceItemID2`, `q`.`RewardChoiceItemQuantity2`,
    `q`.`RewardChoiceItemID3`, `q`.`RewardChoiceItemQuantity3`, `q`.`RewardChoiceItemID4`,
    `q`.`RewardChoiceItemQuantity4`, `q`.`RewardChoiceItemID5`, `q`.`RewardChoiceItemQuantity5`,
    `q`.`RewardChoiceItemID6`, `q`.`RewardChoiceItemQuantity6`, `q`.`POIContinent`, `q`.`POIx`, `q`.`POIy`,
    `q`.`POIPriority`, `q`.`RewardTitle`, `q`.`RewardTalents`, `q`.`RewardArenaPoints`, `q`.`RewardFactionID1`,
    `q`.`RewardFactionValue1`, `q`.`RewardFactionOverride1`, `q`.`RewardFactionID2`, `q`.`RewardFactionValue2`,
    `q`.`RewardFactionOverride2`, `q`.`RewardFactionID3`, `q`.`RewardFactionValue3`, `q`.`RewardFactionOverride3`,
    `q`.`RewardFactionID4`, `q`.`RewardFactionValue4`, `q`.`RewardFactionOverride4`, `q`.`RewardFactionID5`,
    `q`.`RewardFactionValue5`, `q`.`RewardFactionOverride5`,
    CASE WHEN `a`.`TimeAllowed` IS NULL THEN 0 ELSE `a`.`TimeAllowed` END,
    CASE WHEN `a`.`AllowableRaces` IS NULL THEN 0 ELSE `a`.`AllowableRaces` END, `q`.`LogTitle`,
    `q`.`LogDescription`, `q`.`QuestDescription`, `q`.`AreaDescription`, `q`.`QuestCompletionLog`,
    `q`.`RequiredNpcOrGo1`, `q`.`RequiredNpcOrGo2`, `q`.`RequiredNpcOrGo3`, `q`.`RequiredNpcOrGo4`,
    `q`.`RequiredNpcOrGoCount1`, `q`.`RequiredNpcOrGoCount2`, `q`.`RequiredNpcOrGoCount3`,
    `q`.`RequiredNpcOrGoCount4`, `q`.`RequiredItemId1`, `q`.`RequiredItemId2`, `q`.`RequiredItemId3`,
    `q`.`RequiredItemId4`, `q`.`RequiredItemId5`, `q`.`RequiredItemId6`, `q`.`RequiredItemCount1`,
    `q`.`RequiredItemCount2`, `q`.`RequiredItemCount3`, `q`.`RequiredItemCount4`, `q`.`RequiredItemCount5`,
    `q`.`RequiredItemCount6`, 0, `q`.`ObjectiveText1`, `q`.`ObjectiveText2`, `q`.`ObjectiveText3`,
    `q`.`ObjectiveText4`, `q`.`VerifiedBuild`
FROM `cata_world`.`quest_template` AS `q`
LEFT JOIN `cata_world`.`quest_template_addon` AS `a` ON `a`.`ID` = `q`.`ID`
WHERE `q`.`ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);

DELETE FROM `quest_template_addon` WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `quest_template_addon` (
    `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`,
    `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`,
    `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`,
    `ProvidedItemCount`, `SpecialFlags`)
SELECT
    `s`.`ID`, `s`.`MaxLevel`, `s`.`AllowableClasses`, `s`.`SourceSpellID`, `s`.`PrevQuestID`, `s`.`NextQuestID`,
    `s`.`ExclusiveGroup`, `s`.`BreadcrumbForQuestId`, `s`.`RewardMailTemplateID`, `s`.`RewardMailDelay`,
    `s`.`RequiredSkillID`, `s`.`RequiredSkillPoints`, `s`.`RequiredMinRepFaction`, `s`.`RequiredMaxRepFaction`,
    `s`.`RequiredMinRepValue`, `s`.`RequiredMaxRepValue`, `s`.`ProvidedItemCount`, `s`.`SpecialFlags`
FROM `cata_world`.`quest_template_addon` AS `s`
WHERE `s`.`ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);

DELETE FROM `quest_offer_reward` WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `quest_offer_reward` (
    `ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
    `RewardText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`Emote1`, `s`.`Emote2`, `s`.`Emote3`, `s`.`Emote4`, `s`.`EmoteDelay1`, `s`.`EmoteDelay2`,
    `s`.`EmoteDelay3`, `s`.`EmoteDelay4`, `s`.`RewardText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` AS `s`
WHERE `s`.`ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);

DELETE FROM `quest_request_items` WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `quest_request_items` (
    `ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`EmoteOnComplete`, `s`.`EmoteOnIncomplete`, `s`.`CompletionText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` AS `s`
WHERE `s`.`ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);

-- Cata-only pieces: the 'Update Zone Auras and Phase Shift' reward spell 81040 (28518) and the all-race masks
-- (races 1-11 + 22 would shut out the DC custom races; 0 = every race, like most of 750)
UPDATE `quest_template` SET `RewardSpell` = 0, `RewardDisplaySpell` = 0
WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
UPDATE `quest_template` SET `AllowableRaces` = 0
WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841) AND `AllowableRaces` IN (2099199, 8388607);
-- Cata flag 0x10000 is remote turn-in; on AC it is QUEST_FLAGS_AUTOCOMPLETE and skips the objectives
UPDATE `quest_template` SET `Flags` = `Flags` & ~65536
WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);

-- levels, gold (only raised), the objective on the map-750 entry, quest log line of 28841
UPDATE `quest_template` SET `QuestLevel` = -1
WHERE `ID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
UPDATE `quest_template` SET `MinLevel` = 104
WHERE `ID` IN (28518, 28530, 28540, 28631);
UPDATE `quest_template` SET `MinLevel` = 106
WHERE `ID` IN (28837, 28840, 28841);
UPDATE `quest_template` SET `RewardMoney` = 98550
WHERE `RewardMoney` < 98550 AND `ID` IN (28837, 28840);
UPDATE `quest_template` SET `RewardMoney` = 123190
WHERE `RewardMoney` < 123190 AND `ID` IN (28518, 28530, 28540, 28841);
UPDATE `quest_template` SET `RewardMoney` = 147820
WHERE `RewardMoney` < 147820 AND `ID` IN (28631);
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3750291 WHERE `ID` = 28841;
-- 28540: Cata's 'Group' tag (QuestInfoID 1) on a normal level-106 Rimepelt; the tag makes bots skip the quest
UPDATE `quest_template` SET `QuestInfoID` = 0 WHERE `ID` = 28540;
UPDATE `quest_template` SET `LogDescription` =
    'Carry the Empowered Dreamcatcher close to 5 Arcane Tesseracts within Mazthoril to close them.'
WHERE `ID` = 28841;

-- rewards: gear -> the 750 ladder item of the same slot / type / quality (67207 Winterwater Cloak is not in our
-- item_template; it maps by its Cata class / slot), duplicates dropped, slots stay contiguous
UPDATE `quest_template` SET
    `RewardChoiceItemID1` = 420112, `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemID2` = 420152,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemID3` = 420192, `RewardChoiceItemQuantity3` = 1,
    `RewardChoiceItemID4` = 420172, `RewardChoiceItemQuantity4` = 1, `RewardChoiceItemID5` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0
WHERE `ID` = 28540;
UPDATE `quest_template` SET
    `RewardChoiceItemID1` = 420042, `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemID2` = 420122,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemID3` = 420342, `RewardChoiceItemQuantity3` = 1,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemQuantity4` = 0, `RewardChoiceItemID5` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0
WHERE `ID` = 28840;

-- 3. chain links (Cata): 28534 -> 28518 -> 28535, 28847 -> 28837, 28839 -> 28840; 28631 leaves group 28629
UPDATE `quest_template` SET `RewardNextQuest` = 28518 WHERE `ID` = 28534;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28518 WHERE `ID` = 28535;
UPDATE `quest_template` SET `RewardNextQuest` = 28837 WHERE `ID` = 28847 AND `RewardNextQuest` = 0;
UPDATE `quest_template` SET `RewardNextQuest` = 28840 WHERE `ID` = 28839 AND `RewardNextQuest` = 0;
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0 WHERE `ID` = 28631;

-- 4. givers and turn-ins (as in Cata, on the map-750 copies)
DELETE FROM `creature_queststarter` WHERE `quest` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3709298, 28530),
(3710305, 28631),
(3710307, 28540),
(3710929, 28837),
(3710929, 28840),
(3710929, 28841),
(3748659, 28518);
DELETE FROM `creature_questender` WHERE `quest` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3709298, 28530),
(3710305, 28631),
(3710307, 28540),
(3710929, 28837),
(3710929, 28840),
(3710929, 28841),
(3748659, 28518);

-- 5. quest-only drops (QuestRequired 1, ungrouped, Cata chances)
DELETE FROM `creature_loot_template` WHERE `Entry` = 3748740 AND `Item` = 64441;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3748767 AND `Item` = 64449;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3748768 AND `Item` = 64449;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3748765 AND `Item` = 64465;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3749235 AND `Item` = 64664;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3749161 AND `Item` = 66052;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3750250 AND `Item` = 65903;
DELETE FROM `creature_loot_template` WHERE `Entry` = 3750251 AND `Item` = 65903;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3748740, 64441, 0, 100, 1, 1, 0, 1, 1, 'DC750 quest 28518 item (Cata 48740 Archmage Maenius)'),
(3748767, 64449, 0, 75, 1, 1, 0, 1, 1, 'DC750 quest 28530 item (Cata 48767 Scalding Springsurge)'),
(3748768, 64449, 0, 75, 1, 1, 0, 1, 1, 'DC750 quest 28530 item (Cata 48768 Boiling Springbubble)'),
(3748765, 64465, 0, 100, 1, 1, 0, 1, 1, 'DC750 quest 28540 item (Cata 48765 Rimepelt)'),
(3749235, 64664, 0, 100, 1, 1, 0, 1, 1, 'DC750 quest 28631 item (Cata 49235 Icewhomp)'),
(3749161, 66052, 0, 75, 1, 1, 0, 1, 1, 'DC750 quest 28837 item (Cata 49161 Altered Beast)'),
(3750250, 65903, 0, 100, 1, 1, 0, 1, 1, 'DC750 quest 28840 item (Cata 50250 Ice Avatar)'),
(3750251, 65903, 0, 100, 1, 1, 0, 2, 2, 'DC750 quest 28840 item (Cata 50251 Frostilicus)');

-- 6. 28841: an Arcane Tesseract closes for a player on the quest carrying the Dreamcatcher within 10 yd
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 3750291;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3750291 AND `source_type` = 0;
INSERT INTO `smart_scripts` (
    `entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`,
    `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
    `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`,
    `target_z`, `target_o`, `comment`) VALUES
(3750291, 0, 0, 1, 10, 0, 100, 0, 2, 10, 1000, 1000, 1, 0, 33, 3750291, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
    'Arcane Tesseract - OOC LOS 10 yd (player, quest 28841 + Dreamcatcher) - Quest Credit'),
(3750291, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 41, 1000, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    'Arcane Tesseract - Linked - Despawn 1 s (closed)');
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceEntry` = 3750291 AND `SourceId` = 0;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
    `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
    `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(22, 1, 3750291, 0, 0, 9, 0, 28841, 0, 0, 0, 0, 0, '', 'Arcane Tesseract closes only for quest 28841'),
(22, 1, 3750291, 0, 0, 2, 0, 66060, 1, 0, 0, 0, 0, '', '... carrying the Empowered Dreamcatcher');

-- 7. quest targets respawn in 120 s (bot rule for quest pools)
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748740 AND `guid` IN (16376793);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748765 AND `guid` IN (16378197);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748767 AND `guid` IN (16378119, 16378120, 16378149, 16378156, 16378157, 16378158, 16378159, 16378173,
    16378174, 16378175, 16378176, 16378177, 16378184);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748768 AND `guid` IN (16378115, 16378116, 16378117, 16378139, 16378142, 16378144, 16378145, 16378146,
    16378151, 16378160, 16378161, 16378165, 16378182);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3749161 AND `guid` IN (16376519, 16376522, 16376523, 16376528, 16376529, 16376531, 16376533, 16376537,
    16376538, 16376539, 16376540, 16376546, 16376548, 16376552, 16376554, 16376555, 16376561, 16376562, 16376564,
    16376567, 16376577, 16376579, 16376675, 16376678, 16376701, 16376702, 16376703, 16376710);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3749235 AND `guid` IN (16376953);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3750250 AND `guid` IN (16376365, 16376366, 16376367, 16376372, 16376373, 16376383, 16376385, 16376386,
    16376389, 16376394, 16376402, 16376405, 16376406, 16376409, 16376410, 16376424, 16376425, 16376428, 16376429,
    16376430, 16376474, 16376478);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3750251 AND `guid` IN (16376374);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3750291 AND `guid` IN (16376619, 16376632, 16376633, 16376658, 16376659, 16376714, 16376715, 16376736,
    16376738, 16376739);

-- 8. quest map markers
DELETE FROM `quest_poi` WHERE `QuestID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(28518, 0, 4, 750, 1256, 0, 0, 1, 0),
(28518, 1, -1, 750, 1256, 0, 0, 1, 0),
(28530, 0, 4, 750, 1256, 0, 0, 1, 0),
(28530, 1, 4, 750, 1256, 0, 0, 1, 0),
(28530, 2, -1, 750, 1256, 0, 0, 1, 0),
(28540, 0, 4, 750, 1256, 0, 0, 1, 0),
(28540, 1, -1, 750, 1256, 0, 0, 1, 0),
(28631, 0, -1, 750, 1256, 0, 0, 1, 0),
(28837, 0, 4, 750, 1256, 0, 0, 1, 0),
(28837, 1, 4, 750, 1256, 0, 0, 1, 0),
(28837, 2, 4, 750, 1256, 0, 0, 1, 0),
(28837, 3, -1, 750, 1256, 0, 0, 1, 0),
(28840, 0, 4, 750, 1256, 0, 0, 1, 0),
(28840, 1, 4, 750, 1256, 0, 0, 1, 0),
(28840, 2, 4, 750, 1256, 0, 0, 1, 0),
(28840, 3, -1, 750, 1256, 0, 0, 1, 0),
(28841, 0, -1, 750, 1256, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28518, 0, 0, 6436, -4311, 0),
(28518, 0, 1, 6432, -4301, 0),
(28518, 0, 2, 6421, -4296, 0),
(28518, 0, 3, 6410, -4301, 0),
(28518, 0, 4, 6406, -4311, 0),
(28518, 0, 5, 6410, -4322, 0),
(28518, 0, 6, 6421, -4326, 0),
(28518, 0, 7, 6432, -4322, 0),
(28518, 1, 0, 6539, -4116, 0),
(28530, 0, 0, 6806, -3042, 0),
(28530, 0, 1, 6793, -3010, 0),
(28530, 0, 2, 6761, -2997, 0),
(28530, 0, 3, 6729, -3010, 0),
(28530, 0, 4, 6716, -3042, 0),
(28530, 0, 5, 6729, -3073, 0),
(28530, 0, 6, 6761, -3087, 0),
(28530, 0, 7, 6793, -3073, 0),
(28530, 1, 0, 6804, -2948, 0),
(28530, 1, 1, 6791, -2916, 0),
(28530, 1, 2, 6759, -2903, 0),
(28530, 1, 3, 6728, -2916, 0),
(28530, 1, 4, 6714, -2948, 0),
(28530, 1, 5, 6728, -2980, 0),
(28530, 1, 6, 6759, -2993, 0),
(28530, 1, 7, 6791, -2980, 0),
(28530, 2, 0, 6396, -2537, 0),
(28540, 0, 0, 6406, -2771, 0),
(28540, 0, 1, 6402, -2760, 0),
(28540, 0, 2, 6391, -2756, 0),
(28540, 0, 3, 6381, -2760, 0),
(28540, 0, 4, 6376, -2771, 0),
(28540, 0, 5, 6381, -2781, 0),
(28540, 0, 6, 6391, -2786, 0),
(28540, 0, 7, 6402, -2781, 0),
(28540, 1, 0, 6720, -4713, 0),
(28631, 0, 0, 6753, -4639, 0),
(28837, 0, 0, 5973, -4350, 0),
(28837, 0, 1, 5964, -4327, 0),
(28837, 0, 2, 5942, -4318, 0),
(28837, 0, 3, 5919, -4327, 0),
(28837, 0, 4, 5910, -4350, 0),
(28837, 0, 5, 5919, -4372, 0),
(28837, 0, 6, 5942, -4381, 0),
(28837, 0, 7, 5964, -4372, 0),
(28837, 1, 0, 6078, -4636, 0),
(28837, 1, 1, 6071, -4620, 0),
(28837, 1, 2, 6054, -4613, 0),
(28837, 1, 3, 6037, -4620, 0),
(28837, 1, 4, 6030, -4636, 0),
(28837, 1, 5, 6037, -4653, 0),
(28837, 1, 6, 6054, -4660, 0),
(28837, 1, 7, 6071, -4653, 0),
(28837, 2, 0, 5963, -4624, 0),
(28837, 2, 1, 5956, -4607, 0),
(28837, 2, 2, 5940, -4601, 0),
(28837, 2, 3, 5923, -4607, 0),
(28837, 2, 4, 5917, -4624, 0),
(28837, 2, 5, 5923, -4640, 0),
(28837, 2, 6, 5940, -4647, 0),
(28837, 2, 7, 5956, -4640, 0),
(28837, 3, 0, 6110, -4189, 0),
(28840, 0, 0, 5453, -4507, 0),
(28840, 0, 1, 5447, -4491, 0),
(28840, 0, 2, 5431, -4485, 0),
(28840, 0, 3, 5416, -4491, 0),
(28840, 0, 4, 5409, -4507, 0),
(28840, 0, 5, 5416, -4522, 0),
(28840, 0, 6, 5431, -4529, 0),
(28840, 0, 7, 5447, -4522, 0),
(28840, 1, 0, 5513, -4497, 0),
(28840, 1, 1, 5506, -4481, 0),
(28840, 1, 2, 5489, -4474, 0),
(28840, 1, 3, 5472, -4481, 0),
(28840, 1, 4, 5466, -4497, 0),
(28840, 1, 5, 5472, -4514, 0),
(28840, 1, 6, 5489, -4521, 0),
(28840, 1, 7, 5506, -4514, 0),
(28840, 2, 0, 5391, -4510, 0),
(28840, 2, 1, 5386, -4500, 0),
(28840, 2, 2, 5376, -4495, 0),
(28840, 2, 3, 5365, -4500, 0),
(28840, 2, 4, 5361, -4510, 0),
(28840, 2, 5, 5365, -4521, 0),
(28840, 2, 6, 5376, -4525, 0),
(28840, 2, 7, 5386, -4521, 0),
(28840, 3, 0, 6110, -4189, 0),
(28841, 0, 0, 6110, -4189, 0);

-- Check after applying + restart (expect 7 / 7 / 0):
--   SELECT COUNT(*) FROM `item_template` WHERE `entry` IN (64441, 64449, 64465, 64664, 65903, 66052, 66060);
--   .additem 64441 in game (fails silently when the server Item.dbc lacks the row)
--   SELECT COUNT(*) FROM `creature_queststarter` WHERE `quest` IN (28518, 28530, 28540, 28631, 28837, 28840, 28841);
--   SELECT COUNT(*) FROM `quest_template_addon` WHERE `ID` = 28631 AND `ExclusiveGroup` <> 0;
