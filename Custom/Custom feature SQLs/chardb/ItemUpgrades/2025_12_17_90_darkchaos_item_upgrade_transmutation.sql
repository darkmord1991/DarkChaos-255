-- DarkChaos: Item Upgrade Transmutation/Synthesis (characters DB) schema
-- Creates tables required by DC ItemUpgrade transmutation + synthesis runtime queries.

-- NOTE: This is placed in pending_db_characters so it is picked up by the standard db update/import pipeline.

DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_cooldowns`;
DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_log`;
DROP TABLE IF EXISTS `dc_player_transmutation_cooldowns`;
DROP TABLE IF EXISTS `dc_item_upgrade_transmutation_sessions`;
DROP TABLE IF EXISTS `dc_tier_conversion_log`;

CREATE TABLE `dc_item_upgrade_synthesis_cooldowns` (
  `player_guid` INT UNSIGNED NOT NULL,
  `recipe_id` INT UNSIGNED NOT NULL,
  `cooldown_end` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`player_guid`, `recipe_id`),
  KEY `idx_cooldown_end` (`cooldown_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `dc_item_upgrade_synthesis_log` (
  `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `recipe_id` INT UNSIGNED NOT NULL,
  `success` TINYINT UNSIGNED NOT NULL,
  `attempt_time` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_recipe_id` (`recipe_id`),
  KEY `idx_attempt_time` (`attempt_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `dc_player_transmutation_cooldowns` (
  `player_guid` INT UNSIGNED NOT NULL,
  `recipe_id` INT UNSIGNED NOT NULL,
  `last_used` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`player_guid`, `recipe_id`),
  KEY `idx_last_used` (`last_used`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `dc_item_upgrade_transmutation_sessions` (
  `session_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `recipe_id` INT UNSIGNED NOT NULL,
  `start_time` INT UNSIGNED NOT NULL,
  `end_time` INT UNSIGNED NOT NULL,
  `success` TINYINT(1) NOT NULL DEFAULT 0,
  `completed` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`session_id`),
  KEY `idx_player_completed_end` (`player_guid`, `completed`, `end_time`),
  KEY `idx_recipe_id` (`recipe_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `dc_tier_conversion_log` (
  `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED NOT NULL,
  `from_tier` TINYINT UNSIGNED NOT NULL,
  `to_tier` TINYINT UNSIGNED NOT NULL,
  `upgrade_level` TINYINT UNSIGNED NOT NULL,
  `success` TINYINT(1) NOT NULL,
  `cost_essence` INT UNSIGNED NOT NULL DEFAULT 0,
  `cost_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
  `timestamp` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
