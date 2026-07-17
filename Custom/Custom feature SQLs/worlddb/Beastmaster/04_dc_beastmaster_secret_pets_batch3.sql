-- ============================================================================
-- DC Beastmaster - secret hunter pets wiring (batch 4: existing-model pets)
-- ============================================================================
-- Pets from the Secret Hunter Pets Guide whose MODELS already ship in the DC
-- client (Feathermanes / Mechanicals / spectral porcupines from prior downports).
-- Wired to existing CreatureDisplayInfo rows; the SetCreatureDisplay native
-- renders them. NOTE: a few of these displays may still need their TextureVariation
-- skin BLPs packed (same class as the Andira/wingedlion2 green fix,
-- patch-featherfix.MPQ) -- run the skin audit if any render green.
--
--   990040 Whirlwing   disp 502051 (hippogryph2 azsuna)   Feathermane (exotic)
--   990041 Mavarnir    disp 502052 (hippogryph2 valshara) Feathermane (exotic)
--   990042 Netherbeak  disp 502387 (felhippogryph)        Feathermane (exotic)
--   990043 Lalathin    disp 500717 (wingedlion2pet dark)  Feathermane (exotic)
--   990044 Sabertron          disp 86224  (mechanicaltiger red)     Mechanical
--   990045 Haywire Battle-Chicken disp 502655 (mechanicalchicken)   Mechanical
--   990046 Degu   disp 502878 (spectral porcupine red)   Spirit Beast (exotic)
--   990047 Gumi   disp 502877 (spectral porcupine)       Spirit Beast (exotic)
--   990048 Hutia  disp 502876 (spectral porcupine green) Spirit Beast (exotic)
--
-- family 50 = Feathermane, 58 = Mechanical, 46 = Spirit Beast (all scale-bumped
-- retail families where applicable). Cloned from donor 2850.
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS `_bm_clone3`;
CREATE TEMPORARY TABLE `_bm_clone3` LIKE `creature_template`;
INSERT INTO `_bm_clone3` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` BETWEEN 990040 AND 990048;

UPDATE `_bm_clone3` SET `entry`=990040, `name`='Whirlwing',  `subname`='Secret Tame', `family`=50, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990041, `name`='Mavarnir',   `family`=50, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990042, `name`='Netherbeak', `family`=50, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990043, `name`='Lalathin',   `family`=50, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990044, `name`='Sabertron',  `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990045, `name`='Haywire Battle-Chicken', `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990046, `name`='Degu',  `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990047, `name`='Gumi',  `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
UPDATE `_bm_clone3` SET `entry`=990048, `name`='Hutia', `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone3`;
DROP TEMPORARY TABLE `_bm_clone3`;

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 990040 AND 990048;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990040, 0, 502051, 1, 1, 0),
    (990041, 0, 502052, 1, 1, 0),
    (990042, 0, 502387, 1, 1, 0),
    (990043, 0, 500717, 1, 1, 0),
    (990044, 0, 86224,  1, 1, 0),
    (990045, 0, 502655, 1, 1, 0),
    (990046, 0, 502878, 1, 1, 0),
    (990047, 0, 502877, 1, 1, 0),
    (990048, 0, 502876, 1, 1, 0);

DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` BETWEEN 990040 AND 990048;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990040, 'Feathermane',  4, 'Legion (Feathermane)',            3040, 1),
    (990041, 'Feathermane',  4, 'Legion (Feathermane)',            3041, 1),
    (990042, 'Feathermane',  4, 'Legion (Feathermane)',            3042, 1),
    (990043, 'Feathermane',  4, 'Suramar - Nighthold (Feathermane)', 3043, 1),
    (990044, 'Mechanical',   3, 'Stormsong Valley (Sabertron)',    3044, 1),
    (990045, 'Mechanical',   3, 'Mechanical (Haywire Battle-Chicken)', 3045, 1),
    (990046, 'Spirit Beast', 4, 'Valley of the Four Winds (Degu)', 3046, 1),
    (990047, 'Spirit Beast', 4, 'Degu recolor (Gumi)',             3047, 1),
    (990048, 'Spirit Beast', 4, 'Degu recolor (Hutia)',            3048, 1);
