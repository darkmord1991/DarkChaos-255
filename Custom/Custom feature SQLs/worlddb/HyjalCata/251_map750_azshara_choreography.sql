-- ---------------------------------------------------------------------------
-- 251  Azshara (map 750) -- Wings of Steel + Slinky Sharpshiv + Aynasha escort
-- ---------------------------------------------------------------------------
-- Wires up the C++ ported into
-- src/server/scripts/DC/MountHyjal/zone_azshara_cata.cpp:
--     npc_wings_of_steel_airplane -- the biplane flight to the runestone tower
--     npc_slinky_sharpshiv        -- quest 14464 "Lightning Strike Assassination"
--     npc_tower_scaling_seat      -- the six grapple-climb seat vehicles
-- and implements quest 13510 "Timely Arrival" (Sentinel Aynasha, Darkshore)
-- as pure SmartAI + waypoints -- no C++ for that one.
--
-- SOURCE IS `nelt_world`, NOT `cata_world` (same situation 191_ documented):
-- cata_world has NO creature_text for 36729/32964 and NO script_waypoint for
-- 32964. The Neltharion scripts read their own DB, so Slinky's 4 lines,
-- Aynasha's 4 lines and her 25-point escort route all live in nelt_world.
-- Coordinates are copied UNCHANGED -- map 750 preserves Kalimdor coordinates,
-- only creature entries are offset (+3,600,000 Azshara / +3,700,000 Darkshore).
--
-- DELIBERATE DEPARTURES, so nobody hunts for "missing" rows later:
--   * Aynasha's source escort (npc_sentinel_aynasha_escort) summons nothing;
--     the ambush design asked for here reuses the two hostile clones that
--     already besiege Lor'danel -- Horde Enforcer (3732859) and Shatterspear
--     Mystic (3734248) -- because the classic ambusher clones (3711713
--     Blackwood Tracker / 3711714 Marosh) do not exist in creature_template.
--   * waypoint 25's source waittime (40000) is dropped: the end-of-path
--     choreography runs from timed actionlist 373296400 instead, and the
--     escort quest credit comes from ESCORT_START's quest parameter the
--     moment the path ends.
--   * Slinky's greeting menu: the source client menu (13415 -> npc_text
--     15382) collides with a stock WotLK npc_text id, so the text is
--     re-homed at npc_text 915382 under menu 13415 (free here).
--
-- Fork traps honoured: ESCORT_START (53) takes the path id in action_param2
-- (param1 is forcedMovement); escort waypoints report via events 40/58 with
-- the path id in event_param2; JUMP_TO_POS (97) needs target 202 (random
-- point, range 0) because a plain position target resolves to no targets.
--
-- Apply against acore_world, then REBUILD worldserver (new C++ file).
-- Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) ScriptName bindings for the C++
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_slinky_sharpshiv' WHERE `entry` = 3636729 AND `ScriptName` = '';
UPDATE `creature_template` SET `ScriptName` = 'npc_wings_of_steel_airplane' WHERE `entry` = 3637139 AND `ScriptName` = '';
UPDATE `creature_template` SET `ScriptName` = 'npc_tower_scaling_seat'
 WHERE `entry` IN (3636716, 3636718, 3636720, 3636753, 3636754, 3636755) AND `ScriptName` = '';

-- ---------------------------------------------------------------------------
-- B) Slinky boarding click for the escape glide (the C++ only ever raises the
--    SPELLCLICK npcflag at "Hop on!", so the parked questgiver is unaffected)
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 3636729 AND `spell_id` = 46598;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(3636729, 46598, 1, 0);

-- ---------------------------------------------------------------------------
-- C) Slinky's greeting menu (source menu 13415; text re-homed at 915382)
-- ---------------------------------------------------------------------------
DELETE FROM `npc_text` WHERE `ID` = 915382;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES
(915382, 'Don''t give away our position, $n. That tower is crawling with bodyguards.', '', 0, 0, 1);

