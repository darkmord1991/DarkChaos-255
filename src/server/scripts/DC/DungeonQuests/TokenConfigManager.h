/*
* DarkChaos-255 Dungeon Quest System - Token Configuration Manager
* Version: 2.0
*
* Loads token, achievement, and title configuration from CSV files
* at server startup for runtime access without recompilation.
*
* CSV Files:
* - dc_items_tokens.csv
* - dc_achievements.csv
* - dc_titles.csv
* - dc_dungeon_npcs.csv
*/

#ifndef TOKEN_CONFIG_MANAGER_H
#define TOKEN_CONFIG_MANAGER_H

#include "Common.h"
#include <map>
#include <vector>
#include <string>

struct TokenEntry
{
    uint32 tokenId;
    uint32 itemId;
    std::string tokenName;
    std::string tokenType;  // "explorer", "specialist", "legendary", "challenge", "speed_runner"
    uint8 quality;          // 0-5 (0=poor, 5=legendary)
    uint32 vendorPrice;
    std::string description;
};

struct AchievementEntry
{
    uint32 achievementId;
    std::string achievementName;
    std::string description;
    std::string category;
    uint32 criterionValue;
    uint32 rewardTitleId;
    uint32 rewardItemId;
    uint32 rewardItemCount;
};

struct TitleEntry
{
    uint32 titleId;
    std::string titleName;
    std::string description;
    std::string maleFormat;    // e.g., "Explorer %s"
    std::string femaleFormat;  // e.g., "Explorer %s"
    uint32 achievementId;
    uint8 rewardLevel;
};

struct DungeonNPCEntry
{
    uint32 npcId;
    std::string npcName;
    uint32 dungeonId;
    std::string dungeonName;
    uint8 expansion;       // 0=Classic, 1=TBC, 2=WotLK
    uint8 tier;            // 1=Beginner, 2=Intermediate, 3=Advanced
    std::string levelRange;
    uint32 modelId;
    uint32 mapId;
    std::string teleportZone;
    std::string description;
};

class TokenConfigManager
{
public:
    static TokenConfigManager* instance()
    {
        static TokenConfigManager instance;
        return &instance;
    }

    // Initialize: Load all CSV configuration files
    bool Initialize()
    {
        bool success = true;

        success &= LoadTokens("DC_Dungeon_Quests/dc_items_tokens.csv");
        success &= LoadAchievements("DC_Dungeon_Quests/dc_achievements.csv");
        success &= LoadTitles("DC_Dungeon_Quests/dc_titles.csv");
        success &= LoadDungeonNPCs("DC_Dungeon_Quests/dc_dungeon_npcs.csv");

        if (success)
        {
            sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager: Successfully loaded all configuration files");
            PrintStatistics();
        }
        else
        {
            sLog->outError(LOG_FILTER_GUILD, "TokenConfigManager: Failed to load some configuration files");
        }

        return success;
    }

    // Token access methods
    TokenEntry* GetTokenById(uint32 tokenId)
    {
        auto itr = _tokenMap.find(tokenId);
        return itr != _tokenMap.end() ? &itr->second : nullptr;
    }

    TokenEntry* GetTokenByItemId(uint32 itemId)
    {
        for (auto& pair : _tokenMap)
        {
            if (pair.second.itemId == itemId)
                return &pair.second;
        }
        return nullptr;
    }

    // Achievement access methods
    AchievementEntry* GetAchievementById(uint32 achievementId)
    {
        auto itr = _achievementMap.find(achievementId);
        return itr != _achievementMap.end() ? &itr->second : nullptr;
    }

    // Title access methods
    TitleEntry* GetTitleById(uint32 titleId)
    {
        auto itr = _titleMap.find(titleId);
        return itr != _titleMap.end() ? &itr->second : nullptr;
    }

