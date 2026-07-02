-- =====================================================================
-- Plaguelands (map 751) -- 47  Flight master gossip wiring
-- ---------------------------------------------------------------------
-- Binds the gossip flight master CreatureScript
-- (src/server/scripts/DC/AC/dc_downport_taxi.cpp,
--  "npc_dc_downport_flightmaster") to every flight master on map 751.
--
-- The script lists the map's flight nodes (TaxiNodes/TaxiPath/TaxiPathNode.dbc,
-- ids 426-437) as gossip options and starts the flight with ActivateTaxiPathTo,
-- so it does not depend on the client rendering the taxi map for this custom
-- continent. ScriptName preempts the default taxi-map gossip; SmartAI on some
-- of these NPCs is unaffected (no gossip events).
--
-- Scoped by spawn map + FLIGHTMASTER npcflag (0x2000). Idempotent.
-- =====================================================================

UPDATE acore_world.creature_template ct
JOIN (SELECT DISTINCT `id` FROM acore_world.creature WHERE `map` = 751) s ON s.`id` = ct.`entry`
SET ct.`ScriptName` = 'npc_dc_downport_flightmaster'
WHERE (ct.`npcflag` & 8192);
