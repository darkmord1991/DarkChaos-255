-- =====================================================================================
-- Emerald Sanctum (map 824) -- boss and rare-elite spawns
--
-- TRASH IS DELIBERATELY NOT IN THIS FILE. An earlier revision scattered ~77 trash spawns
-- procedurally; those were dropped so the packs can be placed by hand, which is the only way
-- to get pull boundaries, patrol lanes and line-of-sight right in rooms this shape.
--
-- What remains is what must be exact or scripted:
--   * the 5 encounter bosses, at their designed positions
--   * the 2 rare elites, because they are POOLED -- `pool_creature` keys on spawn GUIDs, so
--     those rows cannot exist until the spawns do. Hand-placing the rares later would mean
--     rewriting the pool too, so they are pinned here.
--
-- Guid band 16520000-16529999, inside the reserved 16,500,000-16,599,999 block (spawn guids are
-- 24-bit and MAX(creature.guid) was already 16,712,036 against a 16,777,215 ceiling).
--
-- Placing trash by hand: allocate guids from 16520100 upward so they stay inside the
-- reserved block and never collide with the rows below.
-- =====================================================================================


-- Sweep the map, but never the shared entrance/warden NPCs: those live on this map
-- at guid 16622000-16622099 and a blanket delete would remove the way out.
DELETE FROM `pool_creature` WHERE `guid` BETWEEN 16520000 AND 16529999;
DELETE FROM `creature` WHERE `map` = 824
      AND `guid` NOT BETWEEN 16622000 AND 16622099;

INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
    (16520000, 4030001, 824, 0, 0, 7, 1, 0, 2728.500, 2986.100, 21.331, 1.2000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - ruined gate by the arrival'),
    (16520001, 4030002, 824, 0, 0, 7, 1, 0, 2950.600, 3103.100, 24.740, 3.1416, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 1 of 4, pooled'),
    (16520002, 4030003, 824, 0, 0, 7, 1, 0, 2950.600, 3103.100, 24.740, 3.1416, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 2 of 4, pooled'),
    (16520003, 4030004, 824, 0, 0, 7, 1, 0, 2950.600, 3103.100, 24.740, 3.1416, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 3 of 4, pooled'),
    (16520004, 4030005, 824, 0, 0, 7, 1, 0, 2950.600, 3103.100, 24.740, 3.1416, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 4 of 4, pooled'),
    (16520010, 4030151, 824, 0, 0, 7, 1, 0, 3146.000, 2967.000, 24.634, 2.2000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - glade A'),
    (16520011, 4030152, 824, 0, 0, 7, 1, 0, 3238.000, 3232.000, 26.522, 4.0000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - glade E, far north');

-- Pooled rare elites: exactly ONE of these is present per instance, rolled when the
-- map is created. Upstream's pooling-in-instances support (df93fae2e1) gives every
-- instance its own SpawnedPoolData, so each group gets its own roll.
-- max_limit 1 with equal chances (chance 0 = equal weighting).
DELETE FROM `pool_template` WHERE `entry` = 300040;
INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
    (300040, 1, 'Emerald Sanctum - rare elite');
INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`) VALUES
    (16520010, 300040, 0, 'Emerald Sanctum rare 1'),
    (16520011, 300040, 0, 'Emerald Sanctum rare 2');

SELECT 'boss spawns (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `guid` BETWEEN 16520000 AND 16520009
UNION ALL SELECT 'rare spawns (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16520010 AND 16520019
UNION ALL SELECT 'pool members (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` WHERE `pool_entry` = 300040
UNION ALL SELECT 'pool members whose spawn is missing (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` p LEFT JOIN `creature` c ON c.`guid` = p.`guid`
    WHERE p.`pool_entry` = 300040 AND c.`guid` IS NULL
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id`
    WHERE c.`map` = 824 AND t.`entry` IS NULL;
