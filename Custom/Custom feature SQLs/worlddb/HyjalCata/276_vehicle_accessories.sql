-- ---------------------------------------------------------------------------
-- 276  vehicle_template_accessory -- the riders 5 map-750 vehicles never got
-- ---------------------------------------------------------------------------
-- Found from "Krom'gar Wagon is missing some pieces". Nothing is missing from
-- the wagon: its model, skins and textures were all verified intact (see below).
-- What is missing is the **War Kodo team harnessed to it**, which in the source
-- is not part of the model at all -- it is a separate creature seated in the
-- vehicle via `vehicle_template_accessory`, and that table was never ported.
--
-- The clone band has **10** accessory rows against the source's 371. Same shape
-- as the `creature_addon` gap in 273_: a whole side table the zone importers
-- skipped, with no boot line to announce it, because an accessory that is never
-- declared is simply never summoned.
--
-- 🔴 WHY THE MODEL WAS NOT THE PROBLEM, so nobody re-chases it:
--   * `CREATURE\HORDECARAVAN\HORDECARAVANVEHICLE.M2` is in patch-G, MD20 v264,
--     10,966 verts / 31 bones / 9 anims / 4 views -- **identical counts to the
--     Cata 4.3.4 original** in art.MPQ (only the version byte differs, 272->264,
--     which is the downport). The bake dropped nothing.
--   * all 4 view .skin files present, every vertex index inside the M2's range,
--     no submesh overruns.
--   * all 4 textures resolve and every BLP is BLP2/DXT/hasMips=1 -- none hits
--     the hasMips=2 defect that turns surfaces green.
--   * VehicleId 837 exists in the real Vehicle.dbc (checked with read_server_dbc,
--     not the `vehicle_dbc` overlay, which only holds custom rows).
--
-- 5 of the 8 missing rows are imported here. **The other 3 are deliberately
-- skipped**: Fiona's Caravan Harness (3645416) wants accessories 3645434 /
-- 3645433 / 3645400 and none of those creature templates exist on our side, so
-- the rows would point at nothing. It also has 0 spawns, so nothing is lost.
-- Import them if that caravan is ever ported.
--
-- Seat/minion/summon values are copied from the source rather than invented --
-- `minion` decides whether the passenger despawns with the vehicle, and guessing
-- it wrong either leaks creatures or removes ones that should persist.
SET @OFF := 3600000;

DELETE FROM acore_world.`vehicle_template_accessory`
WHERE `entry` IN (3634160,3634132,3636665,3636852,3641744);

INSERT INTO acore_world.`vehicle_template_accessory`
(`entry`,`accessory_entry`,`seat_id`,`minion`,`description`,`summontype`,`summontimer`)
SELECT na.`entry` + @OFF, na.`accessory_entry` + @OFF, na.`seat_id`, na.`minion`,
       na.`description`, na.`summontype`, na.`summontimer`
FROM nelt_world.`vehicle_template_accessory` na
JOIN acore_world.`creature_template` v ON v.`entry` = na.`entry` + @OFF AND v.`VehicleId` > 0
JOIN acore_world.`creature_template` a ON a.`entry` = na.`accessory_entry` + @OFF
WHERE na.`entry` + @OFF IN (3634160,3634132,3636665,3636852,3641744);

-- What each one restores (spawn counts are live):
--   3634160 Watch Wind Rider          x27 <- 3634163 Hellscream's Hellion  seat 0
--   3634132 Astranaar Thrower         x12 <- 3606087 Astranaar Sentinel    seat 0
--   3636665 Warsong Assault WindRider  x8 <- 3636673 Azshara Bombardier    seat 0
--   3636852 Skychaser Hippogryph       x4 <- 3636850 Talrendis Skychaser   seat 0
--   3641744 Krom'gar Wagon             x1 <- 3640820 War Kodo              seat 1
-- 52 spawns in total, so the visible payoff is much wider than the one wagon:
-- the Ashenvale/Azshara wind riders and hippogryphs have all been flying
-- riderless for the same reason.
--
-- Verify after apply (needs a worldserver restart -- accessories are attached
-- at spawn):
--   SELECT entry, accessory_entry, seat_id FROM vehicle_template_accessory
--    WHERE entry IN (3634160,3634132,3636665,3636852,3641744);        -> 5 rows
--   in game: the Krom'gar Wagon has its kodo team again, and the wind riders
--   carry their gunners.
--
-- NOT done here: nelt gives the wagon `AIName='SmartAI'` with 3 rows that were
-- never ported (we hold 0). That is a separate behaviour gap, not a rendering
-- one -- the wagon is static either way -- so it is left for a SmartAI round
-- rather than bundled in silently.
