-- ============================================================================
-- GIANT ISLES - Invasion Loa ritual objective (Phase 2 enhancement)
-- ----------------------------------------------------------------------------
-- During wave 3 the Zandalari witch doctors raise a Loa effigy on the contested
-- beach and channel a ritual (see dc_giant_isles_invasion.cpp -> StartLoaRitual).
-- The effigy is a passive, attackable idol the orchestrator manages entirely:
--   * Destroy it before the timer expires -> the ritual collapses (no buff).
--   * Let the timer run out -> the Loa answers and every invader gains
--     "Loa's Fury" (enrage, spell 8599) for the rest of the assault.
-- It never moves and never retaliates (REACT_PASSIVE + DISABLE_MOVE set in C++),
-- and RegenHealth = 0 so chip damage sticks and the kill is a real objective.
--   400364 = Loa Effigy (carved totem-pole display 16997, "Totem of Akida")
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` IN (400364);
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400364, 0, 0, 0, 0, 0, 'Loa Effigy', 'Zandalari Ritual', '', 0, 82, 82, 2, 16, 0, 1, 1, 1, 1, 5, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 80, 1, 2, 1, 0, 0, 0, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400364);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400364, 0, 16997, 1.8, 1, 12340);  -- carved Loa totem-pole effigy
