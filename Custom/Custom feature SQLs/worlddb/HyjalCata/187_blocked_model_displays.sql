-- ---------------------------------------------------------------------------
-- 187  Hyjal round-45 -- unblock the displays that had no CreatureModelData row
-- ---------------------------------------------------------------------------
-- 181_ fixed 222 of the 238 missing displays; 16 were left because their model
-- had no CreatureModelData row here.  Splitting those 16 by cause:
--
--   ELEVEN use one of EIGHT models whose FILE ALREADY SHIPS in the client --
--     they were blocked purely by a missing DBC row.  Those rows are added in
--     the same round (CreatureModelData ids 502900+, CreatureDisplayInfo rows for
--     the 11 displays) and this file supplies their creature_model_info.
--
--   FIVE have no model file at all and still need the Cata extract + bake:
--     31290 / 31102 / 31098  Horde caravan vehicle (+carriage, +harness)
--     34383  Goblin tradeskill trainer      30108  Azshara falling tree
--
-- Cata's CreatureModelData is 31 fields but its first 28 ARE the WotLK layout
-- verbatim (28*4 = 112 bytes, Cata appends 3), so collision/geobox values were
-- read straight across rather than invented.
--
-- BoundingRadius/CombatReach are the neutral 1.0 / 1.5: every one of these is a
-- doodad or vehicle prop (target dummy, crate, telegraph pole, hazard light,
-- magical implements, armoured wyvern, a shoulder effect), none is a combat NPC
-- whose reach matters.  Gender 2 (none) for the same reason.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (29310,29311,29312,29313,29350,29746,29949,29962,30009,30117,30317);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `gender`, `DisplayID_Other_Gender`) VALUES
(29310, 1.000000, 1.500000, 2, 0),
(29311, 1.000000, 1.500000, 2, 0),
(29312, 1.000000, 1.500000, 2, 0),
(29313, 1.000000, 1.500000, 2, 0),
(29350, 1.000000, 1.500000, 2, 0),
(29746, 1.000000, 1.500000, 2, 0),
(29949, 1.000000, 1.500000, 2, 0),
(29962, 1.000000, 1.500000, 2, 0),
(30009, 1.000000, 1.500000, 2, 0),
(30117, 1.000000, 1.500000, 2, 0),
(30317, 1.000000, 1.500000, 2, 0);

-- Verify -- map-750 displays without model_info should fall from 16 to 5:
--   SELECT COUNT(DISTINCT m.CreatureDisplayID) FROM `creature` c
--     JOIN `creature_template_model` m ON m.CreatureID = c.id
--     LEFT JOIN `creature_model_info` i ON i.DisplayID = m.CreatureDisplayID
--    WHERE c.map = 750 AND i.DisplayID IS NULL;
