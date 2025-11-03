-- =====================================================================
-- DUNGEON QUEST NPC SYSTEM v2.0 - QUEST TEMPLATE DEFINITIONS (CORRECTED)
-- =====================================================================
-- Purpose: Define all dungeon quests with proper flags and settings
-- Status: Production Ready - Schema Corrected for AzerothCore
-- Version: 2.1 (Fixed column names)
-- Date: 2025-11-03
-- =====================================================================

SET FOREIGN_KEY_CHECKS=0;

-- Clean up existing entries
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700101 AND 700999;
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700101 AND 700999;

-- =====================================================================
-- DAILY QUESTS (700101-700104) - Auto-reset every 24h
-- =====================================================================

INSERT INTO `quest_template` 
(`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`)
VALUES
-- Daily Quest 1: Ragefire Chasm Challenge
(700101, 2, 55, 55, 389, 1, 0, 0, 0, 0, 0, 0, 2, 1000, 0, 0, 0, 0, 0, 0, 0x0800, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Daily: Ragefire Challenge', 'Clear all mobs in Ragefire Chasm', 'Complete this daily dungeon challenge for rewards.$B$BThis quest resets daily at 06:00 server time.', '', 'Quest complete!', 7047, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Taragaman', '', '', ''),

-- Daily Quest 2: Blackfathom Deeps Challenge
(700102, 2, 55, 55, 400, 1, 0, 0, 0, 0, 0, 0, 2, 1000, 0, 0, 0, 0, 0, 0, 0x0800, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Daily: Blackfathom Challenge', 'Clear all mobs in Blackfathom Deeps', 'Complete this daily dungeon challenge for rewards.$B$BThis quest resets daily at 06:00 server time.', '', 'Quest complete!', 4887, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Aku\'mai', '', '', ''),

-- Daily Quest 3: Gnomeregan Challenge
(700103, 2, 55, 55, 412, 1, 0, 0, 0, 0, 0, 0, 2, 1000, 0, 0, 0, 0, 0, 0, 0x0800, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Daily: Gnomeregan Challenge', 'Clear all mobs in Gnomeregan', 'Complete this daily dungeon challenge for rewards.$B$BThis quest resets daily at 06:00 server time.', '', 'Quest complete!', 7800, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Mekgineer Thermaplugg', '', '', ''),

-- Daily Quest 4: Shadowfang Keep Challenge
(700104, 2, 55, 55, 436, 1, 0, 0, 0, 0, 0, 0, 2, 1000, 0, 0, 0, 0, 0, 0, 0x0800, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Daily: Shadowfang Challenge', 'Clear all mobs in Shadowfang Keep', 'Complete this daily dungeon challenge for rewards.$B$BThis quest resets daily at 06:00 server time.', '', 'Quest complete!', 3914, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Baron Silverlaine', '', '', '');

-- =====================================================================
-- WEEKLY QUESTS (700201-700204) - Auto-reset every 7 days
-- =====================================================================

INSERT INTO `quest_template` 
(`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`)
VALUES
-- Weekly Quest 1: Classic Dungeon Mastery
(700201, 2, 55, 55, 389, 1, 0, 0, 0, 0, 0, 0, 2, 1500, 0, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Weekly: Classic Mastery', 'Complete 4 classic dungeons', 'Show your mastery of classic dungeons!$B$BThis quest resets weekly on Tuesday at 06:00 server time.', '', 'Quest complete!', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Complete Ragefire Chasm', 'Complete Shadowfang Keep', 'Complete Blackfathom Deeps', 'Complete Gnomeregan'),

-- Weekly Quest 2: TBC Dungeon Mastery
(700202, 2, 62, 62, 3791, 1, 0, 0, 0, 0, 0, 0, 2, 1500, 0, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Weekly: TBC Mastery', 'Complete 4 Burning Crusade dungeons', 'Show your mastery of Outland dungeons!$B$BThis quest resets weekly on Tuesday at 06:00 server time.', '', 'Quest complete!', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Complete Hellfire Ramparts', 'Complete Blood Furnace', 'Complete Slave Pens', 'Complete Underbog'),

-- Weekly Quest 3: WotLK Dungeon Mastery
(700203, 2, 68, 68, 4395, 1, 0, 0, 0, 0, 0, 0, 2, 1500, 0, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Weekly: WotLK Mastery', 'Complete 4 Northrend dungeons', 'Show your mastery of frozen Northrend dungeons!$B$BThis quest resets weekly on Tuesday at 06:00 server time.', '', 'Quest complete!', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Complete Utgarde Keep', 'Complete Nexus', 'Complete Azjol-Nerub', 'Complete Ahn\'kahet'),

-- Weekly Quest 4: Ultimate Dungeon Challenge
(700204, 2, 68, 68, 4395, 1, 0, 0, 0, 0, 0, 0, 2, 1500, 0, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Weekly: Ultimate Challenge', 'Complete 1 dungeon on hard mode', 'Face the ultimate challenge!$B$BThis quest resets weekly on Tuesday at 06:00 server time.', '', 'Quest complete!', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Complete a heroic dungeon', '', '', '');

-- =====================================================================
-- DUNGEON QUESTS (Sample - 700701-700708)
-- =====================================================================

