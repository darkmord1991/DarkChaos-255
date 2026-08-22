-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 4: spawns
--
-- 505 creatures + 190 gameobjects, copied from cata_world map 33 onto map 825.
-- Coordinates are carried VERBATIM: 825 shares map 33's terrain files and its client
-- art (Map.dbc Directory "Shadowfang"), so the two maps are the same coordinate space.
--
-- REQUIRES 03_templates.sql FIRST -- it creates dc_sfk825_ct_set and the offset templates.
--
-- ---------------------------------------------------------------------------------
-- WHY THE GUIDS ARE REMAPPED DENSELY RATHER THAN OFFSET
-- ---------------------------------------------------------------------------------
-- cata_world map 33 creature guids span 146,563..395,388 -- a range of 248,826 for only
-- 505 rows. AzerothCore hard-caps spawn ids at 0xFFFFFF (16,777,215) in
-- ObjectMgr.cpp:7669/7679, and live MAX(creature.guid) is already 16,721,765, leaving
-- roughly 55,000 usable creature guids in total. A flat `guid + offset` would need five
-- times the whole remaining space. So each spawn is renumbered densely with ROW_NUMBER()
-- (MySQL 8.4) and the mapping is KEPT in a table, because 05 needs it to remap
-- creature_addon / creature_formations, which are guid-keyed.
--
-- Allocated, both verified empty first:
--   creature   guids 16,730,000 .. 16,730,504   (505 dense)
--   gameobject guids 16,510,000 .. 16,510,189   (190 dense)
--
-- Never insert into `creature` or `gameobject` without an explicit guid on this fork --
-- the AUTO_INCREMENT counters sit above 0xFFFFFF and a guid-less INSERT bricks startup
-- with TCE00007.
--
-- ---------------------------------------------------------------------------------
-- SPAWNMASK
-- ---------------------------------------------------------------------------------
-- Source values are 1, 2, 3 -- Cata and 3.3.5 agree that bit0 = normal and bit1 = heroic
-- for a 5-man, so those carry over unchanged. DC adds Mythic as difficulty 2 = bit2 (4),
-- which Cata had no concept of. Mythic is treated as a heroic variant, so bit2 is set
-- exactly where bit1 already is:  1 -> 1,  2 -> 6,  3 -> 7.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Creature guid map. Kept (not TEMPORARY) so 05 can use it and so a clone guid can be
--    traced back to its cata_world source during debugging. Safe to drop once 05 has run
--    and you are happy with the result.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_cguid`;
CREATE TABLE `dc_sfk825_cguid` (
    `src_guid` INT UNSIGNED NOT NULL PRIMARY KEY,
    `new_guid` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uk_new` (`new_guid`)
) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_cguid` (`src_guid`, `new_guid`)
SELECT c.guid, 16730000 + (ROW_NUMBER() OVER (ORDER BY c.guid)) - 1
FROM `cata_world`.`creature` c
WHERE c.map = 33;

-- -------------------------------------------------------------------------------------
-- 2. GameObject guid map.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_gguid`;
CREATE TABLE `dc_sfk825_gguid` (
    `src_guid` INT UNSIGNED NOT NULL PRIMARY KEY,
    `new_guid` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uk_new` (`new_guid`)
) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_gguid` (`src_guid`, `new_guid`)
SELECT g.guid, 16510000 + (ROW_NUMBER() OVER (ORDER BY g.guid)) - 1
FROM `cata_world`.`gameobject` g
WHERE g.map = 33;

-- -------------------------------------------------------------------------------------
-- 3. creature
--
--   guid          dense remap
--   id            +5,000,000
--   map           825
--   zoneId/areaId carried as-is (209 "Shadowfang Keep"): the clone shares the terrain and
--                 the WMO, so both area lookups return the stock area anyway. See the
--                 AreaTable note in Custom/ShadowfangKeepCata/add_sfk825_dbc_rows.py.
--   spawnMask     mythic bit mirrored off heroic (see header)
--   dynamicflags  absent upstream -> AC default 0
--   ScriptName    upstream is empty for all 505 rows (verified); bindings live in 06
--   CreateObject / Comment  absent upstream -> AC defaults
--
--   npcflag / unit_flags   IFNULL(...,0). cata_world stores BOTH as NULL on all 505 rows
--     (they moved to creature_template there), while AzerothCore declares them NOT NULL.
--     Without the guard the whole INSERT aborts with
--         SQL error 1048: Column 'npcflag' cannot be null
--     and map 825 ends up with 0 creatures while the gameobject insert still succeeds --
--     which then leaves 05's addons and formations pointing at guids that do not exist.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `map` = 825;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `ScriptName`, `VerifiedBuild`)
SELECT
     m.new_guid, c.id + 5000000, 825, c.zoneId, c.areaId,
     IF(c.spawnMask & 2, c.spawnMask | 4, c.spawnMask),
     c.phaseMask, c.equipment_id,
     c.position_x, c.position_y, c.position_z, c.orientation, c.spawntimesecs,
     c.wander_distance, c.currentwaypoint, c.curhealth, c.curmana, c.MovementType,
     IFNULL(c.npcflag, 0), IFNULL(c.unit_flags, 0), '', c.VerifiedBuild
FROM `cata_world`.`creature` c
JOIN `dc_sfk825_cguid` m ON m.src_guid = c.guid
WHERE c.map = 33;

-- -------------------------------------------------------------------------------------
-- 4. gameobject
--
--   guid   dense remap (dc_sfk825_gguid)
--   id     dense remap too (dc_sfk825_gomap, built in 03) -- NOT a flat offset. The 43
--          source entries span 18,895..208,524, so `+5,100,000` scattered them over three
--          100k bands and collided with DC's existing 5,301,906.
--   map    825
--   rotation0..3 carried verbatim -- do NOT recompute them from orientation, several
--   SFK doors rely on the authored quaternion.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `map` = 825;
INSERT INTO `gameobject`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
     `position_x`, `position_y`, `position_z`, `orientation`,
     `rotation0`, `rotation1`, `rotation2`, `rotation3`,
     `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`)
