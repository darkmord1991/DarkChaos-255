-- Reports over acore_chars.dc_bench_fight, the table the server-side combat meter fills
-- (src/server/scripts/DC/Benchmark/dc_combat_meter.cpp; switch it on with DC.Bench.Meter.Enable = 1).
--
-- These are read-only queries to run by hand; nothing here is applied to the server. Set @run to the
-- DC.Bench.Meter.RunId of the test run to look at. To compare two balance revisions, run a report once per
-- run id and put the results side by side.
--
-- Class ids: 1 warrior, 2 paladin, 3 hunter, 4 rogue, 5 priest, 6 death knight, 7 shaman, 8 mage, 9 warlock,
-- 11 druid. spec is the talent tree with the most points (0, 1 or 2 in the order of the talent window).

SET @run = 0;

-- 1. Pet share of owner damage, per class, spec and level band.
--    The rule to hold: the share at each band stays close to the 71-80 row of the same spec.
SELECT `class`, `spec`,
       CONCAT(FLOOR((`level` - 1) / 10) * 10 + 1, '-', FLOOR((`level` - 1) / 10) * 10 + 10) AS `level_band`,
       COUNT(*) AS `fights`,
       ROUND(100 * SUM(`damage_pet`) / SUM(`damage_player` + `damage_pet` + `damage_minion`), 1) AS `pet_share_pct`,
       ROUND(100 * SUM(`damage_minion`) / SUM(`damage_player` + `damage_pet` + `damage_minion`), 1) AS `minion_share_pct`
FROM `dc_bench_fight`
WHERE `run_id` = @run AND `class` IN (3, 6, 8, 9) AND (`damage_player` + `damage_pet` + `damage_minion`) > 0
GROUP BY `class`, `spec`, FLOOR((`level` - 1) / 10)
ORDER BY `class`, `spec`, FLOOR((`level` - 1) / 10);

-- 2. Solo kills per class and level band: time to kill, damage per second, health lost per kill, deaths.
SELECT `class`,
       CONCAT(FLOOR((`level` - 1) / 10) * 10 + 1, '-', FLOOR((`level` - 1) / 10) * 10 + 10) AS `level_band`,
       COUNT(*) AS `fights`,
       ROUND(AVG(`duration_ms`) / 1000, 1) AS `avg_fight_sec`,
       ROUND(SUM(`damage_player` + `damage_pet` + `damage_minion`) / (SUM(`duration_ms`) / 1000)) AS `dps`,
       ROUND(100 * AVG(`damage_taken` / GREATEST(`max_health`, 1)), 1) AS `health_lost_pct`,
       ROUND(100 * AVG(`died`), 1) AS `death_pct`
FROM `dc_bench_fight`
WHERE `run_id` = @run AND `group_size` = 1 AND `target_rank` = 0 AND `target_entry` > 0
GROUP BY `class`, FLOOR((`level` - 1) / 10)
ORDER BY `class`, FLOOR((`level` - 1) / 10);

-- 3. Zones where solo fights go badly: long kills or frequent deaths (at least 20 fights).
SELECT `map`, `zone`, COUNT(*) AS `fights`,
       ROUND(AVG(`level`)) AS `avg_level`,
       ROUND(AVG(`duration_ms`) / 1000, 1) AS `avg_fight_sec`,
       ROUND(100 * AVG(`damage_taken` / GREATEST(`max_health`, 1)), 1) AS `health_lost_pct`,
       ROUND(100 * AVG(`died`), 1) AS `death_pct`
FROM `dc_bench_fight`
WHERE `run_id` = @run AND `group_size` = 1 AND `target_entry` > 0
GROUP BY `map`, `zone`
HAVING COUNT(*) >= 20
ORDER BY `death_pct` DESC, `avg_fight_sec` DESC
LIMIT 40;

-- 4. Healing against damage taken in groups, per class and level band (healers show up with a high ratio).
SELECT `class`, `spec`,
       CONCAT(FLOOR((`level` - 1) / 10) * 10 + 1, '-', FLOOR((`level` - 1) / 10) * 10 + 10) AS `level_band`,
       COUNT(*) AS `fights`,
       ROUND(SUM(`healing_done`) / (SUM(`duration_ms`) / 1000)) AS `hps`,
       ROUND(100 * AVG(`healing_done` / GREATEST(`max_health`, 1)), 1) AS `healing_per_fight_pct_of_own_health`
FROM `dc_bench_fight`
WHERE `run_id` = @run AND `group_size` > 1 AND `healing_done` > 0
GROUP BY `class`, `spec`, FLOOR((`level` - 1) / 10)
ORDER BY `class`, `spec`, FLOOR((`level` - 1) / 10);

-- 5. Where a spec's damage comes from (needs the dc_bench_spell table): share of each spell, pet or minion in the
--    spec's total damage, per level band. source 0 = the character, 1 = pet, 2 = minion (caster_entry names it:
--    a totem, a guardian); spell_id 0 = melee swing. Set @class and @spec (spec = tree with the most points, 0-2).
SET @class = 8, @spec = 2;
SELECT CONCAT(FLOOR((`level` - 1) / 10) * 10 + 1, '-', FLOOR((`level` - 1) / 10) * 10 + 10) AS `level_band`,
       `source`, `caster_entry`, `spell_id`,
       SUM(`damage`) AS `damage`, SUM(`hits`) AS `hits`,
       ROUND(SUM(`damage`) / SUM(`hits`)) AS `per_hit`,
       ROUND(100 * SUM(`damage`) / SUM(SUM(`damage`)) OVER (PARTITION BY FLOOR((`level` - 1) / 10)), 1) AS `share_pct`
FROM `dc_bench_spell`
WHERE `run_id` = @run AND `class` = @class AND `spec` = @spec
GROUP BY FLOOR((`level` - 1) / 10), `source`, `caster_entry`, `spell_id`
HAVING `share_pct` >= 2
ORDER BY FLOOR((`level` - 1) / 10), `damage` DESC;
