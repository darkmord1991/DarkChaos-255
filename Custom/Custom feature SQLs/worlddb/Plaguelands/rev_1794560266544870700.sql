-- DarkChaos: three map 751 SmartAI chains whose middle row is not a link event (Errors.log, 2026-11-13)
--
-- "SmartScript::ProcessAction: Entry 3610824 SourceType 0, Event 8, Link Event 9 found but has wrong type
-- (should be 61, is 9)". The ranged-NPC template on Ranger Lord Hawkspear 3610824, Nathanos Blightcaller 3611878
-- and Quel'Lithien Protector 3612322 runs "At 0 - 5 Range": Allow Combat Movement -> Display melee weapon ->
-- Start Auto Attack. The middle row was written as a range event (9) with an empty 0-0 range, so the chain
-- stopped after the first step: in melee range the NPC never switched to its melee weapon or started auto attack.
-- They are the only three such chains on DC entries; the other 7 in the table are stock rows and stay as they are.
--
-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.

UPDATE `smart_scripts` SET `event_type` = 61
WHERE `entryorguid` = 3610824 AND `source_type` = 0 AND `id` = 9 AND `link` = 10 AND `event_type` = 9;
UPDATE `smart_scripts` SET `event_type` = 61
WHERE `entryorguid` = 3611878 AND `source_type` = 0 AND `id` = 13 AND `link` = 14 AND `event_type` = 9;
UPDATE `smart_scripts` SET `event_type` = 61
WHERE `entryorguid` = 3612322 AND `source_type` = 0 AND `id` = 9 AND `link` = 10 AND `event_type` = 9;
