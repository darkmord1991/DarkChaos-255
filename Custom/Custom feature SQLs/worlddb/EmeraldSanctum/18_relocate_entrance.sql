-- =====================================================================================
-- Emerald Sanctum -- move the world-side entrance out of Ashen Lake.
--
-- WHY
-- ---
-- The entrance sits at 4833.10 / -1731.70 on map 750, inside area 16482 "Ashen Lake".
-- Sampling the deployed ADT (DCMountHyjal_35_22, MCVT -> V9/V8 -> getHeightFromFloat, the
-- same maths the worldserver uses) gives ground 1196.21 there, and the MH2O instance
-- covering that chunk has a surface at 1253.44 -- so the gatekeeper post, the walk-in box
-- and the `.tele` target are all ~57 yd BELOW the lake surface. A 41x41 sample grid centred
-- on the old spot is 121/121 underwater; the nearest dry ground is 140 yd away.
--
-- The import comment claimed the spot was "~170 yd from Nordrassil". It is not: area 16543
-- Nordrassil is centred near 5450 / -3533, about 1900 yd south. The two NPCs the comment
-- cited (Malfurion 3652845, Hamuul 3639858) stand in the Sanctuary of Malorne / Grove of
-- Aessina camps, not at the World Tree.
--
-- THE NEW SPOT
-- ------------
-- Area 16498 "Grove of Aessina" -- the Cataclysm druid camp on the plateau east of Ashen
-- Lake, where Hamuul Runetotem, Mylune, Matoclaw and Avrilla already stand. Two reasons it
-- wins over every other dry candidate in the neighbourhood:
--
--   * There is already a doorway there. A single KALIDARMOONGATE.M2 -- the night-elf stone
--     arch -- stands at 5091.64 / -1767.09 / 1332.97 (yaw 10.3, scale 1.08), flanked by two
--     KALIDARSTONERUNE doodads. Nothing else in the region is arch-shaped.
--   * It is the flattest dry ground for 200 yd in any direction: 0.73 yd of relief over a
--     16 yd box, no liquid instance within 240 yd, and a continuous 1332-1336 walk from the
--     camp itself (11-point profile, no step over 1 yd).
--
-- The doodad's own placement Z (1332.97) and the terrain sampler (1332.969) agree to a
-- thousandth -- the same independent cross-check that validated the in-raid 30.10.
--
-- The gatekeeper keeps the 25-yd rule from _shared/dungeon_entrance_npcs.sql: he stands
-- 25.00 yd up the approach from the camp, facing the arch (o = 3.831), so walking down from
-- Hamuul you meet him before you reach the box. That was the 7.6-yd mistake that made the
-- Timbermaw gatekeeper unclickable.
--
-- ID NOTE
-- -------
-- This trigger is 6928, not the 607007 the import files used to name. The 3.3.5 client keeps
-- areatrigger ids in a 16-BIT table (0xFFFF = not found, Wow.exe VA 0x00831686), so the
-- original band crashed the client with ERROR #132 on map changes and instance teleports;
-- `_shared/renumber_areatrigger_ids.sql` moved the whole custom set into 6807-6930 and the
-- rebuilt AreaTrigger.dbc is already deployed. One pre-renumber orphan survived in
-- `areatrigger_teleport` -- above 65535, exactly the crash shape -- and is dropped below.
-- =====================================================================================

SET @GATE_X := 5110.93;
SET @GATE_Y := -1751.19;
SET @GATE_Z := 1334.10;
SET @GATE_O := 3.831;
-- the arch itself, where the walk-in box goes
SET @ARCH_X := 5091.64013671875;
SET @ARCH_Y := -1767.0899658203125;
SET @ARCH_Z := 1332.969970703125;

