-- ---------------------------------------------------------------------------
-- 189  Hyjal round-45 -- the last 5 blocked displays (models downported)
-- ---------------------------------------------------------------------------
-- 187_ unblocked 11 of the 16 displays whose model file already shipped.  These
-- five had NO model in the client at all and needed the full extract + bake:
--
--   31290 / 31102 / 31098  Horde caravan vehicle, carriage, harness
--   34383  Goblin tradeskill trainer      30108  Azshara falling tree
--
-- Pulled from the Cata 4.3.4 client (K:/UntouchedClients/Cata, art.MPQ) and run
-- through wxl-baker --native-m2, giving MD20 v264 for the stock 3.3.5 loader.
-- Verified before packing: all five carry non-zero vertex counts (135/88/43/16/
-- 19 -- a 0-vert doodad crashes the client) and the 7 accompanying BLPs are DXT
-- with hasMips=1, not the hasMips=2 that renders green.  13 further textures the
-- models reference were left alone because our client already ships them.
--
-- Client side, same round: 23 files into patch-6 (5 M2 + 11 .skin + 7 BLP),
-- 5 CreatureModelData rows (ids 502908+) and 5 CreatureDisplayInfo rows into the
-- CSVs and their DBCs.  BOTH HALVES MUST GO LIVE TOGETHER.
--
-- Bounding values are the neutral 1.0 / 1.5 with gender 2: every one is a
-- vehicle prop or doodad, not a combat NPC whose reach matters.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (30108,31098,31102,31290,34383);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `gender`, `DisplayID_Other_Gender`) VALUES
(30108, 1.000000, 1.500000, 2, 0),
(31098, 1.000000, 1.500000, 2, 0),
(31102, 1.000000, 1.500000, 2, 0),
(31290, 1.000000, 1.500000, 2, 0),
(34383, 1.000000, 1.500000, 2, 0);

-- Verify -- map-750 displays without model_info should now be 0:
--   SELECT COUNT(DISTINCT m.CreatureDisplayID) FROM `creature` c
--     JOIN `creature_template_model` m ON m.CreatureID = c.id
--     LEFT JOIN `creature_model_info` i ON i.DisplayID = m.CreatureDisplayID
--    WHERE c.map = 750 AND i.DisplayID IS NULL;
