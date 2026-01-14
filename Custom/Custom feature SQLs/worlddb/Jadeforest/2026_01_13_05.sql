-- DB update 2026_01_13_04 -> 2026_01_13_05
-- Jadeforest Training Grounds: boss-display training dummies (800028+)
--
-- These are spawned randomly (distinct) by the script when players enter map 745.

-- Preferred approach: THREE different boss-display dummy templates, each with a model pool.
-- The model pool is stored in creature_template_model (Idx 0..3) and uses Probability weighting.
-- The script spawns these 3 entries at fixed pads.

SET @ENTRY_PAD_A := 800028;
SET @ENTRY_PAD_B := 800033;
SET @ENTRY_PAD_C := 800034;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (@ENTRY_PAD_A, @ENTRY_PAD_B, @ENTRY_PAD_C);
DELETE FROM `creature_template` WHERE `entry` IN (@ENTRY_PAD_A, @ENTRY_PAD_B, @ENTRY_PAD_C);

INSERT INTO `creature_template` (
  `entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,`unit_flags`,`flags_extra`,`ScriptName`,`BaseAttackTime`,`RangeAttackTime`
) VALUES
(@ENTRY_PAD_A,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000),
(@ENTRY_PAD_B,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000),
(@ENTRY_PAD_C,'Boss Display Dummy','(Random Boss Pad)',80,80,0,14,0,1,0,0,'jadeforest_boss_display_dummy',2000,2000);

-- Build a random sample of boss/elite display IDs to seed the three pools (4 per dummy, disjoint).
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
