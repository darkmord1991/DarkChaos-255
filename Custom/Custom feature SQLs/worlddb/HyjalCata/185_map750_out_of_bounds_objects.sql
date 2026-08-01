-- ---------------------------------------------------------------------------
-- 185  Map 750 -- gameobjects floating outside the map's footprint
-- ---------------------------------------------------------------------------
-- Reported: "flying spawns/objects" on map 750.
--
-- FOUND: 117 of the 3,780 gameobjects on map 750 sit at coordinates that belong
-- to COMPLETELY DIFFERENT Kalimdor zones -- x as low as -9,317 and z as low as
-- -272, i.e. southern Kalimdor (Un'Goro / Silithus / Tanaris / Feralas). Map 750
-- only covers x ~3,200-8,400, y ~-5,500..+1,400, so these have no terrain under
-- them at all: they hang in the void or sit far below the world.
--
-- Almost all of them are herb/mineral nodes tagged `PoolFix-Nel`:
--     PoolFix-Nel        198 objects, 111 out of bounds  (56%)
--     Hyjal-Nel          737 objects,   4 out of bounds
--     MoltenFront-Nel      2 objects,   2 out of bounds  (both)
--     (untagged)       2,842 objects,   0 out of bounds
-- Firebloom, Purple Lotus, Black Lotus, Mountain Silversage, Dreamfoil,
-- Sungrass, Golden Sansam -- a gathering-node pass that copied nodes from the
-- whole of Kalimdor onto this map without filtering to the map's own extent.
--
-- No CREATURE has this problem -- every one of the 7,472 creature spawns on map
-- 750 is inside the footprint. This is gameobjects only.
--
-- These are deleted rather than relocated: there is no correct position to move
-- them to. They are duplicates of nodes that already exist in their real zones
-- on maps 0/1, and the in-bounds part of the same PoolFix-Nel pass (87 objects)
-- is left untouched.
--
-- Bounds used are deliberately generous (a ~600-yard margin beyond the furthest
-- real content on each axis) so nothing legitimately near the new sea border is
-- caught. Every row this deletes is at minimum ~900 yards outside the map.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `gameobject`
WHERE `map` = 750
  AND (`position_x` < 3000 OR `position_x` > 8400
    OR `position_y` < -5500 OR `position_y` > 1400);

-- ---------------------------------------------------------------------------
-- Verification -- should return 0 both before the restart and after:
--   SELECT COUNT(*) FROM gameobject WHERE map=750
--     AND (position_x < 3000 OR position_x > 8400
--       OR position_y < -5500 OR position_y > 1400);
--
-- Sanity check that nothing real was lost -- these should still hold:
--   SELECT COUNT(*) FROM gameobject WHERE map=750;              -- 3780 -> 3663
--   SELECT Comment, COUNT(*) FROM gameobject WHERE map=750 GROUP BY Comment;
--     -- PoolFix-Nel 198 -> 87, Hyjal-Nel 737 -> 733,
--     -- MoltenFront-Nel 2 -> 0, untagged 2842 unchanged
--
-- NOTE this does NOT run 184_'s Darkshore objects into trouble: those land at
-- x 4158-8289 / y -1692..+1308, comfortably inside the bounds above. Apply
-- order does not matter.
-- ---------------------------------------------------------------------------
