-- ============================================================================
-- DC Beastmaster - secret hunter pets wiring (batch 5: Legion/WoD/BfA existing models)
-- ============================================================================
-- Legion/BfA secret tames whose models already ship in the DC client. Wired to
-- existing displays; native renders them. Skins packed into patch-featherfix.MPQ.
--
--   990050 Lost Spectral Gryphon disp 502497 (spectralgryphon)  Spirit Beast (exotic)
--   990051 Iron Juggernaut       disp 501709 (ironjuggernaut grey) Mechanical
--   990052 Blue Juggernaut       disp 501710 (ironjuggernaut blue) Mechanical
--   990053 Plague Toad           disp 500312 (toadloa)            Turtle (tanky ground pet)
--   990054 N.U.T.Z.              disp 500683 (futurebotpet brass) Mechanical
--
-- family 46 Spirit Beast, 58 Mechanical, 21 Turtle. Cloned from donor 2850.
-- Toads have no WotLK family; mapped to Turtle (gameplay only; renders as the toad).
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS `_bm_clone4`;
CREATE TEMPORARY TABLE `_bm_clone4` LIKE `creature_template`;
INSERT INTO `_bm_clone4` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` BETWEEN 990050 AND 990054;

UPDATE `_bm_clone4` SET `entry`=990050, `name`='Lost Spectral Gryphon', `subname`='Secret Tame', `family`=46, `type`=1, `type_flags`=65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone4`;
UPDATE `_bm_clone4` SET `entry`=990051, `name`='Iron Juggernaut', `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone4`;
UPDATE `_bm_clone4` SET `entry`=990052, `name`='Blue Juggernaut', `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone4`;
UPDATE `_bm_clone4` SET `entry`=990053, `name`='Plague Toad', `family`=21, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone4`;
UPDATE `_bm_clone4` SET `entry`=990054, `name`='N.U.T.Z.', `family`=58, `type`=1, `type_flags`=1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone4`;
DROP TEMPORARY TABLE `_bm_clone4`;

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 990050 AND 990054;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990050, 0, 502497, 1, 1, 0),
    (990051, 0, 501709, 1, 1, 0),
    (990052, 0, 501710, 1, 1, 0),
    (990053, 0, 500312, 1, 1, 0),
    (990054, 0, 500683, 1, 1, 0);

DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` BETWEEN 990050 AND 990054;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990050, 'Spirit Beast', 4, 'Stormwind City (Lost Spectral Gryphon)', 3050, 1),
    (990051, 'Mechanical',   4, 'Siege of Orgrimmar (Iron Juggernaut)',   3051, 1),
    (990052, 'Mechanical',   3, 'Siege of Orgrimmar (Blue Juggernaut)',   3052, 1),
    (990053, 'Turtle',       3, 'Temple of Sethraliss (Plague Toad)',     3053, 1),
    (990054, 'Mechanical',   3, 'Mechanical (N.U.T.Z.)',                  3054, 1);