DELETE FROM `gossip_menu` WHERE `MenuID` = 13415 AND `TextID` = 915382;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(13415, 915382);

UPDATE `creature_template` SET `gossip_menu_id` = 13415 WHERE `entry` = 3636729 AND `gossip_menu_id` = 0;

-- ---------------------------------------------------------------------------
-- D) creature_text -- Slinky Sharpshiv (4 lines) + Sentinel Aynasha (4 lines)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (3636729, 3732964);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`entry` + 3600000, t.`groupid`, t.`id`, t.`text`, t.`type`, t.`language`, t.`probability`,
       t.`emote`, t.`duration`, t.`sound`, t.`BroadcastTextID`, t.`text_range`, 'Slinky Sharpshiv (map 750)'
FROM `nelt_world`.`creature_text` t
WHERE t.`entry` = 36729;

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`entry` + 3700000, t.`groupid`, t.`id`, t.`text`, t.`type`, t.`language`, t.`probability`,
       t.`emote`, t.`duration`, t.`sound`, t.`BroadcastTextID`, t.`text_range`, 'Sentinel Aynasha (map 750)'
FROM `nelt_world`.`creature_text` t
WHERE t.`entry` = 32964;

-- ---------------------------------------------------------------------------
-- E) Aynasha's escort route -- 25 points, SmartWaypointMgr `waypoints` table.
--    Path id = her clone entry 3732964 (verified free; matches the
--    entry-keyed convention of the other map-750 paths in this band).
-- ---------------------------------------------------------------------------
DELETE FROM `waypoints` WHERE `entry` = 3732964;

INSERT INTO `waypoints` (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT 3732964, w.`pointid`, w.`location_x`, w.`location_y`, w.`location_z`, NULL, 0,
       CONCAT('Sentinel Aynasha - Timely Arrival wp ', w.`pointid`)
FROM `nelt_world`.`script_waypoint` w
WHERE w.`entry` = 32964;

-- ---------------------------------------------------------------------------
-- F) Aynasha SmartAI -- quest 13510 "Timely Arrival"
--    (she had no smart_scripts rows and AIName '' before this file)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 3732964;

