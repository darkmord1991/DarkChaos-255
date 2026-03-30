-- DarkChaos account-wide reputation pools
-- Used by: Progression/Accountwide/dc_accountwide_reputation.cpp

CREATE TABLE IF NOT EXISTS `dc_account_reputation_pools` (
  `account_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `standing` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `faction_id`),
  KEY `idx_faction` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='DarkChaos: Account-wide reputation pools';
