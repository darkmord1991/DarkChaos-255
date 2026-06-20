-- Dark Chaos Guild Housing - Normalize map 1409 spawns to phase 1 (Phase B)
-- Under the instancing model, isolation comes from the instance id, not phasing,
-- so every shared default/styling/functional spawn on the guild-house map should
-- sit on the normal phase and load into every guild's instance. spawnMask is
-- already 1 (dungeon-normal) on these rows, which is what makes them replicate
-- into each instance. Previously most used phaseMask=4294967295 (all phases);
-- collapsing to 1 is purely canonical - bit 0 was already set, so instance
-- players (phaseMask 1) already saw them. Verified via MCP: 65 creatures +
-- 22 gameobjects on map 1409, all spawnMask=1, none using a per-guild phase bit.

UPDATE `creature` SET `phaseMask` = 1 WHERE `map` = 1409;
UPDATE `gameobject` SET `phaseMask` = 1 WHERE `map` = 1409;
