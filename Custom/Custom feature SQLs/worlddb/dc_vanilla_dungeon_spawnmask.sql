-- Ensures all vanilla 5-player dungeons spawn creatures and gameobjects on Normal, Heroic, and Mythic difficulties.
-- The bitmask uses: 1 (Normal), 2 (Heroic), 4 (Mythic/Epic reuse).
-- List derived from Map.dbc entries with ExpansionID = 0 and InstanceType = 1.

SET @VANILLA_DUNGEON_MAPS := '33,34,36,43,47,48,70,90,109,129,189,209,229,230,289,329,349,389,429';

-- Update creatures
UPDATE `creature`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @VANILLA_DUNGEON_MAPS);

-- Update gameobjects (chests, doors, etc.)
UPDATE `gameobject`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @VANILLA_DUNGEON_MAPS);
