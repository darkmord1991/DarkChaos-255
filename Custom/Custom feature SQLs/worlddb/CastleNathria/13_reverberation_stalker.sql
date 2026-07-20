-- Castle Nathria (map 2296) -- Reverberation Stalker (175102), the Stone Legion Generals'
-- Reverberating Eruption ground-hazard marker. Not in the original 148-entry static-spawn scope
-- (it's C++-summoned by boss_stone_legion_generals.cpp via SummonCreature, never DB-spawned) --
-- missed by the 05_creature_templates.sql transcode pass and blocking that fight until added.
--
-- Source row: shadowcore SLDB_902_world_2021_03_12.sql. displayId uses the REMAPPED id: retail
-- 11686 collided with a stock 3.3.5 display and was remapped to 503517 in creature batch-1 (see
-- GO_DISPLAY_REMAP_NOTE.txt / DISPLAY_REMAP_NOTE.txt) -- using 503517 here, not the raw 11686.
-- unit_flags/type_flags/flags_extra mirror the other invisible "Stalker" trigger-marker entries
-- already in 05 (172661, 172989): non-selectable, passive ground marker.
--
-- Apply to acore_world.

DELETE FROM `creature_template` WHERE `entry` = 175102;
INSERT INTO `creature_template`
    (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`,
    `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
    `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`,
    `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(175102, 0, 0, 0, 0, 0, 'Reverberating Eruption Stalker', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 768, 2048, 0, 0, 10, 16778240, 175102, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 128, 'npc_reverberation_stalker', NULL);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 175102;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(175102, 0, 503517, 1, 1, NULL);
