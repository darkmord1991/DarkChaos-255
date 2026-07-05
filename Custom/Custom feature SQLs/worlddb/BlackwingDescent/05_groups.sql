-- Blackwing Descent (map 669) — spawn groups, summon groups, formations, addons, equips, waypoints
-- Depends on 04_spawns.sql. Re-derives the EXACT SAME dense GUID remap used there
--   ( new_guid = 9555000 + ROW_NUMBER() OVER (ORDER BY guid)  over cata_world.creature map=669 )
-- so every guid reference stays consistent. Entry/map-keyed tables need no remap.
--
-- Cata -> AzerothCore(DarkChaos) mapping:
--   creature_addon:      StandState/VisFlags/AnimTier -> bytes1 ; SheathState/PvPFlags -> bytes2 ;
--                        waypointPathId -> path_id (repointed to the remapped waypoint_data.id = new_guid*10)
--   creature_formations: LeaderGUID/MemberGUID remapped; FollowDistance->dist, FollowAngle->angle,
--                        InversionPoint1/2 -> point_1/2 (Cata -1 sentinel -> 0)
--   spawn_group_template.groupFlags = 4 (MANUAL_SPAWN) — the instance script owns spawning (Initialize()).

-- ---------------------------------------------------------------------------
-- spawn_group_template + spawn_group (400 shields / 402 nefarian's end / 435 & 436 dwarven spirits)
-- ---------------------------------------------------------------------------
DELETE FROM `spawn_group_template` WHERE `groupId` IN (400,402,435,436);
INSERT INTO `spawn_group_template` (`groupId`, `groupName`, `groupFlags`) VALUES
    (400, 'Blackwing Descent - Ancient Dwarven Shields', 4),
    (402, 'Blackwing Descent - Nefarian''s End', 4),
    (435, 'Blackwing Descent - Dwarven Spirits Left', 4),
    (436, 'Blackwing Descent - Dwarven Spirits Right', 4);

DELETE FROM `spawn_group` WHERE `groupId` IN (400,402,435,436);
INSERT INTO `spawn_group` (`groupId`, `spawnType`, `spawnId`)
SELECT sg.`groupId`, 0, m.`new_guid`
FROM `cata_world`.`spawn_group` sg
JOIN (SELECT `guid` AS old_guid, 9555000 + ROW_NUMBER() OVER (ORDER BY `guid`) AS new_guid FROM `cata_world`.`creature` WHERE `map` = 669) m
    ON m.`old_guid` = sg.`spawnId`
WHERE sg.`groupId` IN (400,402,435,436) AND sg.`spawnType` = 0;

-- ---------------------------------------------------------------------------
-- creature_summon_groups (entry/map-keyed — no guid remap)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_summon_groups` WHERE (`summonerType` = 0 AND `summonerId` IN (41376,41378,42186)) OR (`summonerType` = 2 AND `summonerId` = 669);
INSERT INTO `creature_summon_groups`
    (`summonerId`, `summonerType`, `groupId`, `entry`, `position_x`, `position_y`, `position_z`, `orientation`, `summonType`, `summonTime`, `Comment`)
SELECT `summonerId`, `summonerType`, `groupId`, `entry`, `position_x`, `position_y`, `position_z`, `orientation`, `summonType`, `summonTime`, 'BWD'
FROM `cata_world`.`creature_summon_groups`
WHERE (`summonerType` = 0 AND `summonerId` IN (41376,41378,42186)) OR (`summonerType` = 2 AND `summonerId` = 669);

-- ---------------------------------------------------------------------------
-- creature_addon (guid remap + byte packing + path_id repoint)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9555001 AND 9555999;
INSERT INTO `creature_addon`
    (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT
    m.`new_guid`,
    IF(a.`waypointPathId` > 0, m.`new_guid` * 10, 0),
    a.`mount`,
    a.`StandState` + (a.`VisFlags` << 16) + (a.`AnimTier` << 24),
    a.`SheathState` + (a.`PvPFlags` << 8),
    a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_addon` a
JOIN `cata_world`.`creature` c ON c.`guid` = a.`guid` AND c.`map` = 669
JOIN (SELECT `guid` AS old_guid, 9555000 + ROW_NUMBER() OVER (ORDER BY `guid`) AS new_guid FROM `cata_world`.`creature` WHERE `map` = 669) m
    ON m.`old_guid` = a.`guid`;

-- ---------------------------------------------------------------------------
-- creature_formations (leader + member remap)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_formations` WHERE `leaderGUID` BETWEEN 9555001 AND 9555999;
INSERT INTO `creature_formations`
    (`leaderGUID`, `memberGUID`, `dist`, `angle`, `groupAI`, `point_1`, `point_2`)
SELECT
    ml.`new_guid`, mm.`new_guid`, f.`FollowDistance`, f.`FollowAngle`, f.`GroupAI`,
    IF(f.`InversionPoint1` < 0, 0, f.`InversionPoint1`), IF(f.`InversionPoint2` < 0, 0, f.`InversionPoint2`)
FROM `cata_world`.`creature_formations` f
JOIN (SELECT `guid` AS old_guid, 9555000 + ROW_NUMBER() OVER (ORDER BY `guid`) AS new_guid FROM `cata_world`.`creature` WHERE `map` = 669) ml
    ON ml.`old_guid` = f.`LeaderGUID`
JOIN (SELECT `guid` AS old_guid, 9555000 + ROW_NUMBER() OVER (ORDER BY `guid`) AS new_guid FROM `cata_world`.`creature` WHERE `map` = 669) mm
    ON mm.`old_guid` = f.`MemberGUID`;

-- ---------------------------------------------------------------------------
-- creature_equip_template (entry-keyed — no remap)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (42362,42649,42800,42802,42803,46083,42764,42767,42768);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT `CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, 0
FROM `cata_world`.`creature_equip_template`
WHERE `CreatureID` IN (42362,42649,42800,42802,42803,46083,42764,42767,42768);

-- ---------------------------------------------------------------------------
-- waypoint_data (3 patrol paths; id remapped to new_guid*10 to match creature_addon.path_id)
-- ---------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` BETWEEN 95550010 AND 95559990;
INSERT INTO `waypoint_data`
    (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`, `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT
    m.`new_guid` * 10, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
    w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`, w.`action_chance`, 0
FROM `cata_world`.`waypoint_data` w
JOIN (SELECT `guid` AS old_guid, 9555000 + ROW_NUMBER() OVER (ORDER BY `guid`) AS new_guid FROM `cata_world`.`creature` WHERE `map` = 669) m
    ON m.`old_guid` = (w.`id` DIV 10)
WHERE (w.`id` DIV 10) IN (250050,250116,250117);
