-- DarkChaos map 861: open the Molten Front as the 124-130 tail of map 750 (2026-11-14)
--
-- Why: map 861 (zone 4925, 1,269 creatures, 47 quests) was reachable only through the GM-gated dc_teleporter 413,
-- and most of it was locked even for a GM: the gate quest 29201 needed credit from a bunny that was never spawned,
-- and the Forlorn Spire and Druids of the Talon dailies sat behind two C++ events (29205, 29206) whose controller
-- bunnies are not spawned and which summon their actors into phase 64, a phase nothing on 861 grants.
--
-- What:
--  1. Access. Portal to the Molten Front, GO 831300 (Cata druid portal display 10637), in the Avengers camp on
--     the Throne of Flame shore by Sulfuron Spire (map 750, guid 9037500, 4198.0 -2848.0 1001.3: walkable ground,
--     with the Firelands-route hub NPCs 9036000-9036003); Portal to Mount Hyjal, GO 831301, on 861 16 yd from
--     the arrival point (guid 9037501). Type 22 spellcaster, no spell, SmartGameObjectAI gossip hello -> teleport.
--     861 arrival = dc_teleporter 413 / graveyard 15019 (1021, 394, 42.2); the map-750 arrival (4206.0 -2853.0
--     1001.35) is 9 yd in front of the portal. The Sanctuary of Malorne "Portal to the Firelands"
--     3808900 (named in 29201's text, its Cata spell 99556 is only an aura here) gets the same click-teleport.
--     The two red visual markers 15330001/15330002 of the retired walk-in triggers 9861/9862 are removed.
--     dc_teleporter 413 stays GM-gated (no level gate in that menu; the portal + 29201 is the route).
--  2. Breadcrumb 751330 Gateway to the Molten Front: Ilthaine Ashbough 832300 (guid 9037502) next to the portal
--     -> Malfurion Stormrage 3652135 on 861. BreadcrumbForQuestId 29201, RewardNextQuest 29201: Malfurion on 861
--     now also starts 29201, so the breadcrumb leads straight into the gate quest.
--  3. 29201 Through the Gates of Hell: MinLevel 110 -> 124; its Foothold Kill Credit bunny 3653370 (SmartAI OOC
--     LOS, 25 yd) is spawned at the objective POI, Jarod Shadowsong's post (guid 9037503), and made a trigger.
--  4. Ports from cata_world (one-time, given on 861): 751331 Into the Depths (Cata 29203, kill Leyara 3653366, whose
--     encounter is already spawned) and 751332 Druids of the Talon (Cata 29181; the 150-mark currency cost has no
--     3.3.5 equivalent, so it is a talk quest Malfurion -> Skylord Omnuron). Not ported: 29138 Burn Victims (salve
--     item 69240 has no item_template / Item.dbc row), 29246-29248 (Dordaen not spawned anywhere), the Leyara's
--     Locket chain 29298-29311 (memory-vision events, giver in Moonglade on map 1).
--  5. Gates: the Forlorn Spire dailies 29159 29160 29189 29192 follow 29204 instead of the broken 29205; 29264 (and
--     so the Druids of the Talon dailies) follows 751332 or 29182 instead of the broken 29206.
--  6. Fixes: 29289 Mother's Malice gets its ender (Morthis Whisperwing 3652491); Dried Acorn GO 3808535 gets
--     SmartGameObjectAI so its 29249 credit row loads; Tholo's Thermometer 69806 casts 151265 (How Hot pool check)
--     and Arthorn's Injury Kit 69837 casts 98662 (Patch Up Druid) - both spells are in the server and client
--     Spell.dbc and the targets' SmartAI already credit them; 29278 Living Obsidium gets its 15 Obsidium Meteorite
--     chests (GO 831302, display 10159, Neltharion positions, guids 9037510-9037524, loot 69807).
--     Summon Wisp 98151, Summon Firekin 98183 (29143 Wisp Away) and Summon Anren 98590 (29272 escort) used Cata
--     SummonProperties 2402 / 2987 / 3009, which the 3.3.5 DBC lacks, so the summon failed: their spell_dbc rows
--     (which override Spell.dbc) now use 64, a plain wild summon; the scripts only need the summoner.
--  7. Disabled (`disables`, quest type 1) because they can be taken but never finished: 29139 29205 29206 29210
--     29211 29263 29288, and on map 750 Matoclaw's 29202 / 29284 whose enders do not exist.
--  8. Levels: the 47 quests given on 861 plus the five 750 quests that end there (29201 29182 29215 29280 29282)
--     get QuestLevel -1 / MinLevel 124 (29243 29264 29265 were still 85/85). Hostile mobs exclusive to 861: rank 0
--     128-129 -> 125-127, rank 1 129-130 -> 127-128, so nothing a quest needs is more than 4 above a 124 bot.
--     Rares and bosses (rank 2+) stay 130.
--  9. 120 s respawn on the creature spawns the working 861 quests kill or loot (pooled lieutenants and Leyara
--     keep theirs). Quest chests on 861 are already 120 s.
-- 10. Innkeeper Neryssa Emberglade 832301 (guid 9037504, vendor list of Salirn Moonbear) as the bot hub of zone
--     4925; graveyard_zone 15019 -> 4925 already exists.
-- 11. version.cache_id + 1: two item spells and one GO template changed.
--
-- Re-runnable: templates by REPLACE, every other row block deleted and re-inserted, UPDATEs are absolute.
-- Apply after rev_1794668561596110200.sql. Needs the 861 maps/vmaps/mmaps on the live host; restart afterwards.

-- 1. portals
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
    `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`,
    `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`,
    `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT 831300, 22, 10637, 'Portal to the Molten Front', '', '', '', 1.5, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 0;
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
    `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`,
    `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`,
    `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT 831301, 22, 10637, 'Portal to Mount Hyjal', '', '', '', 1.5, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 0;
UPDATE `gameobject_template` SET `Data0` = 0, `AIName` = 'SmartGameObjectAI' WHERE `entry` = 3808900;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 831300 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
    `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`,
    `target_y`, `target_z`, `target_o`, `comment`)
