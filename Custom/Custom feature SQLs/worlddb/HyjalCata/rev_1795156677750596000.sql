-- ===========================================================================
-- HyjalCata r51 -- Darkshore (map 750): ports from BFA-HavenCore #726
-- (The Last Wave of Survivors, flying NPC waypoints), 2026-11-18.
--
-- Already correct on our side, so NOT ported:
--   #730 Disturbing Connections: Hellscream's Missive drops from Jor'kil at
--        100 % with QuestRequired 0, and no NPC hands out 13591 directly.
--   #731 + #726 quest map markers: our quest_poi for 13573 and 13518 already
--        has the same points (map 750, WorldMapArea 1259).
--   #726 Lor'danel Sentinels set idle: ours are already static, or walk the
--        patrol paths an earlier import gave them. Creature 43440 is not on
--        map 750.
--
-- Adapted rather than copied:
--   * Their speed action (208, value 21) is an absolute speed on TC; our
--     SET_MOVEMENT_SPEED takes a RATE, so 21 would mean 21x. Not ported.
--   * Shaldyn: HavenCore summons a flyer behind a SmartAI phase gate. Our
--     OnReset clears the phase back to 0, so that gate would never open. A
--     placed flyer answers instead, the same way the other three survivors
--     are answered. Map 750 has no phasing, so the rescuers are always there.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) Lor'danel Sentinel hippogryph riders 3733115 (11 spawns). nelt rides them
--    on hippogryph 22474 with the fly anim tier and InhabitType 4; none of
--    that was imported, so on map 750 they are night elves standing in the
--    air, three of them walking patrol paths 10-35 yd up. bytes1 50331648 is
--    what stock 3.3.5 mounted flyers use. Flight 1 = DisableGravity. The
--    three patrolling spawns have their own creature_addon row (path), which
--    overrides the template addon, so they get the mount there too.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_addon` WHERE `entry` = 3733115;
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3733115, 0, 22474, 50331648, 1, 0, 0, NULL);

DELETE FROM `creature_template_movement` WHERE `CreatureId` = 3733115;
INSERT INTO `creature_template_movement` (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`) VALUES
(3733115, 1, 0, 1, 0, 0, 0, 0);

UPDATE `creature_addon` SET `mount` = 22474, `bytes1` = 50331648 WHERE `guid` IN (15861115, 15861118, 15861119);

