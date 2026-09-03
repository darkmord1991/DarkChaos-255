-- ---------------------------------------------------------------------------
-- 318  Maps 750/751/861 -- move above-80 creatures onto the WotLK stat column
-- ---------------------------------------------------------------------------
-- Reported 2026-09-02: a level 91-92 named rare (Antilos, 3606648) dies twice
-- in a row without trouble. 315_ already fixed the CURVE; this file fixes the
-- COLUMN, which is the lever 315_ deliberately left on the table.
--
-- WHY. `CreatureBaseStats` is indexed by `creature_template.exp`:
--     CreatureData.h:315  GenerateHealth     = BaseHealth[expansion] * ModHealth
--     CreatureData.h:334  GenerateBaseDamage = BaseDamage[expansion]
-- `creature_classlevelstats` carries three of each -- basehp0/1/2 and
-- damage_base/exp1/exp2 -- for Classic / TBC / WotLK. **1,750 of the 1,983
-- above-80 creatures in the 36xxxxx band are still exp = 0**, i.e. the CLASSIC
-- column, on continents that are entirely level 80+ content. Only 233 are on
-- exp = 2 today.
--
-- Antilos measured live (level 91, rank 4, HealthModifier 1.25):
--     exp 0 -> basehp0  8,633 -> 10,791 HP ; damage_base  71.8
--     exp 2 -> basehp2 21,288 -> 26,610 HP ; damage_exp2 275.5
-- i.e. x2.47 HP and x3.84 damage from one column.
--
-- exp = 2 IS THE CEILING. MAX_EXPANSIONS is 3, and ObjectMgr.cpp:1204 silently
-- resets anything higher to 0 -- so exp = 3 would make these mobs WEAKER, not
-- stronger. There is no fourth column to move to; past this point the only
-- remaining levers are ModHealth / DamageModifier and the classlevelstats
-- curve itself (315_).
--
-- ---------------------------------------------------------------------------
-- HP AND DAMAGE NEED DIFFERENT TREATMENT, AND `exp` MOVES BOTH TOGETHER
-- ---------------------------------------------------------------------------
-- HP: exp = 2 is right everywhere. x2.36 at level 80 rising to x2.63 at 160.
--
-- DAMAGE: raw exp = 2 is wrong in SHAPE, not merely in size, because 315_'s x5
-- damage ramp already bent that curve. Measured against live player health
-- (13,134 HP at 80, 22,472 at 105, 39,396 at 131 -- ~515 HP per level), raw
-- exp = 2 hits for **1.3% of player health at level 80 but 4.7% at 130**, so
-- the entry bands would stay soft while Hyjal became a wall. Taking it raw
-- cannot produce a consistent difficulty at any setting.
--
-- So this file sets exp = 2 for the health, then re-bases `DamageModifier` so
-- damage lands on a target curve instead of inheriting whatever exp = 2 gives.
-- Target is @dmg_pct of the level-appropriate player health per swing, set to
-- **1.5%** -- deliberately ~2x the WotLK trash norm of 0.82%, because the
-- brief was to make this content noticeably dangerous, not merely correct.
-- Resulting change vs. what mobs hit for TODAY:
--
--     level      80     91    106    113    120    130    160
--     HP        x2.36  x2.47  x2.53  x2.56  x2.57  x2.59  x2.63
--     damage    x4.17  x3.93  x2.80  x2.34  x1.93  x1.45  x1.62
--
-- The damage multiplier falls with level because 315_'s x5 damage ramp already
-- did most of the work at the top -- a FLAT 1.5% of player health is the point,
-- and the low bands simply had further to travel. Nothing gets weaker.
--
-- Solo play at level stays viable; sloppy pulls do not. Elites (rank 1, x1.0
-- damage mod but higher HP) and the 43 named rares become genuinely dangerous.
--
-- RETUNING: change @dmg_pct ONLY. The file re-bases from the backup table
-- every run, so it is idempotent and re-runnable at a new value -- it never
-- compounds. 0.010 is "WotLK-plus", 0.020 is group content.
--
-- To take raw exp = 2 damage instead (no compensation at all), skip step 3.
--
-- ---------------------------------------------------------------------------
-- SCOPE
-- ---------------------------------------------------------------------------
-- Entries 3600000-3799999 with maxlevel >= 80, excluding critters (8), totems
-- (11) and non-combat pets (12). That band spawns on exactly three maps and
-- nowhere else -- verified live: 750 (12,849 spawns), 751 (4,230), 861 (1,160).
-- So unlike 315_ this is NOT a global change: Naxxramas (533), Ulduar (603),
-- ICC (631) and BWD (669) share the classlevelstats table but not these
-- templates, and are untouched.
--
-- Affected: 1,992 templates in scope. 1,750 of them change `exp` (43 named
-- rares, 8 bosses, 12 rare elites, 211 elites, 1,476 normal); the 233 already
-- on exp = 2 keep it and get only the damage re-base, which is what puts every
-- creature on the continent on one damage curve rather than two.
--
-- 🔴 THIS COVERS MAPS 751 AND 861 AS WELL AS 750 -- the 36xxxxx band is shared
-- by all three DC continents and cannot be split by entry. That is deliberate
-- (they have the same problem), but it means Lordaeron/Plaguelands and Molten
-- Front change in the same pass. To stage map 750 alone, add to every statement:
--     AND ct.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750)
-- and re-run this file later without it -- the backup table makes that safe.
--
-- `DamageModifier` is a clean final multiplier on creature melee damage
-- (StatSystem.cpp:1169); ObjectMgr.cpp:1216 folds the rank mod into the
-- in-memory copy at load, so the raw DB value written here is the right one.
--
-- Apply against acore_world. Idempotent. Needs a worldserver restart (or
-- `.reload creature_template`) AND a respawn -- stats are picked at SelectLevel.
-- ---------------------------------------------------------------------------

