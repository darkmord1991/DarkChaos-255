-- DarkChaos map flight licenses: account-wide pool
-- Used by: src/server/scripts/DC/Progression/dc_flight_license.cpp (DC.FlightLicense.AccountWide)
--
-- One row per flight license that any character of the account learned:
--   300610 Kalimdor Flight License  (map 750)
--   300611 Lordaeron Flight License (map 751)
-- Every other character of the account learns it the first time it enters that map.
-- learned_by: characters.guid of the character that learned it first. Playerbots are never stored.

CREATE TABLE IF NOT EXISTS `dc_account_flight_license` (
  `account_id` INT UNSIGNED NOT NULL,
  `spell_id` INT UNSIGNED NOT NULL,
  `learned_by` INT UNSIGNED NOT NULL DEFAULT 0,
  `learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: account-wide map flight licenses';
