-- =====================================================================
-- Dungeon Finder: put the Classic / TBC heroics in the level-80 bracket
-- =====================================================================
-- Apply against: acore_world. Safe to re-run (idempotent by design).
--
-- Apply AFTER dc_heroic_classic_tbc_scaling.sql - this file assumes
-- Heroic on those maps is level 80/81/82 content.
--
-- WHAT WAS WRONG
-- ---------------------------------------------------------------------
-- The dungeons are already IN the matchmaking catalog: it admits any
-- 5-man with an EPIC MapDifficulty.dbc row, and the server's
-- MapDifficulty.dbc carries difficulty 0, 1 and 2 for every Classic and
-- TBC dungeon. Nothing had to be added there.
--
-- The level bracket was the problem, and it failed in both directions:
--
--   Vanilla (18 dungeons) had NO difficulty-1 row in this table at all.
--   InstanceCatalog::Build then inherits the Normal requirement -
--       for (diff = 1..) if (minLevel[diff] == 0) minLevel[diff] = minLevel[diff-1]
--   so Heroic Deadmines advertised a minimum level of 10 and Heroic
--   Shadowfang Keep 14, against creatures that now spawn at 80-82.
--
--   TBC (16 dungeons) had difficulty-1 rows, but at min_level 70 - and
--   worse, LFGDungeons.dbc caps their heroic MaxLevel at 75:
--
--       map 540/542/543/545/552/555/269/585  difficulty 1  min 70 max 75
--
--   MatchmakingQueue::IsWithinLevelBracket enforces level <= maxLevel,
--   so a level-80 character was locked OUT of every TBC heroic in the
--   finder. (WotLK heroics carry max 83, which is why they worked.)
--
-- THE BOT SIDE
-- ---------------------------------------------------------------------
-- Bot backfill needs no code change, and it was never broken for a
-- level-80 party. RecruitBots bands candidates off the PARTY's minimum
-- level, using the dungeon requirement only to raise the floor:
--
--     floorLevel = max(catalogMinLevel, partyMin - slack)
--     ceilLevel  = partyMin + slack            (slack default 5)
--
-- so an 80 party already pulled 75-85 bots regardless of what the
-- dungeon claimed. What the old data allowed was the queue itself: a
-- level-10 group could join Heroic Deadmines, and the recruiter would
-- then correctly-but-uselessly fill it with level 5-15 bots for a
-- dungeon spawning at 80-82.
--
-- Raising the floor to 80 closes the queue to those groups, which is
-- what makes bot backfill land on level-80 bots in practice. The TBC
-- half matters more: with the DBC's max of 75 in force, no level-80
-- group could queue TBC heroic at all, so no bot backfill ever ran for
-- those dungeons.
--
-- ABOUT max_level = 255
-- ---------------------------------------------------------------------
-- FillDifficultyRequirement only consults LFGDungeons.dbc when this
-- table leaves max_level at 0, so 0 is not "no cap" - it is "ask the
-- DBC", which is exactly how TBC heroic inherited the 75 cap. Setting an
-- explicit 255 overrides it without touching any DBC, so no client patch
-- is needed.
--
-- 255 means any level can queue, which on a 255-level realm includes
-- characters far past this content. That is a policy choice, not a
-- technical requirement: to make Classic/TBC heroic an 80-89 bracket
-- instead, change the 255 below to 89. DC.GroupFinder.Queue.LevelBracketCap
-- is the other lever - it clamps the level a player is judged at.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Existing Heroic rows (the 16 TBC dungeons): raise to level 80 and
--    lift the DBC's 75 cap.
-- ---------------------------------------------------------------------
UPDATE `dungeon_access_template` t
JOIN `dc_dungeon_setup` s ON s.`map_id` = t.`map_id`
SET t.`min_level` = 80,
    t.`max_level` = 255