SELECT 831300, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 861, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1021, 394, 42.2, 5.64,
    'Portal to the Molten Front - On Gossip Hello - Teleport Invoker';
DELETE FROM `smart_scripts` WHERE `entryorguid` = 831301 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
    `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`,
    `target_y`, `target_z`, `target_o`, `comment`)
SELECT 831301, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 750, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 4206, -2853, 1001.35,
    5.72, 'Portal to Mount Hyjal - On Gossip Hello - Teleport Invoker to Sulfuron Spire';
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3808900 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
    `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`,
    `target_y`, `target_z`, `target_o`, `comment`)
SELECT 3808900, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 861, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1021, 394, 42.2, 5.64,
    'Portal to the Firelands - On Gossip Hello - Teleport Invoker to the Molten Front';
DELETE FROM `gameobject` WHERE `guid` IN (15330001, 15330002) AND `id` = 3803083;
DELETE FROM `gameobject` WHERE `guid` IN (9037500, 9037501) AND `id` IN (831300, 831301);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`,
    `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`,
    `state`) VALUES
(9037500, 831300, 750, 4923, 4923, 1, 1, 4198, -2848, 1001.3, 5.72, 0, 0, 0.277886, -0.960614, 300, 100, 1),
(9037501, 831301, 861, 4925, 4925, 1, 1, 1033.3, 404.3, 41.6, 3.84, 0, 0, 0.939645, -0.34215, 300, 100, 1);

-- 2. breadcrumb giver and innkeeper (templates copied from Hyjal Druid 3652501 and Salirn Moonbear 3653779)
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`,
    `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`,
    `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`,
    `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 832300, 0, 0, 0, 0, 0, 'Ilthaine Ashbough', 'Guardians of Hyjal', '', 0, 130, 130, 2, 2252, 3, 1, 1.14286, 1,
    1.14286, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 4096, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2.00439,
    4.08568, 1, 1, 0, 0, 1, 0, 0, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`,
    `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`,
    `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`,
    `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 832301, 0, 0, 0, 0, 0, 'Neryssa Emberglade', 'Innkeeper', '', 0, 130, 130, 2, 2252, 65664, 1, 1.14286, 1, 1, 20,
    0, 0, 0.812272, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0,
    0, '', 0;
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (832300, 832301);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(832300, 0, 31229, 1, 1, 0),
(832301, 0, 33335, 1, 1, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 832301;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT 832301, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, 0 FROM `npc_vendor` WHERE `entry` = 3653779;

-- 3. spawns: breadcrumb giver, 29201 foothold bunny, innkeeper
UPDATE `creature_template` SET `flags_extra` = `flags_extra` | 128 WHERE `entry` = 3653370;
DELETE FROM `creature` WHERE `guid` IN (9037502, 9037503, 9037504) AND `id` IN (832300, 3653370, 832301);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`,
    `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `MovementType`, `Comment`) VALUES
(9037502, 832300, 750, 4923, 4923, 1, 1, 0, 4196, -2836, 1005.55, 4.87, 300, 0, 0, 'MF861 breadcrumb'),
(9037503, 3653370, 861, 4925, 4925, 1, 1, 0, 1028, 342, 41.35, 1.57, 300, 0, 0, 'MF861 29201 credit'),
(9037504, 832301, 861, 4925, 4925, 1, 1, 0, 1040.3, 417, 41.45, 4.01, 300, 0, 0, 'MF861 innkeeper');

-- 4. new quests: 751330 breadcrumb, 751331 Into the Depths (Cata 29203), 751332 Druids of the Talon (Cata 29181)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`,
    `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`,
    `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`,
    `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`,
    `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`,
    `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`,
    `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`,
    `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`,
    `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`,
    `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`,
    `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT 751330, 2, -1, 124, 616, 0, 0, 0, 0, 0, 0, 29201, 2, 47000, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 'Gateway to the Molten Front',
    'Take the druid portal at Sulfuron Spire to the Molten Front and report to Malfurion Stormrage at '
    'Malfurion''s Breach.',
    'The Firelord''s realm lies just beyond this spire, $n. While Hyjal burned, Malfurion Stormrage '
    'led the Guardians of Hyjal through the breach and carved out a foothold on the Molten Front '
    'itself.$B$BOur druids keep a portal open here for those strong enough to stand with him. Step '
    'through, find Malfurion at the breach camp, and lend your strength to the assault on the '
    'Firelord''s domain.',
    '', 'Speak with Malfurion Stormrage at Malfurion''s Breach in the Molten Front.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0;
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`,
    `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`,
    `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`,
    `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`,
    `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`,
    `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`,
    `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`,
    `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`,
    `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`,
    `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`,
    `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT 751331, 2, -1, 124, 616, 0, 3, 0, 0, 0, 0, 0, 6, 188000, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 'Into the Depths', 'Kill Leyara.',
    'Leyara has been spotted in the Igneous Depths. A group of Shadow Wardens has cornered her.$B$BGo '
    'there immediately. I will join you as soon as I make one necessary preparation.',
    '', 'Speak to Malfurion Stormrage at Malfurion''s Breach.', 3653366, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, '', '', '', '', 0;
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`,
    `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`,
    `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`,
    `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`,
    `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`,
    `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`,
    `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`,
    `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`,
    `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`,
    `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`,
    `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT 751332, 2, -1, 124, 616, 0, 0, 0, 0, 0, 0, 0, 6, 188000, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 'Druids of the Talon', 'Ask Skylord Omnuron to bring the Druids of the Talon to the main front.',
    'Skylord Omnuron and his Druids of the Talon have been a fearsome force for us back in Hyjal. I '
    'know that they prefer the familiar skies of that battlefield, but the time has come when we need '
    'them here.$B$BGo to Omnuron and appeal to him that his druids should be on the main front. '
    'Omnuron watches out for his own, but he also understands the importance of this effort.',
    '', 'Secure the aid of the Druids of the Talon from Skylord Omnuron at Malfurion''s Breach.', 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0;
DELETE FROM `quest_template_addon` WHERE `ID` IN (751330, 751331, 751332);
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`,
    `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`,
    `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`,
    `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`) VALUES
