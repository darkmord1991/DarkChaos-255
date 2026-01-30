-- DB update 2026_01_30
-- Jadeforest Training Grounds: training master + dummy/add/totem + boss display pads (800040+)

SET @ENTRY_MASTER := 800029;
SET @ENTRY_PAD_A := 800040;
SET @ENTRY_DUMMY  := 800041;
SET @ENTRY_ADD    := 800042;
SET @ENTRY_TOTEM  := 800043;
SET @ENTRY_PAD_B := 800044;
SET @ENTRY_PAD_C := 800045;

DELETE FROM `creature` WHERE `id1` IN (@ENTRY_MASTER, @ENTRY_PAD_A, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM, @ENTRY_PAD_B, @ENTRY_PAD_C);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (@ENTRY_MASTER, @ENTRY_PAD_A, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM, @ENTRY_PAD_B, @ENTRY_PAD_C);
DELETE FROM `creature_template` WHERE `entry` IN (@ENTRY_MASTER, @ENTRY_PAD_A, @ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM, @ENTRY_PAD_B, @ENTRY_PAD_C);

-- creature_template_model
-- Provide a safe, valid model for each template so it isn't invisible.
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

-- Boss display pads (scripted display dummy)
INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES
(@ENTRY_PAD_A,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000),
(@ENTRY_PAD_B,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000),
(@ENTRY_PAD_C,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000);

-- Pad visuals (3 pools, 4 models each)
CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_dc_boss_display_pool` (
  `CreatureDisplayID` int unsigned NOT NULL,
  PRIMARY KEY (`CreatureDisplayID`)
) ENGINE=MEMORY;

TRUNCATE TABLE `tmp_dc_boss_display_pool`;

INSERT IGNORE INTO `tmp_dc_boss_display_pool` (`CreatureDisplayID`)
SELECT DISTINCT ctm.`CreatureDisplayID`
FROM `creature_template` ct
JOIN `creature_template_model` ctm ON ctm.`CreatureID` = ct.`entry`
WHERE ct.`rank` IN (2, 3)
  AND ct.`entry` < 800000
  AND ctm.`CreatureDisplayID` <> 0
ORDER BY RAND()
LIMIT 12;

-- Pad A: first 4
SET @i := -1;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @ENTRY_PAD_A, (@i := @i + 1) AS `Idx`, t.`CreatureDisplayID`, 1, 1, 0
FROM (
  SELECT `CreatureDisplayID`
  FROM `tmp_dc_boss_display_pool`
  ORDER BY `CreatureDisplayID`
  LIMIT 0, 4
) t;

-- Pad B: next 4
SET @i := -1;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @ENTRY_PAD_B, (@i := @i + 1) AS `Idx`, t.`CreatureDisplayID`, 1, 1, 0
FROM (
  SELECT `CreatureDisplayID`
  FROM `tmp_dc_boss_display_pool`
  ORDER BY `CreatureDisplayID`
  LIMIT 4, 4
) t;

-- Pad C: last 4
SET @i := -1;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @ENTRY_PAD_C, (@i := @i + 1) AS `Idx`, t.`CreatureDisplayID`, 1, 1, 0
FROM (
  SELECT `CreatureDisplayID`
  FROM `tmp_dc_boss_display_pool`
  ORDER BY `CreatureDisplayID`
  LIMIT 8, 4
) t;

-- Flags and health for pads and training dummies
UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` IN (@ENTRY_PAD_A, @ENTRY_PAD_B, @ENTRY_PAD_C));
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` IN (@ENTRY_PAD_A, @ENTRY_PAD_B, @ENTRY_PAD_C));

UPDATE `creature_template` SET `faction` = 7, `unit_flags2` = 2048, `flags_extra` = 262144 WHERE (`entry` IN (@ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM));
UPDATE `creature_template` SET `HealthModifier` = 1000 WHERE (`entry` IN (@ENTRY_DUMMY, @ENTRY_ADD, @ENTRY_TOTEM));