WHERE s.`heroic_enabled` = 1
  AND s.`expansion` IN (0, 1)
  AND s.`map_id` < 800
  AND t.`difficulty` = 1;

-- ---------------------------------------------------------------------
-- 2) Missing Heroic rows (the 18 Vanilla dungeons).
--
--    NOTE: dungeon_access_template.id is TINYINT UNSIGNED, so the whole
--    table is capped at 255 rows. It held 162 before this file; steps 2
--    and 3 add 52, taking it to 214 and leaving 41 spare. Budget that
--    before adding more dungeons to the H/M model.
-- ---------------------------------------------------------------------
SET @next_id := (SELECT IFNULL(MAX(`id`), 0) FROM `dungeon_access_template`);

INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
SELECT (@next_id := @next_id + 1), s.`map_id`, 1, 80, 255, 0,
       CONCAT(s.`dungeon_name`, ' - Heroic (DC level 80 tier)')
FROM `dc_dungeon_setup` s
WHERE s.`heroic_enabled` = 1
  AND s.`expansion` IN (0, 1)
  AND s.`map_id` < 800
  AND NOT EXISTS (SELECT 1 FROM `dungeon_access_template` t
                  WHERE t.`map_id` = s.`map_id` AND t.`difficulty` = 1);

-- ---------------------------------------------------------------------
-- 3) Mythic rows. No dungeon had a difficulty-2 row anywhere in the
--    table, so Mythic silently inherited whatever Heroic resolved to.
-- ---------------------------------------------------------------------
INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
SELECT (@next_id := @next_id + 1), s.`map_id`, 2, 80, 255, 0,
       CONCAT(s.`dungeon_name`, ' - Mythic (DC level 80 tier)')
FROM `dc_dungeon_setup` s
WHERE s.`mythic_enabled` = 1
  AND s.`expansion` IN (0, 1)
  AND s.`map_id` < 800
  AND NOT EXISTS (SELECT 1 FROM `dungeon_access_template` t
                  WHERE t.`map_id` = s.`map_id` AND t.`difficulty` = 2);


-- =====================================================================
-- Verification
-- =====================================================================
-- Every Classic/TBC heroic dungeon must now report 80/255 at both
-- difficulty 1 and 2 (expect 34 dungeons x 2 rows):
--
--   SELECT s.expansion, t.map_id, s.dungeon_name, t.difficulty,
--          t.min_level, t.max_level
--   FROM dungeon_access_template t
--   JOIN dc_dungeon_setup s ON s.map_id = t.map_id
--   WHERE s.heroic_enabled = 1 AND s.expansion IN (0,1) AND s.map_id < 800
--     AND t.difficulty IN (1,2)
--   ORDER BY s.expansion, t.map_id, t.difficulty;
--
-- No Classic/TBC heroic dungeon may still inherit a sub-80 floor
-- (expect 0 rows):
--
--   SELECT s.map_id, s.dungeon_name FROM dc_dungeon_setup s
--   WHERE s.heroic_enabled = 1 AND s.expansion IN (0,1) AND s.map_id < 800
--     AND NOT EXISTS (SELECT 1 FROM dungeon_access_template t
--                     WHERE t.map_id = s.map_id AND t.difficulty = 1
--                       AND t.min_level = 80);
--
-- The tinyint id ceiling must not have been hit (expect max_id <= 255
-- and no duplicate ids):
--
--   SELECT COUNT(*) rows_used, MAX(id) max_id, 255 - MAX(id) AS headroom
--   FROM dungeon_access_template;
--
-- WotLK dungeons must be untouched - they were already correct at
-- min 80 / max 83 via LFGDungeons.dbc:
--
--   SELECT t.map_id, t.difficulty, t.min_level, t.max_level
--   FROM dungeon_access_template t
--   JOIN dc_dungeon_setup s ON s.map_id = t.map_id
--   WHERE s.expansion = 2 ORDER BY t.map_id, t.difficulty;
-- =====================================================================
