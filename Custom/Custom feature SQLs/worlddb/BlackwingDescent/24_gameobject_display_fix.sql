-- =====================================================================
-- Blackwing Descent Downport  --  24  Missing gameobject displayId rows
-- ---------------------------------------------------------------------
-- 3 gameobjects (203306 "Doodad_BlackrockV2_LabRoom_Cauldron01", 203625
-- "Jumbotron", 204276 "Ancient Bell") reference displayIds (9554/9998/9704)
-- with no matching row anywhere (server gameobjectdisplayinfo_dbc, compiled
-- client DBC, or Custom/CSV DBC master), so all 3 failed to load entirely:
--   Gameobject (GUID: N Entry: M GoType: 10) has an invalid displayId (X),
--   not loaded.
-- Real Cata 4.3.4 (build 15601) GameObjectDisplayInfo.dbc data, extracted
-- from K:/Cata the same way as the item work (see
-- Custom/CSV DBC/GameObjectDisplayInfo.csv for the matching client-side
-- rows + the model/skin/texture asset pack in this same deploy).
-- =====================================================================

DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` IN (9554,9704,9998);

INSERT INTO `gameobjectdisplayinfo_dbc`
    (`ID`, `ModelName`, `Sound_1`, `Sound_2`, `Sound_3`, `Sound_4`, `Sound_5`, `Sound_6`, `Sound_7`, `Sound_8`, `Sound_9`, `Sound_10`,
     `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`, `ObjectEffectPackageID`)
VALUES
(9554, 'WORLD\\BLACKROCKV2\\PASSIVEDOODADS\\BLACKROCKV2_LABROOM_CAULDRON.MDX', 0,0,0,0,0,0,0,0,0,0,
    -11.480136, -12.631937, -0.042685, 13.613278, 12.775516, 14.566513, 0),
(9704, 'world\\blackwingv2\\passivedoodads\\blackwingv2_darkiron_bell_01.mdx', 0,0,0,0,0,0,0,0,0,0,
    -5.542874, -5.550292, -0.005619, 5.553191, 5.545772, 7.762106, 0),
(9998, 'world\\expansion02\\doodads\\generic\\irondwarf\\id_forge_02.mdx', 0,0,0,0,0,0,0,0,0,0,
    -1.792819, -1.029683, -0.007975, 1.655314, 2.446154, 3.819780, 0);
