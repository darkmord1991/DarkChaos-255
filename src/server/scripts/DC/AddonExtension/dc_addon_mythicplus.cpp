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
#include "WorldSessionMgr.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "../MythicPlus/MythicPlusRunManager.h"
#include "../MythicPlus/MythicPlusConstants.h"

namespace DCAddon
{
namespace MythicPlus
{
    // Send current keystone info
    static void SendKeyInfo(Player* player)
    {
        // Query player's current keystone from dc_mplus_keystones
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT map_id, level FROM dc_mplus_keystones WHERE character_guid = {}",
            guid);
        
        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = false;  // dc_mplus_keystones doesn't have depleted column
            
            // Get dungeon name
            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_dungeons WHERE map_id = {}",
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
            "SELECT affix_id, affix_name, affix_description FROM dc_mplus_weekly_affixes "
            "WHERE week_number = (SELECT MAX(week_number) FROM dc_mplus_weekly_affixes)");
        
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

    // Send canonical keystone item IDs as JSON list
    static void SendJsonKeystoneList(Player* player)
    {
        JsonValue itemsArr;
        itemsArr.SetArray();
        for (uint8 i = 0; i < 19; ++i)
        {
            itemsArr.Push(JsonValue(static_cast<int32>(MythicPlusConstants::KEYSTONE_ITEM_IDS[i])));
        }

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEYSTONE_LIST)
            .Set("items", itemsArr.Encode())
            .Send(player);
    }
    
    // Send player's best runs
    static void SendBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, completion_time, deaths, season "
            "FROM dc_mplus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
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

    // Handler: Get canonical keystone list
    static void HandleGetKeystoneList(Player* player, const ParsedMessage& /*msg*/)
    {
        SendJsonKeystoneList(player);
    }
    
    // Forward declaration for HUD handler (defined later)
    static void HandleRequestHud(Player* player, const ParsedMessage& msg);

    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEY_INFO, HandleGetKeyInfo);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_AFFIXES, HandleGetAffixes);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_BEST_RUNS, HandleGetBestRuns);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEYSTONE_LIST, HandleGetKeystoneList);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_REQUEST_HUD, HandleRequestHud);
        
        LOG_INFO("dc.addon", "Mythic+ module handlers registered (includes HUD cache manager)");
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
    // HUD CACHE MANAGER - Migrated from DCMythicPlusHUD.lua
    // ========================================================================
    
    class HudCacheMgr
    {
    private:
        struct CacheEntry
        {
            std::string payload;
            uint64 updatedAt;
            uint64 instanceKey;
        };
        
        struct PlayerSnapshot
        {
            uint64 instanceKey = 0;
            uint64 lastUpdated = 0;
            std::string idleReason;
        };
        
        std::unordered_map<uint64, CacheEntry> m_cache;
        std::unordered_map<uint32, PlayerSnapshot> m_playerSnapshots;  // playerGuid -> snapshot
        std::unordered_map<uint64, time_t> m_missingKeys;  // backoff tracking
        uint64 m_lastSeenUpdate = 0;
        bool m_tableEnsured = false;
        
        static constexpr char const* HUD_CACHE_TABLE = "dc_mplus_hud_cache";
        static constexpr uint32 POLL_INTERVAL_MS = 1000;
        static constexpr uint64 INSTANCE_KEY_FACTOR = 4294967296ULL;  // 2^32
        static constexpr uint32 BACKOFF_SECONDS = 2;
        
        HudCacheMgr() = default;
        
        void EnsureTable()
        {
            if (m_tableEnsured)
                return;
            
            CharacterDatabase.DirectExecute(
                "CREATE TABLE IF NOT EXISTS `{}` ("
                "  `instance_key` BIGINT UNSIGNED NOT NULL,"
                "  `map_id` INT UNSIGNED NOT NULL,"
                "  `instance_id` INT UNSIGNED NOT NULL,"
                "  `owner_guid` INT UNSIGNED NOT NULL,"
                "  `keystone_level` TINYINT UNSIGNED NOT NULL,"
                "  `season_id` INT UNSIGNED NOT NULL,"
                "  `payload` LONGTEXT NOT NULL,"
                "  `updated_at` BIGINT UNSIGNED NOT NULL,"
                "  PRIMARY KEY (`instance_key`)"
                ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
                HUD_CACHE_TABLE);
            
            m_tableEnsured = true;
            LOG_INFO("dc.addon.mplus", "HudCacheMgr: Table `{}` ensured", HUD_CACHE_TABLE);
        }
        
        uint64 MakeInstanceKey(Player* player) const
        {
            if (!player || !player->IsInWorld())
                return 0;
            
            uint32 mapId = player->GetMapId();
            uint32 instanceId = player->GetInstanceId();
            
            if (instanceId == 0)
                return 0;
            
            Map* map = player->GetMap();
            if (!map || (!map->IsDungeon() && !map->IsRaid()))
                return 0;
            
            return static_cast<uint64>(mapId) * INSTANCE_KEY_FACTOR + instanceId;
        }
        
        void SendIdle(Player* player, const std::string& reason)
        {
            if (!player)
                return;
            
            uint32 guid = player->GetGUID().GetCounter();
            PlayerSnapshot& prev = m_playerSnapshots[guid];
            
            if (prev.idleReason == reason)
                return;  // Already sent this idle reason
            
            // Build JSON payload
            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
                .Set("op", "idle")
                .Set("reason", reason)
                .Send(player);
            
            prev.idleReason = reason;
            prev.instanceKey = 0;
            prev.lastUpdated = 0;
        }
        
        void StoreSnapshot(uint32 playerGuid, uint64 instanceKey, uint64 updatedAt)
        {
            PlayerSnapshot& snap = m_playerSnapshots[playerGuid];
            snap.instanceKey = instanceKey;
            snap.lastUpdated = updatedAt;
            snap.idleReason.clear();
        }
        
        bool SendPayload(Player* player, const CacheEntry& record)
        {
            if (!player || record.payload.empty())
                return false;
            
            // Send raw JSON payload
            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
                .Add(record.payload)
                .Send(player);
            
            StoreSnapshot(player->GetGUID().GetCounter(), record.instanceKey, record.updatedAt);
            return true;
        }
        
        bool CacheMissBackoff(uint64 instanceKey)
        {
            time_t now = time(nullptr);
            auto it = m_missingKeys.find(instanceKey);
            
            if (it != m_missingKeys.end() && (now - it->second) < BACKOFF_SECONDS)
                return true;  // Still in backoff
            
            m_missingKeys[instanceKey] = now;
            return false;
        }
        
        CacheEntry* FetchSnapshot(uint64 instanceKey)
        {
            if (instanceKey == 0)
                return nullptr;
            
            // Check cache first
            auto it = m_cache.find(instanceKey);
            if (it != m_cache.end())
                return &it->second;
            
            // Check backoff
            if (CacheMissBackoff(instanceKey))
                return nullptr;
            
            EnsureTable();
            
            // Query database
            QueryResult result = CharacterDatabase.Query(
                "SELECT payload, updated_at FROM `{}` WHERE instance_key = {} LIMIT 1",
                HUD_CACHE_TABLE, instanceKey);
            
            if (!result)
                return nullptr;
            
            Field* fields = result->Fetch();
            std::string payload = fields[0].Get<std::string>();
            uint64 updated = fields[1].Get<uint64>();
            
            if (payload.empty())
                return nullptr;
            
            // Cache it
            CacheEntry& entry = m_cache[instanceKey];
            entry.payload = payload;
            entry.updatedAt = updated;
            entry.instanceKey = instanceKey;
            
            if (updated > m_lastSeenUpdate)
                m_lastSeenUpdate = updated;
            
            m_missingKeys.erase(instanceKey);
            return &entry;
        }
        
        void PullCacheUpdates()
        {
            EnsureTable();
            
            QueryResult result = CharacterDatabase.Query(
                "SELECT instance_key, payload, updated_at FROM `{}` WHERE updated_at > {} ORDER BY updated_at",
                HUD_CACHE_TABLE, m_lastSeenUpdate);
            
            if (!result)
                return;
            
            do
            {
                Field* fields = result->Fetch();
                uint64 key = fields[0].Get<uint64>();
                std::string payload = fields[1].Get<std::string>();
                uint64 updated = fields[2].Get<uint64>();
                
                if (key > 0 && !payload.empty())
                {
                    CacheEntry& entry = m_cache[key];
                    entry.payload = payload;
                    entry.updatedAt = updated;
                    entry.instanceKey = key;
                    
                    if (updated > m_lastSeenUpdate)
                        m_lastSeenUpdate = updated;
                    
                    m_missingKeys.erase(key);
                }
            } while (result->NextRow());
        }
        
        bool DeliverSnapshot(Player* player, bool force = false, const std::string& reason = "")
        {
            uint64 instanceKey = MakeInstanceKey(player);
            
            if (instanceKey == 0)
            {
                SendIdle(player, reason.empty() ? "not_in_mythic" : reason);
                return false;
            }
            
            CacheEntry* record = FetchSnapshot(instanceKey);
            if (!record)
            {
                SendIdle(player, "no_snapshot");
                return false;
            }
            
            uint32 guid = player->GetGUID().GetCounter();
            PlayerSnapshot& previous = m_playerSnapshots[guid];
            
            if (!force && previous.instanceKey == instanceKey && previous.lastUpdated == record->updatedAt)
                return true;  // Already sent, no changes
            
            return SendPayload(player, *record);
        }
        
    public:
        static HudCacheMgr& Instance()
        {
            static HudCacheMgr instance;
            return instance;
        }
        
        // Main update loop (called periodically)
        void Update()
        {
            PullCacheUpdates();
            
            // Iterate all online players
            auto const& sessions = sWorldSessionMgr->GetAllSessions();
            for (auto const& pair : sessions)
            {
                if (WorldSession* session = pair.second)
                {
                    if (Player* player = session->GetPlayer())
                    {
                        if (player->IsInWorld())
                            DeliverSnapshot(player);
                    }
                }
            }
        }
        
        // Client-requested snapshot (force refresh)
        void RequestHud(Player* player, const std::string& reason = "client")
        {
            DeliverSnapshot(player, true, reason);
        }
        
        // Clear cache (for instance resets)
        void ClearCache()
        {
            m_cache.clear();
            m_missingKeys.clear();
            LOG_INFO("dc.addon.mplus", "HudCacheMgr: Cache cleared");
        }
        
        // Clear player snapshot on logout
        void OnPlayerLogout(Player* player)
        {
            if (!player)
                return;
            
            uint32 guid = player->GetGUID().GetCounter();
            m_playerSnapshots.erase(guid);
        }
    };
    
    // Handler: Client requests HUD snapshot
    static void HandleRequestHud(Player* player, const ParsedMessage& msg)
    {
        std::string reason = msg.GetString(0);
        if (reason.empty())
            reason = "client_request";
        
        HudCacheMgr::Instance().RequestHud(player, reason);
    }
    
    // ========================================================================
    // JSON HANDLERS - For complex data that benefits from structured format
    // ========================================================================
    
    // Send key info as JSON (more readable, easier to extend)
    void SendJsonKeyInfo(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT map_id, level FROM dc_mplus_keystones WHERE character_guid = {}",
            guid);
        
        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = false;  // dc_mplus_keystones doesn't have depleted column
            
            // Get dungeon name
            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_dungeons WHERE map_id = {}",
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
            "SELECT affix_id, affix_name, affix_description FROM dc_mplus_weekly_affixes "
            "WHERE week_number = (SELECT MAX(week_number) FROM dc_mplus_weekly_affixes)");
        
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
            "FROM dc_mplus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
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
                    "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
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
    
    // Helper to get current week number (for future weekly reset logic)
    [[maybe_unused]] static uint32 GetCurrentWeekNumber()
    {
        time_t now = time(nullptr);
        // Simple week calculation from epoch
        return static_cast<uint32>((now / 604800) % 52);
    }

}  // namespace MythicPlus
}  // namespace DCAddon

