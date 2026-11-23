-- DarkChaos Azshara Crater (map 37), follow-up to rev_1795346712154348800. Re-runnable.

-- 1) The Blackrock camp (levels 19-25, quests 300900/300901) had two stock Blazing Elementals 5850 at level 45,
--    16-50 yd from level 23-25 grind spots. A level 23-24 copy (300099) replaces them on map 37. Its loot is
--    the stock fire drops of that level (Coal, Elemental Fire) plus the level 23-24 world drops; the stock
--    table's Searing Gorge quest items and level 45-47 world drops are left out.
DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_elemental`;
CREATE TEMPORARY TABLE `tmp_dc_crater_elemental` SELECT * FROM `creature_template` WHERE `entry` = 5850;
UPDATE `tmp_dc_crater_elemental` SET `entry` = 300099;
-- creature_template rows are never deleted: an existing copy is kept, the UPDATE below sets its values again.
DELETE FROM `tmp_dc_crater_elemental` WHERE `entry` IN (SELECT `entry` FROM `creature_template`);
INSERT INTO `creature_template` SELECT * FROM `tmp_dc_crater_elemental`;
DROP TEMPORARY TABLE `tmp_dc_crater_elemental`;
UPDATE `creature_template` SET `minlevel` = 23, `maxlevel` = 24, `lootid` = 300099 WHERE `entry` = 300099;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_elemental`;
CREATE TEMPORARY TABLE `tmp_dc_crater_elemental` SELECT * FROM `creature_template_addon` WHERE `entry` = 5850;
UPDATE `tmp_dc_crater_elemental` SET `entry` = 300099;
DELETE FROM `creature_template_addon` WHERE `entry` = 300099;
INSERT INTO `creature_template_addon` SELECT * FROM `tmp_dc_crater_elemental`;
DROP TEMPORARY TABLE `tmp_dc_crater_elemental`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_elemental`;
CREATE TEMPORARY TABLE `tmp_dc_crater_elemental` SELECT * FROM `creature_template_locale` WHERE `entry` = 5850;
UPDATE `tmp_dc_crater_elemental` SET `entry` = 300099;
DELETE FROM `creature_template_locale` WHERE `entry` = 300099;
INSERT INTO `creature_template_locale` SELECT * FROM `tmp_dc_crater_elemental`;
DROP TEMPORARY TABLE `tmp_dc_crater_elemental`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_elemental`;
CREATE TEMPORARY TABLE `tmp_dc_crater_elemental` SELECT * FROM `creature_template_model` WHERE `CreatureID` = 5850;
UPDATE `tmp_dc_crater_elemental` SET `CreatureID` = 300099;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300099;
INSERT INTO `creature_template_model` SELECT * FROM `tmp_dc_crater_elemental`;
DROP TEMPORARY TABLE `tmp_dc_crater_elemental`;

DELETE FROM `creature_loot_template` WHERE `Entry` = 300099;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(300099, 3857, 0, 28.3854, 0, 1, 0, 1, 1, 'Blazing Elemental (crater) - Coal'),
(300099, 7068, 0, 8.75, 0, 1, 0, 1, 1, 'Blazing Elemental (crater) - Elemental Fire'),
(300099, 1, 1000123, 0, 0, 1, 5, 1, 1, 'Blazing Elemental (crater) - World Loot Level 23'),
(300099, 2, 1000124, 0, 0, 1, 5, 1, 1, 'Blazing Elemental (crater) - World Loot Level 24');

UPDATE `creature` SET `id` = 300099 WHERE `id` = 5850 AND `guid` IN (9000716, 9000717);

-- 2) "The Mosshide Menace" (300912) asks for 8 Mosshide Brutes and 8 Mosshide Mystics; the cave held two of each.
--    Two more of each go into the camp room at the back of the cave. Its five spawns (x -270..-241) all stand at
--    z 282.7-283.1, so each new one is put on the midpoint between two of them (or between one of them and a
--    point of patrol path 53004810), 9-13 yd from its neighbours. The rows are copies of Brute 9000741 and
--    Mystic 9000740 (both static) with a new guid and position.
DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_mosshide`;
CREATE TEMPORARY TABLE `tmp_dc_crater_mosshide`
    SELECT * FROM `creature` WHERE `guid` IN (9000740, 9000741)
    UNION ALL SELECT * FROM `creature` WHERE `guid` IN (9000740, 9000741);
UPDATE `tmp_dc_crater_mosshide` SET `guid` = 9000744, `position_x` = -260.25, `position_y` = 681.3,
    `position_z` = 282.85 WHERE `guid` = 9000741 LIMIT 1;
UPDATE `tmp_dc_crater_mosshide` SET `guid` = 9000747, `position_x` = -234.7, `position_y` = 670.3,
    `position_z` = 283.8 WHERE `guid` = 9000741 LIMIT 1;
UPDATE `tmp_dc_crater_mosshide` SET `guid` = 9000748, `position_x` = -253.1, `position_y` = 663.8,
    `position_z` = 283.0 WHERE `guid` = 9000740 LIMIT 1;
UPDATE `tmp_dc_crater_mosshide` SET `guid` = 9000775, `position_x` = -246.25, `position_y` = 672.8,
    `position_z` = 282.9 WHERE `guid` = 9000740 LIMIT 1;
DELETE FROM `creature` WHERE `id` IN (1012, 1013) AND `guid` IN (9000744, 9000747, 9000748, 9000775);
INSERT INTO `creature` SELECT * FROM `tmp_dc_crater_mosshide`;
DROP TEMPORARY TABLE `tmp_dc_crater_mosshide`;
