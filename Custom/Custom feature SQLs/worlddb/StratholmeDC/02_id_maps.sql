-- =====================================================================================
-- Stratholme DC clone -- map 821, step 02: the id remap tables
--
-- Everything after this file joins to these five tables instead of doing arithmetic on
-- ids inline. They are permanent (not TEMPORARY) on purpose: each later file is applied in
-- its own session, and they are the audit trail for which clone id came from which stock
-- id when something looks wrong months from now.
--
-- WHY DENSE REMAPPING AND NOT A FLAT OFFSET
-- Stock Stratholme's creature entries span 10381 .. 351097 and its gameobject entries
-- 153464 .. 182072. A flat "+N" over a span that wide sprays the clone across several
-- unrelated id bands, and on this realm that is not hypothetical: the same approach on
-- Shadowfang Keep produced a live collision (duplicate entry 5301906) because one band
-- already held DC content while the DELETE guarding the insert only covered another.
-- ROW_NUMBER() packs each set into a contiguous, provably empty band instead.
--
-- BAND ALLOCATION (each verified empty before use)
--   creature_template   5500000 + n    66 entries
--   gameobject_template 5600000 + n   114 entries
--   creature.guid      16740000 + n   468 spawns
--   gameobject.guid    16520000 + n   188 spawns
--   waypoint_data.id    8210000 + n    29 paths
--
-- THE SPAWN-ID CAP
-- ObjectMgr.cpp:7669/7679 rejects any creature or gameobject spawn id above 0xFFFFFF
-- (16777215). Both guid bands sit below it, but the headroom is finite -- the report at the
-- bottom checks it rather than trusting the arithmetic.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Creature entries
--
-- THE SET IS NOT JUST "WHAT IS SPAWNED". This is the mistake that cost the most time on
-- Shadowfang Keep: encounter adds are summoned at RUNTIME and never appear in the
-- `creature` table, so an import seeded from spawned entries alone silently omits them and
-- the failure only shows up when a boss tries to summon something that does not exist.
--
-- The 11 runtime-only entries below were found by unioning three sources:
--   * SmartAI summons         smart_scripts action_type 12 -> 10387 Vengeful Phantom
--   * the instance script     every NPC_* id in stratholme.h
--   * the Jarien/Sothos event 16101/16102 and their spirits 16103/16104
--
-- EXCLUDED: 351097 "Naxx40 Strath Entrance Trigger". That belongs to the naxx40 module and
-- teleports to map 2921; it is stock Stratholme's business, not the clone's. Copying it
-- would give the clone a second, unintended Naxxramas entrance.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_cmap`;
CREATE TABLE `dc_strat821_cmap` (
    `src_entry` INT UNSIGNED NOT NULL,
    `dst_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_entry`),
    UNIQUE KEY `dst` (`dst_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_cmap` (`src_entry`, `dst_entry`)
SELECT s.e, 5500000 + (ROW_NUMBER() OVER (ORDER BY s.e)) - 1
FROM (
    SELECT DISTINCT `id` AS e FROM `creature` WHERE `map` = 329 AND `id` <> 351097
    UNION
    SELECT r.e FROM (
                  SELECT 10387 AS e   -- Vengeful Phantom   (SmartAI summon)
        UNION ALL SELECT 10394        -- Black Guard Sentry (instance script)
        UNION ALL SELECT 10439        -- Ramstein the Gorger
        UNION ALL SELECT 10441        -- Plagued Rat        (gate trap)
        UNION ALL SELECT 10461        -- Plagued Insect     (gate trap)
        UNION ALL SELECT 10536        -- Plagued Maggot     (gate trap)
        UNION ALL SELECT 11030        -- Mindless Undead    (Ramstein wave)
        UNION ALL SELECT 16101        -- Jarien
        UNION ALL SELECT 16102        -- Sothos
        UNION ALL SELECT 16103        -- Spirit of Jarien
        UNION ALL SELECT 16104        -- Spirit of Sothos
    ) r
) s;

-- -------------------------------------------------------------------------------------
-- 2. Gameobject entries -- 112 spawned on 329, plus 2 that are only ever summoned.
--
-- Gameobjects have exactly the same runtime-summon trap as creatures, and an early draft of
-- this file claimed they did not. Two entries are never placed in the `gameobject` table
-- and would have been left pointing at stock objects:
--   176747  Small Barracks Flame        -- 5 SMART_ACTION_SUMMON_GO rows summon it
--   181083  Sothos and Jarien's Heirlooms -- summoned from boss_jarien_and_sothos.cpp:95
--
-- Both sort above every id named in stratholme.h, so adding them appends to the end of the
-- dense band and does not shift any mapping the C++ header depends on. (10 spawned entries
-- above 176747 do shift by one or two places; none of them appear in the header.)
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_gmap`;
CREATE TABLE `dc_strat821_gmap` (
    `src_entry` INT UNSIGNED NOT NULL,
    `dst_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_entry`),
    UNIQUE KEY `dst` (`dst_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_gmap` (`src_entry`, `dst_entry`)
SELECT s.e, 5600000 + (ROW_NUMBER() OVER (ORDER BY s.e)) - 1
FROM (
    SELECT DISTINCT `id` AS e FROM `gameobject` WHERE `map` = 329
    UNION
    SELECT r.e FROM (
                  SELECT 176747 AS e   -- Small Barracks Flame          (SmartAI summon)
        UNION ALL SELECT 181083        -- Sothos and Jarien's Heirlooms (boss script summon)
    ) r
) s;

-- -------------------------------------------------------------------------------------
-- 3. Creature spawn guids
--
-- Guids must be mapped, not offset, for the same collision reason as entries -- and they
-- are needed as a TABLE rather than a formula because two later files key off them:
--   * smart_scripts rows with a negative entryorguid (35 of them) address one specific
--     spawn, not an entry
--   * creature_formations stores leaderGUID/memberGUID
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_cguid`;
CREATE TABLE `dc_strat821_cguid` (
    `src_guid` INT UNSIGNED NOT NULL,
    `dst_guid` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_guid`),
    UNIQUE KEY `dst` (`dst_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_cguid` (`src_guid`, `dst_guid`)
SELECT s.g, 16740000 + (ROW_NUMBER() OVER (ORDER BY s.g)) - 1
FROM (SELECT `guid` AS g FROM `creature` WHERE `map` = 329 AND `id` <> 351097) s;

-- -------------------------------------------------------------------------------------
-- 4. Gameobject spawn guids
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_gguid`;
CREATE TABLE `dc_strat821_gguid` (
    `src_guid` INT UNSIGNED NOT NULL,
    `dst_guid` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_guid`),
    UNIQUE KEY `dst` (`dst_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_gguid` (`src_guid`, `dst_guid`)
SELECT s.g, 16520000 + (ROW_NUMBER() OVER (ORDER BY s.g)) - 1
FROM (SELECT `guid` AS g FROM `gameobject` WHERE `map` = 329) s;

-- -------------------------------------------------------------------------------------
-- 5. Waypoint path ids
--
-- 29 paths, 520 waypoints between them, none shared by more than one spawn. Note that on
-- this data path_id is NEVER equal to the guid (0 of 29 match), so the common AC shortcut
-- of reusing the guid as the path id would silently repoint every patrol -- hence a real
-- map into its own band.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_strat821_wpmap`;
CREATE TABLE `dc_strat821_wpmap` (
    `src_path` INT UNSIGNED NOT NULL,
    `dst_path` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_path`),
    UNIQUE KEY `dst` (`dst_path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_strat821_wpmap` (`src_path`, `dst_path`)
SELECT s.p, 8210000 + (ROW_NUMBER() OVER (ORDER BY s.p)) - 1
FROM (
    SELECT DISTINCT a.`path_id` AS p
        FROM `creature_addon` a
        JOIN `creature` c ON c.`guid` = a.`guid`
        WHERE c.`map` = 329 AND a.`path_id` > 0
) s;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature entries mapped (want 66)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_strat821_cmap`
UNION ALL SELECT 'of which runtime-only, never spawned (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cmap` m
    WHERE m.`src_entry` NOT IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 329)
