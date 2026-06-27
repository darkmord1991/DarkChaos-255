-- =====================================================================
-- Deepholm Downport  --  12  SmartAI  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01 (creature templates with AIName='SmartAI').
--
-- Deepholm's data-driven AI is tiny: 19 lines, all creature ENTRY-based
-- (source_type=0), no guid-based rows, no gameobject scripts, no timed
-- action lists. The 6 shared/stock infra creatures (ELM bunnies etc.) are
-- EXCLUDED so their stock SmartAI is never overwritten.
--
-- Mapping: this fork added event_param6 + target_param4 (Cata has 5 event
-- params / 3 target params) -> both defaulted to 0.
-- =====================================================================

DELETE FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `entryorguid` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
 `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
 `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
 `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT
 s.`entryorguid`,s.`source_type`,s.`id`,s.`link`,s.`event_type`,s.`event_phase_mask`,s.`event_chance`,s.`event_flags`,
 s.`event_param1`,s.`event_param2`,s.`event_param3`,s.`event_param4`,s.`event_param5`,0,
 s.`action_type`,s.`action_param1`,s.`action_param2`,s.`action_param3`,s.`action_param4`,s.`action_param5`,s.`action_param6`,
 s.`target_type`,s.`target_param1`,s.`target_param2`,s.`target_param3`,0,s.`target_x`,s.`target_y`,s.`target_z`,s.`target_o`,s.`comment`
FROM `cata_world`.`smart_scripts` s
WHERE s.`source_type` = 0
  AND s.`entryorguid` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND s.`entryorguid` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);
