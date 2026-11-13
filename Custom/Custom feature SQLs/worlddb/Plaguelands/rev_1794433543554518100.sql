-- DarkChaos: map 751 (Lordaeron 130-160) - Alliance route, phase 1, file 1 of 3: NPCs and spawns
-- Set, apply in this order: rev_1794433543554518100.sql (NPCs), rev_1794433543678762600.sql (quests),
-- rev_1794433543806034000.sql (travel).
--
-- The 7th Legion Base Camp (subzone 16809, southern Silverpine on the Gilneas border) becomes the Alliance
-- camp: General Marstone, the Gilneas Liberation Front (Lord Darius Crowley, Krennan Aranas), SI:7, an
-- innkeeper, a gryphon master, a quartermaster, a submarine captain (ride to the Tirisfal landing), guards,
-- a Spirit Healer and a DC-WoW Teleporter. Plus: a 7th Legion courier at Light's Hope and Chillwind Camp,
-- the Whispering Shore landing in Tirisfal, Zazzo Twinklefingers (SI:7 contact) in Gilneas City, the
-- Kirin Tor waypoint at Ambermill (subzone 16642) and three NPCs + a gryphon master at the Stormpike camp.
--
-- IDS (all verified free in the live acore_world on 2026-11-12)
--   creature_template 830301-830323 (830300 is Innkeeper Brumli), spawns 9025101-9025137, gameobject 9025001,
--   gossip_menu / npc_text 751001-751002.
-- DISPLAYS: every display id is already used by a live template and has a creature_model_info row.
-- Z VALUES come from the terrain heightmap of the test client's map-751 ADTs (MCVT, the client's own
-- interpolation; checked against 20 existing spawns: mean |dz| 0.10, max 0.24). Walk the spots with .gps
-- anyway: buildings and doodads are not in a heightmap.
-- ALSO: removes the two Marsh Crocolisk spawns that stood inside the camp (guids 16714587, 16714590).
--   Revert (restore them): creature rows
--   (16714587, 4145896, 751, 4935, 4935, 1, 1, 0, -647.985, 1680.94, 28.7703, 2.05064, 300, 10, 0, 1, 0, 1,
--    0, 0, 0, '', 0, 0, 'Lordaeron-ext') and
--   (16714590, 4145896, 751, 4935, 4935, 1, 1, 0, -711.093, 1694.01, 27.471, 5.83836, 300, 10, 0, 1, 0, 1,
--    0, 0, 0, '', 0, 0, 'Lordaeron-ext'), plus creature_addon (guid, 0, 0, 0, 1, 0, 0, NULL) for both.
--
-- Re-runnable: templates are REPLACEd, every INSERT is preceded by a DELETE of exactly its keys.
-- Apply to acore_world, then restart the worldserver. Files 2 and 3 of this set need this one.

-- 1. creature_template (REPLACE: template rows are never deleted)
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(830301, 0, 0, 0, 0, 0, 'General Marstone', '7th Legion', NULL, 0, 140, 140, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830302, 0, 0, 0, 0, 0, 'Lord Darius Crowley', 'Gilneas Liberation Front', NULL, 0, 140, 140, 0, 2166, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830303, 0, 0, 0, 0, 0, 'Krennan Aranas', 'Royal Chemist', NULL, 0, 140, 140, 0, 2166, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 8, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830304, 0, 0, 0, 0, 0, 'Sergeant Ironfoot', '7th Legion Engineer', NULL, 0, 140, 140, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830305, 0, 0, 0, 0, 0, 'Field Agent Renwick', 'SI:7', NULL, 0, 140, 140, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 4, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830306, 0, 0, 0, 0, 0, 'Captain Hartwell', '7th Legion Submarine', NULL, 751001, 140, 140, 0, 123, 3, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830307, 0, 0, 0, 0, 0, 'Innkeeper Hallam', 'Innkeeper', NULL, 345, 140, 140, 0, 123, 66177, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830308, 0, 0, 0, 0, 0, 'Gryphon Master Tolvan', 'Gryphon Master', NULL, 6944, 140, 140, 0, 123, 8193, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830309, 0, 0, 0, 0, 0, 'Quartermaster Brannigan', '7th Legion Quartermaster', NULL, 0, 140, 140, 0, 123, 4224, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830310, 0, 0, 0, 0, 0, '7th Legion Infantry', NULL, NULL, 0, 140, 140, 0, 123, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 32768, '', 0),
(830311, 0, 0, 0, 0, 0, 'Worgen Warbringer', 'Gilneas Liberation Front', NULL, 0, 140, 140, 0, 2166, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 32768, '', 0),
(830312, 0, 0, 0, 0, 0, '7th Legion Courier', NULL, NULL, 0, 150, 150, 0, 123, 2, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.3, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830313, 0, 0, 0, 0, 0, 'Scout Ellery Halvorsen', '7th Legion', NULL, 0, 136, 136, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 4, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830314, 0, 0, 0, 0, 0, 'Submarine Crewman', '7th Legion', NULL, 751002, 136, 136, 0, 123, 1, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830315, 0, 0, 0, 0, 0, 'Zazzo Twinklefingers', 'Assassin''s League', NULL, 0, 140, 140, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 8, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830316, 0, 0, 0, 0, 0, 'Magus Lyria Ashcombe', 'Kirin Tor', NULL, 0, 140, 140, 0, 76, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 8, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830317, 0, 0, 0, 0, 0, 'Ranger Corwin Dale', '7th Legion', NULL, 0, 140, 140, 0, 123, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830318, 0, 0, 0, 0, 0, 'Gryphon Master Dorrin', 'Gryphon Master', NULL, 6944, 140, 140, 0, 123, 8193, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830319, 0, 0, 0, 0, 0, 'Kirin Tor Battle-Mage', NULL, NULL, 0, 140, 140, 0, 76, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 8, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 32768, '', 0),
(830320, 0, 0, 0, 0, 0, 'Gryphon Master Hilda Stonepeak', 'Gryphon Master', NULL, 6944, 142, 142, 0, 1334, 8193, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830321, 0, 0, 0, 0, 0, 'Commander Brannoc Stonebrow', 'Stormpike Guard', NULL, 0, 142, 142, 0, 1334, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830322, 0, 0, 0, 0, 0, 'Lieutenant Farren Orinelle', NULL, NULL, 0, 142, 142, 0, 1334, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0),
(830323, 0, 0, 0, 0, 0, 'Marshal Redpath', NULL, NULL, 0, 142, 142, 0, 1334, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0);

