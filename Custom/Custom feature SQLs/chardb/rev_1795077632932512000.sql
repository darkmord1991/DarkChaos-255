-- DC custom tables: make the live schema match the queries the DC scripts run.
--
-- A query naming a missing column or table aborts worldserver (MySQLConnection, errno 1054/1146);
-- the 2026-11-19 09:25 crash was one of these. The 2026-11-19 sweep found the tables below out of
-- step with their code. Every change only adds columns or defaults, except the statistics key, so
-- nothing that reads the existing columns changes behaviour.
--
-- Apply to the characters database (acore_chars). The last five blocks alter acore_world tables by
-- name. Every block checks first, so the file can be applied twice.
--
-- Columns the code writes are added as real columns. Required columns the code's INSERTs leave out
-- get a default; without one MySQL rejects the row (errno 1364, logged, row lost).
-- Columns the code only reads under another name are added as VIRTUAL generated columns over the
-- existing column, so the two can never disagree.

-- dc_character_dungeon_statistics: the code keeps one row per (guid, stat_name), but the key was
-- (guid) alone, so every counter of a character landed in the same row.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`KEY_COLUMN_USAGE`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_character_dungeon_statistics'
        AND `CONSTRAINT_NAME` = 'PRIMARY' AND `COLUMN_NAME` = 'stat_name'),
    'DO 0',
    'ALTER TABLE `dc_character_dungeon_statistics` '
    'DROP PRIMARY KEY, ADD PRIMARY KEY (`guid`, `stat_name`)') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_respec_history: ItemUpgradeAdvancedImpl RespecItem.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_respec_history'
        AND `COLUMN_NAME` = 'previous_level'),
    'DO 0',
    'ALTER TABLE `dc_respec_history` '
    'ADD COLUMN `previous_level` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `essence_refunded` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `tokens_refunded` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `item_entry` INT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `respec_at` BIGINT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_respec_log: ItemUpgradeAdvancedImpl RespecAll, GetRespecCooldown, GetRespecCountToday. The
