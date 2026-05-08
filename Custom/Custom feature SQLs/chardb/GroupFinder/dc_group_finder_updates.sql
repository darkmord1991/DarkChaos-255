-- DC Group Finder Update - Multi-Role & Rewards
-- Adds support for rewards and ensures role column is sufficient (it is, but we might need a rewards table)

-- Table to track daily/weekly rewards for Group Finder
CREATE TABLE IF NOT EXISTS `dc_group_finder_rewards` (
    `player_guid` INT UNSIGNED NOT NULL,
    `reward_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Daily, 1=Weekly',
    `dungeon_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1=Normal, 2=Heroic, 3=Mythic, 4=Raid',
    `claim_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`, `reward_type`, `dungeon_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add column to listings to store if it was auto-created or manual (optional, but good for tracking)
ALTER TABLE `dc_group_finder_listings` ADD COLUMN `auto_group` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `status`;

-- Expand the listing type contract to include quest listings.
ALTER TABLE `dc_group_finder_listings`
    MODIFY COLUMN `listing_type` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Mythic+, 2=Raid, 3=PvP, 4=Other, 5=Quest';

-- Align spectator storage with the live spectate handler payload.
ALTER TABLE `dc_group_finder_spectators`
    ADD COLUMN `spectator_name` VARCHAR(12) NOT NULL DEFAULT '' AFTER `spectator_guid`,
    CHANGE COLUMN `joined_at` `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    DROP COLUMN `privacy_level`;
