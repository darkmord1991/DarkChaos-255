-- 2025_12_13_00_dc_player_upgrade_tokens_season_pk.sql
--
-- Fix ItemUpgrades currency storage to be truly season-scoped.
--
-- Why:
-- - Code reads/writes rows filtered by (player_guid, currency_type, season)
-- - If the PK is only (player_guid, currency_type), ON DUPLICATE KEY UPDATE will merge seasons
--   and the season column won’t update, causing GetCurrency(..., season) to return 0.
--
-- Safe migration note:
-- - With the old PK, there can only be one row per (player_guid, currency_type), so this change
--   should not introduce key conflicts.

ALTER TABLE `dc_player_upgrade_tokens`
  MODIFY `season` INT UNSIGNED NOT NULL DEFAULT 1;

ALTER TABLE `dc_player_upgrade_tokens`
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`player_guid`, `currency_type`, `season`);

-- Optional: keep season index if you often query/aggregate by season.
-- (Existing installs may already have this index.)
CREATE INDEX `idx_season` ON `dc_player_upgrade_tokens` (`season`);
