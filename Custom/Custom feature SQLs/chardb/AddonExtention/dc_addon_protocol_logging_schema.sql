-- ============================================================================
-- Dark Chaos Addon Protocol Logging Tables
-- ============================================================================
-- These tables are for optional debugging/monitoring of addon protocol messages.
-- Enable with: DC.AddonProtocol.Logging.Enable = 1 in worldserver.conf
-- ============================================================================

-- Drop existing tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS `dc_addon_protocol_log`;
DROP TABLE IF EXISTS `dc_addon_protocol_stats`;
DROP TABLE IF EXISTS `dc_addon_protocol_daily`;

-- ============================================================================
-- dc_addon_protocol_log - Logs every C2S/S2C message
-- ============================================================================
-- Request types:
--   STANDARD  = Plain Blizzard addon message (SendAddonMessage, no DC format)
--   DC_JSON   = DC Protocol with JSON payload (MODULE:OPCODE:{...})
--   DC_PLAIN  = DC Protocol with plain data (MODULE:OPCODE:data)
--   AIO       = AIO framework modules (Rochet2 AIO: SPOT, SEAS, MHUD)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_addon_protocol_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `account_id` INT UNSIGNED NOT NULL,
    `character_name` VARCHAR(48) NOT NULL,
    `direction` ENUM('C2S', 'S2C') NOT NULL COMMENT 'Client to Server or Server to Client',
    `request_type` ENUM('STANDARD', 'DC_JSON', 'DC_PLAIN', 'AIO') NOT NULL DEFAULT 'DC_PLAIN' COMMENT 'Protocol format detected',
    `module` VARCHAR(16) NOT NULL COMMENT 'Module code (CORE, AOE, SPEC, LBRD, etc.)',
    `opcode` TINYINT UNSIGNED NOT NULL COMMENT 'Message opcode within module',
    `data_size` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Size of payload in bytes',
    `data_preview` VARCHAR(255) DEFAULT NULL COMMENT 'First 255 chars of payload for debugging',
    `status` ENUM('pending', 'completed', 'error', 'timeout') NOT NULL DEFAULT 'pending',
    `error_message` VARCHAR(255) DEFAULT NULL COMMENT 'Error description if status=error',
    `processing_time_ms` INT UNSIGNED DEFAULT NULL COMMENT 'Time to process message in ms',
    PRIMARY KEY (`id`),
    INDEX `idx_timestamp` (`timestamp`),
    INDEX `idx_guid` (`guid`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_module` (`module`),
    INDEX `idx_direction_module` (`direction`, `module`),
    INDEX `idx_request_type` (`request_type`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Detailed log of all addon protocol messages (debugging)';

-- ============================================================================
-- dc_addon_protocol_stats - Aggregated stats per player per module
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_addon_protocol_stats` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `module` VARCHAR(8) NOT NULL COMMENT 'Module code',
    `total_requests` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total C2S messages',
    `total_responses` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total S2C messages',
    `total_errors` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Messages that resulted in error',
    `total_timeouts` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Messages that timed out',
    `avg_response_time_ms` FLOAT DEFAULT 0 COMMENT 'Average response time in ms',
    `max_response_time_ms` INT UNSIGNED DEFAULT 0 COMMENT 'Maximum response time in ms',
    `first_request` TIMESTAMP NULL DEFAULT NULL COMMENT 'First message from this player',
    `last_request` TIMESTAMP NULL DEFAULT NULL COMMENT 'Most recent message',
    PRIMARY KEY (`guid`, `module`),
    INDEX `idx_module` (`module`),
    INDEX `idx_last_request` (`last_request`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Aggregated protocol statistics per player per module';

-- ============================================================================
-- dc_addon_protocol_daily - Daily summaries for trend analysis
-- ============================================================================
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

-- ============================================================================
-- Stored Procedures
-- ============================================================================

-- Cleanup old log entries (keep last N days)
DROP PROCEDURE IF EXISTS `sp_dc_addon_cleanup_logs`;
DELIMITER //
CREATE PROCEDURE `sp_dc_addon_cleanup_logs`(IN days_to_keep INT)
BEGIN
    DECLARE cutoff_date TIMESTAMP;
    SET cutoff_date = DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    
    -- Delete old log entries
    DELETE FROM `dc_addon_protocol_log` WHERE `timestamp` < cutoff_date;
    
    -- Delete old daily stats
    DELETE FROM `dc_addon_protocol_daily` WHERE `date` < DATE(cutoff_date);
    
    -- Optimize tables after bulk delete
    OPTIMIZE TABLE `dc_addon_protocol_log`;
    OPTIMIZE TABLE `dc_addon_protocol_daily`;
END //
DELIMITER ;

-- Aggregate yesterday's logs into daily summary
DROP PROCEDURE IF EXISTS `sp_dc_addon_aggregate_daily`;
DELIMITER //
CREATE PROCEDURE `sp_dc_addon_aggregate_daily`()
BEGIN
    DECLARE yesterday DATE;
    SET yesterday = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
    
    -- Insert or update daily aggregates
    INSERT INTO `dc_addon_protocol_daily` (`date`, `module`, `total_c2s`, `total_s2c`, `unique_players`, `error_count`, `avg_response_time_ms`, `peak_hour`)
    SELECT 
        DATE(`timestamp`) as log_date,
        `module`,
        SUM(CASE WHEN `direction` = 'C2S' THEN 1 ELSE 0 END) as total_c2s,
        SUM(CASE WHEN `direction` = 'S2C' THEN 1 ELSE 0 END) as total_s2c,
        COUNT(DISTINCT `guid`) as unique_players,
        SUM(CASE WHEN `status` = 'error' THEN 1 ELSE 0 END) as error_count,
        AVG(`processing_time_ms`) as avg_response_time_ms,
        (
            SELECT HOUR(sub.`timestamp`)
            FROM `dc_addon_protocol_log` sub
            WHERE DATE(sub.`timestamp`) = DATE(l.`timestamp`)
              AND sub.`module` = l.`module`
            GROUP BY HOUR(sub.`timestamp`)
            ORDER BY COUNT(*) DESC
            LIMIT 1
        ) as peak_hour
    FROM `dc_addon_protocol_log` l
    WHERE DATE(`timestamp`) = yesterday
    GROUP BY DATE(`timestamp`), `module`
    ON DUPLICATE KEY UPDATE
        `total_c2s` = VALUES(`total_c2s`),
        `total_s2c` = VALUES(`total_s2c`),
        `unique_players` = VALUES(`unique_players`),
        `error_count` = VALUES(`error_count`),
        `avg_response_time_ms` = VALUES(`avg_response_time_ms`),
        `peak_hour` = VALUES(`peak_hour`);
END //
DELIMITER ;

-- ============================================================================
-- Scheduled Events (require event_scheduler = ON in MySQL)
-- ============================================================================

-- Drop existing events if they exist
DROP EVENT IF EXISTS `evt_dc_addon_daily_aggregate`;
DROP EVENT IF EXISTS `evt_dc_addon_cleanup_logs`;

-- Daily aggregation at 2 AM
DELIMITER //
CREATE EVENT IF NOT EXISTS `evt_dc_addon_daily_aggregate`
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE, '02:00:00'))
ON COMPLETION PRESERVE
ENABLE
DO BEGIN
    CALL `sp_dc_addon_aggregate_daily`();
