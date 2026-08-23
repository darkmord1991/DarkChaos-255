-- =====================================================================================
-- Scholomance DC clone -- map 822, step 02: the id remap tables
--
-- Everything after this file joins to these tables instead of doing arithmetic on ids
-- inline. They are permanent (not TEMPORARY) on purpose: each later file is applied in its
-- own session, and they are the audit trail for which clone id came from which stock id.
--
-- WHY DENSE REMAPPING AND NOT A FLAT OFFSET
-- Scholomance's creature entries span 1853 .. 16047 and its gameobject entries
-- 175167 .. 181096. A flat "+N" over spans that wide scatters the clone across unrelated
-- id bands, and on this realm that is not hypothetical: the same approach on Shadowfang
-- produced a live collision (duplicate entry 5301906) because one band already held DC
-- content while the DELETE guarding the insert only covered another. ROW_NUMBER() packs
-- each set into a contiguous, provably empty band instead.
--
-- BAND ALLOCATION (each verified empty before use)
--   creature_template   5700000 + n    47 entries
--   gameobject_template 5800000 + n    62 entries
--   creature.guid      16750000 + n   399 spawns
--   gameobject.guid    16530000 + n    62 spawns
--   waypoint_data.id    8230000 + n    16 paths
--   (action lists       8240000 + n, built in 06 -- derived from smart_scripts, not spawns)
--
-- THE SPAWN-ID CAP
-- ObjectMgr.cpp:7669/7679 rejects any creature or gameobject spawn id above 0xFFFFFF
-- (16777215). The highest guid in use before this clone is 16741006, and 16750000 + 399
-- lands at 16750398 -- inside the cap, but the report checks it rather than trusting the
-- arithmetic.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Creature entries
--
-- THE SET IS NOT JUST "WHAT IS SPAWNED". This is the mistake that cost the most time on
-- Shadowfang and recurred on Stratholme: encounter bosses and adds are summoned at RUNTIME
-- and never appear in the `creature` table, so an import seeded from spawned entries alone
-- silently omits them and the failure only shows up when something tries to summon a
-- creature that does not exist.
--
-- Scholomance has SIX such entries, and three of them carry C++ ScriptNames -- so missing
-- them would lose both the creature AND its script binding:
--
--   10506  Kirtonos the Herald  boss_kirtonos_the_herald   (summoned by the brazier event)
--   11284  Dark Shade           -                          (UpdateEntry morph -- see below)
--   11598  Risen Guardian       npc_risen_guardian         (Gandling room adds)
--   16118  Kormok               boss_kormok                (SmartAI summon, act 12)
--   16119  Bone Minion          -                          (Kormok add)
--   16120  Bone Mage            -                          (Kormok add)
--
-- Found by unioning FOUR sources: SmartAI summons (action_type 12), every NPC_* id in
-- scholomance.h, the summon targets inside the boss scripts, and -- the one an earlier draft
-- of this file missed -- every UpdateEntry() target in the C++.
--
-- THAT LAST SOURCE IS A THIRD KIND OF TRAP. Dark Shade is neither spawned nor summoned: the
-- Scholomance Occultist MORPHS into it at 30% health via me->UpdateEntry(). A scan for
-- spawned entries misses it and so does a scan for summon targets, so it has to be found by
-- reading the scripts. Left out, the clone occultists would morph into the STOCK creature
-- and leave this map's id band entirely.
--
-- Unlike Stratholme there is no foreign-module trigger to exclude here: nothing on map 289
-- belongs to another feature.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_cmap`;
CREATE TABLE `dc_scholo822_cmap` (
    `src_entry` INT UNSIGNED NOT NULL,
    `dst_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_entry`),
    UNIQUE KEY `dst` (`dst_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_cmap` (`src_entry`, `dst_entry`)
SELECT s.e, 5700000 + (ROW_NUMBER() OVER (ORDER BY s.e)) - 1
FROM (
    SELECT DISTINCT `id` AS e FROM `creature` WHERE `map` = 289
    UNION
    SELECT r.e FROM (
                  SELECT 10506 AS e   -- Kirtonos the Herald  (brazier event summon)
        UNION ALL SELECT 11284        -- Dark Shade           (occultist UpdateEntry morph)
        UNION ALL SELECT 11598        -- Risen Guardian       (Gandling room adds)
        UNION ALL SELECT 16118        -- Kormok               (SmartAI summon)
        UNION ALL SELECT 16119        -- Bone Minion          (Kormok add)
        UNION ALL SELECT 16120        -- Bone Mage            (Kormok add)
    ) r
) s;

-- -------------------------------------------------------------------------------------
-- 2. Gameobject entries -- all 62 distinct entries spawned on 289.
--
-- Checked explicitly: unlike Stratholme (which had two runtime-summoned gameobjects), every
-- gameobject named in scholomance.h -- the Kirtonos brazier and gate, the key door, and all
-- seven Gandling room gates -- is really placed in the `gameobject` table, so the spawned
-- set is the complete set here.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_gmap`;
CREATE TABLE `dc_scholo822_gmap` (
    `src_entry` INT UNSIGNED NOT NULL,
    `dst_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_entry`),
    UNIQUE KEY `dst` (`dst_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_gmap` (`src_entry`, `dst_entry`)
SELECT s.e, 5800000 + (ROW_NUMBER() OVER (ORDER BY s.e)) - 1
FROM (SELECT DISTINCT `id` AS e FROM `gameobject` WHERE `map` = 289) s;

-- -------------------------------------------------------------------------------------
-- 3. Creature spawn guids
--
-- Needed as a TABLE rather than a formula because creature_formations stores
-- leaderGUID/memberGUID. (Scholomance has no guid-keyed smart_scripts rows -- 0 of them,
-- unlike Stratholme's 35 -- but the table costs nothing and keeps the two ports identical.)
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_cguid`;
CREATE TABLE `dc_scholo822_cguid` (
    `src_guid` INT UNSIGNED NOT NULL,
    `dst_guid` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_guid`),
    UNIQUE KEY `dst` (`dst_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_cguid` (`src_guid`, `dst_guid`)
SELECT s.g, 16750000 + (ROW_NUMBER() OVER (ORDER BY s.g)) - 1
FROM (SELECT `guid` AS g FROM `creature` WHERE `map` = 289) s;

-- -------------------------------------------------------------------------------------
-- 4. Gameobject spawn guids
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_gguid`;
CREATE TABLE `dc_scholo822_gguid` (
    `src_guid` INT UNSIGNED NOT NULL,
    `dst_guid` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_guid`),
    UNIQUE KEY `dst` (`dst_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_gguid` (`src_guid`, `dst_guid`)
SELECT s.g, 16530000 + (ROW_NUMBER() OVER (ORDER BY s.g)) - 1
FROM (SELECT `guid` AS g FROM `gameobject` WHERE `map` = 289) s;

-- -------------------------------------------------------------------------------------
-- 5. Waypoint path ids
--
-- 16 paths. creature_addon.path_id points into waypoint_data.id; left unmapped every clone
-- patroller would walk the STOCK path rows. Those rows exist and are valid, so nothing
-- would error -- the two dungeons would just silently share patrol data, and editing one
-- would move creatures in the other.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_scholo822_wpmap`;
CREATE TABLE `dc_scholo822_wpmap` (
    `src_path` INT UNSIGNED NOT NULL,
    `dst_path` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_path`),
    UNIQUE KEY `dst` (`dst_path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_scholo822_wpmap` (`src_path`, `dst_path`)
SELECT s.p, 8230000 + (ROW_NUMBER() OVER (ORDER BY s.p)) - 1
FROM (
    SELECT DISTINCT a.`path_id` AS p
        FROM `creature_addon` a
        JOIN `creature` c ON c.`guid` = a.`guid`
        WHERE c.`map` = 289 AND a.`path_id` > 0
) s;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature entries mapped (want 47)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_scholo822_cmap`
UNION ALL SELECT 'of which runtime-only, never spawned (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cmap` m
    WHERE m.`src_entry` NOT IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 289)
-- The three runtime-only entries that also carry a C++ script must be present, or their
-- bosses exist as templates with no AI.
UNION ALL SELECT 'scripted runtime-only entries mapped (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cmap` WHERE `src_entry` IN (10506, 11598, 16118)
-- The UpdateEntry morph pair. Dark Shade is the one an earlier draft missed entirely.
UNION ALL SELECT 'occultist morph pair mapped (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cmap` WHERE `src_entry` IN (10472, 11284)
UNION ALL SELECT 'gameobject entries mapped (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_gmap`
UNION ALL SELECT 'creature guids mapped (want 399)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cguid`
UNION ALL SELECT 'gameobject guids mapped (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_gguid`
UNION ALL SELECT 'waypoint paths mapped (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_wpmap`
-- Every target band must be empty, or 03/04 will collide on apply.
UNION ALL SELECT 'creature_template already in 5.7M band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'gameobject_template already in 5.8M band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
UNION ALL SELECT 'creature guids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`)
UNION ALL SELECT 'gameobject guids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_gguid`)
UNION ALL SELECT 'waypoint path ids already taken (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_scholo822_wpmap`)
-- No overlap with the Stratholme clone's bands.
UNION ALL SELECT 'collision with Stratholme clone guids (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cguid` WHERE `dst_guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
-- ObjectMgr.cpp:7669/7679 -- anything at or above 16777215 bricks startup with TCE00007.
UNION ALL SELECT 'creature guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_cguid` WHERE `dst_guid` >= 16777215
UNION ALL SELECT 'gameobject guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_scholo822_gguid` WHERE `dst_guid` >= 16777215;
