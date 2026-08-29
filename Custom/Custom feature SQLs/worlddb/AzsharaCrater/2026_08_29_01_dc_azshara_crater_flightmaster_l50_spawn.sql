-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- spawn the missing Level 50+ flight master
-- ---------------------------------------------------------------------------
-- Companion to the new native taxi map (WorldMapContinent id 11 +
-- Interface\TaxiFrame\TaxiMap37.blp). The crater has FIVE taxi nodes:
--
--   441 Startcamp   -> 800010  spawned (guid 9001599)
--   442 Level 30+   -> 800012  spawned (guid 9001432)
--   443 Level 50+   -> 800013  NOT SPAWNED ANYWHERE  <-- this file
--   444 Level 65+   -> 800014  spawned (guid 16469125)
--   445 Level 70+   -> 800015  spawned (guid 9000786)
--
-- The camp itself exists -- an Azshara Bruiser pair, a Services NPC and a Spirit
-- Healer stand within 42 yd of node 443 -- only the flight master was never
-- placed. Today the gossip list already flies players TO the node, so they land
-- with no way to fly out; once the taxi map is live the node becomes a visible,
-- clickable destination for everyone, which makes the gap worse rather than new.
--
-- Position: 3.6 yd from the DBC node (the other four sit 0.8-3.7 yd from theirs,
-- and ObjectMgr::GetNearestTaxiNode just takes the closest node on the map, so
-- exactness is not required). Z is taken from the camp's own ground level --
-- neighbouring spawns read 279.0 / 279.5 / 279.8 / 280.4 within 42 yd, i.e. flat
-- ground at ~279.8 -- NOT from the node's own Z of 282.58, which sits ~3 yd above
-- the terrain the way taxi nodes usually do.
--
-- guid 9002100: an empty band immediately after the crater's other flight masters
-- (9000786 / 9001432 / 9001599). Never let this row take an AUTO_INCREMENT guid.
--
-- FIRST ATTEMPT USED 16800001 AND REFUSED TO BOOT -- "Creature spawn id overflow!!
-- ... TCE00007", thrown the moment the Outdoor PvP system asked for a spawn id.
-- "That block is empty" is NOT a sufficient check: ObjectMgr::SetHighestGuids()
-- seeds _creatureSpawnId from MAX(creature.guid), and GenerateCreatureSpawnId()
-- refuses at >= 0xFFFFFF = 16,777,215. A SINGLE row above that bricks startup.
-- 16800001 was empty and free -- and 22,786 over the ceiling.
-- The live high-water mark is 16751007, i.e. ~26k of headroom left in total, so a
-- new spawn belongs in a low gap like this one rather than at the top of the range.
-- If the bad row was already applied: DELETE FROM `creature` WHERE `guid` = 16800001;
--
-- creature_template 800013 already carries npcflag 8193 (GOSSIP|FLIGHTMASTER),
-- gossip_menu_id 0 and ScriptName 'acflightmaster50', so nothing else is needed:
-- the C++ script is registered and handles this entry already.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` IN (9002100, 16800001);
DELETE FROM `creature` WHERE `id` = 800013 AND `map` = 37;
INSERT INTO `creature`
  (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
   `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
   `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
   `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
  (9002100, 800013, 37, 0, 0, 1, 1, 0,
   624.0, 124.0, 279.8, 3.5, 300,
   0, 0, 70082, 0, 0,
   0, 0, 0, '', NULL);
