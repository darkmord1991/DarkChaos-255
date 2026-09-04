-- ---------------------------------------------------------------------------
-- 333  Fix the rank hierarchy inversion 332_ introduced for RARES
-- ---------------------------------------------------------------------------
-- Reported from the game: Antilos (level 92 rare) shows 296K HP while the normal
-- mobs around it have ~45K. Both numbers are exactly what 332_ asked for, and
-- that is the bug -- 332_'s target table was wrong.
--
-- ---------------------------------------------------------------------------
-- THE INVERSION
-- ---------------------------------------------------------------------------
-- 332_ set, as a multiple of a same-level player's HP:
--
--     rank 0  normal        2.5
--     rank 1  elite         8
--     rank 4  RARE         15      <-- almost 2x an ELITE
--     rank 2  rare elite   25
--
-- Measured on the live DB afterwards, at levels 88-96:
--
--     normal        47,756
--     elite        138,032   (the 8x floor)
--     RARE        281,985    <-- 2.0x the elite floor, 5.9x a normal
--     rare elite   482,850   (the 25x floor)
--
-- 🔴 Rank 4 is `CREATURE_ELITE_RARE` -- the SILVER dragon, a NON-elite creature
-- meant to be soloable. Rank 1 is `CREATURE_ELITE_ELITE`, the gold dragon, which
-- is group content. WoW's hierarchy is
--
--     normal  <  rare  <  elite  <  rare elite  <  world boss
--
-- and 332_ placed rare ABOVE elite on both axes (HP 15 vs 8, damage 9% vs 7.5%).
-- A silver-dragon mob ended up tougher than the group content next to it.
--
-- Corrected, so the ladder is monotonic again:
--
--     rank                   HP x player       avg swing
--     0  normal                  2.5             4.5%     unchanged
--     4  rare                    5               6%       WAS 15 / 9%
--     1  elite                   8               7.5%     unchanged
--     2  rare elite             25              11%       unchanged
--     3  world boss             60              15%       unchanged
--
-- Antilos lands at ~96,600 at level 91 (~99K as displayed at 92). That is still
-- 3.6x its pre-332_ health of 26,610 -- the original "it dies instantly"
-- complaint stays fixed -- but it is a ~25 second solo fight instead of a slog,
-- and it now sits correctly between a normal and an elite.
--
-- ---------------------------------------------------------------------------
-- 🔴 WHY THIS NEEDS A RESTORE STEP AND CANNOT JUST RE-RUN 332_
-- ---------------------------------------------------------------------------
-- Every write in 332_ is `GREATEST(current, computed)` -- a one-way ratchet, so
-- it can only ever raise. Lowering @hp_rare and re-running it would do NOTHING:
-- GREATEST would keep the 15x value already in the table.
--
-- So this file restores rank 4 from `dc_creature_stat_rebalance_backup` first,
-- then re-applies the formula with the corrected targets. The restore is what
-- makes the reduction possible; the GREATEST on the re-apply is what keeps the
-- hand-authored rares safe, e.g.
--
--     Deth'tilac (3654322)  HealthModifier 1000 -> 107,259,000 HP at level 130
--
-- That is a deliberately brutal Molten Front rare. It goes back to 1000 from the
-- backup and GREATEST keeps it there, because 1000 > the 5x formula value.
--
-- 🔴 332_ HAS ALSO BEEN EDITED so its @hp_rare / @dmg_rare knobs now read 5.0 and
-- 0.060. If it still said 15, a later re-run of 332_ would silently ratchet every
-- rare straight back up and undo this file.
--
-- Apply against acore_world, AFTER 332_. Idempotent. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 0. Corrected rare targets
-- ---------------------------------------------------------------------------
SET @hp_rare      := 5.0;
SET @dmg_rare     := 0.060;
SET @swing_spread := 1.25;

-- ---------------------------------------------------------------------------
-- 1. Roll rank-4 rares back to their pre-332_ values
-- ---------------------------------------------------------------------------
-- 🔴 Guarded on the backup row existing. If 332_ was never applied there is
-- nothing to roll back and this is a no-op rather than a corruption.
UPDATE `creature_template` ct
JOIN `dc_creature_stat_rebalance_backup` b ON b.`entry` = ct.`entry`
SET ct.`HealthModifier` = b.`HealthModifier`,
    ct.`DamageModifier` = b.`DamageModifier`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`minlevel` BETWEEN 80 AND 130
  AND ct.`rank` = 4;

