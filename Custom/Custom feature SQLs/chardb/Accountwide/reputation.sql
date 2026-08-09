-- DarkChaos account-wide reputation pools
-- Used by: Progression/Accountwide/dc_accountwide_reputation.cpp
--
-- Rows are keyed (account_id, faction_id, team) and carry the base reputation
-- they were recorded under.
--
-- Reputation standings are stored as absolutes that already include the
-- character's base value, and that base is race/faction dependent. Without the
-- team in the key, an Alliance character's exalted Stormwind standing would be
-- replayed onto a Horde alt and make enemy-city guards friendly. `base_standing`
-- is verified before anything is applied, which additionally lets factions that
-- are neutral to both sides (base 0 everywhere, e.g. Argent Dawn) still be
-- shared across the faction divide.
--
-- team: 0 = Alliance, 1 = Horde (TeamId).

CREATE TABLE IF NOT EXISTS `dc_account_reputation_pools` (
  `account_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `team` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `standing` INT NOT NULL DEFAULT 0,
  `base_standing` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `faction_id`, `team`),
  KEY `idx_faction` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='DarkChaos: Account-wide reputation pools';

-- ---------------------------------------------------------------------------
-- Migration from the pre-team layout, PRIMARY KEY (account_id, faction_id).
--
-- Legacy rows carry no team and no recorded base, so their standing cannot be
-- attributed to a faction context. They are dropped rather than guessed at:
-- keeping them would risk exactly the cross-faction leak this change fixes, and
-- every pool refills from the characters themselves on their next login sync.
--
-- Written with prepared statements rather than a stored procedure so it needs
-- no DELIMITER, which is a mysql-client directive that non-CLI appliers choke
-- on. On a fresh database the CREATE above already made the new shape, so
-- @needs_migration is 0 and both statements are no-ops.
-- ---------------------------------------------------------------------------

SET @needs_migration := (
  SELECT IF(COUNT(*) = 0, 1, 0)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND `TABLE_NAME` = 'dc_account_reputation_pools'
    AND `COLUMN_NAME` = 'team');

SET @stmt := IF(@needs_migration = 1,
  'DELETE FROM `dc_account_reputation_pools`',
  'DO 0');
PREPARE dc_rep_migrate FROM @stmt;
EXECUTE dc_rep_migrate;
DEALLOCATE PREPARE dc_rep_migrate;

SET @stmt := IF(@needs_migration = 1,
  'ALTER TABLE `dc_account_reputation_pools`
     DROP PRIMARY KEY,
     ADD COLUMN `team` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `faction_id`,
     ADD COLUMN `base_standing` INT NOT NULL DEFAULT 0 AFTER `standing`,
     ADD PRIMARY KEY (`account_id`, `faction_id`, `team`)',
  'DO 0');
PREPARE dc_rep_migrate FROM @stmt;
EXECUTE dc_rep_migrate;
DEALLOCATE PREPARE dc_rep_migrate;
