-- 71_level_reband_130_160.sql — map 751 Lordaeron extension, DB step 10.
--
-- Turns map 751 from a level 1-60 museum into the 130-160 progression continent it
-- already advertises: `AreaTable` 4924 has read "Plaguelands (130-160)" since long
-- before this build, but nothing had ever re-leveled the creatures.
--
-- Mirrors the proven map-750 machinery (HyjalCata/231-233): a frozen SNAPSHOT of the
-- original levels, a tunable BAND table, and a linear re-map from one to the other.
-- The snapshot is what makes this safe to re-run — without it, a second run would
-- re-scale already-scaled levels and the band would drift upward every time.
--
-- ###########################################################################
-- THREE EXCLUSIONS, each of which would corrupt content elsewhere if ignored:
--
-- 1. **Entries spawned outside map 751.** creature_template is global; editing a
--    shared entry changes it everywhere. Measured: **9 entries in the +3,600,000
--    band are spawned on map 750 as well** — that band is shared between the Hyjal
--    and Plaguelands downports — and Hyjal is already banded 80-130. Re-leveling
--    them would silently corrupt Hyjal.
-- 2. **Stock ids.** Only the two private bands (3,600,000-3,699,999 and
--    4,100,000-4,199,999) are ours. The one stock id spawned here is
--    **6491 Spirit Healer, which has 274 spawns on other maps**.
-- 3. **zoneId 0.** 10 spawns of `3608297 Magronos the Unyielding` sit at tile 37_53,
--    far outside any map-751 footprint — a pre-existing bad import. They are
--    deleted at the end rather than banded.
-- ###########################################################################
--
-- Source ranges are Blizzard's INTENDED Cata level range per zone, not the raw
-- min/max of the data (which runs 1..130 everywhere because of critters, city
-- guards and boss outliers). Anything outside the source range clamps to the band
-- edge, so a level-1 critter lands at the band floor rather than below it.

