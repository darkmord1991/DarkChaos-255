-- =====================================================================================
-- DC Teleporter entries for the four new instances reached from map 750:
--   Blackfathom Deeps (Ashenvale)  map 820
--   Timbermaw Hold                 map 819
--   Crescent Grove                 map 823
--   Emerald Sanctum                map 824
--
-- Table shape (read by src/server/scripts/DC/Teleporters/dc_teleporter.cpp:117):
--     id, parent, type, faction, security_level, icon, name, map, x, y, z, o
--
--   * parent 0 + type 1              = a category (map/x/y/z/o stay NULL)
--   * parent <category> + type 2     = a destination
--   * faction -1                     = both factions
--   * security_level                 = compared per row against the player's GM level
--                                      (`GetSecurity() < option.SecurityLevel` -> hidden)
--   * icon 2                         = the icon BWD and Castle Nathria already use
--
-- Placed under category 800 "Custom Dungeons", matching the two entries already there
-- (801 Blackwing Descent map 669, 802 Castle Nathria map 2296), so this follows the
-- established convention of teleporting straight into the instance rather than to the
-- world-side door.
--
-- >>> NOTE, AND IT IS NOT SOMETHING THIS FILE CHANGES ON ITS OWN <<<
-- Category 800 itself carries security_level = 1, so the whole "Custom Dungeons" menu --
-- Blackwing Descent and Castle Nathria included -- is only visible to GMs today. These two
-- rows are security_level 0, but a player still will not see them while the parent is
-- gated. If you want them player-facing, open the category as well:
--
--     UPDATE `dc_teleporter` SET `security_level` = 0 WHERE `id` = 800;
--
-- That is left out of this file deliberately: it would also expose BWD and Castle Nathria,
-- which is a content decision, not a side effect this file should make for you.
--
-- Destinations are the same measured/known-good arrival points the gossip NPCs and the
-- entrance AreaTriggers use -- do not "tidy" them into rounder numbers:
--   * BFD 820: Blizzard's own arrival, lifted from areatrigger_teleport 257 (target map 48).
--     Map 820 is a byte-clone of 48, so this is guaranteed to be on the floor.
--   * Timbermaw 819: measured in game with `.gps`. GroundZ there is 42.4 against FloorZ
--     222.36 -- the raid is WMO interior suspended ~180 yd above the terrain, so a Z guessed
--     from terrain or a WMO bounding box lands under the floor. It already did once.
--   * Crescent Grove 823 / Emerald Sanctum 824: COMPUTED from the deployed ADTs with the
--     worldserver's own MCVT -> V9/V8 -> getHeightFromFloat maths (sampler calibrated to a
--     median 0.00 error against live map-750 spawn Z). Both maps are open terrain with no
--     suspended WMO interior, so terrain height IS floor height here -- the Timbermaw trap
--     does not apply. The Sanctum's 30.10 is corroborated by the source pack's own
--     walk-out AreaTrigger sitting at 30.1.
-- =====================================================================================

-- DELETE covers the NAMES as well as the ids: the loader rejects duplicate labels under the
-- same parent (dc_teleporter.cpp:87), so a re-run under a different id would otherwise leave
-- a stale twin behind and log a duplicate-label warning at startup.
DELETE FROM `dc_teleporter`
    WHERE `id` IN (803, 804, 805, 806)
       OR (`parent` = 800 AND `name` IN ('Blackfathom Deeps (Ashenvale)', 'Timbermaw Hold',
                                         'Crescent Grove', 'Emerald Sanctum'));

INSERT INTO `dc_teleporter`
    (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
    (803, 800, 2, -1, 0, 2, 'Blackfathom Deeps (Ashenvale)', 820, -151.89, 106.96, -39.87, 4.53),
    (804, 800, 2, -1, 0, 2, 'Timbermaw Hold', 819, -8153.15, -3456.87, 222.4, 0.306),
    (805, 800, 2, -1, 0, 2, 'Crescent Grove', 823, 585.6, 96.7, 276.92, 5.498),
    (806, 800, 2, -1, 0, 2, 'Emerald Sanctum', 824, 2767.4, 2959.0, 30.1, 0.785);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'new destinations (want 4)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_teleporter` WHERE `id` IN (803, 804, 805, 806)
UNION ALL SELECT 'parent category 800 exists (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `id` = 800 AND `parent` = 0
UNION ALL SELECT 'duplicate labels under 800 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT `name` FROM `dc_teleporter` WHERE `parent` = 800
          GROUP BY `name` HAVING COUNT(*) > 1) d
UNION ALL SELECT 'destinations pointing at a map with no instance_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` t LEFT JOIN `instance_template` i ON i.`map` = t.`map`
    WHERE t.`id` IN (803, 804, 805, 806) AND i.`map` IS NULL
UNION ALL SELECT 'category 800 visible to non-GMs (0 = GM only)', CAST(IF(`security_level` = 0, 1, 0) AS CHAR)
    FROM `dc_teleporter` WHERE `id` = 800;
