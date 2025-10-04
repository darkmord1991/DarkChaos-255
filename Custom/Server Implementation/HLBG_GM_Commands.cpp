/*
 * HLBG GM Commands Implementation
 * Location: src/server/scripts/Commands/
 * 
 * Add these GM commands for HLBG management
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "World.h"

class HLBG_CommandScript : public CommandScript
{
public:
    HLBG_CommandScript() : CommandScript("HLBG_CommandScript") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> hlbgCommandTable =
        {
            { "config",     rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGConfigCommand,        "" },
            { "stats",      rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGStatsCommand,         "" },
            { "reset",      rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGResetCommand,         "" },
            { "season",     rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGSeasonCommand,        "" },
            { "history",    rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGHistoryCommand,       "" },
            { "players",    rbac::RBAC_PERM_COMMAND_GM,         false, &HandleHLBGPlayersCommand,       "" }
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "hlbg", rbac::RBAC_PERM_COMMAND_GM, false, nullptr, "", hlbgCommandTable }
        };
        return commandTable;
    }

    // Command: .hlbg config [setting] [value]
    static bool HandleHLBGConfigCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            // Display current configuration
            QueryResult result = WorldDatabase.Query("SELECT duration_minutes, max_players_per_side, min_level, max_level, affix_rotation_enabled, resource_cap, queue_type, is_active FROM hlbg_config ORDER BY id DESC LIMIT 1");
            
            if (result)
            {
                Field* fields = result->Fetch();
                handler->PSendSysMessage("=== HLBG Configuration ===");
                handler->PSendSysMessage("Duration: {} minutes", fields[0].GetUInt32());
                handler->PSendSysMessage("Max Players Per Side: {}", fields[1].GetUInt32());
                handler->PSendSysMessage("Level Range: {}-{}", fields[2].GetUInt32(), fields[3].GetUInt32());
                handler->PSendSysMessage("Affix Rotation: {}", fields[4].GetBool() ? "Enabled" : "Disabled");
                handler->PSendSysMessage("Resource Cap: {}", fields[5].GetUInt32());
                handler->PSendSysMessage("Queue Type: {}", fields[6].GetString());
                handler->PSendSysMessage("Status: {}", fields[7].GetBool() ? "Active" : "Inactive");
            }
            else
            {
                handler->SendSysMessage("No HLBG configuration found!");
            }
            return true;
        }

        char* setting = strtok((char*)args, " ");
        char* value = strtok(nullptr, " ");

        if (!setting || !value)
        {
            handler->SendSysMessage("Usage: .hlbg config [duration|maxplayers|minlevel|maxlevel|affix|resources|active] [value]");
            return false;
        }

        std::string settingStr = setting;
        std::string valueStr = value;

        if (settingStr == "duration")
        {
            uint32 minutes = atoi(value);
            if (minutes < 5 || minutes > 120)
            {
                handler->SendSysMessage("Duration must be between 5 and 120 minutes");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET duration_minutes = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", minutes, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG duration set to {} minutes", minutes);
        }
        else if (settingStr == "maxplayers")
        {
            uint32 players = atoi(value);
            if (players < 10 || players > 100)
            {
                handler->SendSysMessage("Max players must be between 10 and 100 per side");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET max_players_per_side = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", players, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG max players per side set to {}", players);
        }
        else if (settingStr == "resources")
        {
            uint32 resources = atoi(value);
            if (resources < 100 || resources > 2000)
            {
                handler->SendSysMessage("Resource cap must be between 100 and 2000");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET resource_cap = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", resources, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG resource cap set to {}", resources);
        }
        else if (settingStr == "affix")
        {
            bool enabled = (valueStr == "on" || valueStr == "true" || valueStr == "1");
            WorldDatabase.PExecute("UPDATE hlbg_config SET affix_rotation_enabled = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", enabled, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG affix rotation {}", enabled ? "enabled" : "disabled");
        }
        else if (settingStr == "active")
        {
            bool active = (valueStr == "on" || valueStr == "true" || valueStr == "1");
            WorldDatabase.PExecute("UPDATE hlbg_config SET is_active = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", active, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG {}", active ? "activated" : "deactivated");
        }
        else
        {
            handler->SendSysMessage("Unknown setting. Available: duration, maxplayers, minlevel, maxlevel, affix, resources, active");
            return false;
        }

        // Broadcast config update to all players
        BroadcastConfigUpdate();
        return true;
    }

    // Command: .hlbg stats [reset]
    static bool HandleHLBGStatsCommand(ChatHandler* handler, char const* args)
    {
        if (*args && strcmp(args, "reset") == 0)
        {
            // Reset all statistics
            WorldDatabase.PExecute("UPDATE hlbg_statistics SET total_runs = 0, alliance_wins = 0, horde_wins = 0, draws = 0, manual_resets = manual_resets + 1, current_streak_faction = 'None', current_streak_count = 0, avg_run_time_seconds = 0, shortest_run_seconds = 0, longest_run_seconds = 0, total_players_participated = 0, total_kills = 0, total_deaths = 0, last_reset_by_gm = NOW(), last_reset_gm_name = '{}' ORDER BY id DESC LIMIT 1", handler->GetSession()->GetPlayer()->GetName());
            
            handler->SendSysMessage("HLBG statistics have been reset!");
            
            // Record in battle history
            WorldDatabase.PExecute("INSERT INTO hlbg_battle_history (battle_end, winner_faction, duration_seconds, ended_by_gm, gm_name, notes) VALUES (NOW(), 'Draw', 0, 1, '{}', 'Statistics reset by GM')", handler->GetSession()->GetPlayer()->GetName());
            
            return true;
        }

        // Display current statistics
        QueryResult result = WorldDatabase.Query("SELECT total_runs, alliance_wins, horde_wins, draws, manual_resets, current_streak_faction, current_streak_count, longest_streak_faction, longest_streak_count, avg_run_time_seconds, total_players_participated, total_kills, total_deaths, last_reset_gm_name, last_reset_by_gm FROM hlbg_statistics ORDER BY id DESC LIMIT 1");
        
        if (result)
        {
            Field* fields = result->Fetch();
            handler->PSendSysMessage("=== HLBG Statistics ===");
            handler->PSendSysMessage("Total Battles: {}", fields[0].GetUInt32());
            handler->PSendSysMessage("Alliance Wins: {} | Horde Wins: {} | Draws: {}", fields[1].GetUInt32(), fields[2].GetUInt32(), fields[3].GetUInt32());
            handler->PSendSysMessage("Manual Resets: {}", fields[4].GetUInt32());
            handler->PSendSysMessage("Current Streak: {} ({})", fields[5].GetString(), fields[6].GetUInt32());
            handler->PSendSysMessage("Longest Streak: {} ({})", fields[7].GetString(), fields[8].GetUInt32());
            handler->PSendSysMessage("Avg Battle Time: {}s", fields[9].GetUInt32());
            handler->PSendSysMessage("Total Participants: {}", fields[10].GetUInt32());
            handler->PSendSysMessage("Total Kills/Deaths: {}/{}", fields[11].GetUInt32(), fields[12].GetUInt32());
            
            if (!fields[13].IsNull())
            {
                handler->PSendSysMessage("Last Reset: {} on {}", fields[13].GetString(), fields[14].GetString());
            }
        }
        else
        {
            handler->SendSysMessage("No HLBG statistics found!");
        }

        return true;
    }

    // Command: .hlbg reset
    static bool HandleHLBGResetCommand(ChatHandler* handler, char const* args)
    {
        // This would reset current battle - implement based on your BG system
        std::string gmName = handler->GetSession()->GetPlayer()->GetName();
        
        // Record manual reset in statistics
        WorldDatabase.PExecute("UPDATE hlbg_statistics SET manual_resets = manual_resets + 1, last_reset_by_gm = NOW(), last_reset_gm_name = '{}' ORDER BY id DESC LIMIT 1", gmName);
        
        // Add battle history entry
        WorldDatabase.PExecute("INSERT INTO hlbg_battle_history (battle_end, winner_faction, duration_seconds, ended_by_gm, gm_name, notes) VALUES (NOW(), 'Draw', 0, 1, '{}', 'Battle manually reset')", gmName);
        
        handler->PSendSysMessage("HLBG battle has been manually reset by {}", gmName);
        
        // TODO: Implement actual battle reset logic here
        // ResetCurrentHLBGBattle();
        
        return true;
    }

    // Command: .hlbg season [create|activate|list] [name] [start] [end]
    static bool HandleHLBGSeasonCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            // Show current season
            QueryResult result = WorldDatabase.Query("SELECT name, start_date, end_date, description FROM hlbg_seasons WHERE is_active = 1 LIMIT 1");
            
            if (result)
            {
                Field* fields = result->Fetch();
                handler->PSendSysMessage("=== Current HLBG Season ===");
                handler->PSendSysMessage("Name: {}", fields[0].GetString());
                handler->PSendSysMessage("Period: {} to {}", fields[1].GetString(), fields[2].GetString());
                handler->PSendSysMessage("Description: {}", fields[3].GetString());
            }
            else
            {
                handler->SendSysMessage("No active HLBG season found!");
            }
            return true;
        }

        char* action = strtok((char*)args, " ");
        
        if (strcmp(action, "list") == 0)
        {
            QueryResult result = WorldDatabase.Query("SELECT id, name, start_date, end_date, is_active FROM hlbg_seasons ORDER BY id DESC LIMIT 10");
            
            if (result)
            {
                handler->PSendSysMessage("=== HLBG Seasons ===");
                do
                {
                    Field* fields = result->Fetch();
                    handler->PSendSysMessage("ID:{} {} ({} to {}) [{}]", 
                        fields[0].GetUInt32(), 
                        fields[1].GetString(), 
                        fields[2].GetString(), 
                        fields[3].GetString(),
                        fields[4].GetBool() ? "ACTIVE" : "inactive");
                } while (result->NextRow());
            }
            else
            {
                handler->SendSysMessage("No seasons found!");
            }
        }
        else if (strcmp(action, "create") == 0)
        {
            char* name = strtok(nullptr, " ");
            char* startDate = strtok(nullptr, " ");
            char* endDate = strtok(nullptr, " ");
            
            if (!name || !startDate || !endDate)
            {
                handler->SendSysMessage("Usage: .hlbg season create [name] [start_date] [end_date]");
                handler->SendSysMessage("Example: .hlbg season create \"Season 2\" \"2025-11-01\" \"2025-12-31\"");
                return false;
            }
            
            WorldDatabase.PExecute("INSERT INTO hlbg_seasons (name, start_date, end_date, created_by) VALUES ('{}', '{}', '{}', '{}')", 
                name, startDate, endDate, handler->GetSession()->GetPlayer()->GetName());
                
            handler->PSendSysMessage("Created new HLBG season: {}", name);
        }
        else if (strcmp(action, "activate") == 0)
        {
            char* seasonId = strtok(nullptr, " ");
            
            if (!seasonId)
            {
                handler->SendSysMessage("Usage: .hlbg season activate [season_id]");
                return false;
            }
            
            // Deactivate all seasons first
            WorldDatabase.Execute("UPDATE hlbg_seasons SET is_active = 0");
            
            // Activate specified season
            WorldDatabase.PExecute("UPDATE hlbg_seasons SET is_active = 1 WHERE id = {}", atoi(seasonId));
            
            handler->PSendSysMessage("Activated HLBG season ID: {}", seasonId);
        }

        return true;
    }

    // Command: .hlbg history [limit]
    static bool HandleHLBGHistoryCommand(ChatHandler* handler, char const* args)
    {
        uint32 limit = 10;
        
        if (*args)
        {
            limit = atoi(args);
            if (limit > 50) limit = 50;
        }

        QueryResult result = WorldDatabase.PQuery("SELECT battle_end, winner_faction, duration_seconds, alliance_resources, horde_resources, affix_id, ended_by_gm, gm_name FROM hlbg_battle_history WHERE battle_end IS NOT NULL ORDER BY id DESC LIMIT {}", limit);
        
        if (result)
        {
            handler->PSendSysMessage("=== HLBG Battle History (Last {}) ===", limit);
            do
            {
                Field* fields = result->Fetch();
                std::string gmInfo = fields[6].GetBool() ? " [GM:" + std::string(fields[7].GetString()) + "]" : "";
                handler->PSendSysMessage("{}: {} won ({}s) A:{} H:{} Affix:{}{}", 
                    fields[0].GetString(),   // battle_end
                    fields[1].GetString(),   // winner_faction
                    fields[2].GetUInt32(),   // duration_seconds
                    fields[3].GetUInt32(),   // alliance_resources
                    fields[4].GetUInt32(),   // horde_resources
                    fields[5].GetUInt32(),   // affix_id
                    gmInfo                   // gm info if applicable
                );
            } while (result->NextRow());
        }
        else
        {
            handler->SendSysMessage("No battle history found!");
        }

        return true;
    }

    // Command: .hlbg players [top|faction]
    static bool HandleHLBGPlayersCommand(ChatHandler* handler, char const* args)
    {
        if (!*args || strcmp(args, "top") == 0)
        {
            // Show top players by battles won
            QueryResult result = WorldDatabase.Query("SELECT player_name, faction, battles_participated, battles_won, total_kills, total_deaths FROM hlbg_player_stats ORDER BY battles_won DESC LIMIT 10");
            
            if (result)
            {
                handler->PSendSysMessage("=== Top HLBG Players ===");
                handler->PSendSysMessage("Name | Faction | Battles | Wins | K/D");
                do
                {
                    Field* fields = result->Fetch();
                    float winRate = fields[2].GetUInt32() > 0 ? (float(fields[3].GetUInt32()) / fields[2].GetUInt32() * 100) : 0;
                    handler->PSendSysMessage("{} | {} | {} | {} ({:.1f}%) | {}/{}", 
                        fields[0].GetString(),   // player_name
                        fields[1].GetString(),   // faction
                        fields[2].GetUInt32(),   // battles_participated
                        fields[3].GetUInt32(),   // battles_won
                        winRate,
                        fields[4].GetUInt32(),   // total_kills
                        fields[5].GetUInt32()    // total_deaths
                    );
                } while (result->NextRow());
            }
            else
            {
                handler->SendSysMessage("No player statistics found!");
            }
        }

        return true;
    }

private:
    static void BroadcastConfigUpdate()
    {
        // Send config updates to all online players with HLBG UI
        SessionMap const& sessions = sWorld->GetAllSessions();
        for (SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (player->IsInWorld())
                {
                    // Send fresh config via AIO
                    // This would call your HandleRequestServerConfig function
                }
            }
        }
    }
};

void AddSC_hlbg_commandscript()
{
    new HLBG_CommandScript();
}