-- ---------------------------------------------------------------------------
-- B) 13518 "The Last Wave of Survivors" -- the rescue. Talking to a survivor
--    still gives the credit (r49); now a sentinel also comes to fetch them,
--    speaks, and goes back to her post after a minute. Rescuer positions are
--    HavenCore's (nelt has none). Lines are the Blizzard broadcast texts.
--      survivor            sentinel            data   point
--      Volcor   3733094    9025011 (sabre)     1 10   10
--      Gershala 3732911    9025014             1 11   11
--      Cerellean 3733093   9025013             1 12   12
--      Shaldyn  3733095    9025015 (flyer)     1 13   13
--    9025012 stands with the Volcor rider and has no script.
-- ---------------------------------------------------------------------------
-- Own guid block 9025000+: 9025011-9025015 checked empty on 2026-11-20.
DELETE FROM `creature` WHERE `guid` BETWEEN 9025011 AND 9025015 AND `id` IN (3732969, 3733115);
INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9025011, 3732969, 750, 0, 0, 1, 1, 0, 7422.75, 39.3669, 2.39565, 1.24879, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r51 - 13518 rescuer for Volcor'),
(9025012, 3732969, 750, 0, 0, 1, 1, 0, 7418.63, 34.9982, 2.28486, 1.24879, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r51 - 13518 rescuer, with 9025011'),
(9025013, 3732969, 750, 0, 0, 1, 1, 0, 7390.69, 108.088, 7.5072, 3.20836, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r51 - 13518 rescuer for Cerellean'),
(9025014, 3732969, 750, 0, 0, 1, 1, 0, 7430.35, 150.339, 0.779603, 1.45299, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r51 - 13518 rescuer for Gershala'),
(9025015, 3733115, 750, 0, 0, 1, 1, 0, 7273.81, 256.58, 10.13, 6.01, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r51 - 13518 rescuer for Shaldyn');

DELETE FROM `creature_addon` WHERE `guid` = 9025011;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(9025011, 0, 9991, 0, 1, 0, 0, NULL);

DELETE FROM `creature_text` WHERE `CreatureID` IN (3732969, 3733115);
INSERT INTO `creature_text` (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`) VALUES
(3732969, 0, 0, 'Cerellean! You made it!', 12, 0, 100, 0, 0, 0, 33248, 0, 'Lor''danel Sentinel - 13518 rescue Cerellean'),
(3732969, 1, 0, 'Gershala... Dentaria will be so happy to see you alive.', 12, 0, 100, 0, 0, 0, 33258, 0, 'Lor''danel Sentinel - 13518 rescue Gershala'),
(3732969, 2, 0, 'I''ll take him back to the priestess. Thank you for your kindness.', 12, 0, 100, 0, 0, 0, 33259, 0, 'Lor''danel Sentinel - 13518 rescue Gershala'),
(3732969, 5, 0, 'Volcor... I''m so glad to see that you made it. But where is Grimclaw?', 12, 0, 100, 0, 0, 0, 33262, 0, 'Lor''danel Sentinel - 13518 rescue Volcor'),
(3733115, 3, 0, 'I will see to it that Shaldyn is returned safely. Thank you, hero.', 12, 0, 100, 0, 0, 0, 33260, 0, 'Lor''danel Sentinel - 13518 rescue Shaldyn'),
(3733115, 4, 0, 'Shaldyn!', 12, 0, 100, 0, 0, 0, 33261, 0, 'Lor''danel Sentinel - 13518 rescue Shaldyn');

-- Survivors: keep r49's credit row, link it to "call my rescuer".
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (3732911, 3733093, 3733094, 3733095) AND `source_type` = 0 AND `id` IN (0, 1);
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(3732911, 0, 0, 1, 64, 0, 100, 0, 0, 0, 0, 0, 0, 0, 33, 3732911, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Gershala Nightwhisper - On Gossip Hello - Quest Credit (13518)'),
(3732911, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 45, 1, 11, 0, 0, 0, 0, 10, 9025014, 3732969, 0, 0, 0, 0, 0, 0, 'Gershala Nightwhisper - Linked - Set Data 1 11 on rescuer 9025014'),
(3733093, 0, 0, 1, 64, 0, 100, 0, 0, 0, 0, 0, 0, 0, 33, 3733093, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Cerellean Whiteclaw - On Gossip Hello - Quest Credit (13518)'),
(3733093, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 45, 1, 12, 0, 0, 0, 0, 10, 9025013, 3732969, 0, 0, 0, 0, 0, 0, 'Cerellean Whiteclaw - Linked - Set Data 1 12 on rescuer 9025013'),
(3733094, 0, 0, 1, 64, 0, 100, 0, 0, 0, 0, 0, 0, 0, 33, 3733094, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Volcor - On Gossip Hello - Quest Credit (13518)'),
(3733094, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 45, 1, 10, 0, 0, 0, 0, 10, 9025011, 3732969, 0, 0, 0, 0, 0, 0, 'Volcor - Linked - Set Data 1 10 on rescuer 9025011'),
(3733095, 0, 0, 1, 64, 0, 100, 0, 0, 0, 0, 0, 0, 0, 33, 3733095, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Shaldyn - On Gossip Hello - Quest Credit (13518)'),
(3733095, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 45, 1, 13, 0, 0, 0, 0, 10, 9025015, 3733115, 0, 0, 0, 0, 0, 0, 'Shaldyn - Linked - Set Data 1 13 on rescuer 9025015');

-- Rescuers. Entry-level, but only the guid each survivor names ever receives
-- the data. 60 s cooldown = one trip at a time. The arrival lists end in an
-- evade, which walks (or flies) the rescuer back to her spawn point.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND ((`entryorguid` = 3732969 AND `id` BETWEEN 30 AND 35) OR (`entryorguid` = 3733115 AND `id` IN (10, 11)));
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (373296910, 373296911, 373296920, 373296921, 373296930, 373296931, 373311500, 373311501);
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(3732969, 0, 30, 0, 38, 0, 100, 0, 1, 10, 60000, 60000, 0, 0, 80, 373296910, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Data 1 10 - Run To Volcor (13518)'),
(3732969, 0, 31, 0, 34, 0, 100, 0, 8, 10, 0, 0, 0, 0, 80, 373296911, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Point 10 Reached - Greet Volcor (13518)'),
(3732969, 0, 32, 0, 38, 0, 100, 0, 1, 11, 60000, 60000, 0, 0, 80, 373296920, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Data 1 11 - Run To Gershala (13518)'),
(3732969, 0, 33, 0, 34, 0, 100, 0, 8, 11, 0, 0, 0, 0, 80, 373296921, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Point 11 Reached - Greet Gershala (13518)'),
(3732969, 0, 34, 0, 38, 0, 100, 0, 1, 12, 60000, 60000, 0, 0, 80, 373296930, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Data 1 12 - Run To Cerellean (13518)'),
(3732969, 0, 35, 0, 34, 0, 100, 0, 8, 12, 0, 0, 0, 0, 80, 373296931, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Point 12 Reached - Greet Cerellean (13518)'),
(3733115, 0, 10, 0, 38, 0, 100, 0, 1, 13, 60000, 60000, 0, 0, 80, 373311500, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Data 1 13 - Fly To Shaldyn (13518)'),
(3733115, 0, 11, 0, 34, 0, 100, 0, 8, 13, 0, 0, 0, 0, 80, 373311501, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - On Point 13 Reached - Greet Shaldyn (13518)'),
(373296910, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, 0, 59, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run On'),
(373296910, 9, 1, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 69, 10, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 7439.04, 102.05, 0.56, 1.29, 'Lor''danel Sentinel - Actionlist - Move To Point 10 (Volcor)'),
(373296911, 9, 0, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 1, 5, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 5'),
(373296911, 9, 1, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 59, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run Off'),
(373296911, 9, 2, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Evade (Back To Post)'),
(373296920, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, 0, 59, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run On'),
(373296920, 9, 1, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 69, 11, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 7453.65, 162.69, 2.22, 0.59, 'Lor''danel Sentinel - Actionlist - Move To Point 11 (Gershala)'),
(373296921, 9, 0, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 1'),
(373296921, 9, 1, 0, 0, 0, 100, 0, 5000, 5000, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 2'),
(373296921, 9, 2, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 59, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run Off'),
(373296921, 9, 3, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Evade (Back To Post)'),
(373296930, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, 0, 59, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run On'),
(373296930, 9, 1, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 69, 12, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 7370.18, 132.09, 12.08, 2.55, 'Lor''danel Sentinel - Actionlist - Move To Point 12 (Cerellean)'),
(373296931, 9, 0, 0, 0, 0, 100, 0, 200, 200, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 0'),
(373296931, 9, 1, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 59, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Set Run Off'),
(373296931, 9, 2, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Evade (Back To Post)'),
(373311500, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, 0, 69, 13, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 7291.64, 244.72, 2.38, 6.01, 'Lor''danel Sentinel - Actionlist - Fly To Point 13 (Shaldyn)'),
(373311501, 9, 0, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 4'),
(373311501, 9, 1, 0, 0, 0, 100, 0, 5000, 5000, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Say Line 3'),
(373311501, 9, 2, 0, 0, 0, 100, 0, 30000, 30000, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lor''danel Sentinel - Actionlist - Evade (Back To Post)');
