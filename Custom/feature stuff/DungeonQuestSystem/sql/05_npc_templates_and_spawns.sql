-- ============================================
-- NPC Templates and Automatic Spawning
-- Creates quest master NPCs with automatic spawn locations
-- ============================================

-- ============================================
-- 1. Creature Templates (Quest Master NPCs)
-- ============================================

DELETE FROM `creature_template` WHERE `entry` IN (700000, 700001, 700002, 700003);

-- Classic Dungeon Quest Master (NPC 700000)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `minrangedmg`, `maxrangedmg`, `rangedattackpower`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `resistance1`, `resistance2`, `resistance3`, `resistance4`, `resistance5`, `resistance6`, `spell1`, `spell2`, `spell3`, `spell4`, `spell5`, `spell6`, `spell7`, `spell8`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `InhabitType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(700000, 15991, 'Dungeon Quest Master', 'Classic Dungeons', 'Directions', 0, 80, 80, 35, 3, 1, 1.14286, 1, 1, 0, 1, 2000, 2000, 1, 512, 2048, 0, 0, 0, 0, 0, 0, 1, 1, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 10, 1, 1, 1, 0, 0, 1, 0, 2, 'npc_dungeon_quest_master');

-- TBC Dungeon Quest Master (NPC 700001)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `minrangedmg`, `maxrangedmg`, `rangedattackpower`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `resistance1`, `resistance2`, `resistance3`, `resistance4`, `resistance5`, `resistance6`, `spell1`, `spell2`, `spell3`, `spell4`, `spell5`, `spell6`, `spell7`, `spell8`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `InhabitType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(700001, 21773, 'Dungeon Quest Master', 'Burning Crusade', 'Directions', 0, 80, 80, 35, 3, 1, 1.14286, 1, 1, 0, 1, 2000, 2000, 1, 512, 2048, 0, 0, 0, 0, 0, 0, 1, 1, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 10, 1, 1, 1, 0, 0, 1, 0, 2, 'npc_dungeon_quest_master');

-- WotLK Dungeon Quest Master (NPC 700002)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `minrangedmg`, `maxrangedmg`, `rangedattackpower`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `resistance1`, `resistance2`, `resistance3`, `resistance4`, `resistance5`, `resistance6`, `spell1`, `spell2`, `spell3`, `spell4`, `spell5`, `spell6`, `spell7`, `spell8`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `InhabitType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(700002, 26723, 'Dungeon Quest Master', 'Wrath of the Lich King', 'Directions', 0, 80, 80, 35, 3, 1, 1.14286, 1, 1, 0, 1, 2000, 2000, 1, 512, 2048, 0, 0, 0, 0, 0, 0, 1, 1, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 10, 1, 1, 1, 0, 0, 1, 0, 2, 'npc_dungeon_quest_master');

-- Daily/Weekly Quest Master (NPC 700003)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `minrangedmg`, `maxrangedmg`, `rangedattackpower`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `resistance1`, `resistance2`, `resistance3`, `resistance4`, `resistance5`, `resistance6`, `spell1`, `spell2`, `spell3`, `spell4`, `spell5`, `spell6`, `spell7`, `spell8`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `InhabitType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(700003, 28213, 'Quest Herald', 'Daily & Weekly Challenges', 'Directions', 0, 80, 80, 35, 3, 1, 1.14286, 1.2, 2, 0, 1, 2000, 2000, 1, 512, 2048, 0, 0, 0, 0, 0, 0, 1, 1, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 15, 1, 1, 1, 0, 0, 1, 0, 2, 'npc_dungeon_quest_daily_weekly');

-- ============================================
-- 2. Creature Model Info (Visual Appearance)
-- ============================================
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (15991, 21773, 26723, 28213);

INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
(15991, 0.383, 1.5, 0, 12340),  -- Classic model
(21773, 0.383, 1.5, 0, 12340),  -- TBC model
(26723, 0.383, 1.5, 0, 12340),  -- WotLK model
(28213, 0.5, 2.0, 0, 12340);    -- Daily/Weekly model (larger)

-- ============================================
-- 3. Automatic Spawn Locations
-- ============================================

-- Delete existing spawns
DELETE FROM `creature` WHERE `id1` IN (700000, 700001, 700002, 700003);

-- ===== ALLIANCE CITIES =====

-- Stormwind City - Classic Quest Master (700000)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800001, 700000, 0, 1519, 5390, 1, 1, 0, -8522.86, 456.078, 104.818, 5.48033, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Stormwind City - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800002, 700003, 0, 1519, 5390, 1, 1, 0, -8520.12, 458.245, 104.818, 5.48033, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Ironforge - Classic Quest Master (700000)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800003, 700000, 0, 1537, 809, 1, 1, 0, -4921.07, -956.564, 501.455, 2.18166, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Ironforge - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800004, 700003, 0, 1537, 809, 1, 1, 0, -4918.43, -958.822, 501.455, 2.18166, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- ===== HORDE CITIES =====

