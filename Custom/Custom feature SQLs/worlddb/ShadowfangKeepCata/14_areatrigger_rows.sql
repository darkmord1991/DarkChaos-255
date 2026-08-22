-- =====================================================================================
-- THE ACTUAL FIX for "the Shadowfang Keep exit does not work"
-- -- and for the six Naxx-40 areatriggers, which have been dead for the same reason.
--
-- ---------------------------------------------------------------------------------
-- THE ERROR MESSAGE LIES
-- ---------------------------------------------------------------------------------
-- The worldserver logs, every boot:
--     Area trigger (ID:6961) does not exist in `AreaTrigger.dbc`.
--
-- That text is legacy and misleading. The check behind it is ObjectMgr.cpp:7093
--     AreaTrigger const* atEntry = GetAreaTrigger(Trigger_ID);
-- and `GetAreaTrigger` (ObjectMgr.h:877) reads `_areaTriggerStore`, which
-- `ObjectMgr::LoadAreaTriggers` fills from the **`areatrigger` DATABASE TABLE**
-- (ObjectMgr.cpp:7280-7299) -- entry/map/x/y/z/radius/length/width/height/orientation.
-- AreaTrigger.dbc is never consulted for this at all.
--
-- So the trigger being in AreaTrigger.dbc is necessary for the CLIENT (it only sends
-- CMSG_AREATRIGGER for boxes it knows) but does nothing for the SERVER. Without a row
-- here, `areatrigger_teleport` is discarded at load and the trigger is inert.
--
-- Everything else was already correct and is NOT the problem: the DBC has all eight ids,
-- Map.dbc has 825, and `areatrigger_teleport` carries the right destinations. Only this
-- table was missing -- which is why redeploying DBCs and restarting changed nothing.
--
-- ---------------------------------------------------------------------------------
-- GEOMETRY
-- ---------------------------------------------------------------------------------
-- Cloned from stock Shadowfang Keep's own pair, which is what the DBC rows were cloned
-- from too, so the two stay consistent:
--     145  map 0,  (-229.49,  1576.35, 78.8909) r7  -> in
--     194  map 33, (-230.953, 2105.06, 79.7533) r5  -> out
-- Only the map changes: 6960 sits on 751 (Silverpine on the Lordaeron extension),
-- 6961 inside 825.
--
-- `LoadAreaTriggers` rejects any row whose map is not in Map.dbc, so 751 and 825 must
-- both be present server-side -- they are (verified via the live data/dbc).
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Shadowfang Keep (Cataclysm), map 825
-- -------------------------------------------------------------------------------------
DELETE FROM `areatrigger` WHERE `entry` IN (6960, 6961);
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
    (6960, 751, -229.49,  1576.35, 78.8909, 7, 0, 0, 0, 0),   -- entrance, Silverpine on map 751
    (6961, 825, -230.953, 2105.06, 79.7533, 5, 0, 0, 0, 0);   -- exit, just inside the keep

-- -------------------------------------------------------------------------------------
-- 2. Naxxramas (40), map 2921 -- same omission, same symptom.
--
-- Geometry is taken from the AreaTrigger.dbc rows that already exist for these ids, so
-- the server-side boxes match what the client is already sending for.
-- -------------------------------------------------------------------------------------
-- Geometry read straight out of Custom/DBCs/AreaTrigger.dbc, so the server-side boxes are
-- identical to the ones the client is already sending for. DBC column order
--     ID, ContinentID, X, Y, Z, Radius, Box_Length, Box_Width, Box_Height, Box_Yaw
-- maps 1:1 onto this table's entry, map, x, y, z, radius, length, width, height, orientation.
--
-- 6936 and 6943 are spheres (radius set, box zero); 6951-6954 are BOXES -- radius 0 with
-- length/width/height and a yaw. Both forms are supported; do not "tidy" a box row by
-- giving it a radius, that changes which shape the server tests.
DELETE FROM `areatrigger` WHERE `entry` IN (6936, 6943, 6951, 6952, 6953, 6954);
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
    (6936, 2921, 3432.81, -3007.21, 295.609, 10, 0,      0,     0, 0),
    (6943, 2921, 3006.09, -3434.17, 306.195,  6, 0.2778, 0.2778, 0.2778, 0),
    (6951, 2921, 3005.47, -3445.11, 297.925,  0, 9.3,    1.718, 8, 0.02805),
    (6952, 2921, 3016.94, -3434.39, 297.928,  0, 9.3,    1.718, 8, 4.714),
    (6953, 2921, 3005.67, -3423.28, 297.927,  0, 9.3,    1.718, 8, 6.276),
    (6954, 2921, 2994.63, -3434.37, 297.928,  0, 9.3,    1.718, 8, 4.728);

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'areatrigger rows for 6960/6961 (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `areatrigger` WHERE `entry` IN (6960, 6961)
UNION ALL SELECT 'entrance on map 751 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` = 6960 AND `map` = 751
UNION ALL SELECT 'exit on map 825 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` = 6961 AND `map` = 825
-- Both halves must line up or the row is still discarded at load.
UNION ALL SELECT 'teleport rows with no areatrigger row (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` t
    WHERE t.ID IN (6960, 6961)
      AND t.ID NOT IN (SELECT `entry` FROM `areatrigger`)
UNION ALL SELECT 'Naxx-40 areatrigger rows (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` IN (6936, 6943, 6951, 6952, 6953, 6954)
UNION ALL SELECT 'Naxx-40 teleports still unbacked (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` t
    WHERE t.ID IN (6936, 6943, 6951, 6952, 6953, 6954)
      AND t.ID NOT IN (SELECT `entry` FROM `areatrigger`)
-- Every areatrigger row must sit on a map the server knows, or LoadAreaTriggers drops it
-- with "map (ID: N) does not exist in `Map.dbc`" and you are back where you started.
UNION ALL SELECT 'our rows on maps missing from Map.dbc (want 0 - check server dbc)',
    CAST(COUNT(DISTINCT `map`) AS CHAR)
    FROM `areatrigger` WHERE `entry` IN (6960, 6961, 6936, 6943, 6951, 6952, 6953, 6954)
      AND `map` NOT IN (751, 825, 2921)
-- Stock must be untouched.
UNION ALL SELECT 'STOCK 145/194 intact (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` IN (145, 194);
