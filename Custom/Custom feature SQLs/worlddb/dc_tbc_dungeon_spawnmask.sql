-- Ensures all Burning Crusade 5-player dungeons spawn creatures and gameobjects on Normal, Heroic, and Mythic difficulties.
-- The bitmask uses: 1 (Normal), 2 (Heroic), 4 (Mythic/Epic reuse).
-- List derived from Map.dbc entries with ExpansionID = 1 and InstanceType = 1.

SET @TBC_DUNGEON_MAPS := '269,540,542,543,545,546,547,552,553,554,555,556,557,558,560,585';

-- Update creatures
UPDATE `creature`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @TBC_DUNGEON_MAPS);

-- Update gameobjects (chests, doors, etc.)
UPDATE `gameobject`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @TBC_DUNGEON_MAPS);
