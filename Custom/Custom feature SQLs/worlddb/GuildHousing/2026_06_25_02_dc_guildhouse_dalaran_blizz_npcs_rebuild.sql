-- Dark Chaos Guild Housing - REBUILD of the blizzlike-Dalaran population on map 1409 ("guildhousedala").
--
-- Supersedes 2026_06_25_00 (initial clone) and 2026_06_25_01 (event strip). Run THIS file; it wipes any
-- existing DalaranBlizz1409 clone rows and re-creates them correctly. Idempotent (re-runnable).
--
-- Two fixes over the first import:
--   1) WIDER selection box. The first box (x 5750..5950) clipped ~130 yds off the city in X, dropping the
--      Dalaran mage portals (Stormwind/Ironforge/Exodar/Shattrath), the "A Hero's Welcome" inn sign, the
--      Dalaran Fountain, shop signs, lamp posts, mailboxes, chairs/benches and Underbelly props -> whole
--      areas looked empty. True Dalaran footprint is x 5540..6070 / y 350..880 / z 560..715 (verified:
--      widening further adds <10 objects, and Dalaran floats over a crater so there is no Crystalsong
--      content to catch -- nothing exists below z560 here).
--   2) EXACT rigid transform from the Dalaran WMO MODF placements (extracted nd_dalaran.wmo on Northrend
--      map 571 + dalaran2.wmo on the guildhouse map). Pure rotation+translation, scale exactly 1.0:
--          x' = -0.777146*x + 0.629320*y + 5210.5701
--          y' = -0.629320*x - 0.777146*y + 5229.2853
--          z' =  z - 116.0358
--          o' =  o - 2.46091425 rad     (-141.000 deg about Z; GO quaternion left-multiplied by qz)
--      The rotation is the exact 219 deg WMO heading delta (the first import's -141.42 was a 0.42 deg fit
--      error that pulled edge objects ~1.8 yds off). The MODF translation matches the 12-landmark best-fit
--      to 0.02 yd; cloned objects use real map-571 coords so they land exact (the ~1.6 yd landmark residual
--      is just scatter in those hand-placed reference NPCs, not transform error).
--
-- SCOPE (unchanged): map 1409 only; civilians/vendors/critters; EXCLUDE 9 faction war-guard entries and
-- all game_event_* (holiday) spawns; skip creature entries already hand-placed on 1409 (marker rows are
-- ignored by that check so re-runs stay correct).
--
-- EXPECTED VOLUME (audited): creatures 351 (35 with waypoint paths), gameobjects 498.

DROP PROCEDURE IF EXISTS `dc_rebuild_dalaran_1409`;

DELIMITER $$

