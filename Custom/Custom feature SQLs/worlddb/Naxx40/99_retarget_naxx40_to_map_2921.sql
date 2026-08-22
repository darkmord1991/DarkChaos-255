-- =====================================================================
-- mod-vanilla-naxxramas: retarget map 533 -> 2921 (SoD Naxxramas)
-- =====================================================================
-- RUN THIS **AFTER** the module's own SQL has been applied by the
-- worldserver updater (data/sql/db-world/base/naxx40*.sql).
--
-- The module ships map 533 in ~1,100 places, but a blind search/replace
-- of "533" corrupts the data: it also matches coordinates (-3533.4387)
-- and guid prefixes (5330450). These UPDATEs key on the module's own
-- reserved id ranges instead:
--     creature entries  351000 - 351092
--     creature guids    361000 - 362065  (+ 362100 - 362114; 352042 stays on map 329)
--     gameobject guids  5330300 - 5330508 (frozen runes)
--     gameobject entry  361001            (Naxx40 teleporter)
--
-- Every naxx40 spawn carries spawnMask = 4 (RAID_DIFFICULTY_10MAN_HEROIC),
-- so the 40-man occupies difficulty slot 2 and does not collide with the
-- WotLK 10/25 spawns that stay on map 533.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Creature spawns -> map 2921
-- ---------------------------------------------------------------------
UPDATE `creature` SET `map` = 2921
 WHERE `map` = 533 AND `guid` BETWEEN 361000 AND 362114;

-- guid 352042 is the "Naxx40 Strath Entrance Trigger" and lives INSIDE Stratholme
-- (map 329) - it is the in-instance NPC that ports you to the 40-man. It must NOT be
-- moved to 2921. The `map = 533` filter already makes this a no-op; kept only so the
-- id band above reads completely. Do not "fix" it by dropping the filter.
UPDATE `creature` SET `map` = 2921
 WHERE `map` = 533 AND `guid` = 352042;

-- ---------------------------------------------------------------------
-- 2. Gameobject spawns -> map 2921 (frozen runes)
-- ---------------------------------------------------------------------
UPDATE `gameobject` SET `map` = 2921
 WHERE `map` = 533 AND `guid` BETWEEN 5330300 AND 5330508;

-- ---------------------------------------------------------------------
-- 3. World-side entrance objects -> map 751 (DC Plaguelands)
--    The module places these in Eastern Plaguelands on map 0. Map 751 is
--    a coordinate-identical copy of map 0 for that zone, so the
--    positions carry over unchanged.
-- ---------------------------------------------------------------------
UPDATE `gameobject` SET `map` = 751 WHERE `map` = 0 AND `id` = 361001;
-- [DC skip stock-533] DISABLED: 181056 (Naxxramas transport) and 193166 (Meeting Stone) are
-- STOCK gameobject entries. The module's own DELETE/INSERT for them is disabled, so there is
-- nothing naxx40-owned to move here - this would relocate STOCK map-0 spawns onto map 751.
-- UPDATE `gameobject` SET `map` = 751 WHERE `map` = 0 AND `id` IN (181056, 193166);

-- ---------------------------------------------------------------------
-- 4. Instance template
--    Script renamed from 'instance_naxxramas' to 'instance_naxxramas_40'
--    so the module no longer silently replaces core's map-533 script.
--    parent = 751 so exits land on the DC Plaguelands continent.
-- ---------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 2921;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
(2921, 751, 'instance_naxxramas_40', 0);

-- ---------------------------------------------------------------------
-- 5. Renamed C++ script bindings
--    npc_tesla -> npc_tesla_40 and at_naxxramas_hub_portal ->
--    at_naxxramas_hub_portal_40, so core's map-533 versions survive.
--    NOTE: fill in the correct entry / areatrigger ids for the module's
--    own Tesla coil creature and hub portal before running -- verify
--    against the module's naxx40_creatures.sql (@CENTRY range).
-- ---------------------------------------------------------------------
-- UPDATE `creature_template`   SET `ScriptName` = 'npc_tesla_40'               WHERE `entry` = <naxx40 tesla entry>;
-- DELETE FROM `areatrigger_scripts` WHERE `entry` = <naxx40 hub portal AT id>;
-- INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES (<id>, 'at_naxxramas_hub_portal_40');

