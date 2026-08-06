-- ---------------------------------------------------------------------------
-- 269  The two C++ scripts registered in code but never bound in the DB
-- ---------------------------------------------------------------------------
--     Script named 'at_mh_hyjal_barrow_dens' is not assigned in the database.
--     Script named 'npc_darkshore_wisp_circling' is not assigned in the database.
--
-- Both live in DC/MountHyjal/. Only ONE of them should be bound, and the reason
-- the other should not is worth reading before "fixing" it the obvious way.

-- ---- 1. at_mh_hyjal_barrow_dens -> areatrigger 5876 ------------------------
-- Quest 25325 "Through the Dream" has a questgiver and a turn-in but NO
-- objectives at all, so walking into the Barrow Dens is its only completion
-- path -- exactly what zone_mount_hyjal.cpp:4144 implements. Without this row
-- the quest is accepted and can never be handed in.
--
-- 5876 is the id cata_world binds the same script to, and it checks out against
-- our own deployed data rather than being taken on trust: AreaTrigger.dbc has it
-- as record 1368/1369 on **map 750** at (5707.54, -3160.32, 1596.90), box
-- 35.42 x 11.81 x 13.45 -- the Hyjal Barrow Dens on our custom map. It is a
-- DC-added trigger (last row in the file), which is why nothing bound it yet.
-- Nothing else claims it: no areatrigger_scripts, areatrigger_teleport or
-- areatrigger_involvedrelation row exists for 5876.
DELETE FROM acore_world.`areatrigger_scripts` WHERE `entry` = 5876;

INSERT INTO acore_world.`areatrigger_scripts` (`entry`,`ScriptName`) VALUES
(5876,'at_mh_hyjal_barrow_dens');

-- ---- 2. npc_darkshore_wisp_circling -- deliberately NOT bound --------------
-- 🔴 Binding this one would BREAK the wisps, not fix them.
--
-- The target is 3734306 "Darkshore Wisp" (29 spawns on map 750). It carries
-- AIName='SmartAI' with one row -- on respawn, cast 65127 'Darkshore Wisp
-- Sparkle' -- and that sparkle IS the wisps' whole visible behaviour. The C++
-- script's own header says it leaves that untouched, but it cannot:
--
--     FactorySelector::SelectAI (CreatureAISelector.cpp:78)
--       -> if (CreatureAI* scriptedAI = sScriptMgr->GetCreatureAI(creature))
--              return scriptedAI;              // ScriptName wins
--       -> SelectFactory<CreatureAI>(creature) // AIName / SmartAI, never reached
--
-- ScriptName is checked BEFORE AIName, so setting it replaces SmartAI outright.
-- The script's UpdateAI is empty and it casts nothing, so the wisps would drift
-- and stop sparkling -- trading a cosmetic warning for a cosmetic regression.
--
-- What the script actually does is one MoveRandom call, and SmartAI already has
-- that verb: SMART_ACTION_RANDOM_MOVE (89, param1 = maxDist). CLAUDE.md's rule
-- is to prefer SmartAI unless its vocabulary falls short, and here it does not.
-- So the drift is added as a second SmartAI row instead, and both behaviours
-- coexist:
DELETE FROM acore_world.`smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3734306 AND `id` = 1;

INSERT INTO acore_world.`smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
(3734306,0,1,0,11,0,100,0,0,0,0,0,0,0,89,6,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'Darkshore Wisp - On Respawn - Drift randomly within 6 yd (replaces npc_darkshore_wisp_circling)');

-- The C++ side still needs a one-line removal or the warning persists: drop
--     RegisterCreatureAI(npc_darkshore_wisp_circling);
-- from AddSC_dc_darkshore_cata() in
-- src/server/scripts/DC/MountHyjal/zone_darkshore_cata.cpp (and the now-unused
-- struct above it). That is a code change, so it is NOT done here -- it needs a
-- rebuild, which this workflow does not do without being asked.
--
-- Verify after apply:
--   * SELECT ScriptName FROM areatrigger_scripts WHERE entry = 5876;  -> at_mh_hyjal_barrow_dens
--   * SELECT COUNT(*) FROM smart_scripts WHERE entryorguid = 3734306
--       AND source_type = 0;                                          -> 2
--   * "Script named 'at_mh_hyjal_barrow_dens' is not assigned" is gone.
--   * "Script named 'npc_darkshore_wisp_circling' is not assigned" REMAINS until
--     the registration is removed from the source and the server rebuilt. That
--     is expected, not a failed apply.
--   * in-game: the wisps still sparkle on respawn AND now drift.
