-- ============================================================================
-- DC Beastmaster - secret hunter pets wiring (batch 6: Legion/WoD/BfA/MoP downports)
-- ============================================================================
-- Sixteen secret tames whose models did NOT already ship in the DC client. Models
-- were extracted from retail, baked v272->v264 (wxl-baker) and packed into
-- patch-secretpets.MPQ. New DBC rows (apply the recompiled Custom/DBCs):
--
--   CreatureModelData 502700-502715 -> the baked M2 per pet
--   CreatureDisplayInfo 503500-503515 -> ModelID + TextureVariation skin
--
-- Skins are bound via CreatureDisplayInfo.TextureVariation (native + stock path);
-- the matching BLP for each is packed in patch-secretpets.MPQ. Felbound Wolf uses
-- the fel model's own embedded texture (no TextureVariation).
--
-- family: 46 Spirit Beast (exotic), 58 Mechanical, 21 Turtle, 1 Wolf, 2 Cat,
--         9 Gorilla, 7 Carrion Bird, 5 Boar. Cloned from donor 2850.
-- Exotic Spirit Beasts -> type_flags 65537 (TAMEABLE | TAMEABLE_EXOTIC).
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS `_bm_clone6`;
CREATE TEMPORARY TABLE `_bm_clone6` LIKE `creature_template`;
INSERT INTO `_bm_clone6` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` BETWEEN 990060 AND 990075;

UPDATE `_bm_clone6` SET `entry`=990060, `name`='Gara',                `subname`='Secret Tame', `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990061, `name`='Gon',                 `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990062, `name`='Bulvinkel',           `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990063, `name`='Lowland Manashell',   `family`=21, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990064, `name`='Felbound Wolf',       `family`=1,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990065, `name`='Silver Arachnodrone', `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990066, `name`='Rush',                `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990067, `name`='Mechanical Bunny',    `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990068, `name`='A-Me 02',             `family`=9,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990069, `name`='War-Iron Axebeak',    `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990070, `name`='Savage',              `family`=2,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990071, `name`='Patrannache',         `family`=7,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990072, `name`='Bloodtooth',          `family`=21, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990073, `name`='Stompy',              `family`=5,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990074, `name`='Bristlespine',        `family`=5,  `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
UPDATE `_bm_clone6` SET `entry`=990075, `name`='Rockhide',            `family`=21, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone6`;
DROP TEMPORARY TABLE `_bm_clone6`;

-- --- display links -----------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 990060 AND 990075;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990060, 0, 503500, 1, 1, 0),
    (990061, 0, 503501, 1, 1, 0),
    (990062, 0, 503502, 1, 1, 0),
    (990063, 0, 503503, 1, 1, 0),
    (990064, 0, 503504, 1, 1, 0),
    (990065, 0, 503505, 1, 1, 0),
    (990066, 0, 503506, 1, 1, 0),
    (990067, 0, 503507, 1, 1, 0),
    (990068, 0, 503508, 1, 1, 0),
    (990069, 0, 503509, 1, 1, 0),
    (990070, 0, 503510, 1, 1, 0),
    (990071, 0, 503511, 1, 1, 0),
    (990072, 0, 503512, 1, 1, 0),
    (990073, 0, 503513, 1, 1, 0),
    (990074, 0, 503514, 1, 1, 0),
    (990075, 0, 503515, 1, 1, 0);

-- --- creature_model_info for the new displays (BoundingRadius from baked M2) --
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 503500 AND 503515;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
    (503500, 0.9275, 1.5, 2, 0, 0),
    (503501, 1.552, 1.5, 2, 0, 0),
    (503502, 1.4526, 1.5, 2, 0, 0),
    (503503, 0.9373, 1.5, 2, 0, 0),
    (503504, 0.9275, 1.5, 2, 0, 0),
    (503505, 2.1946, 1.5, 2, 0, 0),
    (503506, 0.9076, 1.5, 2, 0, 0),
    (503507, 0.4519, 1.5, 2, 0, 0),
    (503508, 1.5526, 1.5, 2, 0, 0),
    (503509, 1.7375, 1.5, 2, 0, 0),
    (503510, 1.0045, 1.5, 2, 0, 0),
    (503511, 1.5652, 1.5, 2, 0, 0),
    (503512, 1.0493, 1.5, 2, 0, 0),
    (503513, 1.1366, 1.5, 2, 0, 0),
    (503514, 0.4507, 1.5, 2, 0, 0),
    (503515, 0.3561, 1.5, 2, 0, 0);

-- --- Beastmaster catalog rows ------------------------------------------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` BETWEEN 990060 AND 990075;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990060, 'Spirit Beast', 4, 'Warlords of Draenor - Frostfire Ridge (Gara)',   3060, 1),
    (990061, 'Spirit Beast', 4, 'Warlords of Draenor - Gorgrond (Gon)',           3061, 1),
    (990062, 'Spirit Beast', 4, 'Legion - Highmountain (Bulvinkel)',              3062, 1),
    (990063, 'Turtle',       3, 'Legion - Azsuna (Lowland Manashell)',            3063, 1),
    (990064, 'Wolf',         3, 'Warlords of Draenor - Tanaan (Felbound Wolf)',   3064, 1),
    (990065, 'Mechanical',   3, 'Mechagon (Silver Arachnodrone)',                 3065, 1),
    (990066, 'Mechanical',   3, 'Mechagon (Rush)',                                3066, 1),
    (990067, 'Mechanical',   3, 'Mechagon (Mechanical Bunny)',                    3067, 1),
    (990068, 'Gorilla',      3, 'Un''Goro Crater (A-Me 02)',                      3068, 1),
    (990069, 'Mechanical',   3, 'Mechagon (War-Iron Axebeak)',                    3069, 1),
    (990070, 'Cat',          4, 'Warlords of Draenor - Frostfire (Savage)',       3070, 1),
    (990071, 'Carrion Bird', 3, 'Pandaria - Valley of the Four Winds (Patrannache)', 3071, 1),
    (990072, 'Turtle',       3, 'Warlords of Draenor - Nagrand (Bloodtooth)',     3072, 1),
    (990073, 'Boar',         3, 'Pandaria - Kun-Lai Summit (Stompy)',             3073, 1),
    (990074, 'Boar',         3, 'Legion - Val''sharah (Bristlespine)',            3074, 1),
    (990075, 'Turtle',       3, 'Warlords of Draenor - Gorgrond (Rockhide)',      3075, 1);
