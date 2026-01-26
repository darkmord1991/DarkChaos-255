-- Add guild house upgrade level
ALTER TABLE `dc_guild_house`
    ADD COLUMN `guildhouse_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `orientation`;

UPDATE `dc_guild_house`
SET `guildhouse_level` = 1
WHERE `guildhouse_level` IS NULL;