-- ---------------------------------------------------------------------
-- 6. Verification
-- ---------------------------------------------------------------------
-- SELECT map, spawnMask, COUNT(*) FROM creature   WHERE guid BETWEEN 361000 AND 362114 GROUP BY map, spawnMask;
-- SELECT map, spawnMask, COUNT(*) FROM gameobject WHERE guid BETWEEN 5330300 AND 5330508 GROUP BY map, spawnMask;
-- SELECT * FROM instance_template WHERE map IN (533, 2921);

-- ---------------------------------------------------------------------
-- 7. Map 2921 must be an INSTANCE_TYPE_RAID (2), not a party dungeon (1)
--    Server side this fork honours the map_dbc override table, so no
--    client DBC edit is needed for the WORLDSERVER. The CLIENT's own
--    Map.dbc row still needs InstanceType 1 -> 2 for the raid-difficulty
--    dropdown -- see Custom/CSV DBC/Map.csv.
-- ---------------------------------------------------------------------
-- VERIFY BEFORE RUNNING: `map_dbc` is loaded via LoadDBC(sMapStore, "Map.dbc", "map_dbc")
-- (DBCStores.cpp:336). It is proven to ADD rows that Map.dbc lacks -- the module
-- relies on exactly that for `mapdifficulty_dbc` (533/difficulty 2 is absent from
-- MapDifficulty.dbc). Whether it can OVERRIDE a row that already exists in Map.dbc
-- has not been confirmed, and 2921 does already exist there. If the override does
-- not take, edit `Custom/CSV DBC/Map.csv` instead -- the CLIENT needs
-- InstanceType 1 -> 2 on row 2921 regardless, for the raid-difficulty dropdown.
DELETE FROM `map_dbc` WHERE `ID` = 2921;
INSERT INTO `map_dbc`
  (`ID`, `Directory`, `InstanceType`, `Flags`, `PVP`,
   `MapName_Lang_enUS`, `MapName_Lang_Mask`, `AreaTableID`,
   `LoadingScreenID`, `CorpseMapID`, `ExpansionID`, `MaxPlayers`)
VALUES
  (2921, '2921', 2, 0, 0,
   'Naxxramas', 16712190, 16394,
   0, 751, 2, 40);

-- ---------------------------------------------------------------------
-- 8. Clone stock Naxxramas' gameobject layer onto map 2921
--    The module was written to SHARE map 533 with stock Naxx, relying on
--    the stock doors / gates / chests being present in difficulty 2 on
--    the same map (that is what the two `spawnMask` UPDATEs in the
--    module's naxx40.sql did -- they are commented out now, because they
--    mutate stock Naxxramas).
--    Moving the 40-man to its own map means map 2921 has NO doors at all
--    unless we clone them, and the instance script drives real GO entries
--    (e.g. GO_HEIGAN_EXIT_GATE_40 = 181496).
--    101 stock GOs on map 533 -> guid band 5340000+ (verified free).
-- ---------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 5340000 AND 5340200;
SET @g := 5339999;
INSERT INTO `gameobject`
  (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
   `position_x`, `position_y`, `position_z`, `orientation`,
   `rotation0`, `rotation1`, `rotation2`, `rotation3`,
   `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`)
SELECT @g := @g + 1, `id`, 2921, `zoneId`, `areaId`, 4, `phaseMask`,
       `position_x`, `position_y`, `position_z`, `orientation`,
       `rotation0`, `rotation1`, `rotation2`, `rotation3`,
       `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`,
       'naxx40 clone of stock map-533 gameobject'
  FROM `gameobject`
 WHERE `map` = 533
   AND `id` NOT IN (202278, 202277)   -- Orb of Naxxramas: does not exist in classic
 ORDER BY `guid`;

