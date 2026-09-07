-- =====================================================================
-- Heroic tier: the three dungeons the earlier files missed
-- =====================================================================
-- Apply against: acore_world. Safe to re-run.
--
-- Apply AFTER dc_heroic_classic_tbc_scaling.sql and
-- dc_heroic_dungeonfinder_access.sql - this file extends them to three
-- maps they could not see.
--
-- WHY
-- ---------------------------------------------------------------------
-- dc_heroic_dungeonfinder_access.sql and dc_heroic_classic_tbc_scaling.sql
-- both drive off dc_dungeon_setup. The Group Finder catalog does not: it
-- admits any 5-man map with an EPIC MapDifficulty.dbc row, which is 56
-- dungeons, while dc_dungeon_setup describes 55 - and they are not the
-- same 55. Three catalog dungeons have no setup row at all, so every fix
-- so far skipped them:
--
--     389  Ragefire Chasm         access rows: d0 min 8   -> "Heroic - Lv 8-23"
--     821  Stratholme (DarkChaos) access rows: d0 min 45  -> "Heroic - Lv 45-60"
--     822  Scholomance (DarkChaos)access rows: d0 min 45  -> "Heroic - Lv 45-60"
--
-- Those are the brackets the client actually showed on the Heroic tab.
-- Worse than cosmetic: with no dc_dungeon_mythic_profile row,
-- MythicDifficultyScaling::GetDungeonProfile returns null for them, so
-- the scaling hook AND the heroic loot hook both bail out early. They
-- were level-13 / level-45 dungeons wearing a "Heroic" label, dropping
-- stock loot.
--
-- All three carry creature_template.exp = 0, so they belong on the same
-- Classic curve as the rest:
--
--     389  12 templates, levels 13-16
--     821  56 templates, levels 1-80   (Classic-era clone, not the 8xx band)
--     822  45 templates, levels 1-80   (Classic-era clone, not the 8xx band)
--
-- WHAT IS DELIBERATELY LEFT OUT
-- ---------------------------------------------------------------------
--   * 825 Shadowfang Keep (Cataclysm) is also absent from dc_dungeon_setup
--     but already has its own access rows at d0 80 / d1 85 / d2 85. It is
--     an 85-tier dungeon by somebody's deliberate choice, not part of the
--     level-80 Classic tier, so it is not touched here. It has no
--     dc_dungeon_mythic_profile row either, which means it currently gets
--     no scaling and no heroic loot - decide its tier before wiring it up.
--   * 820 / 823 (Ashenvale band) and 819 / 824 (raids) stay on their own
--     level-125/130 model.
--   * spawnMask is NOT touched on 821/825. Their Normal-only spawns are
--     the Love is in the Air event (Apothecary Hummel, Valentine bunnies,
--     perfume neutralizers, chemistry sets) plus a Stratholme Exit and a
--     Teleporter - all correctly scoped. Forcing them heroic-visible
--     would spawn the holiday boss event inside a heroic run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- ORDER AND UPSERTS MATTER HERE - dc_dungeon_mythic_profile is a PARENT
-- ---------------------------------------------------------------------
-- dc_dungeon_mythic_profile.map_id is referenced by three child tables,
-- all ON DELETE CASCADE:
--
--     dc_dungeon_setup.map_id            -> dc_dungeon_mythic_profile.map_id
--     dc_dungeon_entrances.dungeon_map   -> dc_dungeon_mythic_profile.map_id
--     dc_mplus_featured_dungeons.map_id  -> dc_dungeon_mythic_profile.map_id
--
-- Two consequences, both of which bit the first draft of this file:
--
--   1. The profile row must be INSERTED FIRST. Inserting dc_dungeon_setup
--      before its parent fails with errno 1452, "Cannot add or update a
--      child row: a foreign key constraint fails".
--   2. These are upserts, NOT delete-and-reinsert. Deleting a profile row
--      cascades into all three children - so a re-run would silently
--      destroy that dungeon's entrance and featured-dungeon rows. Right
--      now these three maps have none (the FK makes that impossible while
--      the parent is absent), but that stops being true the moment
--      someone adds an entrance for them.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 1) dc_dungeon_mythic_profile (parent) - without this
--    GetDungeonProfile returns null and both the scaling hook and the
--    heroic loot hook return early.
--    Values match the Classic block after dc_heroic_classic_tbc_scaling:
--    80/81/82 levels, 1.35 / 1.20 multipliers.
--    loot_ilvl mirrors each dungeon's closest peer - Ragefire Chasm sits
--    at the bottom with The Stockade (198); the two DarkChaos clones take
--    the same 219 their stock counterparts (329 / 289) carry.
-- ---------------------------------------------------------------------
INSERT INTO `dc_dungeon_mythic_profile`
  (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
   `base_health_mult`, `base_damage_mult`,
   `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
   `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
   `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`)
VALUES
  (389, 'Ragefire Chasm',          1, 1, 1.35, 1.20, 80, 81, 82, 80, 81, 82, 10, 3, 198, 300311),
  (821, 'Stratholme (DarkChaos)',  1, 1, 1.35, 1.20, 80, 81, 82, 80, 81, 82, 20, 4, 219, 300311),
  (822, 'Scholomance (DarkChaos)', 1, 1, 1.35, 1.20, 80, 81, 82, 80, 81, 82, 18, 4, 219, 300311)
