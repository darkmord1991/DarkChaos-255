-- ===========================================================================
-- Map 751 -- Quel'Danil Lodge (The Hinterlands): make 27625 "In Defense of
-- Quel'Danil" and its sibling 27626 "The Highvale Documents" completable.
-- Both are given and taken by Anchorite Traska (4146475) after 27725.
--
-- 27625: the objective pointed at the RAW Cata creature 43541 (a level-34
--   template with no spawns), and the Deathstalker Invaders were never
--   imported -- nelt keeps them in a phase, and 751 was built from cata_world.
--   Now: a 751-band clone 4143541, levelled like the Forsaken Troopers at the
--   lodge (148-149), the 33 nelt spawns, and the objective repointed.
--   The invaders are immune to NPCs: the Highvale Sentries (faction 1802) are
--   hostile to them and would otherwise kill the quest targets themselves.
--   Faction 2213 = Undercity, hostile to Alliance only -- the questgiver is
--   Alliance (Exodar), so this is an Alliance quest, as in Cata.
--   Quest phasing: the invaders are shown until the player turns in 27625,
--   after which the lodge stands saved for them (map 751 bit 2).
--
-- 27626: needs Highvale Report / Records / Notes (61972-61974, all in
--   Item.dbc), but their three chests (Cata 205890-205892) were never
--   imported either. Now: GO band +4,600,000 clones 4805890-4805892 at nelt's
--   positions, quest-only loot. The 1440xx "Highvale ..." objects are the
--   unrelated vanilla quest objects and are left alone.
--
-- Guid block 9027000+ (creature and gameobject), checked empty 2026-11-20.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) Deathstalker Invader, 751 band.
-- ---------------------------------------------------------------------------
-- Template rows are never deleted (codestyle), so they are written with REPLACE.
REPLACE INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,
     `DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,
     `unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,
     `skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,
     `RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
