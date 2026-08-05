-- =============================================================================
-- DC Rare Spawn Pools - one spawn point live per rare
-- =============================================================================
-- Twelve rares on maps 750 and 37 have more than one spawn point, and every point
-- is up simultaneously. Eight of those pairs are a legacy WotLK-era spawn at
-- spawntimesecs = 300 sitting a few hundred yards from the proper Cata spawn at
-- 12-24h - so the "12h rare" was in practice permanently available, which
-- defeated both the rarity and the respawn announcer.
--
-- Fix is pooling, NOT deletion: every spawn point stays in `creature`, and a
-- max_limit = 1 pool_template makes exactly one of them live at a time. On kill,
-- Creature::Update -> PoolMgr::UpdatePool<Creature> re-rolls the pool and the
-- rare comes back at a randomly chosen point after its spawntimesecs
-- (src/server/game/Entities/Creature/Creature.cpp:2118, Maps/Map.cpp:2794).
-- This is the retail behaviour for Cata/WotLK rares and it preserves the
-- map-750 rule that creature spawn rows are never deduped.
--
-- Prerequisite: 2026_08_05_00_dc_rare_spawn_timers.sql, which gives every member
-- of a pool the same spawntimesecs. The pool re-roll delay comes from the member
-- that despawned, so mixed timers inside one pool produce a random cadence.
--
-- Pool id band 133000100-133000199 reserved for DC rare rotations. Verified free:
-- pool_template previously held exactly one entry above 133000000 (133000001).
--
-- Verified before writing: none of these guids appear in pool_creature,
-- linked_respawn, game_event_creature or creature_formations, so pooling cannot
-- conflict with an existing spawn-control mechanism. Three of them
-- (15501205, 15501214, 15501216) have creature_addon waypoint paths, which stay
-- valid - pooling changes which point spawns, not how it moves.
-- =============================================================================

DELETE FROM `pool_creature` WHERE `pool_entry` BETWEEN 133000100 AND 133000199;
DELETE FROM `pool_template` WHERE `entry` BETWEEN 133000100 AND 133000199;

INSERT INTO `pool_template` (`entry`, `max_limit`, `description`) VALUES
(133000101, 1, 'DC Rare: Garr (3650056) - Hyjal Frontier'),
(133000102, 1, 'DC Rare: General Colbatann (3710196) - Winterspring'),
(133000103, 1, 'DC Rare: Thartuk the Exile (3650053) - Hyjal Frontier'),
(133000104, 1, 'DC Rare: Terrorpene (3650058) - Hyjal Frontier'),
(133000105, 1, 'DC Rare: Blazewing (3650057) - Hyjal Frontier'),
(133000106, 1, 'DC Rare: Ban''thalos (3654320) - Hyjal Frontier'),
(133000107, 1, 'DC Rare: Ankha (3654318) - Hyjal Frontier'),
(133000108, 1, 'DC Rare: Lady Vespira (3707016) - Darkshore'),
(133000109, 1, 'DC Rare: Lord Sinslayer (3707017) - Darkshore'),
(133000110, 1, 'DC Rare: Death Howl (3714339) - Felwood'),
(133000111, 1, 'DC Rare: Olm the Wise (3714343) - Felwood'),
(133000112, 1, 'DC Rare: Lord Hel''nurath (14506) - Azshara Crater');

-- chance = 0 on every member: equal-weight random pick among the despawned points.
INSERT INTO `pool_creature` (`guid`, `pool_entry`, `chance`, `description`) VALUES
-- Garr - 86400s
(12202216, 133000101, 0, 'Garr spawn point 1'),
(15501214, 133000101, 0, 'Garr spawn point 2 (was 300s legacy spawn)'),
-- General Colbatann - 43200s
(15802279, 133000102, 0, 'General Colbatann spawn point 1'),
(16376689, 133000102, 0, 'General Colbatann spawn point 2 (was 300s legacy spawn)'),
-- Thartuk the Exile - 72000s
(12193475, 133000103, 0, 'Thartuk the Exile spawn point 1'),
(15501205, 133000103, 0, 'Thartuk the Exile spawn point 2 (was 300s legacy spawn)'),
-- Terrorpene - 72000s
(12193834, 133000104, 0, 'Terrorpene spawn point 1'),
(15501216, 133000104, 0, 'Terrorpene spawn point 2 (was 300s legacy spawn)'),
-- Blazewing - 14400s
(12250898, 133000105, 0, 'Blazewing spawn point 1'),
(15501215, 133000105, 0, 'Blazewing spawn point 2 (was 300s legacy spawn)'),
-- Ban'thalos - 14400s
(12194904, 133000106, 0, 'Ban''thalos spawn point 1'),
(15501256, 133000106, 0, 'Ban''thalos spawn point 2 (was 300s legacy spawn)'),
-- Ankha - 14400s (both points were 300s)
(12250976, 133000107, 0, 'Ankha spawn point 1'),
(15501255, 133000107, 0, 'Ankha spawn point 2'),
-- Lady Vespira - 14400s
(15802287, 133000108, 0, 'Lady Vespira spawn point 1'),
(15862300, 133000108, 0, 'Lady Vespira spawn point 2 (was 300s legacy spawn)'),
-- Lord Sinslayer - 14400s
(15800275, 133000109, 0, 'Lord Sinslayer spawn point 1'),
(15862301, 133000109, 0, 'Lord Sinslayer spawn point 2 (was 300s legacy spawn)'),
-- Death Howl - 86400s (both points already authored at 24h)
(15700092, 133000110, 0, 'Death Howl spawn point 1'),
(15801066, 133000110, 0, 'Death Howl spawn point 2'),
-- Olm the Wise - 86400s (three points already authored at 24h)
(15802285, 133000111, 0, 'Olm the Wise spawn point 1'),
(15802685, 133000111, 0, 'Olm the Wise spawn point 2'),
(15802686, 133000111, 0, 'Olm the Wise spawn point 3'),
-- Lord Hel'nurath - 7200s, map 37
(3112070, 133000112, 0, 'Lord Hel''nurath spawn point 1'),
(9001041, 133000112, 0, 'Lord Hel''nurath spawn point 2');

-- =============================================================================
-- Verification
-- =============================================================================
-- 12 pools, 25 members, and every member of a pool sharing one timer:
--
-- SELECT pc.pool_entry, pt.max_limit, COUNT(*) AS points,
--        COUNT(DISTINCT c.spawntimesecs) AS distinct_timers
-- FROM pool_creature pc
-- JOIN pool_template pt ON pt.entry = pc.pool_entry
-- JOIN creature c ON c.guid = pc.guid
-- WHERE pc.pool_entry BETWEEN 133000100 AND 133000199
-- GROUP BY pc.pool_entry, pt.max_limit;
--   -> every row: max_limit = 1, distinct_timers = 1
--
-- No rare should still have two live points after a worldserver restart:
--
-- SELECT c.id, ct.name, COUNT(*) AS points, COUNT(pc.guid) AS pooled
-- FROM creature c
-- JOIN creature_template ct ON ct.entry = c.id
-- LEFT JOIN pool_creature pc ON pc.guid = c.guid
-- WHERE c.map IN (750, 37) AND ct.rank IN (2, 4)
-- GROUP BY c.id, ct.name HAVING points > 1 AND pooled <> points;
--   -> 0 rows
--
-- Boot log check: "Loaded X objects pooled" in server startup, and no
-- "creature_pool ... is not part of a pool" / "max_limit" warnings for the
-- 133000100+ band in Errors.log.