(751330, 0, 0, 0, 0, 0, 0, 29201, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(751331, 0, 0, 0, 29201, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(751332, 0, 0, 0, 29201, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
REPLACE INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT 751330, 1, 0, 0, 0, 0, 0, 0, 0,
    'You have come at the right hour, $n. The Firelord''s servants press us on every side, and the '
    'foothold we hold here is narrower than it looks.$B$BCatch your breath. Then let us see what you '
    'can do.',
    0;
REPLACE INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT 751331, 1, 0, 0, 0, 0, 0, 0, 0,
    'Leyara''s tale is a tragic one. It pains me that it came to this.$B$BStaghelm must be stopped, '
    'before he drags anyone else down with him.',
    0;
REPLACE INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT 751332, 1, 0, 0, 0, 0, 0, 0, 0,
    'I see. I can''t say I''m eager to bring my flock to the Firelands, but I knew it would become '
    'necessary at some point.$B$BWe will be there, $c. Thank you for carrying the message.',
    0;
DELETE FROM `creature_queststarter` WHERE `quest` IN (751330, 751331, 751332);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(832300, 751330),
(3652135, 751331),
(3652135, 751332);
DELETE FROM `creature_questender` WHERE `quest` IN (751330, 751331, 751332);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3652135, 751330),
(3652135, 751331),
(3652490, 751332);
DELETE FROM `quest_poi` WHERE `QuestID` IN (751330, 751331, 751332);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(751330, 0, -1, 861, 1255, 0, 0, 1, 0),
(751331, 0, 0, 861, 1255, 0, 0, 1, 0),
(751331, 1, -1, 861, 1255, 0, 0, 1, 0),
(751332, 0, -1, 861, 1255, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (751330, 751331, 751332);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751330, 0, 0, 977, 374, 0),
(751331, 0, 0, 1229, 165, 0),
(751331, 1, 0, 977, 374, 0),
(751332, 0, 0, 1062, 421, 0);

-- 29201: Malfurion on 861 starts it too (the breadcrumb hands over to it), and it opens at 124
DELETE FROM `creature_queststarter` WHERE `id` = 3652135 AND `quest` = 29201;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3652135, 29201);
-- 29289 Mother's Malice had no ender
DELETE FROM `creature_questender` WHERE `id` = 3652491 AND `quest` = 29289;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3652491, 29289);

