-- =====================================================================================
-- DC Teleporter: the three dungeons that had no menu entry
--
--   809  Stratholme (DC)     map 821   -- Custom Dungeons (800)
--   810  Scholomance (DC)    map 822   -- Custom Dungeons (800)
--   811  Karazhan Crypts     map 2875  -- Custom Dungeons (800), see the CAVEAT below
--
-- Follows 2026_08_23_00_dc_teleporter_custom_raids_and_levels.sql exactly -- same table
-- shape, same "(N+)" label rule, same DELETE-by-id-AND-by-name idempotency.
--
-- Table shape (read by src/server/scripts/DC/Teleporters/dc_teleporter.cpp:117):
--     id, parent, type, faction, security_level, icon, name, map, x, y, z, o
--   parent 0 + type 1          = category
--   parent <category> + type 2 = destination
--   faction -1                 = both factions
--   icon 2                     = the icon every other teleport row uses
--
-- Apply with `.dc teleporter reload` in game (GM only, dc_teleporter.cpp:270) or a
-- worldserver restart -- options are cached in memory at startup.
--
-- -------------------------------------------------------------------------------------
-- WHY 800 AND NOT 850
-- -------------------------------------------------------------------------------------
-- Map.dbc InstanceType decides, not taste: 821, 822 and 2875 are all type 1 (dungeon),
-- so all three sit under "Custom Dungeons". Nothing moves between the two categories here.
--
-- -------------------------------------------------------------------------------------
-- WHERE THE ARRIVAL POINTS COME FROM
-- -------------------------------------------------------------------------------------
-- Not invented, and not the `.tele` shortcuts -- each one is the destination the dungeon's
-- OWN walk-in portal uses, so the teleporter and the door drop you on the same tile:
--
--   821  npc_stratholme_dc_portal_trigger.cpp:106  front-right gate
--            -> 3393.27, -3392.00, 143.15, o 1.571
--        (this is also game_tele 10669 `dcstrath` to within 12 yd; the portal value is
--         used because it is the one that is actually walked into every day)
--   822  npc_scholomance_dc_portal_trigger.cpp:94  entrance
--            -> 199.88, 125.35, 138.43, o 4.677   == game_tele 10670 `dcscholo` exactly
--   2875 game_tele 10615 `sodcrypts` -> -11170.8, -1997.6, 35.7399, o 0
--        (no portal exists for this one -- see the caveat)
--
-- -------------------------------------------------------------------------------------
-- WHERE THE LEVEL NUMBERS COME FROM
-- -------------------------------------------------------------------------------------
-- `MIN(min_level)` from `dungeon_access_template`, the number the server itself enforces
-- at the door -- same rule as the previous file. Both clones inherited stock's gate:
--     821 -> 45      822 -> 45
--
-- READ THIS BEFORE "fixing" the labels: StratholmeDC/00_README.md and
-- ScholomanceDC/00_README.md both state the intent to re-level these to 130-160 for the
-- Lordaeron extension, and that has NOT happened -- the access rows still say 45.
-- "(45+)" therefore describes the door correctly today. When you re-level either map,
-- re-run the matching UPDATE in section 3 rather than editing the name by hand.
--
-- -------------------------------------------------------------------------------------
-- CAVEAT -- KARAZHAN CRYPTS (811) IS AN EMPTY SHELL
-- -------------------------------------------------------------------------------------
-- Map 2875 is registered (`instance_template` row present, Map.dbc row present on the live
-- server, terrain baked and packed) but it has 0 creature spawns, no
-- `dungeon_access_template` row, and no instance script. KarazhanCrypts/00_README.md also
-- lists the mapextractor/vmap4extractor/mmaps_generator run as "not done by this session,
-- the user is running this separately" -- if that never happened, arriving there means
-- falling through the world.
--
-- It is included anyway because the menu it lands in is GM-only (see VISIBILITY) and
-- `.tele sodcrypts` already gives exactly the same reach, so this adds no player-facing
-- risk -- only a discoverable entry. It carries NO "(N+)" suffix on purpose: there is no
-- access gate to read one from, and inventing a number would be a guess. The report at
-- the bottom excludes it from the label check for that reason.
--
-- If you would rather it not be listed until it has content:
--     DELETE FROM `dc_teleporter` WHERE `id` = 811;
--
-- -------------------------------------------------------------------------------------
-- VISIBILITY -- READ THIS BEFORE YOU EXPECT PLAYERS TO SEE ANY OF IT
-- -------------------------------------------------------------------------------------
-- Category 800 "Custom Dungeons" carries security_level = 1, so the whole menu is GM-only
-- today, and these three inherit that gating by living inside it. This file does not
-- change that. To open the menu:
--
--     UPDATE `dc_teleporter` SET `security_level` = 0 WHERE `id` IN (800, 850);
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. The three destinations
--
-- Ids 809-811 continue the 800 band (live MAX under it was 808; 809-811 verified free).
--
-- The DELETE covers the NAMES as well as the ids: the loader rejects duplicate labels
-- under the same parent (dc_teleporter.cpp:87), so a re-run under a different id would
-- leave a stale twin behind and log a duplicate-label warning at startup. The unsuffixed
-- spellings are included so a hand-added row from before this file is also cleared.
--
-- The "(DC)" in the two clone names is load-bearing, not decoration: ids 82 and 95 under
-- "Dungeons Classic" are stock Stratholme (329) and stock Scholomance (289) and stay
-- exactly where they are. These are the map 821/822 clones that exit onto the Lordaeron
-- extension (751), which is a different destination, not a replacement.
-- -------------------------------------------------------------------------------------
DELETE FROM `dc_teleporter`
    WHERE `id` IN (809, 810, 811)
       OR (`parent` = 800 AND `name` IN ('Stratholme (DC) (45+)', 'Stratholme (DC)',
                                         'Scholomance (DC) (45+)', 'Scholomance (DC)',
                                         'Karazhan Crypts (SoD)', 'Karazhan Crypts'));

