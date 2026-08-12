-- =====================================================================================
-- Crescent Grove (map 823) -- boss and rare-elite spawns
--
-- TRASH IS DELIBERATELY NOT IN THIS FILE. An earlier revision scattered ~210 trash spawns
-- procedurally; those were dropped so the packs can be placed by hand, which is the only way
-- to get pull boundaries, patrol lanes and line-of-sight right in rooms this shape.
--
-- What remains is what must be exact or scripted:
--   * the 7 encounter bosses, at their designed positions
--   * the 3 rare elites, because they are POOLED -- `pool_creature` keys on spawn GUIDs, so
--     those rows cannot exist until the spawns do. Hand-placing the rares later would mean
--     rewriting the pool too, so they are pinned here.
--
-- Guid band 16510000-16519999, inside the reserved 16,500,000-16,599,999 block (spawn guids are
-- 24-bit and MAX(creature.guid) was already 16,712,036 against a 16,777,215 ceiling).
--
-- Placing trash by hand: allocate guids from 16510100 upward so they stay inside the
-- reserved block and never collide with the rows below.
-- =====================================================================================


-- Sweep the map, but never the shared entrance/warden NPCs: those live on this map
-- at guid 16622000-16622099 and a blanket delete would remove the way out.
DELETE FROM `pool_creature` WHERE `guid` BETWEEN 16510000 AND 16519999;
DELETE FROM `creature` WHERE `map` = 823
      AND `guid` NOT BETWEEN 16622000 AND 16622099;

INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
    (16510000, 4020001, 823, 0, 0, 7, 1, 0, 155.300, 69.000, 230.198, 1.0000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - elf-ruin village, by the moongate'),
    (16510001, 4020002, 823, 0, 0, 7, 1, 0, 300.000, -120.000, 274.209, 2.4000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - furbolg camp'),
    (16510002, 4020003, 823, 0, 0, 7, 1, 0, 292.000, -128.000, 274.718, 2.4000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - furbolg camp - Elder ''One Eye'''),
    (16510003, 4020004, 823, 0, 0, 7, 1, 0, 308.000, -112.000, 272.437, 2.4000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - furbolg camp - Elder Blackmaw'),
    (16510004, 4020005, 823, 0, 0, 7, 1, 0, -308.400, -310.300, 291.544, 0.5000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Giant Moonwell'),
    (16510005, 4020006, 823, 0, 0, 7, 1, 0, -540.000, -72.000, 331.570, 3.9000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - satyr camp B - Vilethorn Scar'),
    (16510006, 4020007, 823, 0, 0, 7, 1, 0, -716.300, -202.400, 335.241, 5.6000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - far-west gated ruin - final'),
    (16510010, 4020151, 823, 0, 0, 7, 1, 0, -650.000, -130.000, 332.150, 1.1000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - satyr camp C'),
    (16510011, 4020152, 823, 0, 0, 7, 1, 0, -640.000, -225.000, 334.571, 4.4000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - satyr camp D'),
    (16510012, 4020153, 823, 0, 0, 7, 1, 0, 186.600, -6.400, 235.763, 0.3000, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'rare elite (pooled) - east elf ruin');

-- Pooled rare elites: exactly ONE of these is present per instance, rolled when the
-- map is created. Upstream's pooling-in-instances support (df93fae2e1) gives every
-- instance its own SpawnedPoolData, so each group gets its own roll.
-- max_limit 1 with equal chances (chance 0 = equal weighting).
DELETE FROM `pool_template` WHERE `entry` = 300030;
INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
    (300030, 1, 'Crescent Grove - rare elite');
INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`) VALUES
    (16510010, 300030, 0, 'Crescent Grove rare 1'),
    (16510011, 300030, 0, 'Crescent Grove rare 2'),
    (16510012, 300030, 0, 'Crescent Grove rare 3');

SELECT 'boss spawns (want 7)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `guid` BETWEEN 16510000 AND 16510009
UNION ALL SELECT 'rare spawns (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16510010 AND 16510019
UNION ALL SELECT 'pool members (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` WHERE `pool_entry` = 300030
UNION ALL SELECT 'pool members whose spawn is missing (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` p LEFT JOIN `creature` c ON c.`guid` = p.`guid`
    WHERE p.`pool_entry` = 300030 AND c.`guid` IS NULL
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id`
    WHERE c.`map` = 823 AND t.`entry` IS NULL;
