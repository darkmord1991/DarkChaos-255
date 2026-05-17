ALTER TABLE `dc_addon_client_caps`
ADD INDEX `idx_last_seen_recent_cover_v1`
(`last_seen`, `account_id`, `version_string`, `capabilities`, `negotiated_caps`);

ALTER TABLE `dc_addon_protocol_errors`
ADD INDEX `idx_recent_browse_cover_v1`
(`id`, `guid`, `module`, `opcode`, `event_type`);

ALTER TABLE `dc_addon_protocol_log`
ADD INDEX `idx_recent_browse_cover_v1`
(`id`, `guid`, `module`, `opcode`, `status`);