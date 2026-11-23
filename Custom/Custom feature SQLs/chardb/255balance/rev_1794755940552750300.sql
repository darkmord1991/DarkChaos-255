-- DarkChaos: per-spell damage of the balance damage meter (src/server/scripts/DC/Benchmark/dc_combat_meter.cpp)
--
-- One row per spell, pet and minion of every fight the meter records in dc_bench_fight: what the character
-- (source 0), its pet (1) or one of its minions (2, e.g. a totem or a summoned guardian, with its creature
-- entry) dealt with that spell. spell_id 0 is a melee swing; 4294967295 lumps everything past the first 40
-- spells of a long fight. The meter writes it only while the table exists (checked at startup and config
-- reload), so this file can be applied at any time. Rows grow with DC.Bench.Meter.SamplePct.

CREATE TABLE IF NOT EXISTS `dc_bench_spell` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `fight_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `run_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `guid` INT UNSIGNED NOT NULL DEFAULT 0,
    `is_bot` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `class` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `map` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `source` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `caster_entry` INT UNSIGNED NOT NULL DEFAULT 0,
    `spell_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `damage` INT UNSIGNED NOT NULL DEFAULT 0,
    `hits` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_run_class` (`run_id`, `class`, `spec`, `level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
