-- Castle Nathria (map 2296) -- C++-summoned add creature_templates (19).
-- The full-port audit (2026-07-20) cross-checked every NPC entry the boss AI references against
-- creature_template and found 21 C++-summoned adds with NO template row -- the same gap class as
-- 13_reverberation_stalker.sql (the 05 transcode only covered statically-spawned entries; adds are
-- summoned by boss AI via SummonCreature, which silently returns nullptr for unknown entries,
-- breaking the mechanic without an error). Source rows: shadowcore SLDB_902_world_2021_03_12.sql;
-- stats normalized to the 05-transcode conventions (level 80, exp 2, faction 14, DamageModifier 1;
-- markers use the invisible-stalker convention from 175102). ScriptNames bind the C++ AIs registered
-- in the boss files (RegisterCastleNathriaCreatureAI) -- incl. npc_nightcloak on 174161/173164,
-- closing the "DB binds only 174126/174134" gap noted in boss_sire_denathrius.cpp.
-- Display substitutions (SL display not deployed client-side): Begrudging Waiter 96006->94015
-- (Dutiful Attendant model), Veteran Stoneguard 96710->96699 (Stone Legion Commando model).
-- Shade of Kael'thas (165805) is faction 35 (friendly): the raid HEALS him during Sun King's Salvation.
--
-- Apply to acore_world.

DELETE FROM `creature_template` WHERE `entry` IN (165762,165805,167691,167999,168317,168962,169219,169271,169813,169924,169925,170199,170710,171557,172803,172993,173053,173164,174080,174161,175992);
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
(165762, 0, 0, 0, 0, 0, 'Soul Infuser', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5.5, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(165805, 0, 0, 0, 0, 0, 'Shade of Kael''thas', NULL, NULL, 0, 80, 80, 2, 35, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 150, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_shade_of_kaelthas', NULL),
(167691, 0, 0, 0, 0, 0, 'Stasis Trap', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 768, 2048, 0, 0, 10, 16778240, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5, 1, 1, 1, 0, 0, 1, 0, 128, '', NULL),
(167999, 0, 0, 0, 0, 0, 'Echo of Sin', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_echo_of_sin', NULL),
(168317, 0, 0, 0, 0, 0, 'Fleeting Spirit', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 8, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_fleeting_spirit', NULL),
(168962, 0, 0, 0, 0, 0, 'Reborn Phoenix', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(169219, 0, 0, 0, 0, 0, 'Seed of Extinction', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(169271, 0, 0, 0, 0, 0, 'Rift Blast Portal', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 768, 2048, 0, 0, 10, 16778240, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 128, '', NULL),
(169813, 0, 0, 0, 0, 0, 'Hand of Destruction', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 12, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_hand_of_destruction', NULL),
(169924, 0, 0, 0, 0, 0, 'Veteran Stoneguard', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 8, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(169925, 0, 0, 0, 0, 0, 'Begrudging Waiter', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 4, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(170199, 0, 0, 0, 0, 0, 'Harnessed Specter', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL),
(170710, 0, 0, 0, 0, 0, 'Sinister Reflection', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_sinister_reflection', NULL),
(171557, 0, 0, 0, 0, 0, 'Shade of Bargast', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_shade_of_bargast', NULL),
(172803, 0, 0, 0, 0, 0, 'Afterimage of Baroness Frieda', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_afterimage', NULL),
(172993, 0, 0, 0, 0, 0, 'Afterimage of Castellan Niklaus', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_afterimage', NULL),
(173053, 0, 0, 0, 0, 0, 'Afterimage of Lord Stavros', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_afterimage', NULL),
(173164, 0, 0, 0, 0, 0, 'Countess Gloomveil', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 15, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_nightcloak', NULL),
(174080, 0, 0, 0, 0, 0, 'The Blood Lantern', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 0, 1, 1, 1, 768, 2048, 0, 0, 10, 16778240, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 128, '', NULL),
(174161, 0, 0, 0, 0, 0, 'Lady Sinsear', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 15, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_nightcloak', NULL),
(175992, 0, 0, 0, 0, 0, 'Dutiful Attendant', NULL, NULL, 0, 80, 80, 2, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 0, 1, 1, 1, 32768, 2048, 0, 0, 7, 2097224, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5, 1, 1, 1, 0, 0, 1, 0, 0, '', NULL);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (165762,165805,167691,167999,168317,168962,169219,169271,169813,169924,169925,170199,170710,171557,172803,172993,173053,173164,174080,174161,175992);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(165762, 0, 95921, 1, 1, NULL),
(165805, 0, 96807, 3, 1, NULL),
(167691, 0, 97057, 1, 1, NULL),
(167999, 0, 96648, 0.65, 1, NULL),
(168317, 0, 90428, 1.8, 1, NULL),
(168962, 0, 96959, 1, 1, NULL),
(169219, 0, 11686, 1, 1, NULL),
(169271, 0, 16925, 1, 1, NULL),
(169813, 0, 96951, 1, 1, NULL),
(169924, 0, 96699, 1, 1, NULL),
(169925, 0, 94015, 1, 1, NULL),
(170199, 0, 100563, 2, 1, NULL),
(170710, 0, 16925, 1, 1, NULL),
(171557, 0, 97677, 1, 1, NULL),
(172803, 0, 98071, 1, 1, NULL),
(172993, 0, 98173, 1, 1, NULL),
(173053, 0, 98193, 1, 1, NULL),
(173164, 0, 93055, 1, 1, NULL),
(174080, 0, 99063, 1, 1, NULL),
(174161, 0, 93611, 1.5, 1, NULL),
(175992, 0, 94015, 1.2, 1, NULL);
