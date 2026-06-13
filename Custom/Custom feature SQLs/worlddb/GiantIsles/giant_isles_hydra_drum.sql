-- ============================================================================
-- GIANT ISLES - War Drum + Hydra Boss
-- ----------------------------------------------------------------------------
-- A clickable "war drum" gameobject on the eastern shore. When a player who is
-- on the faction hydra quest beats it, the C++ script (go_giant_isles_war_drum)
-- summons the hydra boss at the drum.
--   400360 = Hydra boss (display 500008, from creature_template 3461008), SmartAI
--   700016 = War Drum gameobject (ScriptName go_giant_isles_war_drum)
--   400342 = quest "Drums Along the Shore" (Alliance, AllowableRaces 1101)
--   400343 = quest "Drums Along the Shore" (Horde,    AllowableRaces 690)
-- Quest giver: Elder Zul'jin (400200) - each player sees only their faction's
-- quest via AllowableRaces. Position: map 1405 @ 6323.4595 1068.7466 12.090531.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Hydra boss creature (400360)
-- ----------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 400360;
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400360, 0, 0, 0, 0, 0, 'Vorath the Drowned', 'Ancient Hydra', '', 0, 83, 83, 2, 14, 0, 1, 1.14286, 1, 1, 20, 3, 0, 8, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 5000, 8000, 'SmartAI', 0, 1, 150, 1, 2, 1, 0, 0, 1, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 400360;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400360, 0, 500008, 1, 1, 12340); -- hydra model (same display as creature_template 3461008)

-- Group 0 = aggro roar (SmartAI Talk on aggro). Group 1 = spawn shout, played
-- by the drum script (CreatureAI::Talk(1)) the moment the hydra is summoned.
DELETE FROM `creature_text` WHERE `CreatureID` = 400360;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(400360, 0, 0, 'unleashes a deafening, many-throated roar!', 16, 0, 100, 0, 0, 0, 0, 0, 'Vorath - Aggro'),
(400360, 1, 0, 'The drums have called me from the black water! You will drown with the rest!', 14, 0, 100, 0, 0, 0, 0, 0, 'Vorath - Spawn');

-- SmartAI: a brawler hydra (cleave + tail-sweep stomp + bleeding bite) that
-- roars on aggro. All spell ids are validated WotLK creature spells.
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 400360;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 400360;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400360, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Vorath - On Aggro - Talk (roar)'),
(400360, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 8000, 12000, 0, 0, 11, 15284, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vorath - In Combat - Cleave'),
(400360, 0, 2, 0, 0, 0, 100, 0, 9000, 14000, 14000, 20000, 0, 0, 11, 8078, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vorath - In Combat - Thunder Clap'),
(400360, 0, 3, 0, 0, 0, 100, 0, 6000, 9000, 11000, 16000, 0, 0, 11, 13443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vorath - In Combat - Rend'),
-- event 1 = SMART_EVENT_UPDATE_OOC (only ticks while out of combat, resets on
-- evade); fires once at 5 min => despawn an un-engaged / abandoned hydra.
(400360, 0, 4, 0, 1, 0, 100, 0, 300000, 300000, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vorath - 5 min not attacked - Force Despawn');

-- ----------------------------------------------------------------------------
-- War Drum gameobject (700016) + its spawn on the eastern shore.
-- type 2 (QUESTGIVER) so the GameObjectScript's OnGossipHello fires on click.
-- ----------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` = 700016;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700016, 2, 7535, 'War Drum of the Isles', '', '', '', 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_war_drum', 12340);

-- ----------------------------------------------------------------------------
-- Quests (one per faction; only the matching faction can take each). DAILY
-- (Flags 0x1000) so the boss is re-summonable each day and the questgiver shows
-- the blue daily "!" icon.
-- ----------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` IN (400342, 400343);
INSERT INTO `quest_template`
(`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(400342, 2, 83, 80, 0, 0, 3, 0, 500000, 0x1000, 1101,
 'Drums Along the Shore',
 'Beat the War Drum of the Isles on the eastern shore of the Giant Isles and slay the hydra Vorath the Drowned.',
 'The tides of the Giant Isles hide an ancient hydra, $N. A great war drum still stands on the eastern shore - beat it, and the beast will answer the call. Sound the drum and put Vorath the Drowned down before it drags more souls into the deep.',
 'Vorath the Drowned has been slain.',
 400360, 1),
(400343, 2, 83, 80, 0, 0, 3, 0, 500000, 0x1000, 690,
 'Drums Along the Shore',
 'Beat the War Drum of the Isles on the eastern shore of the Giant Isles and slay the hydra Vorath the Drowned.',
 'The tides of the Giant Isles hide an ancient hydra, $N. A great war drum still stands on the eastern shore - beat it, and the beast will answer the call. Sound the drum and put Vorath the Drowned down before it drags more souls into the deep.',
 'Vorath the Drowned has been slain.',
 400360, 1);

-- Mark both quests repeatable so the daily reset logic engages cleanly.
DELETE FROM `quest_template_addon` WHERE `ID` IN (400342, 400343);
INSERT INTO `quest_template_addon` (`ID`, `SpecialFlags`) VALUES
(400342, 1),
(400343, 1);

-- Quest giver: Scholar Zal'ira (400525). Already a questgiver (npcflag 3) and
-- neutral (faction 35) so both factions can use her; AllowableRaces decides which
-- quest each player sees. The blue-icon override script + the override row below
-- render the daily "!" in blue.
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2, `ScriptName` = 'npc_giant_isles_questgiver' WHERE `entry` = 400525;

-- Remove any earlier wiring on Elder Zul'jin (400200); the quests live on 400525 now.
DELETE FROM `creature_queststarter` WHERE `id` = 400200 AND `quest` IN (400342, 400343);
DELETE FROM `creature_questender` WHERE `id` = 400200 AND `quest` IN (400342, 400343);

DELETE FROM `creature_queststarter` WHERE `id` = 400525 AND `quest` IN (400342, 400343);
DELETE FROM `creature_questender` WHERE `id` = 400525 AND `quest` IN (400342, 400343);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(400525, 400342),
(400525, 400343);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(400525, 400342),
(400525, 400343);

-- Blue "!" overhead icon: promote available daily/weekly quests for Zal'ira.
DELETE FROM `dc_questgiver_status_overrides` WHERE `creature_entry` = 400525;
INSERT INTO `dc_questgiver_status_overrides` (`creature_entry`, `enabled`, `promote_daily`, `promote_weekly`, `promote_monthly`, `comment`) VALUES
(400525, 1, 1, 1, 0, 'Scholar Zal''ira: blue overhead icon for the Giant Isles hydra daily quests');
