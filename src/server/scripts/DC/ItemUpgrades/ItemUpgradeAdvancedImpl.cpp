/*
 * DarkChaos Item Upgrade - Advanced Features Implementation (Phase 4D)
 * 
 * Implements:
 * - Respec system (reset upgrades)
 * - Spec-based loadouts
 * - Achievement system
 * - Guild progression tracking
 * 
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "DatabaseEnv.h"
#include "Guild.h"
#include "ItemUpgradeAdvanced.h"
#include "ItemUpgradeManager.h"
#include <sstream>
#include <iomanip>

using namespace Acore::ChatCommands;
using namespace DarkChaos::ItemUpgrade;

// =====================================================================
// Respec Manager Implementation
// =====================================================================

class RespecManagerImpl : public RespecManager
{
private:
    RespecConfig config;

public:
    RespecManagerImpl() = default;

    bool CanRespec(uint32 player_guid) override
    {
        if (!config.allow_full_respec)
            return false;
        
        // Check cooldown
        if (GetRespecCooldown(player_guid) > 0)
            return false;
        
        // Check daily limit
        if (GetRespecCountToday(player_guid) >= config.daily_respec_limit)
            return false;
        
        return true;
    }

    bool RespecItem(uint32 player_guid, uint32 item_guid) override
    {
        // Get current upgrade level
        QueryResult result = CharacterDatabase.Query(
            "SELECT upgrade_level, essence_invested, tokens_invested "
            "FROM dc_player_item_upgrades WHERE player_guid = {} AND item_guid = {}",
            player_guid, item_guid);
        
        if (!result)
            return false;
        
        Field* fields = result->Fetch();
        uint8 current_level = fields[0].Get<uint8>();
        uint32 essence_invested = fields[1].Get<uint32>();
        uint32 tokens_invested = fields[2].Get<uint32>();
        
        // Calculate refund
        if (config.refund_on_respec)
        {
            uint32 essence_refund = (essence_invested * config.refund_percent) / 100;
            uint32 tokens_refund = (tokens_invested * config.refund_percent) / 100;
            
            // Add currency back to player
            CharacterDatabase.Execute(
                "UPDATE dc_player_upgrade_tokens "
                "SET essence = essence + {}, tokens = tokens + {} "
                "WHERE player_guid = {}",
                essence_refund, tokens_refund, player_guid);
        }
        
        // Reset item
        CharacterDatabase.Execute(
            "UPDATE dc_player_item_upgrades "
            "SET upgrade_level = 0, current_stat_multiplier = 1.0, "
            "upgraded_item_level = base_item_level, essence_invested = 0, tokens_invested = 0 "
            "WHERE player_guid = {} AND item_guid = {}",
            player_guid, item_guid);
        
        // Record respec
        CharacterDatabase.Execute(
            "INSERT INTO dc_respec_history "
            "(player_guid, item_guid, previous_level, essence_refunded, tokens_refunded, timestamp) "
            "VALUES ({}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
            player_guid, item_guid, current_level,
            (essence_invested * config.refund_percent) / 100,
            (tokens_invested * config.refund_percent) / 100);
        
        return true;
    }

    bool RespecAll(uint32 player_guid) override
    {
        if (!CanRespec(player_guid))
            return false;
        
        // Get all upgraded items
        QueryResult result = CharacterDatabase.Query(
            "SELECT item_guid, essence_invested, tokens_invested "
            "FROM dc_player_item_upgrades WHERE player_guid = {} AND upgrade_level > 0",
            player_guid);
        
        if (!result)
            return false;
        
        uint32 total_essence = 0;
        uint32 total_tokens = 0;
        
        do
        {
            Field* fields = result->Fetch();
            uint32 item_guid = fields[0].Get<uint32>();
            total_essence += fields[1].Get<uint32>();
            total_tokens += fields[2].Get<uint32>();
            
            RespecItem(player_guid, item_guid);
        } while (result->NextRow());
        
        // Record full respec
        CharacterDatabase.Execute(
            "INSERT INTO dc_respec_log "
            "(player_guid, respec_type, total_essence_refunded, total_tokens_refunded, timestamp) "
            "VALUES ({}, 'FULL', {}, {}, UNIX_TIMESTAMP())",
            player_guid,
            (total_essence * config.refund_percent) / 100,
            (total_tokens * config.refund_percent) / 100);
        
        return true;
    }

    uint32 GetRespecCooldown(uint32 player_guid) override
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT timestamp FROM dc_respec_log "
            "WHERE player_guid = {} ORDER BY timestamp DESC LIMIT 1",
            player_guid);
        
        if (!result)
            return 0;
        
        time_t last_respec = result->Fetch()[0].Get<uint64>();
        time_t now = time(nullptr);
        time_t cooldown = 3600;  // 1 hour cooldown
        
        if (now - last_respec < cooldown)
            return cooldown - (now - last_respec);
        
        return 0;
    }

    uint32 GetRespecCountToday(uint32 player_guid) override
    {
        time_t now = time(nullptr);
        struct tm* timeinfo = localtime(&now);
        timeinfo->tm_hour = 0;
        timeinfo->tm_min = 0;
        timeinfo->tm_sec = 0;
        time_t day_start = mktime(timeinfo);
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_respec_log "
            "WHERE player_guid = {} AND timestamp >= {}",
            player_guid, day_start);
        
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }

    void CalculateRespecCost(uint32 /*player_guid*/, bool full_respec,
                            uint32& out_tokens, uint32& out_essence) override
    {
        if (full_respec)
        {
            out_tokens = config.respec_cost_tokens;
            out_essence = config.respec_cost_essence;
        }
        else
        {
            out_tokens = config.partial_respec_cost;
            out_essence = config.partial_respec_cost / 2;
        }
    }
};

