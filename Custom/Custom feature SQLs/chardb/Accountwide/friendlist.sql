-- DarkChaos account-wide friendlist pool
-- Used by: Progression/Accountwide/dc_accountwide_friendlist.cpp

CREATE TABLE IF NOT EXISTS `dc_account_social_friends` (
  `account_id` INT UNSIGNED NOT NULL,
  `friend_guid` INT UNSIGNED NOT NULL,
  `note` VARCHAR(48) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `friend_guid`),
  KEY `idx_friend_guid` (`friend_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='DarkChaos: Account-wide friendlist entries';
