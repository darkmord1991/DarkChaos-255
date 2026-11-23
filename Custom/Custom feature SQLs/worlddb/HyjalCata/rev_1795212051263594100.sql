-- Fiery Behemoth (7352289, map 750 Hyjal, level 129 elite, 12 spawns) had 10x health and 4.6x melee damage, the
-- values of the single-spawn Firelands rares (Andrazor, Searris, Fah Jarakk, Kelbnar). Its spawns stand inside the
-- Sethria's Roost and "Rage Against the Flames" objective areas (MinLevel 110, one 12 yd from an objective). Bots of
-- 113-130 died in 76% of their fights with it, about 160-210 deaths a day since 2026-11-17 (dc_bench_fight). The Cata
-- original (52289) had 1.0x damage. It now matches the zone's ordinary hostile elites (Barrow Deeps Watcher, Ironbark
-- Ancient). Fire Nova (97721, a fixed 19,500-20,500) is not scaled by DamageModifier and stays as it is.
UPDATE `creature_template` SET `HealthModifier` = 4.19285, `DamageModifier` = 2.1017 WHERE `entry` = 7352289;
