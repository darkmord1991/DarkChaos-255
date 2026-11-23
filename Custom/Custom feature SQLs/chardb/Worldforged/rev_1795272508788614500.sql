-- Worldforged pickups (maps 750/751): one claim per ACCOUNT instead of per character (decided 2026-11-21).
-- The worldserver loads this table at startup and moves each character's old claims (character_settings source
-- 'dc-worldforged') in here at that character's next login.
CREATE TABLE IF NOT EXISTS `dc_worldforged_claims` (
    `account_id` INT UNSIGNED NOT NULL,
    `spawn_guid` INT UNSIGNED NOT NULL COMMENT 'gameobject spawn guid, 6900001-6999999',
    `claimed_by` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'guid of the character that looted it',
    `claimed_at` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'unix time',
    PRIMARY KEY (`account_id`, `spawn_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Worldforged pickup claims, one row per account and pickup';
