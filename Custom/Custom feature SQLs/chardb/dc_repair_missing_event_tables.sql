-- ============================================================================
-- Repair: tables referenced by scheduled events but missing from acore_chars
-- ============================================================================
-- Symptom (2026-09-09, /var/log/mysql/error.log):
--   [MY-010045] Event Scheduler: [acore@%][acore_chars.evt_dc_addon_daily_aggregate]
--       Table 'acore_chars.dc_addon_protocol_daily' doesn't exist
--   [MY-010045] Event Scheduler: [acore@%][acore_chars.dc_cross_system_cleanup]
--       Table 'acore_chars.dc_cross_system_multipliers' doesn't exist
--
-- Both events exist and fire on schedule; only their target tables are gone, so
-- every nightly run aborts. Definitions below are copied verbatim from:
--   chardb/AddonExtension/dc_addon_protocol_logging_schema.sql  (lines 74-87)
--   chardb/CrossSystem/dc_cross_system_schema.sql               (lines 118-133)
-- Re-running either full schema file is NOT safe -- both start with
-- DROP TABLE IF EXISTS on the live log/stats tables. Hence this extract.
--
-- Safe to re-run: steps 1-2 are IF NOT EXISTS, step 3 is idempotent once converted,
-- step 4 is DROP + CREATE PROCEDURE. No live data is touched by any of it.
--
-- NOTE: contains DELIMITER, which is a mysql-client directive, not server SQL.
-- Apply via HeidiSQL / DBeaver / the mysql CLI (all handle it); a raw driver
-- connection would choke on it -- run steps 1-3 there and step 4 separately.
-- ============================================================================

USE `acore_chars`;

