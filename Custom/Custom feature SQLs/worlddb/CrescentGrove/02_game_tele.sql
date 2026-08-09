-- Crescent Grove (map 823) -- `.tele dccrescentgrove` / `.tele dccrescentgrovegate`.
--
-- dccrescentgrove     = GM shortcut to the arrival point inside the dungeon.
-- dccrescentgrovegate = the world-side entrance on map 750, Ashenvale above Mystral Lake.
--
-- Both Z values are COMPUTED from the deployed terrain, not estimated: the sampler runs the
-- worldserver's own MCVT -> V9/V8 -> getHeightFromFloat maths over the ADTs that were shipped,
-- and reproduces live map-750 spawn Z with a median error of 0.00. The in-dungeon point checks
-- out independently -- it computes to 276.92 where the source pack put its own walk-out
-- AreaTrigger at 275.9, i.e. the usual ~1 yd that trigger boxes are sunk by.
--
-- 10645/10646 are the next free ids (live max was 10644). The DELETE covers the NAMES as well
-- as the ids so a stale row from an earlier run cannot leave `.tele` ambiguous.
DELETE FROM `game_tele` WHERE `id` IN (10645, 10646)
   OR `name` IN ('dccrescentgrove', 'dccrescentgrovegate');
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10645, 585.6, 96.7, 276.92, 5.498, 823, 'dccrescentgrove'),
    (10646, 1707.48, -1289.88, 173.694, 2.356, 750, 'dccrescentgrovegate');
