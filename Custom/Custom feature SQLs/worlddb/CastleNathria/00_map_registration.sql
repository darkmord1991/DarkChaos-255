-- Castle Nathria (map 2296) — Milestone 1: MAP REGISTRATION ONLY (walkable geometry).
--
-- This is the single server-DB row needed to make the InstanceType=2 raid map ENTERABLE.
-- Content (creature/gameobject spawns, loot, quests) and the C++ boss/instance scripts come LATER.
--
-- `script` = 'instance_castle_nathria': the ported instance C++ now exists
-- (src/server/scripts/DC/CastleNathria/instance_castle_nathria.cpp, registered via
-- dc_script_loader.cpp). Requires a worldserver build that includes it, or boot logs a
-- missing-ScriptName warning and the map falls back to scriptless (still enterable).
--
-- Client side already deployed (2026-07-16): assets in patch-H.MPQ; Map.dbc (2296, InstanceType=2)
-- + MapDifficulty.dbc (rows 9335-9338) in patch-4.MPQ AND the winning patch-enGB-3.MPQ; server
-- data/dbc updated. Server maps/vmaps(/mmaps) for 2296 must be generated before entering (else fall-through).
--
-- Apply against acore_world (idempotent):  SOURCE 00_map_registration.sql;

-- ---------------------------------------------------------------------------
-- instance_template — required or entry is rejected (CANNOT_ENTER_UNINSTANCED_DUNGEON)
-- ---------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 2296;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (2296, 0, 'instance_castle_nathria', 0);

-- Walk-in test (no game_tele row needed): as a GM, with the map registered and maps+vmaps deployed, run
--   .go xyz -1865.94 6721.381 4319.212 2296
-- (a known on-geometry interior coordinate from the Sludgefist arena). The real entrance AreaTrigger
-- teleport is authored with the content pass.
