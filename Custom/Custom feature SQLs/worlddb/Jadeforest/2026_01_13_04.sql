-- DB update 2026_01_13_03 -> 2026_01_13_04
-- Jadeforest Training Grounds: boss-training dummy + configurable spawner

-- Creature template entries (all 800028+ per training grounds)
-- 800028 is reserved for boss-display pad dummy (see 2026_01_13_05.sql)
SET @ENTRY_MASTER := 800029;
SET @ENTRY_DUMMY  := 800030;
SET @ENTRY_ADD    := 800031;
SET @ENTRY_TOTEM  := 800032;

DELETE FROM `creature` WHERE `id1` IN (@ENTRY_MASTER, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM);
DELETE FROM `creature_template` WHERE `entry` IN (@ENTRY_MASTER, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM);

-- Training Master (gossip)
INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES (
  @ENTRY_MASTER,'Training Master','Boss Training Grounds',80,80,0,35,1,1,0,0,'jadeforest_training_master',2000,2000
);

-- Boss Training Dummy (invulnerable, scripted mechanics)
INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES (
  @ENTRY_DUMMY,'Boss Training Dummy','(Training)',80,80,0,14,0,1,0,130,'jadeforest_boss_training_dummy',2000,2000
);

-- Training Add (killable runner)
INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES (
  @ENTRY_ADD,'Training Add','(Training)',80,80,0,14,0,1,0,0,'jadeforest_training_add',2000,2000
);

-- Training Totem (visual goal / fail condition)
-- unit_flags: NON_ATTACKABLE (2) + NOT_SELECTABLE (33554432) => 33554434
INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES (
  @ENTRY_TOTEM,'Training Totem','(Training)',1,1,0,35,0,1,33554434,0,'',2000,2000
);

-- Optional spawn: place the Training Master at Jadeforest Training Grounds
-- Map 745 coords are taken from DC Jadeforest teleports.
INSERT INTO `creature` (
  `id1`,`id2`,`id3`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
  `position_x`,`position_y`,`position_z`,`orientation`,
  `spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
  `npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`
) VALUES (
  @ENTRY_MASTER,0,0,745,0,0,1,1,0,
  1252.4359,-2478.3853,143.6,6.201568,
  300,0,0,1,0,0,
  0,0,0,'',12340,0,'Jadeforest Training Grounds: Training Master'
);
