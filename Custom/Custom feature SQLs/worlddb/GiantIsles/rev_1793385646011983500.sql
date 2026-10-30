-- Isles of Giants: the Blood Tide (2026-10-30). Rework of the Zandalari invasion on the MoP terrain.
-- Goes with the C++ in src/server/scripts/DC/GiantIsles (dc_giant_isles_invasion*.cpp, dc_giant_isles_warfront.cpp).
--   * clears CREATURE_FLAG_EXTRA_TRIGGER from 26 combat creatures: it made them unselectable and unable to fight,
--     so Warlord Zul'mar could never be killed and every invasion ended in defeat
--   * kill credit no longer needs 50% player damage on invaders (defender NPCs do most of the damage)
--   * new units 400580-400599, static Zandalari camps on the real MoP dinomancer posts, flagship crew,
--     cage captives, island wildlife on the MoP spawn points
--   * foothold camps as game events 251-253, started and stopped by the script
--   * quests 400344-400353
-- Creature guids 9014000+, gameobject guids 9014000+ (both empty on 2026-10-30).
-- Deleting from creature_template, gameobject_template and quest_template is intended: custom ids only.

-- TRIGGER off for everything that is meant to be fought. 400323 Ship Explosion Trigger stays a trigger.
UPDATE `creature_template` SET `flags_extra` = `flags_extra` & ~128 WHERE `entry` IN (400001, 400002, 400050, 400051, 400052, 400053, 400054, 400055, 400056, 400057, 400058, 400059, 400252, 400253, 400254, 400260, 400272, 400275, 400276, 400301, 400330, 400332, 400333, 400334, 400336, 400400);

-- Invaders: players earn credit however much of the damage the defender line did.
UPDATE `creature_template` SET `flags_extra` = `flags_extra` | 2097152 WHERE `entry` IN (400326, 400327, 400328, 400329, 400330, 400331, 400332, 400333, 400334, 400335, 400336, 400337, 400361, 400362, 400363, 400364, 400366);

-- General Rak'zor can take the field now: civilian flag off, and a hit that matches his rank.
UPDATE `creature_template` SET `flags_extra` = 2097152, `DamageModifier` = 14 WHERE `entry` = 400338;

-- Objectives report who destroyed them; defenders and the Landing guards use their ability kits.
UPDATE `creature_template` SET `ScriptName` = 'npc_invasion_objective' WHERE `entry` IN (400364, 400366);
UPDATE `creature_template` SET `ScriptName` = 'npc_invasion_defender' WHERE `entry` BETWEEN 401004 AND 401009;