SELECT
     m.new_guid, e.new_entry, 825, g.zoneId, g.areaId,
     IF(g.spawnMask & 2, g.spawnMask | 4, g.spawnMask),
     g.phaseMask,
     g.position_x, g.position_y, g.position_z, g.orientation,
     g.rotation0, g.rotation1, g.rotation2, g.rotation3,
     g.spawntimesecs, g.animprogress, g.state, '', g.VerifiedBuild
FROM `cata_world`.`gameobject` g
JOIN `dc_sfk825_gguid` m ON m.src_guid = g.guid
JOIN `dc_sfk825_gomap` e ON e.src_entry = g.id
WHERE g.map = 33;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature spawns (want 505)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `map` = 825
UNION ALL SELECT 'gameobject spawns (want 190)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 825
UNION ALL SELECT 'max creature guid (must be < 16777215)', CAST(MAX(guid) AS CHAR)
    FROM `creature` WHERE `map` = 825
UNION ALL SELECT 'max gameobject guid (must be < 16777215)', CAST(MAX(guid) AS CHAR)
    FROM `gameobject` WHERE `map` = 825
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c WHERE c.map = 825
      AND c.id NOT IN (SELECT entry FROM `creature_template`)
UNION ALL SELECT 'GO spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` g WHERE g.map = 825
      AND g.id NOT IN (SELECT entry FROM `gameobject_template`)
UNION ALL SELECT 'spawnMask values on 825', GROUP_CONCAT(DISTINCT spawnMask ORDER BY spawnMask)
    FROM `creature` WHERE `map` = 825
UNION ALL SELECT 'STOCK map 33 creature spawns (want 216, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 33
UNION ALL SELECT 'STOCK map 33 gameobject spawns (want 173, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 33;
