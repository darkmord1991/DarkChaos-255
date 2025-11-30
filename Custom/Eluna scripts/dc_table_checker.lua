--[[
    DC Database Table Checker (Eluna Lua)
    
    Checks for required DarkChaos custom tables at server startup
    and reports any missing tables. The server will continue to start,
    but features with missing tables will be disabled.
    
    Updated: 2025-11-30 (synced with quality stats, HLBG seasons, consolidated AOE tables, protocol logging)
    Tables: ~98 in acore_chars, ~65 in acore_world = ~163 total
    
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
        -- ============================================================
        -- CHARACTER DATABASE (acore_chars)
        -- ============================================================
        
        -- Achievement System
        {"acore_chars", "dc_achievement_definitions", "Achievements", false},
        {"acore_chars", "dc_player_achievements", "Achievements", false},
        {"acore_chars", "dc_server_firsts", "Achievements", false},
        
        -- AoE Loot System (consolidated - uses dc_aoeloot_preferences as main settings table)
        {"acore_chars", "dc_aoeloot_accumulated", "AoE Loot", false},
        {"acore_chars", "dc_aoeloot_detailed_stats", "AoE Loot", true},  -- Now includes quality breakdown columns
        {"acore_chars", "dc_aoeloot_preferences", "AoE Loot", true},     -- Main settings table (consolidated)
        
        -- Artifact System
        {"acore_chars", "dc_artifact_mastery_events", "Artifacts", false},
        {"acore_chars", "dc_player_artifact_discoveries", "Artifacts", false},
        {"acore_chars", "dc_player_artifact_mastery", "Artifacts", true},
        
        -- Challenge/Dungeon Progress
        {"acore_chars", "dc_character_challenge_modes", "Challenge Mode", true},
        {"acore_chars", "dc_character_challenge_mode_log", "Challenge Mode", false},
        {"acore_chars", "dc_character_challenge_mode_stats", "Challenge Mode", false},
        {"acore_chars", "dc_character_difficulty_completions", "Dungeon Progress", false},
        {"acore_chars", "dc_character_difficulty_streaks", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_npc_respawn", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_progress", "Dungeon Progress", true},
        {"acore_chars", "dc_character_dungeon_quests_completed", "Dungeon Progress", false},
        {"acore_chars", "dc_character_dungeon_statistics", "Dungeon Stats", false},
        {"acore_chars", "dc_dungeon_instance_resets", "Dungeon System", false},
        {"acore_chars", "dc_player_dungeon_completion_stats", "Dungeon Stats", false},
        
        -- Prestige System
        {"acore_chars", "dc_character_prestige", "Prestige", true},
        {"acore_chars", "dc_character_prestige_log", "Prestige", false},
        {"acore_chars", "dc_character_prestige_stats", "Prestige", false},
        {"acore_chars", "dc_prestige_challenge_rewards", "Prestige", false},
        {"acore_chars", "dc_prestige_challenges", "Prestige", false},
        
        -- Duel System
        {"acore_chars", "dc_duel_class_matchups", "Duel System", false},
        {"acore_chars", "dc_duel_history", "Duel System", false},
        {"acore_chars", "dc_duel_statistics", "Duel System", true},
        
        -- Guild/Leaderboard
        {"acore_chars", "dc_guild_leaderboard", "Leaderboards", false},
        {"acore_chars", "dc_guild_upgrade_stats", "Leaderboards", false},
        {"acore_chars", "dc_leaderboard_cache", "Leaderboards", false},
        
        -- Heirloom System
        {"acore_chars", "dc_heirloom_package_history", "Heirloom", false},
        {"acore_chars", "dc_heirloom_player_packages", "Heirloom", false},
        {"acore_chars", "dc_heirloom_upgrade_log", "Heirloom", false},
        {"acore_chars", "dc_heirloom_upgrades", "Heirloom", true},
        
        -- HLBG (Hinterlands BG) System - Player data in chars, seasons in world
        {"acore_chars", "dc_hlbg_player_history", "HLBG System", false},
        {"acore_chars", "dc_hlbg_player_season_data", "HLBG System", true},
        {"acore_chars", "dc_hlbg_player_stats", "HLBG System", true},     -- All-time stats
        {"acore_chars", "dc_hlbg_match_history", "HLBG System", false},
        
        -- Item Upgrade System
        {"acore_chars", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_currency_exchange_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_stat_scaling", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_state", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_synthesis_log", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrade_transmutation_sessions", "Item Upgrade", false},
        {"acore_chars", "dc_item_upgrades", "Item Upgrade", false},
        {"acore_chars", "dc_player_item_upgrades", "Item Upgrade", true},
        {"acore_chars", "dc_player_synthesis_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_player_tier_caps", "Item Upgrade", false},
        {"acore_chars", "dc_player_tier_unlocks", "Item Upgrade", false},
        {"acore_chars", "dc_player_transmutation_cooldowns", "Item Upgrade", false},
        {"acore_chars", "dc_player_upgrade_summary", "Item Upgrade", false},
        {"acore_chars", "dc_player_upgrade_tokens", "Item Upgrade", true},
        {"acore_chars", "dc_recent_upgrades_feed", "Item Upgrade", false},
        {"acore_chars", "dc_respec_history", "Item Upgrade", false},
        {"acore_chars", "dc_respec_log", "Item Upgrade", false},
        {"acore_chars", "dc_tier_conversion_log", "Item Upgrade", false},
        {"acore_chars", "dc_top_upgraders", "Item Upgrade", false},
        {"acore_chars", "dc_upgrade_history", "Item Upgrade", false},
        {"acore_chars", "dc_upgrade_speed_stats", "Item Upgrade", false},
        
        -- Mythic+ System
        {"acore_chars", "dc_mplus_keystones", "Mythic+", true},
        {"acore_chars", "dc_mplus_runs", "Mythic+", true},
        {"acore_chars", "dc_mplus_scores", "Mythic+", false},
        {"acore_chars", "dc_mythicplus_hud_cache", "Mythic+", false},
        {"acore_chars", "dc_mythic_keystones", "Mythic+", false},
        {"acore_chars", "dc_player_keystones", "Mythic+", false},
        
        -- Mythic Spectator
        {"acore_chars", "dc_mythic_spectator_invites", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_spectator_popularity", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_spectator_replays", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_spectator_sessions", "Mythic Spectator", false},
        {"acore_chars", "dc_mythic_spectator_settings", "Mythic Spectator", false},
        {"acore_chars", "dc_spectator_settings", "Mythic Spectator", false},
        
        -- Season System
        {"acore_chars", "dc_player_claimed_chests", "Season System", false},
        {"acore_chars", "dc_player_season_data", "Season System", true},
        {"acore_chars", "dc_player_seasonal_achievements", "Season System", false},
        {"acore_chars", "dc_player_seasonal_chests", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats", "Season System", false},
        {"acore_chars", "dc_player_seasonal_stats_history", "Season System", false},
        {"acore_chars", "dc_season_history", "Season System", false},
        {"acore_chars", "dc_seasons", "Season System", true},
        
        -- Quest/Daily/Weekly System
        {"acore_chars", "dc_player_daily_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_weekly_cap_snapshot", "Quest System", false},
        {"acore_chars", "dc_player_weekly_quest_progress", "Quest System", false},
        {"acore_chars", "dc_player_weekly_rewards", "Weekly Vault", false},
        
        -- Token System
        {"acore_chars", "dc_token_event_config", "Token System", false},
        {"acore_chars", "dc_token_rewards_log", "Token System", false},
        {"acore_chars", "dc_token_transaction_log", "Token System", false},
        
        -- Vault/Rewards
        {"acore_chars", "dc_player_progression_summary", "Vault/Rewards", false},
        {"acore_chars", "dc_reward_transactions", "Vault/Rewards", false},
        {"acore_chars", "dc_vault_reward_pool", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_spending", "Vault/Rewards", false},
        {"acore_chars", "dc_weekly_vault", "Weekly Vault", true},
        
        -- Addon Protocol Logging (optional - only needed if DCAddon.EnableProtocolLogging is enabled)
        {"acore_chars", "dc_addon_protocol_log", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_stats", "Protocol Logging", false},
        {"acore_chars", "dc_addon_protocol_daily", "Protocol Logging", false},
        
        -- ============================================================
        -- WORLD DATABASE (acore_world)
        -- ============================================================
        
        -- AoE Loot Config
        {"acore_world", "dc_aoeloot_blacklist", "AoE Loot Config", false},
        {"acore_world", "dc_aoeloot_config", "AoE Loot Config", true},
        {"acore_world", "dc_aoeloot_smart_categories", "AoE Loot Config", false},
        {"acore_world", "dc_aoeloot_zone_modifiers", "AoE Loot Config", false},
        
        -- Artifact Config
        {"acore_world", "dc_chaos_artifact_items", "Artifacts", false},
        
        -- Quest Token Rewards
        {"acore_world", "dc_daily_quest_token_rewards", "Quest Rewards", false},
        {"acore_world", "dc_weekly_quest_token_rewards", "Quest Rewards", false},
        {"acore_world", "dc_quest_reward_tokens", "Quest Rewards", false},
        {"acore_world", "dc_quest_difficulty_mapping", "Quest System", false},
        {"acore_world", "dc_npc_quest_link", "Quest System", false},
        
        -- Difficulty System
        {"acore_world", "dc_difficulty_config", "Difficulty System", true},
        
        -- Duel System
        {"acore_world", "dc_duel_tournament_npcs", "Duel System", false},
        {"acore_world", "dc_duel_zones", "Duel System", false},
        
        -- Dungeon System
        {"acore_world", "dc_dungeon_entrances", "Dungeon System", false},
        {"acore_world", "dc_dungeon_mythic_profile", "Dungeon System", true},
        {"acore_world", "dc_dungeon_npc_mapping", "Dungeon System", false},
        {"acore_world", "dc_dungeon_setup", "Dungeon System", false},
        
        -- Heirloom Config
        {"acore_world", "dc_heirloom_enchant_mapping", "Heirloom", false},
        {"acore_world", "dc_heirloom_package_levels", "Heirloom", false},
        {"acore_world", "dc_heirloom_stat_packages", "Heirloom", false},
        {"acore_world", "dc_heirloom_upgrade_costs", "Heirloom", false},
        
        -- Hotspots
        {"acore_world", "dc_hotspots_active", "Hotspot System", true},
        
        -- Item Upgrade Config
        {"acore_world", "dc_item_proc_spells", "Item Procs", false},
        {"acore_world", "dc_item_templates_upgrade", "Item Upgrade", true},
        {"acore_world", "dc_item_upgrade_clones", "Item Upgrade", true},
        {"acore_world", "dc_item_upgrade_costs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_stage", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_state", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_inputs", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_synthesis_recipes", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_tier_items", "Item Upgrade", false},
        {"acore_world", "dc_item_upgrade_tiers", "Item Upgrade", true},
        {"acore_world", "dc_synthesis_recipes", "Item Upgrade", false},
        {"acore_world", "dc_upgrade_tracks", "Item Upgrade", false},
        
        -- Mythic+ Config
        {"acore_world", "dc_mplus_affix_pairs", "Mythic+", false},
        {"acore_world", "dc_mplus_affix_schedule", "Mythic+", false},
        {"acore_world", "dc_mplus_affixes", "Mythic+", true},
        {"acore_world", "dc_mplus_featured_dungeons", "Mythic+", false},
        {"acore_world", "dc_mplus_seasons", "Mythic+", true},
        {"acore_world", "dc_mplus_teleporter_npcs", "Mythic+", false},
        {"acore_world", "dc_mythic_plus_dungeons", "Mythic+", false},
        {"acore_world", "dc_mythic_plus_weekly_affixes", "Mythic+", false},
        {"acore_world", "dc_mythic_scaling_multipliers", "Mythic+", false},
        
        -- Mythic Spectator Config
        {"acore_world", "dc_mythic_spectator_npcs", "Mythic Spectator", false},
        {"acore_world", "dc_mythic_spectator_positions", "Mythic Spectator", false},
        {"acore_world", "dc_mythic_spectator_strings", "Mythic Spectator", false},
        
        -- HLBG Seasons Config (season definitions in world DB, player data in chars)
        {"acore_world", "dc_hlbg_seasons", "HLBG System", true},
        
        -- Season Rewards Config
        {"acore_world", "dc_seasonal_chest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_creature_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_quest_rewards", "Season System", false},
        {"acore_world", "dc_seasonal_reward_config", "Season System", false},
        {"acore_world", "dc_seasonal_reward_multipliers", "Season System", false},
        
        -- Token/Vendor Config
        {"acore_world", "dc_token_vendor_items", "Token System", false},
        
        -- Vault Config
        {"acore_world", "dc_vault_loot_table", "Weekly Vault", false},
    },
    
    -- Results storage
    missing_tables = {},
    missing_critical = {},
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
    
    -- Output results
    print("")
    print("[DC TableChecker] Results:")
    print(string.format("  Tables Checked: %d", checked))
    print(string.format("  Tables Present: %d", present))
    print(string.format("  Tables Missing: %d", missing))
    print(string.format("  Critical Missing: %d", criticalMissing))
    print("")
    
    if missing > 0 then
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
        print("[DC TableChecker] All required DC tables are present. ✓")
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
