-- =====================================================================================
-- Emerald Sanctum (map 824) -- instance script binding + encounter registration
--
-- `instance_template.script` binds the C++ InstanceScript. InstanceMapScript bakes the map id
-- into its constructor, so each map needs its own registration and cannot share another's.
--
-- `instance_encounters` is NOT cosmetic. MythicPlusRunManager::CacheBossMetadata() builds the
-- boss count, final-boss detection, M+ loot and the HUD timer entirely from these rows joined
-- against DungeonEncounter.dbc. Miss them and M+ silently misreports.
-- `lastEncounterDungeon` = the map id on the FINAL boss only; that is what marks it final.
--
-- DungeonEncounter.dbc ids 1120-1121 were added to Custom/CSV DBC/DungeonEncounter.csv and
-- compiled + deployed to patch-4, the enGB chain and the three WarcraftXLHost dirs.
-- =====================================================================================


UPDATE `instance_template` SET `script` = 'instance_emerald_sanctum' WHERE `map` = 824;

-- THE WAKENER IS FOUR CREATURES SHARING ONE ENCOUNTER.
-- instance_encounters has a PRIMARY KEY on `entry` alone, so a single encounter can carry
-- exactly ONE creditEntry -- there is no way to list all four dragons here. Ysondre is the
-- nominal credit; the InstanceScript's OnUnitDeath credits DATA_WAKENER for whichever of
-- Ysondre / Lethon / Emeriss / Taerar actually dies. That keeps the boss count at 2 whatever
-- the week rolled, which is the whole point of the rotation sharing one slot.
DELETE FROM `instance_encounters` WHERE `entry` BETWEEN 1120 AND 1121;
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
    (1120, 0, 4030001, 0, 'Erennius'),
    (1121, 0, 4030002, 824, 'The Wakener -- final; see note');

SELECT 'instance_template script bound (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `instance_template` WHERE `map` = 824 AND `script` = 'instance_emerald_sanctum'
UNION ALL SELECT 'encounters (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1120 AND 1121
UNION ALL SELECT 'exactly one final boss (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` WHERE `entry` BETWEEN 1120 AND 1121 AND `lastEncounterDungeon` = 824
UNION ALL SELECT 'creditEntry with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `instance_encounters` ie LEFT JOIN `creature_template` ct ON ct.`entry` = ie.`creditEntry`
    WHERE ie.`entry` BETWEEN 1120 AND 1121 AND ct.`entry` IS NULL;
