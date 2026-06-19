-- Dark Chaos Guild Housing - Per-guild dynamic instance content (Phase B)
-- Unified ownership table for everything a guild dynamically spawns inside its
-- private instance of the guild-house map: butler-bought NPCs/objects now, and
-- player-placed decorations in Phase 4 (source column distinguishes them).
--
-- Under the instancing model these are NOT static world.creature/world.gameobject
-- rows (those would leak into every guild's instance). Instead each row here is
-- re-summoned non-persistently into the guild's instance on load by
-- GuildHouseManager::LoadGuildContentIntoInstance, and written by
-- GuildHouseManager::PlaceGuildContent when a member buys/places something.

CREATE TABLE IF NOT EXISTS `dc_guild_house_instance_spawns` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `guild_id` INT UNSIGNED NOT NULL,
    `spawn_type` ENUM('CREATURE','GAMEOBJECT') NOT NULL,
    `entry` INT UNSIGNED NOT NULL,
    `posX` FLOAT NOT NULL,
    `posY` FLOAT NOT NULL,
    `posZ` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL DEFAULT 0,
    `scale` FLOAT NOT NULL DEFAULT 1.0,
    `source` ENUM('BUTLER','DECORATION') NOT NULL DEFAULT 'BUTLER',
    `paid_copper` INT UNSIGNED NOT NULL DEFAULT 0,
    `placed_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_guild` (`guild_id`),
    KEY `idx_guild_entry` (`guild_id`, `entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
