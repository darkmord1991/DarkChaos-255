-- ---------------------------------------------------------------------------
-- 148  Map-750 areatrigger targets: Kalimdor leftovers + the dead Firelands portal
-- ---------------------------------------------------------------------------
-- `15_areatrigger.sql` cloned 61 Cata triggers as ID+600,000 and set their
-- client `AreaTrigger.csv` ContinentID to 750 -- but left `target_map` at the
-- Cata value of **1 (Kalimdor)**, because in 4.3.4 Mount Hyjal was a Kalimdor
-- zone. On this fork Hyjal is its own continent, so walking into any of these
-- six triggers **ejects the player onto Kalimdor** at Hyjal's coordinates.
--
-- The coordinates themselves are correct and need no change. Proof: the six
-- rows form three reciprocal entrance/exit pairs whose targets land on each
-- other's trigger positions, all inside map 750's spawn footprint
-- (X[3399,5770] Y[-4979,-1280]):
--
--   605880 Forgeworks (Enterance)  @ 5030.8,-2036.3,1378.1 -> 5029.5,-2029.4,1149.0
--   605879 Forgeworks (Exit)       @ 5042.2,-2026.5,1149.0 -> 5036.4,-2046.0,1368.4
--   605893 from Seat of the Prophets @ 4320.9,-3288.2,1036.1 -> 3948.6,-2818.2, 618.8
--   605895 from Sulfuron Spire     @ 3943.9,-2807.5, 618.7 -> 4316.1,-3282.5,1035.5
--   605931 Crucible (Enterance)    @ 4664.0,-3686.8, 956.6 -> 4679.1,-3675.5, 696.5
--   605937 Crucible (Exit)         @ 4678.1,-3682.8, 696.5 -> 4654.0,-3688.4, 955.3
--
-- The sibling `spell_target_position` rows (74948, 75667, 76162, 76405, 77662,
-- 77802, 77815) were already corrected to map 750 -- this was an isolated miss.
--
-- 🔴 CLIENT-SIDE COMPANION (required, or this fix changes nothing observable):
-- the same downport also shifted every cloned trigger's GEOMETRY. Cata's
-- AreaTrigger.dbc is 13 fields / recsize 52; WotLK's is 10 / 40, because Cata
-- inserts three extra fields at indices 5-7. The clone copied positionally, so
-- the real Radius (Cata idx 8) landed in Box_Height and Box_Length (idx 9) in
-- Box_Yaw, leaving Radius + Box_Length + Box_Width all zero -- a trigger with
-- **no volume, which can never fire**. 110 of the 112 rows in the 600,000 block
-- were in that state (stock WotLK has 3 such rows out of 1,256).
-- Repaired by `Custom/Documentation/scripts/fix_areatrigger_geometry.py`, which
-- re-reads Cata fields 8-12; `Custom/CSV DBC/AreaTrigger.csv` now yields 67
-- spheres + 43 boxes and 0 degenerate rows, and `Custom/DBCs/AreaTrigger.dbc`
-- was recompiled (0 ids lost/added, exactly 110 rows changed).
-- 607000/607001 (Karazhan Crypts) are hand-authored and deliberately untouched.
-- DEPLOY: pack AreaTrigger.dbc into BOTH patch-4.MPQ and enGB/patch-enGB-3.MPQ,
-- and copy to the Linux server's data/dbc/.
--
-- Also removed here: trigger 606864 and gameobject 3808900, which both lead to
-- the **Firelands raid (map 720)**. Map 720 is not registered in `Map.csv` and
-- has no server maps/vmaps/mmaps -- the raid was never downported. Today:
--   * 606864 is skipped every boot by `ObjectMgr::LoadAreaTriggerTeleports`
--     (ObjectMgr.cpp:7346-7350 rejects a target map missing from Map.dbc) and
--     logs "Area trigger (ID:606864) target map (ID: 720) does not exist".
--   * GO 3808900 "Portal to the Firelands" (type 22, Data0 = spell 99556) has
--     no `spell_target_position` row for 99556, so clicking it silently does
--     nothing.
-- Both are removed rather than repointed: there is nowhere valid to send the
-- player until Firelands is downported. The gameobject_template is kept so the
-- portal can simply be re-spawned if that happens.
-- ---------------------------------------------------------------------------

-- 1. The six Kalimdor leftovers -> map 750.
UPDATE `areatrigger_teleport`
SET `target_map` = 750
WHERE `ID` IN (605879, 605880, 605893, 605895, 605931, 605937)
  AND `target_map` = 1;

-- 2. Retire the two dead Firelands-raid entry points (map 720 does not exist).
DELETE FROM `areatrigger_teleport` WHERE `ID` = 606864;

DELETE FROM `gameobject` WHERE `id` = 3808900;
