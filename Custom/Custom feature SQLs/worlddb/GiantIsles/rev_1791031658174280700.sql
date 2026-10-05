-- Isles of Giants: the Temple of Atal'Hakkar (Sunken Temple, map 109) copied 1:1 under the island temple,
-- level 80. World position = map 109 position + (6767, 985, -100); the WMO copy ships in the client patch
-- (World\wmo\DarkChaos\IslesofGiants\IoG_SunkenTempleDepths.wmo, area 5008) with the 1405 vmaps/mmaps.
-- Open-world event script: src/server/scripts/DC/GiantIsles/dc_giant_isles_sunken_temple.cpp.
--
-- creature_template  400500-400505, 400510-400513, 400520-400523 (re-pointed custom quest/achievement
--                    objectives) + 400530-400561 (new clones and summons)
-- gameobject_template 700018-700034, gossip_menu 400500, pool_template 400500, action list 70002800
-- creature guid      9003001+ (copied map 109 spawns), path ids = guid * 10
-- gameobject guid    9005401-9005416 (copied map 109 objects), 9005420-9005422 (portals, ritual altar)
-- Deleting from creature_template/gameobject_template is intended (custom ids only).

-- ---- mapping tables (this session only) ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_npc`;
CREATE TEMPORARY TABLE `tmp_iog_npc` (`src` INT UNSIGNED NOT NULL PRIMARY KEY, `dst` INT UNSIGNED NOT NULL, `clone` TINYINT UNSIGNED NOT NULL, `name` VARCHAR(100) NULL, `subname` VARCHAR(100) NULL,
    `minlevel` TINYINT UNSIGNED NOT NULL, `maxlevel` TINYINT UNSIGNED NOT NULL, `rank` TINYINT UNSIGNED NOT NULL, `hp` FLOAT NOT NULL, `mp` FLOAT NOT NULL, `dmg` FLOAT NOT NULL,
    `lootid` INT UNSIGNED NOT NULL, `skinloot` INT UNSIGNED NOT NULL, `pickpocketloot` INT UNSIGNED NOT NULL, `mingold` INT UNSIGNED NOT NULL, `maxgold` INT UNSIGNED NOT NULL,
    `ai` VARCHAR(64) NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_npc`;
