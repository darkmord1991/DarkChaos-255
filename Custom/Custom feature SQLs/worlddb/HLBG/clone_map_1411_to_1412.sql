-- Clone the live world DB slice on map 1411 onto map 1412.
--
-- Audited on the current live acore_world snapshot before writing this file:
--   creature            : 149 rows
--   creature_addon      : 27 rows
--   waypoint_data       : 161 rows across 10 path IDs
--   gameobject          : 288 rows
--   dc_teleporter       : 2 rows
--   game_tele           : 2 rows
--   game_graveyard      : 4 rows
--
-- Audited as zero-row / no-reference for map 1411 at the time of writing:
--   areatrigger, dc_guild_house_locations, dc_guild_house_spawns,
--   instance_template, playercreateinfo, quest_poi, spell_target_position,
--   pool_creature, pool_gameobject, game_event_creature,
--   game_event_gameobject, linked_respawn, spawn_group,
--   creature_formations, gameobject_addon, waypoint_data_addon,
--   smart_scripts bound to negative spawn GUIDs.
--
-- Notes:
--   1. The script aborts if map 1412 already contains rows in the main clone
--      tables, so it is safe against accidental re-runs. Set
--      v_replace_target = 1 inside the procedure if you want to wipe the
--      current 1412 slice and rebuild it from 1411.
--   2. Teleport and graveyard labels get a configurable suffix so the cloned
--      entries are distinguishable from the original 1411 rows.
--   3. game_graveyard IDs are regenerated because that table is keyed by ID.
--      If your cloned map also expects matching WorldSafeLocs-style IDs on the
--      client side, update the corresponding DBC data to match the generated
--      IDs before you rely on those graveyards.

DROP PROCEDURE IF EXISTS `dc_clone_map_1411_to_1412`;

DELIMITER $$