INSERT INTO `quest_template` 
(`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`)
VALUES
-- Ragefire Chasm Quests
(700701, 2, 55, 55, 389, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Ragefire Quest 1', 'Clear Ragefire Chasm', 'Venture into the volcanic depths and prove your worth!', '', 'Quest complete!', 7047, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Taragaman the Hungerer', '', '', ''),

(700702, 2, 55, 55, 389, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Ragefire Quest 2', 'Defeat all bosses in Ragefire', 'Challenge the bosses of Ragefire Chasm!', '', 'Quest complete!', 7047, 11517, 11518, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Taragaman', 'Defeat Jergosh', 'Defeat Bazzalan', ''),

-- Blackfathom Deeps Quests
(700703, 2, 55, 55, 400, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Blackfathom Quest 1', 'Explore Blackfathom Deeps', 'Discover the secrets of the deep waters!', '', 'Quest complete!', 4887, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Ghamoo-ra', '', '', ''),

(700704, 2, 55, 55, 400, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Blackfathom Quest 2', 'Defeat Aku\'mai', 'Face the deep ones and emerge victorious!', '', 'Quest complete!', 4887, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Aku\'mai', '', '', ''),

-- Gnomeregan Quests
(700705, 2, 55, 55, 412, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Gnomeregan Quest 1', 'Clear Gnomeregan', 'Navigate the mechanical madness!', '', 'Quest complete!', 7800, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Mekgineer Thermaplugg', '', '', ''),

(700706, 2, 55, 55, 412, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Gnomeregan Quest 2', 'Defeat all bosses', 'Master the mechanical dungeon!', '', 'Quest complete!', 7800, 7361, 6229, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Thermaplugg', 'Defeat Electrocutioner', 'Defeat Crowd Pummeler', ''),

-- Shadowfang Keep Quests
(700707, 2, 55, 55, 436, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowfang Quest 1', 'Clear Shadowfang Keep', 'Cleanse the cursed keep!', '', 'Quest complete!', 3914, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Baron Silverlaine', '', '', ''),

(700708, 2, 55, 55, 436, 1, 5, 0, 0, 0, 0, 0, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowfang Quest 2', 'Defeat Arugal', 'End the curse of Arugal!', '', 'Quest complete!', 4275, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Defeat Archmage Arugal', '', '', '');

-- =====================================================================
-- QUEST_TEMPLATE_ADDON - Additional Quest Settings
-- =====================================================================

DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700101 AND 700999;

INSERT INTO `quest_template_addon`
(`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepFaction`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
VALUES
-- Daily quests (SpecialFlags = 1 for QUEST_SPECIAL_FLAGS_REPEATABLE)
(700101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700102, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700103, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),

-- Weekly quests (SpecialFlags = 1 for QUEST_SPECIAL_FLAGS_REPEATABLE)
(700201, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700202, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700203, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(700204, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),

-- Dungeon quests (sample) - Normal quests
(700701, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700702, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700703, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700704, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700705, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700706, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700707, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700708, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

SET FOREIGN_KEY_CHECKS=1;

-- =====================================================================
-- NOTES - IMPORTANT SCHEMA CHANGES FROM v2.0
-- =====================================================================

-- COLUMN NAME CORRECTIONS:
-- Old Name              → New Name (Actual Schema)
-- ----------------------------------------
-- Method                → QuestType
-- Level                 → QuestLevel
-- ZoneOrSort            → QuestSortID
-- Type                  → QuestInfoID
-- SuggestedPlayers      → SuggestedGroupNum
-- LimitTime             → TimeAllowed
-- RewardKillingBlows    → RewardKillHonor
-- RewardChoiceItemId1   → RewardChoiceItemID1
-- RewardChoiceAmount1   → RewardChoiceItemQuantity1
-- PointMapId            → POIContinent
-- PointX                → POIx
-- PointY                → POIy
-- Title                 → LogTitle
-- Objectives            → LogDescription
-- Details               → QuestDescription
-- CompletedText         → QuestCompletionLog
-- ReqItemId1            → RequiredItemId1
-- ReqItemCount1         → RequiredItemCount1
-- ReqCreatureOrGOId1    → RequiredNpcOrGo1
-- ReqCreatureOrGOCount1 → RequiredNpcOrGoCount1

-- quest_template_addon columns removed:
-- - StartItemID (doesn't exist)
-- - flags (doesn't exist)

-- KEY POINTS:
-- 1. Daily quests (700101-700104): Flags = 0x0800 (QUEST_FLAGS_DAILY)
--    - Auto-reset every 24 hours at daily reset time (default 06:00)
--    - AzerothCore handles resets automatically!
--
-- 2. Weekly quests (700201-700204): Flags = 0x1000 (QUEST_FLAGS_WEEKLY)
--    - Auto-reset every 7 days at weekly reset time (default Tuesday 06:00)
--    - AzerothCore handles resets automatically!
--
-- 3. Dungeon quests (700701-700999): Flags = 0
--    - One-time quests (no repeating unless manually reset)
--
-- 4. SpecialFlags in quest_template_addon:
--    - 1 = QUEST_SPECIAL_FLAGS_REPEATABLE (allows repeating)
--    - Set for daily/weekly quests
--
-- 5. NO custom reset code needed - AzerothCore handles everything!
--
-- 6. Token rewards are handled in C++ script using:
--    - dc_daily_quest_token_rewards table
--    - dc_weekly_quest_token_rewards table

-- =====================================================================
-- END OF FILE
-- =====================================================================
