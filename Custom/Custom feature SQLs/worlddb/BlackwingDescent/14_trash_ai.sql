-- Blackwing Descent (map 669) — trash AI (the non-boss fidelity gap)
-- CataTC ships C++ for all named adds/RP; only these 6 trash entries have no AI in CataTC:
--   42802 Drakonid Slayer, 46083 Drakeadon Mongrel, 42764 Pyrecraw, 42767 Ivoroc, 42768 Maimgor  -> nelt SmartAI
--   42803 Drakeadon Mongrel (no SmartAI anywhere) -> built-in AggressorAI
-- Also carry the Golem Sentry 42800 SmartAI (cata). Drudge 42362 has AIName SmartAI in cata but no
-- rows there; its Magmaw-chain role is handled by the instance C++, so it drops to default reactive AI.
--
-- smart_scripts column counts differ per DB (event_param: acore 6 / nelt 4 / cata 5; target_param:
-- acore 4 / cata 3) so the missing trailing params are zero-filled explicitly (no SELECT *).

-- ---------------------------------------------------------------------------
-- AIName overrides (01 imported cata's empty AIName for these)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI'     WHERE `entry` IN (42764,42767,42768,42802,46083,42800);
UPDATE `creature_template` SET `AIName` = 'AggressorAI' WHERE `entry` = 42803;
UPDATE `creature_template` SET `AIName` = ''            WHERE `entry` = 42362;

-- ---------------------------------------------------------------------------
-- smart_scripts — 5 gap entries from nelt_world (event_param5/6 -> 0)
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (42764,42767,42768,42802,46083,42800);

INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
     `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT
    s.`entryorguid`, s.`source_type`, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`, s.`event_chance`, s.`event_flags`,
    s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`, 0, 0,
    s.`action_type`, s.`action_param1`, s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
    s.`target_type`, s.`target_param1`, s.`target_param2`, s.`target_param3`, s.`target_param4`,
    s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `nelt_world`.`smart_scripts` s
WHERE s.`source_type` = 0 AND s.`entryorguid` IN (42764,42767,42768,42802,46083);

-- ---------------------------------------------------------------------------
-- smart_scripts — Golem Sentry 42800 from cata_world (event_param6/target_param4 -> 0)
-- ---------------------------------------------------------------------------
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
     `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT
    s.`entryorguid`, s.`source_type`, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`, s.`event_chance`, s.`event_flags`,
    s.`event_param1`, s.`event_param2`, s.`event_param3`, s.`event_param4`, s.`event_param5`, 0,
    s.`action_type`, s.`action_param1`, s.`action_param2`, s.`action_param3`, s.`action_param4`, s.`action_param5`, s.`action_param6`,
    s.`target_type`, s.`target_param1`, s.`target_param2`, s.`target_param3`, 0,
    s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
WHERE s.`source_type` = 0 AND s.`entryorguid` = 42800;