INSERT INTO `tmp_iog_npc` (`src`, `dst`, `clone`, `name`, `subname`, `minlevel`, `maxlevel`, `rank`, `hp`, `mp`, `dmg`, `lootid`, `skinloot`, `pickpocketloot`, `mingold`, `maxgold`, `ai`) VALUES
(5256, 400500, 1, 'Awakened Atal''ai Warrior', NULL, 79, 80, 1, 4, 1, 7.5, 400500, 0, 27533, 1600, 11000, 'SmartAI'),
(5259, 400501, 1, 'Awakened Atal''ai Witch Doctor', NULL, 79, 80, 1, 4, 5, 7.5, 400501, 0, 27533, 1600, 11000, 'SmartAI'),
(5273, 400502, 1, 'Risen Atal''ai Priest', NULL, 80, 80, 1, 4, 5, 7.5, 400502, 0, 27533, 1600, 11000, 'SmartAI'),
(5267, 400503, 1, 'Atal''ai Boneguard', NULL, 79, 80, 1, 4, 1, 7.5, 400503, 0, 27533, 1600, 11000, 'SmartAI'),
(5270, 400504, 1, 'Atal''ai Soulflayer', NULL, 80, 80, 1, 4, 1, 7.5, 400504, 0, 27533, 1600, 11000, 'SmartAI'),
(5263, 400505, 1, 'Hakkar''s Devotee', NULL, 79, 79, 0, 1, 1, 1, 400505, 0, 27533, 500, 3500, 'SmartAI'),
(5713, 400510, 1, 'Zul''kar the Flayer', 'Bloodseeker', 81, 81, 1, 10, 1, 7.5, 400510, 0, 27533, 4000, 8000, 'SmartAI'),
(5715, 400511, 1, 'Seer Mazra', 'Bloodseeker', 81, 81, 1, 10, 5, 7.5, 400511, 0, 27533, 4000, 8000, 'SmartAI'),
(5712, 400512, 1, 'Bone Weaver Zolo', 'Bloodseeker', 81, 81, 1, 10, 5, 7.5, 400512, 0, 27533, 4000, 8000, 'SmartAI'),
(5717, 400513, 1, 'Soul Raker Mijan', 'Bloodseeker', 81, 81, 1, 11, 5, 7.5, 400513, 0, 27533, 4000, 8000, 'SmartAI'),
(8580, 400520, 1, 'Atal''alarion the Eternal', 'Guardian of the Idol', 82, 82, 1, 20, 1, 7.5, 400520, 0, 0, 5000, 8500, 'SmartAI'),
(5710, 400521, 1, 'Jammal''an the Eternal', 'Eternal Prophet', 82, 82, 1, 22, 5, 7.5, 400521, 0, 0, 5000, 8500, 'SmartAI'),
(8443, 400522, 1, 'Reawakened Avatar of Hakkar', 'Blood God', 82, 82, 1, 25, 1, 7.5, 400522, 0, 0, 5000, 8500, 'SmartAI'),
(5709, 400523, 1, 'Ancient Shade of Eranikus', 'Nightmare Wyrm', 82, 82, 1, 25, 1, 7.5, 400523, 70212, 0, 5000, 8500, 'SmartAI'),
(5714, 400530, 1, NULL, NULL, 81, 81, 1, 10, 1, 7.5, 400530, 0, 27533, 4000, 8000, 'SmartAI'),
(5716, 400531, 1, NULL, NULL, 81, 81, 1, 12, 1, 7.5, 400531, 0, 27533, 4000, 8000, 'SmartAI'),
(5226, 400532, 1, NULL, NULL, 79, 80, 1, 4, 1, 7.5, 26672, 70212, 0, 0, 0, 'SmartAI'),
(5228, 400533, 1, NULL, NULL, 79, 80, 1, 4, 1, 7.5, 28583, 0, 0, 0, 0, 'SmartAI'),
(5269, 400534, 1, NULL, NULL, 79, 79, 0, 1, 5, 1, 28368, 0, 27533, 500, 3500, 'SmartAI'),
(5271, 400535, 1, NULL, NULL, 80, 80, 1, 4, 5, 7.5, 28368, 0, 27533, 1600, 11000, 'SmartAI'),
(5277, 400536, 1, NULL, NULL, 80, 80, 1, 4, 1, 7.5, 26672, 70212, 0, 1600, 11000, 'SmartAI'),
(5280, 400537, 1, NULL, NULL, 80, 80, 1, 4, 5, 7.5, 26672, 70212, 0, 1600, 11000, 'SmartAI'),
(5283, 400538, 1, NULL, NULL, 79, 80, 1, 4, 1, 7.5, 26672, 70212, 0, 1600, 11000, 'SmartAI'),
(5291, 400539, 1, NULL, NULL, 79, 80, 1, 4, 5, 7.5, 26672, 70212, 0, 0, 0, 'SmartAI'),
(5708, 400540, 1, NULL, NULL, 81, 81, 2, 8, 1, 7.5, 400540, 70212, 0, 0, 0, 'SmartAI'),
(5711, 400541, 1, NULL, NULL, 81, 81, 1, 10, 5, 7.5, 400541, 0, 27533, 4000, 8000, 'SmartAI'),
(5719, 400542, 1, NULL, NULL, 81, 81, 1, 10, 1, 7.5, 400542, 70212, 0, 4000, 8000, 'SmartAI'),
(5720, 400543, 1, NULL, NULL, 81, 81, 1, 10, 1, 7.5, 400543, 70212, 0, 4000, 8000, 'SmartAI'),
(5721, 400544, 1, NULL, NULL, 81, 81, 1, 10, 1, 7.5, 400544, 70212, 0, 4000, 8000, 'SmartAI'),
(5722, 400545, 1, NULL, NULL, 81, 81, 1, 10, 1, 7.5, 400545, 70212, 0, 4000, 8000, 'SmartAI'),
(8311, 400546, 1, NULL, NULL, 79, 79, 0, 0.5, 1, 1, 26672, 0, 0, 0, 0, ''),
(8318, 400547, 1, NULL, NULL, 79, 79, 0, 1, 1, 1, 26553, 0, 0, 500, 3500, ''),
(8319, 400548, 1, NULL, NULL, 79, 79, 0, 1, 1, 1, 26672, 70212, 0, 500, 3500, 'SmartAI'),
(8384, 400549, 1, NULL, NULL, 79, 80, 1, 4, 1, 7.5, 28583, 0, 0, 1600, 11000, 'SmartAI'),
(8440, 400550, 1, NULL, NULL, 80, 80, 1, 3, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8438, 400551, 1, NULL, NULL, 80, 80, 1, 4, 5, 7.5, 400551, 0, 0, 0, 0, 'SmartAI'),
(8437, 400552, 1, NULL, NULL, 79, 79, 0, 1, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8497, 400553, 1, NULL, NULL, 80, 80, 1, 4, 1, 7.5, 26672, 0, 0, 1600, 11000, 'SmartAI'),
(8317, 400554, 1, NULL, NULL, 80, 80, 1, 3, 1, 7.5, 0, 0, 0, 0, 0, 'SmartAI'),
(8324, 400555, 1, NULL, NULL, 79, 79, 0, 1, 1, 1, 0, 0, 0, 0, 0, ''),
(8257, 400556, 1, NULL, NULL, 79, 79, 0, 0.5, 1, 1, 0, 0, 0, 0, 0, ''),
(8510, 400557, 1, NULL, NULL, 80, 80, 0, 0.1, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8179, 400558, 1, NULL, NULL, 80, 80, 0, 0.5, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8656, 400559, 1, NULL, NULL, 80, 80, 0, 2, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8657, 400560, 1, NULL, NULL, 80, 80, 0, 1.5, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(8658, 400561, 1, NULL, NULL, 80, 80, 0, 1, 1, 1, 0, 0, 0, 0, 0, 'SmartAI'),
(15593, 15593, 0, NULL, NULL, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, '');
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_go`;
CREATE TEMPORARY TABLE `tmp_iog_go` (`src` INT UNSIGNED NOT NULL PRIMARY KEY, `dst` INT UNSIGNED NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_go`;
INSERT INTO `tmp_iog_go` (`src`, `dst`) VALUES
(148418, 700018),
(148419, 700019),
(148420, 700020),
(148421, 700021),
(148422, 148422),
(148512, 148512),
(148830, 700022),
(148831, 700023),
(148832, 700024),
(148833, 700025),
(148834, 700026),
(148835, 700027),
(148836, 700028),
(149431, 149431),
(149432, 700029),
(149433, 700030);
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_guid`;
CREATE TEMPORARY TABLE `tmp_iog_guid` (`old` INT UNSIGNED NOT NULL PRIMARY KEY, `new` INT UNSIGNED NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_guid`;
INSERT INTO `tmp_iog_guid` (`old`, `new`)
SELECT
    `c`.`guid`, 9003000 + ROW_NUMBER() OVER (ORDER BY `c`.`guid`)
FROM `creature` AS `c`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `c`.`id`
WHERE `c`.`map` = 109;
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_goguid`;
CREATE TEMPORARY TABLE `tmp_iog_goguid` (`old` INT UNSIGNED NOT NULL PRIMARY KEY, `new` INT UNSIGNED NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_goguid`;
INSERT INTO `tmp_iog_goguid` (`old`, `new`)
SELECT
    `g`.`guid`, 9005400 + ROW_NUMBER() OVER (ORDER BY `g`.`guid`)
FROM `gameobject` AS `g`
JOIN `tmp_iog_go` AS `m` ON `m`.`src` = `g`.`id`
WHERE `g`.`map` = 109;

-- ---- creature templates: the source template with level-80 numbers ------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    `m`.`dst`, 0, 0, 0, 0, 0,
    COALESCE(`m`.`name`, `t`.`name`), IF(`m`.`name` IS NULL, `t`.`subname`, `m`.`subname`), `t`.`IconName`, `t`.`gossip_menu_id`, `m`.`minlevel`, `m`.`maxlevel`,
    2, `t`.`faction`, `t`.`npcflag`, `t`.`speed_walk`, `t`.`speed_run`, `t`.`speed_swim`,
    `t`.`speed_flight`, `t`.`detection_range`, `m`.`rank`, `t`.`dmgschool`, `m`.`dmg`, `t`.`BaseAttackTime`,
    `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, `t`.`unit_class`, `t`.`unit_flags`, `t`.`unit_flags2`,
    `t`.`dynamicflags`, `t`.`family`, `t`.`type`, `t`.`type_flags`, `m`.`lootid`, `m`.`pickpocketloot`,
    `m`.`skinloot`, `t`.`PetSpellDataId`, `t`.`VehicleId`, `m`.`mingold`, `m`.`maxgold`, `m`.`ai`,
    `t`.`MovementType`, `t`.`HoverHeight`, `m`.`hp`, `m`.`mp`, `t`.`ArmorModifier`, `t`.`ExperienceModifier`,
    `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`, `t`.`flags_extra`, '',
    12340
FROM `creature_template` AS `t`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `t`.`entry`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`Idx`, `x`.`CreatureDisplayID`, `x`.`DisplayScale`, `x`.`Probability`, `x`.`VerifiedBuild`
FROM `creature_template_model` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`ID`, `x`.`ItemID1`, `x`.`ItemID2`, `x`.`ItemID3`, `x`.`VerifiedBuild`
FROM `creature_equip_template` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_template_addon` WHERE `entry` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT
    `m`.`dst`, `x`.`path_id`, `x`.`mount`, `x`.`bytes1`, `x`.`bytes2`, `x`.`emote`, `x`.`visibilityDistanceType`, `x`.`auras`
FROM `creature_template_addon` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`entry`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT
    `m`.`dst`, `x`.`Ground`, `x`.`Swim`, `x`.`Flight`, `x`.`Rooted`, `x`.`Chase`, `x`.`Random`, `x`.`InteractionPauseTimer`
FROM `creature_template_movement` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureId`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400557, 400558);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`) VALUES
(400557, 1, 0, 0, 1, 0, 0, 0),
(400558, 1, 0, 0, 1, 0, 0, 0);
DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`School`, `x`.`Resistance`, `x`.`VerifiedBuild`
FROM `creature_template_resistance` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`
WHERE `m`.`clone` = 1;
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`Index`, `x`.`Spell`, `x`.`VerifiedBuild`
FROM `creature_template_spell` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`
WHERE `m`.`clone` = 1;
-- map-wide yells (TextRange 3) would cover the whole island: area range keeps them in the temple
DELETE FROM `creature_text` WHERE `CreatureID` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT
    `m`.`dst`, `x`.`GroupID`, `x`.`ID`, `x`.`Text`, `x`.`Type`, `x`.`Language`, `x`.`Probability`, `x`.`Emote`, `x`.`Duration`, `x`.`Sound`, `x`.`BroadcastTextId`, IF(`x`.`TextRange` = 3, 1, `x`.`TextRange`), `x`.`comment`
