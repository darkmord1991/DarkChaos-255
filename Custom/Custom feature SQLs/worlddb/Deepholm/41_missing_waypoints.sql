-- =====================================================================
-- Deepholm Downport  --  41  Missing escort/patrol waypoints
-- ---------------------------------------------------------------------
-- 2 MovementType=2 (WAYPOINT_MOTION_TYPE) creatures -- Gyreworm (44257,
-- guid 9549026) and Xariona (50061, guid 9746396), the Twilight world boss
-- -- have a creature_addon.path_id set but no matching waypoint_data rows,
-- so they have nothing to patrol/escort along. Same gap class as
-- HyjalCata/52_smartai_error_fixes.sql fix D (paths never copied over from
-- nelt_world during the neltharion sub-batch import).
--
-- NOTE: nelt_world.waypoint_data has no `move_type` column (older/different
-- schema than acore_world's -- confirmed live: "Unknown column 'move_type'
-- in field list"). Dropped from the copy; the target row keeps its column
-- default (0 = walk), correct for a normal ground patrol path anyway.
-- =====================================================================

DELETE FROM `waypoint_data` WHERE `id` IN (9490260,9244515);
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`)
    SELECT `id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`
    FROM `nelt_world`.`waypoint_data`
    WHERE `id` IN (9490260,9244515);
