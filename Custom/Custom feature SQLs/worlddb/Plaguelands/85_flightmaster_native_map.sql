-- 85_flightmaster_native_map.sql -- map 751 Lordaeron extension, DB step 24.
--
-- Switches map 751's flight masters from the DC gossip LIST to the native taxi MAP,
-- so they behave like map 750's.
--
-- WHY THEY DIFFERED
-- Nothing about the maps -- purely the ScriptName binding applied by 72_:
--   map 750: all 27 flight masters have ScriptName = ''  -> native taxi frame -> MAP
--   map 751: all 32 have 'npc_dc_downport_flightmaster'  -> gossip destination LIST
--
-- `npc_dc_downport_flightmaster` (src/server/scripts/DC/AC/dc_downport_taxi.cpp)
-- exists because a custom continent could not render the taxi map: it needs
-- WorldMapContinent bounds and a TaxiMap<mapId>.blp, and map 751 had neither. Both
-- now exist:
--   * WorldMapContinent id 10 carries map 751's taxi box, squared to 5333x5333 so
--     the pins are not distorted against a square image
--   * Interface\TaxiFrame\TaxiMap751.blp is deployed in patch-5 alongside 750's,
--     512x512 DXT1 with mips, byte-for-byte the same shape as TaxiMap750.blp
-- and the network itself was already complete: 31 TaxiNodes on map 751, 930 paths,
-- every one with TaxiPathNode rows.
--
-- Clearing ScriptName lets HandleTaxiQueryAvailableNodes / SendTaxiMenu run, which
-- is exactly the path map 750 takes.
--
-- REVERTING is one statement -- set the ScriptName back on those 32 entries -- so
-- if the native frame disappoints, the gossip list is still there. The C++ script is
-- intentionally left in the build for that reason.

-- ---------------------------------------------------------------------------
-- 1. Unbind the gossip-list script from every map-751 flight master
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
SET t.`ScriptName` = ''
WHERE t.`ScriptName` = 'npc_dc_downport_flightmaster'
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = t.`entry` AND c.`map` = 751);

-- ---------------------------------------------------------------------------
-- 2. Four of them would strand the player without this.
--
-- With the script gone, a flight master with NO gossip menu opens the taxi map on
-- right-click, and one WITH a menu needs a GOSSIP_OPTION_TAXIVENDOR (OptionType 4)
-- entry to reach it. 18 of the 22 menu-bearing ones already have that option; these
-- four have a menu carrying ZERO options -- greeting text only -- so they would show
-- a dead window.
--
--   3612636 Georgia              menu 12237
--   4102851 Urda                 menu 11684
--   4108018 Guthrum Thunderfist  menu 11885
--   4137915 Timothy Cunningham   menu 11152  (also a quest giver -- keep the menu)
--
-- Adding the option rather than clearing gossip_menu_id preserves their greetings
-- and Timothy's quests. Row shape and BroadcastTextID 3409 ("I need a ride.") are
-- copied from menu 4281, the flight-master menu already working on this map.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (12237, 11684, 11885, 11152) AND `OptionID` = 0;

INSERT INTO `gossip_menu_option`
  (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`,
   `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`,
   `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(12237, 0, 2, 'I need a ride.', 3409, 4, 8192, 0, 0, 0, 0, '', 0, 0),
(11684, 0, 2, 'I need a ride.', 3409, 4, 8192, 0, 0, 0, 0, '', 0, 0),
(11885, 0, 2, 'I need a ride.', 3409, 4, 8192, 0, 0, 0, 0, '', 0, 0),
(11152, 0, 2, 'I need a ride.', 3409, 4, 8192, 0, 0, 0, 0, '', 0, 0);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'map-751 flight masters still scripted (want 0)' AS what, COUNT(DISTINCT t.`entry`) AS n
FROM `creature_template` t JOIN `creature` c ON c.`id` = t.`entry`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192) AND t.`ScriptName` = 'npc_dc_downport_flightmaster'
UNION ALL SELECT 'map-751 flight masters total (want 32)', COUNT(DISTINCT t.`entry`)
FROM `creature_template` t JOIN `creature` c ON c.`id` = t.`entry`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192)
UNION ALL SELECT 'the 4 repaired menus now offer a ride (want 4)', COUNT(*)
FROM `gossip_menu_option` WHERE `MenuID` IN (12237, 11684, 11885, 11152) AND `OptionType` = 4
UNION ALL SELECT 'map-750 flight masters, untouched (want 27)', COUNT(DISTINCT t.`entry`)
FROM `creature_template` t JOIN `creature` c ON c.`id` = t.`entry`
WHERE c.`map` = 750 AND (t.`npcflag` & 8192) AND t.`ScriptName` = '';

-- must be empty: a map-751 flight master that can no longer sell a flight --
-- it has a gossip menu but no taxi option, so right-click would show a dead window
SELECT 'PROBLEM: flight master with no way to fly' AS problem, t.`entry`, t.`name`, t.`gossip_menu_id`
FROM `creature_template` t JOIN `creature` c ON c.`id` = t.`entry`
WHERE c.`map` = 751 AND (t.`npcflag` & 8192) AND t.`gossip_menu_id` <> 0
  AND NOT EXISTS (SELECT 1 FROM `gossip_menu_option` o
                  WHERE o.`MenuID` = t.`gossip_menu_id` AND o.`OptionType` = 4);
