CREATE TABLE IF NOT EXISTS `dc_addon_feature_transport_audit` (
  `guid` INT UNSIGNED NOT NULL,
  `account_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `character_name` VARCHAR(12) NOT NULL DEFAULT '',
  `feature_name` VARCHAR(64) NOT NULL,
  `native_observations` INT UNSIGNED NOT NULL DEFAULT 0,
  `addon_observations` INT UNSIGNED NOT NULL DEFAULT 0,
  `unavailable_observations` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_transport` VARCHAR(16) NOT NULL DEFAULT 'addon',
  `last_reason` VARCHAR(64) NOT NULL DEFAULT '',
  `last_capability_source` VARCHAR(32) NOT NULL DEFAULT '',
  `last_client_caps` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_negotiated_caps` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_native_build_fingerprint` VARCHAR(96) NOT NULL DEFAULT '',
  `capability_from_persisted_fallback` TINYINT(1) NOT NULL DEFAULT 0,
  `first_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `feature_name`),
  KEY `idx_dc_feature_transport_feature_seen` (`feature_name`, `last_seen`),
  KEY `idx_dc_feature_transport_account_feature` (`account_id`, `feature_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;