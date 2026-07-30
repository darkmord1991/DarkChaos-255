-- =====================================================================
-- Mount Hyjal (map 750) -- 175  Kalimdor-edge flight masters
-- ---------------------------------------------------------------------
-- PROBLEM
-- Map 750 is a coordinate-preserving copy of the Hyjal corner of Kalimdor, so
-- it also contains the surrounding Winterspring / Felwood / Azshara / Moonglade
-- flight points.  Those got their own taxi nodes (338, 339, 343, 344, 345, 446,
-- 447 in Custom/CSV DBC/TaxiNodes.csv) and a full path mesh to the five Hyjal
-- nodes (TaxiPath 9500-9651, all with real Cata waypoints) -- so, for example,
-- Everlook -> Nordrassil already exists as data and is deployed in both the
-- client and the server DBCs.
--
-- But the flight masters standing on those nodes could not deliver it: none of
-- them carried `npc_dc_downport_flightmaster`, so they fell back to the stock
-- taxi-map UI, which is exactly the path this project moved away from for the
-- custom continents.  Result: you can fly Hyjal -> Everlook today, but not back,
-- and none of the Kalimdor-edge nodes can be departed from.
--
-- WHY 60_ DID NOT ALREADY FIX IT (this is the important part)
-- `60_flightmaster_scripts.sql` binds the ScriptName template-wide, scoped by
-- "has a spawn on map 750 + FLIGHTMASTER npcflag".  Six of these seven NPCs are
-- STOCK KALIMDOR FLIGHT MASTERS that are spawned on BOTH map 1 and map 750 and
-- share ONE creature_template row:
--     8610  Kroum      (Valormok, Azshara)          Horde
--     10897 Sindrayl   (Moonglade)                  Alliance
--     11138 Maethrya   (Everlook, Winterspring)     Alliance
--     11139 Yugrek     (Everlook, Winterspring)     Horde
--     12578 Mishellena (Talonbranch Glade, Felwood) Alliance
--     12740 Faustron   (Moonglade)                  Horde
-- Running 60_'s template-level UPDATE over them would ALSO rewire the real
-- Azeroth flight masters on Kalimdor -- replacing the stock taxi map (with the
-- player's whole discovered network) with a gossip list of map-750 destinations.
-- That is a live-realm regression, so the template-level fix is NOT usable here.
--
-- FIX
-- Clone the six shared templates into the DC band (+3,600,000) and repoint only
-- the map-750 spawns at the clones.  The clones carry the ScriptName and the
-- GOSSIP npcflag; the stock templates are left completely untouched, so real
-- Kalimdor keeps its stock flight masters and its stock taxi map.
-- Gorrim (3722931, Emerald Sanctuary) is already a DC-only entry with no spawn
-- outside 750, so it is fixed in place -- no clone needed.
--
-- The clone keeps the stock defensive SmartAI ("on aggro summon an enraged
-- mount + say line 0"), so smart_scripts and creature_text are cloned too --
-- otherwise the cloned AIName='SmartAI' would log "has SmartAI enabled but no
-- SmartAI entries" and the Say action would have no text.
--
-- 🔴 REQUIRES A WORLDSERVER REBUILD.  src/server/scripts/DC/AC/dc_downport_taxi.cpp
-- was edited alongside this file: its hardcoded node table only listed 421-437,
-- so without the rebuild these flight masters would resolve their "current node"
-- as the nearest HYJAL node (Everlook would come out as Nordrassil, 1688 yards
-- away) and sell flights departing from the wrong place.  The same edit adds a
-- 100-yard sanity guard so a flight master that is not actually standing on a
-- node now offers nothing instead of impersonating a distant one.
-- Also requires a worldserver restart/respawn for the npcflag change to take on
-- already-spawned creatures.
--
-- Idempotent / re-runnable.  Uses temporary tables so it stays correct across
-- this fork's creature_template column drift (55 columns, no scale/trainer_*).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Clone the six shared stock templates into the DC band
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_dc_fm_template;
CREATE TEMPORARY TABLE tmp_dc_fm_template LIKE acore_world.`creature_template`;
INSERT INTO tmp_dc_fm_template
SELECT * FROM acore_world.`creature_template`
WHERE `entry` IN (8610,10897,11138,11139,12578,12740);

UPDATE tmp_dc_fm_template
SET `entry` = `entry` + 3600000,
    `ScriptName` = 'npc_dc_downport_flightmaster',
    -- GOSSIP bit (0x1): a pure flight master (0x2000 only) makes the CLIENT send
    -- the taxi-map query instead of gossip-hello, so the CreatureScript never
    -- fires and the blank custom-continent taxi map opens instead.
    `npcflag` = `npcflag` | 1;

DELETE FROM acore_world.`creature_template` WHERE `entry` IN (3608610,3610897,3611138,3611139,3612578,3612740);
INSERT INTO acore_world.`creature_template` SELECT * FROM tmp_dc_fm_template;
DROP TEMPORARY TABLE tmp_dc_fm_template;

-- ---------------------------------------------------------------------
-- 2. Clone the display models
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_dc_fm_model;
CREATE TEMPORARY TABLE tmp_dc_fm_model LIKE acore_world.`creature_template_model`;
INSERT INTO tmp_dc_fm_model
SELECT * FROM acore_world.`creature_template_model`
WHERE `CreatureID` IN (8610,10897,11138,11139,12578,12740);

UPDATE tmp_dc_fm_model SET `CreatureID` = `CreatureID` + 3600000;

DELETE FROM acore_world.`creature_template_model` WHERE `CreatureID` IN (3608610,3610897,3611138,3611139,3612578,3612740);
INSERT INTO acore_world.`creature_template_model` SELECT * FROM tmp_dc_fm_model;
DROP TEMPORARY TABLE tmp_dc_fm_model;

-- ---------------------------------------------------------------------
-- 3. Clone the defensive SmartAI + its text
--    (stock pattern: on aggro summon an enraged mount and say line 0)
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_dc_fm_smart;
CREATE TEMPORARY TABLE tmp_dc_fm_smart LIKE acore_world.`smart_scripts`;
INSERT INTO tmp_dc_fm_smart
SELECT * FROM acore_world.`smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` IN (8610,10897,11138,11139,12578,12740);

-- Only entryorguid is offset. action_param1 on these rows is the summoned
-- ENRAGED MOUNT (stock ids 9297/9527/...), which is not cloned and must stay raw.
UPDATE tmp_dc_fm_smart SET `entryorguid` = `entryorguid` + 3600000;

DELETE FROM acore_world.`smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` IN (3608610,3610897,3611138,3611139,3612578,3612740);
INSERT INTO acore_world.`smart_scripts` SELECT * FROM tmp_dc_fm_smart;
DROP TEMPORARY TABLE tmp_dc_fm_smart;

DROP TEMPORARY TABLE IF EXISTS tmp_dc_fm_text;
CREATE TEMPORARY TABLE tmp_dc_fm_text LIKE acore_world.`creature_text`;
INSERT INTO tmp_dc_fm_text
SELECT * FROM acore_world.`creature_text`
WHERE `CreatureID` IN (8610,10897,11138,11139,12578,12740);

UPDATE tmp_dc_fm_text SET `CreatureID` = `CreatureID` + 3600000;

DELETE FROM acore_world.`creature_text` WHERE `CreatureID` IN (3608610,3610897,3611138,3611139,3612578,3612740);
INSERT INTO acore_world.`creature_text` SELECT * FROM tmp_dc_fm_text;
DROP TEMPORARY TABLE tmp_dc_fm_text;

-- ---------------------------------------------------------------------
-- 4. Repoint ONLY the map-750 spawns at the clones
--    (the map-1 spawns keep the stock entry -- that is the whole point)
-- ---------------------------------------------------------------------
UPDATE acore_world.`creature`
SET `id` = `id` + 3600000
WHERE `map` = 750
  AND `id` IN (8610,10897,11138,11139,12578,12740)
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.`entry` = acore_world.`creature`.`id` + 3600000);

-- ---------------------------------------------------------------------
-- 5. Gorrim (Emerald Sanctuary) -- DC-only entry, fix in place
-- ---------------------------------------------------------------------
UPDATE acore_world.`creature_template`
SET `ScriptName` = 'npc_dc_downport_flightmaster',
    `npcflag` = `npcflag` | 1
WHERE `entry` = 3722931
  AND (`npcflag` & 8192);

-- ---------------------------------------------------------------------
-- 6. Post-apply verification (run these by hand)
-- ---------------------------------------------------------------------
-- Expect 7 rows, every one ScriptName='npc_dc_downport_flightmaster' and
-- npcflag with both 0x2000 and 0x1 set:
--   SELECT c.guid, c.id, ct.name, ct.npcflag, ct.ScriptName
--     FROM acore_world.creature c JOIN acore_world.creature_template ct ON ct.entry = c.id
--    WHERE c.map = 750 AND (ct.npcflag & 8192);
--
-- Expect 0 rows -- proves real Kalimdor was NOT touched (stock entries must
-- still have an EMPTY ScriptName):
--   SELECT entry, name, ScriptName FROM acore_world.creature_template
--    WHERE entry IN (8610,10897,11138,11139,12578,12740) AND ScriptName <> '';
--
-- Expect 6 rows, all map 1 -- the stock spawns stayed behind:
--   SELECT id, map, COUNT(*) FROM acore_world.creature
--    WHERE id IN (8610,10897,11138,11139,12578,12740) GROUP BY id, map;
