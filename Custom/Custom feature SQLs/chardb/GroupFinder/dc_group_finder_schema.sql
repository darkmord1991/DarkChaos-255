-- DC Group Finder Database Tables
-- Part of the DarkChaos-255 Mythic+ Suite
-- Tables for storing group listings, applications, and spectator data

-- =====================================================================
-- dc_group_finder_listings - Active group listings
-- =====================================================================
CREATE TABLE IF NOT EXISTS `dc_group_finder_listings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `leader_guid` INT UNSIGNED NOT NULL,
    `group_guid` INT UNSIGNED NOT NULL DEFAULT 0,
    `listing_type` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Mythic+, 2=Raid, 3=PvP, 4=Other',
    `dungeon_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `dungeon_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
    `difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Normal, 1=Heroic, 2=Mythic',
    `keystone_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `min_ilvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `current_tank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `current_healer` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `current_dps` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `need_tank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `need_healer` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `need_dps` TINYINT UNSIGNED NOT NULL DEFAULT 3,
    `note` VARCHAR(256) NOT NULL DEFAULT '',
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Active, 0=Inactive/Expired',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_leader` (`leader_guid`),
    INDEX `idx_status_type` (`status`, `listing_type`),
    INDEX `idx_dungeon` (`dungeon_id`, `keystone_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- dc_group_finder_applications - Player applications to groups
-- =====================================================================
CREATE TABLE IF NOT EXISTS `dc_group_finder_applications` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `listing_id` INT UNSIGNED NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `player_name` VARCHAR(12) NOT NULL DEFAULT '',
    `role` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1=Tank, 2=Healer, 4=DPS',
    `player_class` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `player_level` TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `player_ilvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `note` VARCHAR(256) NOT NULL DEFAULT '',
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Pending, 1=Accepted, 2=Declined, 3=Cancelled',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_listing` (`listing_id`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_status` (`status`),
    UNIQUE INDEX `idx_unique_app` (`listing_id`, `player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- dc_group_finder_spectators - Players spectating live runs
-- =====================================================================
CREATE TABLE IF NOT EXISTS `dc_group_finder_spectators` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `run_id` INT UNSIGNED NOT NULL COMMENT 'References mythic+ run ID or custom session',
    `spectator_guid` INT UNSIGNED NOT NULL,
    `privacy_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Public, 2=Friends, 3=Guild, 4=Private',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_run` (`run_id`),
    INDEX `idx_spectator` (`spectator_guid`),
    UNIQUE INDEX `idx_unique_spec` (`run_id`, `spectator_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- dc_group_finder_scheduled_events - Scheduled group events
-- =====================================================================
CREATE TABLE IF NOT EXISTS `dc_group_finder_scheduled_events` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `leader_guid` INT UNSIGNED NOT NULL,
    `event_type` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Mythic+, 2=Raid, 3=PvP',
    `dungeon_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `dungeon_name` VARCHAR(64) NOT NULL DEFAULT 'Unknown',
    `keystone_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `scheduled_time` TIMESTAMP NOT NULL,
    `max_signups` TINYINT UNSIGNED NOT NULL DEFAULT 5,
    `current_signups` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `note` VARCHAR(256) NOT NULL DEFAULT '',
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Open, 2=Full, 3=Started, 4=Cancelled, 5=Completed',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_leader` (`leader_guid`),
    INDEX `idx_scheduled` (`scheduled_time`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- dc_group_finder_event_signups - Signups for scheduled events
-- =====================================================================
CREATE TABLE IF NOT EXISTS `dc_group_finder_event_signups` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `event_id` INT UNSIGNED NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `player_name` VARCHAR(12) NOT NULL DEFAULT '',
    `role` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1=Tank, 2=Healer, 4=DPS',
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Pending, 1=Confirmed, 2=Declined, 3=Cancelled',
    `note` VARCHAR(256) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_event` (`event_id`),
    INDEX `idx_player` (`player_guid`),
    UNIQUE INDEX `idx_unique_signup` (`event_id`, `player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
