-- ---------------------------------------------------------------------------
-- Huntmaster Grimtusk (401202, guid 9000368) -- MovementType 2 -> 1
-- ---------------------------------------------------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Huntmaster Grimtusk
--     (Entry: 401202) doesn't have waypoint path id: 0
--
-- Boot-log pass 2026-07-20. This spawn asks for WAYPOINT_MOTION_TYPE (2) with
-- no `creature_addon` row, so it resolves to path id 0 and logs on every
-- respawn.
--
-- Unlike the Deepholm/Plaguelands/Hyjal cases fixed in the same pass, there is
-- no route to recover: Grimtusk is DC-authored content (entry 401202,
-- giant_isles_creatures.sql, map 1405), not a downport, so no upstream source
-- has a patrol for him -- and the spawn row itself is live-DB-only, not present
-- in any tracked SQL file in this folder, so there is no authoring intent
-- recorded anywhere to honour.
--
-- Set to 1 (random wander) rather than 0 (idle): `wander_distance` is 0 today,
-- so it is raised to 5 alongside -- a "Beast Tracker" NPC that shifts around
-- his camp reads better than a frozen statue, and MovementType=1 with
-- wander_distance=0 is itself a known no-op trap this codebase has hit before
-- (HyjalCata/155_). If a real patrol is ever wanted here, author a
-- waypoint_data path + creature_addon.path_id and flip this back to 2.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 5
WHERE `guid` = 9000368 AND `id` = 401202 AND `MovementType` = 2;
