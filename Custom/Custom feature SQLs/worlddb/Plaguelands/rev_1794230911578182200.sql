-- Undercity on map 751 as the Horde capital of the Lordaeron continent (decided 2026-11-09:
-- Horde only, no Alliance hub; the DarkChaos service added is the teleporter).
--
-- 1. Teleporter menu: "Undercity (Lordaeron)" under Custom Locations (500), Horde only
--    (dc_teleporter.faction is a TeamId, 1 = Horde). The arrival point is game_tele 10649
--    'dcundercity', recorded standing on the Trade Quarter's lower floor of 751's own Undercity
--    (z -62.08, the level Jeremiah Payson and his wandering cockroaches stand on).
--    dc_teleporter is read at startup.
--
-- 2. A DC-WoW Teleporter (800002) in Undercity, 3 yards in front of that arrival point and facing
--    it, so the way out is where players land. Guid from the free block 9025010-9025099, all other
--    columns as the existing 751 Teleporter (guid 16731004 at Shadowfang Keep). Not seen in game:
--    if it stands off the floor, move it with .npc move and update the row.

DELETE FROM `dc_teleporter` WHERE `id` = 509;
INSERT INTO `dc_teleporter` (`id`, `parent`, `type`, `faction`, `security_level`, `comment`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
(509, 500, 2, 1, 0, 'Map 751 capital (Horde), arrival = game_tele dcundercity', 2, 'Undercity (Lordaeron)', 751, 1611.22, 244.5, -62.08, 4.634);

DELETE FROM `creature` WHERE `guid` = 9025010 AND `id` = 800002;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9025010, 800002, 751, 0, 0, 1, 1, 0, 1610.98, 241.51, -62.08, 1.492, 300, 0, 0, 111864, 0, 0, 0, 0, 0, '', NULL, 0, 'Undercity (751) teleporter, Trade Quarter lower floor');
