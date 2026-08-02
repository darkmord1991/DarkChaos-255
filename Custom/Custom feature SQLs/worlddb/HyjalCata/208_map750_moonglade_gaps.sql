-- ---------------------------------------------------------------------------
-- 208  Map 750 -- the real Moonglade gaps (20 creatures, 3 objects)
-- ---------------------------------------------------------------------------
-- Moonglade was reported as feeling empty. It is very nearly complete: 286 of
-- its 289 creatures and all 157 of its gameobjects are cloned from our own
-- map 1 at byte-identical positions, and the whole Nighthaven roster is there
-- (Keeper Remulos, Rabine Saturna, the trainers, flight masters, Timbermaw,
-- the Clintar Dreamwalker chain).
--
-- MOST OF THE APPARENT GAP IS NOT A GAP. Of everything stock Kalimdor has in
-- Moonglade that map 750 does not, 51 of 71 creature spawns and 329 of 332
-- gameobjects are `game_event`-gated Lunar Festival content -- revelers,
-- fireworks, lanterns, banners, streamers. Those are invisible on stock
-- Kalimdor too outside the festival, so they are deliberately NOT ported here.
-- Moonglade is also a sanctuary zone with no hostile mobs and 178 of its 289
-- creatures are critters, so it is genuinely quiet by design.
--
-- TWO BANDS, NOT ONE -- the thing that makes this zone easy to misread.
-- Moonglade's CREATURES use entry + 3,700,000 but its GAMEOBJECTS use
-- entry + 3,900,000 (4085494 = Emerald Dream Flower 185494 + 3.9M,
-- 4095219 = Mailbox 195219 + 3.9M). Checking gameobjects against +3,700,000
-- reports 88 phantom "missing" objects that are all actually present.
--
-- WHAT IS ACTUALLY MISSING, and why:
--   * 2 objects genuinely absent inside the map -- Deadwood Cauldron (a
--     Timbermaw reputation quest object) and one Mountain Silversage node.
--   * 20 spawns that sit EAST of x = 8000, which is off the edge of the
--     world. The deployed DCMountHyjal.wdt (read out of patch-4.MPQ) declares
--     108 tiles covering x 3200-8000 and y -5333..+1067. The recent terrain
--     extension is live and is included in that -- but it extended the map
--     along +Y, adding the Darkshore sea edge (tile row 30 now exists where
--     the old build started at 33). The EASTERN boundary never moved: tiles at
--     column 16 (x 8000-8533) have never existed, in either build, and are not
--     in the deployed archive.
--
-- So these NPCs were not dropped by mistake -- the import correctly clipped to
-- the map footprint. They are nudged just inside the edge instead, to x = 7995
-- (a 5y margin): the largest move is 81y for a deer, 73y for Great Bear Spirit,
-- and the rest are under 40y, because they were already standing on the
-- boundary. Every relocated z is RE-MEASURED from the ADT heightmap using the
-- same arithmetic the worldserver uses, not carried over from map 1, so they
-- stand on the ground rather than in it -- several would otherwise have been
-- buried by up to 26y where the lakeshore drops away.
--
-- This matters beyond decoration: Bessany Plainswind and Dendrite Starblaze are
-- druid trainers, and GREAT BEAR SPIRIT is the Dire Bear Form quest giver --
-- without this that quest has no giver anywhere on map 750.
--
--   Rabbit                 guid 16000001 x  8021.20 ->  7995.00   z   496.16 ->   488.98  (measured)
--   Rabbit                 guid 16000002 x  8010.92 ->  7995.00   z   492.23 ->   490.09  (measured)
--   Rabbit                 guid 16000003 x  8011.76 ->  7995.00   z   506.44 ->   509.49  (measured)
--   Rabbit                 guid 16000004 x  8029.03 ->  7995.00   z   510.37 ->   489.37  (measured)
--   Rabbit                 guid 16000005 x  8011.95 ->  7995.00   z   493.23 ->   489.06  (measured)
--   Deer                   guid 16000006 x  8047.73 ->  7995.00   z   498.52 ->   488.75  (measured)
--   Deer                   guid 16000007 x  8010.76 ->  7995.00   z   512.28 ->   510.66  (measured)
--   Deer                   guid 16000008 x  8075.92 ->  7995.00   z   515.60 ->   489.67  (measured)
--   Squirrel               guid 16000009 x  8000.31 ->  7995.00   z   490.69 ->   488.24  (measured)
--   Squirrel               guid 16000010 x  8060.94 ->  7995.00   z   518.94 ->   500.51  (measured)
--   Squirrel               guid 16000011 x  8000.02 ->  7995.00   z   490.96 ->   489.06  (measured)
--   Squirrel               guid 16000012 x  8013.17 ->  7995.00   z   499.91 ->   492.62  (measured)
--   Squirrel               guid 16000013 x  8025.18 ->  7995.00   z   512.11 ->   513.73  (measured)
--   Squirrel               guid 16000014 x  8003.29 ->  7995.00   z   491.99 ->   488.92  (measured)
--   Bessany Plainswind     guid 16000015 x  8002.22 ->  7995.00   z   491.95 ->   489.87  (measured)
--   Dendrite Starblaze     guid 16000016 x  8020.00 ->  7995.00   z   524.53 ->   512.10  (measured)
--   Moonglade Warden       guid 16000017 x  8008.61 ->  7995.00   z   512.18 ->   512.10  (measured)
--   Moonglade Warden       guid 16000018 x  8031.08 ->  7995.00   z   512.21 ->   519.61  (measured)
--   Great Bear Spirit      guid 16000019 x  8068.29 ->  7995.00   z   497.07 ->   488.48  (measured)
--   Kharedon               guid 16000020 x  8030.57 ->  7995.00   z   515.14 ->   511.97  (measured)
--   Deadwood Cauldron      guid 16000001 x  6909.33 ->  6909.33   z   570.55 ->   570.55  (kept)
--   Mailbox                guid 16000002 x  8008.74 ->  7995.00   z   512.06 ->   512.10  (measured)
--   Mountain Silversage    guid 16000003 x  6950.70 ->  6950.70   z   604.19 ->   604.19  (kept)
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Templates
-- ---------------------------------------------------------------------------
-- Cloned via a temporary table rather than an explicit column list, so this
-- cannot break when the fork's schema drifts (it has: creature_template here
-- dropped scale/trainer_*/mechanic and added CreatureImmunitiesId).
-- Mountain Silversage (4076640) already has its template -- only its spawn was
-- missing -- so only the two genuinely absent ones are created.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3711796, 3711802, 3711956, 3712023);
DELETE FROM `creature_template`       WHERE `entry`      IN (3711796, 3711802, 3711956, 3712023);