INSERT INTO `dc_teleporter`
    (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`, `comment`) VALUES
    (809, 800, 2, -1, 0, 2, 'Stratholme (DC) (45+)',  821,   3393.270, -3392.000,  143.150, 1.571,
        'npc_stratholme_dc_portal_trigger front-right gate destination'),
    (810, 800, 2, -1, 0, 2, 'Scholomance (DC) (45+)', 822,    199.880,   125.350,  138.430, 4.677,
        'npc_scholomance_dc_portal_trigger entrance destination = game_tele 10670 dcscholo'),
    (811, 800, 2, -1, 0, 2, 'Karazhan Crypts (SoD)', 2875, -11170.800, -1997.600,   35.740, 0.000,
        'game_tele 10615 sodcrypts -- map has 0 spawns and no access template, see file header');

-- -------------------------------------------------------------------------------------
-- 2. Nothing to re-parent
--
-- All three are dungeons (Map.dbc InstanceType 1), so category 850 "Custom Raids" is not
-- touched by this file.
-- -------------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- 3. Level labels
--
-- Scoped by id, one statement per row, so a name edited by hand since is still overwritten
-- predictably and a re-run is a no-op. Re-run these after re-levelling 821/822.
-- -------------------------------------------------------------------------------------
UPDATE `dc_teleporter` SET `name` = 'Stratholme (DC) (45+)'  WHERE `id` = 809;
UPDATE `dc_teleporter` SET `name` = 'Scholomance (DC) (45+)' WHERE `id` = 810;

-- -------------------------------------------------------------------------------------
-- Report
--
-- Every branch is CAST(... AS CHAR): a bare literal in a UNION takes the connection
-- collation while `name`/`comment` are utf8mb4_unicode_ci, and MySQL raises
-- 1271 Illegal mix of collations.
-- -------------------------------------------------------------------------------------
SELECT 'new destinations 809-811 exist (want 3)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_teleporter` WHERE `id` IN (809, 810, 811) AND `parent` = 800 AND `type` = 2
UNION ALL SELECT 'dungeons now under 800 (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `parent` = 800
UNION ALL SELECT 'new rows pointing at a map with no instance_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` t LEFT JOIN `instance_template` i ON i.`map` = t.`map`
    WHERE t.`id` IN (809, 810, 811) AND i.`map` IS NULL
UNION ALL SELECT 'new label level <> dungeon_access_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` t
    WHERE t.`id` IN (809, 810)
      AND t.`name` NOT LIKE CONCAT('%(', (SELECT MIN(d.`min_level`) FROM `dungeon_access_template` d
                                          WHERE d.`map_id` = t.`map`), '+)')
UNION ALL SELECT 'duplicate labels under any parent (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT `parent`, `faction`, `security_level`, `name` FROM `dc_teleporter`
          GROUP BY `parent`, `faction`, `security_level`, `name` HAVING COUNT(*) > 1) d
UNION ALL SELECT 'orphan parent links (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` c LEFT JOIN `dc_teleporter` p ON p.`id` = c.`parent`
    WHERE c.`parent` <> 0 AND p.`id` IS NULL
UNION ALL SELECT 'dungeon/raid rows missing a level label, 811 excluded (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `parent` IN (80, 100, 150, 200, 250, 300, 800, 850)
      AND `id` <> 811 AND `name` NOT LIKE '%+)'
UNION ALL SELECT 'Karazhan Crypts spawn count (0 = still an empty shell)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 2875
UNION ALL SELECT 'menus 800/850 visible to non-GMs (0 = GM only)', CAST(SUM(IF(`security_level` = 0, 1, 0)) AS CHAR)
    FROM `dc_teleporter` WHERE `id` IN (800, 850);
