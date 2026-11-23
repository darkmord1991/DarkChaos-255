-- DarkChaos: two more columns for the combat meter's dc_bench_fight table
--
--   biggest_spell_hit   the largest single spell hit a creature landed on the character during the fight
--   biggest_spell_id    the spell that did it
-- Compared with max_health they show creature spells that scale out of proportion, per spell. The worldserver
-- checks for these columns at startup and on .reload config, and writes them only when they exist, so this file
-- can be applied before or after the new build is started.
--
-- MySQL has no ADD COLUMN IF NOT EXISTS, hence the guard: re-running changes nothing. Apply to acore_chars.

SET @has_col := (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_bench_fight' AND `COLUMN_NAME` = 'biggest_spell_hit' LIMIT 1);
SET @stmt := IF(@has_col IS NULL, 'ALTER TABLE `dc_bench_fight` ADD COLUMN `biggest_spell_hit` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `biggest_spell_id` INT UNSIGNED NOT NULL DEFAULT 0', 'DO 0');
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;