-- Pterrordax bombers fly.
DELETE FROM `creature_template_movement` WHERE `CreatureId` = 400362;
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`) VALUES
(400362, 1, 0, 1, 0);

DELETE FROM `creature_template` WHERE `entry` BETWEEN 400580 AND 400599;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400580, 0, 0, 0, 400339, 0, 'Zandalari Dinomancer', 'Beast Binder', NULL, 0, 80, 80, 2, 16, 0, 1, 1.14286, 1, 1, 20, 0, 0, 5, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 16, 3, 1.5, 1.0, 0, 0, 1, 0, 2097152, 'npc_invasion_mob', 12340),
(400581, 0, 0, 0, 0, 0, 'War-God Dokah', 'Master of the Blood Tide', NULL, 0, 83, 83, 2, 16, 0, 1, 1.14286, 1, 1, 20, 3, 0, 14, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 40000, 60000, '', 0, 1, 140, 1.0, 2.5, 4, 0, 0, 0, 0, 2097152, 'npc_war_god_dokah', 12340),
(400582, 0, 0, 0, 0, 0, 'Zandalari War Engine', 'Iron Rain', NULL, 0, 81, 81, 2, 16, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 45, 1.0, 2, 1.0, 0, 0, 0, 0, 2097152, 'npc_invasion_objective', 12340),
(400583, 0, 0, 0, 400339, 0, 'Zandalari Engine Crewman', NULL, NULL, 0, 80, 80, 2, 16, 0, 1, 1.14286, 1, 1, 20, 0, 0, 4.5, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 12, 1.0, 1.5, 1.0, 0, 0, 1, 0, 2097152, 'npc_invasion_mob', 12340),
(400584, 0, 0, 0, 0, 0, 'Binding Pylon', 'The Binding', NULL, 0, 81, 81, 2, 16, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 40, 1.0, 2, 1.0, 0, 0, 0, 0, 2097152, 'npc_invasion_objective', 12340),
(400585, 0, 0, 0, 0, 0, 'Bound Primal Behemoth', 'Thrall of the Dinomancers', NULL, 0, 82, 82, 2, 16, 0, 1, 1.4, 1, 1, 20, 3, 0, 16, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 200, 1.0, 3, 4, 0, 0, 0, 0, 2097152, 'npc_invasion_mob', 12340),
(400586, 0, 0, 0, 400339, 0, 'Zandalari Beastmaster', 'The Stampede', NULL, 0, 81, 81, 2, 16, 0, 1, 1.14286, 1, 1, 20, 1, 0, 6, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 26, 1.0, 1.5, 1.0, 0, 0, 1, 0, 2097152, 'npc_invasion_mob', 12340),
(400587, 0, 0, 0, 400339, 0, 'Stampeding Direhorn', NULL, NULL, 0, 80, 80, 2, 16, 0, 1, 2.2, 1, 1, 20, 0, 0, 5, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 9, 1.0, 1.5, 1.0, 0, 0, 1, 0, 2097152, 'npc_invasion_mob', 12340),
(400588, 0, 0, 0, 400339, 0, 'Zandalari Sky-Caller', 'Sky Raid', NULL, 0, 81, 81, 2, 16, 0, 1, 1.14286, 1, 1, 20, 1, 0, 6, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 28, 3, 1.5, 1.0, 0, 0, 1, 0, 2097152, 'npc_invasion_mob', 12340),
(400589, 0, 0, 0, 0, 0, 'Elder Zul''jin', 'Zandalari Expedition Leader', NULL, 0, 82, 82, 2, 250, 0, 1, 1.14286, 1, 1, 20, 1, 0, 8, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 120, 5, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_invasion_zuljin', 12340),
(400590, 0, 0, 0, 0, 0, 'Captive Beast Hunter', NULL, NULL, 0, 80, 80, 2, 35, 1, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 8, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_giant_isles_captive', 12340),
(400591, 0, 0, 0, 0, 0, 'Slimer Bay Canoes', 'Scouting Credit', NULL, 0, 80, 80, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554434, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_giant_isles_scout_marker', 12340),
(400592, 0, 0, 0, 0, 0, 'Zandalari War Camp', 'Scouting Credit', NULL, 0, 80, 80, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554434, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_giant_isles_scout_marker', 12340),
(400593, 0, 0, 0, 0, 0, 'Zandalari Bunkers', 'Scouting Credit', NULL, 0, 80, 80, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554434, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_giant_isles_scout_marker', 12340),
(400594, 0, 0, 0, 0, 0, 'Expedition Medic', 'Seeping Shores Defense', NULL, 0, 80, 80, 2, 250, 0, 1, 1.14286, 1, 1, 20, 0, 0, 2, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 30, 10, 1.5, 1.0, 0, 0, 1, 0, 0, 'npc_invasion_medic', 12340),
(400595, 0, 0, 0, 0, 0, 'Impact Marker', NULL, NULL, 0, 80, 80, 2, 16, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554434, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 128, 'npc_invasion_impact', 12340),
(400596, 0, 0, 0, 0, 0, 'Rogue Tyrant', 'Drawn by the Blood', NULL, 0, 82, 82, 2, 1925, 0, 1, 1.5, 1, 1, 20, 2, 0, 12, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1500, 2500, '', 0, 1, 90, 1.0, 3, 4, 0, 0, 0, 0, 2097152, 'npc_invasion_mob', 12340),
(400597, 0, 0, 0, 0, 0, 'War Standard felled', 'Kill Credit', NULL, 0, 1, 1, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, '', 12340),
(400598, 0, 0, 0, 0, 0, 'War plan broken', 'Kill Credit', NULL, 0, 1, 1, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, '', 12340),
(400599, 0, 0, 0, 0, 0, 'War engine sabotaged', 'Kill Credit', NULL, 0, 1, 1, 2, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1.0, 1.5, 1.0, 0, 0, 1, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 400580 AND 400599;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400580, 0, 11292, 1.05, 1, 12340),
(400581, 0, 11311, 1.6, 1, 12340),
(400582, 0, 27658, 1.0, 1, 12340),
(400583, 0, 11290, 1.0, 1, 12340),
(400584, 0, 16997, 1.2, 1, 12340),
(400585, 0, 500234, 8.0, 1, 12340),
(400586, 0, 11291, 1.1, 1, 12340),
(400587, 0, 5305, 0.9, 1, 12340),
(400588, 0, 11292, 1.15, 1, 12340),
(400589, 0, 11288, 1.15, 1, 12340),
(400590, 0, 4259, 1.0, 1, 12340),
(400591, 0, 11686, 1.0, 1, 12340),
(400592, 0, 11686, 1.0, 1, 12340),
(400593, 0, 11686, 1.0, 1, 12340),
(400594, 0, 4259, 0.95, 1, 12340),
(400595, 0, 11686, 1.0, 1, 12340),
(400596, 0, 5240, 1.4, 1, 12340),
(400597, 0, 11686, 1.0, 1, 12340),
(400598, 0, 11686, 1.0, 1, 12340),
(400599, 0, 11686, 1.0, 1, 12340);

DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 400580 AND 400599;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(400580, 1, 13720, 0, 0, 12340),
(400581, 1, 14870, 0, 0, 12340),
(400583, 1, 14877, 1985, 0, 12340),
(400586, 1, 14877, 0, 2506, 12340),
(400588, 1, 13720, 0, 0, 12340),
(400589, 1, 13720, 0, 0, 12340),
(400594, 1, 13720, 0, 0, 12340);

-- The captives kneel in their cages.
DELETE FROM `creature_template_addon` WHERE `entry` = 400590;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(400590, 0, 0, 8, 0, 0, 0, '');

DELETE FROM `creature_text` WHERE `CreatureID` IN (400338, 400581, 400589, 400590, 400596);
DELETE FROM `creature_text` WHERE `CreatureID` = 400336 AND `GroupID` IN (4, 5, 6);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(400338, 0, 0, 'Da tide be turnin'' red, mon! Unload everyt''ing! Dis island belongs to Zandalar!', 14, 0, 100, 0, 0, 0, 0, 3, 'Omens'),
(400338, 1, 0, 'Scouts to da sand! Plant da standards an'' probe dere line!', 14, 0, 100, 0, 0, 0, 0, 3, 'Landfall'),
(400338, 2, 0, 'Warriors! Break dem shields! Let da beach drink deep!', 14, 0, 100, 0, 0, 0, 0, 3, 'Onslaught'),
(400338, 3, 0, 'Now da real war begins! Elites, no prisoners!', 14, 0, 100, 0, 0, 0, 0, 3, 'Siege'),
(400338, 4, 0, 'Warlord Zul''mar! Finish dis!', 14, 0, 100, 0, 0, 0, 0, 3, 'Warlord'),
(400338, 5, 0, 'Back to da ships! Da Empire remembers dis shore!', 14, 0, 100, 0, 0, 0, 0, 3, 'Retreat'),
(400338, 6, 0, 'Da beach be ours! Raise da banners!', 14, 0, 100, 0, 0, 0, 0, 3, 'Triumph'),
(400338, 7, 0, 'ENOUGH! If ya want somet''in'' done right... Stand aside, ya useless whelps. I will end dis myself!', 14, 0, 100, 0, 0, 0, 0, 3, 'Reckoning'),
(400338, 8, 0, 'Witch doctors! Raise da effigy! Let da Loa taste dis battle!', 14, 0, 100, 0, 0, 0, 0, 3, 'Plan: Loa'),
(400338, 9, 0, 'Beastmasters! Loose da herd! Trample dem all!', 14, 0, 100, 0, 0, 0, 0, 3, 'Plan: Stampede'),
(400338, 10, 0, 'Sky-callers! Bring da fire down from above!', 14, 0, 100, 0, 0, 0, 0, 3, 'Plan: Sky Raid'),
(400338, 11, 0, 'War engines, fire! Let it rain iron on dere heads!', 14, 0, 100, 0, 0, 0, 0, 3, 'Plan: Iron Rain'),
(400338, 12, 0, 'Dinomancers! Bind da beast! It will kneel to Zandalar!', 14, 0, 100, 0, 0, 0, 0, 3, 'Plan: Binding'),
(400336, 4, 0, 'To me, beast! Feed on dem!', 14, 0, 100, 0, 0, 0, 0, 3, 'Calls the devilsaur'),
(400336, 5, 0, 'The Loa take hold of Warlord Zul''mar!', 41, 0, 100, 0, 0, 0, 0, 3, 'Possessed'),
(400336, 6, 0, 'Warlord Zul''mar gathers the blood of the fallen! Get away from him!', 41, 0, 100, 0, 0, 0, 0, 3, 'Blood Nova'),
(400589, 0, 0, 'Zul''mar! Ya shame da Empire dat raised us both. Dis ends today, boy! Defenders, FORWARD!', 14, 0, 100, 0, 0, 0, 0, 3, 'Counter-charge'),
(400589, 1, 0, 'Da wound be deep... finish him! I will hold da camp!', 14, 0, 100, 0, 0, 0, 0, 3, 'Falls back'),
(400589, 2, 0, 'Da shore holds! Zandalar will remember dis day, an'' so will we!', 14, 0, 100, 0, 0, 0, 0, 3, 'Victory'),
(400589, 3, 0, 'Rak''zor comes himself! Stand wit'' me, all of ya! His blood ends dis tide!', 14, 0, 100, 0, 0, 0, 0, 3, 'Reckoning'),
(400581, 0, 0, 'Ya climb my ship, little t''ing? Den ya die on it.', 14, 0, 100, 0, 0, 0, 0, 0, 'Aggro'),
(400581, 1, 0, 'Da blood tide does not stop! NOT FOR YOU!', 14, 0, 100, 0, 0, 0, 0, 0, 'Fury'),
(400581, 2, 0, 'Da Empire... has... other gods...', 14, 0, 100, 0, 0, 0, 0, 0, 'Death'),
(400590, 0, 0, 'Tell Zul''jin I still got one good arm for dem trolls!', 12, 0, 100, 0, 0, 0, 0, 0, 'Freed'),
(400590, 0, 1, 'I owe ya one. Next time dey land, I will be on dat line!', 12, 0, 100, 0, 0, 0, 0, 0, 'Freed'),
(400596, 0, 0, 'A wild tyrant crashes through the treeline, drawn by the scent of blood!', 41, 0, 100, 0, 0, 0, 0, 3, 'Arrives');

DELETE FROM `npc_text` WHERE `ID` = 400366;
INSERT INTO `npc_text` (`ID`, `text0_0`, `Probability0`) VALUES
(400366, 'The lock is cheap and the bars are worse. Get me out of here and I will be back on the line before they beach again.', 1);

DELETE FROM `gameobject_template` WHERE `entry` = 700040;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700040, 2, 8185, 'Zandalari Powder Charge', '', '', '', 0.8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_powder_charge', 12340);

DELETE FROM `creature` WHERE `guid` BETWEEN 9014000 AND 9014107 AND `id` IN (400000, 400001, 400002, 400003, 400004, 400005, 400006, 400012, 400050, 400051, 400052, 400053, 400054, 400326, 400328, 400329, 400331, 400332, 400333, 400334, 400580, 400581, 400583, 400590, 400591, 400592, 400593);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9014000, 400005, 1405, 5006, 5009, 1, 1, 0, 5897.90, 1380.10, 28.21, 3.26, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014001, 400003, 1405, 5006, 5009, 1, 1, 0, 5877.20, 1358.60, 27.96, 0.72, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014002, 400000, 1405, 5006, 5015, 1, 1, 0, 6041.90, 964.80, 60.54, 0.14, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014003, 400000, 1405, 5006, 5015, 1, 1, 0, 6111.00, 1053.10, 56.36, 2.61, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014004, 400000, 1405, 5006, 5015, 1, 1, 0, 6147.50, 1073.30, 61.18, 3.13, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014005, 400000, 1405, 5006, 5015, 1, 1, 0, 6010.10, 1017.70, 59.89, 2.95, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014006, 400000, 1405, 5006, 5015, 1, 1, 0, 6155.80, 1142.70, 61.21, 6.05, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014007, 400000, 1405, 5006, 5015, 1, 1, 0, 6108.00, 1157.50, 56.90, 6.06, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014008, 400000, 1405, 5006, 5015, 1, 1, 0, 6151.00, 1196.20, 62.12, 3.63, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014009, 400000, 1405, 5006, 5015, 1, 1, 0, 6102.30, 1243.70, 64.01, 1.16, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014010, 400000, 1405, 5006, 5016, 1, 1, 0, 5979.10, 1397.90, 86.09, 4.65, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014011, 400000, 1405, 5006, 5016, 1, 1, 0, 6007.30, 1386.60, 87.51, 1.89, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014012, 400000, 1405, 5006, 5012, 1, 1, 0, 5888.00, 687.90, 24.34, 1.15, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014013, 400000, 1405, 5006, 5012, 1, 1, 0, 5911.90, 674.00, 25.11, 5.10, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014014, 400000, 1405, 5006, 5012, 1, 1, 0, 5961.50, 688.70, 28.09, 3.29, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014015, 400000, 1405, 5006, 5012, 1, 1, 0, 5961.80, 674.00, 26.47, 4.33, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014016, 400002, 1405, 5006, 5015, 1, 1, 0, 6148.70, 1168.00, 61.32, 2.27, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014017, 400001, 1405, 5006, 5016, 1, 1, 0, 5972.90, 1330.50, 84.84, 1.97, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014018, 400001, 1405, 5006, 5016, 1, 1, 0, 5982.60, 1366.70, 85.39, 3.37, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014019, 400001, 1405, 5006, 5012, 1, 1, 0, 5924.00, 709.90, 24.45, 1.60, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014020, 400004, 1405, 5006, 5011, 1, 1, 0, 5832.50, 858.00, 12.49, 2.94, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014021, 400003, 1405, 5006, 5011, 1, 1, 0, 5819.90, 884.90, 11.62, 4.81, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014022, 400003, 1405, 5006, 5011, 1, 1, 0, 5843.20, 927.40, 20.24, 0.78, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014023, 400003, 1405, 5006, 5010, 1, 1, 0, 5849.50, 1020.50, 17.74, 3.23, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014024, 400004, 1405, 5006, 5012, 1, 1, 0, 5904.40, 854.90, 45.15, 5.31, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014025, 400004, 1405, 5006, 5012, 1, 1, 0, 5967.40, 852.10, 44.53, 2.19, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014026, 400006, 1405, 5006, 5010, 1, 1, 0, 5849.10, 986.10, 21.50, 2.43, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014027, 400006, 1405, 5006, 5010, 1, 1, 0, 5811.10, 974.50, 25.80, 1.43, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014028, 400012, 1405, 5006, 5006, 1, 1, 0, 6327.10, 716.10, 4.06, 6.14, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014029, 400012, 1405, 5006, 5018, 1, 1, 0, 6334.20, 730.00, 2.00, 5.30, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014030, 400012, 1405, 5006, 5018, 1, 1, 0, 6346.80, 712.80, 2.68, 1.50, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014031, 400012, 1405, 5006, 5006, 1, 1, 0, 5928.60, 1042.70, 61.54, 3.44, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014032, 400012, 1405, 5006, 5006, 1, 1, 0, 5924.70, 1063.50, 59.44, 3.16, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014033, 400012, 1405, 5006, 5016, 1, 1, 0, 6105.80, 1427.10, 88.12, 0.24, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014034, 400012, 1405, 5006, 5016, 1, 1, 0, 6118.30, 1415.10, 86.77, 0.94, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014035, 400012, 1405, 5006, 5007, 1, 1, 0, 6119.00, 1517.40, 43.70, 0.40, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014036, 400012, 1405, 5006, 5007, 1, 1, 0, 6118.20, 1550.20, 31.94, 0.44, 300, 12, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants wildlife'),
(9014037, 400050, 1405, 5006, 5015, 1, 1, 0, 6043.90, 996.10, 60.59, 3.36, 14400, 8, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants rare'),
(9014038, 400051, 1405, 5006, 5015, 1, 1, 0, 6163.30, 1100.60, 59.00, 3.21, 14400, 8, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants rare'),
(9014039, 400052, 1405, 5006, 5016, 1, 1, 0, 5998.10, 1429.60, 86.35, 2.95, 14400, 8, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants rare'),
(9014040, 400053, 1405, 5006, 5007, 1, 1, 0, 6001.60, 1588.30, 33.43, 3.78, 14400, 8, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants rare'),
(9014041, 400054, 1405, 5006, 5012, 1, 1, 0, 5905.10, 888.60, 45.50, 5.65, 14400, 8, 0, 100, 0, 1, 0, 0, 0, '', NULL, 0, 'Isles of Giants rare'),
(9014042, 400580, 1405, 5006, 5011, 1, 1, 1, 5790.60, 819.50, 3.14, 1.82, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014043, 400583, 1405, 5006, 5011, 1, 1, 1, 5793.30, 832.60, 4.28, 3.94, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014044, 400580, 1405, 5006, 5011, 1, 1, 1, 5796.90, 803.40, 2.93, 0.08, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014045, 400326, 1405, 5006, 5011, 1, 1, 1, 5800.30, 805.30, 3.28, 5.28, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014046, 400328, 1405, 5006, 5011, 1, 1, 1, 5789.80, 816.70, 2.54, 4.11, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014047, 400332, 1405, 5006, 5012, 1, 1, 1, 5843.40, 754.60, 19.11, 4.25, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014048, 400580, 1405, 5006, 5011, 1, 1, 1, 5845.00, 773.30, 17.33, 5.88, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014049, 400329, 1405, 5006, 5011, 1, 1, 1, 5847.50, 767.40, 17.33, 1.76, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014050, 400580, 1405, 5006, 5011, 1, 1, 1, 5852.00, 774.90, 17.33, 4.27, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014051, 400334, 1405, 5006, 5012, 1, 1, 1, 5859.20, 757.90, 17.72, 5.32, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014052, 400331, 1405, 5006, 5011, 1, 1, 1, 5864.60, 781.60, 17.58, 3.95, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014053, 400580, 1405, 5006, 5012, 1, 1, 1, 5871.10, 766.90, 17.98, 5.80, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014054, 400580, 1405, 5006, 5012, 1, 1, 1, 5913.20, 837.30, 44.43, 4.26, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014055, 400332, 1405, 5006, 5012, 1, 1, 1, 5920.50, 844.70, 44.41, 1.74, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014056, 400580, 1405, 5006, 5012, 1, 1, 1, 5929.00, 834.90, 44.62, 4.62, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014057, 400580, 1405, 5006, 5014, 1, 1, 1, 6205.90, 774.50, 73.78, 6.17, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014058, 400331, 1405, 5006, 5014, 1, 1, 1, 6210.50, 776.40, 73.65, 5.18, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari camp'),
(9014059, 400332, 1405, 5006, 5006, 1, 1, 1, 5728.50, 607.30, 18.20, 2.58, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014060, 400580, 1405, 5006, 5006, 1, 1, 1, 5733.40, 627.40, 17.90, 6.11, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014061, 400580, 1405, 5006, 5006, 1, 1, 1, 5740.80, 572.70, 19.20, 0.97, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014062, 400329, 1405, 5006, 5006, 1, 1, 1, 5746.40, 616.20, 19.40, 4.25, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014063, 400580, 1405, 5006, 5006, 1, 1, 1, 5749.10, 588.20, 18.50, 0.34, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014064, 400333, 1405, 5006, 5006, 1, 1, 1, 5752.50, 593.40, 18.50, 4.77, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014065, 400332, 1405, 5006, 5006, 1, 1, 1, 5753.70, 585.20, 18.50, 1.91, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014066, 400331, 1405, 5006, 5006, 1, 1, 1, 5757.00, 590.70, 18.50, 3.47, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014067, 400580, 1405, 5006, 5006, 1, 1, 1, 5758.60, 612.10, 17.90, 0.30, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014068, 400329, 1405, 5006, 5006, 1, 1, 1, 5777.80, 577.40, 18.00, 0.57, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014069, 400580, 1405, 5006, 5006, 1, 1, 1, 5710.00, 620.30, 3.20, 5.68, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014070, 400583, 1405, 5006, 5006, 1, 1, 1, 5717.80, 595.80, 3.20, 3.82, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014071, 400583, 1405, 5006, 5006, 1, 1, 1, 5719.50, 593.40, 3.20, 3.41, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014072, 400580, 1405, 5006, 5006, 1, 1, 1, 5741.90, 607.00, 3.50, 0.20, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014073, 400583, 1405, 5006, 5006, 1, 1, 1, 5755.00, 607.10, 3.20, 0.04, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014074, 400583, 1405, 5006, 5006, 1, 1, 1, 5762.00, 588.70, 3.20, 2.20, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014075, 400580, 1405, 5006, 5006, 1, 1, 1, 5771.20, 575.90, 3.20, 0.14, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014076, 400583, 1405, 5006, 5006, 1, 1, 1, 5772.90, 578.20, 3.20, 5.22, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari flagship'),
(9014077, 400581, 1405, 5006, 5006, 1, 1, 1, 5709.60, 619.90, 18.40, 2.58, 21600, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'War-God Dokah'),
(9014078, 400590, 1405, 5006, 5011, 1, 1, 0, 5797.80, 798.20, 3.08, 1.93, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014079, 400590, 1405, 5006, 5011, 1, 1, 0, 5802.30, 801.20, 3.69, 2.51, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014080, 400590, 1405, 5006, 5011, 1, 1, 0, 5796.60, 834.70, 4.82, 4.71, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014081, 400590, 1405, 5006, 5011, 1, 1, 0, 5792.50, 836.70, 4.49, 3.10, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014082, 400590, 1405, 5006, 5012, 1, 1, 0, 5909.40, 833.00, 43.78, 1.14, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014083, 400590, 1405, 5006, 5012, 1, 1, 0, 5915.10, 832.50, 44.13, 2.71, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014084, 400590, 1405, 5006, 5012, 1, 1, 0, 5939.00, 842.00, 44.53, 3.20, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014085, 400590, 1405, 5006, 5013, 1, 1, 0, 6074.10, 809.80, 61.15, 4.71, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014086, 400590, 1405, 5006, 5013, 1, 1, 0, 6069.50, 804.10, 60.40, 4.30, 180, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Captive Beast Hunter'),
(9014087, 400591, 1405, 5006, 5011, 1, 1, 0, 5790.00, 815.00, 3.00, 0.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Scouting marker'),
(9014088, 400592, 1405, 5006, 5011, 1, 1, 0, 5858.00, 772.00, 17.50, 0.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Scouting marker'),
(9014089, 400593, 1405, 5006, 5012, 1, 1, 0, 5925.00, 838.00, 44.40, 0.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Scouting marker'),
(9014090, 400580, 1405, 5006, 5009, 1, 1, 1, 5835.00, 1301.20, 34.09, 1.61, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 251'),
(9014091, 400332, 1405, 5006, 5010, 1, 1, 1, 5853.70, 1270.80, 38.20, 5.76, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 251'),
(9014092, 400580, 1405, 5006, 5009, 1, 1, 1, 5859.20, 1302.00, 36.44, 2.18, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 251'),
(9014093, 400332, 1405, 5006, 5010, 1, 1, 1, 5859.40, 1271.40, 38.74, 4.06, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 251'),
(9014094, 400329, 1405, 5006, 5010, 1, 1, 1, 5806.00, 1158.00, 6.66, 1.60, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014095, 400580, 1405, 5006, 5010, 1, 1, 1, 5812.00, 1168.00, 6.93, 2.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014096, 400332, 1405, 5006, 5010, 1, 1, 1, 5832.00, 1176.00, 8.49, 1.80, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014097, 400331, 1405, 5006, 5010, 1, 1, 1, 5842.00, 1188.00, 8.40, 2.20, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014098, 400329, 1405, 5006, 5010, 1, 1, 1, 5790.00, 1186.00, 2.35, 1.40, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014099, 400580, 1405, 5006, 5010, 1, 1, 1, 5778.00, 1196.00, 2.47, 1.20, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014100, 400332, 1405, 5006, 5010, 1, 1, 1, 5768.00, 1146.00, 1.45, 1.10, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014101, 400331, 1405, 5006, 5010, 1, 1, 1, 5755.00, 1152.00, 0.94, 1.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 252'),
(9014102, 400332, 1405, 5006, 5010, 1, 1, 1, 5805.00, 1085.00, 1.34, 1.60, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253'),
(9014103, 400580, 1405, 5006, 5010, 1, 1, 1, 5815.00, 1075.00, 5.10, 1.80, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253'),
(9014104, 400329, 1405, 5006, 5010, 1, 1, 1, 5826.00, 1095.00, 4.31, 1.50, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253'),
(9014105, 400331, 1405, 5006, 5010, 1, 1, 1, 5834.00, 1000.00, 22.12, 2.00, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253'),
(9014106, 400332, 1405, 5006, 5010, 1, 1, 1, 5840.00, 985.00, 22.64, 1.90, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253'),
(9014107, 400580, 1405, 5006, 5010, 1, 1, 1, 5828.00, 995.00, 24.50, 1.70, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Zandalari foothold 253');

DELETE FROM `gameobject` WHERE `guid` BETWEEN 9014000 AND 9014005 AND `id` IN (700040, 4620977);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9014000, 700040, 1405, 5006, 5012, 1, 1, 5864.00, 751.00, 18.20, 0.00, 0, 0, 0.0, 1.0, 180, 100, 1, '', NULL, 'Powder charge'),
(9014001, 700040, 1405, 5006, 5012, 1, 1, 5933.00, 825.00, 44.50, 0.00, 0, 0, 0.0, 1.0, 180, 100, 1, '', NULL, 'Powder charge'),
(9014002, 700040, 1405, 5006, 5012, 1, 1, 5961.00, 765.00, 37.50, 0.00, 0, 0, 0.0, 1.0, 180, 100, 1, '', NULL, 'Powder charge'),
(9014003, 4620977, 1405, 5006, 5010, 1, 1, 5847.00, 1284.00, 36.20, 0.00, 0, 0, 0.0, 1.0, 300, 100, 1, '', NULL, 'Zandalari foothold 251 fire'),
(9014004, 4620977, 1405, 5006, 5010, 1, 1, 5822.00, 1170.00, 7.90, 0.00, 0, 0, 0.0, 1.0, 300, 100, 1, '', NULL, 'Zandalari foothold 252 fire'),
(9014005, 4620977, 1405, 5006, 5010, 1, 1, 5812.00, 1086.00, 2.20, 0.00, 0, 0, 0.0, 1.0, 300, 100, 1, '', NULL, 'Zandalari foothold 253 fire');

-- Foothold camps. Never active on their own: start_time = end_time keeps them off, and the script starts and
-- stops them from the campaign world state (251 at foothold 1+, 252 at 3+, 253 at 5). Event ids stop at 255:
-- game_event.eventEntry is a tinyint unsigned and the core reads it as uint8.
DELETE FROM `game_event` WHERE `eventEntry` IN (251, 252, 253);
INSERT INTO `game_event` (`eventEntry`, `start_time`, `end_time`, `occurence`, `length`, `holiday`, `holidayStage`, `description`, `world_event`, `announce`) VALUES
(251, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the terrace', 0, 0),
(252, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the beach garrison', 0, 0),
(253, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the Warpath outposts', 0, 0);

DELETE FROM `game_event_creature` WHERE `guid` BETWEEN 9014000 AND 9014107;
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) VALUES
(251, 9014090),
(251, 9014091),
(251, 9014092),
(251, 9014093),
(252, 9014094),
(252, 9014095),
(252, 9014096),
(252, 9014097),
(252, 9014098),
(252, 9014099),
(252, 9014100),
(252, 9014101),
(253, 9014102),
(253, 9014103),
(253, 9014104),
(253, 9014105),
(253, 9014106),
(253, 9014107);

DELETE FROM `game_event_gameobject` WHERE `guid` BETWEEN 9014000 AND 9014005;
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) VALUES
(251, 9014003),
(252, 9014004),
(253, 9014005);

-- Existing invasion quests belong in the Isles of Giants quest log header. 5000 was never a real zone here.
UPDATE `quest_template` SET `QuestSortID` = 5006 WHERE `ID` IN (80100, 400340, 400341, 400342, 400343);
UPDATE `quest_template` SET `ObjectiveText1` = 'Zandalari invaders slain' WHERE `ID` IN (400340, 400341);

DELETE FROM `quest_template` WHERE `ID` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardItem1`, `RewardAmount1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGo3`, `RequiredNpcOrGoCount3`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `VerifiedBuild`) VALUES
(400344, 2, 80, 80, 5006, 0, 0, 5, 100000, 8, 400456, 5, 0, 'Smoke on the Horizon', 'Scout the canoes at Slimer Bay, the Zandalari War Camp and the bunkers on the heights, then return to Elder Zul''jin at Warden''s Landing.', 'Dat ship off da south-east shore be no scouting party, $n. I know dose sails. I served under dem once, before I learned what da Empire does to its own.$B$BFollow da coast east from da Landing. Ya will find dere canoes at Slimer Bay, a war camp past dem, an'' bunkers on da heights. Get close enough to count dem, den come back an'' tell me what we be facing.', 'Return to Elder Zul''jin at Warden''s Landing.', 400591, 1, 400592, 1, 400593, 1, 'Slimer Bay canoes scouted', 'Zandalari War Camp scouted', 'Bunkers on the heights scouted', 12340),
(400345, 2, 80, 80, 5006, 0, 0, 5, 150000, 8, 400456, 8, 0, 'Blood and Bone', 'Slay 8 Zandalari Dinomancers on the Isles of Giants for Elder Zul''jin at Warden''s Landing.', 'Da war camp be full of Dinomancers, $n. Binders. Dey chain a beast''s spirit to dere will, an'' every dinosaur on dis island be a weapon to dem. I have seen a devilsaur walk into fire because a binder told it to.$B$BThin dem out before da next tide comes in. Eight of dem, an'' da beasts sleep easier.', 'Return to Elder Zul''jin at Warden''s Landing.', 400580, 8, 0, 0, 0, 0, '', '', '', 12340),
(400346, 2, 80, 80, 5006, 1, 3, 5, 200000, 8, 400456, 10, 0, 'The High Ritualist', 'Slay High Ritualist Zor''kesh in the caves beneath the western plateau for Elder Zul''jin at Warden''s Landing.', 'One name came up on every binder ya put down: Zor''kesh. He be da one who reads da tide an'' tells da War-God when to sail. He hides in da caves under da plateau west of da tar pits, wit'' his bone collectors around him.$B$BTake friends, $n, an'' take his head. Without him dey must guess at da storm.', 'Return to Elder Zul''jin at Warden''s Landing.', 400276, 1, 0, 0, 0, 0, '', '', '', 12340),
(400347, 2, 80, 80, 5006, 1, 5, 5, 500000, 8, 400456, 25, 0, 'The War-God''s Deck', 'Board the Zandalari flagship off the south-east shore and slay War-God Dokah for Elder Zul''jin at Warden''s Landing.', 'Dere be only one way to end a tide, $n. Ya go to where it comes from.$B$BDokah stands on da high deck of dat flagship, an'' he has never lost a battle he fought himself. Fly out, gather everyone ya trust, an'' cut him down in front of his own crew. Every time he falls, da foothold dey hold on dis island falls wit'' him.', 'Return to Elder Zul''jin at Warden''s Landing.', 400581, 1, 0, 0, 0, 0, '', '', '', 12340),
(400348, 2, 80, 80, 5006, 0, 0, 5, 150000, 4104, 400456, 3, 0, 'Cut Their Chains', 'Free 3 Captive Beast Hunters from the Zandalari cages at Slimer Bay and the bunkers.', 'Da cages at Slimer Bay an'' da bunkers be full of hunters dey took alive. Dey plan to feed dem to da beasts, or worse, to da Loa.$B$BBreak dem out, $n. Every one ya free picks up a spear at da next landing, an'' dat line needs all da spears it can get.', 'Return to Elder Zul''jin at Warden''s Landing.', 400590, 3, 0, 0, 0, 0, 'Beast Hunters freed', '', '', 12340),
(400349, 2, 80, 80, 5006, 0, 0, 5, 150000, 4104, 400456, 3, 0, 'Spike the Engines', 'Set off 2 powder charges at the Zandalari war engines near the War Camp and the bunkers.', 'Dose engines be stacked wit'' powder, an'' Zandalari crews be careless wit'' it. Find da charges dey left beside da engines an'' set dem off.$B$BDey will mend what ya break, but every shot dey cannot fire at da next assault be one less on da heads of my people.', 'Return to Elder Zul''jin at Warden''s Landing.', 400599, 2, 0, 0, 0, 0, 'War engines sabotaged', '', '', 12340),
(400350, 2, 80, 80, 5006, 0, 0, 5, 150000, 4104, 400456, 3, 0, 'Thin the Binders', 'Slay 6 Zandalari Dinomancers on the Isles of Giants.', 'New binders come in on every canoe, $n. Da fewer dere be when da drums start, da fewer beasts dey throw at our line.', 'Return to Elder Zul''jin at Warden''s Landing.', 400580, 6, 0, 0, 0, 0, '', '', '', 12340),
(400351, 2, 80, 80, 5006, 0, 0, 5, 250000, 4104, 400456, 5, 0, 'Scuttle the Longboats', 'During a Zandalari invasion, cut down 2 War Standards at the landings on Seeping Shores.', 'When da longboats beach, dey plant a standard at every landing. As long as it stands, more raiders come ashore behind it.$B$BNext time da tide comes in, cut down two of dem an'' choke da landing.', 'Return to Elder Zul''jin at Warden''s Landing.', 400597, 2, 0, 0, 0, 0, 'War Standards cut down', '', '', 12340),
(400352, 2, 80, 80, 5006, 0, 0, 5, 250000, 4104, 400456, 8, 0, 'Break the War Plan', 'During a Zandalari invasion, help destroy the objectives of one Zandalari war plan.', 'Rak''zor never fights a battle wit'' one idea, $n. Rituals, stampedes, engines, bombers. Each assault he draws a different plan, an'' if it finishes, da line pays for it.$B$BNext time, listen for da plan an'' break it before it breaks us.', 'Return to Elder Zul''jin at Warden''s Landing.', 400598, 1, 0, 0, 0, 0, 'Zandalari war plan broken', '', '', 12340),
(400353, 2, 80, 80, 5006, 0, 0, 5, 350000, 4104, 400456, 8, 0, 'The Warlord''s Head', 'Slay Warlord Zul''mar during a Zandalari invasion.', 'Zul''mar was a boy when I left da Empire. Now he be dere finest butcher. When he comes ashore I will meet him on da sand, but I am old, $n, an'' I would not mind da help.', 'Return to Elder Zul''jin at Warden''s Landing.', 400336, 1, 0, 0, 0, 0, '', '', '', 12340);