DELETE FROM `smart_scripts` WHERE `entryorguid` = 3732964 AND `source_type` = 0;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 373296400 AND `source_type` = 9;

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
-- accept 13510 -> talk 0 ("Thanks for the rescue...") then start the escort
-- (fork: action 53 = forcedMovement/pathId/repeat/quest/despawn/reactState)
(3732964, 0, 0, 1, 19, 0, 100, 0, 13510, 0, 0, 0, 0, 0,  1, 0, 2000, 0, 0, 0, 0,  7, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - On Quest 13510 Accepted - Talk 0'),
(3732964, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,  53, 1, 3732964, 0, 13510, 0, 1,  7, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Linked - Start escort path 3732964 (quest 13510, defensive)'),
-- ambush 1 at waypoint 8 -- two Horde Enforcers (Shatterspear siege clones)
(3732964, 0, 2, 3, 40, 0, 100, 0, 8, 3732964, 0, 0, 0, 0,  12, 3732859, 1, 120000, 1, 0, 0,  8, 0, 0, 0, 0, 7854.0, -1040.0, 30.3, 2.1, 'Sentinel Aynasha - On WP 8 Reached - Summon Horde Enforcer'),
(3732964, 0, 3, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,  12, 3732859, 1, 120000, 1, 0, 0,  8, 0, 0, 0, 0, 7849.0, -1030.0, 31.0, 2.1, 'Sentinel Aynasha - Linked - Summon Horde Enforcer'),
-- ambush 2 at waypoint 16 -- Shatterspear Mystic + Horde Enforcer
(3732964, 0, 4, 5, 40, 0, 100, 0, 16, 3732964, 0, 0, 0, 0,  12, 3734248, 1, 120000, 1, 0, 0,  8, 0, 0, 0, 0, 7889.0, -955.0, 6.0, 2.3, 'Sentinel Aynasha - On WP 16 Reached - Summon Shatterspear Mystic'),
(3732964, 0, 5, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,  12, 3732859, 1, 120000, 1, 0, 0,  8, 0, 0, 0, 0, 7883.0, -950.5, 5.5, 2.3, 'Sentinel Aynasha - Linked - Summon Horde Enforcer'),
-- path end (wp 25, the beach) -> farewell scene; quest credit is already
-- granted by ESCORT_START's quest parameter when the path ends
(3732964, 0, 6, 0, 58, 0, 100, 0, 25, 3732964, 0, 0, 0, 0,  80, 373296400, 0, 2, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - On Escort Ended - Run farewell actionlist'),
-- farewell actionlist: sanctuary + passive + immune, face the sea, three
-- goodbye lines, dive into the ocean, despawn (timings match the source)
(373296400, 9, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0,  11, 88467, 2, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Cast Sanctuary No Combat'),
(373296400, 9, 1, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0,  8, 0, 0, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Set react passive'),
(373296400, 9, 2, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0,  18, 768, 0, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Immune to PC and NPC'),
(373296400, 9, 3, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, 0,  66, 0, 0, 0, 0, 0, 0,  8, 0, 0, 0, 0, 0, 0, 0, 5.6, 'Sentinel Aynasha - Actionlist - Face the sea'),
(373296400, 9, 4, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, 0,  1, 1, 6000, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Talk 1'),
(373296400, 9, 5, 0, 0, 0, 100, 0, 7000, 7000, 0, 0, 0, 0,  1, 2, 8000, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Talk 2'),
(373296400, 9, 6, 0, 0, 0, 100, 0, 9000, 9000, 0, 0, 0, 0,  1, 3, 4000, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Talk 3'),
(373296400, 9, 7, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, 0,  97, 18, 20, 0, 0, 0, 0,  202, 0, 0, 0, 0, 7895.48, -854.18, -2.0, 0, 'Sentinel Aynasha - Actionlist - Dive into the sea'),
(373296400, 9, 8, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, 0,  41, 0, 0, 0, 0, 0, 0,  1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sentinel Aynasha - Actionlist - Despawn');

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver rebuild:
--   SELECT entry, ScriptName, gossip_menu_id, AIName FROM creature_template
--    WHERE entry IN (3636729, 3637139, 3636716, 3636753, 3732964);
--     -- Slinky/plane/seats scripted; 3636729 menu 13415; 3732964 SmartAI
--   SELECT CreatureID, COUNT(*) FROM creature_text
--    WHERE CreatureID IN (3636729, 3732964) GROUP BY CreatureID;   -- 4 + 4
--   SELECT COUNT(*) FROM waypoints WHERE entry = 3732964;          -- 25
--   SELECT COUNT(*) FROM smart_scripts WHERE entryorguid = 3732964;    -- 7
--   SELECT COUNT(*) FROM smart_scripts WHERE entryorguid = 373296400;  -- 9
--   SELECT * FROM npc_spellclick_spells WHERE npc_entry = 3636729;
--
-- In game (Azshara side, all at the Southern Rocketway / runestone tower):
--   1. Click a parked Wings of Steel biplane -- it taxis to the runway
--      controller, takes off, flies its route and drops you at the tower.
--   2. Take "Lightning Strike Assassination" (14464) from Slinky Sharpshiv,
--      talk to her again, pick "I'm ready" -- grapples, seat-climb, kill
--      Captain Grunwald and Mariel Dawnsong on top, watch her arm the
--      charges, click her at "Hop on!" for the glide down, turn in at Chawg.
-- In game (Darkshore side): take "Timely Arrival" (13510) from Sentinel
--   Aynasha at the Ruins of Mathystra -- she talks, walks the 25-point route
--   with two Shatterspear ambushes, credits at the beach, says her three
--   farewells and dives into the sea.
-- ---------------------------------------------------------------------------
