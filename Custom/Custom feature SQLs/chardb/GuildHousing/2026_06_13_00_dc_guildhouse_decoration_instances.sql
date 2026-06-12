-- Dark Chaos Guild Housing - Decoration Instance Tracking
-- Maps placed decoration gameobjects (world.gameobject rows) to the owning
-- guild for budget accounting, refunds, and ownership validation.
-- Table: dc_guildhouse_decoration_instances

CREATE TABLE IF NOT EXISTS `dc_guildhouse_decoration_instances` (
    `go_lowguid` INT UNSIGNED PRIMARY KEY, -- world.gameobject guid
    `guild_id` INT UNSIGNED NOT NULL,
    `entry` INT UNSIGNED NOT NULL, -- gameobject_template entry (555xxx)
    `placed_by` INT UNSIGNED NOT NULL DEFAULT 0, -- character guid
    `paid_copper` INT UNSIGNED NOT NULL DEFAULT 0,
    `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
