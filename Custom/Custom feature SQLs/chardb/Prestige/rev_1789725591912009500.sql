-- DarkChaos-255 Prestige Talents: reward track claims (one per account and threshold).
CREATE TABLE IF NOT EXISTS `dc_account_prestige_rewards` (
  `account_id` INT UNSIGNED NOT NULL,
  `threshold` SMALLINT UNSIGNED NOT NULL COMMENT 'world.dc_prestige_talent_rewards.threshold',
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character that claimed it (received the mail)',
  `claim_time` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `threshold`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prestige talent reward track claims';
