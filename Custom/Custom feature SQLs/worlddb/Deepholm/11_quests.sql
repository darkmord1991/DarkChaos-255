-- =====================================================================
-- Deepholm Downport  --  11  Quests + quest POI  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01/02/04 (templates + spawns) so quest givers/objectives resolve.
--
-- Scope = the 128 quests started OR ended by an NPC/GO spawned on map 646
-- (ids 26244..29338). Both engines use the full TrinityCore quest model, so the
-- objective columns (RequiredNpcOrGo1-4 / RequiredItemId1-6 / ObjectiveText1-4)
-- and text (LogTitle/LogDescription/QuestDescription/AreaDescription) map 1:1.
--
-- Transform notes (Cata 4.3.4 -> this fork's 105-col quest_template):
--   * TimeAllowed + AllowableRaces live in quest_template here (Cata keeps them
--     in quest_template_addon) -> relocated via LEFT JOIN.
--   * AllowableRaces masked with 0x6FF (drop Cata-only Worgen/Goblin race bits;
--     a quest that becomes mask 0 = available to all races, the safe fallback).
--   * Dropped (no column in this fork): RewardBonusMoney, MinimapTargetMark,
--     RewardSkillId/Points, RewardReputationMask, QuestGiver/TurnInPortrait,
--     RequiredSpell, Reward/RequiredCurrency*, QuestGiver/TurnTextWindow/TargetName,
--     SoundAccept/SoundTurnIn.
--   * RewardMoneyDifficulty set 0 (AC index, not Cata's flat bonus money).
--   * RewardFactionID/Value/Override 1-5 map directly (both have them).
--   * quest_poi_points drops Cata BlobIndex.
--
-- KNOWN CAVEATS (data imported as-is; refine later):
--   * Currency rewards are dropped -> the handful of currency-reward quests need a
--     placeholder-item reward (see 03_items_and_spells_MANIFEST.md).
--   * Daily/repeatable Flags are preserved; any daily whose objectives live outside
--     Deepholm (e.g. Molten Front/Firelands) will accept but not complete until that
--     content exists -- disable those Flags if undesired.
--   * QuestSortID is kept as the retail value (5042); if the zone was authored as
--     4922, rewrite 5042->4922 here to group them under Deepholm in the quest log.
--   * quest_template_locale (translations) NOT ported -- enUS text is in quest_template.
-- =====================================================================

-- ---------------------------------------------------------------------
-- quest_template   (full 105-column remap)
-- ---------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

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
WHERE q.`ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

-- ---------------------------------------------------------------------
-- quest_template_addon   (drop AllowableRaces/TimeAllowed -> moved to quest_template)
-- ---------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_template_addon`
(`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,`ExclusiveGroup`,`BreadcrumbForQuestId`,
 `RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
 `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`)
SELECT `ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,`ExclusiveGroup`,`BreadcrumbForQuestId`,
 `RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
 `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`
FROM `cata_world`.`quest_template_addon`
WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

-- ---------------------------------------------------------------------
-- quest_offer_reward / quest_request_items / quest_details   (identical schema)
-- ---------------------------------------------------------------------
DELETE FROM `quest_offer_reward` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_offer_reward` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`)
SELECT `ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

DELETE FROM `quest_request_items` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_request_items` (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
SELECT `ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`
FROM `cata_world`.`quest_request_items` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

DELETE FROM `quest_details` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_details` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`)
SELECT `ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`
FROM `cata_world`.`quest_details` WHERE `ID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

-- ---------------------------------------------------------------------
-- Quest giver links   (creature/gameobject queststarter/questender; id,quest)
-- Scoped to givers spawned on map 646; their quests are exactly the 128 above.
-- ---------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `id` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646);
INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT DISTINCT qs.`id`, qs.`quest` FROM `cata_world`.`creature_queststarter` qs
JOIN `cata_world`.`creature` c ON c.`id` = qs.`id` WHERE c.`map` = 646;

DELETE FROM `creature_questender` WHERE `id` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646);
INSERT INTO `creature_questender` (`id`,`quest`)
SELECT DISTINCT qe.`id`, qe.`quest` FROM `cata_world`.`creature_questender` qe
JOIN `cata_world`.`creature` c ON c.`id` = qe.`id` WHERE c.`map` = 646;

DELETE FROM `gameobject_queststarter` WHERE `id` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646);
INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT DISTINCT gs.`id`, gs.`quest` FROM `cata_world`.`gameobject_queststarter` gs
JOIN `cata_world`.`gameobject` g ON g.`id` = gs.`id` WHERE g.`map` = 646;

DELETE FROM `gameobject_questender` WHERE `id` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646);
INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT DISTINCT ge.`id`, ge.`quest` FROM `cata_world`.`gameobject_questender` ge
JOIN `cata_world`.`gameobject` g ON g.`id` = ge.`id` WHERE g.`map` = 646;

-- ---------------------------------------------------------------------
-- quest_poi  (identical schema)  +  quest_poi_points  (drop BlobIndex)
-- ---------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_poi` (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT `QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`
FROM `cata_world`.`quest_poi` WHERE `QuestID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT `QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` WHERE `QuestID` IN (26244,26245,26246,26247,26255,26256,26258,26259,26260,26261,26312,26313,26314,26315,26326,26328,26375,26376,26377,26409,26410,26411,26413,26426,26436,26437,26438,26439,26441,26484,26499,26500,26501,26502,26507,26537,26564,26575,26576,26577,26578,26579,26580,26581,26582,26584,26585,26591,26625,26632,26656,26657,26658,26659,26709,26710,26750,26752,26755,26762,26766,26768,26770,26771,26791,26792,26827,26828,26829,26831,26832,26833,26834,26835,26836,26857,26861,26869,26871,26875,26876,26971,27004,27005,27006,27007,27008,27010,27040,27041,27042,27043,27046,27047,27049,27050,27051,27058,27059,27061,27100,27101,27102,27123,27126,27135,27136,27931,27932,27933,27934,27935,27936,27937,27938,27952,27953,28292,28293,28390,28391,28488,28824,28866,28869,29329,29337,29338);
