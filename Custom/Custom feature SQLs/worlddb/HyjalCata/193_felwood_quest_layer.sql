-- ---------------------------------------------------------------------------
-- 193  Felwood (map 750) -- the Cata quest layer
-- ---------------------------------------------------------------------------
-- Stage 2, after 192_ supplied the 46 missing items. Same recipe as the
-- Darkshore pair (189_/190_), applied to the zone 181_/183_ populated.
--
-- SCOPE -- 171 Felwood quests exist in cata_world (QuestSortID = 361).
-- EIGHTY-SEVEN ALREADY EXIST HERE with the same ids -- the vanilla-era Felwood
-- quests that survived the revamp, LIVE ON MAP 1. This file imports only the
-- other 84 and never touches those 87. The id list is PINNED as a literal so
-- that guarantee is auditable from the file and the file stays re-runnable.
--
-- Quest ids stay RAW, matching Hyjal and Darkshore.
--
-- ID REMAPPING (identical rules to 190_):
--   * RequiredNpcOrGo1-4 -- POSITIVE is a creature, NEGATIVE is a gameobject,
--     so the offset moves AWAY from zero: +3,700,000 / -3,700,000.
--   * POIContinent 1 -> 750.
--   * quest_poi WorldMapAreaID 182 (Felwood on map 1) -> 1257 (Felwood on map
--     750, AreaID 4927 -- verified present in WorldMapArea.csv). Darkshore used
--     1259; getting this wrong puts every objective arrow on the wrong map.
--
-- Apply against acore_world AFTER 192_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The 14 creature + 4 gameobject templates the quests reference
-- ---------------------------------------------------------------------------
-- Kill-credit markers and quest-only objects with no spawn of their own, so the
-- spawn-driven imports in 181_/183_ never saw them. All 18 exist in cata_world.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (
  3707108, 3709877, 3747329, 3747365, 3747555, 3748032, 3748042, 3748044, 3748164, 3748200,
  3748227, 3748311, 3748330, 3748352);

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,
     `unit_flags2`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,
     `DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, 0, 0,
       CASE WHEN s.`KillCredit1` > 0 THEN s.`KillCredit1` + 3700000 ELSE 0 END,
       CASE WHEN s.`KillCredit2` > 0 THEN s.`KillCredit2` + 3700000 ELSE 0 END,
       s.`name`, s.`subname`, s.`IconName`, s.`gossip_menu_id`, s.`minlevel`, s.`maxlevel`, s.`faction`,
       COALESCE(s.`npcflag`, 0), s.`speed_walk`, s.`speed_run`, s.`rank`, s.`dmgschool`,
       s.`BaseAttackTime`, s.`RangeAttackTime`, s.`BaseVariance`, s.`RangeVariance`, s.`unit_class`,
       COALESCE(s.`unit_flags`, 0), s.`unit_flags2`, s.`family`, s.`type`, s.`type_flags`,
       0, 0, 0, s.`PetSpellDataId`, s.`VehicleId`, s.`mingold`, s.`maxgold`, '', s.`MovementType`,
       s.`HoverHeight`, s.`HealthModifier`, s.`ManaModifier`, s.`ArmorModifier`, s.`DamageModifier`,
       s.`ExperienceModifier`, s.`RacialLeader`, s.`movementId`, s.`RegenHealth`, s.`flags_extra`, '', s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` IN (
  7108, 9877, 47329, 47365, 47555, 48032, 48042, 48044, 48164, 48200,
  48227, 48311, 48330, 48352);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  3707108, 3709877, 3747329, 3747365, 3747555, 3748032, 3748042, 3748044, 3748164, 3748200,
  3748227, 3748311, 3748330, 3748352);

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry` + 3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (
  7108, 9877, 47329, 47365, 47555, 48032, 48042, 48044, 48164, 48200,
  48227, 48311, 48330, 48352)
  AND m.model > 0;

DELETE FROM `gameobject_template` WHERE `entry` IN (
  3876158, 3876159, 3876160, 3876161);

INSERT INTO `gameobject_template`
    (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
     `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,
     `Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,
     `Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT g.`entry` + 3700000, g.`type`, g.`displayId`, g.`name`, g.`IconName`, g.`castBarCaption`, g.`unk1`, g.`size`,
       g.`Data0`, g.`Data1`, g.`Data2`, g.`Data3`, g.`Data4`, g.`Data5`, g.`Data6`, g.`Data7`, g.`Data8`,
       g.`Data9`, g.`Data10`, g.`Data11`, g.`Data12`, g.`Data13`, g.`Data14`, g.`Data15`, g.`Data16`,
       g.`Data17`, g.`Data18`, g.`Data19`, g.`Data20`, g.`Data21`, g.`Data22`, g.`Data23`, '', '', g.`VerifiedBuild`
