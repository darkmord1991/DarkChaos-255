-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- DC LEADERBOARD ADDON & COMMAND SYSTEM EVALUATION
-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- Date: November 29, 2025
-- Author: GitHub Copilot Analysis
-- ═══════════════════════════════════════════════════════════════════════════════════════════

--[[
    ╔═══════════════════════════════════════════════════════════════════════════════════════╗
    ║                    PART 1: UNIFIED LEADERBOARD ADDON PROPOSAL                         ║
    ╚═══════════════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- EXECUTIVE SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    Current State:
    - Leaderboard data scattered across multiple systems:
      • Seasonal: dc_addon_seasons.cpp (HandleGetLeaderboard - TODO placeholder)
      • M+: npc_mythic_plus_statistics.cpp (NPC-based gossip menu)
      • HLBG: HLBGSeasonalParticipant.cpp (GetSeasonLeaderboard function)
      • AoE Loot: ac_aoeloot.cpp (chat command based)
      • Item Upgrades: dc_top_upgraders table (no UI)
      • Duels: dc_duel_statistics table (no UI)
      • Prestige: dc_character_prestige table (no unified view)
    
    Now that big packets work via chunked addon messaging, a unified leaderboard
    addon becomes feasible and highly beneficial.
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- PROPOSED ARCHITECTURE: DC-Leaderboards
-- ═══════════════════════════════════════════════════════════════════════════════════════════

local LEADERBOARD_SYSTEMS = {
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- LEADERBOARD CATEGORIES (Server → Client data flow)
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    
    MYTHIC_PLUS = {
        id = 1,
        name = "Mythic+",
        subcategories = {
            {id = 1, name = "Overall Score", table = "dc_mplus_scores", orderBy = "best_score DESC"},
            {id = 2, name = "Highest Key", table = "dc_mplus_scores", orderBy = "best_level DESC"},
            {id = 3, name = "Total Runs", table = "dc_mplus_scores", orderBy = "total_runs DESC"},
            {id = 4, name = "Per-Dungeon (UK)", table = "dc_mplus_runs", filter = "dungeon_id=574"},
            {id = 5, name = "Per-Dungeon (AN)", table = "dc_mplus_runs", filter = "dungeon_id=601"},
            -- ... more dungeons
        },
        refresh_interval = 300, -- 5 minutes cache
        max_entries = 100,
    },
    
    ITEM_UPGRADES = {
        id = 2,
        name = "Item Upgrades",
        subcategories = {
            {id = 1, name = "Total Upgrades", table = "dc_player_item_upgrades", aggregate = "SUM(level)"},
            {id = 2, name = "Highest Tier Item", table = "dc_player_item_upgrades", orderBy = "level DESC"},
            {id = 3, name = "Tokens Spent", table = "dc_upgrade_history", aggregate = "SUM(cost_tokens)"},
            {id = 4, name = "Weekly Top", table = "dc_top_upgraders", filter = "week_start > UNIX_TIMESTAMP()-604800"},
            {id = 5, name = "Guild Rankings", table = "dc_guild_upgrade_stats", groupBy = "guild_id"},
        },
        refresh_interval = 600, -- 10 minutes cache
        max_entries = 100,
    },
    
    SEASONAL = {
        id = 3,
        name = "Season Progress",
        subcategories = {
            {id = 1, name = "Total Tokens", table = "dc_player_seasonal_stats", orderBy = "total_tokens_earned DESC"},
            {id = 2, name = "Total Essence", table = "dc_player_seasonal_stats", orderBy = "total_essence_earned DESC"},
            {id = 3, name = "Quests Done", table = "dc_player_seasonal_stats", orderBy = "quests_completed DESC"},
            {id = 4, name = "Bosses Killed", table = "dc_player_seasonal_stats", orderBy = "bosses_killed DESC"},
        },
        refresh_interval = 300,
        max_entries = 100,
    },
    
    HLBG = {
        id = 4,
        name = "Hinterland BG",
        subcategories = {
            {id = 1, name = "Rating", table = "dc_hlbg_player_season_data", orderBy = "rating DESC"},
            {id = 2, name = "Wins", table = "dc_hlbg_player_season_data", orderBy = "wins DESC"},
            {id = 3, name = "Win Rate", table = "dc_hlbg_player_season_data", computed = "wins/(wins+losses)*100"},
            {id = 4, name = "Games Played", table = "dc_hlbg_player_season_data", orderBy = "completed_games DESC"},
        },
        refresh_interval = 120,
        max_entries = 100,
    },
    
    DUELS = {
        id = 5,
        name = "PvP Duels",
        subcategories = {
            {id = 1, name = "Overall Wins", table = "dc_duel_statistics", orderBy = "total_wins DESC"},
            {id = 2, name = "Win Rate", table = "dc_duel_statistics", computed = "total_wins/(total_wins+total_losses)*100"},
            {id = 3, name = "Win Streak", table = "dc_duel_statistics", orderBy = "best_streak DESC"},
            {id = 4, name = "Per-Class", table = "dc_duel_class_matchups", groupBy = "opponent_class"},
        },
        refresh_interval = 180,
        max_entries = 100,
    },
    
    PRESTIGE = {
        id = 6,
        name = "Prestige",
        subcategories = {
            {id = 1, name = "Prestige Level", table = "dc_character_prestige", orderBy = "prestige_level DESC"},
            {id = 2, name = "Total Prestiges", table = "dc_character_prestige", aggregate = "COUNT(*)"},
            {id = 3, name = "Fastest Prestige", table = "dc_character_prestige_log", orderBy = "duration ASC"},
        },
        refresh_interval = 600,
        max_entries = 100,
    },
    
    AOE_LOOT = {
        id = 7,
        name = "AoE Loot",
        subcategories = {
            {id = 1, name = "Gold Looted", table = "dc_aoeloot_accumulated", orderBy = "total_gold DESC"},
            {id = 2, name = "Items Looted", table = "dc_aoeloot_accumulated", orderBy = "total_items DESC"},
            {id = 3, name = "Kills", table = "dc_aoeloot_accumulated", orderBy = "total_kills DESC"},
        },
        refresh_interval = 600,
        max_entries = 50,
    },
    
    ACHIEVEMENTS = {
        id = 8,
        name = "Achievements",
        subcategories = {
            {id = 1, name = "Points", table = "dc_player_achievements", aggregate = "COUNT(*)"},
            {id = 2, name = "Server Firsts", table = "dc_server_firsts", orderBy = "achieved_at ASC"},
        },
        refresh_interval = 1800,
        max_entries = 50,
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- BENEFITS OF UNIFIED LEADERBOARD ADDON
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    1. PLAYER ENGAGEMENT
       - Single window for all competitive content
       - Easy comparison across systems
       - "My Rank" button shows player's position in each category
       - Encourages participation in multiple systems
    
    2. PERFORMANCE
       - Centralized caching (dc_leaderboard_cache table)
       - Batch queries instead of per-request queries
       - Chunked packets handle large datasets efficiently
       - Server-side ranking calculation reduces client load
    
    3. CONSISTENCY
       - Unified UI/UX across all features
       - Same refresh rates, pagination, filtering
       - Single addon to maintain
    
    4. EXTENSIBILITY
       - Easy to add new leaderboard categories
       - Modular design allows system-specific customization
       - Season-aware filtering built-in
    
    5. MONETIZATION POTENTIAL (if applicable)
       - Premium features (detailed stats, historical data)
       - Guild leaderboards as premium feature
       - Export/share functionality
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- TECHNICAL IMPLEMENTATION
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    C++ Side (dc_addon_leaderboards.cpp):
    - Handler for CMSG_GET_LEADERBOARD (category, subcategory, page)
    - Caching layer using dc_leaderboard_cache table
    - Batch query execution for multiple categories
    - Chunked response for 100+ entries
    
    Lua Side (DC-Leaderboards.lua):
    - Tabbed interface for categories
    - Dropdown for subcategories
    - Scrollable list with player names, values, ranks
    - "Find Me" button to scroll to player's position
    - Refresh button with cooldown
    - Season selector dropdown
    
    Protocol:
    - Module ID: LEADERBOARD (new module in DCAddonNamespace.h)
    - CMSG_GET_LEADERBOARD: categoryId, subcategoryId, page, seasonId
    - SMSG_LEADERBOARD_DATA: totalCount, entries[], myRank, myValue
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- ESTIMATED EFFORT
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    C++ Backend:
    - dc_addon_leaderboards.cpp (new): 400-600 lines
    - Leaderboard cache system: 200 lines
    - Query builders per system: 100 lines each × 8 = 800 lines
    - Total C++: ~1600-2000 lines
    
    Lua Addon:
    - DC-Leaderboards.lua: 800-1200 lines (AIO frame-based)
    - Shared utilities: 100 lines
    - Total Lua: ~900-1300 lines
    
    Database:
    - dc_leaderboard_cache table (already created)
    - Index optimizations on source tables
    
    Timeline: 3-5 days for full implementation
]]


--[[
    ╔═══════════════════════════════════════════════════════════════════════════════════════╗
    ║                    PART 2: UNIFIED COMMAND SYSTEM PROPOSAL                            ║
    ╚═══════════════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- CURRENT COMMAND DISTRIBUTION (SCATTERED)
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    CURRENT LOCATIONS:
    
    1. ItemUpgrades/
       - ItemUpgradeGMCommands.cpp         → .upgrade (GM commands)
       - ItemUpgradeMechanicsCommands.cpp  → .upgrade (mechanics)
       - ItemUpgradeAddonHandler.cpp       → .upgrade (addon-related)
       
    2. MythicPlus/
       - mythic_plus_commands.cpp          → .mplus
       - keystone_admin_commands.cpp       → .keystone
       
    3. Seasons/
       - SeasonalRewardCommands.cpp        → .season
       
    4. HinterlandBG/
       - cs_hl_bg.cpp (in Commands/ folder) → .hlbg
       
    5. PhasedDuels/
       - dc_phased_duels.cpp (inline)      → .duel
       
    6. Hotspot/
       - ac_hotspots.cpp (inline)          → .hotspots
       
    7. ac_aoeloot.cpp (inline)             → .aoeloot
    
    8. Prestige/
       - dc_prestige_system.cpp (inline)   → .prestige
       
    9. Scattered in core scripts:
       - Various .dc subcommands
       
    PROBLEMS:
    - Commands spread across 15+ files
    - No unified help system
    - Inconsistent command naming (.mplus vs .mythicplus)
    - Hard to find all available DC commands
    - Difficult to maintain and audit
    - No permission overview
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- PROPOSED STRUCTURE: DC/Commands/ Folder
-- ═══════════════════════════════════════════════════════════════════════════════════════════
local PROPOSED_STRUCTURE = [[
src/server/scripts/DC/Commands/
├── CMakeLists.txt                    # Build configuration
├── dc_commands_loader.cpp            # Loads all command scripts
├── dc_commands_shared.h              # Shared utilities, macros, permission checks
│
├── cs_dc_main.cpp                    # .dc help, .dc version, .dc reload
│
├── cs_dc_upgrade.cpp                 # ALL .upgrade commands (merged from 3 files)
│   • .upgrade info
│   • .upgrade stats
│   • .upgrade apply
│   • .upgrade remove
│   • .upgrade tokens
│   • .upgrade setlevel (GM)
│   • .upgrade settier (GM)
│   • .upgrade reload (Admin)
│
├── cs_dc_mplus.cpp                   # ALL .mplus commands (merged)
│   • .mplus info
│   • .mplus stats
│   • .mplus start
│   • .mplus abandon
│   • .mplus leaderboard
│   • .mplus keystone (GM)
│   • .mplus setlevel (GM)
│   • .mplus reload (Admin)
│
├── cs_dc_season.cpp                  # ALL .season commands
│   • .season info
│   • .season stats
│   • .season chest
│   • .season claim
│   • .season award (GM)
│   • .season reset (GM)
│   • .season reload (Admin)
│
├── cs_dc_hlbg.cpp                    # ALL .hlbg commands
│   • .hlbg info
│   • .hlbg stats
│   • .hlbg queue
│   • .hlbg leave
│   • .hlbg season
│   • .hlbg admin (GM)
│
├── cs_dc_duel.cpp                    # ALL .duel commands
│   • .duel stats
│   • .duel history
│   • .duel challenge
│   • .duel reset (GM)
│
├── cs_dc_prestige.cpp                # ALL .prestige commands
│   • .prestige info
│   • .prestige stats
│   • .prestige reset
│   • .prestige setlevel (GM)
│
├── cs_dc_aoeloot.cpp                 # ALL .aoeloot commands
│   • .aoeloot toggle
│   • .aoeloot range
│   • .aoeloot stats
│   • .aoeloot leaderboard
│   • .aoeloot reload (Admin)
│
├── cs_dc_hotspot.cpp                 # ALL .hotspot commands
│   • .hotspot list
│   • .hotspot tp
│   • .hotspot bonus
│   • .hotspot spawn (Admin)
│   • .hotspot reload (Admin)
│
├── cs_dc_admin.cpp                   # Master admin commands
│   • .dc reload all
│   • .dc status
│   • .dc debug
│   • .dc tables (check DB tables)
│   • .dc version
│
└── cs_dc_debug.cpp                   # Debug/testing commands (GM+)
    • .dctest packet
    • .dctest addon
    • .dctest leaderboard
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- BENEFITS OF CONSOLIDATED COMMAND SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    1. DISCOVERABILITY
       - .dc help shows ALL DC commands
       - Consistent .dc <system> <action> pattern
       - Tab completion works better with unified namespace
       
    2. MAINTAINABILITY
       - One file per system = easy to find and modify
       - Shared permission checks in dc_commands_shared.h
       - Consistent error handling and output formatting
       
    3. DOCUMENTATION
       - Auto-generated command reference from code
       - Permission matrix easy to audit
       - Changelog per command file
       
    4. TESTING
       - Unit tests per command file
       - Easier to mock dependencies
       - Integration test suite for all DC commands
       
    5. SECURITY
       - Centralized permission definitions
       - Easy audit of all GM/Admin commands
       - Rate limiting can be applied uniformly
       
    6. PLAYER EXPERIENCE
       - .dc help shows categorized commands
       - Aliases supported (.mplus = .mythicplus)
       - Consistent feedback messages
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- MIGRATION PLAN
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    Phase 1: Create Commands/ folder structure (1 day)
    - Create folder and CMakeLists.txt
    - Create dc_commands_loader.cpp
    - Create dc_commands_shared.h with macros
    
    Phase 2: Migrate one system at a time (1 day each)
    - Start with simplest: cs_dc_duel.cpp
    - Then cs_dc_prestige.cpp
    - Then cs_dc_aoeloot.cpp
    - Then cs_dc_hotspot.cpp
    - Then cs_dc_hlbg.cpp
    - Then cs_dc_season.cpp
    - Then cs_dc_mplus.cpp (complex)
    - Finally cs_dc_upgrade.cpp (most complex)
    
    Phase 3: Add master commands (1 day)
    - cs_dc_main.cpp
    - cs_dc_admin.cpp
    - cs_dc_debug.cpp
    
    Phase 4: Testing & Polish (1-2 days)
    - Test all commands
    - Add aliases
    - Update documentation
    
    Total: ~10-12 days for complete migration
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- SHARED UTILITIES EXAMPLE (dc_commands_shared.h)
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
```cpp
#pragma once

#include "Chat.h"
#include "Player.h"
#include "WorldSession.h"

namespace DCCommands
{
    // Standard permission levels for DC commands
    enum DCPermission : uint8
    {
        DC_PERM_PLAYER      = SEC_PLAYER,
        DC_PERM_GAMEMASTER  = SEC_GAMEMASTER,
        DC_PERM_ADMIN       = SEC_ADMINISTRATOR,
    };

    // Color codes for consistent output
    constexpr const char* COLOR_TITLE   = "|cffff8000";  // Orange
    constexpr const char* COLOR_SUCCESS = "|cff00ff00";  // Green
    constexpr const char* COLOR_ERROR   = "|cffff0000";  // Red
    constexpr const char* COLOR_INFO    = "|cffffffff";  // White
    constexpr const char* COLOR_VALUE   = "|cffffff00";  // Yellow
    constexpr const char* COLOR_LABEL   = "|cffaaaaaa";  // Gray
    constexpr const char* COLOR_END     = "|r";

    // Standard message formatters
    inline void SendTitle(ChatHandler* handler, const char* title)
    {
        handler->PSendSysMessage("%s=== %s ===%s", COLOR_TITLE, title, COLOR_END);
    }

    inline void SendSuccess(ChatHandler* handler, const char* msg)
    {
        handler->PSendSysMessage("%s✓ %s%s", COLOR_SUCCESS, msg, COLOR_END);
    }

    inline void SendError(ChatHandler* handler, const char* msg)
    {
        handler->PSendSysMessage("%s✗ %s%s", COLOR_ERROR, msg, COLOR_END);
    }

    inline void SendInfo(ChatHandler* handler, const char* label, const char* value)
    {
        handler->PSendSysMessage("%s%s:%s %s%s%s", 
            COLOR_LABEL, label, COLOR_END, COLOR_VALUE, value, COLOR_END);
    }

    // Permission check macro
    #define DC_REQUIRE_PLAYER(handler) \
        Player* player = handler->getSelectedPlayerOrSelf(); \
        if (!player) { \
            DCCommands::SendError(handler, "No player selected"); \
            return false; \
        }

    #define DC_REQUIRE_TARGET(handler) \
        Player* target = handler->getSelectedPlayer(); \
        if (!target) { \
            DCCommands::SendError(handler, "No target selected"); \
            return false; \
        }

} // namespace DCCommands
```
]]

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- COMMAND INVENTORY (Current → Proposed)
-- ═══════════════════════════════════════════════════════════════════════════════════════════
local COMMAND_INVENTORY = {
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- ITEM UPGRADE COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    upgrade = {
        current_files = {
            "ItemUpgrades/ItemUpgradeGMCommands.cpp",
            "ItemUpgrades/ItemUpgradeMechanicsCommands.cpp",
            "ItemUpgrades/ItemUpgradeAddonHandler.cpp",
        },
        proposed_file = "Commands/cs_dc_upgrade.cpp",
        commands = {
            {cmd = ".upgrade info",       perm = "PLAYER",    desc = "Show upgrade info for equipped item"},
            {cmd = ".upgrade stats",      perm = "PLAYER",    desc = "Show player upgrade statistics"},
            {cmd = ".upgrade apply",      perm = "PLAYER",    desc = "Apply upgrade to item (via NPC preferred)"},
            {cmd = ".upgrade tokens",     perm = "PLAYER",    desc = "Show token balance"},
            {cmd = ".upgrade history",    perm = "PLAYER",    desc = "Show upgrade history"},
            {cmd = ".upgrade setlevel",   perm = "GM",        desc = "Set item upgrade level"},
            {cmd = ".upgrade settier",    perm = "GM",        desc = "Set player tier cap"},
            {cmd = ".upgrade addtokens",  perm = "GM",        desc = "Add upgrade tokens"},
            {cmd = ".upgrade reset",      perm = "ADMIN",     desc = "Reset player upgrades"},
            {cmd = ".upgrade reload",     perm = "ADMIN",     desc = "Reload upgrade config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- MYTHIC+ COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    mplus = {
        current_files = {
            "MythicPlus/mythic_plus_commands.cpp",
            "MythicPlus/keystone_admin_commands.cpp",
        },
        proposed_file = "Commands/cs_dc_mplus.cpp",
        commands = {
            {cmd = ".mplus info",         perm = "PLAYER",    desc = "Show current M+ info"},
            {cmd = ".mplus stats",        perm = "PLAYER",    desc = "Show M+ statistics"},
            {cmd = ".mplus key",          perm = "PLAYER",    desc = "Show current keystone"},
            {cmd = ".mplus start",        perm = "PLAYER",    desc = "Start M+ run (in dungeon)"},
            {cmd = ".mplus abandon",      perm = "PLAYER",    desc = "Abandon current run"},
            {cmd = ".mplus leaderboard",  perm = "PLAYER",    desc = "Show top players"},
            {cmd = ".mplus setkey",       perm = "GM",        desc = "Set keystone level"},
            {cmd = ".mplus givekey",      perm = "GM",        desc = "Give keystone to player"},
            {cmd = ".mplus complete",     perm = "GM",        desc = "Force complete current run"},
            {cmd = ".mplus reload",       perm = "ADMIN",     desc = "Reload M+ config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- SEASON COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    season = {
        current_files = {
            "Seasons/SeasonalRewardCommands.cpp",
        },
        proposed_file = "Commands/cs_dc_season.cpp",
        commands = {
            {cmd = ".season info",        perm = "PLAYER",    desc = "Show current season info"},
            {cmd = ".season stats",       perm = "PLAYER",    desc = "Show seasonal stats"},
            {cmd = ".season chest",       perm = "PLAYER",    desc = "Show weekly chest status"},
            {cmd = ".season claim",       perm = "PLAYER",    desc = "Claim weekly chest"},
            {cmd = ".season award",       perm = "GM",        desc = "Award tokens/essence"},
            {cmd = ".season reset",       perm = "GM",        desc = "Reset player season"},
            {cmd = ".season setseason",   perm = "ADMIN",     desc = "Change active season"},
            {cmd = ".season multiplier",  perm = "ADMIN",     desc = "Set reward multipliers"},
            {cmd = ".season reload",      perm = "ADMIN",     desc = "Reload season config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- HLBG COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    hlbg = {
        current_files = {
            "Commands/cs_hl_bg.cpp", -- Note: in core Commands folder
        },
        proposed_file = "Commands/cs_dc_hlbg.cpp",
        commands = {
            {cmd = ".hlbg info",          perm = "PLAYER",    desc = "Show HLBG info"},
            {cmd = ".hlbg stats",         perm = "PLAYER",    desc = "Show HLBG statistics"},
            {cmd = ".hlbg queue",         perm = "PLAYER",    desc = "Queue for HLBG"},
            {cmd = ".hlbg leave",         perm = "PLAYER",    desc = "Leave HLBG queue"},
            {cmd = ".hlbg season",        perm = "PLAYER",    desc = "Show season info"},
            {cmd = ".hlbg leaderboard",   perm = "PLAYER",    desc = "Show rankings"},
            {cmd = ".hlbg setrating",     perm = "GM",        desc = "Set player rating"},
            {cmd = ".hlbg start",         perm = "ADMIN",     desc = "Force start match"},
            {cmd = ".hlbg end",           perm = "ADMIN",     desc = "Force end match"},
            {cmd = ".hlbg reload",        perm = "ADMIN",     desc = "Reload HLBG config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- DUEL COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    duel = {
        current_files = {
            "PhasedDuels/dc_phased_duels.cpp", -- Inline commands
        },
        proposed_file = "Commands/cs_dc_duel.cpp",
        commands = {
            {cmd = ".duel stats",         perm = "PLAYER",    desc = "Show duel statistics"},
            {cmd = ".duel history",       perm = "PLAYER",    desc = "Show recent duels"},
            {cmd = ".duel challenge",     perm = "PLAYER",    desc = "Challenge player"},
            {cmd = ".duel accept",        perm = "PLAYER",    desc = "Accept challenge"},
            {cmd = ".duel decline",       perm = "PLAYER",    desc = "Decline challenge"},
            {cmd = ".duel leaderboard",   perm = "PLAYER",    desc = "Show top duelists"},
            {cmd = ".duel reset",         perm = "GM",        desc = "Reset player stats"},
            {cmd = ".duel reload",        perm = "ADMIN",     desc = "Reload duel config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- PRESTIGE COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    prestige = {
        current_files = {
            "Prestige/dc_prestige_system.cpp", -- Inline commands
        },
        proposed_file = "Commands/cs_dc_prestige.cpp",
        commands = {
            {cmd = ".prestige info",      perm = "PLAYER",    desc = "Show prestige info"},
            {cmd = ".prestige stats",     perm = "PLAYER",    desc = "Show prestige statistics"},
            {cmd = ".prestige reset",     perm = "PLAYER",    desc = "Reset to prestige"},
            {cmd = ".prestige setlevel",  perm = "GM",        desc = "Set prestige level"},
            {cmd = ".prestige reload",    perm = "ADMIN",     desc = "Reload prestige config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- AOE LOOT COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    aoeloot = {
        current_files = {
            "ac_aoeloot.cpp", -- Inline commands
        },
        proposed_file = "Commands/cs_dc_aoeloot.cpp",
        commands = {
            {cmd = ".aoeloot toggle",     perm = "PLAYER",    desc = "Toggle AoE loot"},
            {cmd = ".aoeloot range",      perm = "PLAYER",    desc = "Set loot range"},
            {cmd = ".aoeloot stats",      perm = "PLAYER",    desc = "Show loot statistics"},
            {cmd = ".aoeloot leaderboard",perm = "PLAYER",    desc = "Show top looters"},
            {cmd = ".aoeloot blacklist",  perm = "PLAYER",    desc = "Manage item blacklist"},
            {cmd = ".aoeloot reload",     perm = "ADMIN",     desc = "Reload AoE config"},
        },
    },
    
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    -- HOTSPOT COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════════════════════
    hotspot = {
        current_files = {
            "Hotspot/ac_hotspots.cpp", -- Inline commands (large)
        },
        proposed_file = "Commands/cs_dc_hotspot.cpp",
        commands = {
            {cmd = ".hotspot list",       perm = "PLAYER",    desc = "List active hotspots"},
            {cmd = ".hotspot bonus",      perm = "PLAYER",    desc = "Show current bonus"},
            {cmd = ".hotspot status",     perm = "PLAYER",    desc = "Show hotspot status"},
            {cmd = ".hotspot tp",         perm = "GM",        desc = "Teleport to hotspot"},
            {cmd = ".hotspot spawn",      perm = "ADMIN",     desc = "Spawn new hotspot"},
            {cmd = ".hotspot setbonus",   perm = "ADMIN",     desc = "Set bonus multiplier"},
            {cmd = ".hotspot clear",      perm = "ADMIN",     desc = "Clear all hotspots"},
            {cmd = ".hotspot reload",     perm = "ADMIN",     desc = "Reload hotspot config"},
        },
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- RECOMMENDATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════
--[[
    PRIORITY 1 (High Value, Lower Effort):
    ✓ Create DC/Commands/ folder structure
    ✓ Create dc_commands_shared.h with utilities
    ✓ Migrate cs_dc_duel.cpp (simplest)
    ✓ Migrate cs_dc_prestige.cpp
    
    PRIORITY 2 (High Value, Medium Effort):
    ✓ Migrate cs_dc_season.cpp
    ✓ Migrate cs_dc_aoeloot.cpp
    ✓ Migrate cs_dc_hlbg.cpp
    
    PRIORITY 3 (High Value, Higher Effort):
    ✓ Migrate cs_dc_mplus.cpp (merge 2 files)
    ✓ Migrate cs_dc_upgrade.cpp (merge 3 files)
    ✓ Migrate cs_dc_hotspot.cpp (large inline block)
    
    PRIORITY 4 (Leaderboard Addon):
    ✓ Create dc_addon_leaderboards.cpp
    ✓ Create DC-Leaderboards.lua addon
    ✓ Integrate with all systems
    
    COMBINED TIMELINE:
    - Command consolidation: ~10-12 days
    - Leaderboard addon: ~3-5 days
    - Testing & polish: ~2-3 days
    - Total: ~15-20 days
]]

-- End of evaluation document
