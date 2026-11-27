-- DarkChaos: combat ratings and attack outcomes for the combat meter's dc_bench_fight table
--
-- When the fight started (percent):
--   spell_haste, physical_haste   from haste rating only, no talents or buffs (physical: ranged for hunters)
--   spell_hit, physical_hit       bonus to hit from rating and talents (physical: ranged for hunters)
--   expertise                     off the target's dodge and parry chance
--   armor_pen                     from armor penetration rating
-- How the character's own attacks ended in the fight (pets and minions not counted):
--   swings, swing_crits, swing_misses, swing_dodges_parries, swing_glancing   main and off hand auto attacks
--   spell_attempts                damage spells (direct or over time) at a target not friendly to it
--   spell_misses, spell_resists, spell_dodges_parries, spell_other (immune, evade, reflect, absorb, deflect)
--   spell_direct_hits, spell_crits   landed spells with a direct damage effect, and how many of those crit
-- Combat ratings convert to less of a percentage with every level above 80; these show what that costs in
-- misses and crits. The worldserver checks for these columns at startup and on .reload config and writes them only
-- when they exist, so this file can be applied before or after the new build.
--
-- MySQL has no ADD COLUMN IF NOT EXISTS, hence the guard: re-running changes nothing. Apply to acore_chars.

SET @has_col := (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_bench_fight' AND `COLUMN_NAME` = 'spell_crits' LIMIT 1);
SET @stmt := IF(@has_col IS NULL, 'ALTER TABLE `dc_bench_fight` ADD COLUMN `spell_haste` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `physical_haste` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `spell_hit` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `physical_hit` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `expertise` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `armor_pen` DECIMAL(5,2) NOT NULL DEFAULT 0, ADD COLUMN `swings` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `swing_crits` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `swing_misses` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `swing_dodges_parries` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `swing_glancing` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_attempts` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_misses` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_resists` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_dodges_parries` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_other` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_direct_hits` SMALLINT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_crits` SMALLINT UNSIGNED NOT NULL DEFAULT 0', 'DO 0');
PREPARE `stmt` FROM @stmt;
EXECUTE `stmt`;
DEALLOCATE PREPARE `stmt`;
