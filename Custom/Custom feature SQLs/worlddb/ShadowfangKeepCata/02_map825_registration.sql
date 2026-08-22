-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 2: instance registration
--
-- Registers the clone as a dungeon. Nothing here spawns anything; that is step 03.
--
-- REQUIRES FIRST:
--   * Map.dbc row 825 + MapDifficulty 9352/9353/9354
--     (Custom/ShadowfangKeepCata/add_sfk825_dbc_rows.py --apply, then compile + deploy
--      to the client MPQ *and* the server's data/dbc -- without the Map.dbc row the
--      server asserts in MapMgr::CreateBaseMap the first time anyone enters)
--   * the server terrain rename-copy
--     (Custom/ShadowfangKeepCata/clone_map33_files_to_825.sh <data> --apply, 64 files)
--   * a worldserver carrying src/server/scripts/DC/ShadowfangKeepCata (already built)
--
-- STOCK SHADOWFANG KEEP (map 33) IS NOT TOUCHED BY THIS FILE. Every statement is
-- scoped to map 825 or to ids in a band verified free.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- instance_template
--
-- `script` binds the C++ InstanceScript. Map 33's own script is registered as
-- InstanceMapScript("instance_shadowfang_keep", 33) -- the map id is baked into the
-- constructor, so the clone cannot reuse it. The DC port registers the Cataclysm
-- encounter set as "instance_sfk_cata" against map 825
-- (src/server/scripts/DC/ShadowfangKeepCata/instance_sfk_cata.cpp).
--
-- allowMount 0: stock SFK does not allow mounts, and the Cata revamp did not change that.
-- -------------------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 825;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (825, 0, 'instance_sfk_cata', 0);

-- -------------------------------------------------------------------------------------
-- dungeon_access_template -- one row per difficulty.
-- `id` is tinyint unsigned (max 255); live MAX was 157, so 158-160 are free.
--
-- Levels are PLACEHOLDER TUNING, deliberately conservative, and are the one thing in
-- this file you will want to revisit. The Cataclysm original is an 85 heroic. Nothing
-- has been re-leveled yet -- step 03 imports the Cata spawns at their source levels --
-- so these gates just keep low-level characters out until you pick a band.
-- -------------------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 825;
INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (158, 825, 0, 80, 0, 0, 'Shadowfang Keep (Cataclysm) - Normal'),
    (159, 825, 1, 85, 0, 0, 'Shadowfang Keep (Cataclysm) - Heroic'),
    (160, 825, 2, 85, 0, 0, 'Shadowfang Keep (Cataclysm) - Mythic');

-- -------------------------------------------------------------------------------------
-- game_tele -- `.tele dcsfk`
--
-- id 10667 (live MAX was 10666). The arrival point is map 33's own entrance position,
-- read off the existing stock tele row 833 'SFK', which maps 33 and 825 share verbatim
-- because they share the terrain.
--
-- Stock row 833 'SFK' -> map 33 is LEFT ALONE, so `.tele sfk` still goes to classic SFK.
-- The DELETE covers the name as well as the id so a re-run cannot leave `.tele dcsfk`
-- ambiguous between two rows.
--
-- NOTE: a bare `.tele` into an instance map can abort with TRANSFER_ABORT_DIFFICULTY if
-- the character's dungeon difficulty has no MapDifficulty row for the target -- that is
-- what bit the first Naxx-40 attempt. All three rows (9352/9353/9354) exist, so normal,
-- heroic and mythic are all enterable, but the DBC must be deployed to the SERVER for
-- that to hold.
-- -------------------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` = 10667 OR `name` = 'dcsfk';
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10667, -229.135, 2109.18, 76.8898, 1.5, 825, 'dcsfk');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'instance_template (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 825
UNION ALL SELECT 'access rows (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `dungeon_access_template` WHERE `map_id` = 825
UNION ALL SELECT 'game_tele dcsfk (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `game_tele` WHERE `name` = 'dcsfk'
UNION ALL SELECT 'STOCK map 33 instance_template untouched (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` = 33 AND `script` = 'instance_shadowfang_keep'
UNION ALL SELECT 'STOCK game_tele SFK still map 33 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `game_tele` WHERE `id` = 833 AND `map` = 33;
