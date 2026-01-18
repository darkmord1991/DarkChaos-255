-- Dark Chaos: World Boss Schedule (Giant Isles)
-- Adds a simple day-of-week schedule for world bosses.

CREATE TABLE IF NOT EXISTS `dc_world_boss_schedule` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `boss_entry` INT UNSIGNED NOT NULL,
    `day_of_week` TINYINT UNSIGNED NOT NULL, -- 0=Sun, 6=Sat
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_boss_day` (`boss_entry`, `day_of_week`),
    KEY `idx_day` (`day_of_week`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Giant Isles rotation (fallback mirrors current code logic)
INSERT INTO `dc_world_boss_schedule` (`boss_entry`, `day_of_week`, `enabled`) VALUES
(400102, 0, 1), -- Sun: Nalak
(400100, 1, 1), -- Mon: Oondasta
(400101, 2, 1), -- Tue: Thok
(400102, 3, 1), -- Wed: Nalak
(400100, 4, 1), -- Thu: Oondasta
(400101, 5, 1), -- Fri: Thok
(400102, 6, 1)  -- Sat: Nalak
ON DUPLICATE KEY UPDATE `enabled` = VALUES(`enabled`);
