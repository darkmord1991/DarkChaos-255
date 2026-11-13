-- Silverpine Forest on map 751, the Battlefront slice of the Neltharion 4.3.4 C++ port.
-- C++: src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_battlefront.cpp (AddSC_dc_silverpine_battlefront).
--
-- WHY THIS FILE CREATES TEMPLATES INSTEAD OF ONLY BINDING SCRIPTNAMES
--   None of the six creatures these scripts drive existed in acore_world, and cata_world has no spawns
--   for them either (the Battlefront questline after 27513 was never imported). Data comes from
--   cata_world (templates, displays) and nelt_world (the 4.3.4 DB the C++ was written for: spawns,
--   spellclick, creature_text). Templates are written with REPLACE, as template rows must not be deleted.
--
-- IDS
--   45878 / 45879 / 45880  Lord Godfrey / Lord Walden / Baron Ashbury: PLAIN ids, because spells
--                          85517 / 85518 / 85519 (112_) summon exactly these ids.
--   4145910                Cowering Trooper, spawned, so cata id + 4,100,000.
--   4145997                Commander Lorna Crowley, spawned, so cata id + 4,100,000.
--   46002                  Lord Godfrey kill-credit marker for quest 27594. Never spawned; the template
--                          exists so a later quest import does not zero the objective.
--
-- LEVELS AND STATS follow the 751 band, not Cata's level 17-20: Silverpine is 134-140 (71_), stats as
--   106_ computes them (normal 0.5 x basehp2, elite 5 x basehp2, elite damage x2). The guardians are
--   summoned as guardians and take the player's level whatever the template says.
--
-- DEPARTURES FROM THE SOURCE DATA
--   * Lorna's displays (34520 and the older 30209 / 33474) are not in this server's CreatureDisplayInfo.dbc.
--     She uses 33615, the female Gilnean Envoy already on 751, until a display pass adds 34520.
--   * The guardians' type_flags drop 0x4 (BOSS_MOB) that Cata gave Godfrey: a world-boss flag on a
--     player's companion changes its combat rules.
--   * Cowering Trooper gets CREATURE_FLAG_EXTRA_NO_XP: one click in three ends with Godfrey (the player's
--     guardian) executing him, which would otherwise pay kill XP.
--   * Cata's aura 91166 ("cower emote") does not exist here; the script sets EMOTE_STATE_COWER instead,
--     so there is no creature_template_addon row.
--   * Equipment is left out: 52052 and 61512 are Cata items.
--
-- SPAWNS: guid block 11545900-11545922 (22 troopers + Lorna), verified empty on 2026-11-09 together with
--   creature_addon and negative smart_scripts guids. Positions are nelt_world's map-0 ones, which map 751
--   keeps. Phase masks are dropped (Lorna was phase 1536 on Cata): no phasing on 751.
--
-- NOT IN THIS FILE (needed before anything here can be played, see the port report):
--   * quests 27542 / 27547 / 27594 and their quest giver relations (none exist in acore_world);
--   * SummonProperties 3045, which 85517-85519 use and which is in neither SummonProperties.dbc nor
--     summonproperties_dbc, so the summon spells fail with "Unhandled summon type 3045".

