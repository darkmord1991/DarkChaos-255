-- ==============================================================================
-- Guild House WotLK Dalaran (map 1409) graveyards.
-- Mirrors 2026_06_28_00_dc_guildhouse_1413_graveyards.sql: map 1409 had ZERO game_graveyard rows,
-- so GuildHousePlayerScript::FindNearestGraveyardOnMap (dc_guildhouse.cpp) always came back null and
-- ReviveAtGuildHouseRespawn fell back to the fixed house-entrance coords instead of the actual death
-- location. 1409 and 1413 share the same local coordinate space (their entrance graveyard rows 2001
-- and 15004 are identical x/y/z), so these reuse 1413's Main Deck / Underbelly / Upper Spires anchors.
-- ==============================================================================

DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15008 AND 15010;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
    (15008, 1409, 1102.52, 1198.41, 536.8, 'Guild House WotLK Dalaran (1409) - Main Deck'),
    (15009, 1409, 1130.60, 978.88, -372.91, 'Guild House WotLK Dalaran (1409) - Underbelly'),
    (15010, 1409, 1274.03, 928.46, 749.79, 'Guild House WotLK Dalaran (1409) - Upper Spires');
