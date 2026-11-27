-- DarkChaos: four more columns for the combat meter's dc_bench_fight table
--
--   spell_power    the character's spell power (magic schools) when the fight started
--   attack_power   attack power when the fight started: ranged for hunters, melee for everyone else
--   spell_crit     spell crit chance in percent, the best magic school
--   physical_crit  melee crit chance in percent (ranged for hunters)
-- Read against the per-spell damage in dc_bench_spell they show whether a spell rank above level 80 falls short
-- because of its numbers or because the character's spell power and crit do not grow as the rank generator
-- assumes. The worldserver checks for these columns at startup and on .reload config and writes them only when
-- they exist, so this file can be applied before or after the new build.
--
-- MySQL has no ADD COLUMN IF NOT EXISTS, hence the guard: re-running changes nothing. Apply to acore_chars.

SET @has_col := (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_bench_fight' AND `COLUMN_NAME` = 'physical_crit' LIMIT 1);
SET @stmt := IF(@has_col IS NULL, 'ALTER TABLE `dc_bench_fight` ADD COLUMN `spell_power` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `attack_power` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_crit` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `physical_crit` DECIMAL(5,2) NOT NULL DEFAULT 0', 'DO 0');
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;
