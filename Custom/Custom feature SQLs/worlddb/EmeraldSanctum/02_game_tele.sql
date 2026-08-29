-- Emerald Sanctum (map 824) -- `.tele dcemeraldsanctum` / `.tele dcemeraldsanctumgate`.
--
-- dcemeraldsanctum     = GM shortcut to the arrival point inside the raid.
-- dcemeraldsanctumgate = the world-side entrance on map 750, in the Grove of Aessina.
--
-- The in-raid Z is the strongest number in this whole import: the sampler (worldserver's own
-- MCVT -> V9/V8 -> getHeightFromFloat maths, run over the shipped ADTs) computes 30.099 at
-- that x/y, and the source pack's own walk-out AreaTrigger sits at 30.1. Two independent
-- derivations agreeing to a thousandth.
--
-- The map-750 side is ours alone. Turtle's entrance is in map 1's VANILLA Hyjal, which map 750
-- does not have -- map 750's Hyjal is the CATA zone, rebuilt in place at the same coordinates
-- but with entirely different geometry. The gate spot is therefore chosen, not ported: the
-- same neighbourhood Turtle used, on ground that exists here, 170 yd from the Nordrassil
-- spawns (Malfurion 3652845 at 4534/-2079/1220, Hamuul 3639858 at 4774/-1919/1272).
--
-- 10647/10648 are the next free ids after Crescent Grove's 10645/10646.
DELETE FROM `game_tele` WHERE `id` IN (10647, 10648)
   OR `name` IN ('dcemeraldsanctum', 'dcemeraldsanctumgate');
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10647, 2767.4, 2959.0, 30.10, 0.785, 824, 'dcemeraldsanctum'),
    (10648, 5110.93, -1751.19, 1334.10, 3.831, 750, 'dcemeraldsanctumgate');
