-- Blackwing Descent (map 669) — instance registration, encounters, entrance teleport, access
--
-- Any InstanceType>0 map REQUIRES an instance_template row or entry is rejected
-- (CANNOT_ENTER_UNINSTANCED_DUNGEON). Map 669 must also exist in Map.dbc with InstanceType=2 (DBC step).
-- instance_encounters + the entrance AreaTrigger reference DBC rows that are added in the DBC step:
--   DungeonEncounter.dbc 1022-1027 (boss-kill credit UI) and AreaTrigger.dbc 6581 (entrance geometry).

-- ---------------------------------------------------------------------------
-- instance_template  (binds map 669 to the ported InstanceMapScript)
-- ---------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 669;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (669, 0, 'instance_blackwing_descent', 0);

-- ---------------------------------------------------------------------------
-- instance_encounters  (DungeonEncounter ids 1022-1027; creditType 0 = kill creature)
-- ---------------------------------------------------------------------------
DELETE FROM `instance_encounters` WHERE `entry` BETWEEN 1022 AND 1027;
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
    (1022, 0, 41442, 0, 'Atramedes'),
    (1023, 0, 43296, 0, 'Chimaeron'),
    (1024, 0, 41570, 0, 'Magmaw'),
    (1025, 0, 41378, 0, 'Maloriak'),
    (1026, 0, 41376, 0, 'Nefarian''s End'),
    (1027, 0, 42180, 0, 'Omnotron Defense System');

-- ---------------------------------------------------------------------------
-- areatrigger_teleport  (entrance AT 6581 -> inside map 669; coords from the 4.3.4 client)
-- ---------------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` = 6581;
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (6581, 'Blackwing Descent - Entrance', 669, -345.872, -224.344, 193.127, 0);

-- ---------------------------------------------------------------------------
-- dungeon_access_template  (level gate, 4 difficulties 0=10N/1=25N/2=10H/3=25H)
-- TODO(heroic gate): retail gated 10H/25H behind achievement 4842. Add dungeon_access_requirements
-- rows (requirement_type=achievement) once a DC-authored heroic achievement id exists (see 13/DBC).
-- ---------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 669;
-- NOTE: dungeon_access_template.id is tinyint unsigned (max 255); stock uses 1..137, so BWD takes 138..141.
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (138, 669, 0, 85, 0, 0, 'Blackwing Descent - 10man Normal'),
    (139, 669, 1, 85, 0, 0, 'Blackwing Descent - 25man Normal'),
    (140, 669, 2, 85, 0, 0, 'Blackwing Descent - 10man Heroic'),
    (141, 669, 3, 85, 0, 0, 'Blackwing Descent - 25man Heroic');