-- 5. quest levels and gates
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 124 WHERE `ID` IN (29137, 29139, 29141, 29142, 29143, 29159,
    29160, 29179, 29182, 29189, 29192, 29201, 29204, 29205, 29206, 29209, 29210, 29211, 29214, 29215, 29243, 29244,
    29245, 29249, 29254, 29255, 29257, 29263, 29264, 29265, 29272, 29273, 29274, 29275, 29276, 29278, 29279, 29280,
    29281, 29282, 29283, 29287, 29288, 29289, 29290, 29293, 29295, 29296, 29297, 29299, 29304, 29305);
UPDATE `quest_template_addon` SET `PrevQuestID` = 29204 WHERE `ID` IN (29159, 29160, 29189, 29192);
UPDATE `quest_template_addon` SET `PrevQuestID` = 751332 WHERE `ID` = 29264;
-- 29182 (Matoclaw -> Skylord Omnuron) also opens 29264: a NextQuestID adds it to 29264's any-of prerequisites
UPDATE `quest_template_addon` SET `NextQuestID` = 29264 WHERE `ID` = 29182;

-- 6. item spells, Dried Acorn AI, summon properties, Obsidium Meteorites for 29278
UPDATE `gameobject_template` SET `AIName` = 'SmartGameObjectAI' WHERE `entry` = 3808535;
UPDATE `spell_dbc` SET `EffectMiscValueB_1` = 64 WHERE `ID` IN (98151, 98183, 98590);
UPDATE `item_template` SET `spellid_1` = 151265, `spelltrigger_1` = 0, `spellcharges_1` = 0 WHERE `entry` = 69806;
UPDATE `item_template` SET `spellid_1` = 98662, `spelltrigger_1` = 0, `spellcharges_1` = 0 WHERE `entry` = 69837;
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
    `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`,
    `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`,
    `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT 831302, 3, 10159, 'Obsidium Meteorite', '', '', '', 0.6, 43, 831302, 0, 1, 0, 0, 0, 0, 29278, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 831302;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(831302, 69807, 0, 100, 1, 1, 0, 1, 3, 'Obsidium Meteorite - 29278 Living Obsidium');
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9037510 AND 9037524 AND `id` = 831302;
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`,
    `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`,
    `state`) VALUES