-- 2. models (displays reused from live 751 templates)
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830301 AND 830323;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(830301, 0, 36321, 1, 1, 0),
(830302, 0, 34386, 1, 1, 0),
(830303, 0, 3981, 1, 1, 0),
(830304, 0, 36375, 1, 1, 0),
(830305, 0, 36258, 1, 1, 0),
(830306, 0, 36316, 1, 1, 0),
(830307, 0, 4044, 1, 1, 0),
(830308, 0, 33420, 1, 1, 0),
(830309, 0, 36330, 1, 1, 0),
(830310, 0, 36316, 1, 1, 0),
(830310, 1, 36318, 1, 1, 0),
(830310, 2, 36319, 1, 1, 0),
(830310, 3, 36320, 1, 1, 0),
(830311, 0, 36072, 1, 1, 0),
(830311, 1, 36074, 1, 1, 0),
(830311, 2, 36075, 1, 1, 0),
(830311, 3, 36076, 1, 1, 0),
(830312, 0, 36330, 1, 1, 0),
(830313, 0, 36262, 1, 1, 0),
(830314, 0, 36318, 1, 1, 0),
(830315, 0, 3719, 1, 1, 0),
(830316, 0, 3718, 1, 1, 0),
(830317, 0, 3632, 1, 1, 0),
(830318, 0, 7250, 1, 1, 0),
(830319, 0, 3602, 1, 1, 0),
(830319, 1, 3603, 1, 1, 0),
(830320, 0, 12549, 1, 1, 0),
(830321, 0, 36339, 1, 1, 0),
(830322, 0, 1769, 1, 1, 0),
(830323, 0, 1861, 1, 1, 0);

-- 3. equipment (item displays copied from live 751 NPCs of the same role)
DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 830301 AND 830323;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830301, 1, 13312, 6254, 5258, 0),
(830302, 1, 40967, 40968, 0, 0),
(830304, 1, 12934, 1985, 0, 0),
(830310, 1, 12890, 12981, 5259, 0),
(830311, 1, 40967, 40968, 0, 0),
(830316, 1, 2177, 0, 0, 0),
(830317, 1, 1901, 0, 2552, 0),
(830319, 1, 2177, 0, 0, 0),
(830321, 1, 12890, 12981, 5259, 0);

-- 4. vendor lists, copied at apply time: the innkeeper sells what Innkeeper Brumli (830300) sells, the
--    quartermaster what the 751 general-goods provisioner (4145484) sells, and repairs.
DELETE FROM `npc_vendor` WHERE `entry` = 830307;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT 830307, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, 0 FROM `npc_vendor` WHERE `entry` = 830300;
DELETE FROM `npc_vendor` WHERE `entry` = 830309;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT 830309, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, 0 FROM `npc_vendor` WHERE `entry` = 4145484;

