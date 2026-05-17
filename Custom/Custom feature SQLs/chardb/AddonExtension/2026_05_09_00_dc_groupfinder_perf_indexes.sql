ALTER TABLE `dc_group_finder_scheduled_events`
    ADD INDEX `idx_status_scheduled_time` (`status`, `scheduled_time`);

ALTER TABLE `dc_group_finder_event_signups`
    ADD INDEX `idx_player_status_event` (`player_guid`, `status`, `event_id`);
