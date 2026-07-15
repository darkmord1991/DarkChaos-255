-- ============================================================================
-- DC Beastmaster - secret hunter pets wiring (batch 3)
-- ============================================================================
-- Wires the remaining Cataclysm challenge tames from the Secret Hunter Pets Guide.
-- All models already ship in the DC client; the SetCreatureDisplay native renders
-- them. Client-side companion changes (apply the recompiled DBCs from Custom/DBCs):
--   New CreatureDisplayInfo rows 503410-503414 (added to Custom/CSV DBC):
--     503410 firespider + FireSpider_yellow  (Anthriss)
--     503411 firespider + FireSpider_green   (Kirix)
--     503412 firespider + FireSpider_red     (Skitterflame)
--     503413 firespider + FireSpider_orange  (Solix)
--     503414 stock crab + CrabSkinDarkDiamond (Karkin)
--   Existing displays reused: 503151 (deepseacrab_ghost = Ghostcrawler),
--                             19607  (stock tiger gem     = Skarr).
--
-- creature_template rows are cloned from a clean tameable beast (2850) so every
-- column is inherited; only identity + family + tameable/exotic flags change.
-- Spirit Beasts (Ghostcrawler) are exotic (type_flags 65537).
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS `_bm_clone2`;
CREATE TEMPORARY TABLE `_bm_clone2` LIKE `creature_template`;
INSERT INTO `_bm_clone2` SELECT * FROM `creature_template` WHERE `entry` = 2850;

DELETE FROM `creature_template` WHERE `entry` IN (990030, 990031, 990032, 990033, 990034, 990035, 990036);

UPDATE `_bm_clone2` SET `entry` = 990030, `name` = 'Anthriss',     `subname` = 'Secret Tame', `family` = 3,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990031, `name` = 'Kirix',        `family` = 3,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990032, `name` = 'Skitterflame', `family` = 3,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990033, `name` = 'Solix',        `family` = 3,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990034, `name` = 'Ghostcrawler', `family` = 46, `type` = 1, `type_flags` = 65537;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990035, `name` = 'Karkin',       `family` = 8,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
UPDATE `_bm_clone2` SET `entry` = 990036, `name` = 'Skarr',        `family` = 2,  `type` = 1, `type_flags` = 1;
INSERT INTO `creature_template` SELECT * FROM `_bm_clone2`;
DROP TEMPORARY TABLE `_bm_clone2`;

-- --- display links -----------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (990030, 990031, 990032, 990033, 990034, 990035, 990036);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (990030, 0, 503410, 1, 1, 0),
    (990031, 0, 503411, 1, 1, 0),
    (990032, 0, 503412, 1, 1, 0),
    (990033, 0, 503413, 1, 1, 0),
    (990034, 0, 503151, 1, 1, 0),
    (990035, 0, 503414, 1, 1, 0),
    (990036, 0, 19607,  1, 1, 0);

-- --- creature_model_info for the NEW displays (existing 503151/19607 already have rows)
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (503410, 503411, 503412, 503413, 503414);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
    (503410, 0.6111, 2.0313, 2, 0, 0),
    (503411, 0.6111, 2.0313, 2, 0, 0),
    (503412, 0.6111, 2.0313, 2, 0, 0),
    (503413, 0.6111, 2.0313, 2, 0, 0),
    (503414, 0.6111, 2.0313, 2, 0, 0);

-- --- Beastmaster catalog rows ------------------------------------------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` IN (990030, 990031, 990032, 990033, 990034, 990035, 990036);
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (990030, 'Spider',       3, 'Molten Front (Deth''tilac recolor)', 3020, 1),
    (990031, 'Spider',       3, 'Molten Front (Deth''tilac recolor)', 3021, 1),
    (990032, 'Spider',       3, 'Molten Front (Deth''tilac recolor)', 3022, 1),
    (990033, 'Spider',       3, 'Molten Front (Deth''tilac recolor)', 3023, 1),
    (990034, 'Spirit Beast', 4, 'Vashj''ir - Abyssal Depths',         3024, 1),
    (990035, 'Crab',         3, 'Molten Front (challenge tame)',      3025, 1),
    (990036, 'Cat',          3, 'Molten Front (challenge tame)',      3026, 1);
