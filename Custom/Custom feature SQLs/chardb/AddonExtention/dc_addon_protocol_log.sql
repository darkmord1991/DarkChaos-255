-- ============================================================
-- DC Addon Protocol Request/Response Logging
-- For debugging and monitoring addon communication
-- ============================================================

-- Main request log table
DROP TABLE IF EXISTS `dc_addon_protocol_log`;
CREATE TABLE `dc_addon_protocol_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
    `account_id` INT UNSIGNED NOT NULL,
    `character_name` VARCHAR(32) NOT NULL,
    `direction` ENUM('C2S', 'S2C') NOT NULL COMMENT 'Client->Server or Server->Client',
    `module` VARCHAR(8) NOT NULL COMMENT 'Module code (CORE, LBRD, etc)',
    `opcode` TINYINT UNSIGNED NOT NULL,
    `opcode_name` VARCHAR(32) DEFAULT NULL COMMENT 'Human readable opcode name',
    `data_size` INT UNSIGNED DEFAULT 0 COMMENT 'JSON payload size in bytes',
    `data_preview` VARCHAR(255) DEFAULT NULL COMMENT 'First 255 chars of JSON data',
    `response_time_ms` INT UNSIGNED DEFAULT NULL COMMENT 'Response time in milliseconds (for matched requests)',
    `status` ENUM('pending', 'completed', 'timeout', 'error') DEFAULT 'pending',
    `error_message` VARCHAR(255) DEFAULT NULL,
    `session_id` VARCHAR(64) DEFAULT NULL COMMENT 'Unique session identifier',
    PRIMARY KEY (`id`),
    KEY `idx_timestamp` (`timestamp`),
    KEY `idx_guid` (`guid`),
    KEY `idx_module` (`module`),
    KEY `idx_direction_module` (`direction`, `module`),
    KEY `idx_status` (`status`),
    KEY `idx_session` (`session_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Addon protocol request/response logging';

