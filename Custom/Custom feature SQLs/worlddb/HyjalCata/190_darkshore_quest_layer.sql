-- ---------------------------------------------------------------------------
-- 190  Darkshore (map 750) -- the Cata quest layer
-- ---------------------------------------------------------------------------
-- Stage 2, after 189_ supplied the 56 missing items. 184_ imported Darkshore's
-- creatures and gameobjects but no quests at all, which was the single root
-- cause behind three separate symptoms: 17 of 18 Neltharion Darkshore scripts
-- unreachable, 306 chests empty (fixed in 189_), and a zone you could walk
-- through with nothing to do.
--
-- SCOPE -- 175 Darkshore quests exist in cata_world (QuestSortID = 148).
-- SEVENTY-TWO OF THEM ALREADY EXIST ON OUR SIDE with the same ids: they are the
-- vanilla-era Darkshore quests that survived the revamp, and they are LIVE ON
-- MAP 1. This file imports only the other 103 and never touches those 72 --
-- overwriting them with the Cata revision would have changed real Kalimdor.
--
-- Quest ids stay RAW (no offset). That matches Hyjal, which uses raw 25xxx
-- (193 rows, and zero rows in a 125xxx band), and it means the Neltharion
-- script constants line up without edits when those get ported.
--
-- ID REMAPPING applied on the way in:
--   * RequiredNpcOrGo1-4  -- POSITIVE is a creature and NEGATIVE is a
--     gameobject, so the offset moves AWAY from zero in both directions:
--     +3,700,000 for creatures, -3,700,000 for gameobjects. Getting this
--     backwards would silently point kill-credit at the wrong object type.
--   * POIContinent 1 (Kalimdor) -> 750, so quest POI arrows land on our map.
--   * Everything else is copied verbatim.
--
-- SCHEMA -- 101 of our 105 quest_template columns exist in cata_world too. The
-- 30 cata-only columns are all 4.x additions (currencies, portraits, sounds)
-- and are dropped. Of our 4 extra columns, THREE live in cata's
-- quest_template_addon rather than its quest_template -- AllowableRaces,
-- TimeAllowed and RewardMoneyDifficulty -- so they are pulled across with a
-- LEFT JOIN; Unknown0 gets 0.
--
-- Apply against acore_world AFTER 189_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The 31 creature templates the quests reference but 184_ never imported
-- ---------------------------------------------------------------------------
-- Kill-credit markers, quest-only questgivers and a few objective NPCs that
-- have no spawn of their own in cata_world, so the spawn-driven import in 184_
-- could not see them. All 31 exist in cata_world.creature_template.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (
  3711836, 3732852, 3732911, 3732937, 3732959, 3732960, 3733000, 3733093,
  3733094, 3733095, 3733131, 3733132, 3733133, 3733165, 3733166, 3734010,
  3734323, 3734324, 3734325, 3734331, 3734344, 3734349, 3734371, 3734373,
  3734410, 3734411, 3734422, 3734485, 3742936, 3748736, 3751314);

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
  11836, 32852, 32911, 32937, 32959, 32960, 33000, 33093, 33094, 33095, 33131,
  33132, 33133, 33165, 33166, 34010, 34323, 34324, 34325, 34331, 34344, 34349,
  34371, 34373, 34410, 34411, 34422, 34485, 42936, 48736, 51314);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  3711836, 3732852, 3732911, 3732937, 3732959, 3732960, 3733000, 3733093,
  3733094, 3733095, 3733131, 3733132, 3733133, 3733165, 3733166, 3734010,
  3734323, 3734324, 3734325, 3734331, 3734344, 3734349, 3734371, 3734373,
  3734410, 3734411, 3734422, 3734485, 3742936, 3748736, 3751314);

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry` + 3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (
  11836, 32852, 32911, 32937, 32959, 32960, 33000, 33093, 33094, 33095, 33131,
  33132, 33133, 33165, 33166, 34010, 34323, 34324, 34325, 34331, 34344, 34349,
  34371, 34373, 34410, 34411, 34422, 34485, 42936, 48736, 51314)
  AND m.model > 0;

-- ---------------------------------------------------------------------------
-- B) quest_template -- the 103 quests we do not already have
-- ---------------------------------------------------------------------------
-- The id list is PINNED as a literal rather than computed with a live
-- NOT EXISTS against quest_template. Two reasons: the file stays genuinely
-- re-runnable (a computed guard would make the second run a silent no-op once
-- the rows exist), and the promise that the 72 shared vanilla quests are never
-- touched becomes auditable from the file itself instead of depending on what
-- happens to be in the database at apply time.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

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
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

-- ---------------------------------------------------------------------------
-- C) quest_template_addon -- chain links, exclusive groups, rep gates
-- ---------------------------------------------------------------------------
-- All 18 of our columns exist in cata's addon table, so this is a straight
-- copy. PrevQuestID / NextQuestID / ExclusiveGroup are quest ids and stay raw
-- like the quests themselves, so the chains survive intact.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

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
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

-- ---------------------------------------------------------------------------
-- D) quest text tables -- offer/request/details
-- ---------------------------------------------------------------------------
DELETE FROM `quest_offer_reward` WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `quest_offer_reward`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,
     `RewardText`,`VerifiedBuild`)
SELECT o.`ID`, o.`Emote1`, o.`Emote2`, o.`Emote3`, o.`Emote4`, o.`EmoteDelay1`, o.`EmoteDelay2`,
       o.`EmoteDelay3`, o.`EmoteDelay4`, o.`RewardText`, o.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` o
