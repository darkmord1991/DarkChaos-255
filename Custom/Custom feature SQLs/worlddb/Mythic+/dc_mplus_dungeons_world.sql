-- ========================================================================
-- DarkChaos Mythic+ System - dc_mplus_dungeons World Database Seed
-- ========================================================================
-- Purpose: Create and seed dc_mplus_dungeons in acore_world.
--          This table is queried without a guard by dc_mythicplus_font_of_power.cpp,
--          dc_addon_mythicplus.cpp, dc_addon_spectator.cpp, and
--          dc_addon_groupfinder.cpp. If it is absent the server crashes
--          with MySQL error 1146 / ABORT_SERVER on any Mythic+ interaction.
-- Database: acore_world
-- Apply with: mysql -u root -p acore_world < this_file.sql
-- ========================================================================

USE acore_world;

-- ========================================================================
-- Table
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_dungeons` (
    `dungeon_id`        INT UNSIGNED NOT NULL         COMMENT 'Map ID (matches Map.dbc)',
    `dungeon_name`      VARCHAR(100)  NOT NULL         COMMENT 'Display name',
    `short_name`        VARCHAR(10)   DEFAULT NULL     COMMENT 'Abbreviation shown in UI',
    `min_level`         TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `base_timer`        INT UNSIGNED  NOT NULL DEFAULT 1800 COMMENT 'Completion timer in seconds',
    `trash_count`       INT UNSIGNED  NOT NULL DEFAULT 0   COMMENT 'Required trash kills',
    `boss_count`        TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `difficulty_rating` TINYINT UNSIGNED NOT NULL DEFAULT 5 COMMENT '1-10 difficulty scale',
    `season_enabled`    TINYINT(1)    NOT NULL DEFAULT 1,
    `teleport_x`        FLOAT         DEFAULT NULL,
    `teleport_y`        FLOAT         DEFAULT NULL,
    `teleport_z`        FLOAT         DEFAULT NULL,
    `teleport_o`        FLOAT         DEFAULT NULL,
    `icon_path`         VARCHAR(255)  DEFAULT NULL,
    `created_at`        TIMESTAMP     NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        TIMESTAMP     NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`dungeon_id`),
    KEY `idx_season_enabled` (`season_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic+ dungeon definitions';

-- ========================================================================
-- Seed: WotLK dungeons (idempotent)
-- ========================================================================
DELETE FROM `dc_mplus_dungeons` WHERE `dungeon_id` IN
    (574, 575, 576, 578, 595, 599, 600, 601, 602, 604, 608, 619, 632, 650, 658, 668);

-- base_timer values match acore_chars.dc_mplus_dungeons.timer_seconds
-- dungeon_name values match acore_chars.dc_mplus_dungeons.dungeon_name
INSERT INTO `dc_mplus_dungeons`
    (`dungeon_id`, `dungeon_name`,                  `short_name`, `min_level`, `base_timer`, `trash_count`, `boss_count`, `difficulty_rating`, `season_enabled`)
VALUES
    (574, 'Utgarde Keep',                           'UK',          80,          1500,          0,             3,            3,                   1),
    (575, 'Utgarde Pinnacle',                       'UP',          80,          1800,          0,             4,            6,                   1),
    (576, 'The Nexus',                              'NEX',         80,          1800,          0,             4,            4,                   1),
    (578, 'The Oculus',                             'OCC',         80,          2100,          0,             5,            7,                   1),
    (595, 'The Culling of Stratholme',              'COS',         80,          1800,          0,             5,            5,                   1),
    (599, 'Halls of Stone',                         'HOS',         80,          1800,          0,             4,            5,                   1),
    (600, 'Drak''Tharon Keep',                      'DTK',         80,          1800,          0,             4,            4,                   1),
    (601, 'Azjol-Nerub',                            'AN',          80,          1200,          0,             3,            3,                   1),
    (602, 'Halls of Lightning',                     'HOL',         80,          1800,          0,             4,            6,                   1),
    (604, 'Gundrak',                                'GD',          80,          1500,          0,             4,            5,                   1),
    (608, 'Violet Hold',                            'VH',          80,          1500,          0,             3,            4,                   1),
    (619, 'Ahn''kahet: The Old Kingdom',            'OK',          80,          1800,          0,             5,            5,                   1),
    (632, 'The Forge of Souls',                     'FOS',         80,          1500,          0,             2,            6,                   1),
    (650, 'Trial of the Champion',                  'TOC',         80,          1200,          0,             3,            5,                   1),
    (658, 'Pit of Saron',                           'POS',         80,          1800,          0,             3,            7,                   1),
    (668, 'Halls of Reflection',                    'HOR',         80,          1500,          0,             3,            8,                   1);

SELECT
    'dc_mplus_dungeons' AS table_name,
    COUNT(*) AS row_count
FROM `dc_mplus_dungeons`;