-- Aggregated statistics per module per player
DROP TABLE IF EXISTS `dc_addon_protocol_stats`;
CREATE TABLE `dc_addon_protocol_stats` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `guid` INT UNSIGNED NOT NULL,
    `module` VARCHAR(8) NOT NULL,
    `total_requests` INT UNSIGNED DEFAULT 0,
    `total_responses` INT UNSIGNED DEFAULT 0,
    `total_timeouts` INT UNSIGNED DEFAULT 0,
    `total_errors` INT UNSIGNED DEFAULT 0,
    `avg_response_time_ms` FLOAT DEFAULT 0,
    `max_response_time_ms` INT UNSIGNED DEFAULT 0,
    `total_data_sent_bytes` BIGINT UNSIGNED DEFAULT 0,
    `total_data_received_bytes` BIGINT UNSIGNED DEFAULT 0,
    `first_request` DATETIME DEFAULT NULL,
    `last_request` DATETIME DEFAULT NULL,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_guid_module` (`guid`, `module`),
    KEY `idx_module` (`module`),
    KEY `idx_last_request` (`last_request`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Aggregated protocol statistics per player per module';

-- Daily summary for trend analysis
DROP TABLE IF EXISTS `dc_addon_protocol_daily`;
CREATE TABLE `dc_addon_protocol_daily` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `date` DATE NOT NULL,
    `module` VARCHAR(8) NOT NULL,
    `total_requests` INT UNSIGNED DEFAULT 0,
    `total_responses` INT UNSIGNED DEFAULT 0,
    `total_timeouts` INT UNSIGNED DEFAULT 0,
    `unique_players` INT UNSIGNED DEFAULT 0,
    `avg_response_time_ms` FLOAT DEFAULT 0,
    `peak_hour` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Hour with most requests (0-23)',
    `peak_requests` INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_date_module` (`date`, `module`),
    KEY `idx_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Daily aggregated protocol statistics';

-- ============================================================
-- Views for easy querying
-- ============================================================

-- Recent activity view
CREATE OR REPLACE VIEW `v_dc_addon_recent_activity` AS
SELECT 
    l.timestamp,
    l.character_name,
    l.direction,
    l.module,
    CONCAT('0x', LPAD(HEX(l.opcode), 2, '0')) as opcode_hex,
    l.opcode_name,
    l.status,
    l.response_time_ms,
    l.data_size
FROM dc_addon_protocol_log l
WHERE l.timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY l.timestamp DESC
LIMIT 100;

-- Module health view
CREATE OR REPLACE VIEW `v_dc_addon_module_health` AS
SELECT 
    module,
    COUNT(*) as total_requests_24h,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
    SUM(CASE WHEN status = 'timeout' THEN 1 ELSE 0 END) as timeouts,
    SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) as errors,
    ROUND(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) as success_rate,
    ROUND(AVG(response_time_ms), 2) as avg_response_ms,
    MAX(response_time_ms) as max_response_ms
FROM dc_addon_protocol_log
WHERE timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    AND direction = 'C2S'
GROUP BY module
ORDER BY total_requests_24h DESC;

-- Player activity view
CREATE OR REPLACE VIEW `v_dc_addon_player_activity` AS
SELECT 
    s.guid,
    c.name as character_name,
    s.module,
    s.total_requests,
    s.total_responses,
    s.total_timeouts,
    ROUND((s.total_responses / NULLIF(s.total_requests, 0)) * 100, 2) as success_rate,
    ROUND(s.avg_response_time_ms, 2) as avg_response_ms,
    s.last_request
FROM dc_addon_protocol_stats s
LEFT JOIN characters c ON c.guid = s.guid
ORDER BY s.last_request DESC;

-- ============================================================
-- Cleanup procedure (run daily via scheduled task)
-- ============================================================

DELIMITER //

CREATE PROCEDURE `sp_dc_addon_cleanup_logs`(IN days_to_keep INT)
BEGIN
    DECLARE deleted_count INT DEFAULT 0;
    
    -- Delete old detailed logs (keep aggregated stats)
    DELETE FROM dc_addon_protocol_log 
    WHERE timestamp < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    
    SET deleted_count = ROW_COUNT();
    
    -- Log the cleanup
    INSERT INTO dc_addon_protocol_log 
        (guid, account_id, character_name, direction, module, opcode, opcode_name, data_preview)
    VALUES 
        (0, 0, 'SYSTEM', 'S2C', 'CORE', 0xFF, 'CLEANUP', 
         CONCAT('Deleted ', deleted_count, ' log entries older than ', days_to_keep, ' days'));
END//

-- Aggregate daily stats procedure
CREATE PROCEDURE `sp_dc_addon_aggregate_daily`()
BEGIN
    DECLARE target_date DATE DEFAULT DATE_SUB(CURDATE(), INTERVAL 1 DAY);
    
    INSERT INTO dc_addon_protocol_daily 
        (date, module, total_requests, total_responses, total_timeouts, unique_players, avg_response_time_ms)
    SELECT 
        target_date,
        module,
        SUM(CASE WHEN direction = 'C2S' THEN 1 ELSE 0 END),
        SUM(CASE WHEN direction = 'S2C' THEN 1 ELSE 0 END),
        SUM(CASE WHEN status = 'timeout' THEN 1 ELSE 0 END),
        COUNT(DISTINCT guid),
        AVG(response_time_ms)
    FROM dc_addon_protocol_log
    WHERE DATE(timestamp) = target_date
    GROUP BY module
    ON DUPLICATE KEY UPDATE
        total_requests = VALUES(total_requests),
        total_responses = VALUES(total_responses),
        total_timeouts = VALUES(total_timeouts),
        unique_players = VALUES(unique_players),
        avg_response_time_ms = VALUES(avg_response_time_ms);
END//

DELIMITER ;

-- ============================================================
-- Sample queries for debugging
-- ============================================================

-- Find slow requests (response time > 5 seconds)
-- SELECT * FROM dc_addon_protocol_log WHERE response_time_ms > 5000 ORDER BY timestamp DESC LIMIT 50;

-- Find timeout patterns by module
-- SELECT module, COUNT(*) as timeouts, DATE(timestamp) as date 
-- FROM dc_addon_protocol_log WHERE status = 'timeout' 
-- GROUP BY module, DATE(timestamp) ORDER BY date DESC, timeouts DESC;

-- Most active players
-- SELECT character_name, COUNT(*) as requests 
-- FROM dc_addon_protocol_log WHERE direction = 'C2S' 
-- AND timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
-- GROUP BY guid ORDER BY requests DESC LIMIT 20;

-- Request distribution by hour (for capacity planning)
-- SELECT HOUR(timestamp) as hour, module, COUNT(*) as requests
-- FROM dc_addon_protocol_log WHERE direction = 'C2S'
-- AND DATE(timestamp) = CURDATE()
-- GROUP BY HOUR(timestamp), module ORDER BY hour, requests DESC;
