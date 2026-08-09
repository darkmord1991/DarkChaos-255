-- =====================================================================
-- DarkChaos Hotspots - move runtime state from acore_world to acore_chars
-- =====================================================================
-- RUN AGAINST: acore_chars   (your CharacterDatabaseInfo database)
--
-- Why: both tables are written by the worldserver at runtime and are
-- per-realm. acore_world is read-mostly and gets rebuilt from its SQL, which
-- silently wipes them. The C++ side now uses CharacterDatabase prepared
-- statements (CHAR_SEL/REP/DEL/INS_DC_HOTSPOT*) against these tables.
--
-- Safe to re-run: the tables are recreated empty and the carry-over step is
-- guarded on the source table actually existing, so a second run just
-- re-imports whatever the world DB still holds (or nothing).
--
-- Neither table holds anything precious: the spawn-point pool re-discovers
-- itself within minutes and active hotspots expire inside Hotspots.Duration.
-- If the carry-over is awkward for you, delete the two guarded blocks at the
-- bottom and just take the empty tables.
-- =====================================================================

DROP TABLE IF EXISTS `dc_hotspots_active`;
CREATE TABLE `dc_hotspots_active` (
    `id` INT UNSIGNED NOT NULL COMMENT 'Unique hotspot ID',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID where hotspot is located',
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Resolved level-band zone ID (see ZONE_BANDS in HotspotMgr.cpp)',
    `x` FLOAT NOT NULL DEFAULT 0 COMMENT 'X coordinate',
    `y` FLOAT NOT NULL DEFAULT 0 COMMENT 'Y coordinate',
    `z` FLOAT NOT NULL DEFAULT 0 COMMENT 'Z coordinate',
    `spawn_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot was spawned',
    `expire_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot expires',
    `gameobject_guid` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Marker GO GUID (0 if none); always reset on load, markers are recreated lazily',
    PRIMARY KEY (`id`),
    KEY `idx_expire_time` (`expire_time`),
    KEY `idx_map_zone` (`map_id`, `zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos Hotspots - active hotspots (crash persistence)';

DROP TABLE IF EXISTS `dc_hotspot_spawn_points`;
CREATE TABLE `dc_hotspot_spawn_points` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID',
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Zone ID at discovery time; re-resolved to the level band on load',
    `x` FLOAT NOT NULL DEFAULT 0 COMMENT 'X coordinate (validated ground)',
    `y` FLOAT NOT NULL DEFAULT 0 COMMENT 'Y coordinate (validated ground)',
    `z` FLOAT NOT NULL DEFAULT 0 COMMENT 'Z coordinate (validated ground height)',
    `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Set 0 to retire a point without deleting it',
    PRIMARY KEY (`id`),
    KEY `idx_map_zone` (`map_id`, `zone_id`),
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos Hotspots - pre-validated spawn point pool';

-- ---------------------------------------------------------------------
-- Carry over the old world-DB rows, but only if those tables still exist.
-- A bare cross-DB INSERT ... SELECT would ERROR (not no-op) on a server that
-- has already had 02_drop_moved_tables.sql applied, and mysql keeps going
-- after an error - leaving you unsure whether anything ran.
-- Adjust 'acore_world' below if your WorldDatabaseInfo names it differently.
-- ---------------------------------------------------------------------

SET @src_db := 'acore_world';

SET @has_active := (SELECT COUNT(*) FROM `information_schema`.`TABLES`
    WHERE `TABLE_SCHEMA` = @src_db AND `TABLE_NAME` = 'dc_hotspots_active');
SET @sql := IF(@has_active > 0,
    CONCAT('INSERT INTO `dc_hotspots_active` (`id`,`map_id`,`zone_id`,`x`,`y`,`z`,`spawn_time`,`expire_time`,`gameobject_guid`) ',
           'SELECT `id`,`map_id`,`zone_id`,`x`,`y`,`z`,`spawn_time`,`expire_time`,0 FROM `', @src_db, '`.`dc_hotspots_active` ',
           'WHERE `expire_time` > UNIX_TIMESTAMP()'),
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_points := (SELECT COUNT(*) FROM `information_schema`.`TABLES`
    WHERE `TABLE_SCHEMA` = @src_db AND `TABLE_NAME` = 'dc_hotspot_spawn_points');
SET @sql := IF(@has_points > 0,
    CONCAT('INSERT INTO `dc_hotspot_spawn_points` (`map_id`,`zone_id`,`x`,`y`,`z`,`enabled`) ',
           'SELECT `map_id`,`zone_id`,`x`,`y`,`z`,`enabled` FROM `', @src_db, '`.`dc_hotspot_spawn_points`'),
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT (SELECT COUNT(*) FROM `dc_hotspots_active`) AS `active_hotspots_carried`,
       (SELECT COUNT(*) FROM `dc_hotspot_spawn_points`) AS `spawn_points_carried`;
