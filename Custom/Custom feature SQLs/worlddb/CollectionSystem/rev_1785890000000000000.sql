-- Druid/shaman form catalog: add the form skins that shipped in the client
-- patch but never got a CreatureDisplayInfo row, and relabel the rows whose
-- name did not match the skin they actually wear.
--
-- Requires the matching CreatureDisplayInfo.dbc rebuild (ids 503551-503583).

-- form 1
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 1 AND `race` = 0 AND `model` IN (503562, 503563, 503564, 503565, 503566, 503567, 503568, 503569);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(1, 0, 503562, 'Troll Cat - Black', 200, 0),
(1, 0, 503563, 'Troll Cat - Green', 201, 0),
(1, 0, 503564, 'Troll Cat - Red', 202, 0),
(1, 0, 503565, 'Troll Cat - White', 203, 0),
(1, 0, 503566, 'Worgen Cat - Default', 204, 0),
(1, 0, 503567, 'Worgen Cat - Brown', 205, 0),
(1, 0, 503568, 'Worgen Cat - White', 206, 0),
(1, 0, 503569, 'Worgen Cat - Yellow', 207, 0);

-- form 2
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 2 AND `race` = 0 AND `model` IN (503551, 503552, 503553, 503554, 503555);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(2, 0, 503551, 'Tree - Green', 200, 0),
(2, 0, 503552, 'Tree - Orange', 201, 0),
(2, 0, 503553, 'Tree - Purple', 202, 0),
(2, 0, 503554, 'Tree - Red', 203, 0),
(2, 0, 503555, 'Tree - Zandalari', 204, 0);

-- form 3
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 3 AND `race` = 0 AND `model` IN (503558, 503559, 503560, 503561);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(3, 0, 503558, 'Kul Tiran Travel - Blue (Armored)', 200, 0),
(3, 0, 503559, 'Kul Tiran Travel - Brown (Armored)', 201, 0),
(3, 0, 503560, 'Kul Tiran Travel - Green (Armored)', 202, 0),
(3, 0, 503561, 'Kul Tiran Travel - White (Armored)', 203, 0);

-- form 4
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 4 AND `race` = 0 AND `model` IN (503556, 503557);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(4, 0, 503556, 'Zandalari Aquatic - Light', 200, 0),
(4, 0, 503557, 'Zandalari Aquatic - Teal', 201, 0);

-- form 5
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 5 AND `race` = 0 AND `model` IN (503570, 503571, 503572, 503573, 503574, 503575, 503576, 503577);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(5, 0, 503570, 'Troll Bear - Purple', 200, 0),
(5, 0, 503571, 'Troll Bear - Red', 201, 0),
(5, 0, 503572, 'Troll Bear - White', 202, 0),
(5, 0, 503573, 'Troll Bear - Yellow', 203, 0),
(5, 0, 503574, 'Worgen Bear - Default', 204, 0),
(5, 0, 503575, 'Worgen Bear - Brown', 205, 0),
(5, 0, 503576, 'Worgen Bear - Tan', 206, 0),
(5, 0, 503577, 'Worgen Bear - White', 207, 0);

-- form 8
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 8 AND `race` = 0 AND `model` IN (503570, 503571, 503572, 503573, 503574, 503575, 503576, 503577);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(8, 0, 503570, 'Troll Dire Bear - Purple', 200, 0),
(8, 0, 503571, 'Troll Dire Bear - Red', 201, 0),
(8, 0, 503572, 'Troll Dire Bear - White', 202, 0),
(8, 0, 503573, 'Troll Dire Bear - Yellow', 203, 0),
(8, 0, 503574, 'Worgen Dire Bear - Default', 204, 0),
(8, 0, 503575, 'Worgen Dire Bear - Brown', 205, 0),
(8, 0, 503576, 'Worgen Dire Bear - Tan', 206, 0),
(8, 0, 503577, 'Worgen Dire Bear - White', 207, 0);

