/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * NPC: Archivist Serah (100060) - Mythic+ Statistics Board
 * Location: Near Mythic teleporter hub (Dalaran)
 * Mirrors Hinterland BG stats presentation
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicPlusRunManager.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectGuid.h"

enum StatisticsActions
{
    ACTION_MY_STATS = 1,
    ACTION_LEADERBOARD = 2,
    ACTION_DUNGEON_DETAILS = 3,
    ACTION_CLOSE = 99
};

class npc_mythic_plus_statistics : public CreatureScript
{
public:
    npc_mythic_plus_statistics() : CreatureScript("npc_mythic_plus_statistics") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Mythic+ Statistics ===|r", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
            "|cff00ff00My Statistics|r", 
            GOSSIP_SENDER_MAIN, ACTION_MY_STATS);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
            "|cffffff00Top 10 Leaderboard|r", 
            GOSSIP_SENDER_MAIN, ACTION_LEADERBOARD);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
            "|cff1eff00Per-Dungeon Best Times|r", 
            GOSSIP_SENDER_MAIN, ACTION_DUNGEON_DETAILS);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, 
            "|cffaaaaaa[Close]|r", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        switch (action)
        {
            case ACTION_MY_STATS:
                DisplayPlayerStatistics(player, creature);
                break;
                
            case ACTION_LEADERBOARD:
                DisplayLeaderboard(player, creature);
                break;
                
            case ACTION_DUNGEON_DETAILS:
                DisplayDungeonDetails(player, creature);
                break;
                
            case ACTION_CLOSE:
            default:
                CloseGossipMenuFor(player);
                return true;
        }

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

private:
    void DisplayPlayerStatistics(Player* player, Creature* creature)
    {
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 guidLow = player->GetGUID().GetCounter();
        
        // Query overall stats
        QueryResult result = CharacterDatabase.Query(
            "SELECT MAX(best_level) AS best_key, SUM(total_runs) AS total_runs, "
            "AVG(avg_score) AS avg_score, SUM(total_deaths) AS total_deaths, SUM(total_wipes) AS total_wipes "
            "FROM dc_mplus_scores WHERE character_guid = {} AND season_id = {}",
            guidLow, seasonId);
        
        if (!result)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff0000No Mythic+ data this season|r", 
                GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            return;
        }
        
        Field* fields = result->Fetch();
        uint8 bestKey = fields[0].Get<uint8>();
        uint32 totalRuns = fields[1].Get<uint32>();
        uint32 avgScore = fields[2].Get<uint32>();
        uint32 totalDeaths = fields[3].Get<uint32>();
        uint32 totalWipes = fields[4].Get<uint32>();
        
        // Color code best key (green for 10+, orange for 15+)
        std::string bestKeyColor = bestKey >= 15 ? "|cffff8000" : (bestKey >= 10 ? "|cff00ff00" : "|cffffffff");
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000Your Season Statistics|r", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            bestKeyColor + "Best Key Cleared:|r M+" + std::to_string(bestKey), 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffffffffTotal Runs:|r " + std::to_string(totalRuns), 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffffffffAverage Score:|r " + std::to_string(avgScore), 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        // Death budget efficiency (lower is better)
        float deathsPerRun = totalRuns > 0 ? static_cast<float>(totalDeaths) / totalRuns : 0.0f;
        std::string efficiencyColor = deathsPerRun < 2.0f ? "|cff00ff00" : (deathsPerRun < 5.0f ? "|cffffff00" : "|cffff0000");
        
        char buffer[128];
        snprintf(buffer, sizeof(buffer), "%sDeaths Per Run:|r %.2f", efficiencyColor.c_str(), deathsPerRun);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, buffer, GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffffffffTotal Wipes:|r " + std::to_string(totalWipes), 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        // Vault progress
        QueryResult vaultResult = CharacterDatabase.Query(
            "SELECT runs_completed FROM dc_weekly_vault WHERE character_guid = {} AND season_id = {} AND week_start = {}",
            guidLow, seasonId, sMythicRuns->GetWeekStartTimestamp());
        
        uint8 weeklyRuns = vaultResult ? vaultResult->Fetch()[0].Get<uint8>() : 0;
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffffff00This Week:|r " + std::to_string(weeklyRuns) + " runs completed", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Back]|r", GOSSIP_SENDER_MAIN, 0);
    }

    void DisplayLeaderboard(Player* player, Creature* /*creature*/)
    {
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, s.best_level, s.total_runs, s.avg_score "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} "
            "ORDER BY s.best_level DESC, s.avg_score DESC "
            "LIMIT 10",
            seasonId);
        
        if (!result)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff0000No leaderboard data available|r", 
                GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            return;
        }
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000Top 10 Players This Season|r", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        uint8 rank = 1;
        do
        {
            Field* fields = result->Fetch();
            std::string playerName = fields[0].Get<std::string>();
            uint8 bestLevel = fields[1].Get<uint8>();
            uint32 totalRuns = fields[2].Get<uint32>();
            uint32 avgScore = fields[3].Get<uint32>();
            
            std::string rankColor = rank <= 3 ? "|cffff8000" : "|cffffffff";
            char buffer[256];
            snprintf(buffer, sizeof(buffer), "%s#%u|r %s - M+%u (%u runs, %u avg score)", 
                rankColor.c_str(), rank, playerName.c_str(), bestLevel, totalRuns, avgScore);
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, buffer, GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            ++rank;
            
        } while (result->NextRow() && rank <= 10);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Back]|r", GOSSIP_SENDER_MAIN, 0);
    }

    void DisplayDungeonDetails(Player* player, Creature* /*creature*/)
    {
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 guidLow = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT p.name, s.best_level, s.best_duration, s.total_runs "
            "FROM dc_mplus_scores s "
            "JOIN dc_dungeon_mythic_profile p ON s.map_id = p.map_id "
            "WHERE s.character_guid = {} AND s.season_id = {} AND s.best_level > 0 "
            "ORDER BY s.best_level DESC, p.name ASC "
            "LIMIT 10",
            guidLow, seasonId);
        
        if (!result)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff0000No dungeon clears this season|r", 
                GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            return;
        }
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cff00ff00Your Best Dungeon Clears|r", 
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        
        do
        {
            Field* fields = result->Fetch();
            std::string dungeonName = fields[0].Get<std::string>();
            uint8 bestLevel = fields[1].Get<uint8>();
            uint32 bestTime = fields[2].Get<uint32>();
            uint32 totalRuns = fields[3].Get<uint32>();
            
            uint32 minutes = bestTime / 60;
            uint32 seconds = bestTime % 60;
            
            char buffer[256];
            snprintf(buffer, sizeof(buffer), "|cff1eff00%s|r - M+%u (%um %us, %u runs)", 
                dungeonName.c_str(), bestLevel, minutes, seconds, totalRuns);
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, buffer, GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            
        } while (result->NextRow());
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Back]|r", GOSSIP_SENDER_MAIN, 0);
    }
};

void AddSC_npc_mythic_plus_statistics()
{
    new npc_mythic_plus_statistics();
}
