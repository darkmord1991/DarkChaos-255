-- Mount Hyjal graveyard. game_graveyard = physical location (mirrors WorldSafeLocs.dbc id 1723);
-- graveyard_zone = links that graveyard to the zone area (GhostZone). Two different tables in AC.
INSERT IGNORE INTO acore_world.game_graveyard (ID, Map, x, y, z, Comment) VALUES (1723, 750, 4793.13, -2834.27, 1155.03, 'Mount Hyjal');
INSERT IGNORE INTO acore_world.graveyard_zone (ID, GhostZone, Faction, Comment) VALUES (1723, 4923, 0, 'Mount Hyjal');