-- ---------------------------------------------------------------------
-- 9. Clone the two stock creatures the 40-man reuses
--    16980 Lich King (same entry in WotLK Naxx and Naxx40)
--    16082 Naxxramas Trigger (frogger)
--    guid band 362200+ (verified free)
-- ---------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 362200 AND 362299;
SET @c := 362199;
INSERT INTO `creature`
  (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
   `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
   `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
   `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT @c := @c + 1, `id`, 2921, `zoneId`, `areaId`, 4, `phaseMask`, `equipment_id`,
       `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
       `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
       `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`,
       'naxx40 clone of stock map-533 creature'
  FROM `creature`
 WHERE `map` = 533 AND `id` IN (16980, 16082)
 ORDER BY `guid`;

-- ---------------------------------------------------------------------
-- 10. Extra verification
-- ---------------------------------------------------------------------
-- SELECT map, spawnMask, COUNT(*) FROM gameobject WHERE map IN (533, 2921) GROUP BY map, spawnMask;
-- SELECT map, spawnMask, COUNT(*) FROM creature   WHERE map IN (533, 2921) GROUP BY map, spawnMask;
-- SELECT * FROM map_dbc WHERE ID = 2921;
-- SELECT * FROM mapdifficulty_dbc WHERE MapID = 2921;
-- SELECT COUNT(*) FROM dungeonencounter_dbc WHERE MapID = 2921;   -- expect 15

-- ---------------------------------------------------------------------
-- 11. Areatriggers for map 2921
--     `AreaTrigger.dbc` is keyed by ContinentID, so every one of Naxxramas'
--     24 internal triggers only fires on map 533. They were cloned onto
--     ContinentID 2921 as ids 6931-6954 (see Custom/CSV DBC/AreaTrigger.csv;
--     client keeps trigger ids in a 16-bit table, so stay under 65535).
--     Only these six carry server-side behaviour.
-- ---------------------------------------------------------------------
DELETE FROM `areatrigger_scripts` WHERE `entry` IN (6936, 6943, 6951, 6952, 6953, 6954);
INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES
(6936, 'at_thaddius_entrance'),         -- Thaddius encounter start (clone of 4113)
(6943, 'at_naxxramas_hub_portal_40'),  -- hub portal (clone of 4156); module copy renamed so core keeps 4156 on map 533
(6951, 'naxx_exit_trigger'),           -- wing exit (clone of 5196)
(6952, 'naxx_exit_trigger'),           -- wing exit (clone of 5197)
(6953, 'naxx_exit_trigger'),           -- wing exit (clone of 5198)
(6954, 'naxx_exit_trigger');           -- wing exit (clone of 5199)

-- `naxx_exit_trigger` returns false at RAID_DIFFICULTY_10MAN_HEROIC ("Naxx 40
-- cannot be exited via portals, as in Classic"), so these are inert in the
-- 40-man and exist only so the behaviour matches upstream.

-- ---------------------------------------------------------------------
-- 12. Tesla Coil (16218)
--     The module's Thaddius summons the STOCK entry 16218, and its npc_tesla
--     copy is byte-identical to core's apart from the class name. The copy was
--     renamed npc_tesla_40 so core's registration survives; rebinding 16218 to
--     it loses nothing, and GetNaxxramasAI now accepts BOTH instance script
--     names so the AI still attaches inside stock Naxxramas on map 533.
-- ---------------------------------------------------------------------
-- [DC skip stock-533] DISABLED: 16218 is a STOCK creature and core's `npc_tesla` owns it.
-- Rebinding it would change stock Naxxramas. Consequence: on map 2921 the Tesla Coils fall
-- back to the default AI. That AI only suppresses evade/aggro/damage on an immobile prop
-- (EnterEvadeMode/UpdateAI/JustEngagedWith empty, DamageTaken -> 0), so the visible effect is
-- a killable, evading coil during Thaddius. Fix properly in the clone pass by giving the
-- 40-man its own Tesla Coil entry and repointing NPC_TESLA_COIL in boss_thaddius_40.cpp.
-- UPDATE `creature_template` SET `ScriptName` = 'npc_tesla_40' WHERE `entry` = 16218;

-- ---------------------------------------------------------------------
-- 13. Verification
-- ---------------------------------------------------------------------
-- SELECT * FROM areatrigger_scripts WHERE entry BETWEEN 6931 AND 6954;
-- SELECT entry, ScriptName FROM creature_template WHERE entry = 16218;
