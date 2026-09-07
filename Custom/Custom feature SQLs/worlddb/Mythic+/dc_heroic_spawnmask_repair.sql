-- =====================================================================
-- Heroic spawnMask repair for the Classic / TBC dungeons
-- =====================================================================
-- Apply against: acore_world. Safe to re-run.
--
-- WHY
-- ---------------------------------------------------------------------
-- spawnMask decides which difficulties a spawn appears in: bit 1 Normal,
-- bit 2 Heroic, bit 4 Mythic. dc_vanilla_dungeon_spawnmask.sql and
-- dc_tbc_dungeon_spawnmask.sql already set 7 across these maps, but both
-- carry a hardcoded map list and rows added since then were never
-- covered. The result is spawns that exist on Normal and silently vanish
-- on Heroic.
--
-- Shadowfang Keep is the bad one. Its doors all spawn at Heroic -
-- Courtyard Door (18895), Sorcerer's Gate (18972), Arugal's Lair
-- (18971), three Cell Doors - but three of the five levers that open
-- them do not:
--
--     18900  Lever   spawnMask 1
--     18901  Lever   spawnMask 1
--     101811 Lever   spawnMask 1
--
-- Doors present, levers absent: Heroic Shadowfang Keep cannot be
-- completed.
--
-- Deadmines is the same class of bug but self-cancelling - all six doors
-- AND all four Door Levers are spawnMask 1, so nothing blocks the path.
-- It still wants fixing, because the encounter flow (Mr. Smite's ship,
-- the Iron Clad Door) is built around those doors existing.
--
-- Remaining: Blackrock Depths' Heart of the Mountain chest, and four
-- Firebrand trash spawns in Lower Blackrock Spire.
--
-- WHAT IS DELIBERATELY LEFT ALONE
-- ---------------------------------------------------------------------
-- Not everything with a narrow mask is a bug, so this does NOT blanket
-- set 7:
--
--   * Font of Power (GO 700001) is spawnMask 4 on fifteen WotLK maps -
--     the Mythic+ keystone pedestal, intentionally Mythic-only. It has
--     no Normal bit, which is how the rule below skips it.
--   * Teleporter (creature 800002) and the Naxx40 Stratholme entrance
--     trigger (creature 351097) are DC custom spawns with deliberate
--     difficulty scoping. Excluded by the entry >= 300000 rule.
--   * The 8xx DC dungeons are excluded by map_id < 800; they run their
--     own difficulty model.
--
-- So the rule is: a spawn that exists on Normal, on a Classic/TBC map
-- that has Heroic enabled, and is not a DC custom entry, should also
-- exist on Heroic and Mythic.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Creatures
-- ---------------------------------------------------------------------
UPDATE `creature` c
JOIN `dc_dungeon_setup` s ON s.`map_id` = c.`map`
SET c.`spawnMask` = c.`spawnMask` | 2 | 4
WHERE s.`heroic_enabled` = 1
  AND s.`expansion` IN (0, 1)
  AND s.`map_id` < 800
  AND (c.`spawnMask` & 1) = 1
  AND (c.`spawnMask` & 6) <> 6
  AND c.`id` < 300000;

-- ---------------------------------------------------------------------
-- GameObjects - doors and levers are the ones that actually block a run
-- ---------------------------------------------------------------------
UPDATE `gameobject` g
JOIN `dc_dungeon_setup` s ON s.`map_id` = g.`map`
SET g.`spawnMask` = g.`spawnMask` | 2 | 4
WHERE s.`heroic_enabled` = 1
  AND s.`expansion` IN (0, 1)
  AND s.`map_id` < 800
  AND (g.`spawnMask` & 1) = 1
  AND (g.`spawnMask` & 6) <> 6
  AND g.`id` < 300000;


-- =====================================================================
-- Verification
-- =====================================================================
-- Nothing on a Heroic-enabled Classic/TBC map may exist on Normal but
-- not on Heroic (expect 0 rows):
--
--   SELECT 'creature' AS src, c.map, c.guid, c.id, c.spawnMask
--   FROM creature c JOIN dc_dungeon_setup s ON s.map_id = c.map
--   WHERE s.heroic_enabled = 1 AND s.expansion IN (0,1) AND s.map_id < 800
--     AND (c.spawnMask & 1) = 1 AND (c.spawnMask & 2) = 0 AND c.id < 300000
--   UNION ALL
--   SELECT 'gameobject', g.map, g.guid, g.id, g.spawnMask
--   FROM gameobject g JOIN dc_dungeon_setup s ON s.map_id = g.map
--   WHERE s.heroic_enabled = 1 AND s.expansion IN (0,1) AND s.map_id < 800
--     AND (g.spawnMask & 1) = 1 AND (g.spawnMask & 2) = 0 AND g.id < 300000;
--
-- Shadowfang Keep's five levers must all be Heroic-visible (expect 5
-- rows, every spawnMask with bit 2 set):
--
--   SELECT g.guid, g.id, g.spawnMask FROM gameobject g
--   WHERE g.map = 33 AND g.id IN (18899, 18900, 18901, 101811, 101812);
--
-- The Mythic+ pedestals must still be Mythic-only (expect spawnMask
-- without bit 2 on every row):
--
--   SELECT map, guid, spawnMask FROM gameobject WHERE id = 700001;
-- =====================================================================
