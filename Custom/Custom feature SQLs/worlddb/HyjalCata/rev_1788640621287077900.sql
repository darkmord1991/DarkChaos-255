--
-- Cataclysm-era AreaTable.dbc rows insert an intermediate zone level between each racial
-- starting sub-area and its classic parent zone:
--     Northshire Abbey (24) -> Northshire Valley (6170) -> Elwynn Forest (12)
--
-- Map::GetZoneAndAreaId resolves the zone from ParentAreaID one level only
-- (`zoneid = area->zone`), so a player in a starting area now reports zone 6170 instead of
-- 12. `graveyard_zone` has no row for those ids, so every corpse in a racial starting zone
-- logs "Table `graveyard_zone` incomplete" and falls back to the default graveyard.
--
-- Mirror each parent zone's graveyard set onto the intermediate zone; GetClosestGraveyard
-- then picks by distance exactly what it picked before the intermediate level existed.
--
-- 6170 Northshire Valley  -> 12   Elwynn Forest
-- 6176 Coldridge Valley   -> 1    Dun Morogh
-- 6450 Shadowglen         -> 141  Teldrassil
-- 6451 Valley of Trials   -> 14   Durotar
-- 6452 Camp Narache       -> 215  Mulgore
-- 6454 Deathknell         -> 85   Tirisfal Glades
-- 6455 Sunstrider Isle    -> 3430 Eversong Woods
-- 6456 Ammen Vale         -> 3524 Azuremyst Isle
--
DELETE FROM `graveyard_zone` WHERE `GhostZone` IN (6170, 6176, 6450, 6451, 6452, 6454, 6455, 6456);
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`)
SELECT `gz`.`ID`, `m`.`child`, `gz`.`Faction`, `gz`.`Comment`
FROM `graveyard_zone` `gz`
INNER JOIN (
    SELECT 6170 AS `child`, 12 AS `parent`
    UNION ALL SELECT 6176, 1
    UNION ALL SELECT 6450, 141
    UNION ALL SELECT 6451, 14
    UNION ALL SELECT 6452, 215
    UNION ALL SELECT 6454, 85
    UNION ALL SELECT 6455, 3430
    UNION ALL SELECT 6456, 3524
) `m` ON `m`.`parent` = `gz`.`GhostZone`;
