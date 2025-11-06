-- DarkChaos Item Upgrade System - Characters Database
-- Player currency and item upgrade state tables
-- Run this on CHARACTERS database (acore_characters)

-- Table for player currencies (Upgrade Tokens and Artifact Essence)
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_currency` (
    `player_guid` INT UNSIGNED NOT NULL,
    `currency_type` TINYINT UNSIGNED NOT NULL COMMENT '1=Upgrade Tokens, 2=Artifact Essence',
    `amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`, `currency_type`),
    INDEX `idx_player_season` (`player_guid`, `season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player currency balances for item upgrade system';

-- Table for item upgrade states (per-character item data)
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_state` (
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'From item_instance.guid',
    `player_guid` INT UNSIGNED NOT NULL,
    `tier_id` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Leveling, 2=Heroic, 3=Raid, 4=Mythic, 5=Artifact',
    `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0-15, 0=base, 15=max',
    `tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `base_item_level` SMALLINT UNSIGNED NOT NULL,
    `upgraded_item_level` SMALLINT UNSIGNED NOT NULL,
    `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT '1.0=base, 1.5=+50% stats, etc',
    `first_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `last_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`item_guid`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_tier_level` (`tier_id`, `upgrade_level`),
    INDEX `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Item upgrade states for each item';

-- Example: Give yourself test tokens
-- Find your character's GUID first:
-- SELECT guid, name FROM characters WHERE name = 'YourCharacterName';
-- 
-- Then insert tokens:
-- INSERT INTO `dc_item_upgrade_currency` (`player_guid`, `currency_type`, `amount`, `season`) VALUES
-- (1, 1, 10000, 1),  -- Replace 1 with your character GUID - 10000 Upgrade Tokens
-- (1, 2, 5000, 1);   -- Replace 1 with your character GUID - 5000 Artifact Essence