(9037510, 831302, 861, 4925, 4925, 1, 1, 1362.05, 380.88, 22.9, 5.2649, 0, 0, 0.487413, -0.873172, 120, 100, 1),
(9037511, 831302, 861, 4925, 4925, 1, 1, 1369.94, 366.11, 22.55, 4.2986, 0, 0, 0.837292, -0.546756, 120, 100, 1),
(9037512, 831302, 861, 4925, 4925, 1, 1, 1362.14, 343.1, 22.61, 4.2839, 0, 0, 0.841268, -0.540618, 120, 100, 1),
(9037513, 831302, 861, 4925, 4925, 1, 1, 1365.22, 316.71, 22.48, 4.8284, 0, 0, 0.664911, -0.746923, 120, 100, 1),
(9037514, 831302, 861, 4925, 4925, 1, 1, 1342.87, 274.72, 22.35, 4.0061, 0, 0, 0.908032, -0.418901, 120, 100, 1),
(9037515, 831302, 861, 4925, 4925, 1, 1, 1327.35, 267.13, 22.45, 2.8979, 0, 0, 0.992588, 0.121527, 120, 100, 1),
(9037516, 831302, 861, 4925, 4925, 1, 1, 1307.66, 261.5, 23.61, 4.0589, 0, 0, 0.896641, -0.442758, 120, 100, 1),
(9037517, 831302, 861, 4925, 4925, 1, 1, 1255.36, 291.06, 22.83, 1.6537, 0, 0, 0.735797, 0.677202, 120, 100, 1),
(9037518, 831302, 861, 4925, 4925, 1, 1, 1269.55, 318.36, 22.57, 1.0912, 0, 0, 0.518925, 0.854819, 120, 100, 1),
(9037519, 831302, 861, 4925, 4925, 1, 1, 1323.68, 352.1, 22.18, 0.1676, 0, 0, 0.083683, 0.996492, 120, 100, 1),
(9037520, 831302, 861, 4925, 4925, 1, 1, 1263.14, 345.74, 21.86, 1.7718, 0, 0, 0.774488, 0.632588, 120, 100, 1),
(9037521, 831302, 861, 4925, 4925, 1, 1, 1301.54, 456.72, 23.1, 0.6861, 0, 0, 0.336351, 0.941737, 120, 100, 1),
(9037522, 831302, 861, 4925, 4925, 1, 1, 1357.36, 411.27, 22.77, 0.3678, 0, 0, 0.182841, 0.983142, 120, 100, 1),
(9037523, 831302, 861, 4925, 4925, 1, 1, 1330.08, 399.16, 22.44, 5.8342, 0, 0, 0.222619, -0.974906, 120, 100, 1),
(9037524, 831302, 861, 4925, 4925, 1, 1, 1306.08, 418.26, 22.59, 4.6499, 0, 0, 0.728865, -0.684657, 120, 100, 1);

