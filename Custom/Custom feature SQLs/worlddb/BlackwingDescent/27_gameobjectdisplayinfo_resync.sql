-- ---------------------------------------------------------------------------
-- gameobjectdisplayinfo_dbc resync  (Blackwing Descent, map 669)
-- ---------------------------------------------------------------------------
-- The SQL DBC mirror is stale relative to Custom/CSV DBC/GameObjectDisplayInfo.csv
-- (same class of gap fixed for BWD's cauldron/bell/forge earlier -- here it's
-- 15 gameobject_template rows on this map whose displayId was never synced
-- into gameobjectdisplayinfo_dbc at all, mostly plain stock WotLK props
-- (chairs, lamps, doors, mailboxes) plus this project's own housing-decor
-- 101000+ display range). Missing displayId = "not loaded" -- the
-- gameobject is skipped entirely at boot, not just cosmetically broken.
-- All 15 rows already exist in the CSV; this just re-syncs the SQL mirror.
-- One id (10573, Hyjal) is missing from the CSV too and needs separate
-- real-client extraction -- excluded here, tracked as a follow-up.
-- IDs shared with other maps are duplicated here on purpose so each map's
-- apply run stays self-contained (matches this project's existing pattern).
-- ---------------------------------------------------------------------------

DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` IN (676,4891,6396,6651,9040,9041,9042,9043,9683,9946,10138,10139,10363,10407,10463);

INSERT INTO `gameobjectdisplayinfo_dbc`
    (`ID`, `ModelName`, `Sound_1`, `Sound_2`, `Sound_3`, `Sound_4`, `Sound_5`, `Sound_6`, `Sound_7`, `Sound_8`, `Sound_9`, `Sound_10`,
     `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`, `ObjectEffectPackageID`)
VALUES
(676,'World\\Goober\\G_Cage.mdx',0,4676,0,4677,0,0,0,0,0,0,-1.533726,-1.55286,0.396275,1.559119,1.767044,2.72435,0),
(4891,'World\\Lordaeron\\Scholomance\\PassiveDoodads\\CrystalBall\\ScholomanceCrystalBall01.mdx',0,0,0,0,0,0,0,0,0,0,-0.466271,-1.104712,-0.034083,0.419005,1.106913,2.116828,0),
(6396,'World\\Azeroth\\BootyBay\\PassiveDoodad\\FishingBox\\FishingBox.mdx',0,0,0,0,0,0,0,0,0,0,-0.498044,-0.667427,0.001318,0.472693,0.656481,0.607398,0),
(6651,'World\\Goober\\G_CageBase.mdx',0,0,0,0,0,0,0,0,0,0,-1.507048,-1.524041,-0.002633,1.532441,1.515448,0.395486,0),
(9040,'SPELLS\\INSTANCEPORTAL_GREEN_10MAN_HEROIC.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9041,'SPELLS\\INSTANCEPORTAL_GREEN_10MAN.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9042,'SPELLS\\INSTANCEPORTAL_GREEN_25MAN.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9043,'SPELLS\\INSTANCEPORTAL_GREEN_25MAN_HEROIC.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9683,'world\\blackrockv2\\passivedoodads\\blackrockv2_shieldgong_collision.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9946,'WORLD\\BLACKROCKV2\\PASSIVEDOODADS\\BLACKROCKV2_PORTCULLIS_02.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10138,'world\\blackrockv2\\passivedoodads\\blackrockv2_labroom_bloodvial_breaker01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10139,'world\\blackrockv2\\passivedoodads\\blackrockv2_labroom_bloodvial_breaker02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10363,'World\\wmo\\transports\\wmo_elevators\\blackwingv2_elevator_onyxia_transport.wmo',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10407,'World\\wmo\\transports\\wmo_elevators\\blackwingv2_elevator01.wmo',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10463,'WORLD\\BLACKROCKV2\\PASSIVEDOODADS\\BLACKWING_PORTCULLIS.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

