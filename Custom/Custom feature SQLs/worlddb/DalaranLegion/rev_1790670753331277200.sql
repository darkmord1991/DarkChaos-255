-- Map 1413: Classic Larry gets his own display. Display 501245 (shared with Dagg) carries retail Dagg's look
-- (retail display 71932: grey skin, green armor), which is correct for Dagg. Retail Larry is display 72947:
-- blue skin, orange armor, geosets 103/302/401 with the helm group hidden. New CreatureDisplayInfo row 506057
-- (CreatureGeosetData 0x12F3, scale 1.25) ships in CreatureDisplayInfo.dbc.
-- APPLY ONLY AFTER that DBC is on the server: the core drops a creature_template_model row whose display id
-- is missing from its CreatureDisplayInfo.dbc, and Larry would have no model.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 506057;
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`) VALUES
(506057, 1.2574, 1.8862, 2, 0, 0);
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3500510;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(3500510, 0, 506057, 1, 1, 0);
