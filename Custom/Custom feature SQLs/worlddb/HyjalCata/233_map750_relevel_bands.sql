-- ---------------------------------------------------------------------------
-- 233  Map 750 -- the classic zone-band re-level (80-130)
-- ---------------------------------------------------------------------------
-- SUPERSEDES the level clause of 101_zone_level_bands.sql. 101_'s design note
-- ("no sub-area geography on map 750") predates the seven-zone AreaTable; the
-- user has since decided the classic layout:
--
--   zone                       source lvls   target band   role
--   4929 Darkshore             10-31         80-90         Alliance start (Lor'danel)
--   4930 Azshara               10-25         80-90         Horde start (Bilgewater)
--   4931 Ashenvale             18-30         88-98         contested convergence
--   4927 Felwood               45-58         96-106        neutral
--   4926 Winterspring          48-60         104-115       neutral (Everlook)
--   4923 Hyjal Frontier        80-85         113-128       endgame (elites -> 130)
--   4928 Moonglade             --            --            sanctuary, UNTOUCHED
--
-- WHY a hard re-level: kill-XP grey level is `player - 9` and the FormulaScript
-- hooks are compiled out, so with mobs capped at 85 all kill XP dies at player
-- level ~94. Mobs must physically carry the band. Stats come free from the
-- 255-extended creature_classlevelstats (verify the 84-255 damage repair is
-- applied first -- rev_1785066078400234600).
--
-- Hyjal's linear remap (slope 3: 80->113 ... 85->128) reproduces the zone's
-- geographic quest gradient automatically (Nordrassil 80s north -> Gates of
-- Sothann / Firelands Forgeworks 84-85 south), so the native 84-85 elite belt
-- lands at 125-130 -- that IS the endgame elite pocket, no rect geometry needed.
--
-- SCOPE NOTE (added by 307_): every UPDATE below is guarded by
-- `entry BETWEEN 3600000 AND 3799999`, so map-750 spawns in the 7,3xx,xxx clone
-- band are silently skipped -- 5 Hyjal elites sat at level 85-86 for that
-- reason until 307_ re-levelled them by pinned entry. The guard is deliberate
-- (widening it would re-level DC-authored NPCs such as 830021 Encampment
-- Guard), so new clone bands need a catch-up file, not a wider range here.
--
-- ORDERING: run AFTER 231_ (needs dc_map750_entryzone) and AFTER 101_ (its
-- rank-4 88-90 lift is overwritten here by absolute assignment; its
-- HealthModifier/DamageModifier bumps are RELATIVE and stay wanted).
--
-- IDEMPOTENT + RE-TUNABLE: dc_map750_snap freezes the FIRST-seen template
-- levels (INSERT IGNORE, deliberately no DELETE -- the snapshot must survive
-- re-runs); every formula computes from the snapshot, never from current
-- values, so editing the band table and re-running re-derives everything.
-- This file must be the first thing that ever changes levels in the clone
-- band, or the snapshot baseline is wrong.
--
-- KNOWN LIMITATION: templates with no spawn (script/SmartAI-summoned adds)
-- have no dc_map750_entryzone row and are NOT re-leveled here. The trailer
-- lists them; band them manually as playtest surfaces them.
--
-- Deliberately untouched: type 8 critters and type 10 triggers keep their
-- native levels (some triggers are killcredit/vehicle targets whose level and
-- HP pool matter to quest scripts).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) one-time level/gold snapshot (baseline for every later formula)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_snap` (
  `entry` INT NOT NULL PRIMARY KEY,
  `minlevel0` INT NOT NULL,
  `maxlevel0` INT NOT NULL,
  `mingold0` INT NOT NULL,
  `maxgold0` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_snap` (`entry`, `minlevel0`, `maxlevel0`, `mingold0`, `maxgold0`)
