-- ---------------------------------------------------------------------------
-- 325  Map 750 -- re-level the creatures 233_ missed
-- ---------------------------------------------------------------------------
-- 322_ turned up "The Ongar" (3714345): a rank-4 named rare sitting at level 51
-- in Felwood, which is banded 96-106. Auditing the whole continent for the same
-- defect rather than fixing the one that happened to surface finds **14**
-- creatures below their zone band's floor, across 276 spawns:
--
--   zone band 88-98 (Ashenvale)
--     3603721 / 3703721  Mystlash Hydra        19-20  ->  89-90
--     3603928            Rotting Slime         20-22  ->  90-91
--     3633419 / 3733419  Tendril from Below    20-21  ->  90-91
--     3633444            Harbinger Aphotic     22     ->  91
--   zone band 96-106 (Felwood)
--     3747675            Bloodvenom Slimeslave 46-47  ->  97-98
--     3707086            Cursed Ooze           49-50  ->  99-100
--     3707092            Tainted Ooze          51-52  ->  101
--     3714345            The Ongar   (rank 4)  51     -> 107-108
--   zone band 104-115 (Winterspring)
--     3750312            Mana-Compelled Shade  54-55  ->  110
--     3750319            Dimensional Ooze      54-55  ->  110
--     3750322            Arcane Mana-Cluster   54-55  ->  110
--   zone band 113-128 (Hyjal)
--     3640134            Nightmare Terror      80     ->  113
--
-- ---------------------------------------------------------------------------
-- WHAT IS DELIBERATELY NOT TOUCHED
-- ---------------------------------------------------------------------------
-- 🔴 Being "below the band floor" is NOT by itself a defect. 153 templates
-- match that description and all but 14 are supposed to be there:
--
--   * `type` 8/11/12 (critter, totem, non-combat pet) -- Hyjal's rescued
--     animals are the clearest case: "Panicked Bunny", "Terrified Squirrel",
--     "Injured Fawn", "Anxious Doe", "Grotto Vole", "Ash Lizard",
--     "Darkshore Wisp", "Crystal Spider". They carry loot tables and would pass
--     a naive filter, but a level-113 Panicked Bunny is absurd. Excluded by
--     type, the same exclusion 318_ uses.
--   * `lootid = 0` -- bunnies, triggers, vehicle seats, kill-credit markers,
--     invisible stalkers, and lore NPCs (Onu, Aviana, Elderlimb, the three
--     Timbermaw Ancients, Gnarl). Nothing kills them for loot, so their level
--     is set-dressing.
--
-- So the filter is `lootid > 0 AND type NOT IN (8, 11, 12)` -- "something a
-- player kills and loots" -- not a name pattern, which would have been guesswork.
--
-- ---------------------------------------------------------------------------
-- THE LEVELS -- both rules come from the existing data, not from taste
-- ---------------------------------------------------------------------------
-- `dc_map750_band` stores the SOURCE band (s_lo/s_hi, the creature's classic
-- level range) alongside the TARGET band (t_lo/t_hi), which is exactly what
-- 233_ re-levelled against. Normal and elite creatures map linearly:
--
--     new = t_lo + (level - s_lo) * (t_hi - t_lo) / (s_hi - s_lo)   [clamped]
--
-- 🔴 RANK >= 2 IS DIFFERENT, and it is a measured pattern, not a preference.
-- Every rare/boss already re-levelled sits at exactly t_hi + 1 to t_hi + 2:
-- 80-90 bands hold rares at 91-92, 88-98 at 99-100, 96-106 at 107-108, 104-115
-- at 116-117, 113-128 at 129-130. The Ongar gets 107-108 for that reason --
-- the linear map would have given it 101, which is band-interior and would
-- leave it the only Felwood rare below its zone's ceiling.
--
-- ---------------------------------------------------------------------------
-- 🔴 RUN ORDER -- this file invalidates two others
-- ---------------------------------------------------------------------------
--   1. 325_ (this file)
--   2. re-run 318_  -- DamageModifier is re-based off the creature's LEVEL
--                      (it picks the classlevelstats row by level), so all 14
--                      carry a modifier computed for the level they used to be.
--                      318_ re-bases from its own backup and never compounds.
--   3. re-run 322_  -- The Ongar's loot promotion is currently the COALESCE
--                      fallback to its ZONE band (752096). At level 107-108 the
--                      real rule resolves to band 104, so it moves to 752104
--                      and stops being the one creature relying on a fallback.
--
-- Apply against acore_world. Idempotent -- absolute assignment derived from
-- columns this file does not write. Needs `.reload creature_template` (or a
-- restart) AND a respawn: level is picked in Creature::SelectLevel.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Backup, taken once
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_relevel_backup` (
  `entry`        INT UNSIGNED NOT NULL PRIMARY KEY,
  `old_minlevel` SMALLINT UNSIGNED NOT NULL,
  `old_maxlevel` SMALLINT UNSIGNED NOT NULL,
  `taken_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_relevel_backup` (`entry`, `old_minlevel`, `old_maxlevel`)
SELECT ct.`entry`, ct.`minlevel`, ct.`maxlevel`
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`maxlevel` < b.`t_lo`
  AND ct.`lootid` > 0
  AND ct.`type` NOT IN (8, 11, 12);

-- ---------------------------------------------------------------------------
-- 2. Re-level
-- ---------------------------------------------------------------------------
-- 🔴 CAST TO SIGNED. `minlevel` and `s_lo` are unsigned, and every creature here
-- is BELOW its source floor in at least one case, so `minlevel - s_lo` underflows
-- to a huge BIGINT and the statement dies with "BIGINT UNSIGNED value is out of
-- range". Found the hard way while measuring this set.
UPDATE `creature_template` ct
JOIN `dc_map750_relevel_backup` k ON k.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = CASE WHEN ct.`rank` >= 2 THEN b.`t_hi` + 1
       ELSE GREATEST(b.`t_lo`, LEAST(b.`t_hi`,
              ROUND(b.`t_lo` + (CAST(k.`old_minlevel` AS SIGNED) - CAST(b.`s_lo` AS SIGNED))
                    * (b.`t_hi` - b.`t_lo`) / GREATEST(1, b.`s_hi` - b.`s_lo`)))) END,
    ct.`maxlevel` = CASE WHEN ct.`rank` >= 2 THEN b.`t_hi` + 2
       ELSE GREATEST(b.`t_lo`, LEAST(b.`t_hi`,
              ROUND(b.`t_lo` + (CAST(k.`old_maxlevel` AS SIGNED) - CAST(b.`s_lo` AS SIGNED))
                    * (b.`t_hi` - b.`t_lo`) / GREATEST(1, b.`s_hi` - b.`s_lo`)))) END;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Nothing killable left below its band floor (expect 0):
-- SELECT COUNT(*) FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- JOIN dc_map750_band b ON b.zone = ez.zone
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.maxlevel < b.t_lo
--   AND ct.lootid > 0 AND ct.type NOT IN (8, 11, 12);
--
-- The 14, before and after (expect the table in the header):
-- SELECT ct.entry, ct.name, k.old_minlevel, k.old_maxlevel,
--        ct.minlevel, ct.maxlevel, ct.rank
-- FROM dc_map750_relevel_backup k JOIN creature_template ct ON ct.entry = k.entry
-- ORDER BY ct.minlevel;
--
-- Every NAMED RARE (rank 4) sits at its band ceiling + 1 (expect 0):
-- SELECT ct.entry, ct.name, ct.minlevel, b.t_hi FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- JOIN dc_map750_band b ON b.zone = ez.zone
-- WHERE ct.rank = 4 AND ct.entry BETWEEN 3600000 AND 3799999
--   AND ct.lootid > 0 AND ct.minlevel <> b.t_hi + 1;
--
-- 🔴 Do NOT run that check with `rank >= 2`. The ceiling+1 pattern is specific
-- to rank-4 NAMED RARES. Rank-2 rare-elites and rank-3 bosses sit wherever they
-- were placed and legitimately vary -- Scalebeard 92, Dessecus/Immolatus 106,
-- General Colbatann 113, Kashoch 117, Garr 130, Ysondre 100. All seven are
-- pre-existing and none is a defect; a `rank >= 2` check reports them as 7
-- failures. This file only moves rank-4 rares onto the pattern (The Ongar);
-- it never repositions a rank-2 or rank-3 that was already inside its band.
--
-- Critters were NOT touched (expect Panicked Bunny still 5-7):
-- SELECT entry, name, minlevel, maxlevel FROM creature_template
-- WHERE entry IN (3639997, 3639999, 3650419, 3734306);
--
-- After re-running 322_, The Ongar should point at 752104, not 752096:
-- SELECT Entry, Reference FROM creature_loot_template
-- WHERE Entry = 3714345 AND Reference BETWEEN 752080 AND 752113;
--
-- ROLLBACK:
-- UPDATE creature_template ct JOIN dc_map750_relevel_backup k ON k.entry = ct.entry
-- SET ct.minlevel = k.old_minlevel, ct.maxlevel = k.old_maxlevel;
-- -- then re-run 318_ and 322_.
-- ---------------------------------------------------------------------------
