-- ---------------------------------------------------------------------------
-- 235  Map 750 -- coin drops for the ~80% of killables that have none
-- ---------------------------------------------------------------------------
-- Only 223 of 1,641 spawned templates carry mingold/maxgold; the rest of the
-- Cata clone import shipped 0/0. On a classic-style leveling continent every
-- coin-bearing creature TYPE should drop change.
--
-- Scope: classic coin types only -- 2 dragonkin, 3 demon, 4 elemental,
-- 5 giant, 6 undead, 7 humanoid, 9 mechanical, 11 uncategorized. Beasts and
-- critters stay coinless (that is what skinning is for). npcflag = 0 keeps
-- service NPCs out.
--
-- Curve (copper), computed from the POST-233 level so it tracks the band:
--   mingold = maxlevel * 100 * rankMult      rank 0 -> x1.0
--   maxgold = maxlevel * 180 * rankMult      rank 1-3 -> x2.5, rank 4 -> x5
-- L80 trash 0.80-1.44g, L128 trash 1.28-2.30g, elites x2.5, rares x5 --
-- calibrated against the 223 Blizzard-authored gold bearers (Hyjal 80-85 avg
-- mingold ~2,000c). Tune the two constants, re-run, done.
--
-- Only touches templates whose SNAPSHOT gold was 0/0 (dc_map750_snap from
-- 233_) -- hand-authored gold survives, and the file is re-run safe because
-- it always recomputes from level, never from current gold.
--
-- Run AFTER 233_ (needs dc_map750_snap + re-leveled maxlevel).
-- ---------------------------------------------------------------------------

UPDATE `creature_template` ct
JOIN `dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
SET ct.`mingold` = ROUND(ct.`maxlevel` * 100 *
      (CASE ct.`rank` WHEN 0 THEN 1.0 WHEN 4 THEN 5.0 ELSE 2.5 END)),
    ct.`maxgold` = ROUND(ct.`maxlevel` * 180 *
      (CASE ct.`rank` WHEN 0 THEN 1.0 WHEN 4 THEN 5.0 ELSE 2.5 END))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND s.`mingold0` = 0 AND s.`maxgold0` = 0
  AND ct.`type` IN (2, 3, 4, 5, 6, 7, 9, 11)
  AND ct.`npcflag` = 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- coverage after apply (expect the large majority of coin types covered):
-- SELECT ez.zone, COUNT(*) total, SUM(ct.mingold > 0) with_gold
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE ct.type IN (2, 3, 4, 5, 6, 7, 9, 11) AND ct.npcflag = 0
-- GROUP BY ez.zone;
-- curve sanity vs the Blizzard-authored bearers:
-- SELECT ct.maxlevel, ROUND(AVG(ct.mingold)) avg_min, ROUND(AVG(ct.maxgold)) avg_max
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE ct.mingold > 0 GROUP BY ct.maxlevel ORDER BY ct.maxlevel;
