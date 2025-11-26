-- DarkChaos Hotspots System - Database Persistence Table
-- This table stores active hotspots to survive server crashes/restarts

DROP TABLE IF EXISTS `dc_hotspots_active`;
CREATE TABLE `dc_hotspots_active` (
    `id` INT UNSIGNED NOT NULL COMMENT 'Unique hotspot ID',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID where hotspot is located',
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Zone ID where hotspot is located',
    `x` FLOAT NOT NULL DEFAULT 0 COMMENT 'X coordinate',
    `y` FLOAT NOT NULL DEFAULT 0 COMMENT 'Y coordinate', 
    `z` FLOAT NOT NULL DEFAULT 0 COMMENT 'Z coordinate',
    `spawn_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot was spawned',
    `expire_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot expires',
    `gameobject_guid` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'GUID of visual marker GameObject (0 if none)',
    PRIMARY KEY (`id`),
    KEY `idx_expire_time` (`expire_time`),
    KEY `idx_map_zone` (`map_id`, `zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos Hotspots - Active hotspots for crash persistence';