-- ----------------------------------------------------------------------------
-- 1. dc_addon_protocol_daily -- target of evt_dc_addon_daily_aggregate (02:00 daily)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_addon_protocol_daily` (
    `date` DATE NOT NULL,
    `module` VARCHAR(8) NOT NULL,
    `total_c2s` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total client-to-server messages',
    `total_s2c` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total server-to-client messages',
    `unique_players` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Distinct player count',
    `error_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `avg_response_time_ms` FLOAT DEFAULT 0,
    `peak_hour` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Hour with most traffic (0-23)',
    PRIMARY KEY (`date`, `module`),
    INDEX `idx_date` (`date`),
    INDEX `idx_module` (`module`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Daily aggregated statistics for trend analysis';

-- ----------------------------------------------------------------------------
-- 2. dc_cross_system_multipliers -- target of dc_cross_system_cleanup
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_cross_system_multipliers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_type` ENUM('global', 'player', 'account', 'guild') NOT NULL DEFAULT 'global',
    `target_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Player/Account/Guild GUID or 0 for global',
    `source_system` VARCHAR(32) NULL COMMENT 'Specific system or NULL for all systems',
    `reward_type` TINYINT UNSIGNED NULL COMMENT 'Specific reward type or NULL for all',
    `multiplier` DECIMAL(5,3) NOT NULL DEFAULT 1.000,
    `reason` VARCHAR(255) NULL COMMENT 'Why this override exists',
    `expires_at` TIMESTAMP NULL COMMENT 'When this override expires, NULL = permanent',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_target` (`target_type`, `target_id`),
    KEY `idx_expires` (`expires_at`),
    KEY `idx_system` (`source_system`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-player or per-system multiplier overrides';

-- ----------------------------------------------------------------------------
-- 3. playerbots_arena_team_names -> InnoDB (worldserver asks for this at startup)
-- ----------------------------------------------------------------------------
-- A plain `ENGINE=InnoDB` fails with error 1031 ("Table storage engine for
-- '#sql-...' doesn't have this option") because the table carries ROW_FORMAT=FIXED,
-- which is a MyISAM-only row format. The conversion has to restate the row format.
ALTER TABLE `playerbots_arena_team_names`
    ENGINE=InnoDB,
    ROW_FORMAT=DYNAMIC;

-- Redundant: UNIQUE KEY `name_id` duplicates PRIMARY KEY (`name_id`). Optional.
-- ALTER TABLE `playerbots_arena_team_names` DROP INDEX `name_id`;

-- ----------------------------------------------------------------------------
-- 4. Redeploy sp_dc_addon_aggregate_daily (two fixes)
-- ----------------------------------------------------------------------------
-- The live copy of this procedure has a silent no-op upsert and a non-sargable
-- date filter. Source of truth is now AddonExtension/dc_addon_protocol_logging_schema.sql
-- (lines 141-195); the block below is that procedure verbatim, extracted so it can be
-- deployed WITHOUT running the full schema file -- which opens with DROP TABLE IF
-- EXISTS `dc_addon_protocol_log` and would destroy ~2.0M rows of live log data.
--
--   Fix 1 (correctness): ON DUPLICATE KEY UPDATE `total_c2s` = total_c2s assigned
--     every column to itself, because unqualified names in the UPDATE clause of an
--     INSERT ... SELECT bind to the target table, not to the SELECT's aliases.
--     Re-running for a date silently changed nothing. Now DELETE + INSERT.
--   Fix 2 (performance): WHERE DATE(`timestamp`) = yesterday wrapped the indexed
--     column in a function, so idx_timestamp could not be used and both the outer
--     query and the per-module peak_hour subquery full-scanned the log table. Now a
--     half-open range, which the index can serve.
--
-- Bonus: the rewrite no longer references l.`timestamp` outside the GROUP BY, so it
-- is safe if ONLY_FULL_GROUP_BY is ever enabled (this server currently runs without
-- it, which is why the old form did not raise error 1055).

DROP PROCEDURE IF EXISTS `sp_dc_addon_aggregate_daily`;
DELIMITER //
CREATE PROCEDURE `sp_dc_addon_aggregate_daily`()
BEGIN
    DECLARE log_day   DATE;
    DECLARE day_start DATETIME;
    DECLARE day_end   DATETIME;

    SET log_day   = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
    SET day_start = TIMESTAMP(log_day);
    SET day_end   = TIMESTAMP(CURDATE());

    START TRANSACTION;

    DELETE FROM `dc_addon_protocol_daily` WHERE `date` = log_day;

    INSERT INTO `dc_addon_protocol_daily`
        (`date`, `module`, `total_c2s`, `total_s2c`, `unique_players`,
         `error_count`, `avg_response_time_ms`, `peak_hour`)
    SELECT
        log_day,
        l.`module`,
        SUM(CASE WHEN l.`direction` = 'C2S' THEN 1 ELSE 0 END) as total_c2s,
        SUM(CASE WHEN l.`direction` = 'S2C' THEN 1 ELSE 0 END) as total_s2c,
        COUNT(DISTINCT l.`guid`) as unique_players,
        SUM(CASE WHEN l.`status` IN ('error', 'timeout') THEN 1 ELSE 0 END) as error_count,
        AVG(l.`processing_time_ms`) as avg_response_time_ms,
        (
            SELECT HOUR(sub.`timestamp`)
            FROM `dc_addon_protocol_log` sub
            WHERE sub.`timestamp` >= day_start
              AND sub.`timestamp` <  day_end
              AND sub.`module` = l.`module`
            GROUP BY HOUR(sub.`timestamp`)
            ORDER BY COUNT(*) DESC
            LIMIT 1
        ) as peak_hour
    FROM `dc_addon_protocol_log` l
    WHERE l.`timestamp` >= day_start
      AND l.`timestamp` <  day_end
    GROUP BY l.`module`;

    COMMIT;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Verify (run after applying)
-- ----------------------------------------------------------------------------
-- CALL `sp_dc_addon_aggregate_daily`();
-- SELECT * FROM `dc_addon_protocol_daily` ORDER BY `date` DESC, `module`;
-- Re-run the CALL a second time: row count must stay identical and values must
-- refresh rather than stay frozen. That is the regression test for Fix 1.
