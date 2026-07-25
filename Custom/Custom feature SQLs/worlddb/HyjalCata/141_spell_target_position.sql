-- ---------------------------------------------------------------------------
-- 141  Hyjal round-19 -- teleport spells with no destination
-- ---------------------------------------------------------------------------
-- A class the boot log NEVER shows: `spell_target_position` is only consulted at
-- CAST time, so a TELEPORT_UNITS spell whose EFFECT targets TARGET_DEST_DB (17)
-- but has no row here just silently does nothing in game. Found by sweeping
-- spell_dbc for that effect/target shape and diffing against the table.
--
-- 5 of the 7 gaps are placeable; all 5 destinations come from cata_world /
-- nelt_world (which agree wherever both have the row):
--
--   98053  Teleport: Forlorn Spire, Post Assault -> map 861 (Molten Front)
--          The Hyjal-relevant one: without it the post-assault teleport at the
--          end of "The Forlorn Spire" strands the player. Destination verified
--          inside map 861's actual extent (x 541..1527, y -600..762, z -93..235).
--   74948  Twilight Speech          -> Cata map 1 -> DC map 750. Verified on
--          map 750: its y (-4972) sits inside the zone's -4979..-1280 range and
--          147 map-750 spawns are within 300 units of the point.
--   84699  Teleport to Therazane's Throne -> map 646 (Deepholm), unchanged
--   91854  Shadow Teleport                -> map 669 (BWD), unchanged
--   92160  Finkle's Mole Machine Ride     -> map 0, unchanged
-- (646 / 669 / 861 all confirmed live on this server before reusing the id.)
--
-- NOT placed:
--   100509 Teleport to Uldum -- destination is Cata Uldum on map 1; DC has no
--          Uldum, so there is nowhere to send the player.
--   77779  "TEMP Kill Credit w Teleport" -- has no destination row in cata_world
--          or nelt_world either; a Blizzard test spell.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_target_position` WHERE `ID` IN (74948,84699,91854,92160,98053);

INSERT INTO `spell_target_position` (`ID`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`) VALUES
(74948, 750, 4742.48, -4972.12, 907.45, 1.612),
(84699, 646, 2338.16, 143.69, 179.19, 1.131),
(91854, 669, -302.386, -350.7, 220.482, 4.51),
(92160, 0, -7554.72, -1307.73, 249.202, 3.323),
(98053, 861, 1182.03, 157.997, 60.005, 0);
