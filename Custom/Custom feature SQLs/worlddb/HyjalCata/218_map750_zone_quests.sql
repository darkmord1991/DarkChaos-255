-- ---------------------------------------------------------------------------
-- 218  Map 750 -- the quest layer for Ashenvale and Winterspring
-- ---------------------------------------------------------------------------
-- 212_ spawned the questgivers; this gives them something to hand out. 53
-- quests and 92 relations (50 starters, 42 enders) across the creatures in
-- `dc_map750_zoneport`.
--
-- The structure, the column lists and the id arithmetic are lifted verbatim
-- from 190_, which did the same job for Darkshore's 103 quests and has been
-- live since. Only the quest-id set differs, so this inherits every fix that
-- file already absorbed -- notably that RequiredNpcOrGo is SIGNED (positive is
-- a creature, negative a gameobject) and each sign has to be offset in its own
-- direction, and that POIContinent 1 becomes 750.
--
-- QUEST IDS ARE SAFE TO REUSE AS-IS -- checked, not assumed: of the 56 quests
-- these creatures reference, 3 already exist here with the SAME title, and ZERO
-- collide with a different quest. So no renumbering is needed and the ids stay
-- identical to retail, which keeps them comparable against wowhead.
--
-- Apply AFTER 217_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- B) quest_template -- the 53 quests we do not already have
-- ---------------------------------------------------------------------------
-- The id list is PINNED as a literal rather than computed with a live
-- NOT EXISTS against quest_template. Two reasons: the file stays genuinely
-- re-runnable (a computed guard would make the second run a silent no-op once
-- the rows exist), and the promise that the 72 shared vanilla quests are never
-- touched becomes auditable from the file itself instead of depending on what
-- happens to be in the database at apply time.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_template` (
    `ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,`QuestInfoID`,`SuggestedGroupNum`,
     `RequiredFactionId1`,`RequiredFactionId2`,`RequiredFactionValue1`,`RequiredFactionValue2`,
     `RewardNextQuest`,`RewardXPDifficulty`,`RewardMoney`,`RewardDisplaySpell`,`RewardSpell`,`RewardHonor`,
     `RewardKillHonor`,`StartItem`,`Flags`,`RequiredPlayerKills`,`RewardItem1`,`RewardAmount1`,`RewardItem2`,
     `RewardAmount2`,`RewardItem3`,`RewardAmount3`,`RewardItem4`,`RewardAmount4`,`ItemDrop1`,
     `ItemDropQuantity1`,`ItemDrop2`,`ItemDropQuantity2`,`ItemDrop3`,`ItemDropQuantity3`,`ItemDrop4`,
     `ItemDropQuantity4`,`RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,`RewardChoiceItemID2`,
     `RewardChoiceItemQuantity2`,`RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,`RewardChoiceItemID4`,
     `RewardChoiceItemQuantity4`,`RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,`RewardChoiceItemID6`,
     `RewardChoiceItemQuantity6`,`POIContinent`,`POIx`,`POIy`,`POIPriority`,`RewardTitle`,`RewardTalents`,
     `RewardArenaPoints`,`RewardFactionID1`,`RewardFactionValue1`,`RewardFactionOverride1`,`RewardFactionID2`,
     `RewardFactionValue2`,`RewardFactionOverride2`,`RewardFactionID3`,`RewardFactionValue3`,
     `RewardFactionOverride3`,`RewardFactionID4`,`RewardFactionValue4`,`RewardFactionOverride4`,
     `RewardFactionID5`,`RewardFactionValue5`,`RewardFactionOverride5`,`LogTitle`,`LogDescription`,
     `QuestDescription`,`AreaDescription`,`QuestCompletionLog`,`RequiredNpcOrGo1`,`RequiredNpcOrGo2`,
     `RequiredNpcOrGo3`,`RequiredNpcOrGo4`,`RequiredNpcOrGoCount1`,`RequiredNpcOrGoCount2`,
     `RequiredNpcOrGoCount3`,`RequiredNpcOrGoCount4`,`RequiredItemId1`,`RequiredItemId2`,`RequiredItemId3`,
     `RequiredItemId4`,`RequiredItemId5`,`RequiredItemId6`,`RequiredItemCount1`,`RequiredItemCount2`,
     `RequiredItemCount3`,`RequiredItemCount4`,`RequiredItemCount5`,`RequiredItemCount6`,`ObjectiveText1`,
     `ObjectiveText2`,`ObjectiveText3`,`ObjectiveText4`,`VerifiedBuild`,`AllowableRaces`,
     `RewardMoneyDifficulty`,`TimeAllowed`,`Unknown0`)
SELECT
    q.`ID`, q.`QuestType`, q.`QuestLevel`, q.`MinLevel`, q.`QuestSortID`, q.`QuestInfoID`,
    q.`SuggestedGroupNum`, q.`RequiredFactionId1`, q.`RequiredFactionId2`, q.`RequiredFactionValue1`,
    q.`RequiredFactionValue2`, q.`RewardNextQuest`, q.`RewardXPDifficulty`, q.`RewardMoney`,
    q.`RewardDisplaySpell`, q.`RewardSpell`, q.`RewardHonor`, q.`RewardKillHonor`, q.`StartItem`, q.`Flags`,
    q.`RequiredPlayerKills`, q.`RewardItem1`, q.`RewardAmount1`, q.`RewardItem2`, q.`RewardAmount2`,
    q.`RewardItem3`, q.`RewardAmount3`, q.`RewardItem4`, q.`RewardAmount4`, q.`ItemDrop1`,
    q.`ItemDropQuantity1`, q.`ItemDrop2`, q.`ItemDropQuantity2`, q.`ItemDrop3`, q.`ItemDropQuantity3`,
    q.`ItemDrop4`, q.`ItemDropQuantity4`, q.`RewardChoiceItemID1`, q.`RewardChoiceItemQuantity1`,
    q.`RewardChoiceItemID2`, q.`RewardChoiceItemQuantity2`, q.`RewardChoiceItemID3`,
    q.`RewardChoiceItemQuantity3`, q.`RewardChoiceItemID4`, q.`RewardChoiceItemQuantity4`,
    q.`RewardChoiceItemID5`, q.`RewardChoiceItemQuantity5`, q.`RewardChoiceItemID6`,
    q.`RewardChoiceItemQuantity6`, CASE WHEN q.`POIContinent` = 1 THEN 750 ELSE q.`POIContinent` END, q.`POIx`,
    q.`POIy`, q.`POIPriority`, q.`RewardTitle`, q.`RewardTalents`, q.`RewardArenaPoints`, q.`RewardFactionID1`,
    q.`RewardFactionValue1`, q.`RewardFactionOverride1`, q.`RewardFactionID2`, q.`RewardFactionValue2`,
    q.`RewardFactionOverride2`, q.`RewardFactionID3`, q.`RewardFactionValue3`, q.`RewardFactionOverride3`,
    q.`RewardFactionID4`, q.`RewardFactionValue4`, q.`RewardFactionOverride4`, q.`RewardFactionID5`,
    q.`RewardFactionValue5`, q.`RewardFactionOverride5`, q.`LogTitle`, q.`LogDescription`,
    q.`QuestDescription`, q.`AreaDescription`, q.`QuestCompletionLog`,
    CASE WHEN q.`RequiredNpcOrGo1` > 0 THEN q.`RequiredNpcOrGo1` + 3700000
            WHEN q.`RequiredNpcOrGo1` < 0 THEN q.`RequiredNpcOrGo1` - 3700000 ELSE 0 END,
    CASE WHEN q.`RequiredNpcOrGo2` > 0 THEN q.`RequiredNpcOrGo2` + 3700000
            WHEN q.`RequiredNpcOrGo2` < 0 THEN q.`RequiredNpcOrGo2` - 3700000 ELSE 0 END,
    CASE WHEN q.`RequiredNpcOrGo3` > 0 THEN q.`RequiredNpcOrGo3` + 3700000
            WHEN q.`RequiredNpcOrGo3` < 0 THEN q.`RequiredNpcOrGo3` - 3700000 ELSE 0 END,
    CASE WHEN q.`RequiredNpcOrGo4` > 0 THEN q.`RequiredNpcOrGo4` + 3700000
            WHEN q.`RequiredNpcOrGo4` < 0 THEN q.`RequiredNpcOrGo4` - 3700000 ELSE 0 END,
    q.`RequiredNpcOrGoCount1`, q.`RequiredNpcOrGoCount2`, q.`RequiredNpcOrGoCount3`, q.`RequiredNpcOrGoCount4`,
    q.`RequiredItemId1`, q.`RequiredItemId2`, q.`RequiredItemId3`, q.`RequiredItemId4`, q.`RequiredItemId5`,
    q.`RequiredItemId6`, q.`RequiredItemCount1`, q.`RequiredItemCount2`, q.`RequiredItemCount3`,
    q.`RequiredItemCount4`, q.`RequiredItemCount5`, q.`RequiredItemCount6`, q.`ObjectiveText1`,
    q.`ObjectiveText2`, q.`ObjectiveText3`, q.`ObjectiveText4`, q.`VerifiedBuild`, a.`AllowableRaces`,
    a.`RewardMoneyDifficulty`, a.`TimeAllowed`, 0
FROM `cata_world`.`quest_template` q
LEFT JOIN `cata_world`.`quest_template_addon` a ON a.`ID` = q.`ID`
WHERE q.`ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

