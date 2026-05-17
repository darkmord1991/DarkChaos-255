CREATE TABLE IF NOT EXISTS `dc_addon_client_caps_history` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` int unsigned NOT NULL,
  `addon_name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DC',
  `source` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'core-handshake',
  `version_string` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `capabilities` int unsigned NOT NULL DEFAULT 0,
  `negotiated_caps` int unsigned NOT NULL DEFAULT 0,
  `compatible` tinyint(1) unsigned NOT NULL DEFAULT 0,
  `character_guid` int unsigned NOT NULL DEFAULT 0,
  `character_name` varchar(48) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `seen_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account_recent_cover_v1` (`account_id`, `addon_name`, `seen_at`, `id`),
  KEY `idx_account_character_recent_v1` (`account_id`, `character_guid`, `seen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Recent DC addon capability transitions per account';