CREATE PROCEDURE `dc_clone_map_1411_to_1412`()
BEGIN
    DECLARE v_source_map INT DEFAULT 1411;
    DECLARE v_target_map INT DEFAULT 1412;
    DECLARE v_name_suffix VARCHAR(16) DEFAULT '_1412';
    DECLARE v_replace_target TINYINT DEFAULT 0;
    DECLARE v_source_creatures INT DEFAULT 0;
    DECLARE v_source_gameobjects INT DEFAULT 0;
    DECLARE v_target_rows INT DEFAULT 0;
    DECLARE v_creature_guid_shift BIGINT DEFAULT 0;
    DECLARE v_gameobject_guid_shift BIGINT DEFAULT 0;
    DECLARE v_path_id_shift BIGINT DEFAULT 0;
    DECLARE v_min_source_path BIGINT DEFAULT NULL;
    DECLARE v_game_tele_base INT DEFAULT 0;
    DECLARE v_game_graveyard_base INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_source_creatures
    FROM `creature`
    WHERE `map` = v_source_map;

    SELECT COUNT(*) INTO v_source_gameobjects
    FROM `gameobject`
    WHERE `map` = v_source_map;

    IF v_source_creatures = 0 AND v_source_gameobjects = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source map 1411 has no creature or gameobject rows.';
    END IF;

    SELECT
          (SELECT COUNT(*) FROM `creature` WHERE `map` = v_target_map)
        + (SELECT COUNT(*) FROM `gameobject` WHERE `map` = v_target_map)
        + (SELECT COUNT(*) FROM `dc_teleporter` WHERE `map` = v_target_map)
        + (SELECT COUNT(*) FROM `game_tele` WHERE `map` = v_target_map)
        + (SELECT COUNT(*) FROM `game_graveyard` WHERE `Map` = v_target_map)
    INTO v_target_rows;

    IF v_target_rows > 0 THEN
        IF v_replace_target = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Target map 1412 already has rows in clone target tables. Set v_replace_target = 1 to rebuild it.';
        END IF;
    END IF;

    START TRANSACTION;

    IF v_target_rows > 0 AND v_replace_target = 1 THEN
        DROP TEMPORARY TABLE IF EXISTS `tmp_target_creature_guid`;
        CREATE TEMPORARY TABLE `tmp_target_creature_guid`
        AS
        SELECT `guid`
        FROM `creature`
        WHERE `map` = v_target_map;

        DROP TEMPORARY TABLE IF EXISTS `tmp_target_path_id`;
        CREATE TEMPORARY TABLE `tmp_target_path_id`
        AS
        SELECT DISTINCT ca.`path_id`
        FROM `creature_addon` ca
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = ca.`guid`
        WHERE ca.`path_id` <> 0;

        DROP TEMPORARY TABLE IF EXISTS `tmp_target_gameobject_guid`;
        CREATE TEMPORARY TABLE `tmp_target_gameobject_guid`
        AS
        SELECT `guid`
        FROM `gameobject`
        WHERE `map` = v_target_map;

        DELETE wda
        FROM `waypoint_data_addon` wda
        JOIN `tmp_target_path_id` tp ON tp.`path_id` = wda.`PathID`;

        DELETE wd
        FROM `waypoint_data` wd
        JOIN `tmp_target_path_id` tp ON tp.`path_id` = wd.`id`;

        DELETE ca
        FROM `creature_addon` ca
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = ca.`guid`;

        DELETE ga
        FROM `gameobject_addon` ga
        JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = ga.`guid`;

        DELETE lr
        FROM `linked_respawn` lr
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = lr.`guid`;

        DELETE lr
        FROM `linked_respawn` lr
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = lr.`linkedGuid`;

        DELETE lr
        FROM `linked_respawn` lr
        JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = lr.`guid`;

        DELETE lr
        FROM `linked_respawn` lr
        JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = lr.`linkedGuid`;

        DELETE pc
        FROM `pool_creature` pc
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = pc.`guid`;

        DELETE pg
        FROM `pool_gameobject` pg
        JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = pg.`guid`;

        DELETE gec
        FROM `game_event_creature` gec
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = gec.`guid`;

        DELETE geg
        FROM `game_event_gameobject` geg
        JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = geg.`guid`;

        DELETE sg
        FROM `spawn_group` sg
        LEFT JOIN `tmp_target_creature_guid` tc ON tc.`guid` = sg.`spawnId`
        LEFT JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = sg.`spawnId`
        WHERE tc.`guid` IS NOT NULL
           OR tg.`guid` IS NOT NULL;

        DELETE cf
        FROM `creature_formations` cf
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = cf.`leaderGUID`;

        DELETE cf
        FROM `creature_formations` cf
        JOIN `tmp_target_creature_guid` tc ON tc.`guid` = cf.`memberGUID`;

        DELETE ss
        FROM `smart_scripts` ss
        LEFT JOIN `tmp_target_creature_guid` tc ON tc.`guid` = ABS(ss.`entryorguid`)
        LEFT JOIN `tmp_target_gameobject_guid` tg ON tg.`guid` = ABS(ss.`entryorguid`)
        WHERE ss.`entryorguid` < 0
          AND (tc.`guid` IS NOT NULL OR tg.`guid` IS NOT NULL);

        DELETE FROM `dc_teleporter`
        WHERE `map` = v_target_map;

        DELETE FROM `game_tele`
        WHERE `map` = v_target_map;

        DELETE FROM `game_graveyard`
        WHERE `Map` = v_target_map;

        DELETE FROM `creature`
        WHERE `map` = v_target_map;

        DELETE FROM `gameobject`
        WHERE `map` = v_target_map;
    END IF;

    IF v_source_creatures > 0 THEN
        SELECT
            (SELECT COALESCE(MAX(`guid`), 0) FROM `creature`) + 1
            - (SELECT MIN(`guid`) FROM `creature` WHERE `map` = v_source_map)
        INTO v_creature_guid_shift;

        DROP TEMPORARY TABLE IF EXISTS `tmp_clone_creature`;
        CREATE TEMPORARY TABLE `tmp_clone_creature`
        AS
        SELECT *
        FROM `creature`
        WHERE `map` = v_source_map;

        DROP TEMPORARY TABLE IF EXISTS `tmp_creature_guid_map`;
        CREATE TEMPORARY TABLE `tmp_creature_guid_map`
        AS
        SELECT `guid` AS `old_guid`, `guid` + v_creature_guid_shift AS `new_guid`
        FROM `tmp_clone_creature`;

        UPDATE `tmp_clone_creature` c
        JOIN `tmp_creature_guid_map` m ON m.`old_guid` = c.`guid`
        SET c.`guid` = m.`new_guid`,
            c.`map` = v_target_map;

        INSERT INTO `creature`
        SELECT *
        FROM `tmp_clone_creature`;

        SELECT MIN(ca.`path_id`) INTO v_min_source_path
        FROM `creature_addon` ca
        JOIN `tmp_creature_guid_map` m ON m.`old_guid` = ca.`guid`
        WHERE ca.`path_id` <> 0;

        IF v_min_source_path IS NOT NULL THEN
            SELECT (SELECT COALESCE(MAX(`path_id`), 0) FROM `creature_addon`) + 1 - v_min_source_path
            INTO v_path_id_shift;

            INSERT INTO `waypoint_data`
            (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`, `delay`,
             `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
            SELECT wd.`id` + v_path_id_shift,
                   wd.`point`,
                   wd.`position_x`,
                   wd.`position_y`,
                   wd.`position_z`,
                   wd.`orientation`,
                   wd.`velocity`,
                   wd.`delay`,
                   wd.`smoothTransition`,
                   wd.`move_type`,
                   wd.`action`,
                   wd.`action_chance`,
                   wd.`wpguid`
            FROM `waypoint_data` wd
            JOIN (
                SELECT DISTINCT ca.`path_id`
                FROM `creature_addon` ca
                JOIN `tmp_creature_guid_map` m ON m.`old_guid` = ca.`guid`
                WHERE ca.`path_id` <> 0
            ) src ON src.`path_id` = wd.`id`;

            INSERT INTO `waypoint_data_addon`
            (`PathID`, `PointID`, `SplinePointIndex`, `PositionX`, `PositionY`, `PositionZ`)
            SELECT wda.`PathID` + v_path_id_shift,
                   wda.`PointID`,
                   wda.`SplinePointIndex`,
                   wda.`PositionX`,
                   wda.`PositionY`,
                   wda.`PositionZ`
            FROM `waypoint_data_addon` wda
            JOIN (
                SELECT DISTINCT ca.`path_id`
                FROM `creature_addon` ca
                JOIN `tmp_creature_guid_map` m ON m.`old_guid` = ca.`guid`
                WHERE ca.`path_id` <> 0
            ) src ON src.`path_id` = wda.`PathID`;
        END IF;

        INSERT INTO `creature_addon`
        (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
        SELECT m.`new_guid`,
               CASE
                   WHEN ca.`path_id` <> 0 THEN ca.`path_id` + v_path_id_shift
                   ELSE 0
               END,
               ca.`mount`,
               ca.`bytes1`,
               ca.`bytes2`,
               ca.`emote`,
               ca.`visibilityDistanceType`,
               ca.`auras`
        FROM `creature_addon` ca
        JOIN `tmp_creature_guid_map` m ON m.`old_guid` = ca.`guid`;
    END IF;

    IF v_source_gameobjects > 0 THEN
        SELECT
            (SELECT COALESCE(MAX(`guid`), 0) FROM `gameobject`) + 1
            - (SELECT MIN(`guid`) FROM `gameobject` WHERE `map` = v_source_map)
        INTO v_gameobject_guid_shift;

        DROP TEMPORARY TABLE IF EXISTS `tmp_clone_gameobject`;
        CREATE TEMPORARY TABLE `tmp_clone_gameobject`
        AS
        SELECT *
        FROM `gameobject`
        WHERE `map` = v_source_map;

        DROP TEMPORARY TABLE IF EXISTS `tmp_gameobject_guid_map`;
        CREATE TEMPORARY TABLE `tmp_gameobject_guid_map`
        AS
        SELECT `guid` AS `old_guid`, `guid` + v_gameobject_guid_shift AS `new_guid`
        FROM `tmp_clone_gameobject`;

        UPDATE `tmp_clone_gameobject` g
        JOIN `tmp_gameobject_guid_map` m ON m.`old_guid` = g.`guid`
        SET g.`guid` = m.`new_guid`,
            g.`map` = v_target_map;

        INSERT INTO `gameobject`
        SELECT *
        FROM `tmp_clone_gameobject`;

        INSERT INTO `gameobject_addon`
        (`guid`, `parent_rotation0`, `parent_rotation1`, `parent_rotation2`, `parent_rotation3`,
         `invisibilityType`, `invisibilityValue`)
        SELECT m.`new_guid`,
               ga.`parent_rotation0`,
               ga.`parent_rotation1`,
               ga.`parent_rotation2`,
               ga.`parent_rotation3`,
               ga.`invisibilityType`,
               ga.`invisibilityValue`
        FROM `gameobject_addon` ga
        JOIN `tmp_gameobject_guid_map` m ON m.`old_guid` = ga.`guid`;
    END IF;

    INSERT INTO `dc_teleporter`
    (`parent`, `type`, `faction`, `security_level`, `comment`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`)
    SELECT dt.`parent`,
           dt.`type`,
           dt.`faction`,
           dt.`security_level`,
           CASE
               WHEN dt.`comment` IS NULL OR dt.`comment` = '' THEN dt.`comment`
               ELSE CONCAT(dt.`comment`, v_name_suffix)
           END,
           dt.`icon`,
           CONCAT(dt.`name`, v_name_suffix),
           v_target_map,
           dt.`x`,
           dt.`y`,
           dt.`z`,
           dt.`o`
    FROM `dc_teleporter` dt
    WHERE dt.`map` = v_source_map;

    DROP TEMPORARY TABLE IF EXISTS `tmp_game_tele_id_map`;
    CREATE TEMPORARY TABLE `tmp_game_tele_id_map` (
        `seq` INT NOT NULL AUTO_INCREMENT,
        `old_id` INT NOT NULL,
        PRIMARY KEY (`seq`),
        UNIQUE KEY `uniq_old_id` (`old_id`)
    );

    INSERT INTO `tmp_game_tele_id_map` (`old_id`)
    SELECT `id`
    FROM `game_tele`
    WHERE `map` = v_source_map
    ORDER BY `id`;

    SELECT COALESCE(MAX(`id`), 0) INTO v_game_tele_base
    FROM `game_tele`;

    INSERT INTO `game_tele`
    (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`)
    SELECT v_game_tele_base + ids.`seq`,
           gt.`position_x`,
           gt.`position_y`,
           gt.`position_z`,
           gt.`orientation`,
           v_target_map,
           CONCAT(gt.`name`, v_name_suffix)
    FROM `game_tele` gt
    JOIN `tmp_game_tele_id_map` ids ON ids.`old_id` = gt.`id`
    WHERE gt.`map` = v_source_map
    ORDER BY gt.`id`;

    DROP TEMPORARY TABLE IF EXISTS `tmp_game_graveyard_id_map`;
    CREATE TEMPORARY TABLE `tmp_game_graveyard_id_map` (
        `seq` INT NOT NULL AUTO_INCREMENT,
        `old_id` INT NOT NULL,
        PRIMARY KEY (`seq`),
        UNIQUE KEY `uniq_old_id` (`old_id`)
    );

    INSERT INTO `tmp_game_graveyard_id_map` (`old_id`)
    SELECT `ID`
    FROM `game_graveyard`
    WHERE `Map` = v_source_map
    ORDER BY `ID`;

    SELECT COALESCE(MAX(`ID`), 0) INTO v_game_graveyard_base
    FROM `game_graveyard`;

    INSERT INTO `game_graveyard`
    (`ID`, `Map`, `x`, `y`, `z`, `Comment`)
    SELECT v_game_graveyard_base + ids.`seq`,
           v_target_map,
           gg.`x`,
           gg.`y`,
           gg.`z`,
           CASE
               WHEN gg.`Comment` IS NULL OR gg.`Comment` = '' THEN gg.`Comment`
               ELSE CONCAT(gg.`Comment`, v_name_suffix)
           END
    FROM `game_graveyard` gg
    JOIN `tmp_game_graveyard_id_map` ids ON ids.`old_id` = gg.`ID`
    WHERE gg.`Map` = v_source_map
    ORDER BY gg.`ID`;

    COMMIT;

    SELECT 'creature_guid_shift' AS `metric`, v_creature_guid_shift AS `value`
    UNION ALL
    SELECT 'gameobject_guid_shift', v_gameobject_guid_shift
    UNION ALL
    SELECT 'path_id_shift', v_path_id_shift
    UNION ALL
    SELECT 'game_tele_base', v_game_tele_base
    UNION ALL
    SELECT 'game_graveyard_base', v_game_graveyard_base;

    SELECT 'creature' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `tmp_clone_creature`;

    SELECT 'creature_addon' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `creature_addon` ca
    JOIN `tmp_creature_guid_map` m ON m.`new_guid` = ca.`guid`;

    SELECT 'waypoint_data' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `waypoint_data` wd
    JOIN (
        SELECT DISTINCT ca.`path_id`
        FROM `creature_addon` ca
        JOIN `tmp_creature_guid_map` m ON m.`new_guid` = ca.`guid`
        WHERE ca.`path_id` > 0
    ) cloned_paths ON cloned_paths.`path_id` = wd.`id`;

    SELECT 'gameobject' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `tmp_clone_gameobject`;

    SELECT 'dc_teleporter' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `dc_teleporter`
    WHERE `map` = v_target_map;

    SELECT 'game_tele' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `game_tele`
    WHERE `map` = v_target_map;

    SELECT 'game_graveyard' AS `table_name`, COUNT(*) AS `inserted_rows`
    FROM `game_graveyard`
    WHERE `Map` = v_target_map;

    SELECT ids.`old_id` AS `source_game_tele_id`,
           v_game_tele_base + ids.`seq` AS `new_game_tele_id`
    FROM `tmp_game_tele_id_map` ids
    ORDER BY ids.`old_id`;

    SELECT ids.`old_id` AS `source_game_graveyard_id`,
           v_game_graveyard_base + ids.`seq` AS `new_game_graveyard_id`
    FROM `tmp_game_graveyard_id_map` ids
    ORDER BY ids.`old_id`;
END$$

DELIMITER ;

CALL `dc_clone_map_1411_to_1412`();
DROP PROCEDURE IF EXISTS `dc_clone_map_1411_to_1412`;