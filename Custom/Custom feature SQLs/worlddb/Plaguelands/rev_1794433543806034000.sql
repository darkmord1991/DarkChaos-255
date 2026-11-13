-- DarkChaos: map 751 (Lordaeron 130-160) - Alliance route, phase 1, file 3 of 3: travel
-- Set, apply in this order: rev_1794433543554518100.sql (NPCs), rev_1794433543678762600.sql (quests),
-- rev_1794433543806034000.sql (travel).
--
-- 1. Teleporter menu row 510 "Lordaeron - 7th Legion Base Camp" under Custom Locations (500), Alliance only
--    (dc_teleporter.faction is a TeamId: 0 = Alliance). dc_teleporter is read at startup. game_tele 10671
--    dc7thlegion is the same point. A DC-WoW Teleporter stands 3 yd in front of it (file 1).
-- 2. Graveyard 15140 at the camp (this core reads graveyards from game_graveyard; graveyard_zone.Faction is
--    0 = both, 469 = Alliance, 67 = Horde). Linked for Alliance to Silverpine 4935 and Ruins of Gilneas 4939
--    (Spirit Healer in file 1). Graveyard 15134 inside the Horde Forsaken Forward Command becomes Horde-only,
--    so Alliance ghosts no longer rise in the Horde camp (revert: Faction back to 0). Graveyard 15114, the AV
--    Alliance exit next to the Stormpike camp, was linked only to 4932; it also serves Hillsbrad 4936 now.
-- 3. Rested XP: tavern trigger 7003 (a 20 yd sphere on Innkeeper Hallam), faction 2 = Alliance. The client
--    needs the matching AreaTrigger.dbc row (staged with this change, inserted after 7002 inside map 751's
--    run of the file); the server reads only this table. Same scheme as rev_1794429905500124300 (6985-7002).
-- 4. The flight masters need no SQL beyond file 1: taxi is DBC-only. TaxiNodes 400/401/402 and their 12
--    paths are staged as DBCs (client + server).
--
-- Z of the arrival point, the graveyard and the trigger: terrain heightmap of the test client (see file 1).
-- Re-runnable. Apply to acore_world, then restart the worldserver.

-- 1. teleporter
DELETE FROM `dc_teleporter` WHERE `id` = 510;
INSERT INTO `dc_teleporter` (`id`, `parent`, `type`, `faction`, `security_level`, `comment`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
(510, 500, 2, 0, 0, 'Map 751 Alliance camp, arrival = game_tele dc7thlegion', 2, 'Lordaeron - 7th Legion Base Camp', 751, -652, 1700, 31.37, 0.925);
DELETE FROM `game_tele` WHERE `id` = 10671;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
(10671, -652, 1700, 31.37, 0.925, 751, 'dc7thlegion');

-- 2. graveyards
DELETE FROM `game_graveyard` WHERE `ID` = 15140;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(15140, 751, -625, 1625, 31.49, 'Silverpine Forest, 7th Legion Base Camp GY (751)');
DELETE FROM `graveyard_zone` WHERE (`ID`, `GhostZone`) IN ((15140, 4935), (15140, 4939), (15114, 4936));
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(15140, 4935, 469, '7th Legion Base Camp - Silverpine Forest (751), Alliance'),
(15140, 4939, 469, '7th Legion Base Camp - Ruins of Gilneas (751), Alliance'),
(15114, 4936, 469, 'Alterac Valley Alliance Exit - Hillsbrad Foothills (751), Alliance');
UPDATE `graveyard_zone` SET `Faction` = 67 WHERE `ID` = 15134 AND `GhostZone` = 4939;

-- 3. tavern trigger 7003
DELETE FROM `areatrigger` WHERE `entry` = 7003;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(7003, 751, -606, 1761, 31.69, 20, 0, 0, 0, 0);
DELETE FROM `areatrigger_tavern` WHERE `id` = 7003;
INSERT INTO `areatrigger_tavern` (`id`, `name`, `faction`) VALUES
(7003, 'DCPlaguelands - 7th Legion Base Camp', 2);

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'teleporter 510 (want 1)' AS `check`, COUNT(*) AS `n` FROM `dc_teleporter` WHERE `id` = 510 AND `faction` = 0
--   UNION ALL SELECT 'Alliance links of 15140 (want 2)', COUNT(*) FROM `graveyard_zone` WHERE `ID` = 15140 AND `Faction` = 469
--   UNION ALL SELECT 'graveyard 15134 Horde-only (want 1)', COUNT(*) FROM `graveyard_zone` WHERE `ID` = 15134 AND `GhostZone` = 4939 AND `Faction` = 67
--   UNION ALL SELECT 'tavern 7003 (want 1)', COUNT(*) FROM `areatrigger_tavern` WHERE `id` = 7003;
