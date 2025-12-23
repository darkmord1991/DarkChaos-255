-- DB migration helper (safe to re-run)
-- Purpose: fix older DC-Collection schemas that used `entry` instead of `entry_id`.
-- Applies to: World DB

SET @db := DATABASE();

-- ---------------------------------------------------------------------------
-- dc_collection_definitions: entry -> entry_id
-- ---------------------------------------------------------------------------

SET @has_defs := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_definitions'
);

SET @has_entry := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_definitions' AND COLUMN_NAME = 'entry'
);

SET @has_entry_id := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_definitions' AND COLUMN_NAME = 'entry_id'
);

SET @sql := IF(
  @has_defs = 1 AND @has_entry = 1 AND @has_entry_id = 0,
  'ALTER TABLE `dc_collection_definitions` CHANGE COLUMN `entry` `entry_id` INT UNSIGNED NOT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- dc_collection_shop: entry -> entry_id (if present)
-- ---------------------------------------------------------------------------

SET @has_shop := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_shop'
);

SET @has_s_entry := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_shop' AND COLUMN_NAME = 'entry'
);

SET @has_s_entry_id := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_shop' AND COLUMN_NAME = 'entry_id'
);

SET @sql := IF(
  @has_shop = 1 AND @has_s_entry = 1 AND @has_s_entry_id = 0,
  'ALTER TABLE `dc_collection_shop` CHANGE COLUMN `entry` `entry_id` INT UNSIGNED NOT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
