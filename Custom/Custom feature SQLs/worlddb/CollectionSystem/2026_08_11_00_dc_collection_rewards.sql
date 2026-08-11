-- ============================================================================
-- DC Collection System - Data-driven collectible rewards
-- ============================================================================
-- Version: 1.0.0
-- Author: DarkChaos-255
-- Date: 2026-08-11
-- Description:
--   Attaches a mount, pet, toy, heirloom, title or appearance to a quest or an
--   achievement without a teaching item and without any C++ per reward.
--
--   Read at worldserver startup and on `.collection reload` by
--   src/server/scripts/DC/CollectionSystem/CollectionRewards.cpp, which hands
--   every row to DCCollection::GrantCollectible - so the account-wide unlock,
--   the spellbook entry, the mount-speed bonus and the DC-Collection client
--   notification all happen together.
--
--   Rows whose entry does not resolve are rejected at load time and reported
--   in the worldserver log (category sql.sql), never silently at reward time.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_rewards` (
    `source_type` ENUM('QUEST','ACHIEVEMENT') NOT NULL COMMENT 'What hands the collectible out',
    `source_id` INT UNSIGNED NOT NULL COMMENT 'quest_template.ID or Achievement.dbc ID',
    `collection_type` TINYINT UNSIGNED NOT NULL COMMENT '1=mount,2=pet,3=toy,4=heirloom,5=title,6=transmog',
    `entry_id` INT UNSIGNED NOT NULL COMMENT 'Mount spell / pet teaching item / item / title / display id. Teaching item ids and summon spell ids are normalised automatically.',
    `team` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance only, 2=horde only',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `comment` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'Free text for admins',
    PRIMARY KEY (`source_type`, `source_id`, `collection_type`, `entry_id`),
    KEY `idx_source` (`source_type`, `source_id`),
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Quest/achievement -> collectible rewards (DC-Collection)';

-- ============================================================================
-- EXAMPLES (commented out - uncomment and adjust before use)
-- ============================================================================

-- A quest that rewards a mount. entry_id is the mount spell id; the teaching
-- item id would also be accepted and normalised to the spell.
-- DELETE FROM `dc_collection_rewards` WHERE `source_type` = 'QUEST' AND `source_id` = 820056;
-- INSERT INTO `dc_collection_rewards`
--   (`source_type`, `source_id`, `collection_type`, `entry_id`, `team`, `enabled`, `comment`)
-- VALUES
--   ('QUEST', 820056, 1, 48025, 0, 1, 'Headless Horseman''s Mount');

-- An achievement that rewards a companion pet. entry_id is the teaching item
-- id (the summon spell id would also be accepted).
-- DELETE FROM `dc_collection_rewards` WHERE `source_type` = 'ACHIEVEMENT' AND `source_id` = 1793;
-- INSERT INTO `dc_collection_rewards`
--   (`source_type`, `source_id`, `collection_type`, `entry_id`, `team`, `enabled`, `comment`)
-- VALUES
--   ('ACHIEVEMENT', 1793, 2, 44810, 0, 1, 'Sinister Squashling');

-- A faction-specific title reward.
-- DELETE FROM `dc_collection_rewards` WHERE `source_type` = 'ACHIEVEMENT' AND `source_id` = 1174;
-- INSERT INTO `dc_collection_rewards`
--   (`source_type`, `source_id`, `collection_type`, `entry_id`, `team`, `enabled`, `comment`)
-- VALUES
--   ('ACHIEVEMENT', 1174, 5, 148, 1, 1, 'Alliance-only title');
