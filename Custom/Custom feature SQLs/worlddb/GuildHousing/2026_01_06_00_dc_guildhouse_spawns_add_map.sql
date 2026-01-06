-- Dark Chaos Guild Housing - Spawn presets multi-map migration
-- Adds `map` column and changes uniqueness to (map, entry) so multiple guildhouse locations
-- can have different coordinates for the same spawn entry.

-- Ensure table exists for fresh installs that execute this file standalone
CREATE TABLE IF NOT EXISTS `dc_guild_house_spawns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `map` int(11) NOT NULL DEFAULT '1',
  `entry` int(11) NOT NULL DEFAULT '0',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `comment` varchar(500) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `map_entry` (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Add `map` column if missing
SET @hasTable := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns'
);

SET @hasMap := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' AND COLUMN_NAME = 'map'
);

SET @sql := IF(
  @hasTable = 1 AND @hasMap = 0,
  'ALTER TABLE `dc_guild_house_spawns` ADD COLUMN `map` int(11) NOT NULL DEFAULT \'1\' AFTER `id`',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop old unique index on `entry` if it exists
SET @hasEntryIndex := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' AND INDEX_NAME = 'entry'
);

SET @sql := IF(
  @hasTable = 1 AND @hasEntryIndex > 0,
  'ALTER TABLE `dc_guild_house_spawns` DROP INDEX `entry`',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add composite unique index if missing
SET @hasMapEntryIndex := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' AND INDEX_NAME = 'map_entry'
);

SET @sql := IF(
  @hasTable = 1 AND @hasMapEntryIndex = 0,
  'ALTER TABLE `dc_guild_house_spawns` ADD UNIQUE KEY `map_entry` (`map`,`entry`)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
