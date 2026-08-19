-- 72_flight_masters.sql — map 751 Lordaeron extension, DB step 11.
--
-- Binds the 19 new flight masters to DC's gossip-based taxi. The DBC half (19 new
-- TaxiNodes + the full path mesh) is already generated and deployed by
-- `Custom/Documentation/scripts/gen_taxi.py`; this is the server-side half.
--
-- TWO THINGS, and the second one is the non-obvious one.
--
-- 1. ScriptName = 'npc_dc_downport_flightmaster'. DC does not use the stock taxi
--    map on custom continents (it is blank there), so the flight master hands out
--    destinations through gossip and flies via ActivateTaxiPathTo.
--
-- 2. **npcflag must have bit 0x1 (GOSSIP) set as well as 0x2000 (FLIGHTMASTER).**
--    A "pure" flight master (0x2000 with no gossip bit) makes the CLIENT send the
--    taxi-map query instead of gossip-hello — so the CreatureScript never fires and
--    the player gets the empty custom-continent flight map — the symptom players
--    report as "the flight master isn't replying".
--    This exact bug bit the first Plaguelands import.
--    Measured on the live data before writing this - 32 flight masters on map 751:
--        8193  x18   gossip bit present, script bound
--        8195  x7    gossip bit present, script bound
--        8192  x7    NO gossip bit, NO script   <-- the broken ones
--    So 7 need the flag fix, not all 19 new ones: the Cata import brought several
--    across already carrying a gossip bit. The UPDATEs below are written as
--    'fix whatever is missing' rather than 'set all 19', so that distinction does
--    not change the statements - only the expected row counts.
--
-- Scoped by spawn map + npcflag, so it can never touch a flight master on another
-- map. Idempotent.
--
-- NOTE the node ids stay under the 448 ceiling (TaxiMaskSize = 14 uint32,
-- DBCStructure.h:2248). That ceiling only actually constrains the STOCK taxi UI —
-- `ActivateTaxiPathTo` has no mask check — but the 19 fitted in the free pool, so
-- there was no need to find out how the client copes with ids above it.
-- 20 free ids remain for future use.

-- ---------------------------------------------------------------------------
-- 1. Gossip bit — without this the script is never invoked
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
SET t.`npcflag` = t.`npcflag` | 1
WHERE (t.`npcflag` & 8192) > 0
  AND (t.`npcflag` & 1) = 0
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = t.`entry` AND c.`map` = 751);

-- ---------------------------------------------------------------------------
-- 2. Bind the gossip flight master script
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
SET t.`ScriptName` = 'npc_dc_downport_flightmaster'
WHERE (t.`npcflag` & 8192) > 0
  AND t.`ScriptName` = ''
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = t.`entry` AND c.`map` = 751);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT c.`zoneId`, COUNT(DISTINCT c.`id`) AS flight_masters,
       SUM(DISTINCT (t.`npcflag` & 1) > 0) AS have_gossip_bit
FROM `creature` c
JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0
GROUP BY c.`zoneId` ORDER BY c.`zoneId`;

SELECT 'flight masters on map 751'  AS what, COUNT(DISTINCT c.`id`) AS n
  FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
  WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0
UNION ALL SELECT '  with the gossip bit', COUNT(DISTINCT c.`id`)
  FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
  WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0 AND (t.`npcflag` & 1) > 0
UNION ALL SELECT '  bound to the gossip script', COUNT(DISTINCT c.`id`)
  FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
  WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0
    AND t.`ScriptName` = 'npc_dc_downport_flightmaster';

-- must be zero: a flight master the client will try to open the taxi map for
SELECT 'PROBLEM: flight master without the gossip bit' AS problem, COUNT(DISTINCT c.`id`) AS n
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0 AND (t.`npcflag` & 1) = 0;

-- must be zero: a flight master with some OTHER script, which would preempt the
-- taxi gossip (FactorySelector resolves ScriptName before anything else)
SELECT 'flight master carrying a different ScriptName' AS note,
       t.`entry`, t.`name`, t.`ScriptName`
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0
  AND t.`ScriptName` <> '' AND t.`ScriptName` <> 'npc_dc_downport_flightmaster'
GROUP BY t.`entry`, t.`name`, t.`ScriptName`;

-- cross-check against the DBC: every map-751 taxi node should have a flight master
-- standing near it (and vice versa). 31 nodes / 32 flight masters is expected —
-- Acherus (node 428) is a DK-only point with no ordinary flight master.
SELECT 'taxi nodes on map 751 (from TaxiNodes.dbc)' AS note, 31 AS expected_nodes,
       (SELECT COUNT(DISTINCT c.`id`) FROM `creature` c
        JOIN `creature_template` t ON t.`entry` = c.`id`
        WHERE c.`map` = 751 AND (t.`npcflag` & 8192) > 0) AS flight_masters;