-- Orgrimmar - Classic Quest Master (700000)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800005, 700000, 1, 1637, 1653, 1, 1, 0, 1577.35, -4439.39, 15.4389, 1.95477, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Orgrimmar - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800006, 700003, 1, 1637, 1653, 1, 1, 0, 1579.68, -4437.12, 15.4389, 1.95477, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Undercity - Classic Quest Master (700000)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800007, 700000, 0, 1497, 1519, 1, 1, 0, 1633.75, 219.402, -62.1784, 3.28122, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Undercity - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800008, 700003, 0, 1497, 1519, 1, 1, 0, 1636.18, 221.545, -62.1784, 3.28122, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- ===== TBC LOCATIONS =====

-- Shattrath City - TBC Quest Master (700001)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800009, 700001, 530, 3703, 3703, 1, 1, 0, -1822.53, 5299.58, -12.4281, 3.92699, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Shattrath City - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800010, 700003, 530, 3703, 3703, 1, 1, 0, -1819.87, 5301.95, -12.4281, 3.92699, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- ===== WOTLK LOCATIONS =====

-- Dalaran - WotLK Quest Master (700002)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800011, 700002, 571, 4395, 4395, 1, 1, 0, 5812.75, 588.186, 660.937, 1.88495, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- Dalaran - Daily/Weekly Herald (700003)
INSERT INTO `creature` (`guid`, `id1`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(800012, 700003, 571, 4395, 4395, 1, 1, 0, 5815.22, 590.445, 660.937, 1.88495, 300, 0, 0, 1, 0, 0, 3, 512, 0, '', 0);

-- ============================================
-- 4. NPC Text (Gossip Messages)
-- ============================================
DELETE FROM `npc_text` WHERE `ID` IN (700001, 700002, 700003, 700004);

-- Classic Quest Master
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
(700001, 'Greetings, $c! I offer quests for Classic dungeons. These legendary places hold great challenges and rewards.$B$BWhat type of quest interests you?', '', 0, 0, 1, 1, 0, 0, 0, 0, 0);

-- TBC Quest Master  
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
(700002, 'Welcome to Outland, $c! The dungeons of the Burning Crusade await. Are you prepared?$B$BChoose your quest category:', '', 0, 0, 1, 1, 0, 0, 0, 0, 0);

-- WotLK Quest Master
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
(700003, 'The frozen wastes of Northrend hold many challenges, $c. The dungeons here will test your mettle.$B$BWhat quest do you seek?', '', 0, 0, 1, 1, 0, 0, 0, 0, 0);

-- Daily/Weekly Herald
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
(700004, 'Greetings, champion! I have special daily and weekly challenges for you. Complete them for bonus rewards!$B$BToday\'s challenges refresh at 6:00 AM server time. Weekly challenges refresh every Wednesday.', '', 0, 0, 1, 1, 0, 0, 0, 0, 0);

-- ============================================
-- 5. Creature Addon (Visual Effects)
-- ============================================
DELETE FROM `creature_addon` WHERE `guid` IN (800001, 800002, 800003, 800004, 800005, 800006, 800007, 800008, 800009, 800010, 800011, 800012);

-- Add slight visual effect to Daily/Weekly Herald (glowing aura)
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(800002, 0, 0, 0, 0, 0, 0, ''), -- Stormwind Daily Herald
(800004, 0, 0, 0, 0, 0, 0, ''), -- Ironforge Daily Herald
(800006, 0, 0, 0, 0, 0, 0, ''), -- Orgrimmar Daily Herald
(800008, 0, 0, 0, 0, 0, 0, ''), -- Undercity Daily Herald
(800010, 0, 0, 0, 0, 0, 0, ''), -- Shattrath Daily Herald
(800012, 0, 0, 0, 0, 0, 0, ''); -- Dalaran Daily Herald

-- ============================================
-- SPAWN LOCATION SUMMARY
-- ============================================
-- NPC 700000 (Classic Quest Master):
--   - Stormwind City (Trade District)
--   - Ironforge (The Commons)
--   - Orgrimmar (Valley of Strength)
--   - Undercity (Trade Quarter)
--
-- NPC 700001 (TBC Quest Master):
--   - Shattrath City (Center of City)
--
-- NPC 700002 (WotLK Quest Master):
--   - Dalaran (Krasus' Landing)
--
-- NPC 700003 (Daily/Weekly Herald):
--   - All major cities (next to expansion quest masters)
--
-- Total NPCs Spawned: 12
-- Total Spawn Points: 12 (6 cities × 2 NPCs per city, except Shattrath/Dalaran)
--
-- GUID Range: 800001-800012
-- All NPCs have:
--   - npcflag 3 (gossip + quest giver)
--   - faction 35 (friendly to all)
--   - 300 second respawn
--   - No movement (MovementType 0)