(4143541, 0, 0, 0, 0, 0,
 'Deathstalker Invader', '', '', 0, 148, 149, 2, 2213, 0,
 1, 1.14286, 1, 1, 20, 0, 0,
 0.496059, 2000, 2000, 1, 1, 1,
 512, 2048, 0, 0, 7, 0, 4143541, 0,
 0, 0, 0, 0, 0, 'SmartAI', 0, 1,
 0.692385, 1, 1, 1, 0, 0,
 1, 0, 0, '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 4143541;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`) VALUES
(4143541, 0, 2685, 1, 1, 0);

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 4143541;
INSERT INTO `creature_equip_template` (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`) VALUES
(4143541, 1, 5283, 5283, 0, 0);

-- Same band reference as the Forsaken Troopers and Highvale Sentries here.
DELETE FROM `creature_loot_template` WHERE `Entry` = 4143541;
INSERT INTO `creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(4143541, 0, 752216, 1.2, 0, 1, 0, 1, 1, 'Deathstalker Invader - 751 band reference (148)');

-- Combat abilities of the raw template.
DELETE FROM `smart_scripts` WHERE `entryorguid` = 4143541 AND `source_type` = 0;
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(4143541, 0, 0, 0, 0, 0, 100, 0, 2000, 3000, 12000, 13000, 0, 0, 11, 14873, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Deathstalker Invader - In Combat - Cast Sinister Strike'),
(4143541, 0, 1, 0, 0, 0, 100, 0, 5000, 6000, 16000, 19000, 0, 0, 11, 3583, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Deathstalker Invader - In Combat - Cast Deadly Poison');

-- 27625 counts the 751 clone, not the raw Cata id.
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4143541 WHERE `ID` = 27625 AND `RequiredNpcOrGo1` = 43541;

-- ---------------------------------------------------------------------------
-- B) The 33 invaders at nelt's positions (Cata phase "Quel'Danil Lodge with
--    Invaders"), quest phase bit 2 on map 751.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9027000 AND 9027032 AND `id` = 4143541;
INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9027000, 4143541, 751, 0, 0, 1, 2, 1, 239.679, -2688.74, 117.952, 0.8751, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027001, 4143541, 751, 0, 0, 1, 2, 1, 271.784, -2674.5, 119.474, 6.1812, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027002, 4143541, 751, 0, 0, 1, 2, 1, 348.352, -2742.27, 116.767, 5.4398, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027003, 4143541, 751, 0, 0, 1, 2, 1, 186.642, -2704.16, 115.913, 5.2249, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027004, 4143541, 751, 0, 0, 1, 2, 1, 180.209, -2857.66, 103.088, 5.6934, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027005, 4143541, 751, 0, 0, 1, 2, 1, 223.808, -2780.02, 123.356, 4.0678, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027006, 4143541, 751, 0, 0, 1, 2, 1, 281.645, -2870.33, 109.266, 5.662, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027007, 4143541, 751, 0, 0, 1, 2, 1, 351.472, -2915.59, 116.564, 1.1169, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027008, 4143541, 751, 0, 0, 1, 2, 1, 317.984, -2926.92, 112.489, 5.6824, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027009, 4143541, 751, 0, 0, 1, 2, 1, 293.552, -2921.1, 106.441, 0.5263, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027010, 4143541, 751, 0, 0, 1, 2, 1, 258.831, -2860.56, 112.246, 0.0432, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027011, 4143541, 751, 0, 0, 1, 2, 1, 227.177, -2875.38, 109.577, 6.0146, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027012, 4143541, 751, 0, 0, 1, 2, 1, 179.744, -2775.74, 111.143, 3.9443, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027013, 4143541, 751, 0, 0, 1, 2, 1, 167.455, -2811.52, 110.192, 4.9693, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027014, 4143541, 751, 0, 0, 1, 2, 1, 286.577, -2826.79, 113.5, 3.4346, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027015, 4143541, 751, 0, 0, 1, 2, 1, 341.975, -2880.57, 117.368, 2.1779, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027016, 4143541, 751, 0, 0, 1, 2, 1, 320.377, -2833.53, 118.447, 1.8873, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027017, 4143541, 751, 0, 0, 1, 2, 1, 249.45, -2831.02, 115.295, 2.7395, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027018, 4143541, 751, 0, 0, 1, 2, 1, 220.244, -2745.98, 123.371, 4.3712, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027019, 4143541, 751, 0, 0, 1, 2, 1, 213.776, -2832.17, 110.266, 4.6425, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027020, 4143541, 751, 0, 0, 1, 2, 1, 225.283, -2815.27, 115.697, 6.1835, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027021, 4143541, 751, 0, 0, 1, 2, 1, 143.206, -2880.82, 115.167, 2.2926, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027022, 4143541, 751, 0, 0, 1, 2, 1, 126.495, -2801.79, 108.033, 5.0856, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027023, 4143541, 751, 0, 0, 1, 2, 1, 260.79, -2757.76, 122.556, 4.3041, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027024, 4143541, 751, 0, 0, 1, 2, 1, 243.924, -2922.9, 108.94, 3.305, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027025, 4143541, 751, 0, 0, 1, 2, 1, 214.91, -2910.61, 107.926, 2.5863, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027026, 4143541, 751, 0, 0, 1, 2, 1, 187.034, -2830.76, 108.205, 6.2691, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027027, 4143541, 751, 0, 0, 1, 2, 1, 322.31, -2867.38, 112.456, 0.4917, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027028, 4143541, 751, 0, 0, 1, 2, 1, 199.661, -2767.99, 120.498, 4.992, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027029, 4143541, 751, 0, 0, 1, 2, 1, 124.255, -2852.91, 114.262, 5.8906, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027030, 4143541, 751, 0, 0, 1, 2, 1, 245.377, -2779.53, 123.361, 5.0439, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027031, 4143541, 751, 0, 0, 1, 2, 1, 175.326, -2909.1, 109.902, 2.7733, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)'),
(9027032, 4143541, 751, 0, 0, 1, 2, 1, 201.034, -2885.66, 104.438, 4.2137, 300, 5, 0, 1, 0, 1, 0, 0, '', 0, 'Quel''Danil - Deathstalker Invader (27625)');

-- 43 = every status but rewarded.
DELETE FROM `dc_quest_phase` WHERE `map` = 751 AND `phase_mask` = 2 AND `quest` = 27625;
INSERT INTO `dc_quest_phase` (`map`,`phase_mask`,`quest`,`quest_status_mask`,`comment`) VALUES
(751, 2, 27625, 43, 'Hinterlands: Deathstalker Invaders at Quel''Danil Lodge until 27625 is turned in');

-- ---------------------------------------------------------------------------
-- C) The three Highvale chests for 27626 (nelt 205890-205892, verbatim but
--    the entry; lock 1691 and display 210 are in use here already).
-- ---------------------------------------------------------------------------
REPLACE INTO `gameobject_template` (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data3`,`AIName`,`ScriptName`,`VerifiedBuild`) VALUES
(4805890, 3, 210, 'Highvale Report', '', '', '', 1, 1691, 4805890, 1, '', '', 0),
(4805891, 3, 210, 'Highvale Records', '', '', '', 1, 1691, 4805891, 1, '', '', 0),
(4805892, 3, 210, 'Highvale Notes', '', '', '', 1, 1691, 4805892, 1, '', '', 0);

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (4805890, 4805891, 4805892);
INSERT INTO `gameobject_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(4805890, 61972, 0, 100, 1, 1, 0, 1, 1, 'Highvale Report (27626)'),
(4805891, 61973, 0, 100, 1, 1, 0, 1, 1, 'Highvale Records (27626)'),
(4805892, 61974, 0, 100, 1, 1, 0, 1, 1, 'Highvale Notes (27626)');

DELETE FROM `gameobject` WHERE `guid` BETWEEN 9027000 AND 9027002 AND `id` IN (4805890, 4805891, 4805892);
INSERT INTO `gameobject`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,
     `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9027000, 4805890, 751, 0, 0, 1, 1, 284.63, -2674.4, 119.95, 5.8269, 0, 0, 0.226155, -0.974091, 120, 100, 1, '', 0, 'Quel''Danil - Highvale Report (27626)'),
(9027001, 4805891, 751, 0, 0, 1, 1, 232.99, -2785.61, 124.3, 4.9551, 0, 0, 0.616291, -0.787519, 120, 100, 1, '', 0, 'Quel''Danil - Highvale Records (27626)'),
(9027002, 4805892, 751, 0, 0, 1, 1, 218.68, -2718.04, 121.45, 2.7443, 0, 0, 0.98033, 0.197367, 120, 100, 1, '', 0, 'Quel''Danil - Highvale Notes (27626)');
