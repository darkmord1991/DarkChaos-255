-- Path of Chaos: per-account task progress and the Shop Points balance.
--
-- Both tables are keyed by account, not by character. Shop Points buy account-wide collectibles,
-- so a task pays once per account; a per-character book would pay again on every alt.
-- The rows only ever move forward: progress rises, completed_at and claimed_at are set once.

CREATE TABLE IF NOT EXISTS `dc_path_progress` (
  `account_id` INT UNSIGNED NOT NULL,
  `task_id` SMALLINT UNSIGNED NOT NULL COMMENT 'dc_path_tasks.id (world database)',
  `progress` INT UNSIGNED NOT NULL DEFAULT 0,
  `completed_at` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix time, 0 = not completed',
  `claimed_at` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix time, 0 = reward not collected',
  `claimed_guid` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Character that collected the reward',
  PRIMARY KEY (`account_id`, `task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Path of Chaos progress per account';

CREATE TABLE IF NOT EXISTS `dc_path_points` (
  `account_id` INT UNSIGNED NOT NULL,
  `balance` INT UNSIGNED NOT NULL DEFAULT 0,
  `lifetime_earned` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Shop Points per account';

-- The Collection shop takes Shop Points as an alternative to tokens and essence. A row with
-- price_points = 0 cannot be bought with them; a row priced only in points cannot be bought
-- any other way.
SET @has_col := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_collection_shop' AND `COLUMN_NAME` = 'price_points');
SET @stmt := IF(@has_col = 0,
  'ALTER TABLE `dc_collection_shop` ADD COLUMN `price_points` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `price_emblems`',
  'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_col := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_collection_shop_purchases' AND `COLUMN_NAME` = 'cost_points');
SET @stmt := IF(@has_col = 0,
  'ALTER TABLE `dc_collection_shop_purchases` ADD COLUMN `cost_points` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `cost_emblems`',
  'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Every mount on sale today can also be bought with points.
UPDATE `dc_collection_shop` SET `price_points` = 1500 WHERE `collection_type` = 1 AND `price_points` = 0;
