-- Great Vault raid and PvP rows, and seasonal weekly chests.
--
-- dc_vault_raid_kills / dc_vault_pvp_wins: the vault's own weekly progress.
-- The raid row read instance.resettime, which the core stores as 0 for every
-- raid save, and the PvP row read pvpstats_*, which stays empty while
-- Battleground.StoreStatistics.Enable = 0 and never holds arenas or HLBG.
-- Written by GreatVault.cpp (encounter credit and battleground end hooks),
-- read by GreatVault.cpp and dc_addon_mythicplus.cpp, purged weekly by
-- DCWeeklyResetHub.cpp (current and last week are kept).
CREATE TABLE IF NOT EXISTS `dc_vault_raid_kills` (
    `character_guid` INT UNSIGNED NOT NULL,
    `week_start` BIGINT UNSIGNED NOT NULL COMMENT 'Unix week start, as dc_weekly_vault.week_start',
    `map_id` SMALLINT UNSIGNED NOT NULL,
    `encounter_index` TINYINT UNSIGNED NOT NULL COMMENT 'DungeonEncounter.dbc encounterIndex, shared by the 10 and 25 player versions',
    `difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map difficulty of the first kill that week',
    `killed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_guid`, `week_start`, `map_id`, `encounter_index`),
    KEY `idx_week` (`week_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Great Vault raid row: unique raid bosses per character and week';

CREATE TABLE IF NOT EXISTS `dc_vault_pvp_wins` (
    `character_guid` INT UNSIGNED NOT NULL,
    `week_start` BIGINT UNSIGNED NOT NULL COMMENT 'Unix week start, as dc_weekly_vault.week_start',
    `wins` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Battleground, arena and HLBG wins',
    PRIMARY KEY (`character_guid`, `week_start`),
    KEY `idx_week` (`week_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Great Vault PvP row: wins per character and week';

-- dc_player_seasonal_stats.weekly_dungeon_bosses_killed: the dungeon and raid
-- bosses killed this week, which unlock the weekly chest's slots (1 / 4 / 10).
-- Slots read the season total before. SeasonalRewardSystem.cpp works without
-- the column, but then the week's count is lost on restart.
SET @has_tbl := (SELECT EXISTS (SELECT 1 FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_seasonal_stats'));
SET @has_col := (SELECT EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_seasonal_stats' AND `COLUMN_NAME` = 'weekly_dungeon_bosses_killed'));
SET @stmt := IF(@has_tbl = 1 AND @has_col = 0, 'ALTER TABLE `dc_player_seasonal_stats` ADD COLUMN `weekly_dungeon_bosses_killed` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `dungeon_bosses_killed`', 'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Weekly chests stored with nothing in them. The server no longer writes them
-- and the chest list skips them; these rows only bloat the table.
SET @has_chests := (SELECT EXISTS (SELECT 1 FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_seasonal_chests'));
SET @stmt := IF(@has_chests = 1, 'DELETE FROM `dc_player_seasonal_chests` WHERE `collected` = 0 AND `slot1_tokens` + `slot1_essence` + `slot2_tokens` + `slot2_essence` + `slot3_tokens` + `slot3_essence` = 0', 'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
