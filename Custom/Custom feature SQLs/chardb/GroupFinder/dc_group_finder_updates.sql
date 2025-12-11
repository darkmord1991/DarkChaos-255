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
