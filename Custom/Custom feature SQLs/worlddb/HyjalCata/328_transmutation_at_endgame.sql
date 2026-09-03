-- ---------------------------------------------------------------------------
-- 328  Transmutation / Exchange at the endgame hubs
-- ---------------------------------------------------------------------------
-- The Transmutation Master (190004, script `ItemUpgradeTransmutationNPC`) is
-- spawned SEVEN times -- maps 0, 1 (x2), 530, 745, 1409, 1413 -- and on none of
-- the level-80+ continents. A level-130 player at Molten Front has to fly back
-- to Stormwind or a guild house to trade Upgrade Tokens for Artifact Essence.
--
-- 🔴 NAMING: "Transmutation" was renamed "Exchange" in Jan 2026
-- (ItemUpgradeTransmutation.h is now a forwarding stub to ItemUpgradeExchange.h)
-- but the creature's ScriptName and subname were never updated -- it still
-- reads "Transform your upgraded items!", which it does NOT do. It opens the
-- token <-> essence currency window (SMSG_OPEN_TRANSMUTE_UI). The ScriptName is
-- deliberately left alone: it is the DB binding and renaming it breaks the NPC.
-- The subname IS corrected here, because it actively misleads.
--
-- ---------------------------------------------------------------------------
-- TWO WAYS IN, both shipped
-- ---------------------------------------------------------------------------
-- 1. COMBINED -- both quartermasters gained a gossip entry
--    "|cff32c4ff[UI]|r Transmutation / Currency Exchange" (action 9100) that
--    opens the same addon window. So the level-130 Frontier Quartermaster is a
--    one-stop NPC: gear, currency exchange, and the token vendor UI. That is a
--    C++ change in dc_mythicplus_token_vendor.cpp and needs the build.
--
--    🔴 The inline "Currency Exchange (Tokens <-> Essence)" entry is now shown
--    on BOTH vendors again. An earlier revision hid it on the sap vendor on the
--    reasoning that "sap has no essence conversion" -- which was wrong: that
--    trade moves the PLAYER's own currencies and has nothing to do with what
--    the vendor charges. Hiding it only forced a walk back to a level-80 NPC.
--
-- 2. STANDALONE -- this file also spawns 190004 itself at both endgame hubs,
--    for players who are not at the quartermaster.
--
-- 🔴 SPAWN GUIDS: 16751200-16751201. Verified free, above the live maximum
-- (16,751,103) and under the 0xFFFFFF = 16,777,215 spawn-id ceiling that
-- ObjectMgr::GenerateCreatureSpawnId() hard-fails on. Picking a guid above that
-- ceiling bricks startup with TCE00007 -- it has happened twice on this realm,
-- most recently from 327_. ALWAYS run this first:
--     SELECT MAX(guid), 16777215 - MAX(guid) FROM creature WHERE guid <= 16777215;
-- Headroom at time of writing: ~26,100 ids. Getting tight.
--
-- Apply against acore_world. Idempotent. The spawns work WITHOUT the build
-- (190004 is an existing, already-registered script); only the combined gossip
-- entry on the quartermasters needs the rebuild.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Correct the misleading subname
-- ---------------------------------------------------------------------------
-- It has said "Transform your upgraded items!" since before the Jan 2026
-- rename; the NPC has never transformed an item.
UPDATE `creature_template`
SET `subname` = 'Currency Exchange'
WHERE `entry` = 190004;

-- ---------------------------------------------------------------------------
-- 2. Spawn at the endgame hubs
-- ---------------------------------------------------------------------------
-- Molten Front (861 / 4925) beside the sap quartermasters and the new Frontier
-- Quartermaster; Hyjal Frontier (750 / 4923) at the Nordrassil vendor cluster
-- (Lenedil Moonwing, Toron Rockhoof, Sebelia the innkeeper).
DELETE FROM `creature` WHERE `guid` IN (16751200, 16751201);

INSERT INTO `creature`
  (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
   `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`,
   `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`,
   `MovementType`)
VALUES
  -- Molten Front hub, next to the Frontier Quartermaster (992.4, 379.2, 39.1)
  (16751200, 190004, 861, 4925, 0, 1, 1, 0, 988.60, 383.60, 38.80, 2.408,
   300, 0, 0, 1, 0, 0),
  -- Nordrassil, beside Lenedil Moonwing (5511.0, -3604.2, 1570.1)
  (16751201, 190004, 750, 4923, 0, 1, 1, 0, 5516.90, -3600.80, 1570.10, 0.404,
   300, 0, 0, 1, 0, 0);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Now spawned on the endgame continents too (expect 9 rows, incl. maps 750/861):
-- SELECT guid, map, zoneId, position_x, position_y, position_z
-- FROM creature WHERE id = 190004 ORDER BY map;
--
-- Subname corrected (expect 'Currency Exchange'):
-- SELECT entry, name, subname, ScriptName FROM creature_template WHERE entry = 190004;
--
-- 🔴 NOTHING over the spawn-id ceiling -- run BEFORE every restart (expect 0/0):
-- SELECT COUNT(*) FROM creature WHERE guid > 16777215;
-- SELECT COUNT(*) FROM gameobject WHERE guid > 16777215;
--
-- In-game, after the build + restart:
--   * Frontier Quartermaster -> "[UI] Transmutation / Currency Exchange" opens
--     the exchange window; the same entry exists on the Mythic+ vendor;
--   * the standalone Transmutation Master stands at both hubs and opens the
--     same window on gossip.
-- ---------------------------------------------------------------------------
