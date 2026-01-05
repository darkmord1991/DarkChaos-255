-- DarkChaos Dungeon Level Audit & Normalization Helpers
-- Purpose: list all Vanilla/TBC dungeon bosses + elites that are not level 80 yet,
--          then provide update templates to bump them to 80 for Heroic/Mythic runs.

/* 1. Inspection Query -------------------------------------------------------
   Shows the current level spread for every elite/boss creature that spawns
   in a Vanilla or TBC 5-player dungeon. Run this before applying updates to
   see which entries still need attention.
*/
USE acore_world;

SELECT
    c.map                                                   AS map_id,
    m.Name                                                  AS map_name,
    ct.entry                                                AS creature_entry,
    ct.name                                                 AS creature_name,
   ct.`rank`                                               AS creature_rank,
    MIN(ct.minlevel)                                        AS min_level,
    MAX(ct.maxlevel)                                        AS max_level,
    COUNT(DISTINCT c.guid)                                  AS spawn_count
FROM creature_template ct
JOIN creature c       ON c.id = ct.entry
JOIN map m            ON m.Id = c.map
JOIN instance_template it  ON it.map = c.map
WHERE m.MapType = 1                      -- 5-player dungeons
  AND m.Expansion IN (0, 1)              -- Vanilla + TBC only
  AND ct.rank >= 2                       -- elites (2) and bosses (3)
  AND COALESCE(it.ScriptName, '') <> ''
GROUP BY c.map, ct.entry
HAVING MAX(ct.maxlevel) <> 80
    OR MIN(ct.minlevel) <> 80
ORDER BY m.Name, ct.rank DESC, ct.entry;/* 2. Normalization Template -------------------------------------------------
   For Vanilla/TBC dungeons: Set differentiated levels for Heroic/Mythic consistency.
   - Normal NPCs (rank 0): level 80
   - Elites (rank 2): level 81
   - Bosses (rank 3): level 82
   Keeping min/max equal prevents scaling drift.
*/
-- UPDATE creature_template ct
-- JOIN creature c ON c.id = ct.entry
-- JOIN map m ON m.Id = c.map
-- JOIN instance_template it ON it.map = c.map
-- SET ct.minlevel = CASE
--     WHEN ct.rank = 0 THEN 80
--     WHEN ct.rank = 2 THEN 81
--     WHEN ct.rank = 3 THEN 82
--     ELSE ct.minlevel
-- END,
-- ct.maxlevel = CASE
--     WHEN ct.rank = 0 THEN 80
--     WHEN ct.rank = 2 THEN 81
--     WHEN ct.rank = 3 THEN 82
--     ELSE ct.maxlevel
-- END
-- WHERE m.MapType = 1
--   AND m.Expansion IN (0, 1)
--   AND COALESCE(it.ScriptName, '') <> ''
--   AND ct.rank IN (0, 2, 3);

/* 3. Optional: ensure elite trash also lands at 80. -------------------------
   If you want non-boss elites (rank = 2) to land at level 80 as well, use the
   following helper to stage the entries first.
*/
SELECT DISTINCT ct.entry
FROM creature_template ct
JOIN creature c ON c.id = ct.entry
JOIN map m      ON m.Id = c.map
JOIN instance_template it ON it.map = c.map
WHERE m.MapType = 1
  AND m.Expansion IN (0, 1)
  AND ct.rank = 2
  AND ct.maxlevel < 80
  AND COALESCE(it.ScriptName, '') <> '';

/* After gathering those entries, run the UPDATE block above with the
   differentiated levels (normal 80, elite 81, boss 82) so Heroic/Mythic provides consistent challenge in Vanilla/TBC dungeons. Do not apply to WotLK dungeons. */

/* 4. WotLK Heroic Dungeon Level Check ---------------------------------------
   Shows the current level spread for elite/boss creatures in WotLK (expansion 2)
   5-player dungeons. Use this to verify Heroic levels before applying Mythic scaling.
*/
USE world;

SELECT
    c.map                                                   AS map_id,
    m.Name                                                  AS map_name,
    ct.entry                                                AS creature_entry,
    ct.name                                                 AS creature_name,
    ct.`rank`                                               AS creature_rank,
    MIN(ct.minlevel)                                        AS min_level,
    MAX(ct.maxlevel)                                        AS max_level,
    COUNT(DISTINCT c.guid)                                  AS spawn_count
FROM creature_template ct
JOIN creature c       ON c.id = ct.entry
JOIN map m            ON m.Id = c.map
JOIN instance_template it  ON it.map = c.map
WHERE m.MapType = 1                      -- 5-player dungeons
  AND m.Expansion = 2                    -- WotLK only
  AND ct.rank >= 2                       -- elites (2) and bosses (3)
  AND COALESCE(it.ScriptName, '') <> ''
GROUP BY c.map, ct.entry
ORDER BY m.Name, ct.rank DESC, ct.entry;