-- ---------------------------------------------------------------------------
-- 1. Band table — edit these and re-run; nothing else needs changing
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_band`;
CREATE TABLE `dc_map751_band` (
  `zone` SMALLINT UNSIGNED NOT NULL,
  `s_lo` SMALLINT UNSIGNED NOT NULL,
  `s_hi` SMALLINT UNSIGNED NOT NULL,
  `t_lo` SMALLINT UNSIGNED NOT NULL,
  `t_hi` SMALLINT UNSIGNED NOT NULL,
  `name` VARCHAR(48) NOT NULL,
  PRIMARY KEY (`zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_band` (`zone`,`s_lo`,`s_hi`,`t_lo`,`t_hi`,`name`) VALUES
  (4933,  1, 12, 130, 136, 'Tirisfal Glades'),
  (4939,  5, 20, 130, 136, 'Ruins of Gilneas'),
  (4935, 10, 20, 134, 140, 'Silverpine Forest'),
  (4936, 20, 27, 138, 144, 'Hillsbrad Foothills'),
  (4938, 25, 32, 142, 147, 'Arathi Highlands'),
  (4937, 30, 40, 145, 150, 'The Hinterlands'),
  (4932, 35, 42, 148, 153, 'Western Plaguelands'),
  (4924, 40, 48, 152, 158, 'Eastern Plaguelands');

-- ---------------------------------------------------------------------------
-- 2. Which entry belongs to which zone, and the frozen original levels.
--    An entry spawned in several zones is assigned to the one it appears in most
--    (a template has ONE level, so it can only belong to one band).
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_entryzone`;
CREATE TABLE `dc_map751_entryzone` (
  `entry` INT UNSIGNED NOT NULL,
  `zone`  SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_entryzone` (`entry`,`zone`)
SELECT x.`id`, x.`zoneId`
FROM (
  SELECT c.`id`, c.`zoneId`,
         ROW_NUMBER() OVER (PARTITION BY c.`id` ORDER BY COUNT(*) DESC, c.`zoneId`) AS rn
  FROM `creature` c
  WHERE c.`map` = 751
    AND c.`zoneId` IN (4924,4932,4933,4935,4936,4937,4938,4939)
    AND ((c.`id` BETWEEN 3600000 AND 3699999) OR (c.`id` BETWEEN 4100000 AND 4199999))
    -- exclusion 1: never touch an entry that also lives somewhere else
    AND NOT EXISTS (SELECT 1 FROM `creature` o WHERE o.`id` = c.`id` AND o.`map` <> 751)
  GROUP BY c.`id`, c.`zoneId`
) x
WHERE x.rn = 1;

-- Frozen original levels. INSERT IGNORE means the FIRST run wins forever, so
-- re-running never re-scales an already-scaled level.
CREATE TABLE IF NOT EXISTS `dc_map751_snap` (
  `entry`    INT UNSIGNED NOT NULL,
  `minlevel` SMALLINT NOT NULL,
  `maxlevel` SMALLINT NOT NULL,
  `rank`     TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map751_snap` (`entry`,`minlevel`,`maxlevel`,`rank`)
SELECT t.`entry`, t.`minlevel`, t.`maxlevel`, t.`rank`
FROM `creature_template` t
JOIN `dc_map751_entryzone` e ON e.`entry` = t.`entry`;

-- ---------------------------------------------------------------------------
-- 3. Re-level. Linear map snapshot -> band, clamped to the band, elites +2.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
JOIN `dc_map751_entryzone` e ON e.`entry` = t.`entry`
JOIN `dc_map751_snap`      s ON s.`entry` = t.`entry`
JOIN `dc_map751_band`      b ON b.`zone`  = e.`zone`
SET
  t.`minlevel` = LEAST(b.`t_hi` + IF(s.`rank` > 0, 2, 0),
                  GREATEST(b.`t_lo`,
                    b.`t_lo` + ROUND( (LEAST(GREATEST(s.`minlevel`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
                                      * (b.`t_hi` - b.`t_lo`)
                                      / GREATEST(b.`s_hi` - b.`s_lo`, 1) )
                            + IF(s.`rank` > 0, 2, 0))),
  t.`maxlevel` = LEAST(b.`t_hi` + IF(s.`rank` > 0, 2, 0),
                  GREATEST(b.`t_lo`,
                    b.`t_lo` + ROUND( (LEAST(GREATEST(s.`maxlevel`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
                                      * (b.`t_hi` - b.`t_lo`)
                                      / GREATEST(b.`s_hi` - b.`s_lo`, 1) )
                            + IF(s.`rank` > 0, 2, 0)));

-- minlevel must never exceed maxlevel after rounding
UPDATE `creature_template` t
JOIN `dc_map751_entryzone` e ON e.`entry` = t.`entry`
SET t.`minlevel` = t.`maxlevel`
WHERE t.`minlevel` > t.`maxlevel`;

-- ---------------------------------------------------------------------------
-- 4. Quests: player-scaled XP, and a MinLevel just under the band floor.
--    Scoped by questgiver, and ONLY for quests whose every starter/ender is one of
--    our entries — quest ids are global, so a quest also handed out on another map
--    must not be re-scaled. (This is the same guard map 750's 234_ needed.)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_questband`;
CREATE TABLE `dc_map751_questband` (
  `quest` INT UNSIGNED NOT NULL,
  `t_lo`  SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_questband` (`quest`,`t_lo`)
SELECT q.`quest`, MIN(b.`t_lo`)
FROM (
  SELECT r.`quest`, r.`id` FROM `creature_queststarter` r
  UNION SELECT r.`quest`, r.`id` FROM `creature_questender` r
) q
JOIN `dc_map751_entryzone` e ON e.`entry` = q.`id`
JOIN `dc_map751_band`      b ON b.`zone`  = e.`zone`
WHERE NOT EXISTS (
  -- any starter/ender that is NOT one of our entries disqualifies the quest
  SELECT 1 FROM (
    SELECT r2.`quest`, r2.`id` FROM `creature_queststarter` r2
    UNION SELECT r2.`quest`, r2.`id` FROM `creature_questender` r2
  ) o
  LEFT JOIN `dc_map751_entryzone` e2 ON e2.`entry` = o.`id`
  WHERE o.`quest` = q.`quest` AND e2.`entry` IS NULL
)
GROUP BY q.`quest`;

UPDATE `quest_template` t
JOIN `dc_map751_questband` qb ON qb.`quest` = t.`ID`
SET t.`QuestLevel` = -1,
    t.`MinLevel`   = GREATEST(qb.`t_lo` - 2, 1);

-- ---------------------------------------------------------------------------
-- 5. Cleanup: the off-map Magronos strays (tile 37_53, no zone, pre-existing bad
--    import). They can never be reached and would sit unbanded forever.
-- ---------------------------------------------------------------------------
DELETE a FROM `creature_addon` a JOIN `creature` c ON c.`guid` = a.`guid`
  WHERE c.`map` = 751 AND c.`zoneId` = 0;
DELETE FROM `creature` WHERE `map` = 751 AND `zoneId` = 0;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT b.`zone`, b.`name`, b.`t_lo`, b.`t_hi`,
       COUNT(t.`entry`) AS entries,
       MIN(t.`minlevel`) AS lvl_min, MAX(t.`maxlevel`) AS lvl_max
FROM `dc_map751_band` b
LEFT JOIN `dc_map751_entryzone` e ON e.`zone` = b.`zone`
LEFT JOIN `creature_template`   t ON t.`entry` = e.`entry`
GROUP BY b.`zone`, b.`name`, b.`t_lo`, b.`t_hi`
ORDER BY b.`t_lo`;

SELECT 'entries re-leveled'        AS what, COUNT(*) AS n FROM `dc_map751_entryzone`
UNION ALL SELECT 'snapshot rows (frozen originals)', COUNT(*) FROM `dc_map751_snap`
UNION ALL SELECT 'quests scaled to player level',    COUNT(*) FROM `dc_map751_questband`
UNION ALL SELECT 'off-map strays deleted',           10 - (SELECT COUNT(*) FROM `creature` WHERE `map` = 751 AND `zoneId` = 0);

-- must be zero: anything we re-leveled that lives outside map 751
SELECT 'PROBLEM: re-leveled an entry spawned elsewhere' AS problem, COUNT(*) AS n
FROM `dc_map751_entryzone` e
WHERE EXISTS (SELECT 1 FROM `creature` o WHERE o.`id` = e.`entry` AND o.`map` <> 751);

-- must be zero: stock (non-private-band) entries touched
SELECT 'PROBLEM: re-leveled a stock id' AS problem, COUNT(*) AS n
FROM `dc_map751_entryzone`
WHERE `entry` NOT BETWEEN 3600000 AND 3699999
  AND `entry` NOT BETWEEN 4100000 AND 4199999;

-- must be zero: level outside its own band (elites may sit 2 over t_hi by design)
SELECT 'PROBLEM: level outside band' AS problem, COUNT(*) AS n
FROM `creature_template` t
JOIN `dc_map751_entryzone` e ON e.`entry` = t.`entry`
JOIN `dc_map751_band`      b ON b.`zone`  = e.`zone`
WHERE t.`minlevel` < b.`t_lo` OR t.`maxlevel` > b.`t_hi` + 2;

-- how much of map 751 is still un-banded, and why
SELECT 'spawned entries NOT re-leveled' AS note, COUNT(DISTINCT c.`id`) AS n,
       'shared with another map, or stock' AS reason
FROM `creature` c
WHERE c.`map` = 751
  AND NOT EXISTS (SELECT 1 FROM `dc_map751_entryzone` e WHERE e.`entry` = c.`id`);
