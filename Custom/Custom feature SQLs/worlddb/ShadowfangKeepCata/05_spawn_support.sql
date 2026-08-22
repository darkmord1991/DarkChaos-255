-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 5: the spawn support layer
--
-- creature_addon (249) + gameobject_addon (20) + creature_formations (81)
-- + waypoint_data (311 points across 23 paths).
--
-- REQUIRES 04_spawns.sql FIRST -- everything here is guid-keyed and joins the
-- dc_sfk825_cguid / dc_sfk825_gguid maps it created.
--
-- SmartAI (smart_scripts) is deliberately NOT in this file. See 05b.
--
-- ID BAND
--   waypoint_data.id   dense from 5,200,000 (band verified empty; the source path ids
--                      span 3,709,230..3,953,350, far too wide to offset flat)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Waypoint path map. cata_world.creature_addon.waypointPathId -> a dense DC id.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_wpmap`;
CREATE TABLE `dc_sfk825_wpmap` (
    `src_path` INT UNSIGNED NOT NULL PRIMARY KEY,
    `new_path` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uk_new` (`new_path`)
) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_wpmap` (`src_path`, `new_path`)
SELECT p.src_path, 5200000 + (ROW_NUMBER() OVER (ORDER BY p.src_path)) - 1
FROM (
    SELECT DISTINCT a.waypointPathId AS src_path
    FROM `cata_world`.`creature_addon` a
    JOIN `cata_world`.`creature` c ON c.guid = a.guid
    WHERE c.map = 33 AND a.waypointPathId <> 0
) p;

-- -------------------------------------------------------------------------------------
-- 2. waypoint_data -- schema is a clean 1:1 (all 13 AC columns exist in cata_world).
-- -------------------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` BETWEEN 5200000 AND 5299999;
INSERT INTO `waypoint_data`
    (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`,
     `move_type`, `action`, `action_chance`, `wpguid`)
SELECT m.new_path, w.point, w.position_x, w.position_y, w.position_z, w.orientation,
       w.delay, w.move_type, w.action, w.action_chance, w.wpguid
FROM `cata_world`.`waypoint_data` w
JOIN `dc_sfk825_wpmap` m ON m.src_path = w.id;

-- -------------------------------------------------------------------------------------
-- 3. creature_addon
--
-- The schemas differ in shape, not just in names -- this is the one real translation in
-- the whole import. Cataclysm split the two packed 3.3.5 byte fields into named columns:
--
--   UNIT_FIELD_BYTES_1  byte0 StandState | byte2 VisFlags | byte3 AnimTier
--   UNIT_FIELD_BYTES_2  byte0 SheathState | byte1 PvPFlags
--
-- so bytes1/bytes2 are re-packed below. `waypointPathId` becomes `path_id`, remapped.
--
-- AURAS ARE IMPORTED IN FULL. There are only 4 distinct values across the 225 addons
-- that carry any, and all 4 now resolve:
--   29266 Permanent Feign Death  (12 uses)  -- already in spell_dbc
--   58506 Stealth               (11 uses)  -- already in spell_dbc
--   88198 Disease Cloud        (200 uses)  -- downported in 01b, dummy aura, visual only
--   57718 Harpoon Loot Sparkles  (2 uses)  -- downported in 01b, dummy aura, visual only
-- Importing an aura whose spell does not exist is what makes NPCs vanish or spam the log,
-- so RUN 01b BEFORE THIS FILE. The verification block at the bottom re-checks all four.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `new_guid` FROM `dc_sfk825_cguid`);
INSERT INTO `creature_addon`
    (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT
    m.new_guid,
    IFNULL(w.new_path, 0),
    a.mount,
    (a.StandState & 0xFF) | ((a.VisFlags & 0xFF) << 16) | ((a.AnimTier & 0xFF) << 24),
    (a.SheathState & 0xFF) | ((a.PvPFlags & 0xFF) << 8),
    a.emote,
    IFNULL(a.visibilityDistanceType, 0),
    a.auras
FROM `cata_world`.`creature_addon` a
JOIN `cata_world`.`creature` c   ON c.guid = a.guid
JOIN `dc_sfk825_cguid`  m        ON m.src_guid = a.guid
LEFT JOIN `dc_sfk825_wpmap` w    ON w.src_path = a.waypointPathId
WHERE c.map = 33;

-- -------------------------------------------------------------------------------------
-- 4. Waypoint consistency.
--
-- AC logs an error for every creature with MovementType 2 (WAYPOINT) whose addon has no
-- path_id. 23 spawns use waypoints and all 23 paths were imported above, so this should
-- match nothing -- it is a guard against a partial run, not an expected fixup.
-- -------------------------------------------------------------------------------------
UPDATE `creature` c
LEFT JOIN `creature_addon` a ON a.guid = c.guid
SET c.MovementType = 0
WHERE c.map = 825 AND c.MovementType = 2 AND IFNULL(a.path_id, 0) = 0;

-- -------------------------------------------------------------------------------------
-- 5. gameobject_addon -- clean 1:1.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_addon` WHERE `guid` IN (SELECT `new_guid` FROM `dc_sfk825_gguid`);
INSERT INTO `gameobject_addon`
    (`guid`, `parent_rotation0`, `parent_rotation1`, `parent_rotation2`, `parent_rotation3`,
     `invisibilityType`, `invisibilityValue`)
SELECT m.new_guid, a.parent_rotation0, a.parent_rotation1, a.parent_rotation2,
       a.parent_rotation3, a.invisibilityType, a.invisibilityValue
FROM `cata_world`.`gameobject_addon` a
JOIN `cata_world`.`gameobject` g ON g.guid = a.guid
JOIN `dc_sfk825_gguid` m         ON m.src_guid = a.guid
WHERE g.map = 33;

-- -------------------------------------------------------------------------------------
-- 6. creature_formations -- same data, different column names:
--   LeaderGUID -> leaderGUID, MemberGUID -> memberGUID, FollowDistance -> dist,
--   FollowAngle -> angle, GroupAI -> groupAI, InversionPoint1/2 -> point_1/point_2.
--
-- BOTH guids are remapped. A formation whose leader is outside map 33 would dangle, so
-- the leader is joined through the map as well and such rows are dropped rather than
-- pointed at a guid that does not exist -- a formation with a missing leader is the
-- classic cause of the iteration use-after-free on this fork.
--
-- point_1/point_2 are smallint unsigned in AC but int NULL (default -1) in cata_world,
-- so -1/NULL is normalised to 0.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_formations` WHERE `memberGUID` IN (SELECT `new_guid` FROM `dc_sfk825_cguid`);
INSERT INTO `creature_formations`
    (`leaderGUID`, `memberGUID`, `dist`, `angle`, `groupAI`, `point_1`, `point_2`)
SELECT
    ml.new_guid, mm.new_guid, f.FollowDistance, f.FollowAngle, f.GroupAI,
    GREATEST(IFNULL(f.InversionPoint1, 0), 0),
    GREATEST(IFNULL(f.InversionPoint2, 0), 0)
FROM `cata_world`.`creature_formations` f
JOIN `cata_world`.`creature` cm ON cm.guid = f.MemberGUID AND cm.map = 33
JOIN `cata_world`.`creature` cl ON cl.guid = f.LeaderGUID AND cl.map = 33
JOIN `dc_sfk825_cguid` mm       ON mm.src_guid = f.MemberGUID
JOIN `dc_sfk825_cguid` ml       ON ml.src_guid = f.LeaderGUID;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'waypoint paths (want 23)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `dc_sfk825_wpmap`
UNION ALL SELECT 'waypoint_data points (want 311)', CAST(COUNT(*) AS CHAR)
    FROM `waypoint_data` WHERE `id` BETWEEN 5200000 AND 5299999
UNION ALL SELECT 'creature_addon (want 249)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `new_guid` FROM `dc_sfk825_cguid`)
UNION ALL SELECT 'gameobject_addon (want 20)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_addon` WHERE `guid` IN (SELECT `new_guid` FROM `dc_sfk825_gguid`)
UNION ALL SELECT 'creature_formations (want 81)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations` WHERE `memberGUID` IN (SELECT `new_guid` FROM `dc_sfk825_cguid`)
UNION ALL SELECT 'formations with a missing leader (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations` f WHERE f.memberGUID IN (SELECT `new_guid` FROM `dc_sfk825_cguid`)
      AND f.leaderGUID NOT IN (SELECT guid FROM `creature`)
UNION ALL SELECT 'MovementType 2 without a path (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_addon` a ON a.guid = c.guid
    WHERE c.map = 825 AND c.MovementType = 2 AND IFNULL(a.path_id, 0) = 0
UNION ALL SELECT 'addon auras missing from spell_dbc (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` a
    WHERE a.guid IN (SELECT `new_guid` FROM `dc_sfk825_cguid`)
      AND a.auras IS NOT NULL AND a.auras <> ''
      AND CAST(a.auras AS UNSIGNED) NOT IN (SELECT ID FROM `spell_dbc`);
