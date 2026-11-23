-- DarkChaos Azshara Crater (map 37): keep level 21-26 mobs away from the level 8-18 quest and grind spots.
-- Meter run 14/15 (11-22, killer columns): bots of level 5-19 died in 17-31% of their crater fights, mostly to
-- mobs 8-16 levels above them that they fought back after being pulled:
--   * the skeleton camp of "The Wailing Noble" (300204, quest level 18) is stock Duskwood skeletons, level 21-23;
--   * the Mosshide cave mouth opens onto the level 10 Dreadbone grounds (300200/300205), and a Brute, a Mystic and
--     a patrolling Fenrunner stood in it;
--   * a level 25 crocolisk wandered 40 yd from the level 9 murloc shore (300108).
-- New positions were checked against the server's map 37 terrain files: on the ground, out of the water, at least
-- 65 yd (crocolisks) / 45 yd (skeletons) from any level 16 or lower mob. Re-runnable.

-- 1) "The Wailing Noble": level 17-19 copies of Skeletal Warrior 48 and Skeletal Mage 203 replace the stock spawns
--    on map 37, and the quest counts the copy. The stock entries still spawn in Duskwood and are not changed.
DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_template` WHERE `entry` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `entry` = CASE `entry` WHEN 48 THEN 300097 ELSE 300098 END;
-- creature_template rows are never deleted: an existing copy is kept, the UPDATE below sets its levels again.
DELETE FROM `tmp_dc_crater_skeleton` WHERE `entry` IN (SELECT `entry` FROM `creature_template`);
INSERT INTO `creature_template` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;
UPDATE `creature_template` SET `minlevel` = 17, `maxlevel` = 18 WHERE `entry` = 300097;
UPDATE `creature_template` SET `minlevel` = 18, `maxlevel` = 19 WHERE `entry` = 300098;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_template_addon` WHERE `entry` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `entry` = CASE `entry` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_template_addon` WHERE `entry` IN (300097, 300098);
INSERT INTO `creature_template_addon` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_template_locale` WHERE `entry` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `entry` = CASE `entry` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_template_locale` WHERE `entry` IN (300097, 300098);
INSERT INTO `creature_template_locale` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_template_model` WHERE `CreatureID` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `CreatureID` = CASE `CreatureID` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (300097, 300098);
INSERT INTO `creature_template_model` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_template_spell` WHERE `CreatureID` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `CreatureID` = CASE `CreatureID` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (300097, 300098);
INSERT INTO `creature_template_spell` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_equip_template` WHERE `CreatureID` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `CreatureID` = CASE `CreatureID` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (300097, 300098);
INSERT INTO `creature_equip_template` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton` SELECT * FROM `creature_questitem` WHERE `CreatureEntry` IN (48, 203);
UPDATE `tmp_dc_crater_skeleton` SET `CreatureEntry` = CASE `CreatureEntry` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `creature_questitem` WHERE `CreatureEntry` IN (300097, 300098);
INSERT INTO `creature_questitem` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

-- SmartAI: Battle Stance + Hamstring (warrior), Frost Armor + Frostbolt (mage), as on the stock entries.
DROP TEMPORARY TABLE IF EXISTS `tmp_dc_crater_skeleton`;
CREATE TEMPORARY TABLE `tmp_dc_crater_skeleton`
    SELECT * FROM `smart_scripts` WHERE `entryorguid` IN (48, 203) AND `source_type` = 0;
UPDATE `tmp_dc_crater_skeleton` SET `entryorguid` = CASE `entryorguid` WHEN 48 THEN 300097 ELSE 300098 END;
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (300097, 300098) AND `source_type` = 0;
INSERT INTO `smart_scripts` SELECT * FROM `tmp_dc_crater_skeleton`;
DROP TEMPORARY TABLE `tmp_dc_crater_skeleton`;

-- The map 37 spawns: 4 warriors, 6 mages.
UPDATE `creature` SET `id` = 300097 WHERE `id` = 48 AND `guid` IN (9000639, 9000640, 9000641, 9000642);
UPDATE `creature` SET `id` = 300098
    WHERE `id` = 203 AND `guid` IN (9000632, 9000633, 9000634, 9000635, 9000636, 9000637);
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 300097 WHERE `ID` = 300204 AND `RequiredNpcOrGo1` IN (48, 300097);

-- The two northern mages stood 36 and 55 yd from the Dreadbone grounds and wandered 30 yd; they join the camp.
UPDATE `creature` SET `position_x` = -46, `position_y` = 630, `position_z` = 271.95, `wander_distance` = 15
    WHERE `id` IN (203, 300098) AND `guid` = 9000632;
UPDATE `creature` SET `position_x` = -34, `position_y` = 630, `position_z` = 270.78, `wander_distance` = 15
    WHERE `id` IN (203, 300098) AND `guid` = 9000633;

-- 2) Mosshide cave: the cave runs west under the hill, its mouth (x -170..-145) opens next to the Dreadbone
--    Skeletons and Venture Co. Mercenaries. The Brute and the Mystic in the mouth move onto points of Brute
--    9000739's own patrol path inside the cave (waypoint path 53004810 points 9 and 13, so known floor). Fenrunner
--    9000742 walked path 53004811 out of the mouth to x -145; it now stands at point 5 of the same inner path.
--    Path 53004811 stays in waypoint_data, unused.
UPDATE `creature` SET `position_x` = -210.927, `position_y` = 677.084, `position_z` = 286.644
    WHERE `id` = 1012 AND `guid` = 9000741;
UPDATE `creature` SET `position_x` = -222.998, `position_y` = 676.756, `position_z` = 285.005
    WHERE `id` = 1013 AND `guid` = 9000740;
UPDATE `creature` SET `position_x` = -198.857, `position_y` = 677.412, `position_z` = 286.389, `MovementType` = 0
    WHERE `id` = 1010 AND `guid` = 9000742;
UPDATE `creature_addon` SET `path_id` = 0 WHERE `guid` = 9000742 AND `path_id` IN (0, 53004811);

-- 3) Giant Wetlands Crocolisks ("Teeth in the Shallows", 300308, level 25): 9000672 stood 39 yd from the murlocs
--    and 9000671 58 yd, each wandering 30 yd. Both move next to 9000670 on the same shore; all three wander 10 yd.
UPDATE `creature` SET `position_x` = 256, `position_y` = 684, `position_z` = 261.28
    WHERE `id` = 2089 AND `guid` = 9000671;
UPDATE `creature` SET `position_x` = 268, `position_y` = 672, `position_z` = 262.17
    WHERE `id` = 2089 AND `guid` = 9000672;
UPDATE `creature` SET `wander_distance` = 10 WHERE `id` = 2089 AND `guid` IN (9000670, 9000671, 9000672);
