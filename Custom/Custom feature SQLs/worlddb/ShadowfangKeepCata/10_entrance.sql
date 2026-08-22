-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 10: the entrance
--
-- A walk-in door at the real Shadowfang Keep in Silverpine Forest on map 751, and the
-- matching way back out. Replaces the `.tele dcsfk` GM shortcut as the way players get in.
--
-- ---------------------------------------------------------------------------------
-- THE GEOMETRY IS STOCK'S, COPIED VERBATIM
-- ---------------------------------------------------------------------------------
-- Classic Shadowfang Keep already has exactly this pair, and both boxes are cloned with
-- their positions and radii untouched -- only ContinentID changes:
--
--   145  map 0,  (-229.49, 1576.35, 78.89)  radius 7  -> into map 33
--   194  map 33, (-230.95, 2105.06, 79.75)  radius 5  -> back out to map 0
--
--   6960 map 751, same coords as 145, radius 7  -> into map 825      [added to AreaTrigger.dbc]
--   6961 map 825, same coords as 194, radius 5  -> back out to 751   [added to AreaTrigger.dbc]
--
-- Copying rather than re-measuring matters here. The arrival point inside the keep sits
-- 4.5 yd from the exit box, which has a 5 yd radius -- i.e. you land INSIDE the trigger
-- that sends you back out. That is normally the "walk out and get teleported straight
-- back in" trap the Blackfathom clone had to solve by re-measuring both boxes in game.
-- Stock demonstrably works with this exact geometry, so reproducing it byte-for-byte
-- inherits whatever makes it work instead of gambling on new numbers.
--
-- Map 751's Silverpine Forest (zone 4935) is a clone of stock zone 130, so the door is at
-- the same coordinates. Verified before allocating: 53 creature and 16 gameobject spawns
-- sit within 300 yd of that point on 751, nearest 54 yd -- the terrain is live and
-- populated there, not an empty tile.
--
-- ---------------------------------------------------------------------------------
-- REQUIRES
-- ---------------------------------------------------------------------------------
--   * AreaTrigger.dbc rows 6960/6961 -- ALREADY compiled and deployed to patch-4.MPQ and
--     all three WarcraftXLHost candidate dirs. The CLIENT reads AreaTrigger.dbc itself and
--     only sends CMSG_AREATRIGGER for boxes it knows about, so without the DBC these rows
--     do nothing at all and fail silently.
--   * 02_map825_registration.sql (instance_template, difficulty gates)
--   * the map-825 terrain rename-copy, or the arrival drops you through the world
--
-- Ids 6960/6961: live MAX in AreaTrigger.csv was 6954. Client AreaTrigger ids must stay
-- below 65535 -- the 607xxx band that some older DC docs mention is NOT valid, and no
-- 607xxx row exists in the CSV.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Entrance and exit.
--
-- Targets are stock 145's and 194's own teleport destinations, unchanged apart from the
-- map id -- 825 shares map 33's coordinate space, and 751's Silverpine shares map 0's.
-- -------------------------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6960, 6961);
INSERT INTO `areatrigger_teleport`
    (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`,
     `target_position_z`, `target_orientation`)
VALUES
    (6960, 'Shadowfang Keep (Cataclysm) - Entrance', 825, -229.135, 2109.18, 76.8898, 1.267),
    (6961, 'Shadowfang Keep (Cataclysm) - Exit',     751, -232.796, 1568.28, 76.8909, 4.398);

-- -------------------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------------------
SELECT 'areatrigger_teleport rows (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `areatrigger_teleport` WHERE `ID` IN (6960, 6961)
UNION ALL SELECT 'entrance targets map 825 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 6960 AND `target_map` = 825
UNION ALL SELECT 'exit targets map 751 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 6961 AND `target_map` = 751
-- Stock Shadowfang Keep's own pair must be untouched: 145 still into map 33, 194 still out
-- to map 0. If either of these reads 0, classic SFK's door has been broken.
UNION ALL SELECT 'STOCK 145 still -> map 33 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 145 AND `target_map` = 33
UNION ALL SELECT 'STOCK 194 still -> map 0 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 194 AND `target_map` = 0;

-- ---------------------------------------------------------------------------------
-- Not done here
-- ---------------------------------------------------------------------------------
-- No level or attunement gate sits on the door itself -- entry is governed by
-- dungeon_access_template (158/159/160), which still carries the placeholder 80/85/85
-- from 02 and wants revisiting with the rest of the rescale.
--
-- There is also no questgiver or signpost outside the door on 751 pointing players at it;
-- the two questgivers this instance has are inside.