SELECT `entry`, `minlevel`, `maxlevel`, `mingold`, `maxgold`
FROM `creature_template`
WHERE `entry` BETWEEN 3600000 AND 3799999;

-- ---------------------------------------------------------------------------
-- B) the band table -- THE tunable surface of the whole re-level
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_band`;

CREATE TABLE `dc_map750_band` (
  `zone` INT NOT NULL PRIMARY KEY,
  `s_lo` INT NOT NULL,
  `s_hi` INT NOT NULL,
  `t_lo` INT NOT NULL,
  `t_hi` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_band` (`zone`, `s_lo`, `s_hi`, `t_lo`, `t_hi`) VALUES
(4929, 10, 31,  80,  90),
(4930, 10, 25,  80,  90),
(4931, 18, 30,  88,  98),
(4927, 45, 58,  96, 106),
(4926, 48, 60, 104, 115),
(4923, 80, 85, 113, 128);
-- 4928 Moonglade has no row on purpose: sanctuary, untouched.

-- ---------------------------------------------------------------------------
-- C) base remap -- rank 0 combat mobs (no npcflag, no critters/triggers)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` ct
JOIN `dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`))),
    ct.`maxlevel` = LEAST(130, b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 0;

-- ---------------------------------------------------------------------------
-- D) rank rules -- elites ride the band top, rares/bosses crown it
-- ---------------------------------------------------------------------------
-- rank 1 (elite): base remap + 1, capped at t_hi + 1
UPDATE `creature_template` ct
JOIN `dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))),
    ct.`maxlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`))))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 1;

-- rank 2 (rare elite): base remap + 2, capped at t_hi + 2
UPDATE `creature_template` ct
JOIN `dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, LEAST(b.`t_hi` + 2, 2 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))),
    ct.`maxlevel` = LEAST(130, LEAST(b.`t_hi` + 2, 2 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`))))
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 2;

-- rank 3 (boss): flat band top + 2
UPDATE `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, b.`t_hi` + 2),
    ct.`maxlevel` = LEAST(130, b.`t_hi` + 2)
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 3;

-- rank 4 (named rare): band top + 1 .. + 2 (Hyjal: 129-130; overwrites 101_'s
-- GREATEST(88/90) lift by absolute assignment)
UPDATE `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, b.`t_hi` + 1),
    ct.`maxlevel` = LEAST(130, b.`t_hi` + 2)
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 4;

-- ---------------------------------------------------------------------------
-- E) service / flagged NPCs -- flat band top, any rank
-- ---------------------------------------------------------------------------
-- Questgivers, vendors, trainers, innkeepers, flightmasters: a zone-top level
-- keeps them from being farmed or one-shot and reads correctly in tooltips.
UPDATE `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = b.`t_hi`,
    ct.`maxlevel` = b.`t_hi`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` <> 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- band conformance (expect 0 rows):
-- SELECT ez.zone, ct.entry, ct.minlevel, ct.maxlevel
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- JOIN dc_map750_band b ON b.zone = ez.zone
-- WHERE ct.`rank` = 0 AND ct.npcflag = 0 AND ct.type NOT IN (8, 10)
--   AND (ct.minlevel < b.t_lo OR ct.maxlevel > b.t_hi);
-- nothing above 130 anywhere in the band (expect 0):
-- SELECT COUNT(*) FROM creature_template
-- WHERE entry BETWEEN 3600000 AND 3799999 AND maxlevel > 130;
-- per-zone level histogram, eyeball the gradient:
-- SELECT ez.zone, ct.maxlevel, COUNT(*) FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- GROUP BY ez.zone, ct.maxlevel ORDER BY 1, 2;
-- un-banded summon-only templates (no spawn -> no entryzone row; manual list):
-- SELECT ct.entry, ct.name, ct.minlevel, ct.maxlevel FROM creature_template ct
-- LEFT JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ez.entry IS NULL
--   AND ct.type NOT IN (8, 10) ORDER BY ct.entry;
