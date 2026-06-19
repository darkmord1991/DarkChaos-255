-- Dark Chaos Guild Housing - Per-guild instance binding (Phase B migration)
-- Maps each guild to the persistent instance id of its private copy of the
-- guild-house map (1409). Replaces the legacy 27-phase shared-map isolation:
-- separation now comes from the instance id, lifting the 27-guild cap to
-- effectively unlimited (100+). The row is (re)created lazily by
-- GuildHouseManager::EnsureGuildInstanceId when a member teleports in; if the
-- underlying normal-dungeon InstanceSave has expired/reset, a fresh instance is
-- minted and this mapping is overwritten.

CREATE TABLE IF NOT EXISTS `dc_guild_house_instance` (
    `guild_id` INT UNSIGNED NOT NULL,
    `instance_id` INT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`guild_id`),
    KEY `idx_instance` (`instance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
