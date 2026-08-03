-- ---------------------------------------------------------------------------
-- 234  Map 750 -- quest levels for the 80-130 bands (QuestLevel = -1)
-- ---------------------------------------------------------------------------
-- Companion to 233_'s mob re-level: the ~530 quests wired to map-750 entities
-- keep authentic Cata QuestLevels (Darkshore 10-31 ... Hyjal 81-85), which
-- after the re-level would award trivial XP and show grey in the log.
--
--   QuestLevel = -1  ->  Quest::XPValue uses the PLAYER's level (QuestXP.dbc is
--                        extended to 255 -- hard prerequisite, already deployed)
--   MinLevel = band start - 2  ->  early arrivals via breadcrumbs can pick up
--
-- SCOPE: by STARTER ENTITY, never by QuestSortID -- the sort ids (148, 331,
-- 361, 16, 618, 493) are shared with stock Kalimdor quests that must not move.
-- Additionally a quest is only touched if EVERY starter of it lives on map 750
-- (quest ids are global and not offset; if a stock NPC anywhere also offers the
-- quest, changing MinLevel would leak into the old world -- those few are
-- listed by the trailer for a manual decision instead).
--
-- Run AFTER 231_ (needs dc_map750_entryzone / _go). Idempotent: the helper
-- table is rebuilt and the UPDATE is absolute. Apply against acore_world.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) quest -> zone attribution via its map-750 starters
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_questzone`;

CREATE TABLE `dc_map750_questzone` (
  `quest` INT NOT NULL PRIMARY KEY,
  `zone` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_questzone` (`quest`, `zone`)
SELECT qs.`quest`, ez.`zone`
FROM `creature_queststarter` qs
JOIN `dc_map750_entryzone` ez ON ez.`entry` = qs.`id`;

INSERT IGNORE INTO `dc_map750_questzone` (`quest`, `zone`)
SELECT qs.`quest`, ez.`zone`
FROM `gameobject_queststarter` qs
JOIN `dc_map750_entryzone_go` ez ON ez.`entry` = qs.`id`;

-- Drop quests that ALSO have a starter which is NOT a map-750 entity (shared
-- with the stock world -- do not touch those globally).
DELETE qz FROM `dc_map750_questzone` qz
WHERE EXISTS (
    SELECT 1 FROM `creature_queststarter` qs
    WHERE qs.`quest` = qz.`quest`
      AND NOT EXISTS (SELECT 1 FROM `dc_map750_entryzone` ez WHERE ez.`entry` = qs.`id`)
)
OR EXISTS (
    SELECT 1 FROM `gameobject_queststarter` qs
    WHERE qs.`quest` = qz.`quest`
      AND NOT EXISTS (SELECT 1 FROM `dc_map750_entryzone_go` ez WHERE ez.`entry` = qs.`id`)
);

-- ---------------------------------------------------------------------------
-- B) scale the quests
-- ---------------------------------------------------------------------------
UPDATE `quest_template` q
JOIN `dc_map750_questzone` qz ON qz.`quest` = q.`ID`
SET q.`QuestLevel` = -1,
    q.`MinLevel` = CASE qz.`zone`
      WHEN 4929 THEN 78
      WHEN 4930 THEN 78
      WHEN 4928 THEN 78
      WHEN 4931 THEN 85
      WHEN 4927 THEN 93
      WHEN 4926 THEN 101
      WHEN 4923 THEN 110
      ELSE q.`MinLevel`
    END;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- coverage + per-zone counts:
-- SELECT qz.zone, COUNT(*) FROM dc_map750_questzone qz GROUP BY qz.zone;
-- quests excluded because a stock starter shares them (manual review list):
-- SELECT qs.quest, qs.id FROM creature_queststarter qs
-- JOIN (SELECT DISTINCT qs2.quest FROM creature_queststarter qs2
--       JOIN dc_map750_entryzone ez ON ez.entry = qs2.id) m ON m.quest = qs.quest
-- WHERE NOT EXISTS (SELECT 1 FROM dc_map750_entryzone ez WHERE ez.entry = qs.id)
-- ORDER BY qs.quest;
-- AllowableRaces sanity -- expect 0 rows outside the live vocabulary
-- (both = 0/4095/2099199/8388607, Alliance = 3149/2098253, Horde = 946):
-- SELECT qz.zone, q.ID, q.AllowableRaces FROM quest_template q
-- JOIN dc_map750_questzone qz ON qz.quest = q.ID
-- WHERE q.AllowableRaces NOT IN (0, 4095, 2099199, 8388607, 3149, 2098253, 946);
-- scaled state spot check:
-- SELECT q.ID, q.QuestLevel, q.MinLevel FROM quest_template q
-- JOIN dc_map750_questzone qz ON qz.quest = q.ID LIMIT 20;
