-- ---------------------------------------------------------------------------
-- 263  Map 750 -- place 56 of the 70 spawns 259_'s objective clones need
-- ---------------------------------------------------------------------------
-- 259_ created the 17 templates and repointed the objectives, which silenced
-- the boot log, and said plainly that eight of them still had nothing to kill
-- until a spawn round ran. This is that round.
--
-- COORDINATES TRANSFER 1:1 AND THAT IS MEASURED, NOT ASSUMED. Every one of the
-- eight already-live spawns of 3636843 Runestone Bunny sits at distance 0.000
-- from a nelt_world source position for raw 36843 (control: 1224 yd against a
-- different entry's spawns). Map 750 keeps the Kalimdor coordinate frame for
-- this content, so only the entry is offset.
--
-- 14 OF THE 70 ARE DELIBERATELY NOT PLACED. The gate was: for each source
-- spawn, how far is the nearest EXISTING map-750 creature, and does the local
-- map-750 ground height agree with the source's --
--
--   entry                          n   avg nearest 750   src Z   local 750 Z
--   3634494 Astranaar Sentinel    23        9.1 yd       109.5      121.7    place
--   3632856 Warsong Invader       10        9.7 yd       193.2      179.2    place
--   3634492 Astranaar Thrower      4       10.4 yd       108.6      120.9    place
--   3636822 Lord Kassarus          1       27.5 yd       107.5       86.3    place
--   3634603 Ashenvale Assassin    17       28.3 yd       101.4      105.4    place
--   3633374 Brutusk                1      141.4 yd        91.8       96.2    place
--   3636407 Bingham Gadgetspring   1       87.6 yd        21.2       94.9    HOLD
--   3640957 Warsong Stockpile     13      361.3 yd        31.7       (none)   HOLD
--
-- Warsong Stockpile is Stonetalon content and map 750 does not carry Stonetalon
-- terrain at (1400-1530, -390 to -550): there is no map-750 creature within
-- 279 yd of any of its 13 positions, and the nearest ones -- 350-450 yd out --
-- are Hyjal-band entries (3639254, 3603781, 3600883) sitting at Z 101-171
-- against the Stockpile's Z 24-46. Those neighbours also do NOT match their own
-- nelt source positions (off by 6-103 yd), which is the tell that this pocket
-- was re-terraformed rather than copied. Placing 13 crates 70+ yd under the
-- ground would look like a fix and be a bug, so quest 25622 "Burn, Baby, Burn!"
-- stays incomplete until someone places them in-game.
--
-- Bingham Gadgetspring is the same class, smaller: his quest siblings 3636384 /
-- 3636385 ARE live on 750 at Z 92.6 / 86.8 while their nelt sources sit at
-- Z 51 / 48.8, so that corner of Azshara was re-heighted by ~40 yd too. His
-- source Z of 21.2 cannot be trusted. Quest 14383 stays incomplete.
--
-- GUIDs: 16,600,000 + (source guid - 164,000), giving 16,600,285-16,614,473.
-- Deterministic, traceable back to the source spawn, and collision-free because
-- source guids are unique. The whole 16,600,000-16,615,000 range was verified
-- empty in `creature` AND `creature_addon` before allocation. The DELETE is
-- scoped to that block AND to map 750 AND to these six entries, so it can never
-- reach another zone's spawns -- the failure mode a bare range-DELETE caused
-- once before.
--
-- Requires 259_ (the templates) and 262_ (creature_model_info -- without a row
-- there the core rejects the spawn outright rather than just failing to draw
-- it).
SET @OFF := 3600000;
SET @GB := 16600000 - 164000;

-- ---- 1. equipment for the two entries that carry any ----------------------
-- nelt stores equipment_id as the old GLOBAL id (34603 / 36822). In this fork
-- `creature.equipment_id` is the per-creature `ID` sub-key of
-- creature_equip_template, so it must be 1 -- copying the source value across
-- would make GetEquipmentInfo fail and log "has equipment_id 34603 but no such
-- entry". The SELECT below therefore writes `IF(equipment_id > 0, 1, 0)`, not
-- the source number.
--
-- Ashenvale Assassin carries 21551 / 21551 / 5258 (dual daggers + a bow) and
-- Lord Kassarus a single ranged 31497. All three item ids already exist here.
DELETE FROM acore_world.`creature_equip_template` WHERE `CreatureID` IN (3634603,3636822);

INSERT INTO acore_world.`creature_equip_template` (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`) VALUES
(3634603,1,21551,21551,5258,0),
(3636822,1,0,0,31497,0);

-- ---- 2. the 56 spawns ------------------------------------------------------
-- zoneId/areaId are taken from the nearest existing map-750 spawn rather than
-- from the source: 4931 for the five Ashenvale/Winterspring entries and 4930
-- for Lord Kassarus in Azshara. spawndist -> wander_distance and MovementType
-- carry over unchanged, so the 23 Sentinels and 17 Assassins keep their random
-- wander (3 and 6 yd) instead of standing still.
DELETE FROM acore_world.`creature`
WHERE `guid` BETWEEN 16600000 AND 16615000 AND `map` = 750
  AND `id` IN (3632856,3633374,3634492,3634494,3634603,3636822);

INSERT INTO acore_world.`creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT n.guid + @GB, n.id + @OFF, 750,
       IF(n.id = 36822, 4930, 4931), IF(n.id = 36822, 4930, 4931),
       1, 1,
       IF(n.equipment_id > 0, 1, 0),
       n.position_x, n.position_y, n.position_z, n.orientation,
       n.spawntimesecs, n.spawndist, n.currentwaypoint, n.curhealth, n.curmana,
       n.MovementType, n.npcflag, n.unit_flags, n.dynamicflags,
       '', 0, 0,
       CONCAT('map750 objective spawn - src ', n.id, '.', n.guid)
FROM nelt_world.creature n
WHERE n.id IN (32856,33374,34492,34494,34603,36822);

-- Verify after apply:
--   * SELECT COUNT(*) FROM creature WHERE map=750
--       AND id IN (3632856,3633374,3634492,3634494,3634603,3636822)   -> 56
--   * SELECT id, COUNT(*) FROM creature WHERE map=750
--       AND id IN (3632856,3633374,3634492,3634494,3634603,3636822)
--     GROUP BY id  -> 10 / 1 / 4 / 23 / 17 / 1
--   * no "has equipment_id ... but no such entry" and no "has an invalid
--     creature_model_info" lines for these on next boot.
--   * Still open after this file, by design: quest 25622 (Warsong Stockpile
--     x13) and quest 14383 (Bingham Gadgetspring x1).
