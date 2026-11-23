-- DarkChaos account-wide flight paths
-- Used by: src/server/scripts/DC/Progression/Accountwide/dc_accountwide_taxi.cpp
--
-- One row per taxi node that any character of the account discovered, kept per
-- team so Horde and Alliance networks never mix. Nodes a character gets for free
-- (racial capitals, the Death Knight's old-world network) are not stored.
--
-- team: 0 = Alliance, 1 = Horde (TeamId).

CREATE TABLE IF NOT EXISTS `dc_account_taxi_nodes` (
  `account_id` INT UNSIGNED NOT NULL,
  `team` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `node_id` INT UNSIGNED NOT NULL,
  `learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `team`, `node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: account-wide flight paths';
