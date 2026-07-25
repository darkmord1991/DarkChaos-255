-- ---------------------------------------------------------------------------
-- 119  Hyjal round-14 -- the 5 flameward helper anchors (quest 25502)
-- ---------------------------------------------------------------------------
-- npc_activated_flameward (zone_mount_hyjal.cpp) picks WHICH of five Ashbearer
-- spawn rings to use by looking up the nearest "Wondi's Bunny - Flameward -
-- Summon Ashbearer Target" (3675029) and switching on that creature's low GUID:
--
--     NPC_FLAMEWARD_HELPER_GUID_1 = 3858933,  ... _5 = 3858934
--
-- Two things were wrong.  First, 3675029 has ZERO spawn rows in this DB, so
-- FindNearestCreature always fails, `_started` stays false and the flameward
-- event never runs at all -- quest 25502 "Prepping the Soil" cannot be
-- completed.  Second, those constants are nelt_world SPAWN GUIDs (258933-937)
-- with the creature-entry offset (+3,600,000) wrongly applied to them; DC
-- re-guids Hyjal spawns into its own blocks, so even with spawns present the
-- switch could never match.
--
-- This lays down the five anchors, in a fresh guid block (15,400,000+ -- free:
-- the pool backfill owns 15,000,000-15,099,999, Molten Front GOs 15,100,000+
-- and MF creatures 15,300,000+).  The guids are assigned in the SAME ORDER the
-- C++ constants expect, so the accompanying source change is a straight
-- five-line substitution:
--
--     _GUID_1 = 15400001   (nelt 258933, Ash ring 1  ~4376 / -2340)
--     _GUID_2 = 15400002   (nelt 258937, Ash ring 2  ~4718 / -2422)
--     _GUID_3 = 15400003   (nelt 258936, Ash ring 3  ~4696 / -2618)
--     _GUID_4 = 15400004   (nelt 258935, Ash ring 4  ~4591 / -2697)
--     _GUID_5 = 15400005   (nelt 258934, Ash ring 5  ~4366 / -2547)
--
-- Coordinates are nelt_world's verbatim (its map 1 Kalimdor holds the Cata
-- Hyjal geometry DC re-hosts on 750).  nelt phases these at phaseMask 16;
-- 3.3.5 has no Firelands campaign phasing here, so they go to phaseMask 1 --
-- the same convention the Molten Front curation uses.
-- REQUIRES the C++ constant change + a worldserver rebuild to take effect.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15400001 AND 15400005;

INSERT INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`) VALUES
(15400001,3675029,750,4923,4923,1,1,0,4367.25,-2331.87,1154.41,1.45764,300,0,0,1,0,0,0,0,0,'',0,0,'Hyjal-r14 flameward helper 1'),
(15400002,3675029,750,4923,4923,1,1,0,4702.42,-2405.51,1167.80,1.45764,300,0,0,1,0,0,0,0,0,'',0,0,'Hyjal-r14 flameward helper 2'),
(15400003,3675029,750,4923,4923,1,1,0,4691.40,-2649.06,1156.33,1.45764,300,0,0,1,0,0,0,0,0,'',0,0,'Hyjal-r14 flameward helper 3'),
(15400004,3675029,750,4923,4923,1,1,0,4606.80,-2705.43,1148.33,1.45764,300,0,0,1,0,0,0,0,0,'',0,0,'Hyjal-r14 flameward helper 4'),
(15400005,3675029,750,4923,4923,1,1,0,4385.72,-2555.91,1123.72,1.45764,300,0,0,1,0,0,0,0,0,'',0,0,'Hyjal-r14 flameward helper 5');