-- ---------------------------------------------------------------------------
-- C) quest_template_addon -- chain links, exclusive groups, rep gates
-- ---------------------------------------------------------------------------
-- All 18 of our columns exist in cata's addon table, so this is a straight
-- copy. PrevQuestID / NextQuestID / ExclusiveGroup are quest ids and stay raw
-- like the quests themselves, so the chains survive intact.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_template_addon`
    (`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,`ExclusiveGroup`,
     `RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,
     `RequiredMaxRepFaction`,`RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`,
     `BreadcrumbForQuestId`)
SELECT a.`ID`, a.`MaxLevel`, a.`AllowableClasses`, a.`SourceSpellID`, a.`PrevQuestID`, a.`NextQuestID`,
       a.`ExclusiveGroup`, a.`RewardMailTemplateID`, a.`RewardMailDelay`, a.`RequiredSkillID`,
       a.`RequiredSkillPoints`, a.`RequiredMinRepFaction`, a.`RequiredMaxRepFaction`, a.`RequiredMinRepValue`,
       a.`RequiredMaxRepValue`, a.`ProvidedItemCount`, a.`SpecialFlags`, a.`BreadcrumbForQuestId`
FROM `cata_world`.`quest_template_addon` a
WHERE a.`ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

-- ---------------------------------------------------------------------------
-- D) quest text tables -- offer/request/details
-- ---------------------------------------------------------------------------
DELETE FROM `quest_offer_reward` WHERE `ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_offer_reward`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,
     `RewardText`,`VerifiedBuild`)
