--
-- DC shapeshift form customization: per-character form appearance picks.
-- One chosen creature display per shapeshift form. Read at login into the
-- Forms addon module cache (dc_addon_forms.cpp); consulted by
-- ObjectMgr::GetModelForShapeshift via the override provider.
--
CREATE TABLE IF NOT EXISTS `dc_character_shapeshift_form` (
    `guid` INT UNSIGNED NOT NULL,
    `form` TINYINT UNSIGNED NOT NULL,
    `model` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`guid`, `form`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
