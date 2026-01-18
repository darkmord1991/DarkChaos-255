-- Addon client capabilities tracking (per account)
CREATE TABLE IF NOT EXISTS `dc_addon_client_caps` (
  `account_id` int unsigned NOT NULL,
  `addon_name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DC',
  `version_string` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `capabilities` int unsigned NOT NULL DEFAULT 0,
  `negotiated_caps` int unsigned NOT NULL DEFAULT 0,
  `last_character_guid` int unsigned DEFAULT NULL,
  `last_character_name` varchar(48) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_seen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`,`addon_name`),
  KEY `idx_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Addon client capabilities per account';
