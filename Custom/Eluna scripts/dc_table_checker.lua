--[[
    DC Database Table Checker (Eluna Lua)
    
    Checks for required DarkChaos custom tables at server startup
    and reports any missing tables. The server will continue to start,
    but features with missing tables will be disabled.
    
    Updated: 2026-01-13 (synced with world/acore_chars schema dumps)
    
    This script now strictly reflects the tables present in:
    - Custom/Custom feature SQLs/world schema.sql
    - Custom/Custom feature SQLs/acore_chars schema.sql
    
    Author: DarkChaos Development Team
]]

local DC_TABLE_CHECKER = {
    -- Configuration
    CONFIG = {
        ABORT_ON_CRITICAL = false,  -- Set to true to abort server start on missing critical tables
        LOG_LEVEL = "INFO",         -- DEBUG, INFO, WARN, ERROR
    },
    
    -- Table definitions: {schema, table_name, feature, critical}
    REQUIRED_TABLES = {
        {"acore_chars", "dc_account_outfits", "Collection System", false},
        {"acore_chars", "dc_account_transmog_cache", "Collection System", false},
        {"acore_chars", "dc_achievement_definitions", "Achievements", false},
        {"acore_chars", "dc_addon_protocol_daily", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_errors", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_log", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_stats", "Protocol Logging", false},
        {"acore_chars", "dc_aoeloot_accumulated", "AoE Loot", false},
        {"acore_chars", "dc_aoeloot_detailed_stats", "AoE Loot", true},
        {"acore_chars", "dc_aoeloot_preferences", "AoE Loot", true},
        {"acore_chars", "dc_artifact_mastery_events", "Artifacts", false},
        {"acore_chars", "dc_character_challenge_mode_log", "Challenge Mode", false},
        {"acore_chars", "dc_character_challenge_mode_stats", "Challenge Mode", false},
        {"acore_chars", "dc_character_challenge_modes", "Challenge Mode", true},
        {"acore_chars", "dc_character_difficulty_completions", "Dungeon Progress", false},
        {"acore_chars", "dc_character_difficulty_streaks", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_npc_respawn", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_progress", "Dungeon Progress", true},
        {"acore_chars", "dc_character_dungeon_quests_completed", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_statistics", "Dungeon Stats", false},
        {"acore_chars", "dc_character_outfits", "Collection System", true},
        {"acore_chars", "dc_character_prestige", "Prestige", true},
        {"acore_chars", "dc_character_prestige_log", "Prestige", false},
        {"acore_chars", "dc_character_prestige_stats", "Prestige", false},
        {"acore_chars", "dc_character_transmog", "Collection System", false},
        {"acore_chars", "dc_collection_achievements", "Collection System", false},
        {"acore_chars", "dc_collection_community_favorites", "Collection System", false},
        {"acore_chars", "dc_collection_community_outfits", "Collection System", true},
        {"acore_chars", "dc_collection_currency", "Collection System", false},
        {"acore_chars", "dc_collection_items", "Collection System", true},
        {"acore_chars", "dc_collection_migrations", "Collection System", false},
        {"acore_chars", "dc_collection_mount_speed", "Collection System", false},
        {"acore_chars", "dc_collection_shop_purchases", "Collection System", false},
        {"acore_chars", "dc_collection_stats", "Collection System", false},
        {"acore_chars", "dc_collection_wishlist", "Collection System", false},
        {"acore_chars", "dc_cross_system_achievement_triggers", "Cross-System", false},
        {"acore_chars", "dc_cross_system_config", "Cross-System", true},
        {"acore_chars", "dc_cross_system_events", "Cross-System", false},
        {"acore_chars", "dc_cross_system_multipliers", "Cross-System", false},
        {"acore_chars", "dc_duel_class_matchups", "Duel System", false},
        {"acore_chars", "dc_duel_history", "Duel System", false},
        {"acore_chars", "dc_duel_statistics", "Duel System", true},
        {"acore_chars", "dc_dungeon_instance_resets", "Dungeon System", false},
        {"acore_chars", "dc_group_finder_applications", "Group Finder", false},
        {"acore_chars", "dc_group_finder_event_signups", "Group Finder", false},
        {"acore_chars", "dc_group_finder_listings", "Group Finder", true},
        {"acore_chars", "dc_group_finder_rewards", "Group Finder", false},
        {"acore_chars", "dc_group_finder_scheduled_events", "Group Finder", false},
        {"acore_chars", "dc_group_finder_spectators", "Group Finder", false},
        {"acore_chars", "dc_guild_house", "Guild Housing", true},
        {"acore_chars", "dc_guild_house_log", "Guild Housing", false},
        {"acore_chars", "dc_guild_house_permissions", "Guild Housing", true},
        {"acore_chars", "dc_guild_house_purchase_log", "Guild Housing", false},
        {"acore_chars", "dc_guild_upgrade_stats", "Leaderboards", false},
        {"acore_chars", "dc_heirloom_collection", "Collection System", true},
        {"acore_chars", "dc_heirloom_package_history", "Heirloom", false},
        {"acore_chars", "dc_heirloom_player_packages", "Heirloom", false},
        {"acore_chars", "dc_heirloom_upgrade_log", "Heirloom", false},
        {"acore_chars", "dc_heirloom_upgrades", "Heirloom", true},
        {"acore_chars", "dc_hlbg_match_history", "HLBG System", false},
        {"acore_chars", "dc_hlbg_match_participants", "HLBG System", true},
        {"acore_chars", "dc_hlbg_player_history", "HLBG System", false},
        {"acore_chars", "dc_hlbg_player_season_data", "HLBG System", true},
        {"acore_chars", "dc_hlbg_player_stats", "HLBG System", false},
        {"acore_chars", "dc_hlbg_season_config", "HLBG System", true},
        {"acore_chars", "dc_hlbg_state", "HLBG System", true},
        {"acore_chars", "dc_hlbg_winner_history", "HLBG System", true},
        {"acore_chars", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_currency_exchange_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_missing_items", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_stat_scaling", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_state", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_transmutation_sessions", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrades", "Item Upgrade", false},
        {"acore_chars", "dc_leaderboard_cache", "Leaderboards", false},
        {"acore_chars", "dc_migration_auth_unlocks", "Migration", false},
        {"acore_chars", "dc_migration_item_display", "Migration", false},
        {"acore_chars", "dc_mount_collection", "Collection System", true},
        {"acore_chars", "dc_mplus_best_runs", "Mythic+", false},
        {"acore_chars", "dc_mplus_dungeons", "Mythic+", false},
        {"acore_chars", "dc_mplus_hud_cache", "Mythic+", false},
        {"acore_chars", "dc_mplus_keystones", "Mythic+", true},
        {"acore_chars", "dc_mplus_player_ratings", "Mythic+", false},
        {"acore_chars", "dc_mplus_runs", "Mythic+", true},
        {"acore_chars", "dc_mplus_scores", "Mythic+", false},
        {"acore_chars", "dc_mplus_spec_invites", "Mythic Spectator", false},
        {"acore_chars", "dc_mplus_spec_popularity", "Mythic Spectator", false},
        {"acore_chars", "dc_mplus_spec_replays", "Mythic Spectator", false},
        {"acore_chars", "dc_mplus_spec_sessions", "Mythic Spectator", false},
        {"acore_chars", "dc_mplus_spec_settings", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_dungeon_stats", "Mythic+", false},
        {"acore_chars", "dc_mythic_weekly_best", "Mythic+", false},
        {"acore_chars", "dc_pet_collection", "Collection System", true},
        {"acore_chars", "dc_player_achievements", "Achievements", false},
        {"acore_chars", "dc_player_artifact_discoveries", "Artifacts", false},
        {"acore_chars", "dc_player_artifact_mastery", "Artifacts", true},
        {"acore_chars", "dc_player_claimed_chests", "Season System", false},
        {"acore_chars", "dc_player_cross_system_stats", "Cross-System", true},
        {"acore_chars", "dc_player_daily_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_dungeon_completion_stats", "Dungeon Stats", false},
        {"acore_chars", "dc_player_item_upgrades", "Item Upgrade", true},
        {"acore_chars", "dc_player_keystones", "Mythic+", false},
        {"acore_chars", "dc_player_qos_settings", "QoS System", false},
        {"acore_chars", "dc_player_season_data", "Season System", true},
        {"acore_chars", "dc_player_seasonal_achievements", "Season System", false},
        {"acore_chars", "dc_player_seasonal_chests", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats_history", "Season System", false},
        {"acore_chars", "dc_player_seen_features", "Welcome System", false},
        {"acore_chars", "dc_player_synthesis_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_player_tier_caps", "Item Upgrade", false},
        {"acore_chars", "dc_player_tier_unlocks", "Item Upgrade", false},
        {"acore_chars", "dc_player_transmutation_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_player_upgrade_tokens", "Item Upgrade", true},
        {"acore_chars", "dc_player_weekly_cap_snapshot", "Quest System", false},
        {"acore_chars", "dc_player_weekly_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_weekly_rewards", "Weekly Vault", false},
        {"acore_chars", "dc_player_welcome", "Welcome System", false},
        {"acore_chars", "dc_prestige_challenge_rewards", "Prestige", false},
        {"acore_chars", "dc_prestige_challenges", "Prestige", false},
        {"acore_chars", "dc_prestige_players", "Prestige", false},
        {"acore_chars", "dc_respec_history", "Item Upgrade", false},
        {"acore_chars", "dc_respec_log", "Item Upgrade", false},
        {"acore_chars", "dc_reward_transactions", "Vault/Rewards", false},
        {"acore_chars", "dc_season_history", "Season System", false},
        {"acore_chars", "dc_seasons", "Season System", true},
        {"acore_chars", "dc_server_firsts", "Achievements", false},
        {"acore_chars", "dc_spectator_settings", "Mythic Spectator", false},
        {"acore_chars", "dc_tier_conversion_log", "Item Upgrade", false},
        {"acore_chars", "dc_title_collection", "Collection System", false},
        {"acore_chars", "dc_token_event_config", "Token System", false},
        {"acore_chars", "dc_token_rewards_log", "Token System", false},
        {"acore_chars", "dc_token_transaction_log", "Token System", false},
        {"acore_chars", "dc_toy_collection", "Collection System", true},
        {"acore_chars", "dc_transmog_collection", "Collection System", true},
        {"acore_chars", "dc_upgrade_history", "Item Upgrade", false},
        {"acore_chars", "dc_vault_reward_pool", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_reset_state", "Weekly Vault", false},
        {"acore_chars", "dc_weekly_spending", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_vault", "Weekly Vault", true},
        {"acore_chars", "dc_welcome_faq", "Welcome System", false},
        {"acore_chars", "dc_welcome_whats_new", "Welcome System", false},
        {"acore_world", "dc_aoeloot_blacklist", "AoE Loot Config", false},
        {"acore_world", "dc_aoeloot_config", "AoE Loot Config", true},
        {"acore_world", "dc_aoeloot_smart_categories", "AoE Loot Config", false},
        {"acore_world", "dc_aoeloot_zone_modifiers", "AoE Loot Config", false},
        {"acore_world", "dc_chaos_artifact_items", "Artifacts", false},
        {"acore_world", "dc_collection_achievement_defs", "Collection System", false},
        {"acore_world", "dc_collection_definitions", "Collection System", true},
        {"acore_world", "dc_collection_shop", "Collection System", false},
        {"acore_world", "dc_daily_quest_token_rewards", "Quest Rewards", false},
        {"acore_world", "dc_difficulty_config", "Difficulty System", true},
        {"acore_world", "dc_duel_tournament_npcs", "Duel System", false},
        {"acore_world", "dc_duel_zones", "Duel System", false},
        {"acore_world", "dc_dungeon_entrances", "Dungeon System", false},
        {"acore_world", "dc_dungeon_mythic_profile", "Dungeon System", true},
        {"acore_world", "dc_dungeon_npc_mapping", "Dungeon System", false},
        {"acore_world", "dc_dungeon_setup", "Dungeon System", false},
        {"acore_world", "dc_guild_house_locations", "Guild Housing", true},
        {"acore_world", "dc_guild_house_spawns", "Guild Housing", false},
        {"acore_world", "dc_heirloom_definitions", "Collection System", true},
        {"acore_world", "dc_heirloom_enchant_mapping", "Heirloom", false},
        {"acore_world", "dc_heirloom_package_levels", "Heirloom", false},
        {"acore_world", "dc_heirloom_stat_packages", "Heirloom", false},
        {"acore_world", "dc_heirloom_upgrade_costs", "Heirloom", false},
        {"acore_world", "dc_hlbg_seasons", "HLBG System", true},
        {"acore_world", "dc_hotspots_active", "Hotspot System", true},
        {"acore_world", "dc_item_custom_data", "Custom Data", false},
        {"acore_world", "dc_item_proc_spells", "Item Procs", false},
        {"acore_world", "dc_item_templates_upgrade", "Item Upgrade", true},
        {"acore_world", "dc_item_upgrade_clones", "Item Upgrade", true},
        {"acore_world", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_state", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_inputs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_recipes", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_tier_items", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_tiers", "Item Upgrade", true},
        {"acore_world", "dc_mount_definitions", "Collection System", true},
        {"acore_world", "dc_mplus_affix_pairs", "Mythic+", false},
        {"acore_world", "dc_mplus_affix_schedule", "Mythic+", false},
        {"acore_world", "dc_mplus_affixes", "Mythic+", true},
        {"acore_world", "dc_mplus_dungeons", "Mythic+", false},
        {"acore_world", "dc_mplus_featured_dungeons", "Mythic+", false},
        {"acore_world", "dc_mplus_scale_multipliers", "Mythic+", false},
        {"acore_world", "dc_mplus_seasons", "Mythic+", true},
        {"acore_world", "dc_mplus_spec_npcs", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_spec_positions", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_spec_strings", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_teleporter_npcs", "Mythic+", false},
        {"acore_world", "dc_mplus_weekly_affixes", "Mythic+", false},
        {"acore_world", "dc_npc_quest_link", "Quest System", false},
        {"acore_world", "dc_pet_definitions", "Collection System", true},
        {"acore_world", "dc_quest_difficulty_mapping", "Quest System", false},
        {"acore_world", "dc_quest_reward_tokens", "Quest Rewards", false},
        {"acore_world", "dc_seasonal_chest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_creature_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_quest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_reward_config", "Season System", false},
        {"acore_world", "dc_seasonal_reward_multipliers", "Season System", false},
        {"acore_world", "dc_spell_custom_data", "Custom Data", false},
        {"acore_world", "dc_synthesis_recipes", "Item Upgrade", false},
        {"acore_world", "dc_teleporter", "Teleporters", false},
        {"acore_world", "dc_token_vendor_items", "Token System", false},
        {"acore_world", "dc_toy_definitions", "Collection System", true},
        {"acore_world", "dc_upgrade_tracks", "Item Upgrade", false},
        {"acore_world", "dc_vault_loot_table", "Weekly Vault", false},
        {"acore_world", "dc_weekly_quest_token_rewards", "Quest Rewards", false},
    },

    -- Deprecated tables (empty as we have synced with schema)
    DEPRECATED_TABLES = {},

    -- Results storage
    missing_tables = {},
    missing_critical = {},
    missing_deprecated = {},
    features_affected = {},
}

-- Check if a table exists
local function TableExists(schema, tableName)
    local query
    if schema == "acore_chars" then
        query = CharDBQuery(string.format(
            "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'acore_chars' AND TABLE_NAME = '%s'",
            tableName
        ))
    elseif schema == "acore_world" then
        query = WorldDBQuery(string.format(
            "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'acore_world' AND TABLE_NAME = '%s'",
            tableName
        ))
    end
    return query ~= nil
end

-- Main check function
local function CheckAllTables()
    print("========================================")
    print("[DC TableChecker] Starting database table validation...")
    print("========================================")
    
    local checked = 0
    local present = 0
    local missing = 0
    local criticalMissing = 0
    
    DC_TABLE_CHECKER.missing_tables = {}
    DC_TABLE_CHECKER.missing_critical = {}
    DC_TABLE_CHECKER.missing_deprecated = {}
    DC_TABLE_CHECKER.features_affected = {}
    
    for _, tableInfo in ipairs(DC_TABLE_CHECKER.REQUIRED_TABLES) do
        local schema = tableInfo[1]
        local tableName = tableInfo[2]
        local feature = tableInfo[3]
        local critical = tableInfo[4]
        
        checked = checked + 1
        
        if TableExists(schema, tableName) then
            present = present + 1
        else
            missing = missing + 1
            table.insert(DC_TABLE_CHECKER.missing_tables, {
                schema = schema,
                name = tableName,
                feature = feature,
                critical = critical
            })
            
            if critical then
                criticalMissing = criticalMissing + 1
                table.insert(DC_TABLE_CHECKER.missing_critical, tableName)
            end
            
            -- Track affected features
            if not DC_TABLE_CHECKER.features_affected[feature] then
                DC_TABLE_CHECKER.features_affected[feature] = {missing = 0, critical = 0}
            end
            DC_TABLE_CHECKER.features_affected[feature].missing = DC_TABLE_CHECKER.features_affected[feature].missing + 1
            if critical then
                DC_TABLE_CHECKER.features_affected[feature].critical = DC_TABLE_CHECKER.features_affected[feature].critical + 1
            end
        end
    end

    -- Check deprecated/optional tables but do not count them as critical or 'missing' errors
    if DC_TABLE_CHECKER.DEPRECATED_TABLES then
        for _, tbl in ipairs(DC_TABLE_CHECKER.DEPRECATED_TABLES) do
            local schema = tbl[1]
            local tableName = tbl[2]
            local feature = tbl[3]
            if not TableExists(schema, tableName) then
                table.insert(DC_TABLE_CHECKER.missing_deprecated, {
                    schema = schema,
                    name = tableName,
                    feature = feature
                })
            end
        end
    end

    -- Print deprecated table results (informational only)
    if #DC_TABLE_CHECKER.missing_deprecated > 0 then
        print("")
        print("[DC TableChecker] MISSING DEPRECATED TABLES (optional):")
        for _, tbl in ipairs(DC_TABLE_CHECKER.missing_deprecated) do
            print(string.format("  [%s] %s (%s) [DEPRECATED]", tbl.schema, tbl.name, tbl.feature))
        end
        print("")
    end

    -- Output results
    if missing > 0 then
        print("")
        print("[DC TableChecker] MISSING TABLES:")
        for _, tbl in ipairs(DC_TABLE_CHECKER.missing_tables) do
            local criticalTag = tbl.critical and " [CRITICAL]" or ""
            print(string.format("  [%s] %s (%s)%s", tbl.schema, tbl.name, tbl.feature, criticalTag))
        end
        print("")
        
        print("[DC TableChecker] AFFECTED FEATURES:")
        for feature, counts in pairs(DC_TABLE_CHECKER.features_affected) do
            local status = counts.critical > 0 and "DISABLED" or "DEGRADED"
            print(string.format("  %s: %s (%d tables missing, %d critical)", feature, status, counts.missing, counts.critical))
        end
        print("")
        
        if criticalMissing > 0 then
            print("========================================")
            print("[DC TableChecker] WARNING: Critical tables are missing!")
            print("[DC TableChecker] Some features will be DISABLED until tables are created.")
            print("[DC TableChecker] Run the SQL files in: Custom/Custom feature SQLs/")
            print("========================================")
            
            if DC_TABLE_CHECKER.CONFIG.ABORT_ON_CRITICAL then
                print("[DC TableChecker] ABORTING SERVER START due to missing critical tables.")
                return false
            end
        end
    else
        print(string.format("[DC TableChecker] All %d required DC tables are present. ✓", checked))
    end
    
    print("========================================")
    return true
end

-- GM Command to check tables
local function OnCommand(event, player, command)
    if command == "dc tables" or command == "dc table check" then
        CheckAllTables()
        if player then
            player:SendBroadcastMessage("|cFF00FF00[DC TableChecker]|r Check complete. See server console for details.")
        end
        return false
    end
    return true
end

-- Store results globally for other scripts to access
local function GetMissingTables()
    return DC_TABLE_CHECKER.missing_tables
end

local function GetAffectedFeatures()
    return DC_TABLE_CHECKER.features_affected
end

local function IsFeatureAvailable(feature)
    local affected = DC_TABLE_CHECKER.features_affected[feature]
    if not affected then return true end
    return affected.critical == 0
end

-- Export functions globally
_G.DC_TableChecker = {
    Check = CheckAllTables,
    GetMissingTables = GetMissingTables,
    GetAffectedFeatures = GetAffectedFeatures,
    IsFeatureAvailable = IsFeatureAvailable,
}

-- Register GM command
RegisterPlayerEvent(42, OnCommand)  -- PLAYER_EVENT_ON_COMMAND

-- Run check on server start
RegisterServerEvent(14, function(event)  -- ELUNA_EVENT_ON_LOAD
    CheckAllTables()
end)

print("[DC TableChecker] Loaded. Will check tables on server start. Use '.dc tables' to recheck.")