// =====================================================================
// Achievement Manager Implementation
// =====================================================================

class AchievementManagerImpl : public AchievementManager
{
private:
    std::vector<UpgradeAchievement> achievements;

public:
    AchievementManagerImpl()
    {
        InitializeAchievements();
    }

    void InitializeAchievements()
    {
        // Load from database or define hardcoded
        UpgradeAchievement ach;
        
        // First Blood
        ach.achievement_id = 1;
        ach.name = "First Blood";
        ach.description = "Perform your first item upgrade";
        ach.reward_prestige_points = 10;
        ach.reward_tokens = 50;
        ach.is_hidden = false;
        ach.unlock_type = "UPGRADE_COUNT";
        ach.unlock_requirement = 1;
        achievements.push_back(ach);
        
        // Dedicated Upgrader
        ach.achievement_id = 2;
        ach.name = "Dedicated Upgrader";
        ach.description = "Perform 100 upgrades";
        ach.reward_prestige_points = 100;
        ach.reward_tokens = 500;
        ach.unlock_type = "UPGRADE_COUNT";
        ach.unlock_requirement = 100;
        achievements.push_back(ach);
        
        // Maxed Out
        ach.achievement_id = 3;
        ach.name = "Maxed Out";
        ach.description = "Fully upgrade an item to level 15";
        ach.reward_prestige_points = 50;
        ach.reward_tokens = 250;
        ach.unlock_type = "MAX_LEVEL";
        ach.unlock_requirement = 15;
        achievements.push_back(ach);
        
        // Legendary Ascension
        ach.achievement_id = 4;
        ach.name = "Legendary Ascension";
        ach.description = "Fully upgrade a Legendary item";
        ach.reward_prestige_points = 200;
        ach.reward_tokens = 1000;
        ach.unlock_type = "MAX_LEGENDARY";
        ach.unlock_requirement = 1;
        achievements.push_back(ach);
    }

    std::vector<UpgradeAchievement> GetAllAchievements() override
    {
        return achievements;
    }

