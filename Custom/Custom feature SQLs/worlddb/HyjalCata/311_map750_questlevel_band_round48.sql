-- ---------------------------------------------------------------------------
-- 311  Round 48 -- QuestLevel: leave the scaling ones, band the fixed ones
-- ---------------------------------------------------------------------------
-- `QuestLevel` drives quest XP and the quest log's colour. On map 750 it was
-- inconsistent: most quests carry -1 (AC computes XP from the PLAYER's level,
-- so they self-scale and are already correct) while a minority kept their
-- vanilla value, so a Hyjal quest handed out level-81 XP to a level-125 player.
-- `MinLevel` was already re-levelled correctly everywhere and is NOT touched.
--
-- DECISION APPLIED: -1 stays -1. Only fixed levels are remapped to the zone band.
--
--   605 map-750 quests
--   539  QuestLevel = -1  -> untouched, they scale to the player
--    66  fixed, reachable from a map-750 questgiver
--   +123 fixed, reached via a map-750 quest ENDER or a map-750 gameobject
--        (keying on questgivers alone misses these -- 91 have no creature
--         starter at all, they are item- or object-started)
--   -57  EXCLUDED, see the guard below
--   =101 remapped here
--
-- 🔴 THE GUARD THAT MATTERS: 57 of those quests are ALSO given or turned in by
-- an NPC spawned OUTSIDE map 750. A quest id is global -- 49 of them hang off a
-- questgiver in the real world, so raising their level to 113-128 would re-tune
-- the quest for a level-20 player standing in real Ashenvale. Only quests whose
-- every giver AND ender spawns exclusively on map 750 are touched. Same
-- blast-radius test as the shared lootids in 309_ and the shared references it
-- refused to edit.
--
-- THE FORMULA is 233_'s, not a new one -- the same linear band remap used for
-- creature levels, reading the same `dc_map750_band` row, so the two cannot
-- drift:
--     QuestLevel = LEAST(130, t_lo + ROUND(
--         (LEAST(GREATEST(QuestLevel, s_lo), s_hi) - s_lo)
--         * (t_hi - t_lo) / (s_hi - s_lo)))
-- Clamping to the source band means an out-of-range straggler (Azshara had a
-- level-84 quest, Ashenvale a level-70 one) lands at the band top instead of
-- overshooting. Quests already inside their band are skipped.
--
--   zone            band      n    was      becomes
--   4923 Hyjal      113-128   29   81-85    116-128
--   4926 Winterspr. 104-115   15   52-60    108-115
--   4927 Felwood     96-106   16   45-60     96-106
--   4929 Darkshore   80-90    12   10-28     80-89
--   4930 Azshara     80-90    13   13-20     82-87
--   4931 Ashenvale   88-98    16   21-27     91-96
--
-- XP is safe at these levels: the live `QuestXP.dbc` has **255 records** and
-- rows 113/120/128/130 all resolve (checked on the server, not assumed) -- the
-- same trap that made `exploration_basexp` award 0 above level 79.
--
-- Apply against acore_world, then restart worldserver. Idempotent: a second run
-- finds every target already inside its band and changes nothing.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Resolve the target set once, into a temp table
-- ---------------------------------------------------------------------------
-- Materialised first because the UPDATE would otherwise have `quest_template`
-- inside its own subquery, which MySQL rejects (error 1093).
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_qlevel_map`;
CREATE TEMPORARY TABLE `dc_qlevel_map` (
  `ID`        INT UNSIGNED NOT NULL PRIMARY KEY,
  `old_level` INT NOT NULL,
  `zone`      INT NOT NULL,
  `new_level` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_qlevel_map` (`ID`, `old_level`, `zone`, `new_level`)
SELECT z.`ID`, z.`QuestLevel`, b.`zone`,
       LEAST(130, b.`t_lo` + ROUND(
         (LEAST(GREATEST(z.`QuestLevel`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
         * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))
FROM (
  SELECT q.`ID`, q.`QuestLevel`, MIN(ez.`zone`) AS zone
  FROM `quest_template` q
  JOIN (
    SELECT `quest`, `id` FROM `creature_queststarter`
    UNION
    SELECT `quest`, `id` FROM `creature_questender`
  ) g ON g.`quest` = q.`ID`
  JOIN `dc_map750_entryzone` ez ON ez.`entry` = g.`id`
  WHERE q.`QuestLevel` > 0
  GROUP BY q.`ID`, q.`QuestLevel`
) z
JOIN `dc_map750_band` b ON b.`zone` = z.`zone`
WHERE NOT (z.`QuestLevel` BETWEEN b.`t_lo` AND b.`t_hi`)
  AND NOT EXISTS (
        SELECT 1 FROM `creature_queststarter` qs
        JOIN `creature` c ON c.`id` = qs.`id` AND c.`map` <> 750
        WHERE qs.`quest` = z.`ID`)
  AND NOT EXISTS (
        SELECT 1 FROM `creature_questender` qe
        JOIN `creature` c2 ON c2.`id` = qe.`id` AND c2.`map` <> 750
        WHERE qe.`quest` = z.`ID`);

-- A zone is picked with MIN(zone) when a quest spans two of them -- a chain that
-- crosses a border belongs to the earlier zone, which is where the player meets
-- it. Only a handful do.

-- ---------------------------------------------------------------------------
-- B) Backup, then apply
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_questlevel_backup` (
  `ID`        INT UNSIGNED NOT NULL PRIMARY KEY,
  `old_level` INT NOT NULL,
  `backed_up_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- INSERT IGNORE, no leading DELETE: the backup must keep the FIRST-seen value,
-- the same reason 233_ freezes dc_map750_snap.
INSERT IGNORE INTO `dc_map750_questlevel_backup` (`ID`, `old_level`)
SELECT m.`ID`, m.`old_level` FROM `dc_qlevel_map` m;

UPDATE `quest_template` q
JOIN `dc_qlevel_map` m ON m.`ID` = q.`ID`
SET q.`QuestLevel` = m.`new_level`;

DROP TEMPORARY TABLE IF EXISTS `dc_qlevel_map`;

-- ---------------------------------------------------------------------------
-- Verify (expected: 101 rows backed up, 0 map-750-exclusive quests left out of band)
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM dc_map750_questlevel_backup;                        -- 101
--   SELECT b.zone, COUNT(*), MIN(q.QuestLevel), MAX(q.QuestLevel)
--     FROM quest_template q
--     JOIN dc_map750_questlevel_backup bk ON bk.ID = q.ID
--     JOIN (SELECT quest, id FROM creature_queststarter
--           UNION SELECT quest, id FROM creature_questender) g ON g.quest = q.ID
--     JOIN dc_map750_entryzone ez ON ez.entry = g.id
--     JOIN dc_map750_band b ON b.zone = ez.zone
--    GROUP BY b.zone;
--   -- the 539 self-scaling quests must still be -1:
--   SELECT COUNT(*) FROM quest_template q
--     JOIN (SELECT quest, id FROM creature_queststarter
--           UNION SELECT quest, id FROM creature_questender) g ON g.quest = q.ID
--     JOIN dc_map750_entryzone ez ON ez.entry = g.id
--    WHERE q.QuestLevel = -1;                                                -- 539
--
-- REVERT:
--   UPDATE quest_template q JOIN dc_map750_questlevel_backup b ON b.ID = q.ID
--      SET q.QuestLevel = b.old_level;
-- ---------------------------------------------------------------------------
