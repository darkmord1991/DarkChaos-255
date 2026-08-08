-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 7: DC difficulty + Mythic+ registry
--
-- ORDER MATTERS. `dc_dungeon_mythic_profile` is the PARENT table:
--     dc_dungeon_setup.map_id          -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
--     dc_dungeon_entrances.dungeon_map -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
--     dc_mplus_featured_dungeons.map_id-> dc_dungeon_mythic_profile.map_id
-- so the profile row must be INSERTed first, and the child rows DELETEd first.
-- (`dc_mplus_dungeons` has no foreign key and is independent.)
--
-- Normal difficulty uses the LEVELS IN THE DATABASE (92-96, set by 01_templates.sql).
-- Heroic and Mythic are re-levelled at runtime by MythicDifficultyScaling::CalculateCreatureLevel
-- from the columns below. Verified against that function before choosing values:
--
--   isBoss  = rank 3 (WORLDBOSS) or rank 2 (RAREELITE)  -> uses *_level_boss
--   isElite = rank 1 (ELITE)                            -> uses *_level_elite
--   else                                                -> uses *_level_normal
--   a value of 0 means "keep the database level"
--
-- BFD follows the AzerothCore convention where 5-man bosses are plain rank 1, exactly like
-- their trash (only Lorgus Jett is rank 2). So in practice:
--   heroic -> almost everything becomes 129, Lorgus Jett 130
--   mythic -> everything becomes 130
-- That is the "heroic/mythic at 130" the design called for. Raising bosses to rank 3 to
-- separate them would also change their HP/damage rate multipliers and mark them as world
-- bosses, so the ranks are left at AzerothCore's values on purpose.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Clear children first, then the parent. Deleting the parent alone would cascade, but
-- doing it explicitly keeps the intent obvious and the file safe to re-run.
-- -------------------------------------------------------------------------------------
DELETE FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 820;
DELETE FROM `dc_dungeon_setup` WHERE `map_id` = 820;
DELETE FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 820;

-- -------------------------------------------------------------------------------------
-- PARENT: dc_dungeon_mythic_profile -- the actual scaling numbers
--
-- Multipliers are deliberately modest (1.35 / 1.2, the same as the WotLK dungeons) because
-- the +34 level jump from normal to mythic already produces a very large stat increase on
-- its own. The vanilla dungeons' 3.0 / 2.0 exists to compensate for a 24 -> 80 jump applied
-- to level-24 base stats; stacking that here would be brutal.
--
-- loot_ilvl is informational only -- the scaler loads it but never reads it.
-- -------------------------------------------------------------------------------------
INSERT INTO `dc_dungeon_mythic_profile`
    (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
     `base_health_mult`, `base_damage_mult`,
     `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
     `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
     `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
    (820, 'Blackfathom Deeps (Ashenvale)', 1, 1,
     1.35, 1.2,
     128, 129, 130,
     130, 130, 130,
     12, 3, 264, 300311);

-- -------------------------------------------------------------------------------------
-- CHILD: dc_dungeon_setup -- which difficulties are offered at all
-- heroic_scaling_mode 0 matches the vanilla-era dungeons, which (like this one) carry
-- explicit heroic level overrides; the WotLK dungeons use mode 2 with no level override.
-- -------------------------------------------------------------------------------------
INSERT INTO `dc_dungeon_setup`
    (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`,
     `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
    (820, 'Blackfathom Deeps (Ashenvale)', 0, 1, 1, 1, 0, 1, 1, 1,
     'Map-48 clone for the map-750 Ashenvale band; normal 92-96, heroic/mythic 130');

-- -------------------------------------------------------------------------------------
-- CHILD: dc_dungeon_entrances -- used by the teleporter NPC (Mythic Steward Alendra,
-- entry 99001) to send a group to the dungeon's world-side door.
-- -------------------------------------------------------------------------------------
INSERT INTO `dc_dungeon_entrances`
    (`dungeon_map`, `entrance_map`, `entrance_x`, `entrance_y`, `entrance_z`, `entrance_o`, `comment`) VALUES
    (820, 750, 4285.0, 775.0, -20.0, 3.90, 'Blackfathom Deeps (Ashenvale) - Zoram Strand, map 750');

-- -------------------------------------------------------------------------------------
-- INDEPENDENT: dc_mplus_dungeons -- the Mythic+ registry (no foreign key). Until now this
-- held only the 16 WotLK dungeons; every pre-WotLK entry in dc_dungeon_setup has
-- mythic_plus_enabled = 0.
--
-- boss_count 7: Ghamoo-ra, Lady Sarevess, Gelihast, Old Serra'kis, Twilight Lord Kelris,
-- Aku'mai, plus Lorgus Jett. Baron Aquanis is summoned from the Fathom Stone and optional,
-- so he is not counted toward the route.
-- -------------------------------------------------------------------------------------
DELETE FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 820;
INSERT INTO `dc_mplus_dungeons`
    (`dungeon_id`, `dungeon_name`, `short_name`, `min_level`, `base_timer`,
     `trash_count`, `boss_count`, `difficulty_rating`, `season_enabled`,
     `teleport_x`, `teleport_y`, `teleport_z`, `teleport_o`) VALUES
    (820, 'Blackfathom Deeps (Ashenvale)', 'BFDA', 130, 2100, 0, 7, 4, 1,
     -151.89, 106.96, -39.87, 1.15);

-- -------------------------------------------------------------------------------------
-- Report -- all four must read 1
-- -------------------------------------------------------------------------------------
SELECT 'dc_dungeon_mythic_profile (parent)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 820
UNION ALL SELECT 'dc_dungeon_setup', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_setup` WHERE `map_id` = 820
UNION ALL SELECT 'dc_dungeon_entrances', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 820
UNION ALL SELECT 'dc_mplus_dungeons', CAST(COUNT(*) AS CHAR) FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 820;
