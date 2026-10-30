-- Run after the three pending files are applied (read-only). Every 'want' should match.

SELECT 'templates (want 36)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `creature_template` WHERE `entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007, 4010008, 4010009, 4010010, 4010011, 4010012, 4010013, 4010014, 4010015, 4010101, 4010102, 4010103, 4010104, 4010105, 4010106, 4010107, 4010108, 4010109, 4010110, 4010111, 4010112, 4010113, 4010114, 4010115, 4010116, 4010117, 4010118, 4010201, 4010202, 4010203)
UNION ALL SELECT 'spawns on 819 in the block (want 283)', CAST(COUNT(*) AS CHAR) FROM `creature` WHERE `map` = 819 AND `guid` BETWEEN 16500000 AND 16509999
UNION ALL SELECT 'patrol points (want 781)', CAST(COUNT(*) AS CHAR) FROM `waypoint_data` WHERE `id` BETWEEN 165000000 AND 165099999
UNION ALL SELECT 'gameobjects (want 10)', CAST(COUNT(*) AS CHAR) FROM `gameobject` WHERE `guid` BETWEEN 16530200 AND 16530299
UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id` WHERE c.`map` = 819 AND t.`entry` IS NULL
UNION ALL SELECT 'models with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID` WHERE m.`CreatureID` BETWEEN 4010001 AND 4010299 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'guid above 0xFFFFFF (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature` WHERE `guid` > 16777215;

SELECT 'items (want 136)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `item_template` WHERE `entry` BETWEEN 410200 AND 410335
UNION ALL SELECT 'loot pointing at a missing item (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item` WHERE l.`Entry` BETWEEN 4010001 AND 4010299 AND i.`entry` IS NULL
UNION ALL SELECT 'vault entries (want 77)', CAST(COUNT(*) AS CHAR) FROM `dc_vault_loot_table` WHERE `source` = 'Timbermaw Hold';

SELECT 'quests (want 15)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `quest_template` WHERE `ID` BETWEEN 700769 AND 700799
UNION ALL SELECT 'quest rewards with no item (want 0)', CAST(COUNT(*) AS CHAR) FROM `quest_template` q LEFT JOIN `item_template` i ON i.`entry` = q.`RewardChoiceItemID1` WHERE q.`ID` BETWEEN 700769 AND 700799 AND q.`RewardChoiceItemID1` <> 0 AND i.`entry` IS NULL
UNION ALL SELECT 'encounters (want 27)', CAST(COUNT(*) AS CHAR) FROM `instance_encounters` WHERE `creditEntry` BETWEEN 4010001 AND 4010011
UNION ALL SELECT 'smart rows (want 43)', CAST(COUNT(*) AS CHAR) FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4010001 AND 4010299;