-- 7. quests that can be taken but never finished
DELETE FROM `disables` WHERE `sourceType` = 1 AND `entry` IN (29139, 29143, 29202, 29205, 29206);
DELETE FROM `disables` WHERE `sourceType` = 1 AND `entry` IN (29210, 29211, 29263, 29284, 29288);
INSERT INTO `disables` (`sourceType`, `entry`, `flags`, `params_0`, `params_1`, `comment`) VALUES
(1, 29139, 0, '', '', 'MF 861: Smothervine Seeds 69749 has no use spell, Smothervine is never summoned'),
(1, 29202, 0, '', '', 'Hyjal 750: The Fate of Runetotem, ender Dordaen Nightweaver is not spawned'),
(1, 29205, 0, '', '', 'MF 861: C++ event, controller 3675186 unspawned, summons into phase 64 (no phasing on 861)'),
(1, 29206, 0, '', '', 'MF 861: C++ event, controller 3675181 unspawned, summons into phase 64 (no phasing on 861)'),
(1, 29210, 0, '', '', 'MF 861: 8 Flame Protection Runes and Igneous Depths credit 3653886 are not spawned'),
(1, 29211, 0, '', '', 'MF 861: Solar Core GO casts 97945, which exists in no DBC, so no credit'),
(1, 29263, 0, '', '', 'MF 861: The Bitter Pill 69759 has no use spell (Cata 98261 absent), worm never summoned'),
(1, 29284, 0, '', '', 'Hyjal 750: Aid of the Ancients, ender Elderlimb 52488 has no template'),
(1, 29288, 0, '', '', 'MF 861: Fire Hawk Hatchling 69845 has no source');

-- 8. hostile mobs that spawn only on 861: trash 125-127, elites 127-128
UPDATE `creature_template` SET `minlevel` = 125, `maxlevel` = 127 WHERE `entry` IN (3652107, 3652503, 3652504, 3652633,
    3652648, 3652660, 3652661, 3652680, 3652871, 3652981, 3653085, 3653093, 3653143, 3653152, 3653240, 3653245, 3653309,
    3653469, 3653477, 3653478, 3653656, 3653659, 3653718, 3653753, 3654252, 3654253, 3654254, 3654255, 3654256, 3654257,
    3654282, 3654339);
UPDATE `creature_template` SET `minlevel` = 127, `maxlevel` = 128 WHERE `entry` IN (3652552, 3653055, 3653249, 3653308,
    3653310, 3653366, 3653470, 3653476, 3653479, 3653759, 3653771, 3653834, 3653864, 3654097);
-- 120 s respawn on the quest pools (847 spawns)
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 861 AND `guid` BETWEEN 15300012 AND 15340108 AND `id` IN (
    3652107, 3652503, 3652504, 3652531, 3652552, 3652633, 3652648, 3652660, 3652661, 3652751, 3652783, 3652815, 3652871,
    3652981, 3653084, 3653085, 3653093, 3653143, 3653152, 3653190, 3653191, 3653192, 3653234, 3653240, 3653243, 3653245,
    3653249, 3653251, 3653263, 3653308, 3653309, 3653310, 3653469, 3653477, 3653478, 3653479, 3654230, 3654339,
    3654343) AND `spawntimesecs` > 120;

-- 9. client caches: item 69806 / 69837 spells and GO 3808900 changed
UPDATE `version` SET `cache_id` = `cache_id` + 1 LIMIT 1;