    bool PlayerHasAchievement(uint32 player_guid, uint32 achievement_id) override
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_player_achievements "
            "WHERE player_guid = {} AND achievement_id = {}",
            player_guid, achievement_id);
        
        return result != nullptr;
    }

    void AwardAchievement(uint32 player_guid, uint32 achievement_id) override
    {
        if (PlayerHasAchievement(player_guid, achievement_id))
            return;
        
        // Find achievement
        UpgradeAchievement* ach = nullptr;
        for (auto& a : achievements)
        {
            if (a.achievement_id == achievement_id)
            {
                ach = &a;
                break;
            }
        }
        
        if (!ach)
            return;
        
        // Award achievement
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_achievements "
            "(player_guid, achievement_id, earned_timestamp) "
            "VALUES ({}, {}, UNIX_TIMESTAMP())",
            player_guid, achievement_id);
        
        // Award rewards
        if (ach->reward_prestige_points > 0)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_player_artifact_mastery "
                "SET total_prestige_points = total_prestige_points + {}, "
                "prestige_points_this_rank = prestige_points_this_rank + {} "
                "WHERE player_guid = {}",
                ach->reward_prestige_points, ach->reward_prestige_points, player_guid);
        }
        
        if (ach->reward_tokens > 0)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_player_upgrade_tokens "
                "SET tokens = tokens + {} WHERE player_guid = {}",
                ach->reward_tokens, player_guid);
        }
    }

    std::vector<UpgradeAchievement> GetPlayerAchievements(uint32 player_guid) override
    {
        std::vector<UpgradeAchievement> player_achievements;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT achievement_id FROM dc_player_achievements WHERE player_guid = {}",
            player_guid);
        
        if (!result)
            return player_achievements;
        
        do
        {
            uint32 ach_id = result->Fetch()[0].Get<uint32>();
            for (const auto& ach : achievements)
            {
                if (ach.achievement_id == ach_id)
                {
                    player_achievements.push_back(ach);
                    break;
                }
            }
        } while (result->NextRow());
        
        return player_achievements;
    }

    uint32 GetAchievementProgress(uint32 player_guid, uint32 achievement_id) override
    {
        // Find achievement to check type
        UpgradeAchievement* ach = nullptr;
        for (auto& a : achievements)
        {
            if (a.achievement_id == achievement_id)
            {
                ach = &a;
                break;
            }
        }
        
        if (!ach)
            return 0;
        
        if (ach->unlock_type == "UPGRADE_COUNT")
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT total_upgrades_applied FROM dc_player_artifact_mastery WHERE player_guid = {}",
                player_guid);
            return result ? result->Fetch()[0].Get<uint32>() : 0;
        }
        else if (ach->unlock_type == "MAX_LEVEL")
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_player_item_upgrades WHERE player_guid = {} AND upgrade_level = 15",
                player_guid);
            return result ? result->Fetch()[0].Get<uint32>() : 0;
        }
        
        return 0;
    }

    void DefineAchievement(const UpgradeAchievement& achievement) override
    {
        achievements.push_back(achievement);
    }

    void CheckAndAwardAchievements(uint32 player_guid) override
    {
        for (const auto& ach : achievements)
        {
            if (PlayerHasAchievement(player_guid, ach.achievement_id))
                continue;
            
            uint32 progress = GetAchievementProgress(player_guid, ach.achievement_id);
            if (progress >= ach.unlock_requirement)
            {
                AwardAchievement(player_guid, ach.achievement_id);
            }
        }
    }
};

// =====================================================================
// Guild Progression Manager Implementation
// =====================================================================

class GuildProgressionManagerImpl : public GuildProgressionManager
{
public:
    GuildUpgradeStats GetGuildStats(uint32 guild_id) override
    {
        GuildUpgradeStats stats;
        stats.guild_id = guild_id;
        
        // Get guild members
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(DISTINCT gm.guid) "
            "FROM guild_member gm WHERE gm.guildid = {}",
            guild_id);
        
        if (result)
            stats.total_members = result->Fetch()[0].Get<uint32>();
        
        // Get upgrade statistics
        result = CharacterDatabase.Query(
            "SELECT COUNT(DISTINCT u.player_guid), SUM(u.upgrade_level), "
            "COUNT(DISTINCT u.item_guid), AVG(u.current_stat_multiplier), "
            "AVG(u.upgraded_item_level - u.base_item_level), "
            "SUM(u.essence_invested), SUM(u.tokens_invested) "
            "FROM dc_player_item_upgrades u "
            "INNER JOIN guild_member gm ON gm.guid = u.player_guid "
            "WHERE gm.guildid = {}",
            guild_id);
        
        if (result)
        {
            Field* fields = result->Fetch();
            stats.members_with_upgrades = fields[0].Get<uint32>();
            stats.total_guild_upgrades = fields[1].Get<uint32>();
            stats.total_items_upgraded = fields[2].Get<uint32>();
            stats.average_ilvl_increase = fields[4].Get<float>();
            stats.total_essence_invested = fields[5].Get<uint32>();
            stats.total_tokens_invested = fields[6].Get<uint32>();
        }
        
        stats.last_updated = time(nullptr);
        
