-- ============================================================================
-- GIANT ISLES - Invasion war economy (Phase 3 enhancement)
-- ----------------------------------------------------------------------------
-- Persistent-war reward loop for the Zandalari invasion:
--   * 400456  Zandalari War-Token  - currency awarded on victory, scaled by
--             personal kills, the campaign foothold and denying the Loa ritual
--             (granted from dc_giant_isles_invasion.cpp -> RewardParticipants).
--   * 400365  War Quartermaster     - gossip vendor that exchanges War-Tokens
--             for goods (ScriptName npc_giant_isles_war_quartermaster). The
--             exchange is fully server-side gossip; no ItemExtendedCost/DBC.
-- The campaign worldstate (20011) lives entirely in the C++ orchestrator.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- War-Token currency (class 10 token, like the emblem tokens: BoP, big stack)
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (400456);
INSERT INTO `item_template`
(`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `bonding`, `MaxCount`, `stackable`, `Material`, `description`) VALUES
(400456, 10, 0, 'Zandalari War-Token', 55045, 3, 0, 1, 0, 0, 1, 0, 2147483647, -1, 'Awarded for defending Seeping Shores against the Zandalari invasion. Spend it with the War Quartermaster.');

-- ---------------------------------------------------------------------------
-- War Quartermaster (gossip token vendor)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (400365);
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400365, 0, 0, 0, 0, 0, 'War Quartermaster', 'Seeping Shores Defense', '', 0, 80, 80, 2, 35, 1, 1, 1, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 20, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_giant_isles_war_quartermaster', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400365);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400365, 0, 23072, 1, 1, 12340);  -- Northrend expedition officer

-- Greeting text shown when the quartermaster gossip opens.
DELETE FROM `npc_text` WHERE `ID` IN (400365);
INSERT INTO `npc_text` (`ID`, `text0_0`, `Probability0`) VALUES
(400365, 'Stand fast, soldier. The Zandalari will break upon this shore. Bring me the War-Tokens you earn defending the beach and I will see you well supplied.', 1);

-- Quartermaster spawn behind the defender camp at Seeping Shores (map 1405).
DELETE FROM `creature` WHERE `guid` IN (9000301);
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9000301, 400365, 0, 0, 1405, 0, 0, 1, 1, 0, 5768.0, 1296.0, 12.4, 4.9, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Giant Isles - War Quartermaster');
