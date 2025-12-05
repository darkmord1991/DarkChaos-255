/*
 * Dark Chaos - Welcome/First-Start Addon Handler
 * ================================================
 * 
 * Server-side handler for the DC-Welcome addon.
 * Provides first-login detection, server info sync, and progressive introduction.
 * 
 * Features:
 * - First-login detection and welcome popup trigger
 * - Server configuration sync (max level, season, links)
 * - Progressive feature unlock notifications
 * - Level milestone messages
 * - FAQ data sync
 * - Progress data sync (M+ rating, prestige, seasons)
 * 
 * Message Format:
 * - JSON format: WELC|OPCODE|J|{json}
 * 
 * Opcodes:
 * - CMSG: 0x01 (GET_SERVER_INFO), 0x02 (GET_FAQ), 0x03 (DISMISS), 0x04 (MARK_SEEN), 0x05 (GET_WHATS_NEW), 0x06 (GET_PROGRESS)
 * - SMSG: 0x10 (SHOW_WELCOME), 0x11 (SERVER_INFO), 0x12 (FAQ_DATA), 0x13 (FEATURE_UNLOCK), 0x14 (WHATS_NEW), 0x15 (LEVEL_MILESTONE), 0x16 (PROGRESS_DATA)
 * 
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "DCAddonNamespace.h"
#include "Config.h"
#include "World.h"
#include <string>

namespace DCWelcome
{
    // Module identifier - must match client-side
    constexpr const char* MODULE = "WELC";
    
    // Opcodes - must match client-side
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_SERVER_INFO     = 0x01;
        constexpr uint8 CMSG_GET_FAQ             = 0x02;
        constexpr uint8 CMSG_DISMISS_WELCOME     = 0x03;
        constexpr uint8 CMSG_MARK_FEATURE_SEEN   = 0x04;
        constexpr uint8 CMSG_GET_WHATS_NEW       = 0x05;
        constexpr uint8 CMSG_GET_PROGRESS        = 0x06;  // NEW: Request progress data
        
        // Server -> Client
        constexpr uint8 SMSG_SHOW_WELCOME        = 0x10;
        constexpr uint8 SMSG_SERVER_INFO         = 0x11;
        constexpr uint8 SMSG_FAQ_DATA            = 0x12;  // Dynamic FAQ from DB
        constexpr uint8 SMSG_FEATURE_UNLOCK      = 0x13;
        constexpr uint8 SMSG_WHATS_NEW           = 0x14;
        constexpr uint8 SMSG_LEVEL_MILESTONE     = 0x15;
        constexpr uint8 SMSG_PROGRESS_DATA       = 0x16;  // NEW: Progress data response
    }
    
    // Configuration keys
    namespace Config
    {
        // Welcome system
        constexpr const char* ENABLED = "DCWelcome.Enable";
        constexpr const char* SERVER_NAME = "DCWelcome.ServerName";
        constexpr const char* DISCORD_URL = "DCWelcome.DiscordUrl";
        constexpr const char* WEBSITE_URL = "DCWelcome.WebsiteUrl";
        constexpr const char* WIKI_URL = "DCWelcome.WikiUrl";
        
        // Progressive introduction
        constexpr const char* PROGRESSIVE_ENABLED = "DCWelcome.Progressive.Enabled";
        // Future: Load custom messages from config
        // constexpr const char* LEVEL_10_MESSAGE = "DCWelcome.Progressive.Level10.Message";
        // constexpr const char* LEVEL_20_MESSAGE = "DCWelcome.Progressive.Level20.Message";
        // constexpr const char* LEVEL_80_MESSAGE = "DCWelcome.Progressive.Level80.Message";
    }
    
    // Level milestones for progressive introduction
    // Matches DarkChaos-255 progression (max level 255)
    struct LevelMilestone
    {
        uint8 level;
        std::string feature;
        std::string message;
    };
    
    const std::vector<LevelMilestone> MILESTONES = {
        { 10,  "hotspots",        "Hotspots are now available! Use /hotspot to see active bonus zones." },
        { 20,  "prestige_preview","At level 80, you'll unlock the Prestige system for permanent bonuses!" },
        { 58,  "outland",         "Outland awaits! At 80, unlock Item Upgrades to enhance your gear." },
        { 80,  "endgame",         "Congratulations! You've unlocked Mythic+ Dungeons and the Prestige System!" },
        { 100, "tier_100",        "Level 100! New custom dungeons are now available: The Nexus & The Oculus!" },
        { 130, "tier_130",        "Level 130! Gundrak and Ahn'kahet dungeons are now accessible!" },
        { 160, "tier_160",        "Level 160! Auchindoun dungeons unlocked: Crypts, Mana Tombs, Sethekk, Shadow Lab!" },
        { 200, "tier_200",        "Level 200! You've entered the endgame tier. Elite challenges await!" },
        { 255, "max_level",       "MAXIMUM LEVEL! You've reached the pinnacle of power on DarkChaos-255!" },
    };
    
    // =======================================================================
    // Handler Functions
    // =======================================================================
    
    void SendServerInfo(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        // Get current season info
        uint32 seasonId = 1;
        std::string seasonName = "Season 1";
        
        // Query current season from database (dc_mplus_seasons is in WorldDatabase)
        // Note: Table uses 'season' as primary key, not 'id' or 'season_id'
        QueryResult result = WorldDatabase.Query("SELECT season, name FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1");
        if (result)
        {
            Field* fields = result->Fetch();
            seasonId = fields[0].Get<uint32>();
            seasonName = fields[1].Get<std::string>();
        }
        
        // Build JSON message
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SERVER_INFO);
        msg.Set("serverName", sConfigMgr->GetOption<std::string>(Config::SERVER_NAME, "DarkChaos-255"));
        msg.Set("maxLevel", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
        msg.Set("discordUrl", sConfigMgr->GetOption<std::string>(Config::DISCORD_URL, "discord.gg/darkchaos"));
        msg.Set("websiteUrl", sConfigMgr->GetOption<std::string>(Config::WEBSITE_URL, "darkchaos255.com"));
        msg.Set("wikiUrl", sConfigMgr->GetOption<std::string>(Config::WIKI_URL, "wiki.darkchaos255.com"));
        msg.Set("seasonId", seasonId);
        msg.Set("seasonName", seasonName);
        
        msg.Send(player);
    }
    
    void SendShowWelcome(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        // Get season info
        uint32 seasonId = 1;
        std::string seasonName = "Season 1";
        
        // Query current season from database (dc_mplus_seasons is in WorldDatabase)
        // Note: Table uses 'season' as primary key, not 'id' or 'season_id'
        QueryResult result = WorldDatabase.Query("SELECT season, name FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1");
        if (result)
        {
            Field* fields = result->Fetch();
            seasonId = fields[0].Get<uint32>();
            seasonName = fields[1].Get<std::string>();
        }
        
        // Build welcome message with embedded server info
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SHOW_WELCOME);
        msg.Set("serverName", sConfigMgr->GetOption<std::string>(Config::SERVER_NAME, "DarkChaos-255"));
        msg.Set("maxLevel", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
        msg.Set("discordUrl", sConfigMgr->GetOption<std::string>(Config::DISCORD_URL, "discord.gg/darkchaos"));
        msg.Set("websiteUrl", sConfigMgr->GetOption<std::string>(Config::WEBSITE_URL, "darkchaos255.com"));
        msg.Set("seasonId", seasonId);
        msg.Set("seasonName", seasonName);
        msg.Set("isFirstLogin", true);
        
        msg.Send(player);
    }
    
    void SendLevelMilestone(Player* player, uint8 level)
    {
        if (!player || !player->GetSession())
            return;
        
        for (const auto& milestone : MILESTONES)
        {
            if (milestone.level == level)
            {
                DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_LEVEL_MILESTONE);
                msg.Set("level", milestone.level);
                msg.Set("feature", milestone.feature);
                msg.Set("message", milestone.message);
                
                msg.Send(player);
                break;
            }
        }
    }
    
    void SendFeatureUnlock(Player* player, const std::string& feature, const std::string& message)
    {
        if (!player || !player->GetSession())
            return;
        
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_FEATURE_UNLOCK);
        msg.Set("feature", feature);
        msg.Set("message", message);
        
        msg.Send(player);
    }
    
    // =======================================================================
    // Message Handlers
    // =======================================================================
    
    void HandleGetServerInfo(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendServerInfo(player);
    }
    
    void HandleGetFAQ(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;
        
        // Parse optional category filter from request
        std::string categoryFilter = "";
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("category"))
        {
            categoryFilter = json["category"].AsString();
        }
        
        // Build FAQ query - load from dc_welcome_faq table
        std::string query = "SELECT id, category, question, answer FROM dc_welcome_faq WHERE active = 1";
        if (!categoryFilter.empty() && categoryFilter != "all")
        {
            query += " AND category = '" + categoryFilter + "'";
        }
        query += " ORDER BY category, priority DESC, id";
        
        QueryResult result = CharacterDatabase.Query(query);
        
        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_FAQ_DATA);
        
        if (result)
        {
            DCAddon::JsonValue entriesArray;
            entriesArray.SetArray();
            
            int count = 0;
            do
            {
                Field* fields = result->Fetch();
                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                entry.Set("category", DCAddon::JsonValue(fields[1].Get<std::string>()));
                entry.Set("question", DCAddon::JsonValue(fields[2].Get<std::string>()));
                entry.Set("answer", DCAddon::JsonValue(fields[3].Get<std::string>()));
                entriesArray.Push(entry);
                count++;
            } while (result->NextRow());
            
            response.Set("entries", entriesArray.Encode());
            response.Set("count", count);
        }
        else
        {
            response.Set("entries", "[]");
            response.Set("count", 0);
        }
        
        response.Send(player);
    }
    
    void HandleDismissWelcome(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;
        
        // Record that player dismissed the welcome screen
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_welcome (guid, account_id, dismissed_at, show_on_login) "
            "VALUES ({}, {}, NOW(), 0) "
            "ON DUPLICATE KEY UPDATE dismissed_at = NOW(), show_on_login = 0",
            player->GetGUID().GetCounter(),
            player->GetSession()->GetAccountId()
        );
    }
    
    void HandleMarkFeatureSeen(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;
        
        std::string feature = json["feature"].AsString();
        if (feature.empty())
            return;
        
        // Record that player has seen this feature intro
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_seen_features (guid, feature, seen_at, dismissed) "
            "VALUES ({}, '{}', NOW(), 1) "
            "ON DUPLICATE KEY UPDATE seen_at = NOW(), dismissed = 1",
            player->GetGUID().GetCounter(),
            feature
        );
    }
    
    void HandleGetWhatsNew(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;
        
        // Load What's New from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT id, version, title, content, icon, category FROM dc_welcome_whats_new "
            "WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW()) "
            "ORDER BY priority DESC, id DESC LIMIT 10"
        );
        
        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_WHATS_NEW);
        
        if (result)
        {
            DCAddon::JsonValue entriesArray;
            entriesArray.SetArray();
            std::string latestVersion = "";
            int count = 0;
            
            do
            {
                Field* fields = result->Fetch();
                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                entry.Set("version", DCAddon::JsonValue(fields[1].Get<std::string>()));
                entry.Set("title", DCAddon::JsonValue(fields[2].Get<std::string>()));
                entry.Set("content", DCAddon::JsonValue(fields[3].Get<std::string>()));
                entry.Set("icon", DCAddon::JsonValue(fields[4].Get<std::string>()));
                entry.Set("category", DCAddon::JsonValue(fields[5].Get<std::string>()));
                entriesArray.Push(entry);
                count++;
                
                if (latestVersion.empty())
                    latestVersion = fields[1].Get<std::string>();
            } while (result->NextRow());
            
            response.Set("version", latestVersion);
            response.Set("entries", entriesArray.Encode());
            response.Set("count", count);
        }
        else
        {
            // Fallback to hardcoded message if no DB entries
            response.Set("version", "1.0.0");
            response.Set("content", "Welcome to DarkChaos-255! Features include Mythic+, Prestige, Hotspots, and more.");
            response.Set("count", 0);
        }
        
        response.Send(player);
    }
    
    // =======================================================================
    // Progress Data Handler - NEW
    // =======================================================================
    
    void HandleGetProgress(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;
        
        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_PROGRESS_DATA);
        
        // Get M+ Rating from dc_mplus_player_rating table
        uint32 mythicRating = 0;
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT rating FROM dc_mplus_player_rating WHERE guid = {}",
                player->GetGUID().GetCounter()
            );
            if (result)
                mythicRating = result->Fetch()[0].Get<uint32>();
        }
        response.Set("mythicRating", static_cast<int32>(mythicRating));
        
        // Get Prestige Level from dc_prestige_player table (if exists)
        uint32 prestigeLevel = 0;
        uint32 prestigeXP = 0;
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT prestige_level, prestige_xp FROM dc_prestige_player WHERE guid = {}",
                player->GetGUID().GetCounter()
            );
            if (result)
            {
                prestigeLevel = result->Fetch()[0].Get<uint32>();
                prestigeXP = result->Fetch()[1].Get<uint32>();
            }
        }
        response.Set("prestigeLevel", static_cast<int32>(prestigeLevel));
        response.Set("prestigeXP", static_cast<int32>(prestigeXP));
        
        // Get Season Rank/Points from dc_mplus_season_player table
        uint32 seasonPoints = 0;
        uint32 seasonRank = 0;
        {
            // Get active season first
            QueryResult seasonResult = WorldDatabase.Query(
                "SELECT season FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1"
            );
            if (seasonResult)
            {
                uint32 activeSeason = seasonResult->Fetch()[0].Get<uint32>();
                
                QueryResult result = CharacterDatabase.Query(
                    "SELECT points FROM dc_mplus_season_player WHERE guid = {} AND season = {}",
                    player->GetGUID().GetCounter(), activeSeason
                );
                if (result)
                    seasonPoints = result->Fetch()[0].Get<uint32>();
            }
        }
        response.Set("seasonPoints", static_cast<int32>(seasonPoints));
        response.Set("seasonRank", static_cast<int32>(seasonRank));
        
        // Get Weekly Vault Progress (M+ runs this week)
        uint32 weeklyVaultProgress = 0;
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_mplus_runs WHERE guid = {} AND completed = 1 "
                "AND YEARWEEK(completed_at, 1) = YEARWEEK(NOW(), 1)",
                player->GetGUID().GetCounter()
            );
            if (result)
                weeklyVaultProgress = std::min(static_cast<uint32>(3), result->Fetch()[0].Get<uint32>());
        }
        response.Set("weeklyVaultProgress", static_cast<int32>(weeklyVaultProgress));
        
        // Get Achievement Points
        uint32 achievementPoints = 0;
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT SUM(COALESCE(a.points, 10)) FROM character_achievement ca "
                "LEFT JOIN achievement a ON ca.achievement = a.id "
                "WHERE ca.guid = {}",
                player->GetGUID().GetCounter()
            );
            if (result && !result->Fetch()[0].IsNull())
                achievementPoints = result->Fetch()[0].Get<uint32>();
        }
        response.Set("achievementPoints", static_cast<int32>(achievementPoints));
        
        // Keys completed this week
        uint32 keysThisWeek = 0;
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_mplus_runs WHERE guid = {} AND completed = 1 "
                "AND YEARWEEK(completed_at, 1) = YEARWEEK(NOW(), 1)",
                player->GetGUID().GetCounter()
            );
            if (result)
                keysThisWeek = result->Fetch()[0].Get<uint32>();
        }
        response.Set("keysThisWeek", static_cast<int32>(keysThisWeek));
        
        response.Send(player);
    }
    
    void RegisterHandlers()
    {
        using namespace DCAddon;
        
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_SERVER_INFO, HandleGetServerInfo);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_FAQ, HandleGetFAQ);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_DISMISS_WELCOME, HandleDismissWelcome);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_MARK_FEATURE_SEEN, HandleMarkFeatureSeen);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_WHATS_NEW, HandleGetWhatsNew);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_PROGRESS, HandleGetProgress);
        
        MessageRouter::Instance().SetModuleEnabled(MODULE, true);
    }
    
} // namespace DCWelcome

// ===========================================================================
// Player Scripts for First Login and Level Up
// ===========================================================================

class DCWelcome_PlayerScript : public PlayerScript
{
public:
    DCWelcome_PlayerScript() : PlayerScript("DCWelcome_PlayerScript") { }
    
    // Called when player logs in
    void OnPlayerLogin(Player* player) override
    {
        if (!player || !sConfigMgr->GetOption<bool>(DCWelcome::Config::ENABLED, true))
            return;
        
        // Check if this is a first login (new character - total played time is 0)
        if (player->GetTotalPlayedTime() == 0)
        {
            // This is effectively a first login - show welcome popup
            DCWelcome::SendShowWelcome(player);
            return;
        }
        
        // Check if player has dismissed welcome
        QueryResult result = CharacterDatabase.Query(
            "SELECT dismissed_at FROM dc_player_welcome WHERE guid = {}",
            player->GetGUID().GetCounter()
        );
        
        // Always send server info on login (for version updates, season changes, etc.)
        DCWelcome::SendServerInfo(player);
    }
    
    // Called when player levels up
    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        if (!player || !sConfigMgr->GetOption<bool>(DCWelcome::Config::PROGRESSIVE_ENABLED, true))
            return;
        
        uint8 newLevel = player->GetLevel();
        
        // Check for milestone levels
        for (const auto& milestone : DCWelcome::MILESTONES)
        {
            if (newLevel == milestone.level && oldLevel < milestone.level)
            {
                DCWelcome::SendLevelMilestone(player, newLevel);
                break;
            }
        }
    }
};

// ===========================================================================
// Script Loader
// ===========================================================================

void AddSC_dc_addon_welcome()
{
    // Register message handlers
    DCWelcome::RegisterHandlers();
    
    // Register player script
    new DCWelcome_PlayerScript();
}
