-- ============================================================================
-- DC Beastmaster - retail model downport (STAGING batch 1)
-- ============================================================================
-- 4 current-retail beast models downported via the wow.export -> casc-extract ->
-- wxl-baker pipeline (2026-07-14) and wired as adoptable Beastmaster pets. The
-- client assets ship in the separate test patch  patch-beasts-test.MPQ  (baked
-- M2 + skins + patched CreatureDisplayInfo.dbc / CreatureModelData.dbc rows
-- 502610/502611/502612/502617 and display ids 70574/71536/90230/108129).
--
-- These are GENERIC retail beasts (not the famous named pets, which need visual
-- selection in the wow.export creature browser). This is a staging/proof batch:
-- verify each renders in the DC-Collection Beastmaster preview before promoting
-- the DBC rows to the live patch chain.
--
--   990001 Stormfang  <- creature\lightningworg (retail display 70574) Wolf
--   990002 Emberfang  <- creature\saber2        (retail display 71536) Cat
--   990003 Duskwing   <- creature\owl2          (retail display 90230) Bird of Prey
--   990004 Ironhorn   <- creature\rhinoprimal   (retail display 108129) Rhino (exotic)
--
-- creature_template rows are cloned from a known-clean tameable beast (2850,
-- Broken Tooth) so every NOT NULL / defaulted column is inherited; only the
-- identity + family + tameable flags are overridden. type_flags: 1 = TAMEABLE,
-- 65537 = TAMEABLE | TAMEABLE_EXOTIC (Ironhorn -> requires Beast Mastery).
-- ============================================================================

-- --- creature_template (clone donor, override identity) ----------------------
DROP TEMPORARY TABLE IF EXISTS `_bm_clone`;
CREATE TEMPORARY TABLE `_bm_clone` LIKE `creature_template`;
INSERT INTO `_bm_clone` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` IN (990001, 990002, 990003, 990004);

UPDATE `_bm_clone` SET `entry` = 990001, `name` = 'Stormfang', `subname` = 'Beastmaster', `family` = 1,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry` = 990002, `name` = 'Emberfang', `family` = 2,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry` = 990003, `name` = 'Duskwing',  `family` = 26, `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
UPDATE `_bm_clone` SET `entry` = 990004, `name` = 'Ironhorn',  `family` = 43, `type` = 1, `type_flags` = 65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone`;
DROP TEMPORARY TABLE `_bm_clone`;

-- --- creature_template_model (display link; this fork holds display here) -----
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (990001, 990002, 990003, 990004);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990001, 0, 70574,  1, 1, 0),
    (990002, 0, 71536,  1, 1, 0),
    (990003, 0, 90230,  1, 1, 0),
    (990004, 0, 108129, 1, 1, 0);

-- --- creature_model_info (bounding/reach for the new displays) ----------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (70574, 71536, 90230, 108129);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
    (70574,  0.6111, 2.0313, 2, 0, 0),
    (71536,  0.6111, 2.0313, 2, 0, 0),
    (90230,  0.6111, 2.0313, 2, 0, 0),
    (108129, 0.6111, 2.0313, 2, 0, 0);

-- --- Beastmaster roster rows (appear in the DC-Collection catalog) ------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` IN (990001, 990002, 990003, 990004);
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990001, 'Wolf',         3, 'Retail downport (staging)', 2000, 1),
    (990002, 'Cat',          3, 'Retail downport (staging)', 2001, 1),
    (990003, 'Bird of Prey', 3, 'Retail downport (staging)', 2002, 1),
    (990004, 'Rhino',        4, 'Retail downport (staging)', 2003, 1);
