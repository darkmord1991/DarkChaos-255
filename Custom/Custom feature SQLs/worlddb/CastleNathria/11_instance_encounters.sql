-- Castle Nathria (map 2296) — instance_encounters + dungeon_access_template.
--
-- instance_encounters references DungeonEncounter.dbc rows 1028-1037 (added in
-- Custom/CSV DBC/DungeonEncounter.csv, compiled + deployed to patch-4 + patch-enGB-3 + synced to the
-- WarcraftXLHost candidate dirs this session). creditEntry = the boss creature entry that grants kill
-- credit for that encounter (creditType 0 = kill a specific creature). Council of Blood and Stone Legion
-- Generals are multi-body encounters; kill credit is wired to ONE representative boss entry each
-- (Baroness Frieda / General Kaal) per this fork's single-creditEntry-per-encounter convention (matches
-- the BlackwingDescent precedent) — the eventual C++ instance script can call SetBossState for the
-- shared encounter after all bodies die, independent of which single entry this credit points at.
--
-- dungeon_access_template: id is tinyint unsigned (max 255); BlackwingDescent took 138-141, so Nathria
-- takes the next free block, 142-145. min_level 80 matches this fork's custom-raid level convention
-- (see BlackwingDescent's own 138-141 rows). No dungeon_access_requirements rows yet (no heroic-gating
-- achievement authored for this raid); add later if/when one exists.
--
-- Apply against acore_world.

-- ---------------------------------------------------------------------------
-- instance_encounters  (DungeonEncounter ids 1028-1037; creditType 0 = kill creature)
-- ---------------------------------------------------------------------------
DELETE FROM `instance_encounters` WHERE `entry` BETWEEN 1028 AND 1037;
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
    (1028, 0, 164406, 0, 'Shriekwing'),
    (1029, 0, 165066, 0, 'Huntsman Altimor'),
    (1030, 0, 164261, 0, 'Hungering Destroyer'),
    (1031, 0, 165759, 0, 'Sun King''s Salvation'),
    (1032, 0, 166644, 0, 'Artificer Xy''mox'),
    (1033, 0, 165521, 0, 'Lady Inerva Darkvein'),
    (1034, 0, 166969, 0, 'Council of Blood'),
    (1035, 0, 164407, 0, 'Sludgefist'),
    (1036, 0, 168112, 0, 'Stone Legion Generals'),
    (1037, 0, 167406, 0, 'Sire Denathrius');

-- ---------------------------------------------------------------------------
-- dungeon_access_template  (level gate, 4 difficulties 0=10N/1=25N/2=10H/3=25H)
-- ---------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 2296;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (142, 2296, 0, 80, 0, 0, 'Castle Nathria - 10man Normal'),
    (143, 2296, 1, 80, 0, 0, 'Castle Nathria - 25man Normal'),
    (144, 2296, 2, 80, 0, 0, 'Castle Nathria - 10man Heroic'),
    (145, 2296, 3, 80, 0, 0, 'Castle Nathria - 25man Heroic');
