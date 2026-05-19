ALTER TABLE `dc_addon_protocol_stats`
    ADD COLUMN `transport` enum('ADDON','NATIVE','LEGACY_MIXED')
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
    DEFAULT 'LEGACY_MIXED' AFTER `module`;

ALTER TABLE `dc_addon_protocol_stats`
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`guid`, `module`, `transport`);

ALTER TABLE `dc_addon_protocol_stats`
    DROP INDEX `idx_module`,
    ADD INDEX `idx_module_transport` (`module`, `transport`),
    DROP INDEX `idx_last_request_recent_cover`,
    DROP INDEX `idx_last_request_recent_cover_v2`,
    ADD INDEX `idx_last_request_recent_cover_v3`
        (`last_request`, `guid`, `module`, `transport`, `total_requests`,
         `total_responses`, `avg_response_time_ms`, `max_response_time_ms`);