-- -------------------------------------------------------------------------------------
-- 1. The gatekeeper spawn. It is MISSING from the world DB entirely -- guid 16622006 is the
--    only one of the eight 1662200x rows that never landed -- so this is an INSERT, not a
--    move. Columns and spawnMask copy _shared/dungeon_entrance_npcs.sql.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` = 16622006;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
VALUES
    (16622006, 3999007, 750, 0, 0, 1, 1, 0,
     @GATE_X, @GATE_Y, @GATE_Z, @GATE_O, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
     'Emerald Sanctum Gatekeeper - Emerald Sanctum');

-- -------------------------------------------------------------------------------------
-- 2. The walk-in box. 6928 IS live and correctly wired -- definition row, teleport row and a
--    deployed DBC row all present. It is simply in the lake. Move the server's half into the
--    arch.
--
--    >>> THE CLIENT HALF IS NOT SQL. <<< AreaTrigger.dbc row 6928 still holds
--    750 / 4833.10 / -1756.70 / 1190.27 on both the live server dbc and the client's
--    patch-4. The client only sends CMSG_AREATRIGGER for the box IT knows about, so until
--    Custom/CSV DBC/AreaTrigger.csv row 6928 is re-compiled and pushed to patch-4, the
--    trigger keeps firing in the lake and this row does nothing. Until then the gatekeeper
--    is the entrance -- which is how Timbermaw has always worked.
-- -------------------------------------------------------------------------------------
UPDATE `areatrigger`
   SET `x` = @ARCH_X, `y` = @ARCH_Y, `z` = @ARCH_Z
 WHERE `entry` = 6928;

-- The pre-renumber orphan: its definition was renumbered to 6928 and this row was left
-- behind, so it is a teleport with no box AND an id above the client's 16-bit ceiling.
DELETE FROM `areatrigger_teleport` WHERE `ID` = 607007;

-- -------------------------------------------------------------------------------------
-- 3. The way out. The Warden's two travel rows (SMART_ACTION_TELEPORT, ids 1 and 3) still
--    drop players into the lake bed. Same destination as the gatekeeper's post, so the exit
--    lands you exactly where you walked in.
-- -------------------------------------------------------------------------------------
UPDATE `smart_scripts`
   SET `target_x` = @GATE_X, `target_y` = @GATE_Y, `target_z` = @GATE_Z, `target_o` = @GATE_O
 WHERE `source_type` = 0 AND `entryorguid` = 3999008 AND `action_type` = 62 AND `action_param1` = 750;

-- -------------------------------------------------------------------------------------
-- 4. `.tele dcemeraldsanctumgate`.
-- -------------------------------------------------------------------------------------
UPDATE `game_tele`
   SET `position_x` = @GATE_X, `position_y` = @GATE_Y, `position_z` = @GATE_Z, `orientation` = @GATE_O
 WHERE `id` = 10648;

-- -------------------------------------------------------------------------------------
-- 5. `dc_dungeon_entrances`. Not cosmetic: dc_mythicplus_portal_selector.cpp reads this
--    row and calls Player::TeleportTo with it verbatim (plus GetDungeonZOffset, which has
--    no case for 824), so a seasonal portal to the Sanctum would put the group in the lake.
--    Latent today only because dc_dungeon_setup.mythic_plus_enabled = 0 for this map -- it
--    is a 20-man raid -- and the portal list is filtered on that flag. Fix it anyway; this
--    is the canonical "where is the world-side door" record and other things read it.
-- -------------------------------------------------------------------------------------
UPDATE `dc_dungeon_entrances`
   SET `entrance_x` = @GATE_X, `entrance_y` = @GATE_Y, `entrance_z` = @GATE_Z, `entrance_o` = @GATE_O
 WHERE `dungeon_map` = 824;

-- -------------------------------------------------------------------------------------
-- 6. Report
-- -------------------------------------------------------------------------------------
SELECT 'gatekeeper spawned (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `guid` = 16622006
UNION ALL SELECT 'areatrigger 6928 moved to the arch (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` = 6928 AND ROUND(`x`, 1) = 5091.6
UNION ALL SELECT 'warden exit rows moved (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3999008
      AND `action_type` = 62 AND ROUND(`target_x`, 1) = 5110.9
UNION ALL SELECT 'game_tele moved (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `game_tele` WHERE `id` = 10648 AND ROUND(`position_x`, 1) = 5110.9
UNION ALL SELECT 'areatrigger ids above the client 16-bit cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` > 65535
UNION ALL SELECT 'areatrigger_teleport ids above the cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` > 65535
UNION ALL SELECT 'dc_dungeon_entrances moved (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 824 AND ROUND(`entrance_x`, 1) = 5110.9
-- 6924 "Timbermaw Hold (Exit)" is a KNOWN, deliberate orphan: its box sits on the old
-- below-the-floor arrival estimate, so _shared/dungeon_areatrigger_definitions.sql leaves
-- it undefined on purpose. Expect 1 here, not 0, until that exit is re-measured in game.
UNION ALL SELECT 'teleports with no definition (want 1 - Timbermaw exit)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` t LEFT JOIN `areatrigger` a ON a.`entry` = t.`ID`
    WHERE a.`entry` IS NULL;
