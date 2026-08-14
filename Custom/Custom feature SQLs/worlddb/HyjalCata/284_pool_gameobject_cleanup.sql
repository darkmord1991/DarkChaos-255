-- ---------------------------------------------------------------------------
-- 284  pool_gameobject -- 111 skipped rows on the Hyjal/Plaguelands herb pools
-- ---------------------------------------------------------------------------
--     `pool_gameobject` has a non existing gameobject spawn (GUID: 12514569)
--     defined for pool id (130008237), skipped.
--     `pool_gameobject` has gameobject spawns on multiple different maps for
--     gameobject guid (15051086) in pool id (130012136), skipped.
--
-- 111 lines, and the loader confirms the size: `Loaded 34702 Gameobjects In
-- Pools` against 34,813 rows in the table. Two unrelated causes, both in the
-- 130,000,000 (Hyjal) and 131,000,000 (Plaguelands) pool bands.
--
-- 🔴 THE CROSS-MAP HALF IS THE SAME BUG AS THE DEEPHOLM WORLD-BOSS POOL (r20),
-- and the importers left the evidence in their own `description` column:
--     "GO 2045,[1622,1623,...],map=0"
--     "GO 2045,[1622,1623,...],map=1"
--     "GO 2045,[1622,1623,...],map=530"
-- The nelt source pool is a genuinely CROSS-MAP herb rotation. Each DC importer
-- copied the whole thing, and each member landed on whichever DC map its offset
-- produced: source map=0 -> **751**, map=1 -> **750**, and map=530 stayed on
-- **530**. So single pools now hold Plaguebloom on 751, Icecap on 750 and
-- Silverleaf in Outland. `PoolMgr` fixes a pool's MapId from its FIRST loaded
-- member (PoolMgr.cpp:666-671) and skips every member that disagrees.
--
-- WHY 45 ROWS CLEAR 52 LINES. Which side gets flagged depends on load order --
-- `pool_creature` runs before `pool_gameobject` and can set the pool's MapId --
-- so the core reported 52 rows where only 45 are in the minority. Rather than
-- try to reproduce that ordering, this makes every pool single-map: once no
-- pool spans maps, no member can be flagged whatever loads first.
--
-- The keeper map is the pool's MAJORITY map, counted across `pool_creature` AND
-- `pool_gameobject` together. Checked first: **0 creature members are ever in
-- the minority**, so the majority map always agrees with the creatures where a
-- pool has any, and no creature row needs touching.

-- ---- 1. 59 rows pointing at gameobjects that do not exist ------------------
-- 27 pools. These reference guids with no `gameobject` row at all -- not
-- deleted by 206_ (checked against `dc_map750_dupe_backup_go`: 0 overlap), so
-- they are import residue rather than something this project removed.
-- Verified before deleting: **0 pools are left with zero valid members**, so no
-- pool becomes empty and no rotation is destroyed.
DELETE FROM acore_world.`pool_gameobject`
WHERE NOT EXISTS (SELECT 1 FROM acore_world.`gameobject` g WHERE g.`guid` = `pool_gameobject`.`guid`);

-- ---- 2. 45 minority-map members across 43 pools ----------------------------
-- Listed as explicit (pool_entry, guid) pairs rather than re-derived: the
-- majority-map subquery has to read `pool_gameobject` itself, and MySQL rejects
-- a subquery on the table being deleted from (error 1093).
--
-- Deleting these changes nothing that is currently working -- the core is
-- already skipping every one, so those nodes are unpooled today and stay
-- unpooled. What changes is that their pools become internally consistent.
-- Also verified: 0 pools are emptied by this plus section 1 combined.
DELETE FROM acore_world.`pool_gameobject`
WHERE (`pool_entry`, `guid`) IN (
(130008297,12517016),(130012136,15050107),(131010754,15051052),(131010847,15051078),
(131010942,15051082),(131011039,15050066),(131011137,15050919),(131011137,15051087),
(131011228,15050079),(131011319,15051090),(131011323,15050912),(131011410,15051040),
(131011413,15051080),(131011507,15050597),(131011511,15051075),(131011513,15051061),
(131011604,15051071),(131011606,15051068),(131011705,15051059),(131011708,15051062),
(131011793,15051091),(131011796,15051089),(131011797,15050105),(131011886,15051077),
(131011890,15050908),(131011983,15051070),(131011987,15051088),(131011988,15050355),
(131012080,15051076),(131012083,15051058),(131012172,15050352),(131012174,15050559),
(131012174,15050767),(131012175,15051072),(131012266,15051066),(131012267,15051064),
(131012272,15050770),(131012358,15051092),(131012359,15051081),(131012448,15051083),
(131012449,15051063),(131012453,15051074),(131012538,15051065),(131013413,15050109),
(131013448,15050061));

-- Verify after apply:
--   SELECT COUNT(*) FROM pool_gameobject pg
--    WHERE NOT EXISTS (SELECT 1 FROM gameobject g WHERE g.guid=pg.guid);      -> 0
--   SELECT COUNT(*) FROM (
--     SELECT pool_entry FROM (
--       SELECT pc.pool_entry, c.map FROM pool_creature pc JOIN creature c ON c.guid=pc.guid
--       UNION ALL
--       SELECT pg.pool_entry, g.map FROM pool_gameobject pg JOIN gameobject g ON g.guid=pg.guid
--     ) m GROUP BY pool_entry HAVING COUNT(DISTINCT map)>1) z;                -> 0
--   SELECT COUNT(*) FROM pool_gameobject;                              -> 34,709
--   next boot: "Loaded 34709 Gameobjects In Pools" and all 111 lines gone.
--
-- ---- NOT done here, reported instead -------------------------------------
-- **5 DC-cloned herb nodes are spawned in OUTLAND (map 530)** -- guids
-- 15050060/15050061 Silverleaf, 15050064 Peacebloom, 15050081 Bruiseweed,
-- 15050355 Stranglekelp, all entries in the +3,600,000 band that should only
-- exist on 750/751, at coordinates far outside Outland's playable area
-- (7779,-6567 / -2282,-11741). Removing their pool rows above stops the log
-- lines but leaves the spawns; they are unreachable junk rather than anything a
-- player meets. Deleting live spawns is a bigger call than a log fix, so it is
-- left for a decision rather than bundled in silently.
--
-- The other 2 DC gameobjects off 750/751 are **intentional** and deliberately
-- untouched: 3809082 "Portal to Lor'danel" and 3809083 "Portal to Bilgewater
-- Harbor" on map 37, which is DC's Azshara Crater custom zone.
