-- Add guild house upgrade level gating to spawn presets
ALTER TABLE `dc_guild_house_spawns`
    ADD COLUMN `guildhouse_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `preset`;

UPDATE `dc_guild_house_spawns`
SET `guildhouse_level` = 0
WHERE `guildhouse_level` IS NULL;
