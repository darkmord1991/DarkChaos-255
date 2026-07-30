-- =====================================================================
-- Deepholm Downport  --  41  Missing escort/patrol waypoints
-- ---------------------------------------------------------------------
-- REWRITTEN 2026-07-20 -- the original version of this file was DESTRUCTIVE.
--
-- It read:
--     DELETE FROM `waypoint_data` WHERE `id` IN (9490260,9244515);
--     INSERT ... SELECT ... FROM `nelt_world`.`waypoint_data`
--                           WHERE `id` IN (9490260,9244515);
--
-- ...but 9490260 / 9244515 are this DB's REMAPPED ids. 30_neltharion_spawn_
-- layer.sql declares the import offsets ("waypoint +9000000"), so nelt_world's
-- own ids are the RAW 490260 / 244515. Selecting the already-offset ids from
-- the un-offset source matched nothing, so the INSERT was a silent no-op while
-- the DELETE still fired -- it deleted the two paths 30_ had correctly imported
-- and put nothing back. Net effect: it CREATED the very error it claimed to fix
--
--     WaypointMovementGenerator::DoInitialize: creature Gyreworm
--     (Entry: 44257) doesn't have waypoint path id: 9490260
--     ... same for Xariona (Entry: 50061), path id 9244515
--
-- ...on every respawn of both. Same bug class as the Flamewaker Shaman `lootid`
-- regression (offset applied to the wrong side of a cross-DB copy) -- when a
-- zone import remaps ids, the remap belongs on the WRITE side; the source must
-- always be queried with ITS OWN ids.
--
-- Verified before rewriting:
--   * nelt_world.waypoint_data 490260 = 16 points, 244515 = 18 points;
--   * 30_neltharion_spawn_layer.sql already contains exactly 16 rows for
--     9490260 and 18 for 9244515 -- byte-for-byte the same routes;
--   * both ids are absent from the live DB right now (0 rows), and no other
--     waypoint_data id in this DB collides with them.
--   * 244515 is Xariona's full circumnavigation of Deepholm (18 points, starts
--     and ends at 964.4/983.9 -- her spawn point, 965.375/983.912); 490260 is
--     Gyreworm's 16-point local patrol around 1756/541.
--
-- This rewrite is now correct AND idempotent: it selects from nelt_world by the
-- raw ids and applies the +9,000,000 offset on write, so re-running it restores
-- the same rows 30_ would. Safe to apply with or without 30_.
--
-- NOTE (kept from the original): nelt_world.waypoint_data has no `move_type`
-- column (older schema). Dropped from the copy; the target row keeps its column
-- default (0 = walk), correct for a ground patrol. Xariona is a flyer, but she
-- carries Flight=1 in creature_template_movement (26_A), which is what actually
-- keeps her airborne -- move_type is not the flight switch on this core.
-- =====================================================================

DELETE FROM `waypoint_data` WHERE `id` IN (9490260,9244515);

INSERT INTO `waypoint_data`
    (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`)
SELECT `id` + 9000000, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`
FROM `nelt_world`.`waypoint_data`
WHERE `id` IN (490260,244515);

-- ---------------------------------------------------------------------
-- Verification -- should return the two ids with 16 and 18 points:
--   SELECT id, COUNT(*) FROM waypoint_data WHERE id IN (9490260,9244515) GROUP BY id;
-- ---------------------------------------------------------------------
