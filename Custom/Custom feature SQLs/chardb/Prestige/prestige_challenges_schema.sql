-- DarkChaos-255 Prestige Challenges Schema
-- Tracks optional hard mode challenges for prestige levels

-- Challenge progress tracking
CREATE TABLE IF NOT EXISTS `dc_prestige_challenges` (
  `guid` INT(10) UNSIGNED NOT NULL COMMENT 'Character GUID',
  `prestige_level` TINYINT(3) UNSIGNED NOT NULL COMMENT 'Prestige level when challenge started',
  `challenge_type` TINYINT(3) UNSIGNED NOT NULL COMMENT '1=Iron, 2=Speed, 3=Solo',
  `active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Is challenge currently active',
  `completed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Was challenge completed successfully',
  `start_time` INT(10) UNSIGNED NOT NULL COMMENT 'Unix timestamp when challenge started',
  `start_playtime` INT(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total played time when challenge started (seconds)',
  `completion_time` INT(10) UNSIGNED DEFAULT NULL COMMENT 'Unix timestamp when challenge completed',
  `death_count` INT(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Deaths during challenge (for Iron)',
  `group_count` INT(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Times grouped during challenge (for Solo)',
  PRIMARY KEY (`guid`, `prestige_level`, `challenge_type`),
  KEY `idx_active` (`guid`, `active`),
  KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige challenge progress';

-- Challenge rewards tracking
CREATE TABLE IF NOT EXISTS `dc_prestige_challenge_rewards` (
  `guid` INT(10) UNSIGNED NOT NULL COMMENT 'Character GUID',
  `challenge_type` TINYINT(3) UNSIGNED NOT NULL COMMENT '1=Iron, 2=Speed, 3=Solo',
  `stat_bonus_percent` TINYINT(3) UNSIGNED NOT NULL DEFAULT 2 COMMENT 'Permanent stat bonus percentage',
  `granted_time` INT(10) UNSIGNED NOT NULL COMMENT 'Unix timestamp when reward granted',
  PRIMARY KEY (`guid`, `challenge_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige challenge rewards';