        return stats;
    }

    void UpdateGuildStats(uint32 guild_id) override
    {
        GuildUpgradeStats stats = GetGuildStats(guild_id);
        
        CharacterDatabase.Execute(
            "REPLACE INTO dc_guild_upgrade_stats "
            "(guild_id, total_members, members_with_upgrades, total_guild_upgrades, "
            "total_items_upgraded, average_ilvl_increase, total_essence_invested, "
            "total_tokens_invested, last_updated) "
            "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {})",
            stats.guild_id, stats.total_members, stats.members_with_upgrades,
            stats.total_guild_upgrades, stats.total_items_upgraded,
            stats.average_ilvl_increase, stats.total_essence_invested,
            stats.total_tokens_invested, stats.last_updated);
    }

    std::vector<GuildUpgradeStats> GetGuildLeaderboard(uint32 limit = 10) override
    {
        std::vector<GuildUpgradeStats> leaderboard;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT guild_id, total_members, members_with_upgrades, total_guild_upgrades, "
            "total_items_upgraded, average_ilvl_increase, total_essence_invested, "
            "total_tokens_invested, last_updated "
            "FROM dc_guild_upgrade_stats "
            "ORDER BY total_guild_upgrades DESC "
            "LIMIT {}",
            limit);
        
        if (!result)
            return leaderboard;
        
        do
        {
            GuildUpgradeStats stats;
            Field* fields = result->Fetch();
            stats.guild_id = fields[0].Get<uint32>();
            stats.total_members = fields[1].Get<uint32>();
            stats.members_with_upgrades = fields[2].Get<uint32>();
            stats.total_guild_upgrades = fields[3].Get<uint32>();
            stats.total_items_upgraded = fields[4].Get<uint32>();
            stats.average_ilvl_increase = fields[5].Get<float>();
            stats.total_essence_invested = fields[6].Get<uint32>();
            stats.total_tokens_invested = fields[7].Get<uint32>();
            stats.last_updated = fields[8].Get<uint64>();
            
            leaderboard.push_back(stats);
        } while (result->NextRow());
        
        return leaderboard;
    }

    void AwardGuildBonuses(uint32 guild_id) override
    {
        uint8 tier = GetGuildTier(guild_id);
        
        // Award bonus tokens to all guild members based on tier
        uint32 bonus_tokens = tier * 10;  // 10 tokens per tier
        
        CharacterDatabase.Execute(
            "UPDATE dc_player_upgrade_tokens t "
            "INNER JOIN guild_member gm ON gm.guid = t.player_guid "
            "SET t.tokens = t.tokens + {} "
            "WHERE gm.guildid = {}",
            bonus_tokens, guild_id);
    }

    uint8 GetGuildTier(uint32 guild_id) override
    {
        GuildUpgradeStats stats = GetGuildStats(guild_id);
        
        // Calculate tier based on total upgrades
        if (stats.total_guild_upgrades >= 10000) return 5;
        if (stats.total_guild_upgrades >= 5000) return 4;
        if (stats.total_guild_upgrades >= 2000) return 3;
        if (stats.total_guild_upgrades >= 500) return 2;
        if (stats.total_guild_upgrades >= 100) return 1;
        return 0;
    }
};

// =====================================================================
// Advanced Feature Commands
// =====================================================================

class ItemUpgradeAdvancedCommands : public CommandScript
{
public:
    ItemUpgradeAdvancedCommands() : CommandScript("ItemUpgradeAdvancedCommands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable upgradeAdvancedCommandTable =
        {
            { "respec",       HandleRespecCommand,      SEC_PLAYER, Console::No },
            { "achievements", HandleAchievementsCommand, SEC_PLAYER, Console::No },
            { "guild",        HandleGuildStatsCommand,   SEC_PLAYER, Console::No },
        };
        
        static ChatCommandTable commandTable =
        {
            { "upgradeadv", upgradeAdvancedCommandTable },
        };
        
        return commandTable;
    }

    static bool HandleRespecCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        
        RespecManagerImpl respecMgr;
        
        if (!*args)
        {
            // Show respec info
            uint32 cooldown = respecMgr.GetRespecCooldown(player->GetGUID().GetCounter());
            uint32 count_today = respecMgr.GetRespecCountToday(player->GetGUID().GetCounter());
            
            handler->PSendSysMessage("|cffffd700===== Respec Information =====|r");
            handler->PSendSysMessage("|cff00ff00Respecs Today:|r %u / %u",
                count_today, respecMgr.GetConfig().daily_respec_limit);
            handler->PSendSysMessage("|cff00ff00Cooldown:|r %u seconds", cooldown);
            handler->PSendSysMessage("|cff00ff00Refund Rate:|r %u%%", respecMgr.GetConfig().refund_percent);
            handler->PSendSysMessage("");
            handler->PSendSysMessage("Usage: .upgradeadv respec <all|item_guid>");
            return true;
        }
        