-- ---------------------------------------------------------------------------
-- 2. Re-apply with the corrected rare targets
-- ---------------------------------------------------------------------------
-- Same exclusions as 332_ -- critters/totems/non-combat pets, friendly and
-- immune NPCs, script-trigger bunnies (flags_extra 128) and unselectable units.
UPDATE `creature_template` ct
JOIN `creature_classlevelstats` cls
  ON cls.`level` = ct.`minlevel`
 AND cls.`class` = ct.`unit_class`
SET
  ct.`HealthModifier` = GREATEST(ct.`HealthModifier`,
      @hp_rare * (13134 + (ct.`minlevel` - 80) * 515) / cls.`basehp2`),

  ct.`DamageModifier` = GREATEST(ct.`DamageModifier`,
      @dmg_rare * (13134 + (ct.`minlevel` - 80) * 515)
      / (cls.`damage_exp2` * @swing_spread))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`minlevel` BETWEEN 80 AND 130
  AND ct.`rank` = 4
  AND ct.`type` NOT IN (8, 11, 12)
  AND (ct.`unit_flags` & 258) = 0
  AND (ct.`flags_extra` & 128) = 0
  AND (ct.`unit_flags` & 33554432) = 0
  AND cls.`basehp2` > 0
  AND cls.`damage_exp2` > 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- 🔴 THE ONE THAT MATTERS -- the ladder must be monotonic. avg_hp should now rise
-- with every step of normal -> rare -> elite -> rare elite:
-- SELECT ct.`rank`,
--   CASE ct.`rank` WHEN 0 THEN 'normal' WHEN 1 THEN 'elite' WHEN 2 THEN 'rare elite'
--                  WHEN 3 THEN 'world boss' WHEN 4 THEN 'rare' END AS label,
--   COUNT(*) AS n,
--   ROUND(MIN(cls.basehp2 * ct.HealthModifier)) AS floor_hp,
--   ROUND(AVG(100 * cls.damage_exp2 * ct.DamageModifier * 1.25
--             / (13134 + (ct.minlevel-80)*515)), 1) AS pct_per_swing
-- FROM creature_template ct
-- JOIN creature_classlevelstats cls ON cls.level = ct.minlevel AND cls.class = ct.unit_class
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.minlevel BETWEEN 88 AND 96
--   AND ct.type NOT IN (8,11,12) AND (ct.unit_flags & 258) = 0
--   AND (ct.flags_extra & 128) = 0 AND (ct.unit_flags & 33554432) = 0
-- GROUP BY ct.`rank` ORDER BY floor_hp;
--   expected floors at these levels: normal ~43K, rare ~91K, elite ~138K,
--   rare elite ~483K
--
-- Antilos specifically (expect HealthModifier ~5.1 and ~96,600 HP at level 91;
-- the client shows ~99K because he spawns at 91-92 and the modifier is fixed at
-- the bottom of that range):
-- SELECT ct.entry, ct.name, ct.minlevel, ct.maxlevel, ROUND(ct.HealthModifier,3) AS hm,
--        ROUND(cls.basehp2 * ct.HealthModifier) AS hp
-- FROM creature_template ct
-- JOIN creature_classlevelstats cls ON cls.level = ct.minlevel AND cls.class = ct.unit_class
-- WHERE ct.entry = 3606648;
--
-- Hand-authored brutal rares survived the round trip (Deth'tilac must still be
-- 1000, NOT ~5):
-- SELECT entry, name, minlevel, HealthModifier FROM creature_template
-- WHERE entry = 3654322;
--
-- No rare is now above the elite floor for its own level (expect 0 rows):
-- SELECT r.entry, r.name, r.minlevel,
--        ROUND(cr.basehp2 * r.HealthModifier) AS rare_hp
-- FROM creature_template r
-- JOIN creature_classlevelstats cr ON cr.level = r.minlevel AND cr.class = r.unit_class
-- WHERE r.entry BETWEEN 3600000 AND 3799999 AND r.`rank` = 4
--   AND r.HealthModifier < 100   -- exclude the hand-authored outliers
--   AND cr.basehp2 * r.HealthModifier
--       > 8.0 * (13134 + (r.minlevel-80)*515);
-- ---------------------------------------------------------------------------
