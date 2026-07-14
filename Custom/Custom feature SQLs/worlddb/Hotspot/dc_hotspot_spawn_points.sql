-- DarkChaos Hotspots System - Pre-validated Spawn Point Pool
-- Caches terrain-validated (map, zone, x, y, z) positions so the runtime never
-- has to random-sample + probe cold terrain on the world thread. The server
-- discovers points lazily (throttled, bounded disk I/O) and persists them here;
-- on restart the pool is reloaded instantly and discovery rarely runs again.

DROP TABLE IF EXISTS `dc_hotspot_spawn_points`;
CREATE TABLE `dc_hotspot_spawn_points` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID',
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Zone ID at this point',
    `x` FLOAT NOT NULL DEFAULT 0 COMMENT 'X coordinate (validated ground)',
    `y` FLOAT NOT NULL DEFAULT 0 COMMENT 'Y coordinate (validated ground)',
    `z` FLOAT NOT NULL DEFAULT 0 COMMENT 'Z coordinate (validated ground height)',
    `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Set 0 to retire a point without deleting it',
    PRIMARY KEY (`id`),
    KEY `idx_map_zone` (`map_id`, `zone_id`),
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos Hotspots - Pre-validated spawn point pool';
