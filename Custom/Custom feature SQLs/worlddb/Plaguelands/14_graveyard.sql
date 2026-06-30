-- Plaguelands graveyard. game_graveyard = physical location (mirrors WorldSafeLocs.dbc id 1724);
-- graveyard_zone = links that graveyard to the zone area (GhostZone). Two different tables in AC.
INSERT IGNORE INTO acore_world.game_graveyard (ID, Map, x, y, z, Comment) VALUES (1724, 751, 2248.10, -3401.22, 114.08, 'Plaguelands');
INSERT IGNORE INTO acore_world.graveyard_zone (ID, GhostZone, Faction, Comment) VALUES (1724, 4924, 0, 'Plaguelands');