FROM `cata_world`.`gameobject_template` g
WHERE g.`entry` IN (
  176158, 176159, 176160, 176161);

-- ---------------------------------------------------------------------------
-- B) quest_template -- the 84 quests we do not already have
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

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
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

-- ---------------------------------------------------------------------------
-- C) quest_template_addon
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

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
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

-- ---------------------------------------------------------------------------
-- D) quest text tables
-- ---------------------------------------------------------------------------
DELETE FROM `quest_offer_reward` WHERE `ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `quest_offer_reward`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,
     `RewardText`,`VerifiedBuild`)
SELECT o.`ID`, o.`Emote1`, o.`Emote2`, o.`Emote3`, o.`Emote4`, o.`EmoteDelay1`, o.`EmoteDelay2`,
       o.`EmoteDelay3`, o.`EmoteDelay4`, o.`RewardText`, o.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` o
WHERE o.`ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

DELETE FROM `quest_request_items` WHERE `ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `quest_request_items`
    (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
SELECT r.`ID`, r.`EmoteOnComplete`, r.`EmoteOnIncomplete`, r.`CompletionText`, r.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` r
WHERE r.`ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

DELETE FROM `quest_details` WHERE `ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `quest_details`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`)
SELECT d.`ID`, d.`Emote1`, d.`Emote2`, d.`Emote3`, d.`Emote4`, d.`EmoteDelay1`, d.`EmoteDelay2`,
       d.`EmoteDelay3`, d.`EmoteDelay4`, d.`VerifiedBuild`
FROM `cata_world`.`quest_details` d
WHERE d.`ID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

-- ---------------------------------------------------------------------------
-- E) Quest relations at +3,700,000
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_queststarter` r
WHERE r.`quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `creature_questender` WHERE `quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `creature_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_questender` r
WHERE r.`quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_queststarter` WHERE `quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_queststarter` r
WHERE r.`quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_questender` WHERE `quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_questender` r
WHERE r.`quest` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

-- ---------------------------------------------------------------------------
-- F) quest_poi / quest_poi_points -- objective arrows, remapped to map 750
-- ---------------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `quest_poi`
    (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`ObjectiveIndex`,
       CASE WHEN p.`MapID` = 1 THEN 750 ELSE p.`MapID` END,
       CASE WHEN p.`WorldMapAreaID` = 182 THEN 1257 ELSE p.`WorldMapAreaID` END,
       p.`Floor`, p.`Priority`, p.`Flags`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi` p
WHERE p.`QuestID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`Idx2`, p.`X`, p.`Y`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` p
WHERE p.`QuestID` IN (
  27989, 27994, 27995, 27997, 28000, 28044, 28049, 28100, 28102, 28113,
  28116, 28119, 28121, 28126, 28128, 28129, 28131, 28148, 28150, 28152,
  28153, 28155, 28190, 28207, 28208, 28213, 28214, 28217, 28218, 28219,
  28220, 28221, 28222, 28224, 28228, 28229, 28256, 28257, 28261, 28264,
  28288, 28305, 28306, 28333, 28334, 28335, 28336, 28337, 28338, 28339,
  28340, 28341, 28342, 28357, 28358, 28359, 28360, 28361, 28362, 28364,
  28365, 28366, 28368, 28370, 28372, 28373, 28374, 28380, 28381, 28382,
  28383, 28384, 28385, 28386, 28387, 28388, 28389, 28392, 28395, 28396,
  28542, 28543, 29028, 29029);

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver restart:
--   SELECT COUNT(*) FROM quest_template WHERE QuestSortID = 361;            -- 171+
--   SELECT COUNT(*) FROM quest_template WHERE ID IN (27989,27995,29029);    -- 3
--   SELECT COUNT(*) FROM quest_poi WHERE MapID = 750 AND WorldMapAreaId = 1257;
--   -- objectives point at map-750 clones, not raw Kalimdor ids (expect 0):
--   SELECT COUNT(*) FROM quest_template WHERE ID BETWEEN 27989 AND 29029
--     AND RequiredNpcOrGo1 BETWEEN 1 AND 3699999;
--   -- no quest gets a starter but no ender of EITHER kind (expect 0):
--   SELECT COUNT(*) FROM creature_queststarter s
--    WHERE s.quest BETWEEN 27989 AND 29029
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = s.quest)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender g WHERE g.quest = s.quest);
--
-- Quests 27989 "Ruumbo Demands Honey" and 27995 "Dance for Ruumbo!" are now
-- present, so the three CataTC Ruumbo scripts become portable -- see 186_.
-- ---------------------------------------------------------------------------
