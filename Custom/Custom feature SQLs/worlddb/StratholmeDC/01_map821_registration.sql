-- =====================================================================================
-- Stratholme DC clone -- map 821, step 01: register the map
--
-- Clones stock Stratholme (map 329) onto map id 821 so the DC re-level to 130-160 and a
-- DC-owned entrance/exit can happen WITHOUT touching stock content. Stock map 329 keeps
-- every one of its 469 creature and 188 gameobject spawns exactly as they are.
--
-- WHY A CLONE RATHER THAN REUSING 329
-- Stratholme's only exit trigger (2221) targets map 0, and its three entrance triggers on
-- map 751 (6822 back door, 6823/6824 the twin front gates) all lead to the shared stock
-- map. Anything placed inside 329 to make the exit land on 751 would change the dungeon
-- for every player on the realm. A private map id makes both ends ours.
--
-- CLIENT ART: NONE REQUIRED
-- Map.dbc field 1 (Directory) stays "Stratholme" on the clone row, so the client loads the
-- exact same WMO it already has. The map id appears only in server-side terrain FILENAMES,
-- which is why the terrain step is a plain rename-copy and no extractor run is needed.
-- See Custom/StratholmeDC/clone_map329_files_to_821.sh.
--
-- APPLY ORDER
--   01 this file           map registration
--   02 id maps             builds the dc_strat821_* remap tables everything else joins to
--   03 templates           creature_template + creature_template_model,
--                          gameobject_template + gameobject_template_addon
--   04 spawns              468 creatures, 188 gameobjects
--   05 spawn support       addons, formations, waypoints
--   06 behaviour           smart_scripts (entry, guid and gameobject) + creature_text
--   07 portals             walk-through trigger NPCs, entrance and exit
--
-- Also required, outside SQL:
--   * Map.dbc row 821                 Custom/StratholmeDC/add_strat821_dbc_rows.py
--   * MapDifficulty rows 9355-9357    same script -- ALL THREE, because every cloned spawn
--                                     carries spawnMask 7. Without them heroic and mythic
--                                     load as completely empty dungeons, silently.
--   * terrain rename-copy             Custom/StratholmeDC/clone_map329_files_to_821.sh
--   * worldserver rebuild             src/server/scripts/DC/StratholmeDC/
--
-- The DBC pair must be deployed to the CLIENT (patch-4 and enGB/patch-enGB-3, plus the
-- three WarcraftXLHost candidate dirs) AND copied to the server's own dbc directory.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. instance_template
--
-- script is 'instance_stratholme_dc', NOT 'instance_stratholme'. The two cannot share a
-- name: InstanceMapScript binds one script name to one map id, and ScriptMgr silently
-- DELETES the older registration when a name is reused (ScriptMgr.h:839) -- no error, the
-- first-registered instance just stops existing. Everything else is copied from 329 so
-- allowMount and parent stay whatever stock uses.
-- -------------------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 821;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`)
SELECT 821, `parent`, 'instance_stratholme_dc', `allowMount`
    FROM `instance_template` WHERE `map` = 329;

-- -------------------------------------------------------------------------------------
-- 2. dungeon_access_template
--
-- NOTE `id` is tinyint unsigned: the ceiling is 255 and the highest in use is 160, so
-- this band has ~94 ids left in it. 161 is the next free one.
--
-- Copied from 329's row rather than written by hand, so whatever level and quest gates
-- stock Stratholme uses apply unchanged to the clone for now.
--
-- THE LEVEL RESCALE TOUCHES THIS ROW. When the 130-160 re-level happens this is the single
-- place the entry gate lives -- the portal trigger NPCs deliberately carry no level check
-- of their own, because Player::TeleportTo already runs MapMgr::PlayerCannotEnter
-- (Player.cpp:1575) against this table and sends the player the standard message.
-- -------------------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 821;
INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
SELECT 161, 821, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`,
       'Stratholme (DC clone, map 821)'
    FROM `dungeon_access_template` WHERE `map_id` = 329;

-- -------------------------------------------------------------------------------------
-- 3. game_tele -- '.tele dcstrat' for testing before the portals exist
--
-- Coordinates are stock Stratholme's own entrance-side arrival point, which is valid on
-- the clone because the terrain is byte-identical.
-- -------------------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` = 10668 OR `name` = 'dcstrat';
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`)
VALUES (10668, 3392.36, -3380.6, 133.16, 4.71, 821, 'dcstrat');

-- -------------------------------------------------------------------------------------
-- Report
--
-- Every branch returns a number cast to CHAR. A UNION mixes the column collations
-- otherwise: `script`/`comment`/`name` are utf8mb4_unicode_ci while a bare literal takes
-- the connection collation, and MySQL raises 1271 "Illegal mix of collations".
-- -------------------------------------------------------------------------------------
SELECT 'instance_template row for 821 (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 821
UNION ALL SELECT 'and it names the DC script, not the stock one (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` = 821 AND `script` = 'instance_stratholme_dc'
-- If this is ever 0 the stock dungeon has been unregistered by a name clash.
UNION ALL SELECT 'stock 329 still bound to instance_stratholme (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` = 329 AND `script` = 'instance_stratholme'
UNION ALL SELECT 'dungeon_access_template row for 821 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dungeon_access_template` WHERE `map_id` = 821
UNION ALL SELECT 'game_tele dcstrat (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `game_tele` WHERE `name` = 'dcstrat' AND `map` = 821
-- Nothing may exist on 821 yet; a non-zero here means a previous run half-applied.
UNION ALL SELECT 'creature spawns on 821 so far (want 0 at this step)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821
UNION ALL SELECT 'gameobject spawns on 821 so far (want 0 at this step)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 821
-- The whole point of the exercise: stock Stratholme is untouched.
UNION ALL SELECT 'stock 329 creature spawns (want 469, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 329
UNION ALL SELECT 'stock 329 gameobject spawns (want 188, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 329;
