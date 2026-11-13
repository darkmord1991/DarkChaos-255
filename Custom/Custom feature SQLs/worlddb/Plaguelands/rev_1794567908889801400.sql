-- DarkChaos: rested XP at the three new Alliance inns on map 751 (2026-11-13)
--
-- Phase 2 and 3 of the Alliance route added inns at Greymane Manor (Innkeeper Marla Bradshaw 830326), Stormglen
-- (Innkeeper Lisbeth Ashworth 830329) and the Whispering Shore landing in Tirisfal (Innkeeper Rowena Pike 830330).
-- Like every other 751 inn they get a tavern trigger: a 20 yd sphere about 1 yd above the ground over the innkeeper
-- and the NPCs around them (the same shape as 7003 at the 7th Legion Base Camp). Cata has no tavern trigger at any
-- of these spots. Faction 2 = Alliance.
--
-- The client half is already deployed: AreaTrigger.dbc rows 7004-7006, inside map 751's scan run right after 7003
-- (sha1 3cffd86f, 1,451 records), in the test client's patch-4, the old client's patch-4 / enGB-3 / enGB-4, the
-- server dbc folder and Custom/DBCs + Custom/CSV DBC. Backups *.pre-tavern751p2-20261113.bak.
-- The server reads triggers only from these tables (it never loads AreaTrigger.dbc); .reload does not cover them.
-- Apply to acore_world after the phase-2/3 innkeeper files, then restart the worldserver.

DELETE FROM `areatrigger` WHERE `entry` IN (7004, 7005, 7006);
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(7004, 751, -1611, 2512, 128.6, 20, 0, 0, 0, 0),
(7005, 751, -2466, 1548, 18, 20, 0, 0, 0, 0),
(7006, 751, 2618, 1808, 18, 20, 0, 0, 0, 0);

DELETE FROM `areatrigger_tavern` WHERE `id` IN (7004, 7005, 7006);
INSERT INTO `areatrigger_tavern` (`id`, `name`, `faction`) VALUES
(7004, 'DCPlaguelands - Greymane Manor', 2),
(7005, 'DCPlaguelands - Stormglen', 2),
(7006, 'DCPlaguelands - Whispering Shore Landing', 2);
