-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 15: spawn groups
--
-- Fixes this, repeated at runtime:
--     Tried to spawn non-existing (or system) spawn group 413. Blocked.
--
-- `instance_sfk_cata.cpp` stages the whole faction-escort layer through spawn groups
-- 412-432 (Map.cpp:2619 SpawnGroupSpawn / :2708 SpawnGroupDespawn): the Alliance and Horde
-- entrance troops, the disease clouds that advance as each boss dies, Belmont, Ivar
-- Bloodfang, and the outside troops. None of those groups existed here, so every call was
-- refused and none of that layer ever appeared.
--
-- REQUIRES 03_templates.sql and 04_spawns.sql (dc_sfk825_cguid).
--
-- ---------------------------------------------------------------------------------
-- THE IDS ARE KEPT, NOT OFFSET -- deliberately, and it was checked
-- ---------------------------------------------------------------------------------
-- 412-432 are FREE in this database: the only rows anywhere near them are 435 and 436
-- (Blackwing Descent - Dwarven Spirits Left/Right). Keeping the source ids means the C++
-- enum in instance_sfk_cata.cpp needs no change and cannot drift out of step with the
-- data. If a future import wants 412-432, it must move -- not this.
--
-- MEMBERS ARE REMAPPED. spawn_group.spawnId is a creature GUID, and the clone's guids are
-- the dense 16,730,000+ ones from 04, so every member goes through dc_sfk825_cguid. All
-- 281 members are creatures on map 33 (no gameobjects), verified before writing.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. spawn_group_template -- 21 groups. Schema is a clean 1:1.
--
-- `groupFlags` carries across untouched: it is what marks a group MANUAL_SPAWN, i.e.
-- inactive until the instance script asks for it. Zeroing or inventing these would make
-- the staged troops either always present or never spawnable.
-- -------------------------------------------------------------------------------------
DELETE FROM `spawn_group_template` WHERE `groupId` BETWEEN 412 AND 432;
INSERT INTO `spawn_group_template` (`groupId`, `groupName`, `groupFlags`)
SELECT t.groupId, t.groupName, t.groupFlags
FROM `cata_world`.`spawn_group_template` t
WHERE t.groupId BETWEEN 412 AND 432;

-- -------------------------------------------------------------------------------------
-- 2. spawn_group -- 281 members, spawnId remapped to the clone's guids.
--
-- The join to cata_world.creature on map 33 is what keeps this scoped: groups in this id
-- range also carry members belonging to other content in cata_world, and those must not
-- be dragged in.
-- -------------------------------------------------------------------------------------
DELETE FROM `spawn_group` WHERE `groupId` BETWEEN 412 AND 432;
INSERT INTO `spawn_group` (`groupId`, `spawnType`, `spawnId`)
SELECT sg.groupId, sg.spawnType, m.new_guid
FROM `cata_world`.`spawn_group` sg
JOIN `cata_world`.`creature` c ON c.guid = sg.spawnId AND c.map = 33
JOIN `dc_sfk825_cguid` m       ON m.src_guid = sg.spawnId
WHERE sg.groupId BETWEEN 412 AND 432
  AND sg.spawnType = 0;

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'spawn_group_template rows (want 21)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `spawn_group_template` WHERE `groupId` BETWEEN 412 AND 432
UNION ALL SELECT 'spawn_group members (want 281)', CAST(COUNT(*) AS CHAR)
    FROM `spawn_group` WHERE `groupId` BETWEEN 412 AND 432
UNION ALL SELECT 'groups with no members (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spawn_group_template` t WHERE t.groupId BETWEEN 412 AND 432
      AND NOT EXISTS (SELECT 1 FROM `spawn_group` g WHERE g.groupId = t.groupId)
-- Every member must resolve to a real spawn on map 825, or the group spawns nothing.
UNION ALL SELECT 'members whose guid is not on map 825 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spawn_group` g
    WHERE g.groupId BETWEEN 412 AND 432 AND g.spawnType = 0
      AND g.spawnId NOT IN (SELECT `guid` FROM `creature` WHERE `map` = 825)
UNION ALL SELECT 'members still holding a cata_world guid (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spawn_group` g
    WHERE g.groupId BETWEEN 412 AND 432 AND g.spawnId NOT BETWEEN 16730000 AND 16730999
-- Blackwing Descent's groups sit just above this range and must be untouched.
UNION ALL SELECT 'BWD groups 435/436 intact (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `spawn_group_template` WHERE `groupId` IN (435, 436);
