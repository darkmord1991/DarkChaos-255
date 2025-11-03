-- Assign ScriptName for Dungeon Quest NPCs
-- This file sets the ScriptName for creature_template entries used by the Dungeon Quest system.
-- Run this against your world (character) database where creature_template lives (usually 'acore_world' or 'characters').

-- Check current assignment (example):
-- SELECT entry, name, ScriptName FROM creature_template WHERE entry BETWEEN 700000 AND 700052;

-- Primary gossip/quest NPC script
UPDATE creature_template
SET ScriptName = 'npc_dungeon_quest_master'
WHERE entry BETWEEN 700000 AND 700052;

-- If you prefer to attach the phasing-only CreatureScript instead of (or in addition to) the gossip script,
-- use the following UPDATE (pick one). Note: creature_template.ScriptName can only hold a single script name.
-- To assign the phasing script instead, uncomment the following and run it instead of the previous UPDATE.
-- UPDATE creature_template
-- SET ScriptName = 'DungeonQuestMasterPhasing'
-- WHERE entry BETWEEN 700000 AND 700052;

-- Sanity check: list the assigned names after update
-- SELECT entry, name, ScriptName FROM creature_template WHERE entry BETWEEN 700000 AND 700052 ORDER BY entry;

-- Notes:
-- * The code registers both CreatureScripts ("npc_dungeon_quest_master" and "npc_dungeon_quest_completion").
--   The typical approach is to assign the gossip/master script to the creature entries so players get the gossip menu.
-- * If you need multiple behaviors attached to the same creature, consider merging functionality into a single
--   CreatureScript class or using an alternate mechanism (for example, a PlayerScript/WorldScript that adjusts
--   phases globally for the quest master entries).
-- * Run these statements with a DB client (mysql) against your world database and then reload the server or
--   use the AC reload mechanism if available.
