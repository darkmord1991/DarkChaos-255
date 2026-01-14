-- DB update 2026_01_13_03 -> 2026_01_13_04
-- Jadeforest Training Grounds: boss-training dummy + configurable spawner

-- Creature template entries (all 800028+ per training grounds)
-- 800028 is reserved for boss-display pad dummy (see 2026_01_13_05.sql)
SET @ENTRY_MASTER := 800029;
SET @ENTRY_DUMMY  := 800030;
SET @ENTRY_ADD    := 800031;
SET @ENTRY_TOTEM  := 800032;

DELETE FROM `creature` WHERE `id1` IN (@ENTRY_MASTER, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (@ENTRY_MASTER, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM);
DELETE FROM `creature_template` WHERE `entry` IN (@ENTRY_MASTER, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM);

-- creature_template_model
-- The world schema uses creature_template_model (CreatureID, Idx) with a CHECK constraint (Idx <= 3).
-- Provide a safe, valid model for each template so it isn't invisible.
-- Use a known-visible base-world display IDs to avoid client-side invisibility edge cases.
-- - 10045 is used by creature entry 1 in base world
-- - 16074 is used by the stock Training Dummy (entry 31144) in base world
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(@ENTRY_MASTER, 0, 10045, 1, 1, 0),
(@ENTRY_DUMMY,  0, 16074, 1, 1, 0),
(@ENTRY_ADD,    0, 10045, 1, 1, 0),
(@ENTRY_TOTEM,  0, 10045, 1, 1, 0);

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
  -- flags_extra was previously set to 130; on most cores 128 means "TRIGGER" which makes the creature invisible/non-interactive.
  -- Keep this as a normal creature; the C++ script handles invulnerability and behavior.
  @ENTRY_DUMMY,'Boss Training Dummy','(Training)',80,80,0,14,0,1,0,0,'jadeforest_boss_training_dummy',2000,2000
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

-- Set factions and flags for the training dummy pads
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800028);
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800033);
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800034);
-- Increase health of the training dummies
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800028);
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800033);
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800034);

-- Set factions and flags for the training dummy pads
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800030);
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800031);
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` = 800032);
-- Increase health of the training dummies
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800030);
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800031);
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` = 800032);