-- The naxx40 module trigger must NOT have been picked up.
UNION ALL SELECT 'naxx40 trigger 351097 excluded (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cmap` WHERE `src_entry` = 351097
UNION ALL SELECT 'gameobject entries mapped (want 114)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_gmap`
UNION ALL SELECT 'of which runtime-only, never spawned (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_gmap` m
    WHERE m.`src_entry` NOT IN (SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 329)
UNION ALL SELECT 'creature guids mapped (want 468)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cguid`
UNION ALL SELECT 'gameobject guids mapped (want 188)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_gguid`
UNION ALL SELECT 'waypoint paths mapped (want 29)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_wpmap`
-- Every target band must be empty, or 03/04 will collide on apply.
UNION ALL SELECT 'creature_template already in 5.5M band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
UNION ALL SELECT 'gameobject_template already in 5.6M band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
UNION ALL SELECT 'creature guids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
UNION ALL SELECT 'gameobject guids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_gguid`)
UNION ALL SELECT 'waypoint path ids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_strat821_wpmap`)
-- ObjectMgr.cpp:7669/7679 -- anything at or above 16777215 bricks startup with TCE00007.
UNION ALL SELECT 'creature guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_cguid` WHERE `dst_guid` >= 16777215
UNION ALL SELECT 'gameobject guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_strat821_gguid` WHERE `dst_guid` >= 16777215;