END //
DELIMITER ;

-- Weekly cleanup - keep 30 days of logs
DELIMITER //
CREATE EVENT IF NOT EXISTS `evt_dc_addon_cleanup_logs`
ON SCHEDULE EVERY 1 WEEK
STARTS (TIMESTAMP(CURRENT_DATE + INTERVAL (7 - WEEKDAY(CURRENT_DATE)) DAY, '03:00:00'))
ON COMPLETION PRESERVE
ENABLE
DO BEGIN
    CALL `sp_dc_addon_cleanup_logs`(30);
END //
DELIMITER ;

-- ============================================================================
-- Useful Queries for Monitoring
-- ============================================================================

-- View recent protocol activity (last hour)
-- SELECT module, direction, COUNT(*) as msg_count, 
--        COUNT(DISTINCT guid) as unique_players
-- FROM dc_addon_protocol_log 
-- WHERE timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
-- GROUP BY module, direction
-- ORDER BY msg_count DESC;

-- View player-specific stats
-- SELECT c.name, s.module, s.total_requests, s.total_responses, 
--        s.total_errors, s.avg_response_time_ms
-- FROM dc_addon_protocol_stats s
-- JOIN characters c ON c.guid = s.guid
-- ORDER BY s.total_requests DESC
-- LIMIT 20;

-- View daily trends for a specific module
-- SELECT date, total_c2s, total_s2c, unique_players, error_count
-- FROM dc_addon_protocol_daily
-- WHERE module = 'LEAD'
-- ORDER BY date DESC
-- LIMIT 30;

-- ============================================================================
-- Enable event scheduler (run this once if not already enabled)
-- ============================================================================
-- SET GLOBAL event_scheduler = ON;
-- 
-- To make this permanent, add to my.cnf / my.ini:
-- [mysqld]
-- event_scheduler = ON
