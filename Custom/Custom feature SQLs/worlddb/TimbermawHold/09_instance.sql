-- =====================================================================================
-- Timbermaw Hold (map 819) -- instance script binding + encounter registration
--
-- `instance_template.script` binds the C++ InstanceScript. InstanceMapScript bakes the map id
-- into its constructor, so each map needs its own registration and cannot share another's.
--
-- `instance_encounters` is NOT cosmetic. MythicPlusRunManager::CacheBossMetadata() builds the
-- boss count, final-boss detection, M+ loot and the HUD timer entirely from these rows joined
-- against DungeonEncounter.dbc. Miss them and M+ silently misreports.
-- `lastEncounterDungeon` = the map id on the FINAL boss only; that is what marks it final.
--
-- DungeonEncounter.dbc ids 1100-1106 were added to Custom/CSV DBC/DungeonEncounter.csv and
-- compiled + deployed to patch-4, the enGB chain and the three WarcraftXLHost dirs.
-- =====================================================================================


UPDATE `instance_template` SET `script` = 'instance_timbermaw_hold' WHERE `map` = 819;

DELETE FROM `instance_encounters` WHERE `entry` BETWEEN 1100 AND 1106;
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
    (1100, 0, 4010001, 0, 'Gatewarden Mor''thak'),
    (1101, 0, 4010002, 0, 'The Sundered Chieftain'),
    (1102, 0, 4010003, 0, 'Den Mother Ursara'),
    (1103, 0, 4010004, 0, 'Xanthir the Defiler'),
    (1104, 0, 4010005, 0, 'The Nightmare Given Root'),
    (1105, 0, 4010006, 0, 'Ursol'),
    (1106, 0, 4010007, 819, 'Ursoc -- final');

SELECT 'instance_template script bound (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 819 AND `script` = 'instance_timbermaw_hold'
UNION ALL SELECT 'encounters (want 7)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1100 AND 1106
UNION ALL SELECT 'exactly one final boss (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1100 AND 1106 AND `lastEncounterDungeon` = 819
UNION ALL SELECT 'creditEntry with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` ie LEFT JOIN `creature_template` ct ON ct.`entry` = ie.`creditEntry`
    WHERE ie.`entry` BETWEEN 1100 AND 1106 AND ct.`entry` IS NULL;
