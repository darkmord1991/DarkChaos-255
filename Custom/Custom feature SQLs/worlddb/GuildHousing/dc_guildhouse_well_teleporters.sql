-- DC GuildHouse Dalaran: well -> Underbelly teleporters (maps 1409 + 1413)
-- v3 2026-08-10 evening. History:
--   v1 areatrigger-only: rows were rejected at boot (this core loads trigger geometry
--      from the world TABLE `areatrigger`, not AreaTrigger.dbc; dbc is client-side only).
--   v2 added `areatrigger` rows + low-id (6100/6101) duplicates: server side loads clean,
--      but the CLIENT was proven (GM .debug areatriggers on, standing inside the sphere)
--      to never send CMSG_AREATRIGGER for these rows - neither 607009 nor 6101.
--   v3 (THIS): mechanism switched to an invisible SmartAI trigger NPC at the well bottom
--      (OOC LOS range 6 -> teleport invoker). 100% server-side, no client data involved.
--      The v2 areatrigger/areatrigger_teleport rows are kept below - they are harmless,
--      and if the client-side mystery is ever solved they'd start working as a bonus.
-- Requires worldserver RESTART after applying (new template + spawns + SmartAI).

-- ---------- v3: invisible SmartAI well trigger NPCs ----------
-- Templates: clone of stock "World Trigger" 22515 (invisible, trigger-flagged).
DROP TABLE IF EXISTS `_dc_tmp_welltrig`;
CREATE TABLE `_dc_tmp_welltrig` LIKE `creature_template`;
INSERT INTO `_dc_tmp_welltrig` SELECT * FROM `creature_template` WHERE `entry` = 22515;
UPDATE `_dc_tmp_welltrig` SET `entry` = 3500900, `name` = 'GuildHouse Well Teleporter 1409', `subname` = '', `AIName` = 'SmartAI', `ScriptName` = '', `flags_extra` = `flags_extra` | 128, `npcflag` = 0, `MovementType` = 0;
DELETE FROM `creature_template` WHERE `entry` IN (3500900, 3500901);
INSERT INTO `creature_template` SELECT * FROM `_dc_tmp_welltrig`;
UPDATE `_dc_tmp_welltrig` SET `entry` = 3500901, `name` = 'GuildHouse Well Teleporter 1413';
INSERT INTO `creature_template` SELECT * FROM `_dc_tmp_welltrig`;
DROP TABLE `_dc_tmp_welltrig`;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3500900, 3500901);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 3500900, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0 FROM `creature_template_model` WHERE `CreatureID` = 22515;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 3500901, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0 FROM `creature_template_model` WHERE `CreatureID` = 22515;

-- Spawns at the well shaft bottom (floor z 517.76), cloned from an existing static
-- spawn on each map so the row matches this fork's `creature` schema.
DROP TABLE IF EXISTS `_dc_tmp_wellspawn`;
CREATE TABLE `_dc_tmp_wellspawn` LIKE `creature`;
INSERT INTO `_dc_tmp_wellspawn` SELECT c.* FROM `creature` c WHERE c.`map` = 1409 AND c.`id` = (SELECT `entry` FROM `creature_template` WHERE `name` = 'Arille Azuregaze' LIMIT 1) LIMIT 1;
UPDATE `_dc_tmp_wellspawn` SET `guid` = 16700001, `id` = 3500900, `map` = 1409, `spawnMask` = 1, `phaseMask` = 1,
  `position_x` = 1046.05, `position_y` = 1018.64, `position_z` = 522.0, `orientation` = 0,
  `spawntimesecs` = 25, `wander_distance` = 0, `MovementType` = 0;
DELETE FROM `creature` WHERE `guid` IN (16700001, 16700002);
INSERT INTO `creature` SELECT * FROM `_dc_tmp_wellspawn`;
UPDATE `_dc_tmp_wellspawn` SET `guid` = 16700002, `id` = 3500901, `map` = 1413;
INSERT INTO `creature` SELECT * FROM `_dc_tmp_wellspawn`;
DROP TABLE `_dc_tmp_wellspawn`;

-- SmartAI: OOC LOS (any hostility, players only, range 6, 1s cooldown) -> teleport
-- invoker to the Underbelly pipe exit on the SAME map.
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (3500900, 3500901) AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(3500900, 0, 0, 0, 10, 0, 100, 0, 2, 5, 1000, 1000, 1, 0, 62, 1409, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1061.46, 1011.69, 499.26, 1.539, 'GuildHouse Well 1409 - OOC LOS - Teleport player to Underbelly'),
(3500901, 0, 0, 0, 10, 0, 100, 0, 2, 5, 1000, 1000, 1, 0, 62, 1413, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1061.46, 1011.69, 499.26, 1.539, 'GuildHouse Well 1413 - OOC LOS - Teleport player to Underbelly');

-- ---------- v2 rows (kept, currently inert client-side) ----------
DELETE FROM `areatrigger` WHERE `entry` IN (607008, 607009, 6100, 6101);
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(607008, 1409, 1046.05, 1018.64, 523.96, 6, 0, 0, 0, 0),
(607009, 1413, 1046.05, 1018.64, 523.96, 6, 0, 0, 0, 0),
(6100, 1409, 1046.05, 1018.64, 521.0, 6, 0, 0, 0, 0),
(6101, 1413, 1046.05, 1018.64, 521.0, 6, 0, 0, 0, 0);

DELETE FROM `areatrigger_teleport` WHERE `ID` IN (607008, 607009, 6100, 6101);
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
(607008, 'GuildHouse Dalaran (1409) - Well teleporter', 1409, 1061.46, 1011.69, 499.26, 1.539),
(607009, 'GuildHouse Dalaran Legion (1413) - Well teleporter', 1413, 1061.46, 1011.69, 499.26, 1.539),
(6100, 'GuildHouse Dalaran (1409) - Well teleporter (low id)', 1409, 1061.46, 1011.69, 499.26, 1.539),
(6101, 'GuildHouse Dalaran Legion (1413) - Well teleporter (low id)', 1413, 1061.46, 1011.69, 499.26, 1.539);
