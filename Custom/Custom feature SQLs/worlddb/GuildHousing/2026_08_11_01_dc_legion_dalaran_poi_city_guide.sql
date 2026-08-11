-- =============================================================================
-- Legion Dalaran (map 1413) -- Phase B: city guide (points of interest + menus)
-- =============================================================================
-- Source: BFA-HavenCore bfa_world.sql, the Legion Dalaran POI set 5118-5161 and
-- guide menus 20506/20512/20513/20515/20516/20517/20519, plus their gossip
-- strings from bfa_hotfixes.sql broadcast_text.
--
-- points_of_interest has NO map column -- the marker is drawn in the world
-- coordinates of whatever map the player is on -- so every POI coordinate below
-- was converted from retail map 1220 into our map 1413 with a rigid transform
-- fitted from 5 name-matched NPC anchors (Khadgar / Modera / Ansirem / Karlain
-- in the Violet Citadel + Greg at the pet tournament):
--   x' = -0.77746771*x - -0.62892286*y + -2364.3865
--   y' = -0.62892286*x + -0.77746771*y + 4021.6060      (rotation -141.029 deg)
--   z' = z - 203.1140
-- Worst anchor residual: 0.004 yd.
--
-- Retail ids are kept where they were free in our DB (POI 5118-5161, menus
-- 20506+), so the data stays traceable. npc_text ids ARE renumbered into the DC
-- range 8005001+ because 13975/14002/14008/14013/14014 are already used by
-- stock WotLK texts here.
--
-- Two menus are authored rather than ported (their retail bodies are not in the
-- dump): 20509 "Bank" and 20521/20522 "Vendors"/"Trainers", built from the POI
-- set itself. Options whose retail submenu we do not carry were flattened to a
-- direct POI link, so every option in this file does something.
--
-- Safe to re-run. Requires a worldserver restart.
-- =============================================================================

