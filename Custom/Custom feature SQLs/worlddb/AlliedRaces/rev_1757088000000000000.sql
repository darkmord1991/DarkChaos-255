-- Totem models for the custom playable races.
--
-- ObjectMgr::GetModelForTotem() has no row for these races, logs
-- "TotemSlot {} with RaceID ({}) have no totem model data defined" and returns 0,
-- which Totem::InitStats() then feeds straight into SetDisplayId(0) -> invisible totems.
--
-- TotemID maps to SummonSlot: 1 = fire, 2 = earth, 3 = water, 4 = air.
--
-- Goblin, Pandaren, Vulpera, Zandalari, Kul Tiran and Dark Iron use their own downported
-- art (custom display band 5006xx / 5051xx). Worgen have none because Worgen cannot be
-- shamans in retail, so they take the generic Alliance (Dwarven) set the client ships.

DELETE FROM `player_totem_model` WHERE `RaceID` IN (9, 12, 22, 23, 24, 25, 26, 27);
INSERT INTO `player_totem_model` (`TotemID`, `RaceID`, `ModelID`) VALUES
-- Goblin (Horde) - Creature\spells\goblinshamantotem_*.m2
(1, 9, 500644), (2, 9, 500643), (3, 9, 500645), (4, 9, 500641),
-- Worgen (Alliance) - no Worgen totem art exists, generic Alliance set
(1, 12, 30754), (2, 12, 30753), (3, 12, 30755), (4, 12, 30736),
-- Pandaren, Alliance - Creature\spells\pandarentotem_*.m2
(1, 22, 500656), (2, 22, 500655), (3, 22, 500657), (4, 22, 500654),
-- Pandaren, Horde - same art as the Alliance Pandaren
(1, 23, 500656), (2, 23, 500655), (3, 23, 500657), (4, 23, 500654),
-- Vulpera (Horde) - World\Expansion07\Doodads\Vulpera\8vp_vulpera_shaman_totem0*.m2
(1, 24, 505139), (2, 24, 505140), (3, 24, 505141), (4, 24, 505142),
-- Zandalari Troll (Horde) - World\Expansion07\Doodads\ZandalariTroll\8tr_zandalari_totem_*.m2
(1, 25, 505135), (2, 25, 505136), (3, 25, 505137), (4, 25, 505138),
-- Kul Tiran (Alliance) - World\Expansion07\Doodads\Human\8hu_kultiras_totem_*.m2
(1, 26, 505143), (2, 26, 505144), (3, 26, 505145), (4, 26, 505146),
-- Dark Iron Dwarf (Alliance) - World\Expansion07\Doodads\DarkIron\8dw_darkiron_totem_*.m2
(1, 27, 505147), (2, 27, 505148), (3, 27, 505149), (4, 27, 505150);