CREATE PROCEDURE `dc_rebuild_dalaran_1409`()
BEGIN
    -- EXACT transform constants (map 571 -> map 1409), derived from the Dalaran WMO MODF placements:
    --   map 571  nd_dalaran.wmo : heading -219 deg, origin server (5824.882, 666.950, 641.956)
    --   map 1409 (== 1413 dalaran2.wmo) : heading 0 deg, origin server (1103.511, 1045.251, 526.068)
    --   net rotation = 0 - (-219) = 219 deg = -141.000 deg (the earlier -141.42 was landmark-fit noise);
    --   translation = origin_1409 - R(-141)*origin_571. Verified vs 12 reference NPCs: MODF translation
    --   matches the landmark-best translation to 0.02 yd (X) / 0.2 yd (Y). Z offset kept from the real
    --   map-1409 NPC floors (-116.0358; the WMO-origin delta is -115.89, within 0.15 yd).
    DECLARE M00 DOUBLE DEFAULT -0.777146;
    DECLARE M01 DOUBLE DEFAULT  0.629320;
    DECLARE M10 DOUBLE DEFAULT -0.629320;
    DECLARE M11 DOUBLE DEFAULT -0.777146;
    DECLARE TX  DOUBLE DEFAULT  5210.5701;
    DECLARE TY  DOUBLE DEFAULT  5229.2853;
    DECLARE TZ  DOUBLE DEFAULT -116.0358;
    DECLARE RZ  DOUBLE DEFAULT -2.46091425;    -- yaw rotation (radians) = -141.0 deg
    DECLARE QS  DOUBLE DEFAULT -0.94264149;    -- sin(RZ/2)
    DECLARE QC  DOUBLE DEFAULT  0.33380686;    -- cos(RZ/2)
    DECLARE TWO_PI DOUBLE DEFAULT 6.28318530717959;

    DECLARE v_creature_shift   BIGINT DEFAULT 0;
    DECLARE v_gameobject_shift BIGINT DEFAULT 0;
    DECLARE v_path_shift       BIGINT DEFAULT 0;
    DECLARE v_min_src_path     BIGINT DEFAULT NULL;
    DECLARE v_src_creatures    INT DEFAULT 0;
    DECLARE v_src_gameobjects  INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- -----------------------------------------------------------------------------------------------
    -- Source selection (built before the transaction; the entry-skip ignores our own marker rows so a
    -- rebuild does not exclude the entries it previously cloned).
    -- -----------------------------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS `tmp_sel_creature`;
    CREATE TEMPORARY TABLE `tmp_sel_creature` (`guid` INT UNSIGNED PRIMARY KEY);
    INSERT INTO `tmp_sel_creature` (`guid`)
        SELECT c.`guid`
        FROM `creature` c
        WHERE c.`map` = 571
          AND c.`position_x` BETWEEN 5540 AND 6070
          AND c.`position_y` BETWEEN 350 AND 880
          AND c.`position_z` BETWEEN 560 AND 715
          AND c.`guid` < 200000
          AND c.`id` NOT IN (29255, 29254, 30755, 30352, 31085, 32651, 30116, 36774, 36776)
          AND c.`id` NOT IN (SELECT DISTINCT `id` FROM `creature`
                             WHERE `map` = 1409 AND (`Comment` IS NULL OR `Comment` NOT LIKE 'DalaranBlizz1409|%'))
          AND NOT EXISTS (SELECT 1 FROM `game_event_creature` gec WHERE gec.`guid` = c.`guid`);

    DROP TEMPORARY TABLE IF EXISTS `tmp_sel_gameobject`;
    CREATE TEMPORARY TABLE `tmp_sel_gameobject` (`guid` INT UNSIGNED PRIMARY KEY);
    INSERT INTO `tmp_sel_gameobject` (`guid`)
        SELECT g.`guid`
        FROM `gameobject` g
        WHERE g.`map` = 571
          AND g.`position_x` BETWEEN 5540 AND 6070
          AND g.`position_y` BETWEEN 350 AND 880
          AND g.`position_z` BETWEEN 560 AND 715
          AND g.`guid` < 200000
          AND NOT EXISTS (SELECT 1 FROM `game_event_gameobject` geg WHERE geg.`guid` = g.`guid`);

    DROP TEMPORARY TABLE IF EXISTS `tmp_sel_path`;
    CREATE TEMPORARY TABLE `tmp_sel_path` (`path_id` INT UNSIGNED PRIMARY KEY);
    INSERT INTO `tmp_sel_path` (`path_id`)
        SELECT DISTINCT ca.`path_id`
        FROM `creature_addon` ca JOIN `tmp_sel_creature` s ON s.`guid` = ca.`guid`
        WHERE ca.`path_id` <> 0;

    SELECT COUNT(*) INTO v_src_creatures   FROM `tmp_sel_creature`;
    SELECT COUNT(*) INTO v_src_gameobjects FROM `tmp_sel_gameobject`;

    IF v_src_creatures = 0 AND v_src_gameobjects = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No source Dalaran rows matched the selection on map 571.';
    END IF;

    START TRANSACTION;

    -- -----------------------------------------------------------------------------------------------
    -- Wipe any previous DalaranBlizz1409 clone (rows + addons + waypoints) so this rebuild is clean.
    -- -----------------------------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS `tmp_old_creature`;
    CREATE TEMPORARY TABLE `tmp_old_creature` AS
        SELECT `guid` FROM `creature` WHERE `map` = 1409 AND `Comment` LIKE 'DalaranBlizz1409|%';
    DROP TEMPORARY TABLE IF EXISTS `tmp_old_path`;
    CREATE TEMPORARY TABLE `tmp_old_path` AS
        SELECT DISTINCT ca.`path_id` FROM `creature_addon` ca
        JOIN `tmp_old_creature` o ON o.`guid` = ca.`guid` WHERE ca.`path_id` <> 0;
    DROP TEMPORARY TABLE IF EXISTS `tmp_old_gameobject`;
    CREATE TEMPORARY TABLE `tmp_old_gameobject` AS
        SELECT `guid` FROM `gameobject` WHERE `map` = 1409 AND `Comment` LIKE 'DalaranBlizz1409|%';

    DELETE wda FROM `waypoint_data_addon` wda JOIN `tmp_old_path` p ON p.`path_id` = wda.`PathID`;
    DELETE wd  FROM `waypoint_data` wd        JOIN `tmp_old_path` p ON p.`path_id` = wd.`id`;
    DELETE ca  FROM `creature_addon` ca       JOIN `tmp_old_creature` o ON o.`guid` = ca.`guid`;
    DELETE ga  FROM `gameobject_addon` ga     JOIN `tmp_old_gameobject` o ON o.`guid` = ga.`guid`;
    DELETE FROM `creature`   WHERE `map` = 1409 AND `Comment` LIKE 'DalaranBlizz1409|%';
    DELETE FROM `gameobject` WHERE `map` = 1409 AND `Comment` LIKE 'DalaranBlizz1409|%';

    -- -----------------------------------------------------------------------------------------------
    -- Fresh GUID / path_id blocks above the current high-water marks (after the wipe).
    -- -----------------------------------------------------------------------------------------------
    SELECT (SELECT COALESCE(MAX(`guid`), 0) FROM `creature`) + 1 - (SELECT MIN(`guid`) FROM `tmp_sel_creature`)
        INTO v_creature_shift;
    SELECT (SELECT COALESCE(MAX(`guid`), 0) FROM `gameobject`) + 1 - (SELECT MIN(`guid`) FROM `tmp_sel_gameobject`)
        INTO v_gameobject_shift;

    SELECT MIN(`path_id`) INTO v_min_src_path FROM `tmp_sel_path`;
    IF v_min_src_path IS NOT NULL THEN
        SELECT GREATEST(
                   (SELECT COALESCE(MAX(`path_id`), 0) FROM `creature_addon`),
                   (SELECT COALESCE(MAX(`id`), 0)      FROM `waypoint_data`),
                   (SELECT COALESCE(MAX(`PathID`), 0)  FROM `waypoint_data_addon`)
               ) + 1 - v_min_src_path
            INTO v_path_shift;
    END IF;

    -- -----------------------------------------------------------------------------------------------
    -- Creatures (rigid transform inline; spawnMask/phaseMask forced to 1 for the instance loader).
    -- -----------------------------------------------------------------------------------------------
    IF v_src_creatures > 0 THEN
        INSERT INTO `creature`
            (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
             `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
             `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
             `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
        SELECT c.`guid` + v_creature_shift, c.`id`, 1409, c.`zoneId`, c.`areaId`, 1, 1, c.`equipment_id`,
               (M00 * c.`position_x` + M01 * c.`position_y` + TX),
               (M10 * c.`position_x` + M11 * c.`position_y` + TY),
               (c.`position_z` + TZ),
               MOD(c.`orientation` + RZ + TWO_PI, TWO_PI),
               c.`spawntimesecs`, c.`wander_distance`, c.`currentwaypoint`, c.`curhealth`, c.`curmana`,
               c.`MovementType`, c.`npcflag`, c.`unit_flags`, c.`dynamicflags`, c.`ScriptName`,
               c.`VerifiedBuild`, c.`CreateObject`,
               CONCAT('DalaranBlizz1409|', COALESCE(c.`Comment`, ''))
        FROM `creature` c JOIN `tmp_sel_creature` s ON s.`guid` = c.`guid`;

        INSERT INTO `creature_addon`
            (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
        SELECT ca.`guid` + v_creature_shift,
               CASE WHEN ca.`path_id` <> 0 THEN ca.`path_id` + v_path_shift ELSE 0 END,
               ca.`mount`, ca.`bytes1`, ca.`bytes2`, ca.`emote`, ca.`visibilityDistanceType`, ca.`auras`
        FROM `creature_addon` ca JOIN `tmp_sel_creature` s ON s.`guid` = ca.`guid`;

        IF v_min_src_path IS NOT NULL THEN
            INSERT INTO `waypoint_data`
                (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`,
                 `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
            SELECT wd.`id` + v_path_shift, wd.`point`,
                   (M00 * wd.`position_x` + M01 * wd.`position_y` + TX),
                   (M10 * wd.`position_x` + M11 * wd.`position_y` + TY),
                   (wd.`position_z` + TZ),
                   CASE WHEN wd.`orientation` = 0 THEN 0 ELSE MOD(wd.`orientation` + RZ + TWO_PI, TWO_PI) END,
                   wd.`velocity`, wd.`delay`, wd.`smoothTransition`, wd.`move_type`, wd.`action`,
                   wd.`action_chance`, wd.`wpguid`
            FROM `waypoint_data` wd JOIN `tmp_sel_path` p ON p.`path_id` = wd.`id`;

            INSERT INTO `waypoint_data_addon`
                (`PathID`, `PointID`, `SplinePointIndex`, `PositionX`, `PositionY`, `PositionZ`)
            SELECT wda.`PathID` + v_path_shift, wda.`PointID`, wda.`SplinePointIndex`,
                   (M00 * wda.`PositionX` + M01 * wda.`PositionY` + TX),
                   (M10 * wda.`PositionX` + M11 * wda.`PositionY` + TY),
                   (wda.`PositionZ` + TZ)
            FROM `waypoint_data_addon` wda JOIN `tmp_sel_path` p ON p.`path_id` = wda.`PathID`;
        END IF;
    END IF;

    -- -----------------------------------------------------------------------------------------------
    -- Gameobjects (rigid transform + yaw-rotate the orientation quaternion, left-multiply by qz):
    --   r0' = QC*r0 - QS*r1 ; r1' = QS*r0 + QC*r1 ; r2' = QS*r3 + QC*r2 ; r3' = QC*r3 - QS*r2
    -- -----------------------------------------------------------------------------------------------
    IF v_src_gameobjects > 0 THEN
        INSERT INTO `gameobject`
            (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
             `position_x`, `position_y`, `position_z`, `orientation`,
             `rotation0`, `rotation1`, `rotation2`, `rotation3`,
             `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`)
        SELECT g.`guid` + v_gameobject_shift, g.`id`, 1409, g.`zoneId`, g.`areaId`, 1, 1,
               (M00 * g.`position_x` + M01 * g.`position_y` + TX),
               (M10 * g.`position_x` + M11 * g.`position_y` + TY),
               (g.`position_z` + TZ),
               MOD(g.`orientation` + RZ + TWO_PI, TWO_PI),
               (QC * g.`rotation0` - QS * g.`rotation1`),
               (QS * g.`rotation0` + QC * g.`rotation1`),
               (QS * g.`rotation3` + QC * g.`rotation2`),
               (QC * g.`rotation3` - QS * g.`rotation2`),
               g.`spawntimesecs`, g.`animprogress`, g.`state`, g.`ScriptName`, g.`VerifiedBuild`,
               CONCAT('DalaranBlizz1409|', COALESCE(g.`Comment`, ''))
        FROM `gameobject` g JOIN `tmp_sel_gameobject` s ON s.`guid` = g.`guid`;

        INSERT INTO `gameobject_addon`
            (`guid`, `parent_rotation0`, `parent_rotation1`, `parent_rotation2`, `parent_rotation3`,
             `invisibilityType`, `invisibilityValue`)
        SELECT ga.`guid` + v_gameobject_shift, ga.`parent_rotation0`, ga.`parent_rotation1`,
               ga.`parent_rotation2`, ga.`parent_rotation3`, ga.`invisibilityType`, ga.`invisibilityValue`
        FROM `gameobject_addon` ga JOIN `tmp_sel_gameobject` s ON s.`guid` = ga.`guid`;
    END IF;

    COMMIT;

    SELECT 'creatures_inserted'    AS `metric`, v_src_creatures    AS `value`
    UNION ALL SELECT 'gameobjects_inserted',  v_src_gameobjects
    UNION ALL SELECT 'creature_guid_shift',   v_creature_shift
    UNION ALL SELECT 'gameobject_guid_shift', v_gameobject_shift
    UNION ALL SELECT 'path_id_shift',         v_path_shift;
END$$

DELIMITER ;

CALL `dc_rebuild_dalaran_1409`();
DROP PROCEDURE IF EXISTS `dc_rebuild_dalaran_1409`;
