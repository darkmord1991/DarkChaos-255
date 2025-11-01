-- =====================================================================
-- DarkChaos-255 Prestige System - Character Database Table
-- =====================================================================
-- Stores prestige history and logs for all characters
-- =====================================================================

DROP TABLE IF EXISTS `dc_character_prestige_log`;
CREATE TABLE `dc_character_prestige_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry ID',
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `prestige_level` TINYINT UNSIGNED NOT NULL COMMENT 'Prestige level achieved',
    `prestige_time` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp when prestige occurred',
    `from_level` TINYINT UNSIGNED NOT NULL COMMENT 'Character level before prestige',
    `kept_gear` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 if kept gear, 0 if removed',
    PRIMARY KEY (`id`),
    KEY `idx_guid` (`guid`),
    KEY `idx_prestige_level` (`prestige_level`),
    KEY `idx_prestige_time` (`prestige_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige history log for all characters';

-- =====================================================================
-- Notes:
-- =====================================================================
-- This table is used by the prestige system in dc_prestige_system.cpp
-- It logs every time a character prestiges for historical tracking
-- =====================================================================