-- ---------- 1. points of interest (44, coordinates in map-1413 space) ----------
DELETE FROM `points_of_interest` WHERE `ID` BETWEEN 5118 AND 5161;
INSERT INTO `points_of_interest` (`ID`, `PositionX`, `PositionY`, `Icon`, `Flags`, `Importance`, `Name`) VALUES
(5118, 1048.7999, 1146.9669, 7, 99, 0, 'Dalaran Eastern Sewer Entrance'),
(5119, 1169.2006, 978.0246, 7, 99, 0, 'Dalaran Western Sewer Entrance'),
(5120, 1045.3581, 1018.8271, 7, 99, 0, 'Dalaran Well'),
(5121, 1240.7924, 1139.9422, 7, 99, 0, 'Dalaran Southern Bank'),
(5122, 978.0862, 1003.6896, 7, 99, 0, 'Dalaran Northern Bank'),
(5123, 1028.1148, 1039.6708, 7, 99, 0, 'Dalaran Barber'),
(5124, 1009.0495, 1222.7387, 7, 99, 0, 'Dalaran Flight Master'),
(5125, 1127.2647, 1128.7646, 7, 99, 0, 'Dalaran Visitor Center'),
(5126, 1179.1608, 1095.3081, 7, 99, 0, 'Dalaran Alliance Inn'),
(5127, 969.9316, 1116.6222, 7, 99, 0, 'Dalaran Horde Inn'),
(5128, 1070.0990, 1043.3813, 7, 99, 0, 'Dalaran Inn'),
(5129, 992.7871, 1170.1734, 7, 99, 0, 'Dalaran Krasus\' Landing'),
(5130, 1183.4262, 1049.4961, 7, 99, 0, 'Dalaran Greyfang\'s Enclave'),
(5131, 1035.1462, 1080.7685, 7, 99, 0, 'Dalaran Windrunner\'s Sanctuary'),
(5132, 1197.6176, 975.0175, 7, 99, 0, 'Dalaran Violet Citadel'),
(5133, 1102.3143, 1254.4781, 7, 99, 0, 'Dalaran Violet Hold'),
(5134, 1026.9182, 1109.0980, 7, 99, 0, 'Dalaran Stable Master'),
(5135, 1143.9473, 954.2135, 7, 99, 0, 'Dalaran Cemetary'),
(5136, 1163.7342, 1127.1653, 7, 99, 0, 'Dalaran Eventide'),
(5137, 1101.5721, 1079.1180, 7, 99, 0, 'Dalaran Chamber of the Guardian'),
(5138, 1007.6694, 967.5024, 7, 99, 0, 'Dalaran Antonidas Memorial'),
(5139, 1079.6552, 955.4935, 7, 99, 0, 'Dalaran Trade District'),
(5140, 1075.0172, 972.1027, 7, 99, 0, 'Dalaran Alchemy Trainer'),
(5141, 1059.1543, 953.8555, 7, 99, 0, 'Dalaran Archaeology Trainer'),
(5142, 1042.0251, 984.9013, 7, 99, 0, 'Dalaran Blacksmithing Trainer'),
(5143, 1128.8701, 995.0738, 7, 99, 0, 'Dalaran Enchanting Trainer'),
(5144, 1118.9195, 963.8209, 7, 99, 0, 'Dalaran First Aid Trainer'),
(5145, 1106.1348, 949.6073, 7, 99, 0, 'Dalaran Tailoring Trainer'),
(5146, 1094.3261, 933.6751, 7, 99, 0, 'Dalaran Leatherworking Trainer'),
(5147, 1070.4149, 939.8255, 7, 99, 0, 'Dalaran Engineering Trainer'),
(5148, 1101.6869, 970.7562, 7, 99, 0, 'Dalaran Jewelcrafting Trainer'),
(5149, 1090.1050, 928.8585, 7, 99, 0, 'Dalaran Skinning Trainer'),
(5150, 1079.7882, 999.0499, 7, 99, 0, 'Dalaran Herbalism Trainer'),
(5151, 1097.8345, 997.8662, 7, 99, 0, 'Dalaran Inscription Trainer'),
(5152, 1026.0265, 986.0308, 7, 99, 0, 'Dalaran Mining Trainer'),
(5153, 1161.6697, 1161.6768, 7, 99, 0, 'Dalaran Fishing Fountain'),
(5154, 1190.8220, 1030.3460, 7, 99, 0, 'Dalaran Cloth Armor & Clothing'),
(5155, 1087.2930, 1147.4675, 7, 99, 0, 'Dalaran Flowers'),
(5156, 1173.2775, 1071.4484, 7, 99, 0, 'Dalaran Fruit Vendor'),
(5157, 1016.4434, 1023.1808, 7, 99, 0, 'Dalaran Pie, Pastry & Cake'),
(5158, 1022.4596, 1053.6434, 7, 99, 0, 'Dalaran Wine & Cheese'),
(5159, 1181.3435, 1170.5431, 7, 99, 0, 'Dalaran General & Trade Store'),
(5160, 1025.8823, 1109.1732, 7, 99, 0, 'Dalaran Pet Store'),
(5161, 1127.4185, 1030.0425, 7, 99, 0, 'Dalaran Toy Store');

