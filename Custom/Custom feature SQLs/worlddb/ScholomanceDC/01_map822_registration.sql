-- =====================================================================================
-- Scholomance DC clone -- map 822, step 01: register the map
--
-- Clones stock Scholomance (map 289) onto map id 822 so the 130-160 re-level and a
-- DC-owned entrance/exit can happen WITHOUT touching stock content. Stock map 289 keeps
-- all 399 creature and 62 gameobject spawns exactly as they are.
--
-- This is the same recipe as the Stratholme clone (map 821), which is the working
-- reference for every step here.
--
-- CLIENT ART: NONE REQUIRED
-- Map.dbc field 1 (Directory) stays "SchoolofNecromancy" on the clone row, so the client
-- loads the exact same WMO it already has. The map id appears only in server-side terrain
-- FILENAMES, which is why the terrain step is a plain rename-copy and no extractor run is
-- needed.
--
-- APPLY ORDER
--   01 this file           map registration
--   02 id maps             builds the dc_scholo822_* remap tables everything else joins to
--   03 templates           creature_template + creature_template_model,
--                          gameobject_template + gameobject_template_addon
--   04 spawns              399 creatures, 62 gameobjects
--   05 spawn support       addons, formations, waypoints
--   06 behaviour           smart_scripts (entry / gameobject / action lists) + creature_text
--   07 portals             walk-through trigger NPCs, 1 entrance and 4 exits
--
-- Also required, outside SQL:
--   * Map.dbc row 822                 Custom/ScholomanceDC/add_scholo822_dbc_rows.py
--   * MapDifficulty rows 9358-9360    same script -- ALL THREE, because every cloned spawn
--                                     carries spawnMask 7. Without them heroic and mythic
--                                     load as completely empty dungeons, silently.
--   * DungeonMap / DungeonMapChunk / WorldMapArea rows -- same script. Without these the
--                                     in-instance map frame comes up blank.
--   * terrain rename-copy             Custom/ScholomanceDC/clone_map289_files_to_822.sh
--   * worldserver rebuild             src/server/scripts/DC/ScholomanceDC/
--
-- The DBCs must be deployed to the CLIENT (patch-4 and enGB/patch-enGB-3, plus the three
-- WarcraftXLHost candidate dirs) AND copied to the server's own dbc directory.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. instance_template
--
-- script is 'instance_scholomance_dc', NOT 'instance_scholomance'. The two cannot share a
-- name: InstanceMapScript binds one script name to one map id, and ScriptMgr silently
-- DELETES the older registration when a name is reused (ScriptMgr.h:839) -- no error, the
-- first-registered instance just stops existing.
-- -------------------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 822;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`)
SELECT 822, `parent`, 'instance_scholomance_dc', `allowMount`
    FROM `instance_template` WHERE `map` = 289;

-- -------------------------------------------------------------------------------------
-- 2. dungeon_access_template
--
-- Copied from 289's row (difficulty 0, min_level 45) rather than written by hand.
--
-- THE LEVEL RESCALE TOUCHES THIS ROW. It is the single place the entry gate lives -- the
-- portal trigger NPCs deliberately carry no level check of their own, because
-- Player::TeleportTo already runs MapMgr::PlayerCannotEnter (Player.cpp:1575) against this
-- table and sends the player the standard message.
--
-- NOTE `id` is tinyint unsigned: ceiling 255, highest in use is 161 (the Stratholme clone).
-- 162 is the next free one.
-- -------------------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 822;
INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
SELECT 162, 822, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`,
       'Scholomance (DC clone, map 822)'
    FROM `dungeon_access_template` WHERE `map_id` = 289;

-- -------------------------------------------------------------------------------------
-- 3. game_tele -- '.tele dcscholo' for testing before the portals exist
--
-- Coordinates are stock Scholomance's own entrance arrival point, valid on the clone
-- because the terrain is byte-identical.
-- -------------------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` = 10670 OR `name` = 'dcscholo';
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`)
SELECT 10670, `target_position_x`, `target_position_y`, `target_position_z`,
       `target_orientation`, 822, 'dcscholo'
    FROM `areatrigger_teleport` WHERE `ID` = 6828;

-- -------------------------------------------------------------------------------------
-- Report
--
-- Every branch returns a number cast to CHAR. A UNION mixes the column collations
-- otherwise: `script`/`comment`/`name` are utf8mb4_unicode_ci while a bare literal takes
-- the connection collation, and MySQL raises 1271 "Illegal mix of collations".
-- -------------------------------------------------------------------------------------
SELECT 'instance_template row for 822 (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 822
UNION ALL SELECT 'and it names the DC script, not the stock one (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` = 822 AND `script` = 'instance_scholomance_dc'
-- If this is ever 0 the stock dungeon has been unregistered by a name clash.
UNION ALL SELECT 'stock 289 still bound to instance_scholomance (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` = 289 AND `script` = 'instance_scholomance'
UNION ALL SELECT 'dungeon_access_template row for 822 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dungeon_access_template` WHERE `map_id` = 822
UNION ALL SELECT 'game_tele dcscholo (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `game_tele` WHERE `name` = 'dcscholo' AND `map` = 822
-- Nothing may exist on 822 yet; a non-zero here means a previous run half-applied.
UNION ALL SELECT 'creature spawns on 822 so far (want 0 at this step)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 822
UNION ALL SELECT 'gameobject spawns on 822 so far (want 0 at this step)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 822
-- The whole point of the exercise: stock Scholomance is untouched.
UNION ALL SELECT 'stock 289 creature spawns (want 399, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 289
UNION ALL SELECT 'stock 289 gameobject spawns (want 62, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 289;
