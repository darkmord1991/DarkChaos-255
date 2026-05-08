ALTER TABLE `dc_addon_protocol_stats`
ADD INDEX `idx_last_request_recent_cover_v2`
(`last_request`, `guid`, `module`, `total_requests`,
 `total_responses`, `avg_response_time_ms`,
 `max_response_time_ms`);
