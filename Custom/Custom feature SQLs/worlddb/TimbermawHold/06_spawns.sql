-- =====================================================================================
-- Timbermaw Hold (map 819) -- boss and rare-elite spawns
--
-- TRASH IS DELIBERATELY NOT IN THIS FILE. An earlier revision scattered ~345 trash spawns
-- procedurally; those were dropped so the packs can be placed by hand, which is the only way
-- to get pull boundaries, patrol lanes and line-of-sight right in rooms this shape.
--
-- What remains is what must be exact or scripted:
--   * the 7 encounter bosses, at their designed positions
--   * the 3 rare elites, because they are POOLED -- `pool_creature` keys on spawn GUIDs, so
--     those rows cannot exist until the spawns do. Hand-placing the rares later would mean
--     rewriting the pool too, so they are pinned here.
--
-- Guid band 16500000-16509999, inside the reserved 16,500,000-16,599,999 block (spawn guids are
-- 24-bit and MAX(creature.guid) was already 16,712,036 against a 16,777,215 ceiling).
--
-- Placing trash by hand: allocate guids from 16500100 upward so they stay inside the
-- reserved block and never collide with the rows below.
-- =====================================================================================


-- Sweep the map, but never the shared entrance/warden NPCs: those live on this map
-- at guid 16622000-16622099 and a blanket delete would remove the way out.
DELETE FROM `pool_creature` WHERE `guid` BETWEEN 16500000 AND 16509999;
DELETE FROM `creature` WHERE `map` = 819
      AND `guid` NOT BETWEEN 16622000 AND 16622099;

INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
    (16500000, 4010001, 819, 0, 0, 7, 1, 0, -7791.200, -3286.500, 200.000, 2.1000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - DungeonLeftCorner'),
    (16500001, 4010002, 819, 0, 0, 7, 1, 0, -7580.000, -3457.300, 201.600, 3.4000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Village01'),
    (16500002, 4010003, 819, 0, 0, 7, 1, 0, -7306.900, -3325.400, 259.600, 4.2000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - VillageInteriorA'),
    (16500003, 4010004, 819, 0, 0, 7, 1, 0, -7770.600, -3653.000, 285.200, 1.2000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - SatyrRoom'),
    (16500004, 4010005, 819, 0, 0, 7, 1, 0, -7927.200, -3810.900, 237.400, 0.6000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Corruption01_Lower'),
    (16500005, 4010006, 819, 0, 0, 7, 1, 0, -7882.500, -3861.600, 311.300, 5.1000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Corruption01_Upper - Ursol'),
    (16500006, 4010007, 819, 0, 0, 7, 1, 0, -7541.000, -3691.200, 377.400, 3.1000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - UrsocRoom - Ursoc, final'),
    (16500010, 4010151, 819, 0, 0, 7, 1, 0, -7464.100, -3431.000, 208.400, 2.0000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - Village02'),
    (16500011, 4010152, 819, 0, 0, 7, 1, 0, -7772.200, -3777.200, 237.900, 1.5000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - Corruption02'),
    (16500012, 4010153, 819, 0, 0, 7, 1, 0, -7765.300, -3195.600, 250.400, 0.8000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - DungeonBackdoorEntrance');

-- Pooled rare elites: exactly ONE of these is present per instance, rolled when the
-- map is created. Upstream's pooling-in-instances support (df93fae2e1) gives every
-- instance its own SpawnedPoolData, so each group gets its own roll.
-- max_limit 1 with equal chances (chance 0 = equal weighting).
DELETE FROM `pool_template` WHERE `entry` = 300020;
INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
    (300020, 1, 'Timbermaw Hold - rare elite');
INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`) VALUES
    (16500010, 300020, 0, 'Timbermaw Hold rare 1'),
    (16500011, 300020, 0, 'Timbermaw Hold rare 2'),
    (16500012, 300020, 0, 'Timbermaw Hold rare 3');

SELECT 'boss spawns (want 7)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `guid` BETWEEN 16500000 AND 16500009
UNION ALL SELECT 'rare spawns (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16500010 AND 16500019
UNION ALL SELECT 'pool members (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` WHERE `pool_entry` = 300020
UNION ALL SELECT 'pool members whose spawn is missing (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` p LEFT JOIN `creature` c ON c.`guid` = p.`guid`
    WHERE p.`pool_entry` = 300020 AND c.`guid` IS NULL
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id`
    WHERE c.`map` = 819 AND t.`entry` IS NULL;
