-- ---------------------------------------------------------------------------
-- 206  Map 750 -- remove 452 gameobjects imported twice from two source DBs
-- ---------------------------------------------------------------------------
-- 429 positions on map 750 carry more than one copy of the SAME gameobject
-- entry at the SAME coordinates -- 881 rows where there should be 429.
--
-- WHERE THEY CAME FROM. The Hyjal object layer was imported twice, from two
-- different databases that both describe Cataclysm's Hyjal, into two guid
-- bands:
--
--     guid  9,734,791 - 9,735,708   916 rows   from cata_world   no Comment
--     guid 12,514,524 - 12,627,425  733 rows   from nelt_world   'Hyjal-Nel'
--
-- Traced on a single object to be certain rather than inferred from the guid
-- ranges -- Twilight Arms Crate 3803066 at (5076.33, -2131.17, 1136.56):
--
--     cata_world  guid 237992   spawntime 300  |  ours  9735182   300  (none)
--     cata_world  guid 238103   spawntime 300  |  ours  9735293   300  (none)
--     nelt_world  guid 113184   spawntime 120  |  ours 12613184   120  Hyjal-Nel
--
-- Our 12613184 is nelt's 113184 + 12,500,000. Three crates stand inside each
-- other where the world has one. (cata_world also duplicates it internally,
-- which the same fix cleans up.)
--
-- WHY THIS IS SAFE FOR GAMEOBJECTS BUT WOULD NOT BE FOR CREATURES.
-- A gameobject cannot move. Two of them at identical coordinates render one
-- inside the other -- the second is invisible, unlootable waste, and for a
-- gatherable node it also doubles the spawn density of that node type.
-- Collapsing them to one is always correct.
--
-- Creatures are the opposite, and this file deliberately does NOT touch them.
-- 60 map-750 creatures look like duplicates by the same test, but checking
-- against the source shows they are not: cata_world has 8 Firesworn at exactly
-- (3935, -2562), 3 Wormwing Screechers at (4874, -2784), 2 Lost Wardens at
-- (4545, -3069) -- and we have 8, 3 and 2. Blizzard stacks spawns on one point
-- and lets random movement spread them out. Deleting those would quietly thin
-- out the mobs, so they are left exactly as they are.
--
-- WHICH COPY SURVIVES. Per position, in order:
--   1. a copy that is a member of a spawn pool  -- so no pool ever loses a
--      member and no pool's chances have to be rebalanced;
--   2. failing that, the tagged (nelt) copy, which is traceable;
--   3. failing that, the lowest guid.
-- Under this rule the 452 removed rows have ZERO rows in `pool_gameobject`,
-- `gameobject_addon` or `game_event_gameobject` -- verified, which is why this
-- file only has to touch one table.
--
-- REVERSIBLE. Every removed row is copied into `dc_map750_dupe_backup_go`
-- first, and the DELETE joins against that table rather than re-deriving the
-- set, so the rows deleted are exactly the rows saved. To undo:
--     INSERT INTO `gameobject` SELECT * FROM `dc_map750_dupe_backup_go`;
--
-- Apply against acore_world, then restart worldserver. Idempotent -- a second
-- run finds no duplicates, backs up nothing and deletes nothing.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Back up the rows that are about to go
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_dupe_backup_go` LIKE `gameobject`;

INSERT IGNORE INTO `dc_map750_dupe_backup_go`
SELECT g.*
FROM `gameobject` g
JOIN (
  SELECT `id`, ROUND(`position_x`, 1) px, ROUND(`position_y`, 1) py,
         CAST(SUBSTRING_INDEX(GROUP_CONCAT(`guid` ORDER BY
              EXISTS(SELECT 1 FROM `pool_gameobject` p WHERE p.`guid` = `gameobject`.`guid`) DESC,
              (`Comment` <> '') DESC, `guid` ASC), ',', 1) AS UNSIGNED) keep_guid
  FROM `gameobject`
  WHERE `map` = 750
  GROUP BY `id`, px, py
  HAVING COUNT(*) > 1
) k ON k.`id` = g.`id`
   AND ROUND(g.`position_x`, 1) = k.px
   AND ROUND(g.`position_y`, 1) = k.py
WHERE g.`map` = 750 AND g.`guid` <> k.keep_guid;

-- ---------------------------------------------------------------------------
-- B) Delete exactly what was backed up
-- ---------------------------------------------------------------------------
DELETE g FROM `gameobject` g
JOIN `dc_map750_dupe_backup_go` b ON b.`guid` = g.`guid`;

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM dc_map750_dupe_backup_go;                       -- 452
--
--   -- no position on map 750 holds two copies of the same entry (expect 0):
--   SELECT COUNT(*) FROM (
--     SELECT 1 FROM gameobject WHERE map=750
--      GROUP BY id, ROUND(position_x,1), ROUND(position_y,1)
--     HAVING COUNT(*)>1) x;
--
--   -- nothing was orphaned (all expect 0):
--   SELECT COUNT(*) FROM pool_gameobject p
--    WHERE NOT EXISTS (SELECT 1 FROM gameobject g WHERE g.guid=p.guid);
--   SELECT COUNT(*) FROM gameobject_addon a
--    WHERE NOT EXISTS (SELECT 1 FROM gameobject g WHERE g.guid=a.guid);
--
-- In game: the doubled herb and ore nodes around Hyjal (Juniper Berries,
-- Cinderbloom, Darkwhisper Lodestone, Obsidium Deposit) and the doubled quest
-- objects (Twilight Arms Crate, Stolen Hyjal Egg, Charred Staff Fragment)
-- should each become a single node, and gathering one should no longer leave a
-- second identical node standing in the same spot.
-- ---------------------------------------------------------------------------
