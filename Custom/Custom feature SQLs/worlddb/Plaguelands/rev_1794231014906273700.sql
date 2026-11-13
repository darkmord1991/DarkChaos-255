-- Silverpine Forest (map 751), Sepulcher slice of the Neltharion C++ port:
-- binds src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_sepulcher.cpp
-- (AddSC_dc_silverpine_sepulcher). Needs the worldserver build that contains that file.
--
-- The Waters Run Red... (27232)
--   4145263 Horde Cannon (3 spawns at the lake shore, guids 16715288-16715290) gets the vehicle AI.
--   It had no way to be boarded: no npc_spellclick_spells row and npcflag 0. Added the row
--   nelt_world has for 45263 (Ride Vehicle Hardcoded 46598, cast_flags 1), its condition (quest
--   27232 taken) and the UNIT_NPC_FLAG_SPELLCLICK bit, which the core does not set by itself.
--   Its weapon in nelt_world (spell1 84575; its hit 84574) exists neither in the server Spell.dbc
--   nor in spell_dbc, so the cannon fires stock 57385 "Argent Cannon" (quest 13086's cannon,
--   ground target, spell_q13086_last_line_of_defence) instead.
--   45270 Hillsbrad Worgen stays at its PLAIN id: it is what the cannon summons, the quest
--   objective (RequiredNpcOrGo1 = 45270), and no 4145270 template exists. It gets the C++
--   companion AI that replaces nelt_world's SmartAI for it (it has no smart_scripts rows here).
--
-- What Tomorrow Brings (27401)
--   4805417 7th Legion Telescope (1 spawn, guid 16402624) gets the GO AI; it also suppresses the
--   template's own spell 84936, which force-casts the absent 84882.
--   45430 Gilneas Camera 01 (Target), the quest objective, is what the telescope summons as the
--   camera (the source's vehicle camera 45427 has no template here, and Vehicle 1105 is not in
--   the server Vehicle.dbc). Its text is the source camera's line, sent as a boss whisper to the
--   viewer because the camera is far from the player's body when it speaks.
--
-- Rows: 4 creature_template / gameobject_template UPDATEs, 1 npc_spellclick_spells, 1 conditions,
-- 1 creature_template_spell, 1 creature_text.

UPDATE `creature_template` SET `ScriptName` = 'npc_horde_cannon_45263', `AIName` = '', `npcflag` = `npcflag` | 16777216 WHERE `entry` = 4145263;
UPDATE `creature_template` SET `ScriptName` = 'npc_hillsbrad_worgen_45270', `AIName` = '' WHERE `entry` = 45270;
UPDATE `creature_template` SET `ScriptName` = 'npc_camera_silverpine_telescope', `AIName` = '' WHERE `entry` = 45430;
UPDATE `gameobject_template` SET `ScriptName` = 'go_7th_legion_telescope' WHERE `entry` = 4805417;

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 4145263 AND `spell_id` = 46598;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(4145263, 46598, 1, 0);

DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 18 AND `SourceGroup` = 4145263 AND `SourceEntry` = 46598;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(18, 4145263, 46598, 0, 0, 9, 0, 27232, 0, 0, 0, 0, 0, '', 'Horde Cannon (751) - board only with quest 27232 The Waters Run Red taken');

DELETE FROM `creature_template_spell` WHERE `CreatureID` = 4145263;
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`) VALUES
(4145263, 0, 57385, 0);

DELETE FROM `creature_text` WHERE `CreatureID` = 45430 AND `GroupID` = 0;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(45430, 0, 0, 'Alliance reinforcements have arrived.', 42, 0, 100, 0, 0, 0, 0, 0, 'Gilneas Camera 01 (Target) - end of the telescope flight, quest 27401');