FROM `creature_text` AS `x`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`
WHERE `m`.`clone` = 1;

-- ---- SmartAI (instance data replaced by the map script; level-80 spells; summons as SmartAI summons) --------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` IN (700018, 700019, 700020, 700021, 700028, 700031, 700032, 700033);
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` = 70002800;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400500, 0, 0, 0, 0, 0, 100, 0, 7100, 15800, 12100, 17800, 0, 0, 11, 13446, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Warrior - In Combat - Cast ''Strike'''),
(400500, 0, 1, 0, 0, 0, 100, 0, 7300, 16000, 19300, 20100, 0, 0, 11, 48880, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Warrior - In Combat - Cast ''Rend'''),
(400501, 0, 0, 0, 0, 0, 100, 0, 0, 1000, 3500, 5000, 0, 0, 11, 48698, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - In Combat - Cast ''Lightning Bolt'''),
(400501, 0, 1, 0, 0, 0, 100, 0, 4000, 9000, 10000, 18000, 0, 0, 11, 43435, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - In Combat - Cast ''Chain Lightning'''),
(400501, 0, 2, 0, 0, 0, 100, 0, 10000, 13000, 19000, 28000, 0, 0, 11, 11641, 0, 0, 0, 0, 0, 6, 20, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - In Combat - Cast ''Hex'''),
(400501, 0, 3, 0, 14, 0, 100, 0, 15000, 30, 10000, 15000, 0, 0, 11, 60012, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - Friendly Missing Health - Cast ''Healing Wave'''),
(400501, 0, 4, 0, 2, 0, 100, 1, 0, 15, 0, 0, 0, 0, 25, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - Between 0-15% Health - Flee For Assist'),
(400501, 0, 5, 0, 1, 0, 100, 0, 1000, 3000, 5000, 10000, 0, 0, 11, 32992, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Awakened Atal''ai Witch Doctor - Out of Combat - Cast ''Ice Cast Visual'' (phase 2 spawns)'),
(400502, 0, 0, 0, 14, 0, 100, 0, 12000, 40, 7500, 14100, 0, 0, 11, 57777, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Risen Atal''ai Priest - Friendly Missing Health - Cast ''Renew'''),
(400502, 0, 1, 0, 14, 0, 100, 0, 15000, 40, 4000, 6000, 0, 0, 11, 31739, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Risen Atal''ai Priest - Friendly Missing Health - Cast ''Heal'''),
(400502, 0, 2, 0, 0, 0, 100, 0, 0, 3000, 4000, 6000, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Risen Atal''ai Priest - In Combat - Cast ''Shadow Bolt'''),
(400502, 0, 3, 0, 0, 0, 100, 0, 5000, 15000, 25000, 35000, 0, 0, 11, 20697, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Risen Atal''ai Priest - In Combat - Cast ''Power Word: Shield'''),
(400502, 0, 4, 0, 0, 0, 100, 0, 5000, 15000, 25000, 45000, 0, 0, 12, 400555, 4, 15000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Risen Atal''ai Priest - In Combat - Summon ''Atal''ai Skeleton'''),
(400503, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 8876, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Boneguard - On Reset - Cast ''Thrash'''),
(400503, 0, 1, 2, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 8269, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Boneguard - Between 0-30% Health - Cast ''Frenzy'''),
(400503, 0, 2, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Boneguard - Between 0-30% Health - Say Line 0'),
(400504, 0, 0, 0, 34, 0, 100, 1, 8, 1, 0, 0, 0, 0, 11, 12134, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Soulflayer - Movement Inform - Cast ''Atal''ai Corpse Eat'''),
(400505, 0, 0, 0, 0, 0, 100, 0, 0, 6000, 7000, 11000, 0, 0, 11, 16186, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Hakkar''s Devotee - In Combat - Cast ''Fevered Plague'''),
(400510, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 6000, 9000, 0, 0, 11, 15580, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zul''kar the Flayer - In Combat - Cast ''Strike'''),
(400511, 0, 0, 1, 0, 0, 100, 1, 3000, 3000, 0, 0, 0, 0, 12, 400559, 4, 10000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Summon ''Hukku''s Voidwalker'''),
(400511, 0, 1, 2, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 12, 400560, 4, 10000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Summon ''Hukku''s Succubus'''),
(400511, 0, 2, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 12, 400561, 4, 10000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Summon ''Hukku''s Imp'''),
(400511, 0, 3, 0, 0, 0, 100, 0, 0, 0, 3500, 4500, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Cast ''Shadow Bolt'''),
(400511, 0, 4, 0, 0, 0, 100, 0, 10000, 12000, 13500, 19000, 0, 0, 11, 49205, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Cast ''Shadow Bolt Volley'''),
(400511, 0, 5, 0, 0, 0, 100, 0, 17000, 20000, 20000, 29000, 0, 0, 11, 12279, 0, 0, 0, 0, 0, 5, 20, 0, 0, 0, 0, 0, 0, 0, 'Seer Mazra - In Combat - Cast ''Curse of Blood'''),
(400511, 0, 6, 7, 25, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 19, 400559, 100, 0, 0, 0, 0, 0, 0, 'Seer Mazra - On Reset - Despawn ''Hukku''s Voidwalker'''),
(400511, 0, 7, 8, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 19, 400560, 100, 0, 0, 0, 0, 0, 0, 'Seer Mazra - On Reset - Despawn ''Hukku''s Succubus'''),
(400511, 0, 8, 0, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 19, 400561, 100, 0, 0, 0, 0, 0, 0, 'Seer Mazra - On Reset - Despawn ''Hukku''s Imp'''),
(400512, 0, 0, 0, 0, 0, 100, 0, 6500, 6500, 9500, 12400, 0, 0, 11, 43435, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Bone Weaver Zolo - In Combat - Cast ''Chain Lightning'''),
(400512, 0, 1, 0, 0, 0, 100, 0, 10000, 12000, 25000, 35000, 0, 0, 12, 400557, 3, 60000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Bone Weaver Zolo - In Combat - Summon ''Atal''ai Totem'''),
(400513, 0, 0, 0, 0, 0, 100, 0, 2000, 5000, 40000, 40000, 0, 0, 11, 43420, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Soul Raker Mijan - In Combat - Cast ''Thorns'''),
(400513, 0, 1, 0, 14, 0, 100, 0, 12000, 40, 19500, 28100, 0, 0, 11, 57777, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Soul Raker Mijan - Friendly Missing Health - Cast ''Renew'''),
(400513, 0, 2, 0, 0, 0, 100, 0, 9500, 18000, 33400, 45600, 0, 0, 12, 400558, 3, 30000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Soul Raker Mijan - In Combat - Summon ''Greater Healing Ward'''),
(400513, 0, 3, 0, 2, 0, 100, 0, 0, 50, 9000, 12000, 0, 0, 11, 55597, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Soul Raker Mijan - Between 0-50% Health - Cast ''Healing Wave'''),
(400520, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''alarion the Eternal - On Aggro - Say Line 1'),
(400520, 0, 1, 0, 0, 0, 100, 0, 3000, 8000, 11000, 14000, 0, 0, 11, 12887, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''alarion the Eternal - In Combat - Cast ''Sweeping Slam'''),
(400520, 0, 2, 0, 0, 0, 100, 0, 10000, 12000, 15000, 15000, 0, 0, 11, 6524, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''alarion the Eternal - In Combat - Cast ''Ground Tremor'''),
(400520, 0, 3, 0, 6, 0, 100, 512, 0, 0, 0, 0, 0, 0, 104, 0, 0, 0, 0, 0, 0, 20, 148838, 100, 0, 0, 0, 0, 0, 0, 'Atal''alarion the Eternal - On Death - Set Gameobject Flags on ''Idol of Hakkar'''),
(400521, 0, 0, 0, 0, 0, 100, 0, 4000, 10000, 30000, 30000, 0, 0, 11, 8376, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - In Combat - Cast ''Earthgrab Totem'''),
(400521, 0, 1, 0, 0, 0, 100, 0, 2000, 8000, 13000, 18000, 0, 0, 11, 61402, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - In Combat - Cast ''Flamestrike'''),
(400521, 0, 2, 0, 14, 0, 100, 0, 20000, 40, 7000, 11000, 0, 0, 11, 55597, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - Friendly Missing Health - Cast ''Healing Wave'''),
(400521, 0, 3, 4, 0, 0, 100, 0, 12000, 12000, 40000, 40000, 0, 0, 11, 12479, 0, 0, 0, 0, 0, 5, 30, 1, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - In Combat - Cast ''Hex of Jammal''an'''),
(400521, 0, 4, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - In Combat - Say Line 1'),
(400521, 0, 5, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Aggro - Say Line 2'),
(400521, 0, 6, 0, 5, 0, 100, 0, 5000, 5000, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Kill - Say Line 2'),
(400521, 0, 7, 0, 2, 0, 100, 1, 0, 10, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - Between 0-10% Health - Say Line 4'),
(400521, 0, 8, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 39, 90, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Aggro - Call For Help'),
(400521, 0, 9, 10, 6, 0, 100, 512, 0, 0, 0, 0, 0, 0, 28, 12479, 0, 0, 0, 0, 0, 18, 100, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Death - Remove Aura ''Hex of Jammal''an'''),
(400521, 0, 10, 0, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 28, 12480, 0, 0, 0, 0, 0, 18, 100, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Death - Remove Aura ''Hex of Jammal''an'''),
(400521, 0, 11, 0, 11, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 13540, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Respawn - Cast ''Green Channeling'''),
(400521, 0, 12, 0, 21, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 13540, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Jammal''an the Eternal - On Reached Home - Cast ''Green Channeling'''),
(400522, 0, 0, 0, 1, 0, 100, 513, 10000, 10000, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - Out of Combat - Despawn (ritual failed)'),
(400522, 0, 1, 2, 1, 0, 100, 769, 3000, 3000, 0, 0, 0, 0, 19, 33555200, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - Out of Combat - Remove Unit Flags'),
(400522, 0, 2, 3, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 11, 12948, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - Out of Combat - Cast ''Avatar of Hakkar is summoned'''),
(400522, 0, 3, 0, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 40, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - Out of Combat - Start Attacking'),
(400522, 0, 4, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 48, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - On Reset - Set Active On'),
(400522, 0, 5, 0, 0, 0, 100, 0, 4000, 7000, 11000, 20000, 0, 0, 11, 6607, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - In Combat - Cast ''Lash'''),
(400522, 0, 6, 0, 0, 0, 100, 0, 6000, 14000, 14000, 22000, 0, 0, 11, 12889, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - In Combat - Cast ''Curse of Tongues'''),
(400522, 0, 7, 0, 0, 0, 100, 0, 14000, 21000, 25000, 40000, 0, 0, 11, 12888, 0, 0, 0, 0, 0, 6, 30, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - In Combat - Cast ''Cause Insanity'''),
(400522, 0, 8, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Reawakened Avatar of Hakkar - On Aggro - Say Line 0'),
(400523, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 12535, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - On Reset - Cast ''Shade of Eranikus Passive Visual'''),
(400523, 0, 1, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 8876, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - On Reset - Cast ''Thrash'''),
(400523, 0, 2, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - On Aggro - Say Line 0'),
(400523, 0, 3, 0, 0, 0, 100, 0, 14000, 20000, 20000, 30000, 0, 0, 11, 11876, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - In Combat - Cast ''War Stomp'''),
(400523, 0, 4, 0, 0, 0, 100, 0, 7000, 14000, 20000, 26000, 0, 0, 11, 12890, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - In Combat - Cast ''Deep Slumber'''),
(400523, 0, 5, 0, 0, 0, 100, 0, 1000, 11000, 8000, 18000, 0, 0, 11, 56524, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Ancient Shade of Eranikus - In Combat - Cast ''Acid Breath'''),
(400530, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 3418, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Loro - On Reset - Cast ''Improved Blocking'''),
(400530, 0, 1, 0, 13, 0, 100, 0, 8000, 8000, 0, 0, 0, 0, 11, 29684, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Loro - Victim Casting - Cast ''Shield Slam'''),
(400531, 0, 0, 0, 0, 0, 100, 0, 2000, 5000, 8000, 12000, 0, 0, 11, 40505, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zul''Lor - In Combat - Cast ''Cleave'''),
(400531, 0, 1, 0, 0, 0, 100, 0, 1000, 1000, 8000, 14000, 0, 0, 11, 12530, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Zul''Lor - In Combat - Cast ''Frailty'''),
(400532, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 8601, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Murk Worm - On Reset - Cast ''Slowing Poison'''),
(400533, 0, 0, 0, 0, 0, 100, 0, 5000, 19000, 28000, 36000, 0, 0, 12, 400556, 4, 15000, 0, 0, 0, 202, 5, 3, 1, 0, 0, 0, 0, 0, 'Saturated Ooze - In Combat - Summon 3 ''Oozeling'''),
(400534, 0, 0, 0, 14, 0, 100, 0, 12000, 40, 4000, 6000, 0, 0, 11, 31739, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Priest - Friendly Missing Health - Cast ''Heal'''),
(400534, 0, 1, 0, 0, 0, 100, 0, 0, 3000, 3000, 5000, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Priest - In Combat - Cast ''Shadow Bolt'''),
(400535, 0, 0, 0, 0, 0, 100, 0, 0, 6000, 8000, 11000, 0, 0, 11, 60005, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Deathwalker - In Combat - Cast ''Shadow Word: Pain'''),
(400535, 0, 1, 0, 0, 0, 100, 0, 4000, 12000, 12000, 18000, 0, 0, 11, 12096, 0, 0, 0, 0, 0, 6, 20, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Deathwalker - In Combat - Cast ''Fear'''),
(400535, 0, 2, 0, 6, 0, 100, 512, 0, 0, 0, 0, 0, 0, 12, 400554, 4, 30000, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Deathwalker - On Death - Summon ''Atal''ai Deathwalker''s Spirit'''),
(400536, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 3637, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Scalebane - On Reset - Cast ''Improved Blocking III'''),
(400537, 0, 0, 0, 0, 0, 100, 0, 0, 1000, 3000, 4000, 0, 0, 11, 48132, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Wyrmkin - In Combat - Cast ''Acid Spit'''),
(400537, 0, 1, 0, 0, 0, 100, 0, 4000, 12000, 12000, 18000, 0, 0, 11, 12098, 0, 0, 0, 0, 0, 6, 30, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Wyrmkin - In Combat - Cast ''Sleep'''),
(400538, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 6000, 9000, 0, 0, 11, 11976, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Wanderer - In Combat - Cast ''Strike'''),
(400538, 0, 1, 0, 0, 0, 100, 0, 4000, 12000, 12000, 18000, 0, 0, 11, 12097, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Wanderer - In Combat - Cast ''Pierce Armor'''),
(400539, 0, 0, 0, 0, 0, 100, 0, 4000, 8000, 8000, 16000, 0, 0, 11, 5708, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Frostwing - In Combat - Cast ''Swoop'''),
(400539, 0, 1, 0, 0, 0, 100, 0, 5000, 10000, 13000, 21000, 0, 0, 11, 58532, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Frostwing - In Combat - Cast ''Frostbolt Volley'''),
(400539, 0, 2, 0, 106, 0, 100, 0, 10000, 20000, 20000, 30000, 0, 10, 11, 61462, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Frostwing - Within 0-10 Range - Cast ''Frost Nova'''),
(400540, 0, 0, 0, 0, 0, 100, 0, 3000, 8000, 9000, 15000, 0, 0, 11, 28969, 0, 0, 0, 0, 0, 5, 40, 0, 0, 0, 0, 0, 0, 0, 'Spawn of Hakkar - In Combat - Cast ''Acid Spit'''),
(400541, 0, 0, 0, 0, 0, 100, 0, 0, 0, 3000, 4000, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Ogom the Wretched - In Combat - Cast ''Shadow Bolt'''),
(400541, 0, 1, 0, 0, 0, 100, 0, 1000, 6000, 8000, 14000, 0, 0, 11, 60005, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Ogom the Wretched - In Combat - Cast ''Shadow Word: Pain'''),
(400541, 0, 2, 0, 0, 0, 100, 0, 3000, 3000, 12000, 17000, 0, 0, 11, 12493, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Ogom the Wretched - In Combat - Cast ''Curse of Weakness'''),
(400542, 0, 0, 0, 0, 0, 100, 0, 8000, 15000, 18000, 30000, 0, 0, 11, 12882, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Morphaz - In Combat - Cast ''Wing Flap'''),
(400542, 0, 1, 0, 0, 0, 100, 0, 1000, 11000, 8000, 18000, 0, 0, 11, 56524, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Morphaz - In Combat - Cast ''Acid Breath'''),
(400542, 0, 2, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 39, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Morphaz - On Aggro - Call For Help'),
(400543, 0, 0, 0, 0, 0, 100, 0, 8000, 15000, 18000, 30000, 0, 0, 11, 12882, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Weaver - In Combat - Cast ''Wing Flap'''),
(400543, 0, 1, 0, 0, 0, 100, 0, 1000, 11000, 8000, 18000, 0, 0, 11, 56524, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Weaver - In Combat - Cast ''Acid Breath'''),
(400543, 0, 2, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 39, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Weaver - On Aggro - Call For Help'),
(400544, 0, 0, 0, 0, 0, 100, 0, 8000, 15000, 18000, 30000, 0, 0, 11, 12882, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscythe - In Combat - Cast ''Wing Flap'''),
(400544, 0, 1, 0, 0, 0, 100, 0, 1000, 11000, 8000, 18000, 0, 0, 11, 56524, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscythe - In Combat - Cast ''Acid Breath'''),
(400544, 0, 2, 3, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscythe - On Aggro - Say Line 0'),
(400544, 0, 3, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 39, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscythe - On Aggro - Call For Help'),
(400545, 0, 0, 0, 0, 0, 100, 0, 8000, 15000, 18000, 30000, 0, 0, 11, 12882, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hazzas - In Combat - Cast ''Wing Flap'''),
(400545, 0, 1, 0, 0, 0, 100, 0, 1000, 11000, 8000, 18000, 0, 0, 11, 56524, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hazzas - In Combat - Cast ''Acid Breath'''),
(400545, 0, 2, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 39, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Hazzas - On Aggro - Call For Help'),
(400548, 0, 0, 0, 0, 0, 100, 0, 2400, 4900, 11800, 17200, 0, 0, 11, 26050, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Whelp - In Combat - Cast ''Acid Spit'''),
(400549, 0, 0, 0, 0, 0, 100, 0, 3000, 8000, 9000, 15000, 0, 0, 11, 5568, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Deep Lurker - In Combat - Cast ''Trample'''),
(400550, 0, 0, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6288.02, 1247.06, -190.48, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 1, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6283.8, 1257.56, -190.64, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 2, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6286.22, 1267.72, -190.6, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 3, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6297.45, 1275.58, -190.6, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 4, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6308.74, 1272.9, -190.56, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 5, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6316.76, 1261.49, -190.58, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 6, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6313.41, 1249.41, -190.5, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 7, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 50, 700031, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6302.58, 1242.45, -190.57, 0, 'Shade of Hakkar - On Reset - Summon Gameobject ''Evil God Summoning Circle'''),
(400550, 0, 8, 0, 25, 0, 100, 769, 0, 0, 0, 0, 0, 0, 48, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Reset - Set Active On'),
(400550, 0, 9, 10, 77, 0, 100, 512, 2, 25, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 2 = 25 - Despawn (ritual failed)'),
(400550, 0, 10, 0, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 15, 700031, 50, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 2 = 25 - Despawn Summoning Circles'),
(400550, 0, 11, 12, 77, 0, 100, 0, 1, 4, 0, 0, 0, 0, 11, 12639, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 4 - Cast ''Summon Hakkar'''),
(400550, 0, 12, 13, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 12, 400522, 8, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 4 - Summon ''Reawakened Avatar of Hakkar'''),
(400550, 0, 13, 14, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 1000, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 4 - Despawn In 1000 ms'),
(400550, 0, 14, 0, 61, 0, 100, 512, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 15, 700031, 50, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 4 - Despawn Summoning Circles'),
(400550, 0, 15, 0, 77, 0, 100, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 1 - Say Line 0'),
(400550, 0, 16, 0, 77, 0, 100, 0, 1, 2, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 2 - Say Line 1'),
(400550, 0, 17, 0, 77, 0, 100, 0, 1, 3, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 3 - Say Line 2'),
(400550, 0, 18, 0, 77, 0, 100, 0, 1, 4, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shade of Hakkar - On Counter 1 = 4 - Say Line 3'),
(400550, 0, 19, 0, 60, 0, 100, 0, 15000, 15000, 110000, 110000, 0, 0, 12, 400551, 4, 30000, 0, 0, 0, 8, 0, 0, 0, 0, 6332.52, 1273.33, -190.82, 3.37, 'Shade of Hakkar - On Update - Summon ''Hakkari Bloodkeeper'''),
(400550, 0, 20, 0, 60, 0, 100, 0, 70000, 70000, 110000, 110000, 0, 0, 12, 400551, 4, 30000, 0, 0, 0, 8, 0, 0, 0, 0, 6259.64, 1250.35, -190.82, 6.13, 'Shade of Hakkar - On Update - Summon ''Hakkari Bloodkeeper'''),
(400550, 0, 21, 0, 60, 0, 100, 0, 10000, 10000, 70000, 70000, 0, 0, 12, 400553, 4, 30000, 0, 0, 0, 8, 0, 0, 0, 0, 6256.86, 1272.44, -190.82, 5.94, 'Shade of Hakkar - On Update - Summon ''Nightmare Suppressor'''),
(400550, 0, 22, 0, 60, 0, 100, 0, 45000, 45000, 70000, 70000, 0, 0, 12, 400553, 4, 30000, 0, 0, 0, 8, 0, 0, 0, 0, 6345.14, 1252.98, -190.82, 3.03, 'Shade of Hakkar - On Update - Summon ''Nightmare Suppressor'''),
(400551, 0, 0, 0, 11, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 7741, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Bloodkeeper - On Respawn - Cast ''Summoned Demon'''),
(400551, 0, 1, 0, 1, 0, 100, 1, 1000, 1000, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 40, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Bloodkeeper - Out of Combat - Start Attacking'),
(400551, 0, 2, 0, 0, 0, 100, 0, 0, 2000, 3000, 4000, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Bloodkeeper - In Combat - Cast ''Shadow Bolt'''),
(400551, 0, 3, 0, 0, 0, 100, 0, 13000, 17000, 11000, 15000, 0, 0, 11, 60016, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Bloodkeeper - In Combat - Cast ''Corruption'''),
(400552, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 89, 8, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Hakkari Minion - On Reset - Move Random'),
(400553, 0, 0, 0, 11, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 7741, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Suppressor - On Respawn - Cast ''Summoned Demon'''),
(400553, 0, 1, 0, 60, 0, 100, 257, 1000, 1000, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Suppressor - On Update - Say Line 0'),
(400553, 0, 2, 0, 1, 0, 100, 1, 0, 0, 0, 0, 0, 0, 69, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6315.88, 1260.37, -190.55, 0, 'Nightmare Suppressor - Out of Combat - Move To Shade (east door)'),
(400553, 0, 3, 0, 1, 0, 100, 1, 0, 0, 0, 0, 0, 0, 69, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6284.16, 1258.66, -190.63, 0, 'Nightmare Suppressor - Out of Combat - Move To Shade (west door)'),
(400553, 0, 4, 0, 1, 0, 100, 1, 4000, 4000, 0, 0, 0, 0, 11, 12623, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Suppressor - Out of Combat - Cast ''Suppression'''),
(400553, 0, 5, 0, 1, 0, 100, 512, 4000, 4000, 1000, 1000, 0, 0, 63, 2, 1, 0, 0, 0, 0, 19, 400550, 40, 0, 0, 0, 0, 0, 0, 'Nightmare Suppressor - Out of Combat - Set Counter 2 on ''Shade of Hakkar'''),
(400554, 0, 0, 0, 1, 0, 100, 0, 0, 0, 2000, 2000, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 50, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Deathwalker''s Spirit - Out of Combat - Start Attacking'),
(400557, 0, 0, 0, 37, 0, 100, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Totem - On AI Initialize - Set Reactstate Passive'),
(400557, 0, 1, 0, 60, 0, 100, 0, 2000, 2000, 10000, 10000, 0, 0, 12, 400555, 4, 15000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Totem - On Update - Summon ''Atal''ai Skeleton'''),
(400558, 0, 0, 0, 37, 0, 100, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Greater Healing Ward - On AI Initialize - Set Reactstate Passive'),
(400558, 0, 1, 0, 60, 0, 100, 0, 1000, 1000, 4000, 4000, 0, 0, 11, 65993, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Greater Healing Ward - On Update - Cast ''Healing Stream'''),
(400559, 0, 0, 0, 1, 0, 100, 1, 0, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 30, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Voidwalker - Out of Combat - Start Attacking'),
(400560, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 8000, 13000, 0, 0, 11, 21987, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Succubus - In Combat - Cast ''Lash of Pain'''),
(400560, 0, 1, 0, 0, 0, 100, 0, 7000, 13000, 20000, 33000, 0, 0, 11, 6358, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Succubus - In Combat - Cast ''Seduction'''),
(400560, 0, 2, 0, 1, 0, 100, 1, 0, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 30, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Succubus - Out of Combat - Start Attacking'),
(400561, 0, 0, 0, 0, 0, 100, 0, 0, 0, 2500, 3000, 0, 0, 11, 54235, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Imp - In Combat - Cast ''Firebolt'''),
(400561, 0, 1, 0, 1, 0, 100, 1, 0, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 21, 30, 0, 0, 0, 0, 0, 0, 0, 'Hukku''s Imp - Out of Combat - Start Attacking'),
(700018, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 63, 1, 1, 0, 0, 0, 0, 19, 400550, 70, 0, 0, 0, 0, 0, 0, 'Eternal Flame - On Gossip Hello - Set Counter 1 on ''Shade of Hakkar'''),
(700019, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 63, 1, 1, 0, 0, 0, 0, 19, 400550, 70, 0, 0, 0, 0, 0, 0, 'Eternal Flame - On Gossip Hello - Set Counter 1 on ''Shade of Hakkar'''),
(700020, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 63, 1, 1, 0, 0, 0, 0, 19, 400550, 70, 0, 0, 0, 0, 0, 0, 'Eternal Flame - On Gossip Hello - Set Counter 1 on ''Shade of Hakkar'''),
(700021, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 63, 1, 1, 0, 0, 0, 0, 19, 400550, 70, 0, 0, 0, 0, 0, 0, 'Eternal Flame - On Gossip Hello - Set Counter 1 on ''Shade of Hakkar'''),
(700028, 1, 0, 0, 62, 0, 100, 0, 400500, 0, 0, 0, 0, 0, 80, 70002800, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Altar of Hakkar - On Gossip Option 0 Selected - Run Script (statue order)'),
(700031, 1, 0, 0, 60, 0, 100, 0, 3000, 10000, 25000, 25000, 0, 0, 12, 400552, 4, 25000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Evil God Summoning Circle - On Update - Summon ''Hakkari Minion'''),
(700032, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 1405, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 6447.76, 1084.9, -231.85, 3.19, 'Portal to the Temple of Atal''Hakkar - On Gossip Hello - Teleport Invoker'),
(700033, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 1405, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 6365.5, 1063, 17.15, 3.1416, 'Portal to the War Drum Hall - On Gossip Hello - Teleport Invoker'),
(70002800, 9, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 105, 4, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Altar of Hakkar - Actionlist - Add Gameobject Flag'),
(70002800, 9, 1, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6251.45, 1080.26, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 1'),
(70002800, 9, 2, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6347.15, 1079.48, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 2'),
(70002800, 9, 3, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6275.6, 1120.97, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 3'),
(70002800, 9, 4, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6275.51, 1038.48, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 4'),
(70002800, 9, 5, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6323.14, 1121.1, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 5'),
(70002800, 9, 6, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, 0, 50, 148883, 4, 0, 0, 0, 0, 8, 0, 0, 0, 0, 6323.58, 1038.83, -248.74, 0, 'Altar of Hakkar - Actionlist - Summon ''Atal''ai Light SMALL'' over statue 6'),
(70002800, 9, 7, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 106, 4, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Altar of Hakkar - Actionlist - Remove Gameobject Flag');

-- ---- conditions --------------------------------------------------------------------------------------------
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceEntry` IN (400501, 400553) AND `SourceId` = 0;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(22, 6, 400501, 0, 0, 26, 1, 2, 0, 0, 0, 0, 0, '', 'Witch Doctor: Ice Cast Visual only for phase-2 spawns'),
(22, 3, 400553, 0, 0, 30, 1, 700030, 50, 0, 0, 0, 0, '', 'Suppressor: walk from the east door'),
(22, 4, 400553, 0, 0, 30, 1, 700029, 50, 0, 0, 0, 0, '', 'Suppressor: walk from the west door');
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceGroup` = 1 AND `SourceEntry` = 12134 AND `ElseGroup` BETWEEN 5 AND 9;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(13, 1, 12134, 0, 5, 31, 0, 3, 400500, 0, 0, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Awakened Atal''ai Warrior'),
(13, 1, 12134, 0, 5, 36, 0, 0, 0, 0, 1, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Awakened Atal''ai Warrior is dead'),
(13, 1, 12134, 0, 6, 31, 0, 3, 400501, 0, 0, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Awakened Atal''ai Witch Doctor'),
(13, 1, 12134, 0, 6, 36, 0, 0, 0, 0, 1, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Awakened Atal''ai Witch Doctor is dead'),
(13, 1, 12134, 0, 7, 31, 0, 3, 400504, 0, 0, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Atal''ai Soulflayer'),
(13, 1, 12134, 0, 7, 36, 0, 0, 0, 0, 1, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Atal''ai Soulflayer is dead'),
(13, 1, 12134, 0, 8, 31, 0, 3, 400535, 0, 0, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Atal''ai Deathwalker'),
(13, 1, 12134, 0, 8, 36, 0, 0, 0, 0, 1, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Atal''ai Deathwalker is dead'),
(13, 1, 12134, 0, 9, 31, 0, 3, 400502, 0, 0, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Risen Atal''ai Priest'),
(13, 1, 12134, 0, 9, 36, 0, 0, 0, 0, 1, 0, 0, '', 'Atal''ai Corpse Eat: corpse of Risen Atal''ai Priest is dead');

-- ---- loot: the custom idol fragments / boss pools plus level-80 world loot (all 4005xx creature loot) ------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400540, 400541, 400542, 400543, 400544, 400545, 400551);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400500, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Awakened Atal''ai Warrior - World Loot Level 80'),
(400500, 33445, 0, 4, 0, 1, 0, 1, 1, 'Awakened Atal''ai Warrior - Honeymint Tea'),
(400500, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Awakened Atal''ai Warrior - Frostweave Cloth'),
(400500, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Awakened Atal''ai Warrior - Thick Fur Clothing Scraps'),
(400500, 402000, 0, 20, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400500, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Awakened Atal''ai Warrior - Dungeon Trash Rares'),
(400501, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Awakened Atal''ai Witch Doctor - World Loot Level 80'),
(400501, 33445, 0, 4, 0, 1, 0, 1, 1, 'Awakened Atal''ai Witch Doctor - Honeymint Tea'),
(400501, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Awakened Atal''ai Witch Doctor - Frostweave Cloth'),
(400501, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Awakened Atal''ai Witch Doctor - Thick Fur Clothing Scraps'),
(400501, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400501, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Awakened Atal''ai Witch Doctor - Dungeon Trash Rares'),
(400502, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Risen Atal''ai Priest - World Loot Level 80'),
(400502, 33445, 0, 4, 0, 1, 0, 1, 1, 'Risen Atal''ai Priest - Honeymint Tea'),
(400502, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Risen Atal''ai Priest - Frostweave Cloth'),
(400502, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Risen Atal''ai Priest - Thick Fur Clothing Scraps'),
(400502, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400502, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Risen Atal''ai Priest - Dungeon Trash Rares'),
(400503, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Atal''ai Boneguard - World Loot Level 80'),
(400503, 33445, 0, 4, 0, 1, 0, 1, 1, 'Atal''ai Boneguard - Honeymint Tea'),
(400503, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Atal''ai Boneguard - Frostweave Cloth'),
(400503, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Atal''ai Boneguard - Thick Fur Clothing Scraps'),
(400503, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400503, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Atal''ai Boneguard - Dungeon Trash Rares'),
(400504, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Atal''ai Soulflayer - World Loot Level 80'),
(400504, 33445, 0, 4, 0, 1, 0, 1, 1, 'Atal''ai Soulflayer - Honeymint Tea'),
(400504, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Atal''ai Soulflayer - Frostweave Cloth'),
(400504, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Atal''ai Soulflayer - Thick Fur Clothing Scraps'),
(400504, 402000, 0, 25, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400504, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Atal''ai Soulflayer - Dungeon Trash Rares'),
(400505, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Hakkar''s Devotee - World Loot Level 80'),
(400505, 33445, 0, 4, 0, 1, 0, 1, 1, 'Hakkar''s Devotee - Honeymint Tea'),
(400505, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Hakkar''s Devotee - Frostweave Cloth'),
(400505, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Hakkar''s Devotee - Thick Fur Clothing Scraps'),
(400505, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400505, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Hakkar''s Devotee - Dungeon Trash Rares'),
(400510, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Zul''kar the Flayer - World Loot Level 80'),
(400510, 33445, 0, 4, 0, 1, 0, 1, 1, 'Zul''kar the Flayer - Honeymint Tea'),
(400510, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Zul''kar the Flayer - Frostweave Cloth'),
(400510, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Zul''kar the Flayer - Thick Fur Clothing Scraps'),
(400510, 402000, 0, 75, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400510, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Zul''kar the Flayer - Dungeon Trash Rares'),
(400511, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Seer Mazra - World Loot Level 80'),
(400511, 33445, 0, 4, 0, 1, 0, 1, 1, 'Seer Mazra - Honeymint Tea'),
(400511, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Seer Mazra - Frostweave Cloth'),
(400511, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Seer Mazra - Thick Fur Clothing Scraps'),
(400511, 402000, 0, 75, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400511, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Seer Mazra - Dungeon Trash Rares'),
(400512, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Bone Weaver Zolo - World Loot Level 80'),
(400512, 33445, 0, 4, 0, 1, 0, 1, 1, 'Bone Weaver Zolo - Honeymint Tea'),
(400512, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Bone Weaver Zolo - Frostweave Cloth'),
(400512, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Bone Weaver Zolo - Thick Fur Clothing Scraps'),
(400512, 402000, 0, 75, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400512, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Bone Weaver Zolo - Dungeon Trash Rares'),
(400513, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Soul Raker Mijan - World Loot Level 80'),
(400513, 33445, 0, 4, 0, 1, 0, 1, 1, 'Soul Raker Mijan - Honeymint Tea'),
(400513, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Soul Raker Mijan - Frostweave Cloth'),
(400513, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Soul Raker Mijan - Thick Fur Clothing Scraps'),
(400513, 402000, 0, 75, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400513, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Soul Raker Mijan - Dungeon Trash Rares'),
(400520, 0, 14132, 40, 0, 1, 0, 1, 1, 'ref: temple boss loot pool'),
(400520, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Atal''alarion the Eternal - World Loot Level 80'),
(400520, 33445, 0, 4, 0, 1, 0, 1, 1, 'Atal''alarion the Eternal - Honeymint Tea'),
(400520, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Atal''alarion the Eternal - Frostweave Cloth'),
(400520, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Atal''alarion the Eternal - Thick Fur Clothing Scraps'),
(400520, 402000, 0, 100, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400521, 0, 14132, 60, 0, 1, 0, 1, 1, 'ref: temple boss loot pool'),
(400521, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Jammal''an the Eternal - World Loot Level 80'),
(400521, 33445, 0, 4, 0, 1, 0, 1, 1, 'Jammal''an the Eternal - Honeymint Tea'),
(400521, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Jammal''an the Eternal - Frostweave Cloth'),
(400521, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Jammal''an the Eternal - Thick Fur Clothing Scraps'),
(400521, 402000, 0, 100, 1, 1, 0, 2, 3, 'Idol Fragment of Hakkar x2-3 (quest)'),
(400522, 0, 14132, 100, 0, 1, 0, 1, 1, 'ref: temple boss loot pool'),
(400522, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Reawakened Avatar of Hakkar - World Loot Level 80'),
(400522, 402016, 0, 30, 0, 1, 0, 1, 1, 'Talisman of the Blood God (trinket, 30%)'),
(400522, 402021, 0, 20, 0, 1, 0, 1, 1, 'Hakkar''s Eternal Seal (epic ring, 20%)'),
(400523, 0, 14132, 80, 0, 1, 0, 1, 1, 'ref: temple boss loot pool'),
(400523, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Ancient Shade of Eranikus - World Loot Level 80'),
(400523, 402020, 0, 30, 0, 1, 0, 1, 1, 'Ward of Hakkar (trinket, 30%)'),
(400523, 402022, 0, 20, 0, 1, 0, 1, 1, 'Dreamscale Amulet of Eranikus (epic neck, 20%)'),
(400530, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Loro - World Loot Level 80'),
(400530, 2, 14132, 15, 0, 1, 0, 1, 1, 'Loro - Temple boss loot pool'),
(400530, 33445, 0, 4, 0, 1, 0, 1, 1, 'Loro - Honeymint Tea'),
(400530, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Loro - Frostweave Cloth'),
(400530, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Loro - Thick Fur Clothing Scraps'),
(400530, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Loro - Dungeon Trash Rares'),
(400531, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Zul''Lor - World Loot Level 80'),
(400531, 2, 14132, 15, 0, 1, 0, 1, 1, 'Zul''Lor - Temple boss loot pool'),
(400531, 33445, 0, 4, 0, 1, 0, 1, 1, 'Zul''Lor - Honeymint Tea'),
(400531, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Zul''Lor - Frostweave Cloth'),
(400531, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Zul''Lor - Thick Fur Clothing Scraps'),
(400531, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Zul''Lor - Dungeon Trash Rares'),
(400540, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Spawn of Hakkar - World Loot Level 80'),
(400540, 2, 14132, 15, 0, 1, 0, 1, 1, 'Spawn of Hakkar - Temple boss loot pool'),
(400540, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Spawn of Hakkar - Dungeon Trash Rares'),
(400541, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Ogom the Wretched - World Loot Level 80'),
(400541, 2, 14132, 15, 0, 1, 0, 1, 1, 'Ogom the Wretched - Temple boss loot pool'),
(400541, 33445, 0, 4, 0, 1, 0, 1, 1, 'Ogom the Wretched - Honeymint Tea'),
(400541, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Ogom the Wretched - Frostweave Cloth'),
(400541, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Ogom the Wretched - Thick Fur Clothing Scraps'),
(400541, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Ogom the Wretched - Dungeon Trash Rares'),
(400542, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Morphaz - World Loot Level 80'),
(400542, 2, 14132, 15, 0, 1, 0, 1, 1, 'Morphaz - Temple boss loot pool'),
(400542, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Morphaz - Dungeon Trash Rares'),
(400543, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Weaver - World Loot Level 80'),
(400543, 2, 14132, 15, 0, 1, 0, 1, 1, 'Weaver - Temple boss loot pool'),
(400543, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Weaver - Dungeon Trash Rares'),
(400544, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Dreamscythe - World Loot Level 80'),
(400544, 2, 14132, 15, 0, 1, 0, 1, 1, 'Dreamscythe - Temple boss loot pool'),
(400544, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Dreamscythe - Dungeon Trash Rares'),
(400545, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Hazzas - World Loot Level 80'),
(400545, 2, 14132, 15, 0, 1, 0, 1, 1, 'Hazzas - Temple boss loot pool'),
(400545, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Hazzas - Dungeon Trash Rares'),
(400551, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Hakkari Bloodkeeper - World Loot Level 80'),
(400551, 10460, 0, 100, 0, 1, 0, 1, 1, 'Hakkari Bloodkeeper - Hakkari Blood'),
(400551, 33445, 0, 4, 0, 1, 0, 1, 1, 'Hakkari Bloodkeeper - Honeymint Tea'),
(400551, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Hakkari Bloodkeeper - Frostweave Cloth'),
(400551, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Hakkari Bloodkeeper - Thick Fur Clothing Scraps');

-- ---- gameobject templates ----------------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` BETWEEN 700018 AND 700034;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700018, 10, 2570, 'Eternal Flame', '', '', '', 1, 520, 0, 0, 86400000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700019, 10, 2570, 'Eternal Flame', '', '', '', 1, 520, 0, 0, 86400000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700020, 10, 2570, 'Eternal Flame', '', '', '', 1, 520, 0, 0, 86400000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700021, 10, 2570, 'Eternal Flame', '', '', '', 1, 520, 0, 0, 86400000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700022, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700023, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700024, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700025, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700026, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700027, 10, 212, 'Atal''ai Statue', '', '', '', 1, 93, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_atalai_statue', 12340),
(700028, 2, 2615, 'Altar of Hakkar', '', '', '', 1.2, 0, 2735, 5, 400500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700029, 0, 2451, 'DOOR1', '', '', '', 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
(700030, 0, 2451, 'DOOR2', '', '', '', 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
(700031, 10, 674, 'Evil God Summoning Circle', '', '', '', 1.5, 0, 0, 0, 3000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700032, 22, 672, 'Portal to the Temple of Atal''Hakkar', '', '', '', 0.8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700033, 22, 672, 'Portal to the War Drum Hall', '', '', '', 0.8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 12340),
(700034, 10, 2615, 'Altar of the Soulflayer', '', '', '', 0.9, 0, 0, 0, 3000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_giant_isles_soulflayer_altar', 12340);
DELETE FROM `gameobject_template_addon` WHERE `entry` BETWEEN 700018 AND 700034;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`) VALUES
(700018, 0, 32, 0, 0, 0, 0, 0, 0),
(700019, 0, 32, 0, 0, 0, 0, 0, 0),
(700020, 0, 32, 0, 0, 0, 0, 0, 0),
(700021, 0, 32, 0, 0, 0, 0, 0, 0),
(700028, 35, 0, 0, 0, 0, 0, 0, 0),
(700029, 14, 48, 0, 0, 0, 0, 0, 0),
(700030, 14, 48, 0, 0, 0, 0, 0, 0),
(700031, 14, 48, 0, 0, 0, 0, 0, 0),
(700034, 35, 0, 0, 0, 0, 0, 0, 0);
DELETE FROM `gossip_menu` WHERE `MenuID` = 400500;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(400500, 1923);
DELETE FROM `gossip_menu_option` WHERE `MenuID` = 400500;
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(400500, 0, 0, 'How could the altar and the statues be related?', 4417, 1, 1, 1302, 0, 0, 0, '', 0, 12340);

-- ---- spawns ----------------------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9003001 AND 9003999 AND `id` IN (15593, 400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400522, 400523, 400530, 400531, 400532, 400533, 400534, 400535, 400536, 400537, 400538, 400539, 400540, 400541, 400542, 400543, 400544, 400545, 400546, 400547, 400548, 400549, 400550, 400551, 400552, 400553, 400554, 400555, 400556, 400557, 400558, 400559, 400560, 400561);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT
    `g`.`new`, `m`.`dst`, 1405, 5006, 5008, 1, `c`.`phaseMask`, `c`.`equipment_id`,
    `c`.`position_x` + 6767, `c`.`position_y` + 985, `c`.`position_z` - 100, `c`.`orientation`,
    IF(`m`.`clone` = 1, 1800, `c`.`spawntimesecs`), `c`.`wander_distance`, 0, 0, 0, `c`.`MovementType`,
    `c`.`npcflag`, `c`.`unit_flags`, `c`.`dynamicflags`, '', 0, 0, 'IoG Temple of Atal''Hakkar'
FROM `creature` AS `c`
JOIN `tmp_iog_guid` AS `g` ON `g`.`old` = `c`.`guid`
JOIN `tmp_iog_npc` AS `m` ON `m`.`src` = `c`.`id`;
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9003001 AND 9003999;
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT
    `g`.`new`, IF(`a`.`path_id` = 0, 0, `g`.`new` * 10), `a`.`mount`, `a`.`bytes1`, `a`.`bytes2`, `a`.`emote`,
    `a`.`visibilityDistanceType`, `a`.`auras`
FROM `creature_addon` AS `a`
JOIN `tmp_iog_guid` AS `g` ON `g`.`old` = `a`.`guid`;
DELETE FROM `waypoint_data` WHERE `id` BETWEEN 90030010 AND 90039990;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`, `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT
    `g`.`new` * 10, `w`.`point`, `w`.`position_x` + 6767, `w`.`position_y` + 985, `w`.`position_z` - 100, `w`.`orientation`,
    `w`.`velocity`, `w`.`delay`, `w`.`smoothTransition`, `w`.`move_type`, `w`.`action`, `w`.`action_chance`, 0
FROM `creature_addon` AS `a`
JOIN `tmp_iog_guid` AS `g` ON `g`.`old` = `a`.`guid`
JOIN `waypoint_data` AS `w` ON `w`.`id` = `a`.`path_id`
WHERE `a`.`path_id` <> 0;
-- MySQL cannot open one TEMPORARY table twice in a query (error 1137): the member side joins a copy
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_guid2`;
CREATE TEMPORARY TABLE `tmp_iog_guid2` (`old` INT UNSIGNED NOT NULL PRIMARY KEY, `new` INT UNSIGNED NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_guid2`;
INSERT INTO `tmp_iog_guid2` (`old`, `new`)
SELECT
    `t`.`old`, `t`.`new`
FROM `tmp_iog_guid` AS `t`;
DELETE FROM `creature_formations` WHERE `leaderGUID` BETWEEN 9003001 AND 9003999;
INSERT INTO `creature_formations` (`leaderGUID`, `memberGUID`, `dist`, `angle`, `groupAI`, `point_1`, `point_2`)
SELECT
    `gl`.`new`, `gm`.`new`, `f`.`dist`, `f`.`angle`, `f`.`groupAI`, `f`.`point_1`, `f`.`point_2`
FROM `creature_formations` AS `f`
JOIN `tmp_iog_guid` AS `gl` ON `gl`.`old` = `f`.`leaderGUID`
JOIN `tmp_iog_guid2` AS `gm` ON `gm`.`old` = `f`.`memberGUID`;
DELETE FROM `pool_template` WHERE `entry` = 400500;
INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
(400500, 1, 'IoG Temple of Atal''Hakkar - Spawn of Hakkar');
DELETE FROM `pool_creature` WHERE `guid` BETWEEN 9003001 AND 9003999;
INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`)
SELECT
    `g`.`new`, 400500, `p`.`chance`, 'IoG Temple of Atal''Hakkar - Spawn of Hakkar'
FROM `pool_creature` AS `p`
JOIN `tmp_iog_guid` AS `g` ON `g`.`old` = `p`.`guid`;
DELETE FROM `game_event_creature` WHERE `guid` BETWEEN 9003001 AND 9003999;
INSERT INTO `game_event_creature` (`eventEntry`, `guid`)
SELECT
    `e`.`eventEntry`, `g`.`new`
FROM `game_event_creature` AS `e`
JOIN `tmp_iog_guid` AS `g` ON `g`.`old` = `e`.`guid`;
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9005401 AND 9005430 AND `id` IN (148422, 148512, 149431, 700018, 700019, 700020, 700021, 700022, 700023, 700024, 700025, 700026, 700027, 700028, 700029, 700030, 700032, 700033, 700034);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`)
SELECT
    `n`.`new`, `m`.`dst`, 1405, 5006, 5008, 1, `o`.`phaseMask`, `o`.`position_x` + 6767, `o`.`position_y` + 985,
    `o`.`position_z` - 100, `o`.`orientation`, `o`.`rotation0`, `o`.`rotation1`, `o`.`rotation2`, `o`.`rotation3`, `o`.`spawntimesecs`,
    `o`.`animprogress`, `o`.`state`, '', 0, 'IoG Temple of Atal''Hakkar'
FROM `gameobject` AS `o`
JOIN `tmp_iog_goguid` AS `n` ON `n`.`old` = `o`.`guid`
JOIN `tmp_iog_go` AS `m` ON `m`.`src` = `o`.`id`;
-- portals (War Drum hall <-> dungeon entrance) and the Altar of the Soulflayer
DELETE FROM `gameobject` WHERE `guid` IN (9005420, 9005421, 9005422) AND `id` IN (700032, 700033, 700034);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9005420, 700032, 1405, 5006, 5008, 1, 1, 6369.5, 1063, 17.2, 3.1416, 0, 0, 1, 0, 300, 0, 1, '', 0, 'IoG Temple of Atal''Hakkar - War Drum hall portal down'),
(9005421, 700033, 1405, 5006, 5008, 1, 1, 6451, 1084.9, -231.85, 3.1416, 0, 0, 1, 0, 300, 0, 1, '', 0, 'IoG Temple of Atal''Hakkar - dungeon exit portal'),
(9005422, 700034, 1405, 5006, 5008, 1, 1, 6299.91, 1261.58, -190.47, 0, 0, 0, 0, 1, 300, 0, 1, '', 0, 'IoG Temple of Atal''Hakkar - Hakkar ritual altar');

-- ---- custom quests: dungeon quests of the island zone; dailies flagged daily; goblins may take the Horde ones ----
UPDATE `quest_template` SET `QuestSortID` = 5006, `QuestInfoID` = 81, `SuggestedGroupNum` = 5, `Flags` = 8 WHERE `ID` IN (82000, 82001, 82002, 82003, 82004, 82010, 82011, 82012, 82013);
UPDATE `quest_template` SET `QuestSortID` = 5006, `QuestInfoID` = 81, `SuggestedGroupNum` = 5, `QuestType` = 2, `Flags` = 4104 WHERE `ID` IN (82005, 82014, 82015);
UPDATE `quest_template` SET `AllowableRaces` = 29361330 WHERE `ID` IN (82012, 82013, 82015);

DROP TEMPORARY TABLE IF EXISTS `tmp_iog_npc`;
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_go`;
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_guid`;
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_guid2`;
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_goguid`;