SELECT o.`ID`, o.`Emote1`, o.`Emote2`, o.`Emote3`, o.`Emote4`, o.`EmoteDelay1`, o.`EmoteDelay2`,
       o.`EmoteDelay3`, o.`EmoteDelay4`, o.`RewardText`, o.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` o
WHERE o.`ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

DELETE FROM `quest_request_items` WHERE `ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_request_items`
    (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
SELECT r.`ID`, r.`EmoteOnComplete`, r.`EmoteOnIncomplete`, r.`CompletionText`, r.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` r
WHERE r.`ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

DELETE FROM `quest_details` WHERE `ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_details`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`)
SELECT d.`ID`, d.`Emote1`, d.`Emote2`, d.`Emote3`, d.`Emote4`, d.`EmoteDelay1`, d.`EmoteDelay2`,
       d.`EmoteDelay3`, d.`EmoteDelay4`, d.`VerifiedBuild`
FROM `cata_world`.`quest_details` d
WHERE d.`ID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

-- ---------------------------------------------------------------------------
-- E) Quest relations -- who gives and who takes each quest, at +3,700,000
-- ---------------------------------------------------------------------------
-- These are what actually put the "!" over a head. Rows are only inserted when
-- the offset creature/gameobject template really exists on our side, so a
-- questgiver we never imported cannot strand a quest with a starter and no
-- ender (the failure mode 179_ had to clean up on the Hyjal side).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_queststarter` r
WHERE r.`quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `creature_questender` WHERE `quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `creature_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_questender` r
WHERE r.`quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_queststarter` WHERE `quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_queststarter` r
WHERE r.`quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_questender` WHERE `quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_questender` r
WHERE r.`quest` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

-- ---------------------------------------------------------------------------
-- F) quest_poi / quest_poi_points -- the objective arrows on the world map
-- ---------------------------------------------------------------------------
-- 200 POI blobs / 623 points. Two remaps are required or the arrows land on
-- the wrong map entirely:
--     MapID           1  (Kalimdor) -> 750
--     WorldMapAreaID  43  (Ashenvale on map 1)    -> 1261 (area 4931 on map 750)
--                     281 (Winterspring on map 1) -> 1256 (area 4926 on map 750)
-- Both target ids were read out of Custom/CSV DBC/WorldMapArea.csv, not guessed
-- -- 190_ used 42 -> 1259 because it was Darkshore, and inheriting that mapping
-- unchanged would have put every arrow in the wrong zone.
--
-- These quests' POIs also use WorldMapAreaID 688, which is Blackfathom Deeps on
-- MAP 48 -- a dungeon, not part of map 750. It is deliberately left untouched,
-- and the MapID CASE only rewrites 1, so those rows pass through intact.
-- Column shapes differ slightly: cata's quest_poi has both `BlobIndex` and
-- `Idx1` where ours has a single `id`. `Idx1` is the one quest_poi_points
-- joins on, so that is the one that maps to `id` -- using BlobIndex would
-- silently orphan every point. quest_poi_points itself is column-identical.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_poi`
    (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`ObjectiveIndex`,
       CASE WHEN p.`MapID` = 1 THEN 750 ELSE p.`MapID` END,
       CASE WHEN p.`WorldMapAreaID` = 43  THEN 1261
            WHEN p.`WorldMapAreaID` = 281 THEN 1256
            ELSE p.`WorldMapAreaID` END,
       p.`Floor`, p.`Priority`, p.`Flags`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi` p
WHERE p.`QuestID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`Idx2`, p.`X`, p.`Y`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` p
WHERE p.`QuestID` IN (
  13595, 13623, 13624, 13626, 13630, 13632, 13642, 13645, 13646, 13848,
  13883, 13890, 13901, 13920, 13923, 26463, 26464, 26474, 26890, 26894,
  28472, 28479, 28536, 28537, 28609, 28610, 28614, 28615, 28618, 28624,
  28625, 28626, 28627, 28628, 28632, 28639, 28641, 28674, 28676, 28701,
  28703, 28706, 28707, 28710, 28718, 28719, 28745, 28782, 28829, 28830,
  28831, 28847, 28848);

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver restart:
--   SELECT COUNT(*) FROM quest_template WHERE ID IN (13595,13923,28472,28848); -- 4
--   SELECT COUNT(*) FROM quest_template WHERE QuestSortID = 148;               -- 175
--   SELECT COUNT(*) FROM creature_queststarter WHERE id >= 3700000;            -- > 0
--   -- no imported quest ends up with a starter but no ender (expect 0).
--   -- NOTE this must check BOTH ender tables: quests 13521/13528 (Buzzbox
--   -- 413 / 723) are turned in at a GAMEOBJECT, not an NPC, so a
--   -- creature-only check reports them as false stranding.
--   SELECT COUNT(*) FROM creature_queststarter s
--    WHERE s.quest BETWEEN 13595 AND 28848
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = s.quest)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender g WHERE g.quest = s.quest);
--   -- objectives point at map-750 clones, not raw Kalimdor ids (expect 0):
--   SELECT COUNT(*) FROM quest_template WHERE ID IN (13514,13518)
--     AND RequiredNpcOrGo1 BETWEEN 1 AND 3699999;
--
-- The boot log should gain no "Quest ... has RequiredNpcOrGo" or
-- "non-existing item" errors for the 13xxx/26xxx/28xxx range.
-- ---------------------------------------------------------------------------
