-- ---------------------------------------------------------------------------
-- 332  Map 750 creature HP + damage retune (supersedes 318_'s damage pass)
-- ---------------------------------------------------------------------------
-- 318_ moved the band to `exp = 2` and re-based DamageModifier to 1.5% of a
-- level-appropriate player's HP. It was not enough, and reading the core shows
-- why on both axes.
--
-- ---------------------------------------------------------------------------
-- WHAT THE CORE ACTUALLY DOES  (read, not assumed)
-- ---------------------------------------------------------------------------
--   HP      Creature.cpp:1513-1516
--             basehp = CreatureBaseStats::GenerateHealth()   -- CreatureData.h:313
--                    = BaseHealth[exp] * HealthModifier
--             health = basehp * _GetHealthMod(rank)
--
--   DAMAGE  Creature.cpp:1538-1541
--             basedamage = GenerateBaseDamage()              -- CreatureData.h:332
--                        = BaseDamage[exp]        <- NOTE: NO modifier here
--             weapon min = basedamage, max = basedamage * 1.5
--           StatSystem.cpp:1169  applies DamageModifier to that weapon damage
--           ObjectMgr.cpp:1216   pre-multiplies DamageModifier by
--                                _GetDamageMod(rank) at load time
--
-- 🔴 `_GetHealthMod` / `_GetDamageMod` read Rate.Creature.* from the config, and
-- every one of those is 1.0 in worldserver.conf.dist with NO DarkChaos override.
-- So the rank multiplier is currently a no-op and the arithmetic is clean:
--
--     HP           = BaseHealth[2]  * HealthModifier
--     avg swing    = BaseDamage[2]  * DamageModifier * 1.25
--                    (1.25 = the average of the min .. min*1.5 weapon spread)
--
-- If you ever set those Rate.Creature.* values away from 1.0, this file's
-- targets shift by the same factor -- re-derive rather than guess.
--
-- ---------------------------------------------------------------------------
-- WHY IT STILL FELT WEAK -- 318_ NEVER TOUCHED HealthModifier
-- ---------------------------------------------------------------------------
-- 318_ changed `exp` and `DamageModifier`. HealthModifier was left exactly as
-- the Cata import left it, so the only HP gain was the incidental one from
-- BaseHealth[0] -> BaseHealth[2] (about 2.4x). Measured on the live DB:
--
--   Antilos (3606648) level 91, rank 4 RARE, HealthModifier 1.25
--     HP        = 21,288 * 1.25          =  26,610
--     a level-91 player has              =  18,799
--     -> a RARE with 1.4x a player's HP.
--     avg swing = 275.489 * 0.9969 * 1.25 = 343, i.e. ~1.8% of player HP
--     -> roughly 55 unanswered swings to kill the player.
--
-- 🔴 And Antilos is NOT an outlier: of the 37 rank-4 rares in the band, **35
-- still sit at HealthModifier 1-3**. Rares were never given a HP identity at
-- all -- they are normal mobs with a silver dragon. Same story for the 1,284
-- rank-0 normals sitting at 1-3.
--
-- ---------------------------------------------------------------------------
-- THE MODEL
-- ---------------------------------------------------------------------------
-- Both axes are expressed against the same-level player, which is the only
-- frame that stays meaningful across an 80->130 band:
--
--     HP      = <HP_X>  x a same-level player's health
--     damage  = <DMG_%> of a same-level player's health, per average swing
--
-- The player curve `13134 + (level-80)*515` is 318_'s and it was CHECKED against
-- live characters, not trusted: level 131 modelled 39,399 vs 39,396 actual.
--
-- The ladder must stay MONOTONIC: normal < rare < elite < rare elite < boss.
--
--   rank                     HP x player      avg swing
--   0  normal                     2.5             4.5%
--   4  rare                        5              6%
--   1  elite                       8              7.5%
--   2  rare elite                 25             11%
--   3  world boss                 60             15%
--
-- 🔴 The rare row was 15 / 9% when this file first ran, which put a soloable
-- silver-dragon rare ABOVE the group-content elite: Antilos got 282K HP standing
-- next to 48K normals. Rank 4 is `CREATURE_ELITE_RARE` (silver, NON-elite) and
-- rank 1 is `CREATURE_ELITE_ELITE` (gold, group) -- the constant names read as if
-- rare outranks elite, and it does not. Corrected by 333_.
--
-- Antilos under the corrected model: ~96,600 HP (from 26,610) and ~1,130 per
-- swing (from 343) -- still 3.6x the health that made him die instantly, but a
-- ~25 second solo fight rather than a slog.
--
-- 🔴 THESE ARE THE TUNING KNOBS. They are the @variables directly below; change
-- them and re-run. Nothing else in the file needs editing.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS SAFE TO RE-RUN, AND WHY IT ONLY EVER RAISES
-- ---------------------------------------------------------------------------
-- The new modifier is computed from an ABSOLUTE target (level, class, rank), not
-- by multiplying what is already there. Re-running therefore lands on the same
-- number instead of compounding -- unlike a naive `SET x = x * 1.5`.
--
-- 🔴 Every write is wrapped in GREATEST(current, computed), so this pass can only
-- raise a creature, never lower one. That is deliberate and load-bearing: the
-- band contains hand-placed lore NPCs that are meant to be unkillable, and a
-- formula would quietly destroy them --
--
--   Deathwing (3639867)   HealthModifier 10000 ->  997,030,000 HP
--   Thrall    (3654313)                   1200 ->  119,643,600 HP
--   Malfurion (3652135)                    500 ->   53,629,500 HP
--
-- Those are correct. Flattening them to "60x a player" would make Deathwing
-- killable by a party. GREATEST leaves all of them untouched.
--
-- Reversal is still possible: the pre-change values are snapshotted in
-- `dc_creature_stat_rebalance_backup` before anything is written (see the
-- trailer for the restore statement).
--
-- Apply against acore_world. Idempotent. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 0. Tuning knobs
-- ---------------------------------------------------------------------------
SET @hp_normal     := 2.5;    SET @dmg_normal     := 0.045;
SET @hp_elite      := 8.0;    SET @dmg_elite      := 0.075;
SET @hp_rareelite  := 25.0;   SET @dmg_rareelite  := 0.110;
SET @hp_boss       := 60.0;   SET @dmg_boss       := 0.150;
-- 🔴 5.0 / 0.060, NOT the 15.0 / 0.090 this file originally shipped. Rank 4 is
-- the SILVER dragon (non-elite, soloable); 15x put it above the rank-1 ELITE at
-- 8x and produced a 282K rare standing next to 48K normals. Corrected by 333_,
-- which had to restore from the backup to undo it -- GREATEST cannot lower.
-- Keep these two numbers in sync with 333_ or a re-run of this file silently
-- re-inflates every rare.
SET @hp_rare       := 5.0;    SET @dmg_rare       := 0.060;

-- The weapon spread from Creature.cpp:1541 (min .. min*1.5), averaged.
SET @swing_spread  := 1.25;

-- ---------------------------------------------------------------------------
-- 1. Snapshot the current values, ONCE
-- ---------------------------------------------------------------------------
-- 🔴 INSERT IGNORE, and deliberately NO `DELETE` before it. The usual DC rule is
-- "every INSERT gets a matching DELETE for idempotency", but here the DELETE
-- would be the bug: on a second run it would overwrite the true originals with
-- the already-rebalanced values and make the restore below a no-op. The PRIMARY
-- KEY on `entry` gives the idempotency instead.
CREATE TABLE IF NOT EXISTS `dc_creature_stat_rebalance_backup` (
  `entry`           INT UNSIGNED NOT NULL,
  `HealthModifier`  FLOAT NOT NULL,
  `DamageModifier`  FLOAT NOT NULL,
  `captured_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_creature_stat_rebalance_backup` (`entry`, `HealthModifier`, `DamageModifier`)
SELECT `entry`, `HealthModifier`, `DamageModifier`
FROM `creature_template`
WHERE `entry` BETWEEN 3600000 AND 3799999;

-- ---------------------------------------------------------------------------
-- 2. Re-assert exp = 2
-- ---------------------------------------------------------------------------
-- A no-op if 318_ already ran, but the whole model below reads BaseHealth[2] and
-- BaseDamage[2]. If a later import dropped a creature in at exp 0, it would be
-- scaled against columns the core will not actually use for it.
UPDATE `creature_template`
SET `exp` = 2
WHERE `entry` BETWEEN 3600000 AND 3799999
  AND `minlevel` BETWEEN 80 AND 130
  AND `exp` <> 2;

-- ---------------------------------------------------------------------------
-- 3. The retune
-- ---------------------------------------------------------------------------
-- Excluded on purpose:
--   type 8/11/12  critters, totems and non-combat pets -- not combat content
--   unit_flags & 258  (0x2 NON_ATTACKABLE | 0x100 IMMUNE_TO_PC) -- friendly
--                     NPCs. Worth excluding explicitly because `rank` is known
--                     to be unreliable on these imports (vendors have come in
--                     as rank 3), and a rank-3 vendor would otherwise be handed
--                     world-boss health.
--   flags_extra & 128 CREATURE_FLAG_EXTRA_TRIGGER (CreatureData.h:53)
--   unit_flags & 0x2000000  UNIT_FLAG_NOT_SELECTABLE (UnitDefines.h:282)
--
-- 🔴 The trigger exclusion is not cosmetic. Without it the single biggest group
-- of rank-0 "creatures" this file would have buffed is the invisible script
-- bunnies -- `Wondi's Bunny - Firelands Forgeworks teleporter IN/OUT`,
-- `... - Summon Marion Wormwing - Object Cross Cast`, `Escape Winds` and friends.
-- They are faction 35, flags_extra 128, and exist only to be a spell target or a
-- teleport anchor. Handing them 39,272 HP and a 707-damage swing is meaningless
-- at best and a live hazard wherever a script actually lets one attack. 47 of the
-- 1,439 in-scope templates are triggers or unselectable; 1,392 remain.
--
-- NOT excluded, on purpose: the 164 faction-35 (Friendly) templates that are not
-- triggers. Players cannot attack them, so raising their stats is inert -- and
-- where one IS a fighting escort ally, surviving longer is the wanted outcome.
--
-- Joined on `minlevel`: a creature with a level RANGE gets one fixed modifier,
-- so scaling off the bottom of its range is the conservative end.
UPDATE `creature_template` ct
JOIN `creature_classlevelstats` cls
  ON cls.`level` = ct.`minlevel`
 AND cls.`class` = ct.`unit_class`
SET
  ct.`HealthModifier` = GREATEST(ct.`HealthModifier`,
      CASE ct.`rank`
        WHEN 0 THEN @hp_normal
        WHEN 1 THEN @hp_elite
        WHEN 2 THEN @hp_rareelite
        WHEN 3 THEN @hp_boss
        WHEN 4 THEN @hp_rare
        ELSE @hp_normal
      END * (13134 + (ct.`minlevel` - 80) * 515) / cls.`basehp2`),

  ct.`DamageModifier` = GREATEST(ct.`DamageModifier`,
      CASE ct.`rank`
        WHEN 0 THEN @dmg_normal
        WHEN 1 THEN @dmg_elite
        WHEN 2 THEN @dmg_rareelite
        WHEN 3 THEN @dmg_boss
        WHEN 4 THEN @dmg_rare
        ELSE @dmg_normal
      END * (13134 + (ct.`minlevel` - 80) * 515) / (cls.`damage_exp2` * @swing_spread))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`minlevel` BETWEEN 80 AND 130
  AND ct.`type` NOT IN (8, 11, 12)
  AND (ct.`unit_flags` & 258) = 0
  AND (ct.`flags_extra` & 128) = 0
  AND (ct.`unit_flags` & 33554432) = 0
  AND cls.`basehp2` > 0
  AND cls.`damage_exp2` > 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Antilos, the creature that started this (expect ~282,000 HP and ~1,690 avg
-- swing, from 26,610 and 343):
-- SELECT ct.entry, ct.name, ct.minlevel, ct.`rank`,
--        ROUND(cls.basehp2 * ct.HealthModifier) AS hp,
--        ROUND(cls.damage_exp2 * ct.DamageModifier * 1.25) AS avg_swing,
--        ROUND(cls.basehp2 * ct.HealthModifier / (13134 + (ct.minlevel-80)*515), 1) AS x_player_hp,
--        ROUND(100 * cls.damage_exp2 * ct.DamageModifier * 1.25
--              / (13134 + (ct.minlevel-80)*515), 1) AS pct_player_hp_per_swing
-- FROM creature_template ct
-- JOIN creature_classlevelstats cls ON cls.level = ct.minlevel AND cls.class = ct.unit_class
-- WHERE ct.entry = 3606648;
--
-- Per-rank medians -- x_player_hp should land on the target table above for every
-- rank EXCEPT where GREATEST kept a bigger hand-authored value:
-- SELECT ct.`rank`, COUNT(*) AS n,
--        ROUND(AVG(cls.basehp2 * ct.HealthModifier
--                  / (13134 + (ct.minlevel-80)*515)), 1) AS avg_x_player_hp,
--        ROUND(AVG(100 * cls.damage_exp2 * ct.DamageModifier * 1.25
--                  / (13134 + (ct.minlevel-80)*515)), 1) AS avg_pct_per_swing
-- FROM creature_template ct
-- JOIN creature_classlevelstats cls ON cls.level = ct.minlevel AND cls.class = ct.unit_class
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.minlevel BETWEEN 80 AND 130
--   AND ct.type NOT IN (8,11,12) AND (ct.unit_flags & 258) = 0
--   AND (ct.flags_extra & 128) = 0 AND (ct.unit_flags & 33554432) = 0
-- GROUP BY ct.`rank` ORDER BY ct.`rank`;
--
-- 🔴 Creatures the JOIN could not reach -- these got NOTHING and are invisible
-- unless you look. A non-zero count means a template carries a `unit_class` with
-- no `creature_classlevelstats` row (valid values are 1, 2, 4, 8):
-- SELECT ct.entry, ct.name, ct.minlevel, ct.unit_class FROM creature_template ct
-- LEFT JOIN creature_classlevelstats cls
--        ON cls.level = ct.minlevel AND cls.class = ct.unit_class
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.minlevel BETWEEN 80 AND 130
--   AND ct.type NOT IN (8,11,12) AND (ct.unit_flags & 258) = 0
--   AND (ct.flags_extra & 128) = 0 AND (ct.unit_flags & 33554432) = 0
--   AND cls.level IS NULL;
--
-- Nothing was nerfed (expect 0 rows -- GREATEST should make this impossible):
-- SELECT ct.entry, ct.name, b.HealthModifier AS was, ct.HealthModifier AS now
-- FROM creature_template ct JOIN dc_creature_stat_rebalance_backup b ON b.entry = ct.entry
-- WHERE ct.HealthModifier < b.HealthModifier OR ct.DamageModifier < b.DamageModifier;
--
-- TO REVERT completely:
-- UPDATE creature_template ct JOIN dc_creature_stat_rebalance_backup b ON b.entry = ct.entry
-- SET ct.HealthModifier = b.HealthModifier, ct.DamageModifier = b.DamageModifier;
--
-- 🔴 TO TUNE FURTHER, edit the @variables and re-run -- do NOT multiply the
-- current values. The targets are absolute, so a re-run converges; a multiply
-- compounds and there is no way back to the intended number.
--
-- 🔴 One-way ratchet: because every write is GREATEST, LOWERING a target and
-- re-running does nothing. To reduce, restore from the backup first (statement
-- above), then re-run with the smaller numbers.
-- ---------------------------------------------------------------------------
