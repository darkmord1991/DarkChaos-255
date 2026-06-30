-- ==============================================================================
-- Guild House Legion Dalaran (map 1413) graveyards.
-- Death routing: GuildHousePlayerScript (dc_guildhouse.cpp) overrides the chosen graveyard to the
-- nearest game_graveyard ON the guild-house map (FindNearestGraveyardOnMap). Map 1413 had NONE, so
-- the core fell back to graveyard_zone (Dalaran zone 4395 -> id 1359 "Crystalsong, Dalaran GY" on
-- map 571) and yanked players out of the instance. These three cover the tall city (z -372..955);
-- FindNearestGraveyardOnMap picks the nearest level. (No orientation column on this fork's
-- game_graveyard; the script keeps the player's facing.)
-- ==============================================================================

DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15005 AND 15007;
INSERT INTO `game_graveyard` (`ID`,`Map`,`x`,`y`,`z`,`Comment`) VALUES
  (15005,1413,1102.52,1198.41,536.8,'Guild House Legion Dalaran (1413) - Main Deck'),
  (15006,1413,1130.60,978.88,-372.91,'Guild House Legion Dalaran (1413) - Underbelly'),
  (15007,1413,1274.03,928.46,749.79,'Guild House Legion Dalaran (1413) - Upper Spires');
