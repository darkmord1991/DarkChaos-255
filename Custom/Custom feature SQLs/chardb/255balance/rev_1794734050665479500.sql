-- DarkChaos: table for the server-side combat meter (src/server/scripts/DC/Benchmark/dc_combat_meter.cpp)
--
-- One row per finished fight of a player or playerbot, written while DC.Bench.Meter.Enable = 1.
--   run_id             DC.Bench.Meter.RunId at the time; raise it before a test run to compare before and after
--   spec               talent tree with the most points (0-2)
--   target_*           the creature with the most health among those hit (the boss in a boss fight)
--   duration_ms        first to last hit
--   damage_player      dealt by the character itself; damage_pet by its permanent pet; damage_minion by totems,
--                      guardians and charmed creatures. Overkill is not counted.
--   healing_done       effective healing by the character and everything it owns, during the fight
--   damage_taken       taken by the character; max_health is its maximum health when the fight ended
-- Ready-made reports (pet share per spec, time to kill per zone) are in tools/balance/bench_reports.sql.
--
-- Apply to acore_chars before switching the meter on. Re-running changes nothing.

CREATE TABLE IF NOT EXISTS `dc_bench_fight` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `fight_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `run_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `guid` INT UNSIGNED NOT NULL DEFAULT 0,
  `is_bot` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `class` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `item_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `group_size` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `map` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `zone` INT UNSIGNED NOT NULL DEFAULT 0,
  `target_entry` INT UNSIGNED NOT NULL DEFAULT 0,
  `target_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `target_rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `target_max_health` INT UNSIGNED NOT NULL DEFAULT 0,
  `duration_ms` INT UNSIGNED NOT NULL DEFAULT 0,
  `damage_player` INT UNSIGNED NOT NULL DEFAULT 0,
  `damage_pet` INT UNSIGNED NOT NULL DEFAULT 0,
  `damage_minion` INT UNSIGNED NOT NULL DEFAULT 0,
  `healing_done` INT UNSIGNED NOT NULL DEFAULT 0,
  `damage_taken` INT UNSIGNED NOT NULL DEFAULT 0,
  `max_health` INT UNSIGNED NOT NULL DEFAULT 0,
  `died` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_run_class` (`run_id`, `class`, `spec`, `level`),
  KEY `idx_run_zone` (`run_id`, `map`, `zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
