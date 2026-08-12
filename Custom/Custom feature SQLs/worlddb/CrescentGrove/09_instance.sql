-- =====================================================================================
-- Crescent Grove (map 823) -- instance script binding + encounter registration
--
-- `instance_template.script` binds the C++ InstanceScript. InstanceMapScript bakes the map id
-- into its constructor, so each map needs its own registration and cannot share another's.
--
-- `instance_encounters` is NOT cosmetic. MythicPlusRunManager::CacheBossMetadata() builds the
-- boss count, final-boss detection, M+ loot and the HUD timer entirely from these rows joined
-- against DungeonEncounter.dbc. Miss them and M+ silently misreports.
-- `lastEncounterDungeon` = the map id on the FINAL boss only; that is what marks it final.
--
-- DungeonEncounter.dbc ids 1110-1114 were added to Custom/CSV DBC/DungeonEncounter.csv and
-- compiled + deployed to patch-4, the enGB chain and the three WarcraftXLHost dirs.
-- =====================================================================================


UPDATE `instance_template` SET `script` = 'instance_crescent_grove' WHERE `map` = 823;

DELETE FROM `instance_encounters` WHERE `entry` BETWEEN 1110 AND 1114;
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
    (1110, 0, 4020001, 0, 'Keeper Ranathos'),
    (1111, 0, 4020002, 0, 'Grovetender Engryss (+ both elders)'),
    (1112, 0, 4020005, 0, 'High Priestess A''lathea'),
    (1113, 0, 4020006, 0, 'Fenektis the Deceiver'),
    (1114, 0, 4020007, 823, 'Master Raxxieth -- final');

SELECT 'instance_template script bound (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 823 AND `script` = 'instance_crescent_grove'
UNION ALL SELECT 'encounters (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1110 AND 1114
UNION ALL SELECT 'exactly one final boss (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1110 AND 1114 AND `lastEncounterDungeon` = 823
UNION ALL SELECT 'creditEntry with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` ie LEFT JOIN `creature_template` ct ON ct.`entry` = ie.`creditEntry`
    WHERE ie.`entry` BETWEEN 1110 AND 1114 AND ct.`entry` IS NULL;