DELETE FROM `quest_template_addon` WHERE `ID` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `SpecialFlags`) VALUES
(400344, 0, 0),
(400345, 400344, 0),
(400346, 400345, 0),
(400347, 400346, 0),
(400348, 400344, 1),
(400349, 400344, 1),
(400350, 400345, 1),
(400351, 0, 1),
(400352, 0, 1),
(400353, 0, 1);

DELETE FROM `quest_offer_reward` WHERE `ID` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(400344, 1, 0, 0, 0, 0, 0, 0, 0, 'Ya saw dem wit'' ya own eyes now. Good. Nobody believes an old exile until da drums start.', 12340),
(400345, 1, 0, 0, 0, 0, 0, 0, 0, 'Eight fewer chains on dis island. Ya have a heavy hand, $c. Da Empire would have made use of ya.', 12340),
(400346, 1, 0, 0, 0, 0, 0, 0, 0, 'Zor''kesh is dead? Den da War-God sails blind. Let him. A blind god still has a ship.', 12340),
(400347, 1, 0, 0, 0, 0, 0, 0, 0, 'Ya killed a War-God on his own deck. I have waited a long, long time to hear dat. Whatever da Empire calls itself now, today it knows fear of dis island.', 12340),
(400348, 1, 0, 0, 0, 0, 0, 0, 0, 'Good. Dey be limping back to da Landing already, an'' dey be angry. I like dem angry.', 12340),
(400349, 1, 0, 0, 0, 0, 0, 0, 0, 'I heard dat all da way from da Landing. Beautiful.', 12340),
(400350, 1, 0, 0, 0, 0, 0, 0, 0, 'Six more. Keep dem scared, $c. Scared binders make for weak chains.', 12340),
(400351, 1, 0, 0, 0, 0, 0, 0, 0, 'No standard, no boats. Dey learn slowly, but dey learn.', 12340),
(400352, 1, 0, 0, 0, 0, 0, 0, 0, 'His plan be ash, an'' his temper wit'' it. Well struck.', 12340),
(400353, 1, 0, 0, 0, 0, 0, 0, 0, 'He fought well for a fool. Rest, $c. Dey will send another.', 12340);