        std::string arg = args;
        if (arg == "all")
        {
            if (!respecMgr.CanRespec(player->GetGUID().GetCounter()))
            {
                handler->PSendSysMessage("|cffff0000Cannot respec: daily limit reached or on cooldown.|r");
                return false;
            }
            
            if (respecMgr.RespecAll(player->GetGUID().GetCounter()))
            {
                handler->PSendSysMessage("|cff00ff00Successfully reset all upgrades!|r");
                handler->PSendSysMessage("Currencies have been refunded at %u%% rate.",
                    respecMgr.GetConfig().refund_percent);
            }
            else
            {
                handler->PSendSysMessage("|cffff0000Respec failed.|r");
            }
        }
        else
        {
            uint32 item_guid = atoi(args);
            if (respecMgr.RespecItem(player->GetGUID().GetCounter(), item_guid))
            {
                handler->PSendSysMessage("|cff00ff00Successfully reset item upgrade!|r");
            }
            else
            {
                handler->PSendSysMessage("|cffff0000Respec failed. Item not found or not upgraded.|r");
            }
        }
        
        return true;
    }

    static bool HandleAchievementsCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        
        AchievementManagerImpl achMgr;
        auto player_achievements = achMgr.GetPlayerAchievements(player->GetGUID().GetCounter());
        
        handler->PSendSysMessage("|cffffd700===== Your Upgrade Achievements =====|r");
        handler->PSendSysMessage("Earned: %u achievements", static_cast<uint32>(player_achievements.size()));
        handler->PSendSysMessage("");
        
        for (const auto& ach : player_achievements)
        {
            handler->PSendSysMessage("|cff00ff00%s|r - %s (Reward: %u prestige, %u tokens)",
                ach.name.c_str(), ach.description.c_str(),
                ach.reward_prestige_points, ach.reward_tokens);
        }
        
        handler->PSendSysMessage("");
        handler->PSendSysMessage("|cffffd700Available Achievements:|r");
        
        auto all_achievements = achMgr.GetAllAchievements();
        for (const auto& ach : all_achievements)
        {
            if (achMgr.PlayerHasAchievement(player->GetGUID().GetCounter(), ach.achievement_id))
                continue;
            
            uint32 progress = achMgr.GetAchievementProgress(player->GetGUID().GetCounter(), ach.achievement_id);
            handler->PSendSysMessage("|cffaaaaaa%s|r - %u / %u",
                ach.name.c_str(), progress, ach.unlock_requirement);
        }
        
        return true;
    }

    static bool HandleGuildStatsCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        
        Guild* guild = player->GetGuild();
        if (!guild)
        {
            handler->PSendSysMessage("You are not in a guild.");
            return false;
        }
        
        GuildProgressionManagerImpl guildMgr;
        GuildUpgradeStats stats = guildMgr.GetGuildStats(guild->GetId());
        
        handler->PSendSysMessage("|cffffd700===== Guild Upgrade Statistics =====|r");
        handler->PSendSysMessage("|cff00ff00Guild:|r %s", guild->GetName().c_str());
        handler->PSendSysMessage("|cff00ff00Total Members:|r %u", stats.total_members);
        handler->PSendSysMessage("|cff00ff00Members with Upgrades:|r %u", stats.members_with_upgrades);
        handler->PSendSysMessage("|cff00ff00Total Guild Upgrades:|r %u", stats.total_guild_upgrades);
        handler->PSendSysMessage("|cff00ff00Total Items Upgraded:|r %u", stats.total_items_upgraded);
        handler->PSendSysMessage("|cff00ff00Average iLvL Gain:|r %.1f", stats.average_ilvl_increase);
        handler->PSendSysMessage("|cff00ff00Total Essence Invested:|r %u", stats.total_essence_invested);
        handler->PSendSysMessage("|cff00ff00Total Tokens Invested:|r %u", stats.total_tokens_invested);
        handler->PSendSysMessage("|cff00ff00Guild Tier:|r %u", guildMgr.GetGuildTier(guild->GetId()));
        
        return true;
    }
};

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeAdvanced()
{
    new ItemUpgradeAdvancedCommands();
}
