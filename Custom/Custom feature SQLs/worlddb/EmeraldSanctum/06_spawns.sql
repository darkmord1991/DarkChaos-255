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
    -- Erennius. MOVED 2026-08-29. The authored 2728.500/2986.100/21.331 put him 47 yd from
    -- the arrival but 8.8 yd BELOW it down a slope, standing in a shallow pond (ground
    -- 21.63 under an MH2O surface at 23.00) -- and his model is human-scale
    -- (BoundingRadius 0.621 / CombatReach 1.863 vs the dragons' 3 / 9), so players walked
    -- straight past him. New spot measured in game: dry, 4.96 yd of relief over 50 yd,
    -- 0 of 121 samples underwater, and 348 yd out so the raid actually walks to him.
    (16520000, 4030001, 824, 0, 0, 7, 1, 0, 3071.052, 3128.700, 25.502, 3.9651, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - first encounter'),
    -- The four Wakeners MUST stay on one shared point -- exactly one is spawned per
    -- instance by the pool block below. Position measured in game 2026-08-29
    -- (.gps: GroundZ 26.951283, FloorZ 26.951283, height data present on all three
    -- of Map/VMap/MMap), replacing the authored 2950.600/3103.100/24.740.
    (16520001, 4030002, 824, 0, 0, 7, 1, 0, 3285.193, 3035.157, 26.951, 3.0878, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 1 of 4, pooled'),
    (16520002, 4030003, 824, 0, 0, 7, 1, 0, 3285.193, 3035.157, 26.951, 3.0878, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 2 of 4, pooled'),
    (16520003, 4030004, 824, 0, 0, 7, 1, 0, 3285.193, 3035.157, 26.951, 3.0878, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 3 of 4, pooled'),
    (16520004, 4030005, 824, 0, 0, 7, 1, 0, 3285.193, 3035.157, 26.951, 3.0878, 604800, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'boss - Dream Giant - Wakener 4 of 4, pooled'),
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

-- -------------------------------------------------------------------------------------
-- The Wakener rotation. ADDED 2026-08-29 -- it was MISSING, and that is why all four
-- dragons stood on top of each other at 2950.6/3103.1 in game.
--
-- The four spawn rows above are commented "pooled" and instance_emerald_sanctum.cpp is
-- built entirely around that: OnPlayerEnter calls DespawnPool(POOL_WAKENER_PARENT) then
-- SpawnPool(POOL_WAKENER_FIRST + weekIndex). With no pool rows at all, PoolMgr had nothing
-- to manage, so every one of the four was just a plain static spawn.
--
-- The ids are fixed by emerald_sanctum.h and must not be renumbered here:
--     POOL_WAKENER_PARENT = 300009 ; POOL_WAKENER_FIRST = 300010 ; WAKENER_COUNT = 4
--
-- Shape (and why each part matters):
--   * one child pool per Wakener, max_limit 1  -> SpawnPool(child) brings up exactly one.
--   * every child carries a `pool_pool` row    -> a pool that has a mother is NOT a
--     top-level pool, so PoolMgr::InitPoolsForMap never auto-spawns it. That is what keeps
--     all four dormant until the script picks one; drop these rows and the bug comes back
--     in a different shape (all four roll independently at map load).
--   * parent max_limit 1                       -> if the script ever fails to run, the map
--     still shows ONE dragon rather than four.
--   * chance 0 everywhere                      -> equal weighting; the actual choice is the
--     week index, not the roll.
-- -------------------------------------------------------------------------------------
DELETE FROM `pool_pool` WHERE `mother_pool` = 300009 OR `pool_id` = 300009;
DELETE FROM `pool_template` WHERE `entry` BETWEEN 300009 AND 300013;
INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
    (300009, 1, 'Emerald Sanctum - Wakener parent (rotating final boss)'),
    (300010, 1, 'Emerald Sanctum - Wakener 1: Ysondre'),
    (300011, 1, 'Emerald Sanctum - Wakener 2: Lethon'),
    (300012, 1, 'Emerald Sanctum - Wakener 3: Emeriss'),
    (300013, 1, 'Emerald Sanctum - Wakener 4: Taerar');

INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`) VALUES
    (16520001, 300010, 0, 'Ysondre the Wakener'),
    (16520002, 300011, 0, 'Lethon the Wakener'),
    (16520003, 300012, 0, 'Emeriss the Wakener'),
    (16520004, 300013, 0, 'Taerar the Wakener');

INSERT INTO `pool_pool` (`pool_id`, `mother_pool`, `chance`, `description`) VALUES
    (300010, 300009, 0, 'Wakener 1 of 4'),
    (300011, 300009, 0, 'Wakener 2 of 4'),
    (300012, 300009, 0, 'Wakener 3 of 4'),
    (300013, 300009, 0, 'Wakener 4 of 4');

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
    WHERE c.`map` = 824 AND t.`entry` IS NULL
UNION ALL SELECT 'wakener pool templates (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `pool_template` WHERE `entry` BETWEEN 300009 AND 300013
UNION ALL SELECT 'wakener pool members (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `pool_creature` WHERE `pool_entry` BETWEEN 300010 AND 300013
UNION ALL SELECT 'wakener children under the parent (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `pool_pool` WHERE `mother_pool` = 300009
-- A Wakener spawn that is NOT in a pool is a static spawn: it comes up unconditionally and
-- stacks on the others. This is the check that would have caught the four-dragon bug.
UNION ALL SELECT 'wakener spawns outside a pool (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `pool_creature` p ON p.`guid` = c.`guid`
    WHERE c.`guid` BETWEEN 16520001 AND 16520004 AND p.`guid` IS NULL;
