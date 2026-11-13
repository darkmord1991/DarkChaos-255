-- Silverpine Forest on map 751, the "ruins" slice of the Neltharion 4.3.4 C++ port.
-- C++: src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_ruins.cpp (AddSC_dc_silverpine_ruins).
-- Needs the worldserver build that contains that file.
--
-- WHY THIS FILE CREATES TEMPLATES INSTEAD OF ONLY BINDING SCRIPTNAMES
--   None of the creatures these scripts drive existed in acore_world at either the plain or the
--   +4,100,000 id: the summon targets of the 112_ spells were never imported (100_ only covered
--   spells from 88_), and cata_world has no spawns for the Ruins of Gilneas tail of the questline.
--   Data comes from cata_world (templates) and nelt_world (the 4.3.4 DB the C++ was written for:
--   ScriptName bindings, creature_text, addon, quest relations). Templates use REPLACE, as template
--   rows must not be deleted; every id below was verified absent from creature_template,
--   creature_template_model / _addon / _movement, creature_text and smart_scripts on 2026-11-09.
--
-- IDS
--   45473 / 45474   Arthura / Deathstalker Commander Belmont, the Ruins of Gilneas guardians: PLAIN
--                   ids because 84941 / 84944 (112_) summon exactly these.
--   45766           Arcane Fiend: PLAIN, summoned by 87253.
--   45555-45557, 45605-45612, 45764
--                   summoned by the C++ itself (escape flight, Rise Godfrey cutscene, Ataeric's
--                   portals); kept at their plain ids like every other summon target.
--   4102120         Archmage Ataeric, the Cata 2120 for 751 (+4,100,000). Stock 2120 is a live map-0
--                   NPC with its own SmartAI and is NOT touched. Not spawned here, see below.
--
-- LEVELS follow the 751 band (Ruins of Gilneas 130-136, Silverpine 134-140) and the levels of the
--   clones already on 751 (Sylvanas 142, Cromush 146, val'kyr 137); modifiers as on those clones.
--   The two guardians are summoned as guardians and take the player's level anyway.
--
-- DEPARTURES FROM THE SOURCE DATA
--   * Displays 30735 (Ashbury), 30730 (Walden) and 35323 (Arcane Fiend) are not in the server's or
--     the client's CreatureDisplayInfo.dbc. Ashbury / Walden use their Forsaken displays 34610 /
--     34612 (the Shadowfang Keep copy's), the fiend uses stock Arcane Fiend 19702.
--   * Every cutscene actor gets unit_flags 768 (immune to players and NPCs) so a passing player of
--     the other faction cannot kill the cast mid-scene.
--   * Archmage Target 45764 also gets UNIT_FLAG_NOT_SELECTABLE; it is a beam target, nothing more.
--   * Phase / invisibility-detection auras (49415, 49417) and Cata loot are left out.
--   * 45555 keeps VehicleId 0, see below.
--
-- SUMMONPROPERTIES 3045 is used by 84941 / 84944 (this slice) and 85517 / 85519 (the battlefront
--   guardians) and is in neither the server SummonProperties.dbc (ids end at 2976) nor
--   summonproperties_dbc, so all five summons failed with "Unhandled summon type 3045". Row taken
--   from the Cata 4.3.4 client (enUS/locale-enUS.MPQ): 3045, 1, 0, 0, 0, 134922. Flags are cut to the
--   low 16 bits (0x0F0A = 3850) because 0x20000 does not exist in 3.3.5; 0x200 is the bit that makes
--   Spell::EffectSummonType summon a guardian. Server-side only.
--
-- QUEST RELATIONS: guardian Belmont (45474, npcflag 2) is the 4.3.4 ender of 27406 / 27423 and a
--   starter of 27438, mirrored from nelt_world. Those three quests exist here with the right titles;
--   none of them had an ender.
--
-- NOT IN THIS FILE (needed before the later scenes can be played, see the port report)
--   * Vehicle 1119 (seats 8562 / 8563) is in no 3.3.5 Vehicle.dbc / VehicleSeat.dbc, server or client.
--     An unknown vehicle hangs the client, so 45555 stays VehicleId 0 and the C++ refuses to summon
--     it until the template carries a vehicle the server resolves. Set VehicleId = 1119 only after
--     BOTH the client patch and vehicle_dbc / vehicleseat_dbc carry 1119 / 8562 / 8563.
--   * Quests 27472, 27484, 27512, 27518, 27542, 27594 and their givers 45525 / 45617, the corpse
--     44369 (27406's objective) and Archmage Ataeric's spawn (nelt_world: -136.002, 1067.24, 66.3516,
--     o 1.54514) are absent. 27423's objective 45495 has no KillCredit source on 751.

-- ---------------------------------------------------------------------------
-- 1. SummonProperties 3045
-- ---------------------------------------------------------------------------
-- SummonProperties 3045 is added by rev_1794231896144905400.sql with the other Cata summon rows.

-- ---------------------------------------------------------------------------
-- 2. creature_template
-- ---------------------------------------------------------------------------
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(45473, 0, 0, 0, 0, 0, 'Arthura', '', '', 0, 136, 136, 0, 68, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 2.4, 30, 20, 1, 1, 0, 0, 1, 0, 0, 'npc_arthura_ruins', 15595),
(45474, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont', '', '', 0, 136, 136, 0, 68, 2, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 4, 0, 2048, 0, 0, 7, 4096, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 15, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_belmont_guardian', 15595),
(45555, 0, 0, 0, 0, 0, 'Arthura', '', '', 0, 136, 136, 0, 35, 0, 1, 4, 1, 4, 20, 1, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, '', 0, 2.4, 30, 20, 1, 1, 0, 0, 1, 0, 0, 'npc_arthura_flight_escape', 15595),
(45556, 0, 0, 0, 0, 0, 'Lord Godfrey', '', '', 0, 135, 135, 0, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45557, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont', '', '', 0, 135, 135, 0, 35, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 4, 768, 2048, 0, 0, 7, 4096, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 15, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45605, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner', 'Banshee Queen', '', 0, 142, 142, 0, 118, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 2124, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 400, 20, 1, 1, 0, 0, 1, 0, 0, 'npc_sylvanas_rise_godfrey_scene', 15595),
(45606, 0, 0, 0, 0, 0, 'Lord Godfrey', '', '', 0, 136, 136, 0, 35, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 20, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45607, 0, 0, 0, 0, 0, 'Baron Ashbury', '', '', 0, 136, 136, 0, 35, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45608, 0, 0, 0, 0, 0, 'Lord Walden', '', '', 0, 136, 136, 0, 35, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45609, 0, 0, 0, 0, 0, 'Agatha', '', '', 0, 137, 137, 0, 68, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 2.4, 30, 20, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45610, 0, 0, 0, 0, 0, 'Daschla', '', '', 0, 137, 137, 0, 68, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 2.4, 30, 20, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45611, 0, 0, 0, 0, 0, 'Arthura', '', '', 0, 137, 137, 0, 68, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 2.4, 30, 20, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45612, 0, 0, 0, 0, 0, 'High Warlord Cromush', '', '', 0, 146, 146, 0, 29, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 15, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(45764, 0, 0, 0, 0, 0, 'Archmage Target', '', '', 0, 138, 138, 0, 35, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 2, 33555200, 2048, 0, 0, 7, 1048576, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 128, '', 15595),
(45766, 0, 0, 0, 0, 0, 'Arcane Fiend', '', '', 0, 138, 138, 0, 76, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.5, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595),
(4102120, 0, 0, 0, 0, 0, 'Archmage Ataeric', '', '', 0, 138, 138, 0, 76, 0, 0.94, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 4, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 20, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_archmage_ataeric_transdimentional_3', 15595);

-- ---------------------------------------------------------------------------
-- 3. creature_template_model (every display checked against the server's AND the client's
--    CreatureDisplayInfo.dbc; all have creature_model_info)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (45473, 45474, 45555, 45556, 45557, 45605, 45606, 45607, 45608, 45609, 45610, 45611, 45612, 45764, 45766, 4102120);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(45473, 0, 33997, 1, 1, 0),
(45474, 0, 34077, 1, 1, 0),
(45555, 0, 33997, 1, 1, 0),
(45556, 0, 29675, 1, 1, 0),
(45557, 0, 34077, 1, 1, 0),
(45605, 0, 28213, 1, 1, 0),
(45606, 0, 29675, 1, 1, 0),
(45607, 0, 34610, 1, 1, 0),
(45608, 0, 34612, 1, 1, 0),
(45609, 0, 33996, 1, 1, 0),
(45610, 0, 33997, 1, 1, 0),
(45611, 0, 33997, 1, 1, 0),
(45612, 0, 34009, 1, 1, 0),
(45764, 0, 22712, 1, 1, 0),
(45764, 1, 17188, 1, 1, 0),
(45766, 0, 19702, 1, 1, 0),
(4102120, 0, 3601, 1, 1, 0);

-- ---------------------------------------------------------------------------
-- 4. creature_template_movement. The val'kyr fly (Flight 1 = DisableGravity, as on the 751 clones);
--    the guardian Arthura follows the player, so she hovers over the ground (Ground 2) instead.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (45473, 45555, 45609, 45610, 45611, 45764);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`) VALUES
(45473, 2, 1, 0, 0, 0, 0, 0),
(45555, 0, 0, 1, 0, 0, 0, 0),
(45609, 0, 0, 1, 0, 0, 0, 0),
(45610, 0, 0, 1, 0, 0, 0, 0),
(45611, 0, 0, 1, 0, 0, 0, 0),
(45764, 0, 0, 1, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- 5. creature_template_addon (nelt_world): the val'kyr's flying anim tier, Belmont hiding as a
--    corpse until Arthura arrives, the three lords lying dead (29266) until Sylvanas raises them,
--    Sylvanas on her mount.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_addon` WHERE `entry` IN (45473, 45555, 45557, 45605, 45606, 45607, 45608, 45609, 45610, 45611);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(45473, 0, 0, 50331648, 1, 0, 0, ''),
(45555, 0, 0, 50331648, 1, 0, 0, ''),
(45557, 0, 0, 7, 1, 0, 0, ''),
(45605, 0, 29257, 0, 1, 0, 0, ''),
(45606, 0, 0, 7, 1, 0, 0, '29266'),
(45607, 0, 0, 7, 1, 0, 0, '29266'),
(45608, 0, 0, 7, 1, 0, 0, '29266'),
(45609, 0, 0, 50331648, 1, 0, 0, ''),
(45610, 0, 0, 50331648, 1, 0, 0, ''),
(45611, 0, 0, 50331648, 1, 0, 0, '');

-- ---------------------------------------------------------------------------
-- 6. creature_text (nelt_world; cata_world has none). Group ids are the ones the C++ calls.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (45555, 45557, 45605, 45606, 45612, 4102120);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(45555, 0, 0, 'What about you, Belmont. How will you get back?', 12, 0, 100, 0, 0, 0, 0, 0, 'Arthura - The Great Escape, player boarded'),
(45555, 1, 0, 'So be it. Farewell, Belmont.', 12, 0, 100, 0, 0, 0, 0, 0, 'Arthura - The Great Escape, take-off'),
(45555, 2, 0, 'Oh my... hang on tight!', 12, 0, 100, 0, 0, 0, 0, 0, 'Arthura - The Great Escape (unused by the C++)'),
(45557, 0, 0, 'I''ll be fine, Arthura. The worgen lost our scent. It''s doubtful that they even know we''re here.', 12, 0, 100, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont - The Great Escape'),
(45557, 1, 0, 'I''ll probably make it back to the Forsaken Front before you two, er, three.', 12, 0, 100, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont - The Great Escape'),
(45557, 2, 0, 'Now move out! You must not keep the Banshee Queen waiting.', 12, 0, 100, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont - The Great Escape'),
(45605, 0, 0, 'Rise, Lord Vincent Godfrey. Be reborn as an instrument of my vengeance!', 12, 0, 100, 25, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey'),
(45605, 1, 0, 'You live to serve me, Godfrey. Together we will crush the worgen uprising and retake Gilneas for the Forsaken.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey'),
(45605, 2, 0, 'Yes, of course...', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey'),
(45605, 3, 0, 'Prepare your men. The Gilneas Liberation Front amasses at the Greymane Wall. Soon their reinforcements from Stormwind will arrive. We haven''t a minute to waste.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey'),
(45605, 4, 0, 'Armor, weapons, whatever you may need, you will find at the supply depot behind me. Go now.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey'),
(45605, 5, 0, 'Once again you have impressed me, $n. Without your aid, we would have not made it this far. Walk with me...', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Rise, Godfrey, to the player'),
(45606, 0, 0, 'I live again...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Rise, Godfrey'),
(45606, 1, 0, 'The irony of what I have become is not lost upon me, Lady Sylvanas.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - Rise, Godfrey'),
(45606, 2, 0, 'Though as I have always said, better dead than worgen.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - Rise, Godfrey'),
(45606, 3, 0, 'Or in this case, better undead than worgen.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - Rise, Godfrey'),
(45606, 4, 0, 'As you wish, Banshee Queen.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - Rise, Godfrey'),
(45612, 0, 0, 'For the Horde...', 12, 0, 100, 5, 0, 0, 0, 0, 'High Warlord Cromush - Rise, Godfrey'),
(4102120, 0, 0, 'Minions, destroy the interloper! The shield must not come down!', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - event start'),
(4102120, 1, 0, 'Destroy Arcane Fiends near Archmage Ataeric to overload the shield!', 41, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - instruction'),
(4102120, 2, 0, 'You will not succeed, monster!', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - 20%'),
(4102120, 3, 0, 'We will... never... give up!', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - 40%'),
(4102120, 4, 0, 'The armies of the Alliance will march upon your bones!', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - 60%'),
(4102120, 5, 0, 'Lordaeron belongs to the Alliance. You only delay the inevitable...', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - 80%'),
(4102120, 6, 0, 'The power...is too much...I cannot hold...any longer...', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - 100%'),
(4102120, 7, 0, 'RUN! DO NOT LET THEM TURN YOU!', 14, 0, 100, 0, 0, 0, 0, 0, 'Archmage Ataeric - collapse');

-- ---------------------------------------------------------------------------
-- 7. Quest relations of the guardian Belmont (nelt_world creature_questrelation /
--    creature_involvedrelation).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `id` = 45474 AND `quest` IN (27406, 27438);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(45474, 27406),
(45474, 27438);

DELETE FROM `creature_questender` WHERE `id` = 45474 AND `quest` IN (27406, 27423);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(45474, 27406),
(45474, 27423);