DROP TEMPORARY TABLE IF EXISTS `tmp_208_ct`;
CREATE TEMPORARY TABLE `tmp_208_ct` LIKE `creature_template`;
INSERT INTO `tmp_208_ct` SELECT * FROM `creature_template` WHERE `entry` IN (11796, 11802, 11956, 12023);
UPDATE `tmp_208_ct` SET `entry` = `entry` + 3700000;
INSERT INTO `creature_template` SELECT * FROM `tmp_208_ct`;
DROP TEMPORARY TABLE `tmp_208_ct`;

DROP TEMPORARY TABLE IF EXISTS `tmp_208_ctm`;
CREATE TEMPORARY TABLE `tmp_208_ctm` LIKE `creature_template_model`;
INSERT INTO `tmp_208_ctm` SELECT * FROM `creature_template_model` WHERE `CreatureID` IN (11796, 11802, 11956, 12023);
UPDATE `tmp_208_ctm` SET `CreatureID` = `CreatureID` + 3700000;
INSERT INTO `creature_template_model` SELECT * FROM `tmp_208_ctm`;
DROP TEMPORARY TABLE `tmp_208_ctm`;

DELETE FROM `gameobject_template` WHERE `entry` IN (4076091, 4095218);

DROP TEMPORARY TABLE IF EXISTS `tmp_208_gt`;
CREATE TEMPORARY TABLE `tmp_208_gt` LIKE `gameobject_template`;
INSERT INTO `tmp_208_gt` SELECT * FROM `gameobject_template` WHERE `entry` IN (176091, 195218);
UPDATE `tmp_208_gt` SET `entry` = `entry` + 3900000;
INSERT INTO `gameobject_template` SELECT * FROM `tmp_208_gt`;
DROP TEMPORARY TABLE `tmp_208_gt`;

