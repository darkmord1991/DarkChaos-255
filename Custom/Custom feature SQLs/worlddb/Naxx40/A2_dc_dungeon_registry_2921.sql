-- =====================================================================
-- Register Naxx-40 (map 2921) with the DC dungeon system
-- =====================================================================
-- Gives it a display name everywhere DC resolves one, and makes the
-- teleporter able to drop players at its entrance.
--
-- INSERT ORDER MATTERS. `dc_dungeon_mythic_profile` is the PARENT table:
--     dc_dungeon_setup.map_id      -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
--     dc_dungeon_entrances.dungeon_map -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
--     dc_mplus_featured_dungeons.map_id -> dc_dungeon_mythic_profile.map_id
-- so the profile row must be inserted FIRST or both children fail with
-- SQL error 1452 (foreign key constraint fails).
--
-- How the teleporter actually works (dc_mythicplus_portal_selector.cpp:204,
-- TeleportToDungeonEntranceByDungeonMap):
--   it reads `dc_dungeon_entrances` and teleports to entrance_map/x/y/z --
--   the WORLD-SIDE doorstep, NOT inside the instance.
-- That is exactly right here: it drops the player next to the runestone on
-- map 751, and the runestone's own script (`gobject_naxx40_tele`) then does
-- the level / attunement / raid-difficulty work and ports them in.
-- Because the teleporter never enters the map itself, this route CANNOT hit
-- the TRANSFER_ABORT_DIFFICULTY that a bare `.tele 2921` runs into.
-- =====================================================================

-- Deleting the parent cascades to both children, so this is the only cleanup needed.
DELETE FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 2921;

-- ---------------------------------------------------------------------
-- 1. dc_dungeon_mythic_profile - required by the foreign keys, kept INERT
--
--    Verified against the code, this row changes nothing about the 40-man:
--
--    * levels - `OnBeforeCreatureSelectLevel` (dc_mythicplus_core_scripts.cpp:166)
--      does NOT check the enabled flags, but only overrides the level when the
--      matching `*_level_*` column is > 0 ("0 = keep original"). All six are 0.
--
--    * HP / damage - `OnCreatureSelectLevel` (same file, ~line 222) DOES check
--      the flags and returns early:
--          case DUNGEON_DIFFICULTY_EPIC: if (!profile->mythicEnabled) return;
--      Both flags are 0, so the multipliers are never applied. (Note the loader
--      at dc_mythicplus_difficulty_scaling.cpp:82 silently defaults
--      mythicHealthMult to 3.0 when base_health_mult <= 1.0 - harmless here
--      precisely because the flag check returns before it is read. Do NOT set
--      mythic_enabled = 1 expecting base_health_mult = 1.0 to mean "no change".)
-- ---------------------------------------------------------------------
INSERT INTO `dc_dungeon_mythic_profile`
  (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
   `base_health_mult`, `base_damage_mult`,
   `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
   `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
   `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`)
VALUES
  (2921, 'Naxxramas (40)', 0, 0,
   1.0, 1.0,
   0, 0, 0,
   0, 0, 0,
   0, 0, 0, 0);

-- ---------------------------------------------------------------------
-- 2. dc_dungeon_setup - the name cache + gating flags
--    Read UNFILTERED by dc_addon_utils.h:407 (SELECT map_id, dungeon_name),
--    so this alone fixes "Dungeon 2921" showing instead of a real name.
--
--    Every *_enabled flag is 0 on purpose:
--      normal/heroic/mythic_enabled -> DC's 5-man H/M tier model does not
--          apply; the 40-man is a single raid tier that lives in the
--          RAID_DIFFICULTY_10MAN_HEROIC slot with its own tuning.
--      mythic_plus_enabled = 0      -> keeps it OUT of the seasonal M+ portal
--          (dc_mythicplus_portal_selector.cpp:266 filters on this) and out of
--          M+ scaling (dc_mythicplus_difficulty_scaling.cpp:198).
-- ---------------------------------------------------------------------
INSERT INTO `dc_dungeon_setup`
  (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`,
   `normal_enabled`, `heroic_enabled`, `heroic_scaling_mode`,
   `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`)
VALUES
  (2921, 'Naxxramas (40)', 0, 1,
   0, 0, 0,
   0, 0, NULL,
   'Vanilla 40-man special edition. Single tier in the RAID_DIFFICULTY_10MAN_HEROIC slot (spawnMask 4). Entered via the runestone on map 751 or the trigger in Stratholme. Not part of the H/M/M+ model.');

-- ---------------------------------------------------------------------
-- 3. dc_dungeon_entrances - the world-side doorstep
--    GO 361001 "Teleport To Naxxramas" sits at exactly these coordinates
--    in Plaguewood, DC Eastern Plaguelands (zone 4924) on map 751.
-- ---------------------------------------------------------------------
INSERT INTO `dc_dungeon_entrances`
  (`dungeon_map`, `entrance_map`, `entrance_x`, `entrance_y`, `entrance_z`, `entrance_o`, `comment`)
VALUES
  (2921, 751, 3123.26, -3869.36, 138.34, 0.2175,
   'Naxxramas (40) - runestone in Plaguewood, DC Eastern Plaguelands (map 751)');

-- ---------------------------------------------------------------------
-- 4. Verification
-- ---------------------------------------------------------------------
-- SELECT * FROM dc_dungeon_mythic_profile WHERE map_id      = 2921;  -- all flags/levels 0
-- SELECT * FROM dc_dungeon_setup          WHERE map_id      = 2921;
-- SELECT * FROM dc_dungeon_entrances      WHERE dungeon_map = 2921;
-- -- must stay EMPTY - the seasonal M+ portal list:
-- SELECT s.map_id, s.dungeon_name FROM dc_dungeon_setup s
--   INNER JOIN dc_dungeon_entrances e ON e.dungeon_map = s.map_id
--   WHERE s.is_unlocked = 1 AND s.mythic_plus_enabled = 1 AND s.map_id = 2921;

-- ---------------------------------------------------------------------
-- Not done here, on purpose
-- ---------------------------------------------------------------------
-- `kDungeonTeleporterOptions` in dc_mythicplus_portal_selector.cpp:41 is a
-- hardcoded 11-entry array used only by the LEGACY gossip path (the addon UI
-- builds its list from dc_dungeon_setup). Adding 2921 there needs a C++ change
-- and a rebuild; skipped until you decide the 40-man belongs in that menu.
