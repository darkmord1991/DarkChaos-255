-- Dark Chaos Guild Housing - Purchase Log (CharacterDB)
-- Logs butler purchases/spawns for auditing.

CREATE TABLE IF NOT EXISTS `dc_guild_house_purchase_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `created_at` INT UNSIGNED NOT NULL DEFAULT 0, -- UNIX_TIMESTAMP()
  `guild_id` INT UNSIGNED NOT NULL,
  `player_guid` BIGINT UNSIGNED NOT NULL,
  `player_name` VARCHAR(12) NOT NULL,
  `map` INT UNSIGNED NOT NULL,
  `phaseMask` INT UNSIGNED NOT NULL,
  `spawn_type` ENUM('CREATURE','GAMEOBJECT') NOT NULL,
  `entry` INT UNSIGNED NOT NULL,
  `template_name` VARCHAR(100) DEFAULT NULL,
  `cost` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_guild_time` (`guild_id`, `created_at`),
  KEY `idx_player_time` (`player_guid`, `created_at`),
  KEY `idx_entry_time` (`entry`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
