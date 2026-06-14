--
-- DC shapeshift form customization: standard skin catalog
-- Catalog of selectable creature displays per (form, race) for the Forms
-- wardrobe tab. Models here already exist in the 3.3.5a client (same display
-- ids used by player_shapeshift_model). Color variants share one .mdx model
-- and differ only by texture variation, so no client patch is required:
--   Night Elf cat  -> Creature\DRUIDCAT\DruidCat.mdx          (DruidCatSkin*)
--   Tauren cat     -> Creature\DruidCatTauren\DruidCatTauren.mdx (DruidCatTaurenSkin*)
--   Night Elf bear -> Creature\DruidBear\DruidBear.mdx         (DruidBearSkin*)
--   Tauren bear    -> Creature\DruidBear\DruidBearTauren.mdx   (DruidTaurenBearSkin*)
--
CREATE TABLE IF NOT EXISTS `dc_shapeshift_form_skins` (
    `form` TINYINT UNSIGNED NOT NULL,
    `race` TINYINT UNSIGNED NOT NULL,
    `model` INT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL DEFAULT '',
    `sort_order` INT NOT NULL DEFAULT 0,
    `is_default` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`form`, `race`, `model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ShapeshiftID: 1=Cat 5=Bear 8=Dire Bear. RaceID: 4=Night Elf 6=Tauren.
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` IN (1, 5, 8) AND `race` IN (4, 6);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
-- Night Elf cat
(1, 4, 892,   'Black (Classic)', 0, 1),
(1, 4, 29406, 'Purple',          1, 0),
(1, 4, 29405, 'Violet',          2, 0),
(1, 4, 29407, 'Dark Blue',       3, 0),
(1, 4, 29408, 'White',           4, 0),
-- Night Elf bear
(5, 4, 2281,  'Red (Classic)',   0, 1),
(5, 4, 29414, 'Black',           1, 0),
(5, 4, 29413, 'Purple',          2, 0),
(5, 4, 29415, 'Blue',            3, 0),
(5, 4, 29416, 'White',           4, 0),
(5, 4, 29417, 'Red',             5, 0),
-- Night Elf dire bear (same model set as bear)
(8, 4, 2281,  'Red (Classic)',   0, 1),
(8, 4, 29414, 'Black',           1, 0),
(8, 4, 29413, 'Purple',          2, 0),
(8, 4, 29415, 'Blue',            3, 0),
(8, 4, 29416, 'White',           4, 0),
(8, 4, 29417, 'Red',             5, 0),
-- Tauren cat
(1, 6, 8571,  'Brown (Classic)', 0, 1),
(1, 6, 29412, 'Black',           1, 0),
(1, 6, 29411, 'Red',             2, 0),
(1, 6, 29410, 'Yellow',          3, 0),
(1, 6, 29409, 'White',           4, 0),
-- Tauren bear
(5, 6, 2289,  'Brown (Classic)', 0, 1),
(5, 6, 29418, 'Black',           1, 0),
(5, 6, 29419, 'Silver',          2, 0),
(5, 6, 29420, 'Yellow',          3, 0),
(5, 6, 29421, 'White',           4, 0),
-- Tauren dire bear (same model set as bear)
(8, 6, 2289,  'Brown (Classic)', 0, 1),
(8, 6, 29418, 'Black',           1, 0),
(8, 6, 29419, 'Silver',          2, 0),
(8, 6, 29420, 'Yellow',          3, 0),
(8, 6, 29421, 'White',           4, 0);
