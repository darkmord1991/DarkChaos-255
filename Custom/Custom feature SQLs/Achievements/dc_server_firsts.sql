-- =====================================================
-- DarkChaos-255 Server First Tracking
-- =====================================================

CREATE TABLE IF NOT EXISTS `dc_server_firsts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(100) NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `player_name` VARCHAR(12) NOT NULL,
    `achievement_time` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