ON DUPLICATE KEY UPDATE
  `name`                = VALUES(`name`),
  `heroic_enabled`      = VALUES(`heroic_enabled`),
  `mythic_enabled`      = VALUES(`mythic_enabled`),
  `base_health_mult`    = VALUES(`base_health_mult`),
  `base_damage_mult`    = VALUES(`base_damage_mult`),
  `heroic_level_normal` = VALUES(`heroic_level_normal`),
  `heroic_level_elite`  = VALUES(`heroic_level_elite`),
  `heroic_level_boss`   = VALUES(`heroic_level_boss`),
  `mythic_level_normal` = VALUES(`mythic_level_normal`),
  `mythic_level_elite`  = VALUES(`mythic_level_elite`),
  `mythic_level_boss`   = VALUES(`mythic_level_boss`),
  `death_budget`        = VALUES(`death_budget`),
  `wipe_budget`         = VALUES(`wipe_budget`),
  `loot_ilvl`           = VALUES(`loot_ilvl`),
  `token_reward`        = VALUES(`token_reward`);

-- ---------------------------------------------------------------------
-- 2) dc_dungeon_setup (child) - makes the dungeon visible to every DC
--    system that keys off this table (scaling, loot, portal selector,
--    curated names). Must come after step 1.
-- ---------------------------------------------------------------------
INSERT INTO `dc_dungeon_setup`
  (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`,
   `heroic_enabled`, `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`,
   `season_lock`, `notes`)
VALUES
  (389, 'Ragefire Chasm',          0, 1, 1, 1, 0, 1, 0, NULL, 'Vanilla baseline - added with the level-80 heroic tier'),
  (821, 'Stratholme (DarkChaos)',  0, 1, 1, 1, 0, 1, 0, NULL, 'DC Classic-era clone, exp 0 - shares the Classic level-80 heroic tier'),
  (822, 'Scholomance (DarkChaos)', 0, 1, 1, 1, 0, 1, 0, NULL, 'DC Classic-era clone, exp 0 - shares the Classic level-80 heroic tier')
ON DUPLICATE KEY UPDATE
  `dungeon_name`        = VALUES(`dungeon_name`),
  `expansion`           = VALUES(`expansion`),
  `is_unlocked`         = VALUES(`is_unlocked`),
  `normal_enabled`      = VALUES(`normal_enabled`),
  `heroic_enabled`      = VALUES(`heroic_enabled`),
  `heroic_scaling_mode` = VALUES(`heroic_scaling_mode`),
  `mythic_enabled`      = VALUES(`mythic_enabled`),
  `mythic_plus_enabled` = VALUES(`mythic_plus_enabled`),
  `notes`               = VALUES(`notes`);

-- ---------------------------------------------------------------------
-- 3) dungeon_access_template - Heroic and Mythic at level 80.
--    max_level 255 for the same reason as the main access file: 0 means
--    "ask LFGDungeons.dbc", and the DBC caps Ragefire Chasm at 23.
--    See dc_heroic_dungeonfinder_access.sql for the id budget note - the
--    table is TINYINT-keyed and this adds 6 more rows.
-- ---------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` IN (389, 821, 822) AND `difficulty` IN (1, 2);

SET @next_id := (SELECT IFNULL(MAX(`id`), 0) FROM `dungeon_access_template`);

INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
SELECT (@next_id := @next_id + 1), s.`map_id`, d.`difficulty`, 80, 255, 0,
       CONCAT(s.`dungeon_name`, IF(d.`difficulty` = 1, ' - Heroic', ' - Mythic'), ' (DC level 80 tier)')
FROM `dc_dungeon_setup` s
JOIN (SELECT 1 AS `difficulty` UNION ALL SELECT 2) d
WHERE s.`map_id` IN (389, 821, 822)
ORDER BY s.`map_id`, d.`difficulty`;


-- =====================================================================
-- Verification
-- =====================================================================
-- All three must now report 80/255 at difficulty 1 and 2 (expect 6 rows):
--
--   SELECT t.map_id, t.difficulty, t.min_level, t.max_level, t.comment
--   FROM dungeon_access_template t
--   WHERE t.map_id IN (389,821,822) AND t.difficulty IN (1,2)
--   ORDER BY t.map_id, t.difficulty;
--
-- Every dungeon the Group Finder catalog can show must now have both a
-- setup row and a profile row. The catalog is "InstanceType = 1 AND has
-- an EPIC MapDifficulty row", which cannot be expressed in SQL because
-- it lives in the DBCs - so check the three by hand (expect 1/1 each):
--
--   SELECT m.map_id,
--          (SELECT COUNT(*) FROM dc_dungeon_setup s WHERE s.map_id = m.map_id) AS in_setup,
--          (SELECT COUNT(*) FROM dc_dungeon_mythic_profile p WHERE p.map_id = m.map_id) AS in_profile
--   FROM (SELECT 389 map_id UNION ALL SELECT 821 UNION ALL SELECT 822) m;
--
-- Profiles must match the Classic block exactly (expect 0 rows):
--
--   SELECT map_id, name FROM dc_dungeon_mythic_profile
--   WHERE map_id IN (389,821,822)
--     AND (heroic_level_boss <> 82 OR ABS(base_health_mult - 1.35) > 0.001
--          OR ABS(base_damage_mult - 1.20) > 0.001);
--
-- The id ceiling still has to hold (expect max_id <= 255):
--
--   SELECT COUNT(*) rows_used, MAX(id) max_id, 255 - MAX(id) headroom
--   FROM dungeon_access_template;
--
-- 825 must stay on its own 85 tier, untouched (expect d0 80 / d1 85 / d2 85):
--
--   SELECT difficulty, min_level, max_level FROM dungeon_access_template
--   WHERE map_id = 825 ORDER BY difficulty;
-- =====================================================================
