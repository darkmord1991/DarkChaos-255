-- DC-Collection shop pricing for custom/retroported mount vendor mounts
-- Vendor: 3461020 (Skeletal Stablemaster)
-- Mount spells covered: 300700-300707, 300720-300734
-- Price per mount: 500 Upgrade Tokens + 500 Artifact Essence
--
-- This migration is idempotent:
-- 1) Removes existing shop rows for these mount spells.
-- 2) Re-inserts them with fixed pricing.
--
-- Schema compatibility:
-- - Supports both `dc_collection_shop.entry_id` (current) and legacy `dc_collection_shop.entry`.

SET @db := DATABASE();

SET @has_shop := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = @db
      AND TABLE_NAME = 'dc_collection_shop'
);

SET @has_shop_entry_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db
      AND TABLE_NAME = 'dc_collection_shop'
      AND COLUMN_NAME = 'entry_id'
);

SET @has_shop_entry := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db
      AND TABLE_NAME = 'dc_collection_shop'
      AND COLUMN_NAME = 'entry'
);

SET @shop_entry_col := IF(
    @has_shop_entry_id = 1,
    'entry_id',
    IF(@has_shop_entry = 1, 'entry', NULL)
);

-- Remove existing rows for these custom mount spells first.
SET @sql := IF(
    @has_shop = 1 AND @shop_entry_col IS NOT NULL,
    CONCAT(
        'DELETE FROM `dc_collection_shop` ',
        'WHERE `collection_type` = 1 AND `', @shop_entry_col, '` IN (',
        '300700,300701,300702,300703,300704,300705,300706,300707,',
        '300720,300721,300722,300723,300724,300725,300726,',
        '300727,300728,300729,300730,300731,300732,300733,300734',
        ')'
    ),
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Insert fixed-price shop rows for all custom mount vendor mounts.
SET @sql := IF(
    @has_shop = 1 AND @shop_entry_col IS NOT NULL,
    CONCAT(
        'INSERT INTO `dc_collection_shop` ',
        '(`collection_type`,`', @shop_entry_col, '`,`price_tokens`,`price_emblems`,`featured`,`enabled`) VALUES ',
        '(1,300700,500,500,0,1),',
        '(1,300701,500,500,0,1),',
        '(1,300702,500,500,0,1),',
        '(1,300703,500,500,0,1),',
        '(1,300704,500,500,0,1),',
        '(1,300705,500,500,0,1),',
        '(1,300706,500,500,0,1),',
        '(1,300707,500,500,0,1),',
        '(1,300720,500,500,0,1),',
        '(1,300721,500,500,0,1),',
        '(1,300722,500,500,0,1),',
        '(1,300723,500,500,0,1),',
        '(1,300724,500,500,0,1),',
        '(1,300725,500,500,0,1),',
        '(1,300726,500,500,0,1),',
        '(1,300727,500,500,0,1),',
        '(1,300728,500,500,0,1),',
        '(1,300729,500,500,0,1),',
        '(1,300730,500,500,0,1),',
        '(1,300731,500,500,0,1),',
        '(1,300732,500,500,0,1),',
        '(1,300733,500,500,0,1),',
        '(1,300734,500,500,0,1)'
    ),
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