-- ---------------------------------------------------------------------------
-- B) Creature spawns
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 16000001 AND 16000020;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,
     `dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
VALUES
  (16000001, 3700721, 750, 0, 0, 1, 1, 0, 7995.0000, -2242.0200, 488.9800, 1.5542, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000002, 3700721, 750, 0, 0, 1, 1, 0, 7995.0000, -2556.8800, 490.0923, 5.5251, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000003, 3700721, 750, 0, 0, 1, 1, 0, 7995.0000, -2624.6900, 509.4854, 3.3164, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000004, 3700721, 750, 0, 0, 1, 1, 0, 7995.0000, -2208.5500, 489.3681, 5.4411, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000005, 3700721, 750, 0, 0, 1, 1, 0, 7995.0000, -2501.0200, 489.0575, 0.2967, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000006, 3700883, 750, 0, 0, 1, 1, 0, 7995.0000, -2301.3900, 488.7519, 0.7343, 300, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000007, 3700883, 750, 0, 0, 1, 1, 0, 7995.0000, -2695.9700, 510.6570, 2.5396, 300, 2, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000008, 3700883, 750, 0, 0, 1, 1, 0, 7995.0000, -2237.8900, 489.6670, 4.1745, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000009, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2276.8900, 488.2386, 3.4199, 300, 10, 0, 8, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000010, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2716.6700, 500.5058, 6.2829, 300, 10, 0, 8, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000011, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2500.9900, 489.0590, 3.2100, 300, 0, 0, 8, 0, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000012, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2595.3300, 492.6246, 5.5904, 300, 10, 0, 8, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000013, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2656.1800, 513.7281, 5.5764, 300, 10, 0, 8, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000014, 3701412, 750, 0, 0, 1, 1, 0, 7995.0000, -2504.5600, 488.9229, 1.3989, 300, 10, 0, 8, 0, 1, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000015, 3711796, 750, 0, 0, 1, 1, 0, 7995.0000, -2492.8500, 489.8743, 2.4917, 300, 0, 0, 3297, 2434, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000016, 3711802, 750, 0, 0, 1, 1, 0, 7995.0000, -2678.7400, 512.0994, 5.8818, 300, 0, 0, 3297, 2434, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000017, 3711822, 750, 0, 0, 1, 1, 1, 7995.0000, -2667.1900, 512.0994, 2.6878, 300, 0, 0, 1, 2790, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000018, 3711822, 750, 0, 0, 1, 1, 1, 7995.0000, -2646.0100, 519.6118, 3.2289, 300, 0, 0, 1, 2790, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000019, 3711956, 750, 0, 0, 1, 1, 0, 7995.0000, -2284.1200, 488.4781, 1.0958, 300, 0, 0, 9431, 0, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208'),
  (16000020, 3712023, 750, 0, 0, 1, 1, 0, 7995.0000, -2687.7800, 511.9725, 0.6283, 300, 0, 0, 2980, 0, 0, 0, 0, 0, '', 0, 0, 'Moonglade-208');

-- ---------------------------------------------------------------------------
-- C) Gameobject spawns
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 16000001 AND 16000003;

INSERT INTO `gameobject`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
     `position_x`,`position_y`,`position_z`,`orientation`,
     `rotation0`,`rotation1`,`rotation2`,`rotation3`,
     `spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
  (16000001, 4076091, 750, 0, 0, 1, 1, 6909.3300, -1820.1200, 570.5500, 1.4661, 0.0000, 0.0000, 0.6691, 0.7431, 120, 255, 1, '', 0, 'Moonglade-208'),
  (16000002, 4095218, 750, 0, 0, 1, 1, 7995.0000, -2668.0500, 512.0994, 2.7576, 0.0000, 0.0000, 0.9816, 0.1908, 120, 255, 1, '', 0, 'Moonglade-208'),
  (16000003, 4076640, 750, 0, 0, 1, 1, 6950.7000, -2005.2800, 604.1900, 3.9444, 0.0000, 0.0000, -0.9205, 0.3907, 900, 255, 1, '', 0, 'Moonglade-208');

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM creature   WHERE guid BETWEEN 16000001 AND 16000020;  -- 20
--   SELECT COUNT(*) FROM gameobject WHERE guid BETWEEN 16000001 AND 16000003;  -- 3
--   SELECT COUNT(*) FROM creature_template WHERE entry IN
--     (3711796,3711802,3711956,3712023);                                       -- 4
--
--   -- nothing landed back outside the map (expect 0):
--   SELECT COUNT(*) FROM creature WHERE map=750 AND position_x > 8000;
--   SELECT COUNT(*) FROM gameobject WHERE map=750 AND position_x > 8000;
--
-- Errors.log should gain no "has no model defined in table
-- `creature_template_model`" lines for 3711796/3711802/3711956/3712023.
--
-- In game: the eastern lakeshore of Nighthaven gets its wildlife back, the two
-- druid trainers and Kharedon stand at the water's edge, Great Bear Spirit is
-- reachable again for Dire Bear Form, and there is a second mailbox. Deadwood
-- Cauldron reappears on the Timbermaw side at (6909, -1820).
--
-- STILL NOT PORTED, on purpose: the Lunar Festival layer (51 creature spawns,
-- 329 objects). If you ever want Moonglade dressed for the festival, that is a
-- separate job -- it needs the `game_event` rows too, not just the spawns.
-- ---------------------------------------------------------------------------
