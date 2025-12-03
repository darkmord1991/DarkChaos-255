-- DarkChaos-255 Account-Wide Prestige Tracking
-- This table aggregates prestige data at the account level for account-wide bonuses
-- Used by dc_firststart.cpp to apply prestige bonuses to new characters

CREATE TABLE IF NOT EXISTS `dc_prestige_players` (
  `account_id` INT(10) UNSIGNED NOT NULL COMMENT 'Account ID from account table',
  `prestige_level` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Highest prestige level achieved on this account',
  `total_prestiges` INT(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of prestiges across all characters',
  `xp_bonus_percent` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account-wide XP bonus percentage',
  `gold_bonus_percent` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account-wide gold find bonus percentage',
  `reputation_bonus_percent` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account-wide reputation bonus percentage',
  `last_updated` INT(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp of last update',
  PRIMARY KEY (`account_id`),
  KEY `idx_prestige_level` (`prestige_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos: Account-wide prestige tracking for cross-character bonuses';

-- View to automatically update account prestige from character prestige
-- This is helpful for syncing account prestige when a character prestiges
-- Usage: Run manually or via trigger after dc_character_prestige updates

-- Populate from existing character data (run once after table creation)
-- INSERT INTO dc_prestige_players (account_id, prestige_level, total_prestiges, last_updated)
-- SELECT 
--     a.id AS account_id,
--     COALESCE(MAX(p.prestige_level), 0) AS prestige_level,
--     COALESCE(SUM(p.total_prestiges), 0) AS total_prestiges,
--     UNIX_TIMESTAMP() AS last_updated
-- FROM account a
-- LEFT JOIN characters c ON c.account = a.id
-- LEFT JOIN dc_character_prestige p ON p.guid = c.guid
-- GROUP BY a.id
-- ON DUPLICATE KEY UPDATE
--     prestige_level = VALUES(prestige_level),
--     total_prestiges = VALUES(total_prestiges),
--     last_updated = VALUES(last_updated);
