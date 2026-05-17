-- DarkChaos QoS: Player Settings Table
-- Database: acore_chars
-- Stores persistent player-specific settings for the QoS module

CREATE TABLE IF NOT EXISTS `dc_player_qos_settings` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `setting_key` VARCHAR(64) NOT NULL COMMENT 'Setting identifier (e.g. "Tooltips.ShowItemLevel")',
    `setting_value` VARCHAR(255) NOT NULL COMMENT 'Setting value (stored as string)',
    PRIMARY KEY (`guid`, `setting_key`),
    INDEX `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Persistent player settings for DarkChaos QoS module';