DELETE FROM `quest_request_items` WHERE `ID` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(400344, 1, 1, 'What did ya see out dere, $n?', 12340),
(400345, 1, 1, 'Da binders still breathe, $n.', 12340),
(400346, 1, 1, 'Zor''kesh still reads da tide, $n.', 12340),
(400347, 1, 1, 'Da War-God still stands on his deck, $n.', 12340),
(400348, 1, 1, 'Dose hunters be runnin'' out of time, $n.', 12340),
(400349, 1, 1, 'Dose engines still stand, $n.', 12340),
(400350, 1, 1, 'Da binders still work, $n.', 12340),
(400351, 1, 1, 'Da standards still fly over da beach, $n.', 12340),
(400352, 1, 1, 'Rak''zor''s plans still run, $n.', 12340),
(400353, 1, 1, 'Zul''mar still draws breath, $n.', 12340);

DELETE FROM `creature_queststarter` WHERE `quest` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(400200, 400344),
(400200, 400345),
(400200, 400346),
(400200, 400347),
(400200, 400348),
(400200, 400349),
(400200, 400350),
(400200, 400351),
(400200, 400352),
(400200, 400353);

DELETE FROM `creature_questender` WHERE `quest` IN (400344, 400345, 400346, 400347, 400348, 400349, 400350, 400351, 400352, 400353);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(400200, 400344),
(400200, 400345),
(400200, 400346),
(400200, 400347),
(400200, 400348),
(400200, 400349),
(400200, 400350),
(400200, 400351),
(400200, 400352),
(400200, 400353);
