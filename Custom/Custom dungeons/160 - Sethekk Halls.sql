-- Sethekk Halls
-- Level 65 - 68 originally
-- map 556

-- NHC
-- update creature_template set minlevel = (minlevel + 90)  where entry in (select id1 from creature where map = 556);
-- update creature_template set maxlevel = (maxlevel + 90) where entry in (select id1 from creature where map = 556);

-- HC
-- select difficulty_entry_1 as entry from creature_template where entry in (select id1 from creature where map = 556);

-- update creature_template set minlevel = (minlevel + 90) where entry in (20692, 20695, 20701, 20693, 20691, 20694, 21989, 20697, 20686, 20688, 21990, 20696, 20699, 20690, 20698, 20706);
-- update creature_template set maxlevel = (maxlevel + 90) where entry in (20692, 20695, 20701, 20693, 20691, 20694, 21989, 20697, 20686, 20688, 21990, 20696, 20699, 20690, 20698, 20706);

update creature_template set HealthModifier = (HealthModifier + 20)  where entry in (select id1 from creature where map = 556);
update creature_template set ManaModifier = (ManaModifier + 20)  where entry in (select id1 from creature where map = 556);

-- update creature_template set HealthModifier = (HealthModifier + 20) where entry in (20692, 20695, 20701, 20693, 20691, 20694, 21989, 20697, 20686, 20688, 21990, 20696, 20699, 20690, 20698, 20706);
-- update creature_template set ManaModifier = (ManaModifier + 20) where entry in (20692, 20695, 20701, 20693, 20691, 20694, 21989, 20697, 20686, 20688, 21990, 20696, 20699, 20690, 20698, 20706);

-- dungeon access template
DELETE FROM `dungeon_access_template` WHERE `id`=56;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES (56, 556, 0, 155, 0, 0, 'Sethekk Halls');
DELETE FROM `dungeon_access_template` WHERE `id`=57;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES (57, 556, 1, 158, 0, 0, 'Sethekk Halls');

-- Questgiver Sethekk Halls
-- 18933 Isfar -> 820005
DELETE FROM `creature_template` WHERE (`entry` = 820005);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(820005, 0, 0, 0, 0, 0, 17865, 0, 0, 0, 'Isfar', '', NULL, 7866, 67, 67, 1, 1818, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 1200, 2000, 1, 1, 2, 32832, 2048, 0, 0, 0, 0, 0, 0, 7, 64, 0, 0, 0, 0, 0, 0, 0, '', 1, 1, 8.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);
update creature_template set subname = 'Sethekk Halls Quests' where entry = 820005;

-- 10097 Brother Against Brother
DELETE FROM `quest_template` WHERE (`ID` = 820050);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardBonusMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(820050, 2, 159, 155, 3688, 81, 0, 0, 0, 0, 0, 0, 8, 82000, 0, 14700, 0, 0, 0, 0, 0, 136, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 29333, 1, 29334, 1, 29335, 1, 29336, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1011, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Brother Against Brother', 'Kill Darkweaver Syth in the Sethekk halls, then free Lakka from captivity. Return to Isfar outside the Sethekk Halls when you\'ve completed the rescue.', 'The Sethekk departed Skettis with great fanfare when Auchindoun exploded. Surely it must\'ve been an omen of our master\'s arrival.$B$BMy brother, Syth, was one of their leaders and told us we were obligated to go into the temple ruins and face our god.$B$BAfter we took up residence in the ruins, calling them the Sethekk Halls, I began to doubt my brother and his ally, Ikiss.$B$BIn time, Syth had me cast out of the Halls, but he refused to let me take our sister Lakka with me. Will you help me rescue her?', NULL, 'Return to Isfar at The Bone Wastes in Terokkar Forest.', 18472, 18956, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'Free Lakka', '', '', 12340);

-- 10098 Terokk's Legacy
DELETE FROM `quest_template` WHERE (`ID` = 820051);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardBonusMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(820051, 2, 159, 155, 3688, 81, 0, 0, 0, 0, 0, 0, 8, 82000, 0, 14700, 0, 0, 0, 0, 32888, 136, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 29330, 1, 29332, 1, 29329, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Terokk\'s Legacy', 'Bring Terokk\'s Mask, Terokk\'s Quill, and the Saga of Terokk to Isfar outside the Sethekk Halls.', 'My people honor an ancient hero named Terokk. Arakkoa hatchlings are regaled with stories of his deeds and descriptions of his beautiful plumage.$B$BHe dwelt among my people for hundreds of years, but mysteriously vanished one day, leaving only his mask, spear, and writings behind.$B$BThe relics are cherished by the arakkoa, but they were heartbroken when the Sethekk bore the objects away from Skettis at their departure.$B$BI have written down what little I know about their location within the halls.', NULL, 'Return to Isfar at The Bone Wastes in Terokkar Forest.', 0, 0, 0, 0, 0, 0, 0, 0, 27634, 27633, 27632, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, '', '', '', '', 12340);

-- Quests for the new NPC
delete from creature_queststarter where id = 820005;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(820005, 820050),
(820005, 820051);

delete from creature_questender where id = 820005;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(820005, 820050),
(820005, 820051);