-- cooldown and daily-limit reads run on every respec attempt, so the first attempt crashed.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_respec_log'
        AND `COLUMN_NAME` = 'timestamp'),
    'DO 0',
    'ALTER TABLE `dc_respec_log` '
    'ADD COLUMN `respec_type` VARCHAR(16) NOT NULL DEFAULT '''', '
    'ADD COLUMN `total_essence_refunded` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_tokens_refunded` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `action` VARCHAR(50) NOT NULL DEFAULT ''respec'' '
    'COMMENT ''respec, refund, reset, etc.'', '
    'MODIFY COLUMN `logged_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD KEY `idx_player_timestamp` (`player_guid`, `timestamp`)') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_player_achievements: ItemUpgradeAdvancedImpl AwardAchievement.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_achievements'
        AND `COLUMN_NAME` = 'earned_timestamp'),
    'DO 0',
    'ALTER TABLE `dc_player_achievements` '
    'ADD COLUMN `earned_timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_guild_upgrade_stats: ItemUpgradeAdvancedImpl UpdateGuildStats, GetGuildLeaderboard.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_guild_upgrade_stats'
        AND `COLUMN_NAME` = 'total_members'),
    'DO 0',
    'ALTER TABLE `dc_guild_upgrade_stats` '
    'ADD COLUMN `total_members` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `members_with_upgrades` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_guild_upgrades` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_items_upgraded` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `average_ilvl_increase` FLOAT NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_essence_invested` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `last_updated` BIGINT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_artifact_mastery_events: ItemUpgradeProgressionImpl NotifyMasteryRankUp, CheckTierUnlocks.
-- The code writes event_type 'RANK_UP' (matches 'rank_up', the collation ignores case) and
-- 'TIER_UNLOCK', which the enum did not have.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_artifact_mastery_events'
        AND `COLUMN_NAME` = 'timestamp'),
    'DO 0',
    'ALTER TABLE `dc_artifact_mastery_events` '
    'ADD COLUMN `new_rank` TINYINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `tier_unlocked` TINYINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `artifact_id` INT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `event_type` ENUM(''unlock'', ''level_up'', ''ability_gained'', '
    '''milestone_reached'', ''reset'', ''rank_up'', ''tier_unlock'') DEFAULT ''level_up''') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_player_tier_unlocks: ItemUpgradeProgressionImpl UnlockTier, CheckTierUnlocks.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_tier_unlocks'
        AND `COLUMN_NAME` = 'unlocked_timestamp'),
    'DO 0',
    'ALTER TABLE `dc_player_tier_unlocks` '
    'ADD COLUMN `unlocked_timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_player_tier_caps: ItemUpgradeProgressionImpl SetPlayerTierCap.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_tier_caps'
        AND `COLUMN_NAME` = 'last_updated'),
    'DO 0',
    'ALTER TABLE `dc_player_tier_caps` '
    'ADD COLUMN `last_updated` BIGINT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_upgrade_history: ItemUpgradeSeasonalImpl RecordUpgrade and the four history reads.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_upgrade_history'
        AND `COLUMN_NAME` = 'timestamp'),
    'DO 0',
    'ALTER TABLE `dc_upgrade_history` '
    'ADD COLUMN `item_id` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `upgrade_from` TINYINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `upgrade_to` TINYINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `token_cost` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `old_ilvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `new_ilvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `item_entry` INT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `upgrade_type` VARCHAR(50) NOT NULL DEFAULT ''tier'' '
    'COMMENT ''tier, stat, socket, enchant, etc.'', '
    'MODIFY COLUMN `upgraded_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD KEY `idx_player_timestamp` (`player_guid`, `timestamp`)') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_leaderboard_cache: ItemUpgradeSeasonalImpl UpdateLeaderboards, run at season start. It keeps
-- one row per (season, player). The table's own rank-based rows had no writer; their key stays, but
-- rank may now be NULL so the per-player rows do not collide on it.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_leaderboard_cache'
        AND `COLUMN_NAME` = 'player_guid'),
    'DO 0',
    'ALTER TABLE `dc_leaderboard_cache` '
    'ADD COLUMN `player_guid` INT UNSIGNED NULL DEFAULT NULL, '
    'ADD COLUMN `upgrade_rank` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `prestige_rank` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `efficiency_rank` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `last_updated` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `leaderboard_type` VARCHAR(50) NOT NULL DEFAULT ''upgrades'' '
    'COMMENT ''upgrades, tokens, mythic, pvp, etc.'', '
    'MODIFY COLUMN `rank` INT UNSIGNED NULL DEFAULT NULL, '
    'MODIFY COLUMN `entity_guid` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Player or guild GUID'', '
    'MODIFY COLUMN `cached_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `expires_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD UNIQUE KEY `uk_season_player` (`season_id`, `player_guid`)') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- dc_player_season_data: SeasonalSystem GetPlayerSeasonData, UpdatePlayerSeasonData. That code keeps
-- one row per player and does not write season_id, so its rows sit at season_id 0, apart from the
-- per-season rows the item upgrade code keeps.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_player_season_data'
        AND `COLUMN_NAME` = 'current_season_id'),
    'DO 0',
    'ALTER TABLE `dc_player_season_data` '
    'ADD COLUMN `current_season_id` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `joined_season_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `last_activity_at` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `total_seasons_played` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `seasons_completed` INT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `first_season_joined` BIGINT UNSIGNED NOT NULL DEFAULT 0, '
    'MODIFY COLUMN `season_id` INT UNSIGNED NOT NULL DEFAULT 0') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- acore_world from here on: reads that use other names for existing columns.
-- cs_dc_dungeonquests (.dcquests reward) reads token_amount and multiplier.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = 'acore_world' AND `TABLE_NAME` = 'dc_daily_quest_token_rewards'
        AND `COLUMN_NAME` = 'token_amount'),
    'DO 0',
    'ALTER TABLE `acore_world`.`dc_daily_quest_token_rewards` '
    'ADD COLUMN `token_amount` TINYINT UNSIGNED GENERATED ALWAYS AS (`token_count`) VIRTUAL, '
    'ADD COLUMN `multiplier` FLOAT GENERATED ALWAYS AS (`bonus_multiplier`) VIRTUAL') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = 'acore_world' AND `TABLE_NAME` = 'dc_weekly_quest_token_rewards'
        AND `COLUMN_NAME` = 'token_amount'),
    'DO 0',
    'ALTER TABLE `acore_world`.`dc_weekly_quest_token_rewards` '
    'ADD COLUMN `token_amount` TINYINT UNSIGNED GENERATED ALWAYS AS (`token_count`) VIRTUAL, '
    'ADD COLUMN `multiplier` FLOAT GENERATED ALWAYS AS (`bonus_multiplier`) VIRTUAL') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- The same command falls back to the first token definition: one token at x1 unless set otherwise.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = 'acore_world' AND `TABLE_NAME` = 'dc_quest_reward_tokens'
        AND `COLUMN_NAME` = 'token_amount'),
    'DO 0',
    'ALTER TABLE `acore_world`.`dc_quest_reward_tokens` '
    'ADD COLUMN `token_amount` INT UNSIGNED NOT NULL DEFAULT 1, '
    'ADD COLUMN `multiplier` FLOAT NOT NULL DEFAULT 1') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

-- SeasonalRewardManager::InitializeForSeason reads token_reward, essence_reward and creature_entry.
SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = 'acore_world' AND `TABLE_NAME` = 'dc_seasonal_quest_rewards'
        AND `COLUMN_NAME` = 'token_reward'),
    'DO 0',
    'ALTER TABLE `acore_world`.`dc_seasonal_quest_rewards` '
    'ADD COLUMN `token_reward` INT UNSIGNED GENERATED ALWAYS AS (IFNULL(`base_token_amount`, 0)) VIRTUAL, '
    'ADD COLUMN `essence_reward` INT UNSIGNED GENERATED ALWAYS AS '
    '(IFNULL(`base_essence_amount`, 0)) VIRTUAL') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;

SELECT IF(EXISTS(SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = 'acore_world' AND `TABLE_NAME` = 'dc_seasonal_creature_rewards'
        AND `COLUMN_NAME` = 'token_reward'),
    'DO 0',
    'ALTER TABLE `acore_world`.`dc_seasonal_creature_rewards` '
    'ADD COLUMN `creature_entry` INT UNSIGNED GENERATED ALWAYS AS (`creature_id`) VIRTUAL, '
    'ADD COLUMN `token_reward` INT UNSIGNED GENERATED ALWAYS AS (IFNULL(`base_token_amount`, 0)) VIRTUAL, '
    'ADD COLUMN `essence_reward` INT UNSIGNED GENERATED ALWAYS AS '
    '(IFNULL(`base_essence_amount`, 0)) VIRTUAL') INTO @stmt;
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;
