-- ---------------------------------------------------------------------------
-- gameobjectdisplayinfo_dbc  (Mount Hyjal, map 750)  --  Furnace Door
-- ---------------------------------------------------------------------------
-- Follow-up to 69_gameobjectdisplayinfo_resync.sql: displayId 10573 (GO
-- entry 3808427 "Furnace Door", Firelands/Molten Front content) was the one
-- id in that batch missing from Custom/CSV DBC/GameObjectDisplayInfo.csv too
-- (not just the SQL mirror), so it needed a real extraction rather than a
-- resync. Sourced directly from the real Cataclysm 4.3.4 client (K:/Cata,
-- DBFilesClient\GameObjectDisplayInfo.dbc, enUS/locale-enUS.MPQ base data).
-- Cata's table grew from 19 to 21 fields; the 2 extra trailing fields
-- (both 0 for this row) are dropped to match this project's 19-field
-- WotLK-format convention.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` = 10573;

INSERT INTO `gameobjectdisplayinfo_dbc`
    (`ID`, `ModelName`, `Sound_1`, `Sound_2`, `Sound_3`, `Sound_4`, `Sound_5`, `Sound_6`, `Sound_7`, `Sound_8`, `Sound_9`, `Sound_10`,
     `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`, `ObjectEffectPackageID`)
VALUES
(10573,'world\\expansion03\\doodads\\firelands\\door\\firelands_door_01.mdx',0,0,0,0,0,0,0,0,0,0,-12.674344,-11.235853,-0.678502,10.709324,13.022075,1.806573,0);