USE `acore_world`;

SET @dmg_pct := 0.015;

-- ---------------------------------------------------------------------------
-- 1. Backup -- taken ONCE, and it is what makes step 3 idempotent
-- ---------------------------------------------------------------------------
-- Deliberately INSERT IGNORE against a frozen snapshot rather than re-reading
-- the live column: re-running this file must re-base DamageModifier from its
-- ORIGINAL value, not from the value the previous run wrote.
CREATE TABLE IF NOT EXISTS `dc_creature_exp_rebalance_backup` (
  `entry`       INT UNSIGNED NOT NULL PRIMARY KEY,
  `old_exp`     TINYINT      NOT NULL,
  `old_dmg_mod` FLOAT        NOT NULL,
  `taken_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_creature_exp_rebalance_backup` (`entry`, `old_exp`, `old_dmg_mod`)
SELECT ct.`entry`, ct.`exp`, ct.`DamageModifier`
FROM `creature_template` ct
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`maxlevel` >= 80
  AND ct.`type` NOT IN (8, 11, 12);

-- ---------------------------------------------------------------------------
-- 2. The column move
-- ---------------------------------------------------------------------------
UPDATE `creature_template` ct
JOIN `dc_creature_exp_rebalance_backup` b ON b.`entry` = ct.`entry`
SET ct.`exp` = 2
WHERE ct.`exp` <> 2;

-- ---------------------------------------------------------------------------
-- 3. Damage re-base
-- ---------------------------------------------------------------------------
-- factor = target_damage(level) / damage_exp2(level, class), applied to the
-- ORIGINAL DamageModifier so relative differences between templates survive
-- (a mob authored at DamageModifier 2.0 still hits twice as hard as its peer).
--
-- Level is the midpoint of the template's own range. `unit_class` picks the
-- right classlevelstats row -- warriors and casters have different curves and
-- assuming class 1 for everything would mis-scale every caster on the map.
--
-- Guards: damage_exp2 = 0 rows are skipped by the JOIN condition rather than
-- dividing by zero, and the factor is clamped to [0.05, 5.0] so a stray
-- template with an extreme authored DamageModifier cannot produce a nonsense
-- value.
UPDATE `creature_template` ct
JOIN `dc_creature_exp_rebalance_backup` b ON b.`entry` = ct.`entry`
JOIN `creature_classlevelstats` s
      ON s.`level` = LEAST(255, GREATEST(80, ROUND((ct.`minlevel` + ct.`maxlevel`) / 2)))
     AND s.`class` = ct.`unit_class`
     AND s.`damage_exp2` > 0
SET ct.`DamageModifier` = ROUND(
      b.`old_dmg_mod` * LEAST(5.0, GREATEST(0.05,
        (@dmg_pct * (13134 + (LEAST(255, GREATEST(80, ROUND((ct.`minlevel` + ct.`maxlevel`) / 2))) - 80) * 515))
        / s.`damage_exp2`)), 4);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Nothing left on the Classic column (expect 0):
-- SELECT COUNT(*) FROM creature_template
-- WHERE entry BETWEEN 3600000 AND 3799999 AND maxlevel >= 80
--   AND type NOT IN (8, 11, 12) AND exp <> 2;
--
-- Antilos before/after (expect exp 2, DamageModifier ~0.997, ~27,955 HP):
-- SELECT entry, name, minlevel, maxlevel, exp, DamageModifier, HealthModifier
-- FROM creature_template WHERE entry = 3606648;
--
-- Effective HP and swing damage per band, against the player-health model:
-- SELECT ez.zone, COUNT(*) mobs,
--        ROUND(AVG(s.basehp2 * ct.HealthModifier)) avg_hp,
--        ROUND(AVG(s.damage_exp2 * ct.DamageModifier), 1) avg_dmg
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- JOIN creature_classlevelstats s
--   ON s.level = LEAST(255, GREATEST(80, ROUND((ct.minlevel + ct.maxlevel) / 2)))
--  AND s.class = ct.unit_class
-- WHERE ct.rank = 0 GROUP BY ez.zone ORDER BY avg_dmg;
--
-- ROLLBACK (restores both columns exactly):
-- UPDATE creature_template ct JOIN dc_creature_exp_rebalance_backup b
--   ON b.entry = ct.entry
-- SET ct.exp = b.old_exp, ct.DamageModifier = b.old_dmg_mod;
-- ---------------------------------------------------------------------------
