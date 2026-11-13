-- Map 751: keep the dead on the map.
--
-- 1. Undercity on 751 is the cloned WMO's area 4940, which the server resolves through
--    WMOAreaTable (".gps" inside reports Zone 4940). That zone had no graveyard_zone row, so
--    Graveyard::GetClosestGraveyard logged "graveyard_zone incomplete" and sent a player who
--    died there to the faction's default graveyard on another continent. Linked the way stock
--    Undercity (1497) is: Horde to the Undercity graveyard, Alliance to the Wrath Gate.
--
-- 2. The dungeon copies keep their stock zone ids (Stratholme 2017 for map 821, Scholomance 2057
--    for 822, Shadowfang Keep 209 for 825), and those zones only linked map-0 graveyards. Each now
--    also links the 751 graveyard at its door. For an instance, GetClosestGraveyard takes the
--    graveyard on the instance's corpse map (Map.dbc corpse map) nearest the corpse point, and
--    uses a graveyard on any other map only as a last resort. So 821/822 (corpse map 751) pick
--    these, and stock 329/289/33 (corpse map 0) keep their map-0 graveyards unchanged.
--    Map 825 still has corpse map 0 in Map.dbc; its row is changed to 751 alongside this file
--    (server data/dbc and client), without which 825 keeps using the map-0 graveyards.
--
-- The corpse run back in goes through the entrance trigger creatures, which now also let
-- ghosts through (src/server/scripts/DC/dc_portal_trigger_ghosts.h), so this needs the
-- matching worldserver build.

DELETE FROM `graveyard_zone` WHERE (`ID`, `GhostZone`) IN ((15101, 4940), (15122, 4940), (15127, 2017), (15139, 2057), (15137, 209));
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(15101, 4940, 67, 'Undercity (751) - Horde: Tirisfal Glades, Undercity (751)'),
(15122, 4940, 469, 'Undercity (751) - Alliance: Undercity - Alliance - Wrath Gate (751)'),
(15127, 2017, 0, 'Stratholme copy (map 821) - Eastern Plaguelands, Stratholme (751)'),
(15139, 2057, 0, 'Scholomance copy (map 822) - Western Plaguelands, Scholo GY (751)'),
(15137, 209, 0, 'Shadowfang Keep copy (map 825) - Silverpine Forest, Shadowfang Keep GY (751)');
