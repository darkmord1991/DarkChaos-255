-- =====================================================================
-- Molten Front -- 75  Quest import: "Delegation" + "Elemental Bonds: The Vow"
-- ---------------------------------------------------------------------
-- Same gap class as 74_: quests 29234/29331 are referenced by SmartAI
-- (Kalecgos 3652995 Event0/Action62 -> quest 29234; Thrall 3654168
-- Event0/Action1 -> quest 29331) but were never downported ("uses
-- non-existent Quest entry N, skipped" boot-log errors, 2026-07-13).
-- Same transform as 11_quests.sql (see that file's header for the full
-- Cata->fork column-drop notes). PrevQuestID/NextQuestID left dangling by
-- cata_world (29225/29239 for 29234; 29330 for 29331) are NOT part of this
-- port -- nulled out rather than chased into the rest of the Firelands
-- quest line, same call as the Deepholm 28292 fix (round 5, 2026-07-11).
-- Questgivers: Kalecgos (52995/3652995, already ported) starts 29234;
-- Kalecgos quest-ender variant (53009/3653009, ported in 74_) ends it;
-- Thrall (54168/3654168, already ported) ends 29331.
-- =====================================================================
SET @OFF := 3600000;

DELETE FROM `quest_template` WHERE `ID` IN (29234,29331);

INSERT INTO `quest_template`
(`ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,`QuestInfoID`,`SuggestedGroupNum`,
 `RequiredFactionId1`,`RequiredFactionId2`,`RequiredFactionValue1`,`RequiredFactionValue2`,
 `RewardNextQuest`,`RewardXPDifficulty`,`RewardMoney`,`RewardMoneyDifficulty`,`RewardDisplaySpell`,`RewardSpell`,
 `RewardHonor`,`RewardKillHonor`,`StartItem`,`Flags`,`RequiredPlayerKills`,
 `RewardItem1`,`RewardAmount1`,`RewardItem2`,`RewardAmount2`,`RewardItem3`,`RewardAmount3`,`RewardItem4`,`RewardAmount4`,
 `ItemDrop1`,`ItemDropQuantity1`,`ItemDrop2`,`ItemDropQuantity2`,`ItemDrop3`,`ItemDropQuantity3`,`ItemDrop4`,`ItemDropQuantity4`,
 `RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,`RewardChoiceItemID2`,`RewardChoiceItemQuantity2`,`RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,
 `RewardChoiceItemID4`,`RewardChoiceItemQuantity4`,`RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,`RewardChoiceItemID6`,`RewardChoiceItemQuantity6`,
 `POIContinent`,`POIx`,`POIy`,`POIPriority`,`RewardTitle`,`RewardTalents`,`RewardArenaPoints`,
 `RewardFactionID1`,`RewardFactionValue1`,`RewardFactionOverride1`,`RewardFactionID2`,`RewardFactionValue2`,`RewardFactionOverride2`,
 `RewardFactionID3`,`RewardFactionValue3`,`RewardFactionOverride3`,`RewardFactionID4`,`RewardFactionValue4`,`RewardFactionOverride4`,
 `RewardFactionID5`,`RewardFactionValue5`,`RewardFactionOverride5`,`TimeAllowed`,`AllowableRaces`,
 `LogTitle`,`LogDescription`,`QuestDescription`,`AreaDescription`,`QuestCompletionLog`,
 `RequiredNpcOrGo1`,`RequiredNpcOrGo2`,`RequiredNpcOrGo3`,`RequiredNpcOrGo4`,
 `RequiredNpcOrGoCount1`,`RequiredNpcOrGoCount2`,`RequiredNpcOrGoCount3`,`RequiredNpcOrGoCount4`,
 `RequiredItemId1`,`RequiredItemId2`,`RequiredItemId3`,`RequiredItemId4`,`RequiredItemId5`,`RequiredItemId6`,
 `RequiredItemCount1`,`RequiredItemCount2`,`RequiredItemCount3`,`RequiredItemCount4`,`RequiredItemCount5`,`RequiredItemCount6`,
 `Unknown0`,`ObjectiveText1`,`ObjectiveText2`,`ObjectiveText3`,`ObjectiveText4`,`VerifiedBuild`)
SELECT
 q.`ID`,q.`QuestType`,q.`QuestLevel`,q.`MinLevel`,q.`QuestSortID`,q.`QuestInfoID`,q.`SuggestedGroupNum`,
 q.`RequiredFactionId1`,q.`RequiredFactionId2`,q.`RequiredFactionValue1`,q.`RequiredFactionValue2`,
 q.`RewardNextQuest`,q.`RewardXPDifficulty`,q.`RewardMoney`,0,q.`RewardDisplaySpell`,q.`RewardSpell`,
 q.`RewardHonor`,q.`RewardKillHonor`,q.`StartItem`,q.`Flags`,q.`RequiredPlayerKills`,
 q.`RewardItem1`,q.`RewardAmount1`,q.`RewardItem2`,q.`RewardAmount2`,q.`RewardItem3`,q.`RewardAmount3`,q.`RewardItem4`,q.`RewardAmount4`,
 q.`ItemDrop1`,q.`ItemDropQuantity1`,q.`ItemDrop2`,q.`ItemDropQuantity2`,q.`ItemDrop3`,q.`ItemDropQuantity3`,q.`ItemDrop4`,q.`ItemDropQuantity4`,
 q.`RewardChoiceItemID1`,q.`RewardChoiceItemQuantity1`,q.`RewardChoiceItemID2`,q.`RewardChoiceItemQuantity2`,q.`RewardChoiceItemID3`,q.`RewardChoiceItemQuantity3`,
 q.`RewardChoiceItemID4`,q.`RewardChoiceItemQuantity4`,q.`RewardChoiceItemID5`,q.`RewardChoiceItemQuantity5`,q.`RewardChoiceItemID6`,q.`RewardChoiceItemQuantity6`,
 q.`POIContinent`,q.`POIx`,q.`POIy`,q.`POIPriority`,q.`RewardTitle`,q.`RewardTalents`,q.`RewardArenaPoints`,
 q.`RewardFactionID1`,q.`RewardFactionValue1`,q.`RewardFactionOverride1`,q.`RewardFactionID2`,q.`RewardFactionValue2`,q.`RewardFactionOverride2`,
 q.`RewardFactionID3`,q.`RewardFactionValue3`,q.`RewardFactionOverride3`,q.`RewardFactionID4`,q.`RewardFactionValue4`,q.`RewardFactionOverride4`,
 q.`RewardFactionID5`,q.`RewardFactionValue5`,q.`RewardFactionOverride5`,
 COALESCE(qa.`TimeAllowed`,0), (COALESCE(qa.`AllowableRaces`,0) & 0x6FF),
 q.`LogTitle`,q.`LogDescription`,q.`QuestDescription`,q.`AreaDescription`,q.`QuestCompletionLog`,
 q.`RequiredNpcOrGo1`,q.`RequiredNpcOrGo2`,q.`RequiredNpcOrGo3`,q.`RequiredNpcOrGo4`,
 q.`RequiredNpcOrGoCount1`,q.`RequiredNpcOrGoCount2`,q.`RequiredNpcOrGoCount3`,q.`RequiredNpcOrGoCount4`,
 q.`RequiredItemId1`,q.`RequiredItemId2`,q.`RequiredItemId3`,q.`RequiredItemId4`,q.`RequiredItemId5`,q.`RequiredItemId6`,
 q.`RequiredItemCount1`,q.`RequiredItemCount2`,q.`RequiredItemCount3`,q.`RequiredItemCount4`,q.`RequiredItemCount5`,q.`RequiredItemCount6`,
 0,q.`ObjectiveText1`,q.`ObjectiveText2`,q.`ObjectiveText3`,q.`ObjectiveText4`,q.`VerifiedBuild`
FROM `cata_world`.`quest_template` q
LEFT JOIN `cata_world`.`quest_template_addon` qa ON qa.`ID` = q.`ID`
WHERE q.`ID` IN (29234,29331);

DELETE FROM `quest_template_addon` WHERE `ID` IN (29234,29331);

INSERT INTO `quest_template_addon`
(`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,`ExclusiveGroup`,`BreadcrumbForQuestId`,
 `RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
 `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`)
SELECT `ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,0,0,`ExclusiveGroup`,`BreadcrumbForQuestId`,
 `RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
 `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`
FROM `cata_world`.`quest_template_addon`
WHERE `ID` IN (29234,29331);

DELETE FROM `quest_offer_reward` WHERE `ID` IN (29234,29331);
INSERT INTO `quest_offer_reward` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`)
SELECT `ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` WHERE `ID` IN (29234,29331);

DELETE FROM `quest_request_items` WHERE `ID` IN (29234,29331);
INSERT INTO `quest_request_items` (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
SELECT `ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`
FROM `cata_world`.`quest_request_items` WHERE `ID` IN (29234,29331);

DELETE FROM `quest_details` WHERE `ID` IN (29234,29331);
INSERT INTO `quest_details` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`)
SELECT `ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`
FROM `cata_world`.`quest_details` WHERE `ID` IN (29234,29331);

DELETE FROM `quest_poi` WHERE `QuestID` IN (29234,29331);
INSERT INTO `quest_poi` (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT `QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`
FROM `cata_world`.`quest_poi` WHERE `QuestID` IN (29234,29331);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (29234,29331);
INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT `QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` WHERE `QuestID` IN (29234,29331);

-- Questgiver links (offset entries; 3652995/3654168 already ported by earlier
-- Molten Front files, 3653009 ported by 74_molten_front_missing_entities.sql)
DELETE FROM `creature_queststarter` WHERE `id` = 3652995 AND `quest` = 29234;
INSERT INTO `creature_queststarter` (`id`,`quest`) VALUES (3652995,29234);

DELETE FROM `creature_questender` WHERE `id` IN (3653009,3654168) AND `quest` IN (29234,29331);
INSERT INTO `creature_questender` (`id`,`quest`) VALUES (3653009,29234),(3654168,29331);