-- form 31
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 31 AND `race` = 0 AND `model` IN (503578, 503579, 503580, 503581, 503582, 503583);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(31, 0, 503578, 'Night Elf Moonkin - Black 3', 200, 0),
(31, 0, 503579, 'Night Elf Moonkin - Blue 3', 201, 0),
(31, 0, 503580, 'Night Elf Moonkin - Default 4', 202, 0),
(31, 0, 503581, 'Night Elf Moonkin - Red 3', 203, 0),
(31, 0, 503582, 'Kul Tiran Moonkin - Black', 204, 0),
(31, 0, 503583, 'Kul Tiran Moonkin - Pale', 205, 0);

-- relabel rows whose name did not match their skin
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Kul Tiran Tree - Default' WHERE `form` = 2 AND `race` = 0 AND `model` = 500519;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Zandalari Aquatic - Armored' WHERE `form` = 4 AND `race` = 0 AND `model` = 500413;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Kul Tiran Travel - Blue (No Armor)' WHERE `form` = 3 AND `race` = 0 AND `model` = 500515;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Kul Tiran Travel - Brown (No Armor)' WHERE `form` = 3 AND `race` = 0 AND `model` = 500516;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Kul Tiran Travel - Green (No Armor)' WHERE `form` = 3 AND `race` = 0 AND `model` = 500517;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Kul Tiran Travel - White (No Armor)' WHERE `form` = 3 AND `race` = 0 AND `model` = 500518;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Highmountain Moonkin - Epic' WHERE `form` = 31 AND `race` = 0 AND `model` = 500502;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Highmountain Moonkin - Default' WHERE `form` = 31 AND `race` = 0 AND `model` = 500500;

-- drop rows that are exact visual duplicates of a sibling
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 31 AND `race` = 0 AND `model` = 500501;
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 31 AND `race` = 0 AND `model` = 500503;

-- Epic moonkin (displays 500486/500487): all three texture slots are bound now
-- that the epic armour BLPs were packed into Creature\druidowlbear\. 500487 is
-- the TAUREN mesh (model 500381), not a second Night Elf skin.
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Night Elf Moonkin - Epic' WHERE `form` = 31 AND `race` = 0 AND `model` = 500486;
UPDATE `dc_shapeshift_form_skins` SET `name` = 'Tauren Moonkin - Epic' WHERE `form` = 31 AND `race` = 0 AND `model` = 500487;

-- The stock 3.3.5a moonkin displays: no custom assets involved, so these are the
-- one pair of moonkin skins guaranteed to render on every client.
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 31 AND `race` = 0 AND `model` IN (15374, 15375);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(31, 0, 15374, 'Night Elf Moonkin - Classic', 206, 0),
(31, 0, 15375, 'Tauren Moonkin - Classic', 207, 0);

-- Moonkin black/red colours, extracted fresh from retail 12.0.7.68974
-- (FileDataIDs 464184-464187 -> Creature\druidowlbear\, packed into patch-G).
-- The two skin halves are mesh-agnostic: slot 1 always takes the neskin1/taskin2
-- atlas layout and slot 2 the neskin2/taskin1 one, so each colour works on both
-- the classic and the epic moonkin mesh.
DELETE FROM `dc_shapeshift_form_skins` WHERE `form` = 31 AND `race` = 0 AND `model` IN (503584, 503585, 503586, 503587, 503588, 503589, 503590, 503591);
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
(31, 0, 503584, 'Night Elf Moonkin - Black (Classic)', 208, 0),
(31, 0, 503585, 'Night Elf Moonkin - Red (Classic)', 209, 0),
(31, 0, 503586, 'Tauren Moonkin - Black (Classic)', 210, 0),
(31, 0, 503587, 'Tauren Moonkin - Red (Classic)', 211, 0),
(31, 0, 503588, 'Night Elf Moonkin - Black (Epic)', 212, 0),
(31, 0, 503589, 'Night Elf Moonkin - Red (Epic)', 213, 0),
(31, 0, 503590, 'Tauren Moonkin - Black (Epic)', 214, 0),
(31, 0, 503591, 'Tauren Moonkin - Red (Epic)', 215, 0);
