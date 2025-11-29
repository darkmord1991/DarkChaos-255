/*
 * Dark Chaos - Mythic+ Addon Module Handler
 * ==========================================
 * 
 * Handles DC|MPLUS|... messages for Mythic+ dungeon system.
 * Integrates with MythicPlusRunManager.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "../MythicPlus/MythicPlusRunManager.h"

namespace DCAddon
{
namespace MythicPlus
{
    // Send current keystone info
    static void SendKeyInfo(Player* player)
    {
        // Query player's current keystone
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, depleted FROM dc_mythic_keystones WHERE player_guid = {}",
            guid);
        
        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = (*result)[2].Get<bool>();
            
            // Get dungeon name
            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mythic_plus_dungeons WHERE dungeon_id = {}",
                dungeonId);
            if (nameResult)
                dungeonName = (*nameResult)[0].Get<std::string>();
            
            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Add(1)  // has keystone
                .Add(dungeonId)
                .Add(dungeonName)
                .Add(level)
                .Add(depleted)
                .Send(player);
        }
        else
        {
            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Add(0)  // no keystone
                .Send(player);
        }
    }
    
    // Send current week's affixes
    static void SendAffixes(Player* player)
    {
        // Get current affixes from MythicPlusRunManager or config
        // For now, query from database
        QueryResult result = WorldDatabase.Query(
            "SELECT affix_id, affix_name, affix_description FROM dc_mythic_plus_weekly_affixes "
            "WHERE week_number = (SELECT MAX(week_number) FROM dc_mythic_plus_weekly_affixes)");
        
        std::string affixList;
        if (result)
        {
            bool first = true;
            do
            {
                if (!first) affixList += ";";
                first = false;
                
                uint32 id = (*result)[0].Get<uint32>();
                std::string name = (*result)[1].Get<std::string>();
                std::string desc = (*result)[2].Get<std::string>();
                
                affixList += std::to_string(id) + ":" + name + ":" + desc;
            } while (result->NextRow());
        }
        
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIXES)
            .Add(affixList)
            .Send(player);
    }
    
    // Send player's best runs
    static void SendBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, completion_time, deaths, season "
            "FROM dc_mythic_plus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
            guid);
        
        std::string runList;
        if (result)
        {
            bool first = true;
            do
            {
                if (!first) runList += ";";
                first = false;
                
                uint32 dungeonId = (*result)[0].Get<uint32>();
                uint32 level = (*result)[1].Get<uint32>();
                uint32 time = (*result)[2].Get<uint32>();
                uint32 deaths = (*result)[3].Get<uint32>();
                uint32 season = (*result)[4].Get<uint32>();
                
                runList += std::to_string(dungeonId) + ":" + std::to_string(level) + ":" 
                        + std::to_string(time) + ":" + std::to_string(deaths) + ":" 
                        + std::to_string(season);
            } while (result->NextRow());
        }
        
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_BEST_RUNS)
            .Add(runList)
            .Send(player);
    }
    
    // Handler: Get keystone info
    static void HandleGetKeyInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        SendKeyInfo(player);
    }
    
    // Handler: Get affixes
    static void HandleGetAffixes(Player* player, const ParsedMessage& /*msg*/)
    {
        SendAffixes(player);
    }
    
    // Handler: Get best runs
    static void HandleGetBestRuns(Player* player, const ParsedMessage& /*msg*/)
    {
        SendBestRuns(player);
    }
    
    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEY_INFO, HandleGetKeyInfo);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_AFFIXES, HandleGetAffixes);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_BEST_RUNS, HandleGetBestRuns);
        
        LOG_INFO("dc.addon", "Mythic+ module handlers registered");
    }
    
    // Broadcast run update to all party members
    void BroadcastRunUpdate(uint32 /*runId*/, uint32 /*elapsed*/, uint32 /*remaining*/, 
                           uint32 /*deaths*/, uint32 /*bossesKilled*/, uint32 /*bossesTotal*/,
                           uint32 /*enemiesKilled*/, bool /*failed*/, bool /*completed*/)
    {
        // This would be called from MythicPlusRunManager
        // Get all players in the run and send updates
        
        // For now, placeholder - actual implementation needs RunManager integration
    }
    
    // Send HUD update to player (pipe-delimited)
    void SendHUDUpdate(Player* player, const std::string& jsonData)
    {
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
            .Add(jsonData)
            .Send(player);
    }
    
    // ========================================================================
    // JSON HANDLERS - For complex data that benefits from structured format
    // ========================================================================
    
    // Send key info as JSON (more readable, easier to extend)
    void SendJsonKeyInfo(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, depleted FROM dc_mythic_keystones WHERE player_guid = {}",
            guid);
        
        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = (*result)[2].Get<bool>();
            
            // Get dungeon name
            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mythic_plus_dungeons WHERE dungeon_id = {}",
                dungeonId);
            if (nameResult)
                dungeonName = (*nameResult)[0].Get<std::string>();
            
            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Set("hasKey", true)
                .Set("dungeonId", dungeonId)
                .Set("dungeonName", dungeonName)
                .Set("level", level)
                .Set("depleted", depleted)
                .Send(player);
        }
        else
        {
            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Set("hasKey", false)
                .Send(player);
        }
    }
    
    // Send affixes as JSON
    void SendJsonAffixes(Player* player)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT affix_id, affix_name, affix_description FROM dc_mythic_plus_weekly_affixes "
            "WHERE week_number = (SELECT MAX(week_number) FROM dc_mythic_plus_weekly_affixes)");
        
        JsonValue affixArray;
        affixArray.SetArray();
        
        if (result)
        {
            do
            {
                JsonValue affix;
                affix.SetObject();
                affix.Set("id", JsonValue((*result)[0].Get<int32>()));
                affix.Set("name", JsonValue((*result)[1].Get<std::string>()));
                affix.Set("description", JsonValue((*result)[2].Get<std::string>()));
                affixArray.Push(affix);
            } while (result->NextRow());
        }
        
        // Calculate current week number
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
        uint32 weekNumber = (weekStart / (7 * 24 * 60 * 60)) % 52;
        
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIXES)
            .Set("weekNumber", weekNumber)
            .Set("affixes", affixArray.Encode())
            .Send(player);
    }
    
    // Send best runs as JSON
    void SendJsonBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, completion_time, deaths, season "
            "FROM dc_mythic_plus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
            guid);
        
        JsonValue runsArray;
        runsArray.SetArray();
        
        if (result)
        {
            do
            {
                JsonValue run;
                run.SetObject();
                run.Set("dungeonId", JsonValue((*result)[0].Get<int32>()));
                run.Set("level", JsonValue((*result)[1].Get<int32>()));
                run.Set("time", JsonValue((*result)[2].Get<int32>()));
                run.Set("deaths", JsonValue((*result)[3].Get<int32>()));
                run.Set("season", JsonValue((*result)[4].Get<int32>()));
                
                // Get dungeon name
                uint32 dungeonId = (*result)[0].Get<uint32>();
                QueryResult nameResult = WorldDatabase.Query(
                    "SELECT dungeon_name FROM dc_mythic_plus_dungeons WHERE dungeon_id = {}",
                    dungeonId);
                if (nameResult)
                    run.Set("dungeonName", JsonValue((*nameResult)[0].Get<std::string>()));
                else
                    run.Set("dungeonName", JsonValue("Unknown"));
                
                runsArray.Push(run);
            } while (result->NextRow());
        }
        
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_BEST_RUNS)
            .Set("runs", runsArray.Encode())
            .Set("count", static_cast<int32>(runsArray.Size()))
            .Send(player);
    }
    
    // Send run update as JSON (for HUD)
    void SendJsonRunUpdate(Player* player, uint32 runId, uint32 elapsed, uint32 remaining,
                           uint32 deaths, uint32 bossesKilled, uint32 bossesTotal,
                           uint32 enemyCount, uint32 enemyRequired, bool failed, bool completed)
    {
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
            .Set("runId", runId)
            .Set("elapsed", elapsed)
            .Set("remaining", remaining)
            .Set("deaths", deaths)
            .Set("bossesKilled", bossesKilled)
            .Set("bossesTotal", bossesTotal)
            .Set("enemyCount", enemyCount)
            .Set("enemyRequired", enemyRequired)
            .Set("failed", failed)
            .Set("completed", completed)
            .Send(player);
    }
    
    // Send run start notification as JSON
    void SendJsonRunStart(Player* player, uint32 keyLevel, uint32 dungeonId, 
                          const std::string& dungeonName, uint32 timeLimit,
                          const std::vector<uint32>& affixIds)
    {
        std::string affixListStr;
        for (size_t i = 0; i < affixIds.size(); ++i)
        {
            if (i > 0) affixListStr += ",";
            affixListStr += std::to_string(affixIds[i]);
        }
        
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_RUN_START)
            .Set("keyLevel", keyLevel)
            .Set("dungeonId", dungeonId)
            .Set("dungeonName", dungeonName)
            .Set("timeLimit", timeLimit)
            .Set("affixes", affixListStr)
            .Send(player);
    }
    
    // Send run end notification as JSON
    void SendJsonRunEnd(Player* player, bool success, uint32 timeElapsed, int32 keyChange,
                        uint32 score, uint32 newKeyLevel)
    {
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_RUN_END)
            .Set("success", success)
            .Set("timeElapsed", timeElapsed)
            .Set("keyChange", keyChange)
            .Set("score", score)
            .Set("newKeyLevel", newKeyLevel)
            .Send(player);
    }
    
    // Helper to get current week number
    static uint32 GetCurrentWeekNumber()
    {
        time_t now = time(nullptr);
        struct tm* timeinfo = localtime(&now);
        
        // Simple week calculation from epoch
        return static_cast<uint32>((now / 604800) % 52);
    }

}  // namespace MythicPlus
}  // namespace DCAddon

void AddSC_dc_addon_mythicplus()
{
    DCAddon::MythicPlus::RegisterHandlers();
}