-- ---------------------------------------------------------------------------
-- 1. creature_template
-- ---------------------------------------------------------------------------
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(45878, 0, 0, 0, 0, 0, 'Lord Godfrey', '', '', 0, 140, 140, 0, 68, 2, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 10, 1, 1, 0, 0, 1, 0, 0, 'npc_godfrey_battlefront_guardian', 15595),
(45879, 0, 0, 0, 0, 0, 'Lord Walden', '', '', 0, 140, 140, 0, 68, 2, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 6, 1, 1, 0, 0, 1, 0, 0, 'npc_walden_battlefront_guardian', 15595),
(45880, 0, 0, 0, 0, 0, 'Baron Ashbury', '', '', 0, 140, 140, 0, 68, 2, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 262144, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 6, 1, 1, 0, 0, 1, 0, 0, 'npc_ashbury_battlefront_guardian', 15595),
(4145910, 0, 0, 0, 0, 0, 'Cowering Trooper', '', 'Inspect', 0, 138, 138, 0, 68, 16777216, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 64, 'npc_cowering_trooper', 15595),
(4145997, 0, 0, 0, 0, 0, 'Commander Lorna Crowley', '', '', 0, 140, 140, 0, 2166, 0, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_lorna_majesty', 15595),
(46002, 0, 0, 0, 0, 0, 'Lord Godfrey', '', '', 0, 140, 140, 0, 68, 0, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595);

-- ---------------------------------------------------------------------------
-- 2. creature_template_model (all ids checked against the server's CreatureDisplayInfo.dbc)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (45878, 45879, 45880, 4145910, 4145997, 46002);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(45878, 0, 34611, 1, 1, 0),
(45879, 0, 34612, 1, 1, 0),
(45880, 0, 34610, 1, 1, 0),
(4145910, 0, 34378, 1, 1, 0),
(4145910, 1, 34379, 1, 1, 0),
(4145910, 2, 34380, 1, 1, 0),
(4145910, 3, 34381, 1, 1, 0),
(4145997, 0, 33615, 1, 1, 0),
(46002, 0, 34611, 1, 1, 0);

-- ---------------------------------------------------------------------------
-- 3. creature_text (nelt_world; cata_world has none). Group ids are the ones the C++ calls.
--    Two spelling slips in the source text are corrected, trailing blanks trimmed.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (45878, 4145910, 4145997);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(45878, 0, 0, 'The Dark Lady lets these mongrels live? Useless...', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 0, 1, 'These cowering troopers should die in shame. This is an embarrassment.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 0, 2, 'Cowardly dog. Run back to your mommy and hide.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 0, 3, 'Get out of my sight before I execute you!', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 0, 4, 'Worthless maggot.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 0, 5, 'I would have burned this whole place down with them in it...', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - rescued Cowering Trooper'),
(45878, 1, 0, 'He died in battle. Bow your heads...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - executes Cowering Trooper'),
(45878, 1, 1, 'Cowards don''t get to return home.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - executes Cowering Trooper'),
(45878, 1, 2, 'This is a mercy killing.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - executes Cowering Trooper'),
(45878, 2, 0, 'Lorna, is that how you greet old friends?', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - On Her Majesty''s Secret Service'),
(45878, 3, 0, 'My kingdom? My kingdom is no more.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - On Her Majesty''s Secret Service'),
(45878, 4, 0, 'Your father and Greymane saw to that... No, Gilneas died when they allowed murderous beasts to reign free. Unchecked.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - On Her Majesty''s Secret Service'),
(45878, 5, 0, 'Now lay down your arms and surrender. We are not here to kill you. Not yet.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lord Godfrey - On Her Majesty''s Secret Service'),
(45878, 6, 0, 'Quickly! We must head back to the Forsaken Front before we are discovered!', 12, 0, 100, 5, 0, 0, 0, 0, 'Lord Godfrey - Lorna Crowley captured'),
(4145910, 0, 0, 'Is it safe?', 12, 0, 100, 6, 0, 0, 0, 0, 'Cowering Trooper - clicked'),
(4145910, 0, 1, 'We overheard their orders... no survivors...', 12, 0, 100, 1, 0, 0, 0, 0, 'Cowering Trooper - clicked'),
(4145910, 0, 2, 'They''re EVERYWHERE! WATCH OUT!', 12, 0, 100, 5, 0, 0, 0, 0, 'Cowering Trooper - clicked'),
(4145910, 0, 3, 'Are... are they all dead?', 12, 0, 100, 6, 0, 0, 0, 0, 'Cowering Trooper - clicked'),
(4145910, 0, 4, 'They struck from the shadows. We didn''t stand a chance.', 12, 0, 100, 1, 0, 0, 0, 0, 'Cowering Trooper - clicked'),
(4145997, 0, 0, 'So the Banshee Queen has sent assassins?', 12, 0, 100, 6, 0, 0, 0, 0, 'Commander Lorna Crowley - player arrives'),
(4145997, 1, 0, 'Godfrey? So the rumors are true.', 12, 0, 100, 1, 0, 0, 0, 0, 'Commander Lorna Crowley - scene'),
(4145997, 2, 0, 'You would betray your kingdom out of spite?', 12, 0, 100, 1, 0, 0, 0, 0, 'Commander Lorna Crowley - scene'),
(4145997, 3, 0, 'HAH! You''ll have to kill me! DIE!', 12, 0, 100, 5, 0, 0, 0, 0, 'Commander Lorna Crowley - turns hostile'),
(4145997, 4, 0, '%s falls unconscious.', 41, 0, 100, 0, 0, 0, 0, 0, 'Commander Lorna Crowley - death');

-- ---------------------------------------------------------------------------
-- 4. npc_spellclick_spells: the click casts 56685 (CSA Dummy Effect 1) from the player at the trooper,
--    which is what the script's SpellHit waits for. cast_flags 1 = the clicker casts.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 4145910;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(4145910, 56685, 1, 0);

-- The click needs quest 27547 in the log (nelt_world condition, cata_world has none). Until 27547 is
-- imported, ConditionMgr logs "Quest condition specifies non-existing quest (27547), skipped" once per
-- boot and the click is open to everyone.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 18 AND `SourceGroup` = 4145910 AND `SourceEntry` = 56685;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(18, 4145910, 56685, 0, 0, 9, 0, 27547, 0, 0, 0, 0, 0, '', 'Cowering Trooper - spellclick only with Of No Consequence taken');

-- ---------------------------------------------------------------------------
-- 5. Spawns: 22 Cowering Troopers in Pyrewood Village, Lorna at the Greymane Wall camp.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 11545900 AND 11545922 AND `id` IN (4145910, 4145997);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(11545900, 4145910, 751, 4935, 4935, 1, 1, 0, -325.62, 1537.59, 24.2787, 5.61996, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545901, 4145910, 751, 4935, 4935, 1, 1, 0, -390.189, 1504.95, 29.5155, 4.81711, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545902, 4145910, 751, 4935, 4935, 1, 1, 0, -356.668, 1525.22, 25.5324, 1.67552, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545903, 4145910, 751, 4935, 4935, 1, 1, 0, -382.931, 1617.55, 27.0758, 2.61799, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545904, 4145910, 751, 4935, 4935, 1, 1, 0, -345.042, 1578.95, 18.8034, 5.60251, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545905, 4145910, 751, 4935, 4935, 1, 1, 0, -325.694, 1477.89, 30.6195, 2.89725, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545906, 4145910, 751, 4935, 4935, 1, 1, 0, -384.837, 1623.22, 20.7355, 4.69494, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545907, 4145910, 751, 4935, 4935, 1, 1, 0, -416.689, 1609.36, 18.7411, 3.1765, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545908, 4145910, 751, 4935, 4935, 1, 1, 0, -435.043, 1572.92, 20.158, 4.74729, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545909, 4145910, 751, 4935, 4935, 1, 1, 0, -313.931, 1585.75, 20.1042, 5.0091, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545910, 4145910, 751, 4935, 4935, 1, 1, 0, -388.995, 1484.04, 18.6664, 5.72468, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545911, 4145910, 751, 4935, 4935, 1, 1, 0, -416.625, 1501.86, 20.1791, 0.314159, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545912, 4145910, 751, 4935, 4935, 1, 1, 0, -446.464, 1569.29, 18.7411, 3.1765, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545913, 4145910, 751, 4935, 4935, 1, 1, 0, -423.196, 1597.19, 18.7411, 2.19912, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545914, 4145910, 751, 4935, 4935, 1, 1, 0, -348.543, 1460.27, 22.5387, 2.87979, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545915, 4145910, 751, 4935, 4935, 1, 1, 0, -397.073, 1444.34, 25.7672, 0.872665, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545916, 4145910, 751, 4935, 4935, 1, 1, 0, -337.08, 1491.84, 19.5949, 4.85202, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545917, 4145910, 751, 4935, 4935, 1, 1, 0, -408.101, 1577.99, 18.7411, 5.3058, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545918, 4145910, 751, 4935, 4935, 1, 1, 0, -355.021, 1614.67, 18.7411, 5.46288, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545919, 4145910, 751, 4935, 4935, 1, 1, 0, -407.417, 1584.48, 29.88, 3.05433, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545920, 4145910, 751, 4935, 4935, 1, 1, 0, -411.087, 1612.75, 19.9879, 2.68781, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545921, 4145910, 751, 4935, 4935, 1, 1, 0, -346.611, 1586.88, 20.5712, 0.750492, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront'),
(11545922, 4145997, 751, 4935, 4935, 1, 1, 0, -804.205, 1338.96, 33.778, 0.853287, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Silverpine port - battlefront');
