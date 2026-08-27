-- 114_blackhowl_real_displays_751.sql -- swap the Blackhowl garrison off its
-- substitute displays and onto the real Cata ones.
--
-- 113_gilneas_city_blackhowl_751.sql shipped with stand-in worgen displays because
-- Cata's 39812-39823 are ExtendedDisplayInfo CHARACTER-NPC displays that did not exist
-- here. gen_map751_blackhowl_displays.py downports them properly:
--   * 7 human displays (ModelID 49/50, the SAME ids Cata uses) via native
--     CreatureDisplayInfoExtra rows 25973-25978/25984 + BakeName. Player models untouched.
--   * 2 worgen displays (39816/39817) via DC NPC-copy model 500962 with the bake bound
--     through MONSTER slots -- worgen has no stock ChrRaces row so the Extra path is dead.
--
-- ORDERING GATE -- DEPLOY THE SERVER DBC FIRST, THEN APPLY THIS FILE.
--   ObjectMgr.cpp:742 skips any creature_template_model row whose CreatureDisplayID is
--   absent from the server's CreatureDisplayInfo.dbc:
--     "Creature (Entry: X) lists non-existing CreatureDisplayID id (Y), this can crash
--      the client."
--   Apply this before /home/wowcore/azeroth-server/data/dbc has the new rows and all four
--   Blackhowl entries lose their models and stop spawning entirely. The client side is
--   already deployed (patch-4, enGB/patch-enGB-3, the WXL mirror, 9 bakes in patch-7);
--   the SERVER copy is the one step this workstation cannot do.
--
-- creature_model_info is the layer that is easy to miss: without it the creature refuses to
-- load with a message naming creature_template_model, which is the WRONG table.

-- ---------------------------------------------------------------------------
-- 1. creature_model_info -- BoundingRadius/CombatReach read off existing displays
--    on the SAME ModelID (49 human male 0.306, 50 human female 0.208, 500962 0.306);
--    a blanket 0.306 is wrong for the female skeleton.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (39812, 39813, 39814, 39815, 39816, 39817, 39818, 39819, 39823);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `gender`) VALUES
(39812, 0.306, 1.5, 0),
(39813, 0.306, 1.5, 0),
(39814, 0.208, 1.5, 1),
(39815, 0.208, 1.5, 1),
(39816, 0.306, 1.5, 0),
(39817, 0.306, 1.5, 0),
(39818, 0.208, 1.5, 1),
(39819, 0.208, 1.5, 1),
(39823, 0.306, 1.5, 0);

-- ---------------------------------------------------------------------------
-- 2. repoint creature_template_model off the substitutes. DisplayScale stays 1 --
--    it MULTIPLIES with CreatureDisplayInfo.CreatureModelScale, and 39823 already
--    carries Creed's 1.75 in the DBC (113's stand-in 35618 was scale 1.0, which is
--    why 113 could put 1.75 in this column).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (4157802, 4157805, 4157806, 4157810);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`,
  `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(4157802, 0, 39823, 1, 1, 15595),
(4157805, 0, 39812, 1, 1, 15595),
(4157805, 1, 39813, 1, 1, 15595),
(4157805, 2, 39814, 1, 1, 15595),
(4157805, 3, 39815, 1, 1, 15595),
(4157806, 0, 39816, 1, 1, 15595),
(4157806, 1, 39817, 1, 1, 15595),
(4157810, 0, 39818, 1, 1, 15595),
(4157810, 1, 39819, 1, 1, 15595);

-- Blackhowl Bloodhound (4157861) is NOT touched: its Cata displays 30211/30213 are
-- already in our DBC and 113 wired them exactly.