WHERE o.`ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

DELETE FROM `quest_request_items` WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `quest_request_items`
    (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
SELECT r.`ID`, r.`EmoteOnComplete`, r.`EmoteOnIncomplete`, r.`CompletionText`, r.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` r
WHERE r.`ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

DELETE FROM `quest_details` WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `quest_details`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`VerifiedBuild`)
SELECT d.`ID`, d.`Emote1`, d.`Emote2`, d.`Emote3`, d.`Emote4`, d.`EmoteDelay1`, d.`EmoteDelay2`,
       d.`EmoteDelay3`, d.`EmoteDelay4`, d.`VerifiedBuild`
FROM `cata_world`.`quest_details` d
WHERE d.`ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

-- ---------------------------------------------------------------------------
-- E) Quest relations -- who gives and who takes each quest, at +3,700,000
-- ---------------------------------------------------------------------------
-- These are what actually put the "!" over a head. Rows are only inserted when
-- the offset creature/gameobject template really exists on our side, so a
-- questgiver we never imported cannot strand a quest with a starter and no
-- ender (the failure mode 179_ had to clean up on the Hyjal side).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_queststarter` r
WHERE r.`quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `creature_questender` WHERE `quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `creature_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`creature_questender` r
WHERE r.`quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_queststarter` WHERE `quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_queststarter` r
WHERE r.`quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

DELETE FROM `gameobject_questender` WHERE `quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_questender` r
WHERE r.`quest` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

-- ---------------------------------------------------------------------------
-- F) quest_poi / quest_poi_points -- the objective arrows on the world map
-- ---------------------------------------------------------------------------
-- 200 POI blobs / 623 points. Two remaps are required or the arrows land on
-- the wrong map entirely:
--     MapID           1  (Kalimdor) -> 750
--     WorldMapAreaID  42 (Darkshore on map 1) -> 1259 (Darkshore on map 750,
--                        AreaID 4929 -- verified present in WorldMapArea.csv)
-- Column shapes differ slightly: cata's quest_poi has both `BlobIndex` and
-- `Idx1` where ours has a single `id`. `Idx1` is the one quest_poi_points
-- joins on, so that is the one that maps to `id` -- using BlobIndex would
-- silently orphan every point. quest_poi_points itself is column-identical.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `quest_poi`
    (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`ObjectiveIndex`,
       CASE WHEN p.`MapID` = 1 THEN 750 ELSE p.`MapID` END,
       CASE WHEN p.`WorldMapAreaID` = 42 THEN 1259 ELSE p.`WorldMapAreaID` END,
       p.`Floor`, p.`Priority`, p.`Flags`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi` p
WHERE p.`QuestID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`Idx2`, p.`X`, p.`Y`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` p
WHERE p.`QuestID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513,
  13514, 13515, 13518, 13519, 13520, 13521, 13522, 13523, 13525, 13526,
  13527, 13528, 13529, 13537, 13542, 13543, 13544, 13545, 13546, 13547,
  13554, 13557, 13558, 13560, 13561, 13562, 13563, 13564, 13565, 13566,
  13567, 13568, 13569, 13570, 13572, 13573, 13575, 13576, 13577, 13578,
  13579, 13580, 13581, 13582, 13583, 13584, 13585, 13586, 13587, 13588,
  13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13605, 13608,
  13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896,
  13897, 13898, 13899, 13900, 13902, 13907, 13909, 13910, 13911, 13912,
  13918, 13925, 13940, 13948, 13953, 26379, 26383, 26385, 26757, 26758,
  26759, 28490, 28529);

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver restart:
--   SELECT COUNT(*) FROM quest_template WHERE ID IN (13504,13510,13911,28529); -- 4
--   SELECT COUNT(*) FROM quest_template WHERE QuestSortID = 148;               -- 175
--   SELECT COUNT(*) FROM creature_queststarter WHERE id >= 3700000;            -- > 0
--   -- no imported quest ends up with a starter but no ender (expect 0).
--   -- NOTE this must check BOTH ender tables: quests 13521/13528 (Buzzbox
--   -- 413 / 723) are turned in at a GAMEOBJECT, not an NPC, so a
--   -- creature-only check reports them as false stranding.
--   SELECT COUNT(*) FROM creature_queststarter s
--    WHERE s.quest BETWEEN 13504 AND 28529
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = s.quest)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender g WHERE g.quest = s.quest);
--   -- objectives point at map-750 clones, not raw Kalimdor ids (expect 0):
--   SELECT COUNT(*) FROM quest_template WHERE ID IN (13514,13518)
--     AND RequiredNpcOrGo1 BETWEEN 1 AND 3699999;
--
-- The boot log should gain no "Quest ... has RequiredNpcOrGo" or
-- "non-existing item" errors for the 13xxx/26xxx/28xxx range.
-- ---------------------------------------------------------------------------
