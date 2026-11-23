-- DarkChaos: three more columns for the combat meter's dc_bench_fight table
--
--   damage_taken_players   the part of damage_taken that players (or their pets, totems and guardians) dealt
--   killer_type            the killing blow: 0 none seen, 1 creature, 2 player or what a player controls, 3 no attacker
--   killer_entry           the creature entry when killer_type is 1
-- On maps both factions share they separate world PvP from mob balance: a bot that dies in a PvE fight while enemy
-- players hit it counts against the mob otherwise. The worldserver checks for these columns at startup and on
-- .reload config and writes them only when they exist, so this file can be applied before or after the new build.
--
-- MySQL has no ADD COLUMN IF NOT EXISTS, hence the guard: re-running changes nothing. Apply to acore_chars.

SET @has_col := (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_bench_fight' AND `COLUMN_NAME` = 'killer_type' LIMIT 1);
SET @stmt := IF(@has_col IS NULL, 'ALTER TABLE `dc_bench_fight` ADD COLUMN `damage_taken_players` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `killer_type` TINYINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `killer_entry` INT UNSIGNED NOT NULL DEFAULT 0', 'DO 0');
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;
