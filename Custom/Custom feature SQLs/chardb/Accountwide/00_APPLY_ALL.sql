-- ===========================================================================
-- DarkChaos-255: Account-wide progression pools -- SINGLE APPLY FILE
--
-- Target database: acore_characters
--
-- This is the only file you need to run for the account-wide systems
-- (achievements / reputation / friendlist). It is safe to run on:
--   * a fresh database                      -> creates all three tables
--   * a database that already has them      -> creates nothing, migrates
--                                              dc_account_reputation_pools
--   * a database where it already ran       -> no-op, re-runnable
--
-- Apply with:
--   mysql -u <user> -p acore_characters < 00_APPLY_ALL.sql
--
-- Related C++: src/server/scripts/DC/Progression/Accountwide/
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. Achievements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_account_achievement_pools` (
  `account_id` INT UNSIGNED NOT NULL,
  `achievement_id` INT UNSIGNED NOT NULL,
  `completed_at` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `achievement_id`),
  KEY `idx_achievement_id` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='DarkChaos: Account-wide completed achievements';


-- ---------------------------------------------------------------------------
-- 2. Friendlist
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_account_social_friends` (
  `account_id` INT UNSIGNED NOT NULL,
  `friend_guid` INT UNSIGNED NOT NULL,
  `note` VARCHAR(48) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `friend_guid`),
  KEY `idx_friend_guid` (`friend_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='DarkChaos: Account-wide friendlist entries';


-- ---------------------------------------------------------------------------
-- 3. Reputation
--
-- Rows are keyed (account_id, faction_id, team) and carry the base reputation
-- they were recorded under.
--
-- A stored standing is an absolute that already includes the character's base
-- value, and that base is race/faction dependent. Without the team in the key,
-- an Alliance character's exalted Stormwind standing would be replayed onto a
-- Horde alt and make enemy-city guards friendly. `base_standing` is verified
-- before anything is applied, which additionally lets factions that are neutral
-- to both sides (base 0 everywhere, e.g. Argent Dawn) still be shared across
-- the faction divide.
--
-- team: 0 = Alliance, 1 = Horde (TeamId)
-- ---------------------------------------------------------------------------
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
-- 4. Migration: pre-team reputation layout, PRIMARY KEY (account_id, faction_id)
--
-- Only runs when the `team` column is absent, i.e. the table predates this
-- change. Legacy rows carry no team and no recorded base, so their standing
-- cannot be attributed to a faction context -- they are dropped rather than
-- guessed at. Keeping them would risk exactly the cross-faction leak this
-- change fixes. Nothing is lost that does not come back: every pool refills
-- from the characters themselves on their next login sync.
--
-- Written with prepared statements rather than a stored procedure so it needs
-- no DELIMITER, which is a mysql-client directive that other appliers choke on.
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


-- ---------------------------------------------------------------------------
-- 5. Result
-- ---------------------------------------------------------------------------
SELECT
  IF(@needs_migration = 1,
     'reputation pool MIGRATED to (account_id, faction_id, team) - old rows cleared',
     'reputation pool already current - no migration needed') AS `reputation`,
  (SELECT COUNT(*) FROM `dc_account_achievement_pools`) AS `achievement_rows`,
  (SELECT COUNT(*) FROM `dc_account_social_friends`)    AS `friend_rows`,
  (SELECT COUNT(*) FROM `dc_account_reputation_pools`)  AS `reputation_rows`;
