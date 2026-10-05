-- Isles of Giants (map 1405), Sunken Temple: the cavern under the island temple has a new floor and teleport zones
-- instead of the basement portals.
-- The cavern shell's floor sat at Z 33.3, under the bottom edge of the temple's outer walls, so anyone who fell off
-- the terrace (or slipped through the stairwell) could run around under the whole temple. The floor is now raised to
-- Z 58.5 (client patch IoG_TempleCavern.wmo + the server vmaps/mmaps of the same package): it buries the foundation
-- just under the lowest walkable part of the temple. The old floor stays below it as a sealed net.
-- Raising it does not give a way back up (the terrace still ends in sheer walls), so every stand point on the cavern
-- floors is now an area-trigger box that teleports to the entrance landing; the same goes for the small walled ledge
-- under the crater hole west of the landing (a 33-yd drop from the hill, no way out). The boxes come from a walk model
-- of the deployed terrain + temple + new cavern: they cover every cavern-floor stand point and keep clear of every
-- temple, stair and terrain surface (plus a jump's height below and 0.5 yd round it).
-- The client needs the AreaTrigger.dbc of the same package: it also moves the map-1405 rows into their sorted place,
-- without which the client never tested ANY map-1405 trigger (6963/6964 included).
--
-- areatrigger / areatrigger_teleport 6965-6984: 9 boxes on the raised floor (Z 58.5), 10 on the old floor (Z 33.3), 1 on the ledge (Z 82.4)
-- gameobject_template 700017 + its 5 spawns (rev_1790927717479313800.sql): they stood on the old floor, now under the
-- raised one. Deleting from gameobject_template is intended (custom id).

DELETE FROM `areatrigger` WHERE `entry` BETWEEN 6965 AND 6984;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(6965, 1405, 6209.5, 1077.25, 58.425, 0, 87, 187.5, 1.05, 0),
(6966, 1405, 6295.75, 1077.25, 58.425, 0, 74.5, 187.5, 1.05, 0),
(6967, 1405, 6202.5, 1027.75, 58.425, 0, 112, 88.5, 1.05, 0),
(6968, 1405, 6203, 1151.5, 58.425, 0, 111, 39, 1.05, 0),
(6969, 1405, 6212.25, 1126.5, 58.425, 0, 92.5, 89, 1.05, 0),
(6970, 1405, 6200.5, 1078, 58.425, 0, 106, 8, 1.05, 0),
(6971, 1405, 6200.75, 1080, 58.425, 0, 106.5, 4, 1.05, 0),
(6972, 1405, 6199.75, 1059.5, 58.425, 0, 107.5, 26, 1.05, 0),
(6973, 1405, 6256.75, 1126.25, 58.425, 0, 2.5, 89.5, 1.05, 0),
(6974, 1405, 6186, 1077.25, 33.275, 0, 105, 187.5, 1.05, 0),
(6975, 1405, 6289.5, 1077.25, 33.275, 0, 87, 187.5, 1.05, 0),
(6976, 1405, 6189.75, 1028.25, 33.275, 0, 112.5, 89.5, 1.05, 0),
(6977, 1405, 6189.75, 1134.75, 33.275, 0, 112.5, 72.5, 1.05, 0),
(6978, 1405, 6189.75, 1087, 33.275, 0, 112.5, 4, 1.05, 0),
(6979, 1405, 6245.5, 1038.25, 33.275, 0, 1, 109.5, 1.05, 0),
(6980, 1405, 6243.75, 1036.25, 33.275, 0, 2.5, 105.5, 1.05, 0),
(6981, 1405, 6245.75, 1040, 33.275, 0, 0.5, 113, 1.05, 0),
(6982, 1405, 6241.25, 1033.5, 33.275, 0, 2.5, 100, 1.05, 0),
(6983, 1405, 6187.25, 1081.75, 33.275, 0, 107.5, 14.5, 1.05, 0),
(6984, 1405, 6207.1196, 1055.2997, 82.4, 0, 6.8609, 10.9783, 1.1, 0.67195);

DELETE FROM `areatrigger_teleport` WHERE `ID` BETWEEN 6965 AND 6984;
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
(6965, 'Isles of Giants - Temple raised cavern floor 1/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6966, 'Isles of Giants - Temple raised cavern floor 2/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6967, 'Isles of Giants - Temple raised cavern floor 3/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6968, 'Isles of Giants - Temple raised cavern floor 4/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6969, 'Isles of Giants - Temple raised cavern floor 5/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6970, 'Isles of Giants - Temple raised cavern floor 6/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6971, 'Isles of Giants - Temple raised cavern floor 7/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6972, 'Isles of Giants - Temple raised cavern floor 8/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6973, 'Isles of Giants - Temple raised cavern floor 9/9 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6974, 'Isles of Giants - Temple old cavern floor 1/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6975, 'Isles of Giants - Temple old cavern floor 2/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6976, 'Isles of Giants - Temple old cavern floor 3/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6977, 'Isles of Giants - Temple old cavern floor 4/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6978, 'Isles of Giants - Temple old cavern floor 5/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6979, 'Isles of Giants - Temple old cavern floor 6/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6980, 'Isles of Giants - Temple old cavern floor 7/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6981, 'Isles of Giants - Temple old cavern floor 8/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6982, 'Isles of Giants - Temple old cavern floor 9/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6983, 'Isles of Giants - Temple old cavern floor 10/10 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504),
(6984, 'Isles of Giants - Temple crater ledge 1/1 -> entrance landing', 1405, 6192.6577, 1084.4207, 81.83047, 6.1340504);

DELETE FROM `gameobject` WHERE `id` = 700017 AND `guid` BETWEEN 9000327 AND 9000331;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 700017 AND `source_type` = 1;
DELETE FROM `gameobject_template` WHERE `entry` = 700017;