-- ---------- 2. gossip texts ----------
DELETE FROM `npc_text` WHERE `ID` BETWEEN 8005001 AND 8005010;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES
(8005001, 'Welcome to Dalaran, traveler.$B$BIs there something I might help you find?', 'Welcome to Dalaran, traveler.$B$BIs there something I might help you find?', 0, 0, 1),
(8005007, 'There are many places of interest in Dalaran. Which do you seek?', 'There are many places of interest in Dalaran. Which do you seek?', 0, 0, 1),
(8005002, 'The most popular inn in Dalaran is the Legerdemain Lounge, just north of the city\'s center.$B$BThe Alliance and Horde Quarters each have their own inns as well, and I am told there is one more beneath the city, in the sewers.', 'The most popular inn in Dalaran is the Legerdemain Lounge, just north of the city\'s center.$B$BThe Alliance and Horde Quarters each have their own inns as well, and I am told there is one more beneath the city, in the sewers.', 0, 0, 1),
(8005003, 'There are many places of interest in Dalaran. Which do you seek?', 'There are many places of interest in Dalaran. Which do you seek?', 0, 0, 1),
(8005004, 'Visiting members of the Alliance keep primarily to Greyfang\'s Enclave in southwestern Dalaran.$B$BThere is an inn there, as well as portals to various cities.', 'Visiting members of the Alliance keep primarily to Greyfang\'s Enclave in southwestern Dalaran.$B$BThere is an inn there, as well as portals to various cities.', 0, 0, 1),
(8005005, 'The visiting Horde keep primarily to the Windrunner\'s Sanctuary in northeastern Dalaran.$B$BThere is an inn there, as well as portals to the various cities.', 'The visiting Horde keep primarily to the Windrunner\'s Sanctuary in northeastern Dalaran.$B$BThere is an inn there, as well as portals to the various cities.', 0, 0, 1),
(8005006, 'The Chamber of the Guardian is a magical focus located directly in the center of Dalaran.', 'The Chamber of the Guardian is a magical focus located directly in the center of Dalaran.', 0, 0, 1),
(8005008, 'There are many places of interest in Dalaran. Which do you seek?', 'There are many places of interest in Dalaran. Which do you seek?', 0, 0, 1),
(8005009, 'There are many places of interest in Dalaran. Which do you seek?', 'There are many places of interest in Dalaran. Which do you seek?', 0, 0, 1),
(8005010, 'Please respect the laws of Dalaran while you are here, stranger.$B$BWere you lost? Is there something I might help you find?', 'Please respect the laws of Dalaran while you are here, stranger.$B$BWere you lost? Is there something I might help you find?', 0, 0, 1);

-- ---------- 3. menus ----------
DELETE FROM `gossip_menu` WHERE `MenuID` IN (20506, 20509, 20512, 20515, 20516, 20517, 20519, 20521, 20522);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(20506, 8005001),
(20506, 8005010),
(20509, 8005007),
(20512, 8005002),
(20515, 8005003),
(20516, 8005004),
(20517, 8005005),
(20519, 8005006),
(20521, 8005008),
(20522, 8005009);

DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (20506, 20509, 20512, 20515, 20516, 20517, 20519, 20521, 20522);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`) VALUES
(20506, 0, 0, 'The Underbelly', 123314, 1, 1, 0, 5118),
(20506, 1, 0, 'Bank', 44628, 1, 1, 20509, 0),
(20506, 2, 0, 'Barber', 45376, 1, 1, 0, 5123),
(20506, 3, 0, 'Flight Master', 45379, 1, 1, 0, 5124),
(20506, 4, 0, 'Guild Master & Vendor', 45380, 1, 1, 0, 5125),
(20506, 5, 0, 'Inn', 44629, 1, 1, 20512, 5128),
(20506, 6, 0, 'Points of Interest', 32180, 1, 1, 20515, 0),
(20506, 7, 0, 'Stable Master', 19208, 1, 1, 0, 5134),
(20506, 8, 0, 'Trainers', 32176, 1, 1, 20522, 0),
(20506, 9, 0, 'Vendors', 32724, 1, 1, 20521, 0),
(20512, 0, 0, 'Alliance Inn', 32133, 1, 1, 0, 5126),
(20512, 1, 0, 'Horde Inn', 32134, 1, 1, 0, 5127),
(20509, 0, 0, 'Northern Bank', 44628, 1, 1, 0, 5122),
(20509, 1, 0, 'Southern Bank', 44628, 1, 1, 0, 5121),
(20515, 0, 0, 'The Alliance Quarter', 32103, 1, 1, 20516, 5130),
(20515, 1, 0, 'The Horde Quarter', 32104, 1, 1, 20517, 5131),
(20515, 2, 0, 'The Violet Citadel', 32105, 1, 1, 0, 5132),
(20515, 3, 0, 'The Violet Hold', 32106, 1, 1, 0, 5133),
(20515, 4, 0, 'Sewers', 32107, 1, 1, 0, 5118),
(20515, 5, 0, 'Trade District', 32121, 1, 1, 0, 5139),
(20515, 6, 0, 'Krasus\' Landing', 32168, 1, 1, 0, 5129),
(20515, 7, 0, 'Antonidas Memorial', 32108, 1, 1, 0, 5138),
(20515, 8, 0, 'Chamber of the Guardian', 123321, 1, 1, 20519, 5137),
(20515, 9, 0, 'The Eventide', 32110, 1, 1, 0, 5136),
(20515, 10, 0, 'Cemetery', 32111, 1, 1, 0, 5135),
(20515, 11, 0, 'Dalaran Well', 0, 1, 1, 0, 5120),
(20515, 12, 0, 'Fishing Fountain', 0, 1, 1, 0, 5153),
(20522, 0, 0, 'Alchemy Trainer', 0, 1, 1, 0, 5140),
(20522, 1, 0, 'Archaeology Trainer', 0, 1, 1, 0, 5141),
(20522, 2, 0, 'Blacksmithing Trainer', 0, 1, 1, 0, 5142),
(20522, 3, 0, 'Enchanting Trainer', 0, 1, 1, 0, 5143),
(20522, 4, 0, 'Engineering Trainer', 0, 1, 1, 0, 5147),
(20522, 5, 0, 'First Aid Trainer', 0, 1, 1, 0, 5144),
(20522, 6, 0, 'Herbalism Trainer', 0, 1, 1, 0, 5150),
(20522, 7, 0, 'Inscription Trainer', 0, 1, 1, 0, 5151),
(20522, 8, 0, 'Jewelcrafting Trainer', 0, 1, 1, 0, 5148),
(20522, 9, 0, 'Leatherworking Trainer', 0, 1, 1, 0, 5146),
(20522, 10, 0, 'Mining Trainer', 0, 1, 1, 0, 5152),
(20522, 11, 0, 'Skinning Trainer', 0, 1, 1, 0, 5149),
(20522, 12, 0, 'Tailoring Trainer', 0, 1, 1, 0, 5145),
(20521, 0, 0, 'Fishing Fountain', 0, 1, 1, 0, 5153),
(20521, 1, 0, 'Cloth Armor & Clothing', 0, 1, 1, 0, 5154),
(20521, 2, 0, 'Flowers', 0, 1, 1, 0, 5155),
(20521, 3, 0, 'Fruit Vendor', 0, 1, 1, 0, 5156),
(20521, 4, 0, 'Pie, Pastry & Cake', 0, 1, 1, 0, 5157),
(20521, 5, 0, 'Wine & Cheese', 0, 1, 1, 0, 5158),
(20521, 6, 0, 'General & Trade Store', 0, 1, 1, 0, 5159),
(20521, 7, 0, 'Pet Store', 0, 1, 1, 0, 5160),
(20521, 8, 0, 'Toy Store', 0, 1, 1, 0, 5161);

-- ---------- 4. attach the guide to the city's guards and citizens ----------
-- These NPCs currently either have no menu at all, or (from Phase A) the WotLK
-- city guide 10043 whose POIs point at map-571 coordinates. Point them at the
-- Legion guide instead.
UPDATE `creature_template` SET `gossip_menu_id` = 20506 WHERE `entry` IN (
  3500148, 3500161, 3500162, 3500163, 3500164, 3500165, 3500166, 3500167,
  3500168, 3500169, 3500171, 3500172, 3500173, 3500174, 3500175, 3500176,
  3500177,                                     -- the 17 Dalaran citizens
  3500340, 3500588, 3500589,                   -- Kirin Tor Guardians
  3500090                                      -- Violet Hold Guard
);
