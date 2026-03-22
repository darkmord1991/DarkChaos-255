DELETE FROM `quest_template` WHERE (`ID` = 820056);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(820056, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 300366, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Welcome to Ashzara Crater!', 'Speak with Hervikus and accept his guidance.', 'Greetings, $N! I am Hervikus, watcher of the Ashzara Crater.

This ancient land has never been fully explored. Strange creatures roam the depths, forgotten ruins hold dark secrets, and the crater itself pulses with chaotic energy.

I will be your guide as you begin your journey through these untamed lands. From the peaks to the deepest caverns, every corner holds a new challenge.

Accept my welcome, and let the adventure begin!', 'Speak with Hervikus to begin your journey.', 'May the wilds of Ashzara Crater forge you into a true champion, $N!', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Speak with Hervikus and accept his guidance.', '', '', '', 0);

-- ============================================================
-- Hervikus the Chaotic (NPC 800009) - creature_template
-- ============================================================
DELETE FROM `creature_template` WHERE (`entry` = 800009);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800009, 0, 0, 0, 0, 0, 'Hervikus the Chaotic', 'Welcome to Ashzara Crater', '', 800009, 255, 255, 2, 35, 3, 0.4, 0.4, 1, 1, 20, 0.05, 2, 0, 7.5, 2000, 2000, 1, 1, 1, 32832, 2048, 0, 0, 5, 8, 32487, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 58, 1, 0, 0, 0, 'AC_Quest_NPC_800009', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800009);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800009, 0, 27979, 0.05, 1, 12340);

-- ============================================================
-- Gossip text for Hervikus when player talks to him
-- ============================================================
DELETE FROM `gossip_menu` WHERE `MenuID` = 800009;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (800009, 800009);

DELETE FROM `npc_text` WHERE `ID` = 800009;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
(800009, 'Greetings, $N! I am Hervikus, watcher of the Ashzara Crater.$B$BThis ancient land pulses with chaotic energy. Strange creatures roam the depths, forgotten ruins hold dark secrets, and the crater itself defies all known magic.$B$BSpeak with me if you wish to begin your journey through these untamed lands. I shall be your guide.', 'Greetings, $N! I am Hervikus, watcher of the Ashzara Crater.$B$BThis ancient land pulses with chaotic energy. Strange creatures roam the depths, forgotten ruins hold dark secrets, and the crater itself defies all known magic.$B$BSpeak with me if you wish to begin your journey through these untamed lands. I shall be your guide.', 0, 0, 1, 0, 0, 0, 0, 0, 0);

-- ============================================================
-- Quest chain: 820056 (Welcome) -> 820057 (First Steps) -> 820058 (Seek the Wardens)
-- 820056: Welcome quest (auto-complete, talk to Hervikus)
-- 820057: Find NPC 300002 (first questgiver)
-- 820058: Find NPC 300001 (second questgiver) - replaces old "AC - wolf desease"
-- ============================================================

-- Quest starter/ender for Welcome quest (820056)
DELETE FROM `creature_queststarter` WHERE (`quest` = 820056);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(800009, 820056);
DELETE FROM `creature_questender` WHERE (`quest` = 820056);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(800009, 820056);

DELETE FROM `quest_request_items` WHERE (`ID` = 820056);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(820056, 10, 0, 'The crater awaits you, $N. Are you ready to begin?', 0);

DELETE FROM `quest_offer_reward` WHERE (`ID` = 820056);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(820056, 0, 0, 0, 0, 0, 0, 0, 0, 'The crater reveals its secrets only to the brave, $N. Now go forth and carve your own path through these untamed lands!', 0);

DELETE FROM `quest_template_addon` WHERE (`ID` = 820056);
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`) VALUES
(820056, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ============================================================
-- Quest 820057: "First Steps - Find the Warden" (go talk to NPC 300002)
-- ============================================================
DELETE FROM `quest_template` WHERE (`ID` = 820057);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(820057, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Welcome to Dark Chaos', 'Speak with the Azshara Crater Warden near the starting camp.', 'Welcome to the Dark Chaos realm, $N. The Azshara Crater is a desolate and dangerous place, crawling with custom abominations and challenges that will test your willpower.$B$BBefore you do anything else, you must report to the Crater Warden. He oversees the newly arrived champions and will give you your first real trial. You can find him stationed just past our camp''s borders, keeping a close eye on the monstrosities that lurk below.', 'Just outside the starting camp', 'Speak to the Azshara Crater Warden.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Speak with the Crater Warden', '', '', '', 0);

DELETE FROM `creature_queststarter` WHERE (`quest` = 820057);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(800009, 820057);
DELETE FROM `creature_questender` WHERE (`quest` = 820057);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300002, 820057);

DELETE FROM `quest_request_items` WHERE (`ID` = 820057);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(820057, 6, 0, 'Hervikus sent you? Good. Only the strongest survive in Dark Chaos.', 0);

DELETE FROM `quest_offer_reward` WHERE (`ID` = 820057);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(820057, 1, 0, 0, 0, 0, 0, 0, 0, 'Welcome to Azshara Crater, $N. You have a long and brutal journey ahead of you if you wish to conquer the Dark Chaos.', 0);

DELETE FROM `quest_template_addon` WHERE (`ID` = 820057);
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`) VALUES
(820057, 0, 0, 0, 820056, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ============================================================
-- Quest 820058: "The Watchful Eye" (go talk to NPC 300001) - REPLACES old "AC - Wolf desease"
-- ============================================================
DELETE FROM `quest_template` WHERE (`ID` = 820058);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(820058, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 300365, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'The Watchful Eye', 'Report to the Scout further into the crater.', 'Now that you have spoken with the Warden, you should push further into the crater. There is a Scout stationed deeper within who keeps watch over the creature movements.$B$BSpeak with them and they will point you toward your first real threats. Stay sharp — the wildlife here does not take kindly to newcomers.', 'Deeper in the crater', 'Find the Scout and report for duty.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Speak with the Scout', '', '', '', 0);

-- Remove old wolf desease quest starters/enders for NPC 800009
DELETE FROM `creature_queststarter` WHERE (`quest` = 820058) AND (`id` IN (800009));
DELETE FROM `creature_questender` WHERE (`quest` = 820058) AND (`id` IN (800009));

-- New quest starters/enders for "The Watchful Eye" (820058)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(800009, 820058);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300001, 820058);

DELETE FROM `quest_request_items` WHERE (`ID` = 820058);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(820058, 6, 0, 'The Warden sent you down here? Then you must be ready for what lies ahead.', 0);

DELETE FROM `quest_offer_reward` WHERE (`ID` = 820058);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(820058, 1, 0, 0, 0, 0, 0, 0, 0, 'Good timing, $N. The creatures around here have been growing bolder. I could use someone with your nerve. Let me show you what we are dealing with.', 0);

DELETE FROM `quest_template_addon` WHERE (`ID` = 820058);
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`) VALUES
(820058, 0, 0, 0, 820056, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);