// Player script to auto-push the keystone list on login and handle logout
class MythicPlusKeystoneLoginPlayerScript : public PlayerScript
{
public:
    MythicPlusKeystoneLoginPlayerScript() : PlayerScript("MythicPlusKeystoneLoginPlayerScript") {}

    void OnPlayerLogin(Player* player) override
    {
        if (!player || !player->GetSession())
            return;
        // Send the canonical keystone list to the player
        DCAddon::MythicPlus::SendJsonKeystoneList(player);
    }
    
    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;
        // Clean up player's HUD snapshot
        DCAddon::MythicPlus::HudCacheMgr::Instance().OnPlayerLogout(player);
    }
};

// World script for HUD cache polling
class MythicPlusHudCacheWorldScript : public WorldScript
{
public:
    MythicPlusHudCacheWorldScript() : WorldScript("MythicPlusHudCacheWorldScript") {}
    
    void OnUpdate(uint32 /*diff*/) override
    {
        // Poll every 1 second
        static uint32 lastUpdate = 0;
        uint32 now = getMSTime();
        
        if (now - lastUpdate >= 1000)
        {
            DCAddon::MythicPlus::HudCacheMgr::Instance().Update();
            lastUpdate = now;
        }
    }
};

void AddSC_dc_addon_mythicplus()
{
    DCAddon::MythicPlus::RegisterHandlers();
    // Auto-push keystone list on login for connected players
    new MythicPlusKeystoneLoginPlayerScript();
    // Start HUD cache polling
    new MythicPlusHudCacheWorldScript();
}
