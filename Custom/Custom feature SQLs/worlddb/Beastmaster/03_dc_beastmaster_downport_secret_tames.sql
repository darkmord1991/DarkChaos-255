-- ============================================================================
-- DC Beastmaster - Secret Hunter Pet Tames downport (batch 2026-07-14)
-- ============================================================================
-- 12 famous "secret tame" models from the Wowhead guide, downported via the
-- wow.export -> casc-extract -> wxl-baker pipeline. Client assets ship in
-- patch-F.MPQ (baked M2 + skins) and DBC rows 502610-502621 / display ids below
-- in CreatureDisplayInfo.dbc + CreatureModelData.dbc (patch-4 + patch-enGB-3 +
-- server data/dbc). 5 NEW pet families were added to CreatureFamily.dbc:
-- 56 Direhorn, 57 Feathermane, 58 Mechanical, 59 Quilen, 60 Blood Beast.
--
-- Entry->display->family mapping (display = REUSED retail CreatureDisplayInfo id):
--   990010 Horridon             47325  Direhorn(56)
--   990011 Fenryr               64466  Wolf(1)
--   990012 Lightning Paw        74736  Fox(50)
--   990013 Cragmaw the Infested 78855  Blood Beast(60)
--   990014 Sabertron            86224  Mechanical(58)
--   990015 Grey Juggernaut      70231  Mechanical(58)
--   990016 K.U.-J.0.            90775  Mechanical(58)
--   990017 Andira               93463  Feathermane(57)  EXOTIC (retail BM-only)
--   990018 Portent              45427  Quilen(59)
--   990019 Madexx               37360  Scorpid(20)
--   990020 Deth'tilac           38424  Spider(3)
--   990021 Elegon               41399  Serpent(35)
--
-- creature_template cloned from 2850 (Broken Tooth) so all NOT NULL/defaulted
-- columns are inherited; only identity/family/tameable flags overridden.
-- type_flags: 1 = TAMEABLE, 65537 = TAMEABLE | TAMEABLE_EXOTIC.
-- ============================================================================

-- --- creature_template (clone donor 2850, override identity) -----------------
DROP TEMPORARY TABLE IF EXISTS `_bm_clone`;
CREATE TEMPORARY TABLE `_bm_clone` LIKE `creature_template`;
INSERT INTO `_bm_clone` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` BETWEEN 990010 AND 990021;

UPDATE `_bm_clone` SET `entry`=990010, `name`='Horridon',             `subname`='Beastmaster', `family`=56, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990011, `name`='Fenryr',               `subname`='Beastmaster', `family`=1,  `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990012, `name`='Lightning Paw',        `subname`='Beastmaster', `family`=50, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990013, `name`='Cragmaw the Infested', `subname`='Beastmaster', `family`=60, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990014, `name`='Sabertron',            `subname`='Beastmaster', `family`=58, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990015, `name`='Grey Juggernaut',      `subname`='Beastmaster', `family`=58, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990016, `name`='K.U.-J.0.',            `subname`='Beastmaster', `family`=58, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990017, `name`='Andira',               `subname`='Beastmaster', `family`=57, `type`=1, `type_flags`=65537; INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990018, `name`='Portent',              `subname`='Beastmaster', `family`=59, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990019, `name`='Madexx',               `subname`='Beastmaster', `family`=20, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990020, `name`='Deth''tilac',          `subname`='Beastmaster', `family`=3,  `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry`=990021, `name`='Elegon',               `subname`='Beastmaster', `family`=35, `type`=1, `type_flags`=1;     INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
DROP TEMPORARY TABLE `_bm_clone`;

-- --- creature_template_model (this fork stores the display link here) ---------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 990010 AND 990021;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990010, 0, 47325, 1, 1, 0),
    (990011, 0, 64466, 1, 1, 0),
    (990012, 0, 74736, 1, 1, 0),
    (990013, 0, 78855, 1, 1, 0),
    (990014, 0, 86224, 1, 1, 0),
    (990015, 0, 70231, 1, 1, 0),
    (990016, 0, 90775, 1, 1, 0),
    (990017, 0, 93463, 1, 1, 0),
    (990018, 0, 45427, 1, 1, 0),
    (990019, 0, 37360, 1, 1, 0),
    (990020, 0, 38424, 1, 1, 0),
    (990021, 0, 41399, 1, 1, 0);

-- --- creature_model_info (bounding/reach for the new displays) ----------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN
    (37360,38424,41399,45427,47325,64466,70231,74736,78855,86224,90775,93463);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
    (37360,0.6111,2.0313,2,0,0),(38424,0.6111,2.0313,2,0,0),(41399,0.6111,2.0313,2,0,0),
    (45427,0.6111,2.0313,2,0,0),(47325,0.6111,2.0313,2,0,0),(64466,0.6111,2.0313,2,0,0),
    (70231,0.6111,2.0313,2,0,0),(74736,0.6111,2.0313,2,0,0),(78855,0.6111,2.0313,2,0,0),
    (86224,0.6111,2.0313,2,0,0),(90775,0.6111,2.0313,2,0,0),(93463,0.6111,2.0313,2,0,0);

-- --- Beastmaster roster rows (appear in the DC-Collection catalog) ------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` BETWEEN 990010 AND 990021;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990010, 'Direhorn',    4, 'Throne of Thunder',        2010, 1),
    (990011, 'Wolf',        4, 'Halls of Valor (Legion)',  2011, 1),
    (990012, 'Fox',         4, 'Duskwood (spirit fox)',    2012, 1),
    (990013, 'Blood Beast', 4, 'Nazmir (BfA)',             2013, 1),
    (990014, 'Mechanical',  4, 'Stormsong Valley (BfA)',   2014, 1),
    (990015, 'Mechanical',  4, 'Siege of Orgrimmar',       2015, 1),
    (990016, 'Mechanical',  4, 'Mechagon',                 2016, 1),
    (990017, 'Feathermane', 5, 'Legion (exotic)',          2017, 1),
    (990018, 'Quilen',      4, 'Vale of Eternal Blossoms', 2018, 1),
    (990019, 'Scorpid',     4, 'Uldum',                    2019, 1),
    (990020, 'Spider',      5, 'Molten Front (Firelands)', 2020, 1),
    (990021, 'Serpent',     5, 'Mogu''shan Vaults',        2021, 1);
