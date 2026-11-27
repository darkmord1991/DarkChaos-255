-- Hyjal Frontier graveyards
-- Coordinates are placeholders using the CoT Hyjal raid tileset reference
-- points; refine once the first Noggit pass fixes camp layouts on map 1410.

-- ============================================================
-- game_graveyard (world_safe_locs)
-- ============================================================
DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15000 AND 15009;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(15000, 1410, 4600.0,  -3760.0, 945.0, 'Hyjal Frontier - Jaina''s Encampment'),
(15001, 1410, 4680.0,  -3780.0, 945.0, 'Hyjal Frontier - Thrall''s Vanguard'),
(15002, 1410, 5050.0,  -2800.0, 1470.0, 'Hyjal Frontier - Scorched Groves outpost'),
(15003, 1410, 5370.0,  -3380.0, 1655.0, 'Hyjal Frontier - Nordrassil Roots');

-- ============================================================
-- graveyard_zone (which zone resurrects at which graveyard)
-- ============================================================
DELETE FROM `graveyard_zone` WHERE `GhostZone` BETWEEN 6100 AND 6106;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`) VALUES
(15000, 6101, 0), -- Foothills -> Jaina's Encampment (generic)
(15001, 6101, 67), -- Foothills -> Thrall's Vanguard (Horde only)
(15000, 6105, 0), -- Jaina's Encampment -> Jaina's (self)
(15001, 6106, 0), -- Thrall's Vanguard -> Thrall's (self)
(15002, 6102, 0), -- Scorched Groves -> Groves outpost
(15003, 6103, 0), -- The Summit -> Nordrassil Roots GY
(15003, 6104, 0); -- Nordrassil Roots -> self
