-- DarkChaos Hotspots System - Active Hotspots Table
-- 
-- This table stores currently active hotspots for persistence across server restarts.
-- Hotspots are automatically loaded on server startup and saved when spawned/despawned.

DROP TABLE IF EXISTS `dc_hotspots_active`;

CREATE TABLE `dc_hotspots_active` (
    `id` INT UNSIGNED NOT NULL COMMENT 'Unique hotspot ID',
    `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Map ID where hotspot is located',
    `zone_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Zone ID where hotspot is located',
    `x` FLOAT NOT NULL COMMENT 'World X coordinate',
    `y` FLOAT NOT NULL COMMENT 'World Y coordinate',
    `z` FLOAT NOT NULL COMMENT 'World Z coordinate',
    `spawn_time` BIGINT NOT NULL COMMENT 'Unix timestamp when hotspot was spawned',
    `expire_time` BIGINT NOT NULL COMMENT 'Unix timestamp when hotspot expires',
    `gameobject_guid` BIGINT DEFAULT NULL COMMENT 'GUID of the visual marker GameObject (if spawned)',
    PRIMARY KEY (`id`),
    INDEX `idx_map_zone` (`map_id`, `zone_id`),
    INDEX `idx_expire` (`expire_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Active hotspots for XP bonus system';
