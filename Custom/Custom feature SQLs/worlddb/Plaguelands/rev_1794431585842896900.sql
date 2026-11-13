-- DarkChaos: map 750 - "Vorsha the Lasher" for the map-750 Muglash, and the map-750 Felwood and Ashenvale NPCs
-- moved onto DC copies of their stock scripts
--
-- Follow-up to the 11-11 quest-gap batch, which listed 35 quests still given only by old-world NPCs. Checked again,
-- 23 of them are already given on map 750 as copies at raw id + 100000 (HyjalCata): Cleansing Felwood and the
-- Salve quests (104101-104112, 105882-105891 at 3709528 / 3709529) and Corrupted Songflower (103363 at the 750
-- Songflower 4071942). 4443 is the same Corrupted Whipper Root quest the 750 Whipper Root 4064888 gives as 104117.
-- Only 6641 needs a new copy; the other 10 stay old-world only (see the 11-11 notes).
--
-- 1. 3709528 / 3709529 ran the stock npcs_riverbreeze_and_silversky, which compares the creature entry with
--    9528 / 9529 and so sent no window at all: none of their 22 quests could be taken. They now run
--    npc_dc_riverbreeze_and_silversky (src/server/scripts/DC/MountHyjal/zone_felwood_cata.cpp).
-- 2. "Vorsha the Lasher" 6641 -> 206641 (QuestLevel -1, MinLevel 86 for the Ashenvale band 88-98,
--    RewardMoney 104620, the Horn Ring 17692 swapped for the band's ring 420356), given by the map-750
--    Muglash 3712717 and turned in at the map-750 Warsong Runner 3712863. Muglash now runs npc_dc_muglash
--    (src/server/scripts/DC/MountHyjal/zone_ashenvale_cata.cpp), a copy of the stock escort that starts for the
--    copied quest and uses the map-750 brazier, naga and Vorsha.
-- 3. The escort's data: Muglash's 30 waypoints copied to 3712717 (map 750 keeps Kalimdor's coordinates); Vorsha
--    3712940, a copy of 12940 at level 92 with 332_'s rare values, the loot and money of the level 90-91
--    map-750 naga 3603944, and her model, spells, names and SmartAI; and the two naga copies the escort summons
--    that were still level 19 (3703712, 3703715: never spawned, used by nothing else), raised to 88-89 with
--    332_'s normal values and the loot of their spawned map-750 kin.
--
-- Needs a worldserver built with the two DC scripts (zone_ashenvale_cata.cpp is a new file: re-run cmake first).
-- Applied before that build, the Felwood NPCs open a plain quest window and the escort does not start.
-- Re-running gives the same result. Apply to acore_world, then restart.

-- 1. the DC copies of the stock scripts
UPDATE `creature_template` SET `ScriptName` = 'npc_dc_riverbreeze_and_silversky' WHERE `entry` IN (3709528, 3709529);
UPDATE `creature_template` SET `ScriptName` = 'npc_dc_muglash' WHERE `entry` = 3712717;

-- 2. the quest copy, recorded in the 11-10 clone tables (this file's rows only)
DELETE FROM `dc_quest_clone` WHERE `src` = 6641;
INSERT INTO `dc_quest_clone` (`src`, `dst`, `map`, `zone`, `min_level`) VALUES
(6641, 206641, 750, 4931, 86);
DELETE FROM `dc_quest_link` WHERE `quest` = 6641;
INSERT INTO `dc_quest_link` (`kind`, `eid`, `quest`, `dst`) VALUES
('CE', 3712863, 6641, 206641),
('CS', 3712717, 6641, 206641);

-- quest_template: every column copied; ID, QuestLevel, MinLevel, RewardMoney and RewardItem1 rewritten
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`,
    `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`,
    `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`,
    `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`,
    `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`,
    `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`,
    `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`,
    `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`,
    `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`,
    `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`,
    `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`,
    `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`,
    `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
    `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`,
    `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`,
    `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`,
    `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`,
    `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT 206641, `QuestType`, -1, 86, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`,
    `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`,
    104620, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`,
    `StartItem`, `Flags`, `RequiredPlayerKills`, 420356, `RewardAmount1`, `RewardItem2`, `RewardAmount2`,
    `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`,
    `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`,
    `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`,
    `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`,
    `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`,
    `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`,
    `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`,
    `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`,
    `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
    `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`,
    `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`,
    `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`,
    `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`,
    `Unknown0`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`
FROM `quest_template` WHERE `ID` = 6641;

-- addon (no chain, no reward mail), texts, emotes and their locales
REPLACE INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`,
    `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`,
    `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`,
    `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT 206641, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`,
    `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`,
    `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`,
    `ProvidedItemCount`, `SpecialFlags`
FROM `quest_template_addon` WHERE `ID` = 6641;
DELETE FROM `quest_details` WHERE `ID` = 206641;
INSERT INTO `quest_details` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `VerifiedBuild`)
SELECT 206641, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, 0
FROM `quest_details` WHERE `ID` = 6641;
DELETE FROM `quest_offer_reward` WHERE `ID` = 206641;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT 206641, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
    `RewardText`, 0
FROM `quest_offer_reward` WHERE `ID` = 6641;
DELETE FROM `quest_request_items` WHERE `ID` = 206641;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT 206641, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, 0
FROM `quest_request_items` WHERE `ID` = 6641;
DELETE FROM `quest_template_locale` WHERE `ID` = 206641;
INSERT INTO `quest_template_locale` (`ID`, `locale`, `Title`, `Details`, `Objectives`, `EndText`, `CompletedText`,
    `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT 206641, `locale`, `Title`, `Details`, `Objectives`, `EndText`, `CompletedText`, `ObjectiveText1`,
    `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, 0
FROM `quest_template_locale` WHERE `ID` = 6641;
DELETE FROM `quest_offer_reward_locale` WHERE `ID` = 206641;
INSERT INTO `quest_offer_reward_locale` (`ID`, `locale`, `RewardText`, `VerifiedBuild`)
SELECT 206641, `locale`, `RewardText`, 0
FROM `quest_offer_reward_locale` WHERE `ID` = 6641;

-- giver and turn-in (both entries spawn on map 750 only)
DELETE FROM `creature_queststarter` WHERE `quest` = 206641;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3712717, 206641);
DELETE FROM `creature_questender` WHERE `quest` = 206641;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3712863, 206641);

-- map markers: the stock ones (map 1, Ashenvale) on map 750's Ashenvale
DELETE FROM `quest_poi` WHERE `QuestID` = 206641;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`)
SELECT 206641, `id`, `ObjectiveIndex`, 750, 1261, `Floor`, `Priority`, `Flags`, 0
FROM `quest_poi` WHERE `QuestID` = 6641;
DELETE FROM `quest_poi_points` WHERE `QuestID` = 206641;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 206641, `Idx1`, `Idx2`, `X`, `Y`, 0
FROM `quest_poi_points` WHERE `QuestID` = 6641;

-- 3. the escort: Muglash's path for the map-750 copy
DELETE FROM `script_waypoint` WHERE `entry` = 3712717;
INSERT INTO `script_waypoint` (`entry`, `pointid`, `location_x`, `location_y`, `location_z`, `waittime`,
    `point_comment`)
SELECT 3712717, `pointid`, `location_x`, `location_y`, `location_z`, `waittime`, `point_comment`
FROM `script_waypoint` WHERE `entry` = 12717;

-- Vorsha the Lasher on map 750: HealthModifier 4.3181 / DamageModifier 3.1902 = 5x a level-92 player's
-- HP, 6% of it per average swing
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`,
    `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`,
    `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`,
    `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`,
    `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 3712940, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`,
    `name`, `subname`, `IconName`, `gossip_menu_id`, 92, 92, 2, `faction`, `npcflag`, `speed_walk`, `speed_run`,
    `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, 3.1902, `BaseAttackTime`,
    `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`,
    `family`, `type`, `type_flags`, 3603944, 0, 0, `PetSpellDataId`, `VehicleId`, 9100, 16380, `AIName`,
    `MovementType`, `HoverHeight`, 4.3181, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`,
    `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, 0
FROM `creature_template` WHERE `entry` = 12940;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3712940;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`)
SELECT 3712940, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0
FROM `creature_template_model` WHERE `CreatureID` = 12940;
DELETE FROM `creature_template_spell` WHERE `CreatureID` = 3712940;
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT 3712940, `Index`, `Spell`, 0
FROM `creature_template_spell` WHERE `CreatureID` = 12940;
DELETE FROM `creature_template_locale` WHERE `entry` = 3712940;
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`)
SELECT 3712940, `locale`, `Name`, `Title`, 0
FROM `creature_template_locale` WHERE `entry` = 12940;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3712940 AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
    `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`,
    `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`,
    `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 3712940, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`,
    `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
    `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`,
    `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `entryorguid` = 12940 AND `source_type` = 0;

-- the naga the escort summons that had only level-19 copies
UPDATE `creature_template` SET `minlevel` = 88, `maxlevel` = 89, `exp` = 2, `HealthModifier` = 2.3596,
    `DamageModifier` = 2.6395, `lootid` = 3603713, `mingold` = 8900, `maxgold` = 16020 WHERE `entry` = 3703712;
UPDATE `creature_template` SET `minlevel` = 88, `maxlevel` = 89, `exp` = 2, `HealthModifier` = 2.3596,
    `DamageModifier` = 2.6395, `lootid` = 3603717, `mingold` = 8900, `maxgold` = 16020 WHERE `entry` = 3703715;

-- Revert: ScriptName back to npcs_riverbreeze_and_silversky / npc_muglash; DELETE quest 206641 from quest_template,
-- _addon, the text and locale tables, quest_poi(_points) and the starter/ender tables; DELETE script_waypoint
-- 3712717 and creature_template(_model/_spell/_locale) / smart_scripts of 3712940. The two naga were unused before.