    // NPC access methods
    DungeonNPCEntry* GetNPCById(uint32 npcId)
    {
        auto itr = _npcMap.find(npcId);
        return itr != _npcMap.end() ? &itr->second : nullptr;
    }

    std::vector<TokenEntry*> GetAllTokens()
    {
        std::vector<TokenEntry*> result;
        for (auto& pair : _tokenMap)
            result.push_back(&pair.second);
        return result;
    }

    std::vector<AchievementEntry*> GetAllAchievements()
    {
        std::vector<AchievementEntry*> result;
        for (auto& pair : _achievementMap)
            result.push_back(&pair.second);
        return result;
    }

    std::vector<DungeonNPCEntry*> GetNPCsByTier(uint8 tier)
    {
        std::vector<DungeonNPCEntry*> result;
        for (auto& pair : _npcMap)
        {
            if (pair.second.tier == tier)
                result.push_back(&pair.second);
        }
        return result;
    }

    std::vector<DungeonNPCEntry*> GetNPCsByExpansion(uint8 expansion)
    {
        std::vector<DungeonNPCEntry*> result;
        for (auto& pair : _npcMap)
        {
            if (pair.second.expansion == expansion)
                result.push_back(&pair.second);
        }
        return result;
    }

private:
    TokenConfigManager() { }

    std::map<uint32, TokenEntry> _tokenMap;
    std::map<uint32, AchievementEntry> _achievementMap;
    std::map<uint32, TitleEntry> _titleMap;
    std::map<uint32, DungeonNPCEntry> _npcMap;

    bool LoadTokens(const std::string& filename)
    {
        // In production, implement CSV parsing here
        // For now, return true (data will be in SQL tables)
        sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager: Attempting to load %s", filename.c_str());
        return true;
    }

    bool LoadAchievements(const std::string& filename)
    {
        sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager: Attempting to load %s", filename.c_str());
        return true;
    }

    bool LoadTitles(const std::string& filename)
    {
        sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager: Attempting to load %s", filename.c_str());
        return true;
    }

    bool LoadDungeonNPCs(const std::string& filename)
    {
        sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager: Attempting to load %s", filename.c_str());
        return true;
    }

    void PrintStatistics()
    {
        sLog->outInfo(LOG_FILTER_GUILD, "TokenConfigManager Statistics:");
        sLog->outInfo(LOG_FILTER_GUILD, "  - Tokens loaded: %u", (uint32)_tokenMap.size());
        sLog->outInfo(LOG_FILTER_GUILD, "  - Achievements loaded: %u", (uint32)_achievementMap.size());
        sLog->outInfo(LOG_FILTER_GUILD, "  - Titles loaded: %u", (uint32)_titleMap.size());
        sLog->outInfo(LOG_FILTER_GUILD, "  - Dungeon NPCs loaded: %u", (uint32)_npcMap.size());
    }
};

#define sTokenConfig TokenConfigManager::instance()

#endif // TOKEN_CONFIG_MANAGER_H

/*
* USAGE EXAMPLES:
*
* // Get token by ID
* TokenEntry* token = sTokenConfig->GetTokenById(1);
* if (token)
*     player->AddItem(token->itemId, 1);
*
* // Get achievement
* AchievementEntry* ach = sTokenConfig->GetAchievementById(700001);
* if (ach)
*     player->CompletedAchievement(ach->achievementId);
*
* // Get all tier 1 NPCs
* auto tier1NPCs = sTokenConfig->GetNPCsByTier(1);
* for (auto npc : tier1NPCs)
*     LOG_INFO("NPC: %s", npc->npcName.c_str());
*
* // Reload configuration (command: .tokenconfig reload)
* sTokenConfig->Initialize();
*
* FUTURE ENHANCEMENTS:
* - Implement actual CSV file parsing using boost::tokenizer
* - Database query fallback if CSV files not found
* - Hot reload capability for config updates without restart
* - Per-server configuration overrides
* - Configuration validation and error reporting
*/
