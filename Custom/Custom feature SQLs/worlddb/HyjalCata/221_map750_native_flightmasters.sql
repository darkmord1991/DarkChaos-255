-- ---------------------------------------------------------------------------
-- 221  Map 750 -- put every flight master on the native taxi map
-- ---------------------------------------------------------------------------
-- Map 750's 27 flight masters were split across two UIs: 13 used the stock taxi
-- frame and 14 the gossip list from npc_dc_downport_flightmaster. That script
-- existed because the native taxi map could not work for a custom continent
-- without WorldMapContinent bounds -- which map 750 now has (row 9, widened this
-- round from the old Hyjal-only box to a square 800..9850 / -7500..1550 so all
-- 27 nodes fall inside it, paired with a rebuilt Interface\TaxiFrame\TaxiMap750).
-- With the map working, the gossip fallback is redundant, so everything moves to
-- the native frame.
--
-- WHICH UI THE CLIENT PICKS IS DECIDED BY THE GOSSIP FLAG, NOT THE ScriptName.
-- This is the part that makes a naive "just clear ScriptName" wrong:
--   * npcflag WITHOUT bit 1 (GOSSIP) -> the client sends
--     MSG_TAXI_QUERY_AVAILABLE_NODES itself and the taxi frame opens directly.
--     WorldSession::HandleGossipHelloOpcode never runs, so the ScriptName on
--     these is dead code (that is why Chyella Hushglade, npcflag 8192, showed
--     the native map even though she carried the script).
--   * npcflag WITH bit 1 -> the client sends CMSG_GOSSIP_HELLO. With the script
--     gone the core falls back to PrepareGossipMenu(gossip_menu_id), and the NPC
--     needs a menu holding an OptionType 4 (GOSSIP_OPTION_TAXIVENDOR) entry --
--     that option is what calls WorldSession::SendTaxiMenu.
--
-- gossip_menu_id = 0 IS NOT A PROBLEM, which is worth stating because it looks
-- like one: menu 0 is AzerothCore's DEFAULT menu, a table of generic options
-- each gated by OptionNpcFlag, and OptionID 2 is "I want to travel fast"
-- (OptionType 4, OptionNpcFlag 8192). PrepareGossipMenu filters those against
-- the creature's own npcflags, so any FLIGHTMASTER sitting on menu 0 is handed a
-- working taxi option for free. The eight map-750 flight masters that leaned on
-- the script (Althera, Dinorae, Elizil, Faustron, Fayran, Kroum 3608610,
-- Mishellena, Ranela) all sit on menu 0 and therefore need nothing beyond step 1.
--
-- Only a CUSTOM menu that overrides menu 0 without carrying a taxi option is
-- broken -- see step 2. Menu 6944 is the stock flight-master menu ("Show me
-- where I can fly.", OptionType 4, OptionNpcFlag 8192), already used by
-- Sindrayl, Yugrek, Maethrya and Kroum 3636728 here, so it is the repoint target.
--
-- NOT TOUCHED -- map 751 (Plaguelands) keeps the gossip script. WorldMapContinent
-- has NO row for 751, so the native taxi frame has no bounds there and cannot
-- render; its 12 flight masters must keep npc_dc_downport_flightmaster. The
-- script therefore stays registered and dc_downport_taxi.cpp keeps its 751 nodes.
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- 1. Drop the gossip script from the map-750 flight masters
-- ---------------------------------------------------------------------------
-- Scoped by "has a spawn on map 750 and none on 751" so the shared script cannot
-- be pulled out from under a Plaguelands flight master.
UPDATE `creature_template` SET `ScriptName` = ''
WHERE `ScriptName` = 'npc_dc_downport_flightmaster'
  AND `entry` IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) AS m750)
  AND `entry` NOT IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751) AS m751);


-- ---------------------------------------------------------------------------
-- 2. Give every GOSSIP-flagged map-750 flight master a working taxi option
-- ---------------------------------------------------------------------------
-- This hits exactly TWO NPCs, both of which are already broken today -- their
-- custom menu overrides the default menu 0 and then fails to offer a ride:
--   * Vhulgra (3612616), gossip_menu_id 10434 -- that menu has ZERO rows in
--     gossip_menu_option, so it renders as an empty window.
--   * Friz Groundspin (3637005), gossip_menu_id 10861 -- its single option is
--     OptionType 0 with OptionNpcFlag 0, i.e. plain chatter labelled "Show me
--     where I can fly." that never calls SendTaxiMenu.
--
-- The `NOT IN` deliberately leaves gossip_menu_id 0 alone: menu 0 contains an
-- OptionType 4 row, so 0 is a member of the taxi-menu set and is filtered out.
-- Hanah Southsong (12428) and Teldira Moonfeather (4301) are also left alone --
-- both already carry an OptionType 4 entry, and 12428 additionally holds two
-- quest-gated ride options that repointing would destroy.
UPDATE `creature_template` SET `gossip_menu_id` = 6944
WHERE `entry` IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) AS m750)
  AND (`npcflag` & 8192)
  AND (`npcflag` & 1)
  AND `gossip_menu_id` NOT IN (
        SELECT `MenuID` FROM (SELECT DISTINCT `MenuID` FROM `gossip_menu_option` WHERE `OptionType` = 4) AS taxi_menus);


-- ---------------------------------------------------------------------------
-- 3. Daelyshia (3604267) -- npcflag 8194 with no quests
-- ---------------------------------------------------------------------------
-- QUESTGIVER (2) | FLIGHTMASTER (8192), no GOSSIP bit. She has ZERO rows in
-- creature_queststarter and creature_questender, so the questgiver bit is a
-- leftover from the Cata import.
--
-- This is polish, not a repair -- she is not broken today. The questgiver bit
-- makes the client send gossip hello, and the default menu 0 then hands her the
-- "I want to travel fast" option, so flying works via one extra click. Dropping
-- the stray bit leaves plain 8192, which is what every other script-free flight
-- master here carries, and the client then opens the taxi frame directly with no
-- gossip window in between. Revert this statement alone if you would rather keep
-- the flag for future quests.
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~2 WHERE `entry` = 3604267;
