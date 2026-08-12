-- =====================================================================================
-- Timbermaw Hold (map 819) -- DC difficulty profile, access gates and registries
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
-- map-id range (33-560 vanilla, 574-650 WotLK) and 819 falls outside both, so leaving them
-- at default would silently inherit the WotLK numbers.
--
-- LEVEL COLUMNS ARE ALL ZERO ON PURPOSE. This is a raid whose creatures are ALREADY level 130
-- in the database, so there is nothing for CalculateCreatureLevel to raise them to -- 0 means
-- "keep the database level". Heroic and Mythic therefore take their difficulty from the
-- health/damage multipliers alone, which is why those are 2.0 / 1.6 here rather than the
-- 1.35 / 1.2 a levelling dungeon uses.
--
-- =====================================================================================


DELETE FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 819;
DELETE FROM `dc_dungeon_setup` WHERE `map_id` = 819;
DELETE FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 819;

INSERT INTO `dc_dungeon_mythic_profile`
    (`map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
     `base_health_mult`, `base_damage_mult`,
     `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
     `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
     `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`) VALUES
    (819, 'Timbermaw Hold', 1, 1, 2.00, 1.60, 0, 0, 0, 0, 0, 0, 20, 5, 450, 300311);

INSERT INTO `dc_dungeon_setup`
    (`map_id`, `dungeon_name`, `expansion`, `is_unlocked`, `normal_enabled`, `heroic_enabled`,
     `heroic_scaling_mode`, `mythic_enabled`, `mythic_plus_enabled`, `season_lock`, `notes`) VALUES
    (819, 'Timbermaw Hold', 0, 1, 1, 1, 2, 1, 0, 1,
     '20-man raid (Nightmares of Ursol) - every difficulty is level 130');

INSERT INTO `dc_dungeon_entrances`
    (`dungeon_map`, `entrance_map`, `entrance_x`, `entrance_y`, `entrance_z`, `entrance_o`, `comment`) VALUES
    (819, 750, 7015.0, -2145.0, 587.0, 0.0, 'Timbermaw Hold - world-side door on map 750');

-- Deliberately NOT in `dc_mplus_dungeons`: Mythic+ keystones are built for 5-man
-- content and this is a 20-man raid, so mythic_plus_enabled stays 0 above.
DELETE FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 819;

-- Access gates, one row per difficulty. `dungeon_access_template`.`id` is tinyint
-- (ceiling 255); the live max was 151 before these.
DELETE FROM `dungeon_access_template` WHERE `map_id` = 819;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (146, 819, 0, 128, 0, 0, 'Timbermaw Hold - Normal'),
    (154, 819, 1, 130, 0, 0, 'Timbermaw Hold - Heroic'),
    (155, 819, 2, 130, 0, 0, 'Timbermaw Hold - Mythic');

-- Quest-master follower. GetQuestMasterEntryForMap() returns 0 on a miss and no
-- follower ever appears, so this row is the entire gate. 700100 = Universal Quest Master.
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 819;
INSERT INTO `dc_dungeon_npc_mapping`
    (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`, `enabled`, `display_id`) VALUES
    (819, 700100, 'Timbermaw Hold', 0, 128, 130, 1, 16466);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'mythic_profile (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `dc_dungeon_mythic_profile` WHERE `map_id` = 819
UNION ALL SELECT 'dungeon_setup (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_setup` WHERE `map_id` = 819
UNION ALL SELECT 'dungeon_entrances (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_entrances` WHERE `dungeon_map` = 819
UNION ALL SELECT 'mplus_dungeons (want 0)', CAST(COUNT(*) AS CHAR) FROM `dc_mplus_dungeons` WHERE `dungeon_id` = 819
UNION ALL SELECT 'access rows (want 3)', CAST(COUNT(*) AS CHAR) FROM `dungeon_access_template` WHERE `map_id` = 819
UNION ALL SELECT 'npc_mapping (want 1)', CAST(COUNT(*) AS CHAR) FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 819
UNION ALL SELECT 'access id used by another map (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dungeon_access_template` WHERE `id` IN (146, 154, 155) AND `map_id` <> 819;
