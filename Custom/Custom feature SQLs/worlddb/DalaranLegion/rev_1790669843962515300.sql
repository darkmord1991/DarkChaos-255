-- Map 1413 (Legion Dalaran guild house): make the Illidari Gateway a working portal.
-- The Illidari door (4100472, spawn 9600496) becomes the clickable part, as retail's 251286 was: a
-- spellcaster with no spell, so a click only runs the SmartAI teleport below. No state change, no
-- despawn, reusable. Destination surveyed in-game 2026-09-29.
UPDATE `gameobject_template` SET `type` = 22, `Data0` = 0, `Data1` = 0, `Data2` = 0, `Data3` = 1, `Data4` = 1, `Data5` = 0, `Data6` = 0, `AIName` = 'SmartGameObjectAI' WHERE `entry` = 4100472;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 4100472 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(4100472, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 1413, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1032.3264, 1141.3925, 535.24445, 5.6386104, 'Illidari Gateway - On Gossip Hello - Teleport Invoker');
-- The Legion portal ring (4100478, spawn 9600114) stays a pure visual. As a goober, a click would switch it
-- to its Closed animation and despawn it for 180 s; not selectable, clicks reach the door instead. Its
-- retail spell 217719 does not exist on this server.
UPDATE `gameobject_template` SET `Data10` = 0 WHERE `entry` = 4100478;
DELETE FROM `gameobject_template_addon` WHERE `entry` = 4100478;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`) VALUES
(4100478, 0, 16, 0, 0, 0, 0, 0, 0);
-- The type change is cached in the client's WDB; bump the cache id so every client refetches templates.
UPDATE `version` SET `cache_id` = `cache_id` + 1 LIMIT 1;
