-- Dark Chaos - creature_model_info rows for the custom player race displays (2026-11-17).
--
-- Unit::SetDisplayId writes creature_model_info.Gender into the unit's gender byte, players included.
-- A transform (polymorph sheep, costumes, ...) sets the gender of the transform model (often 2 = none).
-- RestoreDisplayId then puts the native display back, but these native displays had no row, so the gender was
-- never restored. The client then rebuilds the character for sex 2: helms as <stem>_PaU.m2, textures as *_U.blp.
-- Neither exists, so the helm and armour layers vanish (AssetErrors: "Helm composed for sex 2", helm_*_pau.m2).
-- A transform into a female model would likewise leave a male drawn female. Stock races have rows (49/50 ...).
-- Only Gender matters for players; radius/reach copy the stock human rows (player reach is a constant).
-- Ids from ChrRaces Male/FemaleDisplayId: Pandaren 22/23, Vulpera 24, Zandalari 25, Kul Tiran 26, Drakkari 28.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (503910, 503911, 503912, 503913, 503914, 503915, 503916, 503917, 503950, 503951);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
(503910, 0.306, 1.5, 0, 0, 0),
(503911, 0.208, 1.5, 1, 0, 0),
(503912, 0.306, 1.5, 0, 0, 0),
(503913, 0.208, 1.5, 1, 0, 0),
(503914, 0.306, 1.5, 0, 0, 0),
(503915, 0.208, 1.5, 1, 0, 0),
(503916, 0.306, 1.5, 0, 0, 0),
(503917, 0.208, 1.5, 1, 0, 0),
(503950, 0.306, 1.5, 0, 0, 0),
(503951, 0.208, 1.5, 1, 0, 0);