-- 5. the submarine: gossip menus 751001 (Captain Hartwell, camp beach) and 751002 (crewman, Tirisfal)
DELETE FROM `npc_text` WHERE `ID` IN (751001, 751002);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `VerifiedBuild`) VALUES
(751001, 'The submarine lies just past the breakers, $N. She is quiet, she is cramped, and she will have you on the Tirisfal shore before the Forsaken know you have gone.', '', 0, 0, 1, 0),
(751002, 'The boat waits under the cliffs. Say the word and we will run you back down the coast to the 7th Legion camp.', '', 0, 0, 1, 0);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (751001, 751002);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(751001, 751001),
(751002, 751002);
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (751001, 751002);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(751001, 0, 2, 'Take me to the Whispering Shore in Tirisfal.', 0, 1, 1, 0, 0, 0, 0, '', 0, 0),
(751002, 0, 2, 'Take me back to the 7th Legion Base Camp.', 0, 1, 1, 0, 0, 0, 0, '', 0, 0);
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (830306, 830314) AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(830306, 0, 0, 1, 62, 0, 100, 0, 751001, 0, 0, 0, 0, 0, 72, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Captain Hartwell - On Gossip Option 0 Selected - Close Gossip'),
(830306, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 62, 751, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 2614, 1808, 17.31, 4.249, 'Captain Hartwell - Linked - Teleport Invoker to the Whispering Shore landing'),
(830314, 0, 0, 1, 62, 0, 100, 0, 751002, 0, 0, 0, 0, 0, 72, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Submarine Crewman - On Gossip Option 0 Selected - Close Gossip'),
(830314, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 62, 751, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, -552, 1694, 14.53, 3.08, 'Submarine Crewman - Linked - Teleport Invoker to the 7th Legion Base Camp beach');

-- 6. spawns (zone/area from the terrain of the test client, so the playerbot hub finder sees 4935/4936)
DELETE FROM `creature` WHERE `guid` BETWEEN 9025101 AND 9025137 AND `id` IN (6491, 800002, 830301, 830302, 830303, 830304, 830305, 830306, 830307, 830308, 830309, 830310, 830311, 830312, 830313, 830314, 830315, 830316, 830317, 830318, 830319, 830320, 830321, 830322, 830323);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9025101, 830301, 751, 4935, 16809, 1, 1, 1, -638, 1660, 30.3, 1.862, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: command tents'),
(9025102, 830302, 751, 4935, 16809, 1, 1, 1, -676, 1716, 30.67, 5.732, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: west tents'),
(9025103, 830303, 751, 4935, 16809, 1, 1, 0, -684, 1706, 30.71, 6.109, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: west tents'),
(9025104, 830304, 751, 4935, 16809, 1, 1, 1, -668, 1737, 31.12, 5.165, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: west wagon / weapon racks'),
(9025105, 830305, 751, 4935, 16809, 1, 1, 0, -654, 1655, 30.47, 1.482, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: command tents, gun rack'),
(9025106, 830306, 751, 4935, 16809, 1, 1, 0, -548, 1688, 13.63, 3.024, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: beach, powder kegs'),
(9025107, 830307, 751, 4935, 16809, 1, 1, 0, -606, 1761, 30.74, 4.088, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: north tents'),
(9025108, 830308, 751, 4935, 16809, 1, 1, 0, -580, 1686, 14.74, 2.944, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: beach, large tent'),
(9025109, 830309, 751, 4935, 16809, 1, 1, 0, -617, 1757, 30.96, 4.188, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: north tents'),
(9025110, 830310, 751, 4935, 16801, 1, 1, 1, -702, 1688, 27.9, 3.121, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard west'),
(9025111, 830310, 751, 4935, 16801, 1, 1, 1, -702, 1748, 30.53, 3.121, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard west'),
(9025112, 830310, 751, 4935, 16809, 1, 1, 1, -662, 1630, 30.44, 4.215, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard south'),
(9025113, 830310, 751, 4935, 16809, 1, 1, 1, -622, 1795, 27.2, 1.779, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard north-west'),
(9025114, 830310, 751, 4935, 16809, 1, 1, 1, -560, 1650, 13.83, 5.588, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard beach east'),
(9025115, 830310, 751, 4935, 16809, 1, 1, 1, -552, 1702, 14.41, 0.678, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: guard beach north'),
(9025116, 830311, 751, 4935, 16801, 1, 1, 1, -718, 1704, 30.51, 3.177, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: GLF facing the ridge'),
(9025117, 830311, 751, 4935, 16801, 1, 1, 1, -718, 1722, 30.62, 3.07, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: GLF facing the ridge'),
(9025118, 830311, 751, 4935, 16801, 1, 1, 1, -712, 1684, 27.79, 3.342, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: GLF facing the ridge'),
(9025119, 830311, 751, 4935, 16809, 1, 1, 1, -692, 1652, 30.22, 3.847, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: GLF facing the ridge'),
(9025120, 6491, 751, 4935, 16809, 1, 1, 0, -625, 1625, 31.04, 1.893, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Spirit Healer at graveyard 15140'),
(9025121, 800002, 751, 4935, 16809, 1, 1, 0, -650.19, 1702.4, 31.46, 4.066, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Teleporter, 3 yd in front of the 510 arrival'),
(9025122, 830312, 751, 4924, 16734, 1, 1, 0, 2250, -5230, 76.32, 4.102, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Light''s Hope, beside the 508 arrival'),
(9025123, 830312, 751, 4932, 16760, 1, 1, 0, 938, -1424, 65.7, 3.88, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Chillwind Camp, beside node 426'),
(9025124, 830313, 751, 4933, 16621, 1, 1, 0, 2618, 1803, 16.73, 4.2, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Whispering Shore landing'),
(9025125, 830314, 751, 4933, 16621, 1, 1, 0, 2610, 1815, 15.87, 4.302, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Whispering Shore landing'),
(9025126, 830310, 751, 4933, 16621, 1, 1, 1, 2622, 1795, 15.53, 4.093, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: landing guard'),
(9025127, 830310, 751, 4933, 16621, 1, 1, 1, 2600, 1825, 14.96, 1.571, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: landing guard'),
(9025128, 830315, 751, 4939, 16789, 1, 1, 0, -1387.9, 1235.2, 35.61, 3.75, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Gilneas City NE edge'),
(9025129, 830316, 751, 4935, 16642, 1, 1, 1, -100, 732, 64.69, 1.986, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Ambermill, east of the town hall'),
(9025130, 830317, 751, 4935, 16642, 1, 1, 1, -88, 726, 65.41, 2.087, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Ambermill, east of the town hall'),
(9025131, 830318, 751, 4935, 16642, 1, 1, 0, -40, 720, 65.41, 2.415, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Ambermill, east of the town hall'),
(9025132, 830319, 751, 4935, 16642, 1, 1, 1, -94, 742, 64.43, 0.037, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Ambermill guard'),
(9025133, 830319, 751, 4935, 16642, 1, 1, 1, -76, 738, 66.88, 4.021, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Ambermill guard'),
(9025134, 830320, 751, 4936, 16710, 1, 1, 0, -32.2, -321.2, 130.48, 4.82, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Stormpike camp row, west of Brumli'),
(9025135, 830321, 751, 4936, 16710, 1, 1, 1, -12.3, -322.4, 131.22, 4.82, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Stormpike camp row, east of Haggerdin'),
(9025136, 830322, 751, 4936, 16710, 1, 1, 0, -2, -334.5, 131.34, 4.4, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Stormpike camp'),
(9025137, 830323, 751, 4936, 16710, 1, 1, 0, 8.5, -345, 131.09, 4, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Stormpike camp');

-- 7. a mailbox at the inn tents (the 751 mailbox template 3781236)
DELETE FROM `gameobject` WHERE `guid` = 9025001 AND `id` = 3781236;
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9025001, 3781236, 751, 4935, 16809, 1, 1, -599, 1752, 29.01, 4, 0, 0, 0.909297, -0.416147, 120, 100, 1, '', 0, 'DC Alliance 751: 7th Legion Base Camp mailbox');

-- 8. two Marsh Crocolisks (level 139) stood inside the camp. Their 22 other spawns stay.
DELETE FROM `creature_addon` WHERE `guid` IN (16714587, 16714590);
DELETE FROM `creature` WHERE `guid` IN (16714587, 16714590) AND `id` = 4145896;

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'templates 830301-830323 (want 23)' AS `check`, COUNT(*) AS `n` FROM `creature_template` WHERE `entry` BETWEEN 830301 AND 830323
--   UNION ALL SELECT 'templates without a model (want 0)', COUNT(*) FROM `creature_template` WHERE `entry` BETWEEN 830301 AND 830323 AND `entry` NOT IN (SELECT `CreatureID` FROM `creature_template_model`)
--   UNION ALL SELECT 'spawns 9025101-9025137 (want 37)', COUNT(*) FROM `creature` WHERE `guid` BETWEEN 9025101 AND 9025137 AND `map` = 751
--   UNION ALL SELECT 'innkeeper + quartermaster vendor rows (want 37)', COUNT(*) FROM `npc_vendor` WHERE `entry` IN (830307, 830309)
--   UNION ALL SELECT 'crocodiles left inside the camp (want 0)', COUNT(*) FROM `creature` WHERE `guid` IN (16714587, 16714590);
