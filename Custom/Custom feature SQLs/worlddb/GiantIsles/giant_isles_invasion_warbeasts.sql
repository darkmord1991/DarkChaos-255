-- ============================================================================
-- GIANT ISLES - Invasion war-beasts (Phase 1 enhancement)
-- ----------------------------------------------------------------------------
-- The Zandalari weaponise the isle's primal dinosaurs. These spawn during the
-- invasion's "war-beast surge" chaos pulse (see dc_giant_isles_invasion.cpp).
-- They are invaders (faction 16, ScriptName npc_invasion_mob) and credit the
-- shared invasion kill-credit (400339), so they count for the daily/weekly.
-- Abilities are folded into the C++ npc_invasion_mob kit table (file _npcs.cpp).
--   400361 = Zandalari War-Direhorn  (charging bruiser, display 5305)
--   400362 = Zandalari Pterrordax Bomber (dive-bomb AoE, display 8412)
--   400363 = Primal Devilsaur Siege-Beast (rare-elite mini-boss, display 5240)
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` IN (400361, 400362, 400363);
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400361, 0, 0, 0, 400339, 0, 'Zandalari War-Direhorn', 'Primal Charger', '', 0, 81, 81, 2, 16, 0, 1.4, 1.6, 1, 1, 20, 1, 0, 6, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 400, 700, '', 0, 1, 30, 1, 3, 4, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340),
(400362, 0, 0, 0, 400339, 0, 'Zandalari Pterrordax Bomber', 'Skyborne Terror', '', 0, 80, 80, 2, 16, 0, 1.4, 1.5, 1, 1, 20, 0, 0, 5, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 12, 1, 1, 4, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340),
(400363, 0, 0, 0, 400339, 0, 'Primal Devilsaur', 'Zandalari Siege-Beast', '', 0, 82, 82, 2, 16, 0, 1.6, 1.7, 1, 1, 25, 2, 0, 10, 2000, 2000, 1, 1, 1, 0, 2048, 8, 0, 1, 0, 0, 0, 0, 0, 0, 1500, 2500, '', 0, 1, 80, 1, 4, 12, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400361, 400362, 400363);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400361, 0, 5305, 1.2, 1, 12340),  -- Direhorn
(400362, 0, 8412, 1.0, 1, 12340),  -- Pterrordax
(400363, 0, 5240, 1.3, 1, 12340);  -- Devilsaur (mini-boss, larger)
