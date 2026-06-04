--[[
    DC Database Table Checker (Eluna Lua)
    
    Checks for required DarkChaos custom tables at server startup
    and reports any missing tables. The server will continue to start,
    but features with missing tables will be disabled.
    
    Updated: 2026-05-21 (verified against live DB, active code paths, and maintained DC SQL sources)

    This checker reflects runtime-relevant DC tables verified from:
    - live acore_world and acore_chars metadata
    - active C++ table usage under src/server/scripts/DC/
    - maintained DC SQL sources under Custom/Custom feature SQLs/

    It intentionally separates startup-relevant tables from optional,
    legacy, analytics, or runtime-managed objects so the output tracks the
    current code and database contract more closely.
    
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
        {"acore_chars", "dc_account_achievement_pools", "Account-Wide Achievements", false},
        {"acore_chars", "dc_account_outfits", "Collection System", false},
        {"acore_chars", "dc_account_reputation_pools", "Account-Wide Reputation", false},
        {"acore_chars", "dc_account_social_friends", "Account-Wide Friendlist", false},
        {"acore_chars", "dc_addon_client_caps", "Protocol Logging", false},
        {"acore_chars", "dc_addon_client_caps_history", "Protocol Logging", false},
        {"acore_chars", "dc_addon_feature_transport_audit", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_errors", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_log", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_stats", "Protocol Logging", false},
        {"acore_chars", "dc_aoeloot_accumulated", "AoE Loot", false},
        {"acore_chars", "dc_aoeloot_detailed_stats", "AoE Loot", true},
        {"acore_chars", "dc_aoeloot_preferences", "AoE Loot", true},
        {"acore_chars", "dc_artifact_mastery_events", "Artifacts", false},
        {"acore_chars", "dc_breaking_news_delivery_log", "Breaking News", false},
        {"acore_chars", "dc_character_challenge_mode_log", "Challenge Mode", false},
        {"acore_chars", "dc_character_challenge_mode_stats", "Challenge Mode", false},
        {"acore_chars", "dc_character_challenge_modes", "Challenge Mode", true},
        {"acore_chars", "dc_character_difficulty_completions", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_npc_respawn", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_progress", "Dungeon Progress", true},
        {"acore_chars", "dc_character_dungeon_quests_completed", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_statistics", "Dungeon Stats", false},
        {"acore_chars", "dc_character_prestige", "Prestige", true},
        {"acore_chars", "dc_character_prestige_log", "Prestige", false},
        {"acore_chars", "dc_character_transmog", "Collection System", false},
        {"acore_chars", "dc_collection_community_favorites", "Collection System", false},
        {"acore_chars", "dc_collection_community_outfits", "Collection System", true},
        {"acore_chars", "dc_collection_items", "Collection System", true},
        {"acore_chars", "dc_collection_migrations", "Collection System", false},
        {"acore_chars", "dc_collection_shop_purchases", "Collection System", false},
        {"acore_chars", "dc_collection_wishlist", "Collection System", false},
        {"acore_chars", "dc_cross_system_config", "Cross-System", true},
        {"acore_chars", "dc_cross_system_events", "Cross-System", false},
        {"acore_chars", "dc_duel_statistics", "Duel System", true},
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
        {"acore_chars", "dc_heirloom_upgrade_log", "Heirloom", false},
        {"acore_chars", "dc_heirloom_upgrades", "Heirloom", true},
        {"acore_chars", "dc_hlbg_match_participants", "HLBG System", true},
        {"acore_chars", "dc_hlbg_player_stats", "HLBG System", true},
        {"acore_chars", "dc_hlbg_winner_history", "HLBG System", true},
        {"acore_chars", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_missing_items", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_state", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_transmutation_sessions", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrades", "Item Upgrade", false},
        {"acore_chars", "dc_leaderboard_cache", "Leaderboards", false},
        {"acore_chars", "dc_mount_collection", "Collection System", true},
        {"acore_chars", "dc_mplus_best_runs", "Mythic+", false},
        {"acore_chars", "dc_mplus_dungeons", "Mythic+", false},
        {"acore_chars", "dc_mplus_hud_cache", "Mythic+", false},
        {"acore_chars", "dc_mplus_keystones", "Mythic+", true},
        {"acore_chars", "dc_mplus_player_ratings", "Mythic+", false},
        {"acore_chars", "dc_mplus_runs", "Mythic+", true},
        {"acore_chars", "dc_mplus_scores", "Mythic+", false},
        {"acore_chars", "dc_mplus_spec_replays", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_dungeon_stats", "Mythic+", false},
        {"acore_chars", "dc_mythic_weekly_best", "Mythic+", false},
        {"acore_chars", "dc_pet_collection", "Collection System", true},
        {"acore_chars", "dc_player_achievements", "Achievements", false},
        {"acore_chars", "dc_player_artifact_discoveries", "Artifacts", false},
        {"acore_chars", "dc_player_artifact_mastery", "Artifacts", true},
        {"acore_chars", "dc_player_cross_system_stats", "Cross-System", false},
        {"acore_chars", "dc_player_daily_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_dungeon_completion_stats", "Dungeon Stats", false},
        {"acore_chars", "dc_player_keystones", "Mythic+", false},
        {"acore_chars", "dc_player_qos_settings", "QoS System", false},
        {"acore_chars", "dc_player_season_data", "Season System", true},
        {"acore_chars", "dc_player_seasonal_chests", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats_history", "Season System", false},
        {"acore_chars", "dc_player_seen_features", "Welcome System", false},
        {"acore_chars", "dc_player_tier_caps", "Item Upgrade", false},
        {"acore_chars", "dc_player_tier_unlocks", "Item Upgrade", false},
        {"acore_chars", "dc_player_transmutation_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_player_upgrade_tokens", "Item Upgrade", false},
        {"acore_chars", "dc_player_weekly_cap_snapshot", "Season System", false},
        {"acore_chars", "dc_player_weekly_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_welcome", "Welcome System", false},
        {"acore_chars", "dc_prestige_challenge_rewards", "Prestige", false},
        {"acore_chars", "dc_prestige_challenges", "Prestige", false},
        {"acore_chars", "dc_prestige_players", "Prestige", false},
        {"acore_chars", "dc_respec_history", "Item Upgrade", false},
        {"acore_chars", "dc_respec_log", "Item Upgrade", false},
        {"acore_chars", "dc_reward_transactions", "Vault/Rewards", false},
        {"acore_chars", "dc_season_history", "Season System", false},
        {"acore_chars", "dc_server_firsts", "Achievements", false},
        {"acore_chars", "dc_spectator_settings", "Mythic Spectator", false},
        {"acore_chars", "dc_tier_conversion_log", "Item Upgrade", false},
        {"acore_chars", "dc_token_rewards_log", "Token System", false},
        {"acore_chars", "dc_token_transaction_log", "Token System", false},
        {"acore_chars", "dc_toy_collection", "Collection System", true},
        {"acore_chars", "dc_transmog_collection", "Collection System", true},
        {"acore_chars", "dc_upgrade_history", "Item Upgrade", false},
        {"acore_chars", "dc_vault_reward_pool", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_reset_state", "Weekly Vault", false},
        {"acore_chars", "dc_weekly_spending", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_vault", "Weekly Vault", true},
        {"acore_world", "dc_chaos_artifact_items", "Artifacts", false},
        {"acore_world", "dc_collection_achievement_defs", "Collection System", false},
        {"acore_world", "dc_collection_definitions", "Collection System", true},
        {"acore_world", "dc_daily_quest_token_rewards", "Quest Rewards", false},
        {"acore_world", "dc_difficulty_config", "Difficulty System", true},
        {"acore_world", "dc_dungeon_entrances", "Dungeon System", false},
        {"acore_world", "dc_dungeon_mythic_profile", "Dungeon System", true},
        {"acore_world", "dc_dungeon_npc_mapping", "Dungeon System", false},
        {"acore_world", "dc_dungeon_quest_mapping", "Quest System", false},
        {"acore_world", "dc_dungeon_setup", "Dungeon System", false},
        {"acore_world", "dc_guild_house_locations", "Guild Housing", true},
        {"acore_world", "dc_guild_house_spawns", "Guild Housing", false},
        {"acore_world", "dc_heirloom_definitions", "Collection System", true},
        {"acore_world", "dc_heirloom_stat_packages", "Heirloom", false},
        {"acore_world", "dc_heirloom_upgrade_costs", "Heirloom", false},
        {"acore_world", "dc_hotspots_active", "Hotspot System", true},
        {"acore_world", "dc_item_custom_data", "Custom Data", false},
        {"acore_world", "dc_item_enchantment_random_tiers", "Random Enchants", true},
        {"acore_world", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_inputs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_recipes", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_tiers", "Item Upgrade", true},
        {"acore_world", "dc_mount_definitions", "Collection System", true},
        {"acore_world", "dc_mplus_affix_pairs", "Mythic+", false},
        {"acore_world", "dc_mplus_affix_schedule", "Mythic+", false},
        {"acore_world", "dc_mplus_affixes", "Mythic+", true},
        {"acore_world", "dc_mplus_dungeons", "Mythic+", false},
        {"acore_world", "dc_mplus_featured_dungeons", "Mythic+", false},
        {"acore_world", "dc_mplus_scale_multipliers", "Mythic+", false},
        {"acore_world", "dc_mplus_spec_npcs", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_spec_positions", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_spec_strings", "Mythic Spectator", false},
        {"acore_world", "dc_mplus_teleporter_npcs", "Mythic+", false},
        {"acore_world", "dc_mplus_weekly_affixes", "Mythic+", false},
        {"acore_world", "dc_pet_definitions", "Collection System", true},
        {"acore_world", "dc_quest_difficulty_mapping", "Quest System", false},
        {"acore_world", "dc_quest_reward_tokens", "Quest Rewards", false},
        {"acore_world", "dc_questgiver_status_overrides", "QoS System", false},
        {"acore_world", "dc_seasonal_chest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_creature_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_quest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_reward_config", "Season System", false},
        {"acore_world", "dc_seasonal_reward_multipliers", "Season System", false},
        {"acore_world", "dc_seasons", "Season System", true},
        {"acore_world", "dc_spell_custom_data", "Custom Data", false},
        {"acore_world", "dc_teleporter", "Teleporters", false},
        {"acore_world", "dc_toy_definitions", "Collection System", true},
        {"acore_world", "dc_training_boss_display_pool", "Training System", false},
        {"acore_world", "dc_vault_loot_table", "Weekly Vault", false},
        {"acore_world", "dc_welcome_faq", "Welcome System", false},
        {"acore_world", "dc_welcome_whats_new", "Welcome System", false},
        {"acore_world", "dc_weekly_quest_token_rewards", "Quest Rewards", false},
        {"acore_world", "dc_world_boss_schedule", "World Bosses", false},
    },

    -- Tables where either schema can satisfy the active runtime contract.
    ALTERNATIVE_TABLE_GROUPS = {
        {
            name = "dc_collection_shop",
            feature = "Collection System",
            critical = false,
            tables = {
                {"acore_chars", "dc_collection_shop"},
                {"acore_world", "dc_collection_shop"},
            },
        },
    },

    -- Optional, legacy, analytics, or runtime-managed tables. Missing tables
    -- here are reported informationally only.
    OPTIONAL_TABLES = {
        {"acore_chars", "dc_character_layer_assignment", "Layering"},
        {"acore_chars", "dc_character_partition_ownership", "Layering"},
        {"acore_chars", "dc_collection_community_votes", "Collection System"},
        {"acore_chars", "dc_guild_leaderboard", "Analytics Views"},
        {"acore_chars", "dc_item_upgrade_missing_items_summary", "Analytics Views"},
        {"acore_chars", "dc_player_progression_summary", "Analytics Views"},
        {"acore_chars", "dc_player_upgrade_summary", "Analytics Views"},
        {"acore_chars", "dc_recent_upgrades_feed", "Analytics Views"},
        {"acore_chars", "dc_top_upgraders", "Analytics Views"},
        {"acore_chars", "dc_upgrade_speed_stats", "Analytics Views"},
        {"acore_world", "dc_hlbg_seasons", "HLBG System"},
        {"acore_world", "dc_item_templates_upgrade", "Item Upgrade (legacy compat stub — no longer queried by current binary)"},
        {"acore_world", "dc_mplus_seasons", "Mythic+"},
    },

    -- Results storage
    missing_tables = {},
    missing_critical = {},
    missing_optional = {},
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

    local function RecordMissing(entry)
        missing = missing + 1
        table.insert(DC_TABLE_CHECKER.missing_tables, entry)

        if entry.critical then
            criticalMissing = criticalMissing + 1
            table.insert(DC_TABLE_CHECKER.missing_critical, entry.name)
        end

        local feature = entry.feature
        if not DC_TABLE_CHECKER.features_affected[feature] then
            DC_TABLE_CHECKER.features_affected[feature] = {missing = 0, critical = 0}
        end

        DC_TABLE_CHECKER.features_affected[feature].missing = DC_TABLE_CHECKER.features_affected[feature].missing + 1
        if entry.critical then
            DC_TABLE_CHECKER.features_affected[feature].critical = DC_TABLE_CHECKER.features_affected[feature].critical + 1
        end
    end
    
    DC_TABLE_CHECKER.missing_tables = {}
    DC_TABLE_CHECKER.missing_critical = {}
    DC_TABLE_CHECKER.missing_optional = {}
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
            RecordMissing({
                schema = schema,
                name = tableName,
                feature = feature,
                critical = critical
            })
        end
    end

    if DC_TABLE_CHECKER.ALTERNATIVE_TABLE_GROUPS then
        for _, group in ipairs(DC_TABLE_CHECKER.ALTERNATIVE_TABLE_GROUPS) do
            local groupPresent = false

            for _, tbl in ipairs(group.tables) do
                if TableExists(tbl[1], tbl[2]) then
                    groupPresent = true
                    break
                end
            end

            checked = checked + 1

            if groupPresent then
                present = present + 1
            else
                local alternatives = {}
                for _, tbl in ipairs(group.tables) do
                    table.insert(alternatives, string.format("[%s] %s", tbl[1], tbl[2]))
                end

                RecordMissing({
                    schema = nil,
                    name = group.name,
                    feature = group.feature,
                    critical = group.critical,
                    display = table.concat(alternatives, " OR "),
                })
            end
        end
    end

    -- Check optional tables but do not count them as critical or blocking.
    if DC_TABLE_CHECKER.OPTIONAL_TABLES then
        for _, tbl in ipairs(DC_TABLE_CHECKER.OPTIONAL_TABLES) do
            local schema = tbl[1]
            local tableName = tbl[2]
            local feature = tbl[3]
            if not TableExists(schema, tableName) then
                table.insert(DC_TABLE_CHECKER.missing_optional, {
                    schema = schema,
                    name = tableName,
                    feature = feature
                })
            end
        end
    end

    -- Print optional table results (informational only)
    if #DC_TABLE_CHECKER.missing_optional > 0 then
        print("")
        print("[DC TableChecker] MISSING OPTIONAL TABLES (informational):")
        for _, tbl in ipairs(DC_TABLE_CHECKER.missing_optional) do
            print(string.format("  [%s] %s (%s) [OPTIONAL]", tbl.schema, tbl.name, tbl.feature))
        end
        print("")
    end

    -- Output results
    if missing > 0 then
        print("")
        print("[DC TableChecker] MISSING TABLES:")
        for _, tbl in ipairs(DC_TABLE_CHECKER.missing_tables) do
            local criticalTag = tbl.critical and " [CRITICAL]" or ""
            local descriptor = tbl.display or string.format("[%s] %s", tbl.schema, tbl.name)
            print(string.format("  %s (%s)%s", descriptor, tbl.feature, criticalTag))
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
