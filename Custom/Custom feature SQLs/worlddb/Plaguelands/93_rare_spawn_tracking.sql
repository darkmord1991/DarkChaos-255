-- 93_rare_spawn_tracking.sql -- map 751 Lordaeron extension, DB step 32.
--
-- Rare-spawn markers and announcements on map 751. There is no "rare POI" table to
-- regenerate: rares are handled entirely by the C++ RareSpawnAnnounce system
-- (src/server/scripts/DC/RareSpawns/dc_rare_spawn_announce.cpp), which scans
-- `creature` at startup and pushes markers to the addon.
--
-- ===========================================================================
-- THE ACTUAL BLOCKER IS A CONFIG LINE, NOT SQL -- DO THIS FIRST
--
--     RareSpawn.Announce.Maps  defaults to  "750,37"
--
-- **Map 751 is not in it**, and worldserver.conf does not override the key, so the
-- whole continent is invisible to the system. The boot log agrees:
--     "RareSpawnAnnounce: enabled, 2 map(s) ... tracking 82 rare(s) across 2 map(s)"
--
-- Add 751 to worldserver.conf and restart:
--
--     RareSpawn.Announce.Maps = "750,751,37"
--
-- Nothing below matters until that line is in place.
--
-- ===========================================================================
-- OPTIONAL -- rare respawn timers. THIS IS TUNING, NOT A BUG FIX. SKIP IT FREELY.
--
-- Map 751 has 65 rare spawns (60 RARE + 5 RAREELITE) but only **14 would ever be
-- tracked**, because the announcer ignores anything respawning faster than
-- `RareSpawn.Announce.MinRespawnSecs` (3600). 51 of the 65 sit at **300 seconds**.
--
-- That 300 is FAITHFUL TO THE SOURCE, not an import defect -- checked: all 40 of the
-- +4,100,000-band ones have spawntimesecs = 300 in `cata_world` too, and none has a
-- longer source value. Cataclysm demoted a lot of the old rares into ordinary
-- spawns. So raising them is a deliberate content change, which is why it is fenced
-- off down here rather than folded in above.
--
-- For comparison, map 750's 54 rares all clear the threshold already and cluster at
-- 14400 (4h), with a tail out to 136800:
--     750:  14400 x33, 19900 x2, 21600 x1, 43200 x6, 72000 x4, 86400 x7, 136800 x1
--     751:    300 x51, 28800 x2, 120000 x10, 443820 x2
--
-- The UPDATE below adopts map 750's dominant 14400 so all 65 become trackable and
-- the two continents behave the same. It touches ONLY rank 2/4 creatures on map 751
-- that are currently at exactly 300 -- nothing else on the server moves.
-- ===========================================================================
UPDATE `creature` c
JOIN `creature_template` t ON t.`entry` = c.`id`
SET c.`spawntimesecs` = 14400
WHERE c.`map` = 751
  AND t.`rank` IN (2, 4)
  AND c.`spawntimesecs` = 300;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'map-751 rare spawns (want 65)' AS what, COUNT(*) AS n
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND t.`rank` IN (2, 4)
UNION ALL SELECT '  ...now above the 3600s tracking floor (want 65)', COUNT(*)
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND t.`rank` IN (2, 4) AND c.`spawntimesecs` >= 3600
UNION ALL SELECT '  ...still at 300s (want 0)', COUNT(*)
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND t.`rank` IN (2, 4) AND c.`spawntimesecs` = 300
UNION ALL SELECT 'map-750 rares untouched (want 54)', COUNT(*)
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 750 AND t.`rank` IN (2, 4)
UNION ALL SELECT 'NON-rare map-751 spawns still at 300s (must be unchanged)', COUNT(*)
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND t.`rank` NOT IN (2, 4) AND c.`spawntimesecs` = 300;

-- must be empty: a map-751 rare still below the tracking floor, i.e. one the
-- announcer will keep ignoring
SELECT 'PROBLEM: rare still under the 3600s floor' AS problem,
       c.`guid`, c.`id`, CONVERT(t.`name` USING utf8mb4) COLLATE utf8mb4_general_ci AS name,
       c.`spawntimesecs`
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND t.`rank` IN (2, 4) AND c.`spawntimesecs` < 3600;
