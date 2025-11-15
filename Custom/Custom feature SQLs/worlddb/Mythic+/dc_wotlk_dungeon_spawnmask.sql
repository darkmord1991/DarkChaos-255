-- Ensures all Wrath of the Lich King 5-player dungeons spawn creatures and gameobjects on Normal, Heroic, and Mythic difficulties.
-- The bitmask uses: 1 (Normal), 2 (Heroic), 4 (Mythic/Epic reuse).
-- List derived from Map.dbc entries with ExpansionID = 2 and InstanceType = 1.

SET @WOTLK_DUNGEON_MAPS := '574,575,576,578,595,599,600,601,602,604,608,619,632,650,658,668';

-- Update creatures
UPDATE `creature`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @WOTLK_DUNGEON_MAPS);

-- Update gameobjects (chests, doors, etc.)
UPDATE `gameobject`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @WOTLK_DUNGEON_MAPS);
