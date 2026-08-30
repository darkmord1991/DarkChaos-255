-- ---------------------------------------------------------------------------
-- 307  Round 47 -- the 5 Hyjal elites 233_'s entry guard silently skipped
-- ---------------------------------------------------------------------------
-- Scoping the "60 lootable creatures carry no ladder ref" item found the real
-- number is FIVE, and that they share one root cause with a second symptom.
--
-- 233_ re-levels map 750 with `WHERE ct.entry BETWEEN 3600000 AND 3799999`.
-- These five live in the **7,3xx,xxx clone band**, so every one of its five
-- UPDATEs skipped them -- no error, no log line, exactly the silent-skip class
-- 288_ hit from the other direction (a missing `dc_map750_entryzone` row).
-- They DO have entryzone rows (all zone 4923, Hyjal), so nothing else was
-- wrong; the guard alone is why they are still standing at their Cata levels:
--
--   7352289  Fiery Behemoth   85   rank 1   12 spawns
--   7353264  Searris          86   rank 1    1
--   7353265  Kelbnar          86   rank 1    1
--   7353267  Andrazor         86   rank 1    1
--   7353271  Fah Jarakk       86   rank 1    1
--
-- Consequence in game: level-113-128 Hyjal, and these five elites con grey.
-- Their missing ladder reference is the same story -- the 24x_ ladder pass
-- derives its target set from the re-levelled band, so a mob the re-level never
-- saw never got a reference either.
--
-- WHY 233_'S GUARD IS NOT WIDENED HERE. Dropping the entry range would also
-- pull in 830021 "Encampment Guard" (level 130 by design, a DC-authored NPC),
-- and any future custom NPC placed on map 750 -- a re-run would quietly
-- re-level DC content to the Cata-derived curve. The five are pinned as
-- literals instead, and 233_ carries a pointer to this file.
--
-- NOT TOUCHED, and why: **3640134 Nightmare Terror** (level 80, 9 spawns) also
-- has no ladder reference. It is `type = 10` (not specified), which is exactly
-- what 233_'s `type NOT IN (8, 10)` filter deliberately excludes -- and it
-- already carries stock references 14002/14004, which suit a level-80 mob. Giving
-- it Hyjal's ilvl-398 / ReqLvl-115 tier while it stays level 80 would be worse
-- than leaving it. If it should be a real Hyjal mob, that is a type + level
-- decision first, and the ladder follows.
--
-- Apply against acore_world AFTER 233_ and the 24x_ ladder files, then restart
-- worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Record their originals in dc_map750_snap
-- ---------------------------------------------------------------------------
-- 233_ only snapshots 3,600,000-3,799,999, so these five have never been
-- recorded. INSERT IGNORE matches 233_'s own idiom: the snapshot must capture
-- the PRE-re-level values, so a second run must not overwrite it.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `dc_map750_snap` (`entry`, `minlevel0`, `maxlevel0`, `mingold0`, `maxgold0`)
SELECT `entry`, `minlevel`, `maxlevel`, `mingold`, `maxgold`
FROM `creature_template`
WHERE `entry` IN (7352289, 7353264, 7353265, 7353267, 7353271);

-- ---------------------------------------------------------------------------
-- B) Re-level -- 233_'s rank-1 rule, applied to the pinned five
-- ---------------------------------------------------------------------------
-- Identical formula to 233_ section D (rank 1 = base remap + 1, capped at
-- t_hi + 1), reading the same `dc_map750_band` row so the two cannot drift:
--   zone 4923: s_lo 80, s_hi 85, t_lo 113, t_hi 128
--   85 or 86 -> clamped to 85 -> 1 + 113 + ROUND(5 * 15 / 5) = 129, capped 129
-- Gold follows the same target as every other re-levelled Hyjal rank 1
-- (32250 / 58050 -- checked against 8 of them, all identical).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` ct
JOIN `dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))),
    ct.`maxlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))),
    ct.`mingold` = 32250,
    ct.`maxgold` = 58050
WHERE ct.`entry` IN (7352289, 7353264, 7353265, 7353267, 7353271)
  AND ct.`rank` = 1;

-- ---------------------------------------------------------------------------
-- C) Hook them to the Hyjal loot ladder (reference 750113)
-- ---------------------------------------------------------------------------
-- Same row shape the 24x_ pass used: Item = the reference id, Chance 2 for
-- rank 1 (rank 4 gets 6), LootMode 1, GroupId 0. Their lootids are the RAW
-- Cata ids (52289 / 53264 / 53265 / 53267 / 53271) -- that is pre-existing and
-- left alone; retargeting a working lootid is a separate consistency call, the
-- same one still open for Flamewaker Shaman 3653093.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template`
WHERE `Entry` IN (52289, 53264, 53265, 53267, 53271) AND `Reference` = 750113;

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(52289, 750113, 750113, 2, 0, 1, 0, 1, 1, 'DC750 ladder drop (307 73xx band catch-up)'),
(53264, 750113, 750113, 2, 0, 1, 0, 1, 1, 'DC750 ladder drop (307 73xx band catch-up)'),
(53265, 750113, 750113, 2, 0, 1, 0, 1, 1, 'DC750 ladder drop (307 73xx band catch-up)'),
(53267, 750113, 750113, 2, 0, 1, 0, 1, 1, 'DC750 ladder drop (307 73xx band catch-up)'),
(53271, 750113, 750113, 2, 0, 1, 0, 1, 1, 'DC750 ladder drop (307 73xx band catch-up)');

-- ---------------------------------------------------------------------------
-- Verify (expected: 5 rows at level 129/129, and 5 ladder rows)
-- ---------------------------------------------------------------------------
--   SELECT entry, name, minlevel, maxlevel, mingold, maxgold FROM creature_template
--    WHERE entry IN (7352289,7353264,7353265,7353267,7353271);
--   SELECT Entry, Reference, Chance FROM creature_loot_template
--    WHERE Entry IN (52289,53264,53265,53267,53271) AND Reference = 750113;
--   -- and the sweep that found them should now return 0 rows:
--   SELECT ct.entry, ct.name FROM creature_template ct
--    WHERE ct.entry IN (SELECT DISTINCT id FROM creature WHERE map = 750)
--      AND ct.lootid <> 0 AND ct.`rank` <= 3 AND ct.npcflag = 0 AND ct.minlevel >= 85
--      AND ct.faction NOT IN (35,31,7,114,113) AND (ct.unit_flags & 0x200) = 0
--      AND NOT EXISTS (SELECT 1 FROM creature_loot_template l WHERE l.Entry = ct.lootid
--                        AND l.Reference IN (750080,750081,750088,750096,750104,750113));
-- ---------------------------------------------------------------------------
