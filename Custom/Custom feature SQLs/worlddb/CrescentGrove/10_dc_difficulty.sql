-- =====================================================================================
-- Crescent Grove (map 823) -- DC difficulty profile, access gates and registries
--
-- ORDER MATTERS. `dc_dungeon_mythic_profile` is the PARENT:
--     dc_dungeon_setup.map_id          -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
--     dc_dungeon_entrances.dungeon_map -> dc_dungeon_mythic_profile.map_id  (ON DELETE CASCADE)
-- so children are DELETEd first and the parent INSERTed first. `dc_mplus_dungeons` and
-- `dc_dungeon_npc_mapping` have no foreign key and are independent.
--
-- MythicDifficultyScaling::CalculateCreatureLevel picks the column by RANK:
--     rank 3 or 2 -> *_level_boss ; rank 1 -> *_level_elite ; else *_level_normal
--     0 means "keep the database level". Normal difficulty never re-levels.
--
-- base_health_mult / base_damage_mult MUST be set explicitly. GetExpansionForMap() buckets by
-- map-id range (33-560 vanilla, 574-650 WotLK) and 823 falls outside both, so leaving them
-- at default would silently inherit the WotLK numbers.
--
-- =====================================================================================


DELETE FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 823;
DELETE FROM `dc_dungeon_setup` WHERE `map_id` = 823;
DELETE FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 823;

INSERT INTO `dc_dungeon_mythic_profile`
    (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
     `base_health_mult`, `base_damage_mult`,
     `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
     `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
     `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
    (823, 'Crescent Grove', 1, 1, 1.35, 1.20, 128, 129, 130, 130, 130, 130, 12, 3, 450, 300311);

INSERT INTO `dc_dungeon_setup`
    (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`,
     `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
    (823, 'Crescent Grove', 0, 1, 1, 1, 0, 1, 1, 1,
     'Turtle 5-man on the map-750 Ashenvale band, normal 95-96, heroic and mythic 130');

INSERT INTO `dc_dungeon_entrances`
    (`dungeon_map`, `entrance_map`, `entrance_x`, `entrance_y`, `entrance_z`, `entrance_o`, `comment`) VALUES
    (823, 750, 1707.48, -1289.88, 173.694, 5.498, 'Crescent Grove - world-side door on map 750');

-- Mythic+ registry. Eligibility is `profile exists && mythic_enabled` AND
-- dc_dungeon_setup.is_unlocked && mythic_plus_enabled && (season_lock = 0 OR = season).
-- `dc_mplus_featured_dungeons` is display-only and gates nothing at all.
DELETE FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 823;
INSERT INTO `dc_mplus_dungeons`
    (`dungeon_id`, `dungeon_name`, `short_name`, `min_level`, `base_timer`,
     `trash_count`, `boss_count`, `difficulty_rating`, `season_enabled`,
     `teleport_x`, `teleport_y`, `teleport_z`, `teleport_o`) VALUES
    (823, 'Crescent Grove', 'CRGV', 130, 2100, 0, 5, 3, 1, 585.6, 96.7, 276.92, 5.498);

-- Access gates, one row per difficulty. `dungeon_access_template`.`id` is tinyint
-- (ceiling 255); the live max was 151 before these.
DELETE FROM `dungeon_access_template` WHERE `map_id` = 823;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (150, 823, 0, 88, 0, 0, 'Crescent Grove - Normal'),
    (152, 823, 1, 125, 0, 0, 'Crescent Grove - Heroic'),
    (153, 823, 2, 130, 0, 0, 'Crescent Grove - Mythic');

-- Quest-master follower. GetQuestMasterEntryForMap() returns 0 on a miss and no
-- follower ever appears, so this row is the entire gate. 700100 = Universal Quest Master.
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 823;
INSERT INTO `dc_dungeon_npc_mapping`
    (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`, `enabled`, `display_id`) VALUES
    (823, 700100, 'Crescent Grove', 0, 88, 130, 1, 16466);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'mythic_profile (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 823
UNION ALL SELECT 'dungeon_setup (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_setup` WHERE `map_id` = 823
UNION ALL SELECT 'dungeon_entrances (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 823
UNION ALL SELECT 'mplus_dungeons (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 823
UNION ALL SELECT 'access rows (want 3)', CAST(COUNT(*) AS CHAR) FROM `dungeon_access_template` WHERE `map_id` = 823
UNION ALL SELECT 'npc_mapping (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 823
UNION ALL SELECT 'access id used by another map (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dungeon_access_template` WHERE `id` IN (150, 152, 153) AND `map_id` <> 823;
