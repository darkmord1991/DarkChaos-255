-- ---------------------------------------------------------------------------
-- 171  Hyjal round-38 -- the areatable_dbc override + imported world events
-- ---------------------------------------------------------------------------
-- Two findings from the post-restart session, both in the border zones.
--
-- ---------------------------------------------------------------------------
-- (1) Zone 4926 reported as "Blackrock Caverns" -- an override table, not a DBC
-- ---------------------------------------------------------------------------
--     .gps -> Map: 750 (Mount Hyjal) Zone: 4926 (Blackrock Caverns)
--                                    Area: 4926 (Blackrock Caverns)
--
-- Every AreaTable.dbc in the chain says 4926 is "Winterspring" on continent 750
-- -- client patch-4, client patch-enGB-3, Custom/DBCs, Server/data/dbc and the
-- live server file all agree, and the string "Blackrock Caverns" appears in none
-- of them.  The client proves it: the minimap and zone text read Winterspring.
--
-- The name comes from `areatable_dbc`, the ADDITIVE SQL override table, where
-- 85_questsort_areatable_additions.sql registered 4926 as "Blackrock Caverns"
-- for two Cata dungeon quests -- long before 4926 was allocated to Winterspring
-- for this map.  The SQL row wins over the DBC file, and it carries
-- ContinentID 0, ParentAreaID 0 and **AreaBit 0**, so besides the wrong name it
-- silently breaks exploration credit for the whole zone (AreaBit 0 is not a
-- valid exploration bit; the real row uses 1949).
--
-- METHOD NOTE, because it cost a round: `information_schema.TABLES.TABLE_ROWS`
-- reported this table as 0 rows.  That column is an ESTIMATE for InnoDB and is
-- routinely wrong.  Only `SELECT COUNT(*)` proves a *_dbc override table empty,
-- and these tables are exactly where absence must never be assumed.
--
-- The two quests keep working; they simply move to the zone their questgiver
-- actually stands in (4923, Mount Hyjal) instead of naming a dungeon this
-- server does not have.  Blackrock Caverns is not built here -- 85_ says so
-- itself ("not a sign we need that instance built").
DELETE FROM `areatable_dbc` WHERE `ID` = 4926;

UPDATE `quest_template` SET `QuestSortID` = 4923
WHERE `ID` IN (28732, 28735) AND `QuestSortID` = 4926;

-- ---------------------------------------------------------------------------
-- (2) A Scourge Invasion necropolis floating over Winterspring
-- ---------------------------------------------------------------------------
--     GO 4081373 "Necropolis (scale 1.5)" at (6185, -4910), plus Skullpile
--     01-04, Undead Fire and Undead Fire Aura around it.
--
-- 164_ populated the true map extent by copying every stock spawn whose
-- coordinates fall inside the map-750 terrain box.  That is right for terrain
-- and props, but stock spawns are not all unconditional: world-event content
-- lives in the same `creature` / `gameobject` tables and is gated by
-- `game_event_creature` / `game_event_gameobject`.  The import copied the spawn
-- rows and left the gating behind, so Winterspring's Scourge Invasion staging
-- ground is now permanently built on map 750 -- along with Lunar Festival,
-- Darkmoon and the rest.
--
-- WHAT IS REMOVED
--   Only entries that are ENTIRELY event content: every stock spawn of that
--   entry is gated.  An entry with even one ungated stock spawn is normal world
--   content that merely also appears in an event, and is left alone.
--     660 gameobject spawns across 50 entries
--     348 creature   spawns across 31 entries
--
--   Templates are NOT touched -- only the spawns.  If a DC event is ever wired
--   up on map 750 the clones are still there to spawn.
--
-- The source set is materialised into a scratch table first: the subquery that
-- identifies it reads the same table the DELETE targets, which MySQL rejects
-- with "You can't specify target table for update in FROM clause" (1093).
-- Same pattern, and same reason, as 166_'s clone source set.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS `_dc_event_only_go`;
CREATE TABLE `_dc_event_only_go` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_event_only_go` (`id`)
SELECT s.`id` FROM `gameobject` s
LEFT JOIN `game_event_gameobject` e ON e.`guid` = s.`guid`
GROUP BY s.`id` HAVING SUM(e.`guid` IS NOT NULL) = COUNT(*);

DROP TABLE IF EXISTS `_dc_event_only_cre`;
CREATE TABLE `_dc_event_only_cre` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_event_only_cre` (`id`)
SELECT s.`id` FROM `creature` s
LEFT JOIN `game_event_creature` e ON e.`guid` = s.`guid`
GROUP BY s.`id` HAVING SUM(e.`guid` IS NOT NULL) = COUNT(*);

-- CAST to SIGNED before subtracting: `id` is UNSIGNED and MySQL does not
-- guarantee the `id >= offset` guard is evaluated first, so a raw subtraction
-- aborts the statement with "BIGINT UNSIGNED value is out of range".
DELETE FROM `creature_addon`
WHERE `guid` IN (
  SELECT `guid` FROM (
    SELECT c.`guid` FROM `creature` c
    WHERE c.`map` = 750 AND c.`guid` BETWEEN 15600000 AND 15899999
      AND c.`id` >= 3700000
      AND CAST(c.`id` AS SIGNED) - 3700000 IN (SELECT `id` FROM `_dc_event_only_cre`)
  ) x);

DELETE FROM `gameobject`
WHERE `map` = 750 AND `guid` BETWEEN 15600000 AND 15899999
  AND `id` >= 3900000
  AND CAST(`id` AS SIGNED) - 3900000 IN (SELECT `id` FROM `_dc_event_only_go`);

DELETE FROM `creature`
WHERE `map` = 750 AND `guid` BETWEEN 15600000 AND 15899999
  AND `id` >= 3700000
  AND CAST(`id` AS SIGNED) - 3700000 IN (SELECT `id` FROM `_dc_event_only_cre`);

DROP TABLE IF EXISTS `_dc_event_only_go`;
DROP TABLE IF EXISTS `_dc_event_only_cre`;

-- Verify -- both expect 0:
--   SELECT COUNT(*) FROM `areatable_dbc` WHERE `ID` = 4926;
--   SELECT COUNT(*) FROM `gameobject` WHERE `map` = 750 AND `id` >= 3900000
--     AND `name` LIKE '%Necropolis%';
