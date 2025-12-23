-- DB migration helper (safe to re-run)
-- Purpose: fix older DC-Collection schemas that used `entry` instead of `entry_id`.
-- Applies to: Character DB

-- ---------------------------------------------------------------------------
-- dc_collection_items: entry -> entry_id
-- ---------------------------------------------------------------------------

SET @db := DATABASE();

SET @has_items := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_items'
);

SET @has_entry := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_items' AND COLUMN_NAME = 'entry'
);

SET @has_entry_id := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_items' AND COLUMN_NAME = 'entry_id'
);

SET @sql := IF(
  @has_items = 1 AND @has_entry = 1 AND @has_entry_id = 0,
  'ALTER TABLE `dc_collection_items` CHANGE COLUMN `entry` `entry_id` INT UNSIGNED NOT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- dc_collection_wishlist: entry -> entry_id
-- ---------------------------------------------------------------------------

SET @has_wishlist := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_wishlist'
);

SET @has_w_entry := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_wishlist' AND COLUMN_NAME = 'entry'
);

SET @has_w_entry_id := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'dc_collection_wishlist' AND COLUMN_NAME = 'entry_id'
);

SET @sql := IF(
  @has_wishlist = 1 AND @has_w_entry = 1 AND @has_w_entry_id = 0,
  'ALTER TABLE `dc_collection_wishlist` CHANGE COLUMN `entry` `entry_id` INT UNSIGNED NOT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
