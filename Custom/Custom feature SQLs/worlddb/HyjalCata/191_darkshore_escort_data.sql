-- ---------------------------------------------------------------------------
-- 191  Darkshore (map 750) -- data for the two ported escort scripts
-- ---------------------------------------------------------------------------
-- Stage 3, after 189_ (items) and 190_ (quests). Wires up the C++ ported into
-- src/server/scripts/DC/MountHyjal/zone_darkshore_cata.cpp:
--     npc_hollee_escort              -- quest 13605 "The Last Refugee"
--     npc_prospector_remtravel_escort -- quest 13911 "The Absent-Minded Prospector"
--
-- SOURCE IS `nelt_world`, NOT `cata_world`. This is the notable bit: cata_world
-- has NO creature_text and NO script_waypoint for these NPCs at all. The
-- Neltharion scripts were written against Neltharion's own database, so the
-- dialogue and the walking route live in nelt_world -- 18 text rows + 68
-- waypoints for Hollee, 11 + 37 for Remtravel. Without both tables an escort
-- silently starts with zero waypoints and just stands there
-- (ScriptedEscortAI.cpp logs "starts with 0 waypoints").
--
-- Waypoint coordinates are copied UNCHANGED. Map 750 is a coordinate-preserving
-- copy of this corner of Kalimdor, so the Darkshore routes already land on the
-- right ground; only the creature entry is offset.
--
-- Column names differ between the two schemas (nelt uses the old lowercase
-- TrinityCore names, we use the modern ones), hence the explicit column lists.
-- nelt has no `SoundType`, and its `text_range` maps to our `TextRange`.
--
-- Apply against acore_world AFTER 190_, then REBUILD worldserver (new C++
-- file). Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_text -- Hollee, Elisa Steelhand, Remtravel, Groff
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (3733232, 3733231, 3734343, 3734340);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`entry` + 3700000, t.`groupid`, t.`id`, t.`text`, t.`type`, t.`language`, t.`probability`,
       t.`emote`, t.`duration`, t.`sound`, t.`BroadcastTextID`, t.`text_range`, t.`comment`
FROM `nelt_world`.`creature_text` t
WHERE t.`entry` IN (33232, 33231, 34343, 34340);

-- ---------------------------------------------------------------------------
-- B) script_waypoint -- the escort routes (npc_escortAI loads these by entry)
-- ---------------------------------------------------------------------------
DELETE FROM `script_waypoint` WHERE `entry` IN (3733232, 3734343);

INSERT INTO `script_waypoint`
    (`entry`,`pointid`,`location_x`,`location_y`,`location_z`,`waittime`,`point_comment`)
SELECT w.`entry` + 3700000, w.`pointid`, w.`location_x`, w.`location_y`, w.`location_z`,
       w.`waittime`, w.`point_comment`
FROM `nelt_world`.`script_waypoint` w
WHERE w.`entry` IN (33232, 34343);

-- ---------------------------------------------------------------------------
-- C) Wire the ScriptNames
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_hollee_escort'              WHERE `entry` = 3733232;
UPDATE `creature_template` SET `ScriptName` = 'npc_prospector_remtravel_escort' WHERE `entry` = 3734343;

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver rebuild:
--   SELECT CreatureID, COUNT(*), MIN(GroupID), MAX(GroupID) FROM creature_text
--    WHERE CreatureID IN (3733232,3733231,3734343,3734340) GROUP BY CreatureID;
--     -- 3733232 18 rows groups 0-12 | 3733231 4 rows 0-3
--     -- 3734343 11 rows groups 0-9  | 3734340 2 rows 0-1
--   SELECT entry, COUNT(*) FROM script_waypoint WHERE entry IN (3733232,3734343) GROUP BY entry;
--     -- 3733232 -> 68, 3734343 -> 37
--   SELECT entry, name, ScriptName FROM creature_template WHERE entry IN (3733232,3734343);
--
-- In game: take "The Last Refugee" from Archaeologist Hollee, or "The
-- Absent-Minded Prospector" from Prospector Remtravel. Each should start
-- walking and talking immediately on accept. If one stands still, the boot log
-- will say "EscortAI ... starts with 0 waypoints" -- that means section B did
-- not apply, not that the script is missing.
-- ---------------------------------------------------------------------------
