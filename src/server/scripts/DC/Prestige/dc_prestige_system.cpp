/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige System
 * 
 * Features:
 * - Reset level 255 players to level 1 with permanent stat bonuses
 * - Up to 10 prestige levels
 * - Each prestige grants 1% bonus to all stats (stacking)
 * - Exclusive titles and cosmetic rewards
 * - Prestige levels displayed via achievements/worldstates
 * - Option to keep gear or reset to starter gear
 * - Integration with Heirloom scaling system
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "World.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"
#include "AchievementMgr.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "dc_prestige_api.h"
#include <sstream>

using namespace Acore::ChatCommands;

enum PrestigeConfig
{
    MAX_PRESTIGE_LEVEL = 10,
    REQUIRED_LEVEL = 255,
    STAT_BONUS_PER_PRESTIGE = 1,  // 1% per prestige level
    DEBUG_MODE = 0,  // Set to 1 to enable debug messages (GM only)
};

// Prestige spell lookup table (O(1) access)
constexpr uint32 PRESTIGE_SPELLS[MAX_PRESTIGE_LEVEL] = {
    800010, 800011, 800012, 800013, 800014,
    800015, 800016, 800017, 800018, 800019
};

// Prestige title lookup table (O(1) access)
constexpr uint32 PRESTIGE_TITLES[MAX_PRESTIGE_LEVEL] = {
    178, 179, 180, 181, 182,
    183, 184, 185, 186, 187
};

enum PrestigeSpells
{
    SPELL_PRESTIGE_BONUS_1  = 800010,  // Custom auras for prestige bonuses
    SPELL_PRESTIGE_BONUS_2  = 800011,
    SPELL_PRESTIGE_BONUS_3  = 800012,
    SPELL_PRESTIGE_BONUS_4  = 800013,
    SPELL_PRESTIGE_BONUS_5  = 800014,
    SPELL_PRESTIGE_BONUS_6  = 800015,
    SPELL_PRESTIGE_BONUS_7  = 800016,
    SPELL_PRESTIGE_BONUS_8  = 800017,
    SPELL_PRESTIGE_BONUS_9  = 800018,
    SPELL_PRESTIGE_BONUS_10 = 800019,
};

enum PrestigeTitles
{
    TITLE_PRESTIGE_1  = 178,  // Custom title IDs from CharTitles.dbc
    TITLE_PRESTIGE_2  = 179,
    TITLE_PRESTIGE_3  = 180,
    TITLE_PRESTIGE_4  = 181,
    TITLE_PRESTIGE_5  = 182,
    TITLE_PRESTIGE_6  = 183,
    TITLE_PRESTIGE_7  = 184,
    TITLE_PRESTIGE_8  = 185,
    TITLE_PRESTIGE_9  = 186,
    TITLE_PRESTIGE_10 = 187,
};

struct PrestigeReward
{
    uint32 itemEntry;
    uint32 count;
};

class PrestigeSystem
{
public:
    static PrestigeSystem* instance()
    {
        static PrestigeSystem instance;
        return &instance;
    }

    void LoadConfig()
    {
        enabled = sConfigMgr->GetOption<bool>("Prestige.Enable", true);
        requireLevel = sConfigMgr->GetOption<uint32>("Prestige.RequiredLevel", REQUIRED_LEVEL);
        maxPrestigeLevel = sConfigMgr->GetOption<uint32>("Prestige.MaxLevel", MAX_PRESTIGE_LEVEL);
        statBonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", STAT_BONUS_PER_PRESTIGE);
        resetLevel = sConfigMgr->GetOption<uint32>("Prestige.ResetLevel", 1);
        keepGear = sConfigMgr->GetOption<bool>("Prestige.KeepGear", true);
        keepProfessions = sConfigMgr->GetOption<bool>("Prestige.KeepProfessions", true);
        keepGold = sConfigMgr->GetOption<bool>("Prestige.KeepGold", true);
        grantStarterGear = sConfigMgr->GetOption<bool>("Prestige.GrantStarterGear", false);
        announcePrestige = sConfigMgr->GetOption<bool>("Prestige.AnnounceWorld", true);
        
        // Config validation with error logging
        bool configValid = true;
        
        if (maxPrestigeLevel == 0 || maxPrestigeLevel > MAX_PRESTIGE_LEVEL)
        {
            LOG_ERROR("scripts", "Prestige: Invalid MaxLevel ({}). Must be 1-{}. Using default {}.",
                maxPrestigeLevel, MAX_PRESTIGE_LEVEL, MAX_PRESTIGE_LEVEL);
            maxPrestigeLevel = MAX_PRESTIGE_LEVEL;
            configValid = false;
        }
        
        if (requireLevel == 0 || requireLevel > 255)
        {
            LOG_ERROR("scripts", "Prestige: Invalid RequiredLevel ({}). Must be 1-255. Using default {}.",
                requireLevel, REQUIRED_LEVEL);
            requireLevel = REQUIRED_LEVEL;
            configValid = false;
        }
        
        if (resetLevel == 0 || resetLevel >= requireLevel)
        {
            LOG_ERROR("scripts", "Prestige: Invalid ResetLevel ({}). Must be 1-{} (less than RequiredLevel). Using default 1.",
                resetLevel, requireLevel - 1);
            resetLevel = 1;
            configValid = false;
        }
        
        if (statBonusPercent == 0 || statBonusPercent > 100)
        {
            LOG_WARN("scripts", "Prestige: StatBonusPercent ({}) is outside recommended range 1-100. Proceeding anyway.",
                statBonusPercent);
        }
        
        if (configValid)
        {
            LOG_INFO("scripts", "Prestige: Configuration loaded successfully");
        }
        else
        {
            LOG_WARN("scripts", "Prestige: Configuration loaded with errors (see above). Some values were reset to defaults.");
        }
        
        // Load prestige rewards
        LoadPrestigeRewards();
    }

    bool IsEnabled() const { return enabled; }
    uint32 GetRequiredLevel() const { return requireLevel; }
    uint32 GetMaxPrestigeLevel() const { return maxPrestigeLevel; }
    uint32 GetStatBonusPercent() const { return statBonusPercent; }

    uint32 GetPrestigeLevel(Player* player)
    {
        if (!player)
            return 0;

        uint32 guid = player->GetGUID().GetCounter();
        auto it = prestigeCache.find(guid);
        if (it != prestigeCache.end())
            return it->second;

        // Query from database - guid is uint32 so SQL injection is not possible
        QueryResult result = CharacterDatabase.Query("SELECT prestige_level FROM dc_character_prestige WHERE guid = {}", guid);
        uint32 level = 0;
        if (result)
        {
            Field* fields = result->Fetch();
            level = fields[0].Get<uint32>();
        }
        prestigeCache[guid] = level;
        return level;
    }

    void SetPrestigeLevel(Player* player, uint32 level)
    {
        if (!player)
            return;

        uint32 guid = player->GetGUID().GetCounter();
        
        // All parameters are uint32 so SQL injection is not possible with StringFormat
        CharacterDatabase.Execute(
            "REPLACE INTO dc_character_prestige (guid, prestige_level, total_prestiges, last_prestige_time) VALUES ({}, {}, {}, UNIX_TIMESTAMP())", 
            guid, level, level);
        
        prestigeCache[guid] = level;
    }
    
    void ClearPrestigeCache(ObjectGuid guid)
    {
        auto it = prestigeCache.find(guid.GetCounter());
        if (it != prestigeCache.end())
        {
            prestigeCache.erase(it);
        }
    }

    bool CanPrestige(Player* player)
    {
        if (!enabled || !player)
            return false;

        if (player->GetLevel() < requireLevel)
            return false;

        uint32 currentPrestige = GetPrestigeLevel(player);
        if (currentPrestige >= maxPrestigeLevel)
            return false;

        return true;
    }

    void PerformPrestige(Player* player)
    {
        if (!CanPrestige(player))
            return;

        uint32 currentPrestige = GetPrestigeLevel(player);
        uint32 newPrestige = currentPrestige + 1;

        // Save current state for logging
        std::string playerName = player->GetName();
        uint32 oldLevel = player->GetLevel();

        LOG_INFO("scripts", "Prestige: Player {} (GUID: {}) starting prestige {} -> {}", 
            playerName, player->GetGUID().ToString(), currentPrestige, newPrestige);

        // Remove old prestige buffs
        RemovePrestigeBuffs(player);

        // Reset level
        player->SetLevel(resetLevel);
        
        // Clear player flags using helper function
        ClearPrestigePlayerFlags(player);
        
        // Initialize stats for new level
        player->InitStatsForLevel(true);
        player->UpdateSkillsForLevel();
        player->UpdateAllStats();

        // Handle gear
        if (!keepGear)
        {
            RemoveAllGear(player);
            if (grantStarterGear)
                GrantStarterGear(player);
        }

        // Handle gold
        if (!keepGold)
            player->SetMoney(0);

        // Handle professions
        if (!keepProfessions)
            ResetProfessions(player);

        // Update prestige level
        SetPrestigeLevel(player, newPrestige);

        // Grant title
        GrantPrestigeTitle(player, newPrestige);

        // Grant prestige rewards
        GrantPrestigeRewards(player, newPrestige);

        // Update achievements/statistics
        UpdatePrestigeAchievements(player, newPrestige);

        // Apply new prestige buffs
        ApplyPrestigeBuffs(player);
        
        // Force update player stats and restore health/mana
        player->UpdateAllStats();
        player->SetFullHealth();
        if (player->getPowerType() == POWER_MANA)
            player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
        
        // Reset experience to 0 for new level
        uint32 newXpForLevel = sObjectMgr->GetXPForLevel(resetLevel);
        player->SetUInt32Value(PLAYER_XP, 0);
        player->SetUInt32Value(PLAYER_NEXT_LEVEL_XP, newXpForLevel);
        
        // Save player (single save instead of two)
        player->SaveToDB(false, false);

        // Announce to world
        if (announcePrestige)
        {
            std::string announcement = Acore::StringFormat(
                "|cFFFFD700[Prestige]|r Player {} has achieved Prestige Level {}!", 
                playerName, newPrestige);
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, announcement);
        }

        // Notify player
        ChatHandler(player->GetSession()).PSendSysMessage("Congratulations! You have reached Prestige Level {}!", newPrestige);
        ChatHandler(player->GetSession()).PSendSysMessage("You now have {}% bonus to all stats!", newPrestige * statBonusPercent);

        // Log to database
        try
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_prestige_log (guid, prestige_level, prestige_time, from_level, kept_gear) VALUES ({}, {}, UNIX_TIMESTAMP(), {}, {})",
                player->GetGUID().GetCounter(), newPrestige, oldLevel, keepGear ? 1 : 0
            );
        }
        catch (...)
        {
            LOG_ERROR("scripts", "Prestige: Failed to log prestige for player {} (GUID: {})", 
                playerName, player->GetGUID().ToString());
        }
        
        LOG_INFO("scripts", "Prestige: Player {} completed prestige to level {}", playerName, newPrestige);
        
        // Teleport to starting location
        TeleportToStartingLocation(player);
    }

    void TeleportToStartingLocation(Player* player)
    {
        if (!player)
            return;

        uint32 mapId = 0;
        float x = 0, y = 0, z = 0, o = 0;
        
        // Get starting location from playercreateinfo table based on race AND class
        QueryResult result = WorldDatabase.Query(
            "SELECT map, position_x, position_y, position_z, orientation FROM playercreateinfo WHERE race = {} AND class = {} LIMIT 1", 
            player->getRace(), player->getClass()
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            mapId = fields[0].Get<uint32>();
            x = fields[1].Get<float>();
            y = fields[2].Get<float>();
            z = fields[3].Get<float>();
            o = fields[4].Get<float>();
        }
        else
        {
            // Try to find any entry for this race as fallback
            result = WorldDatabase.Query(
                "SELECT map, position_x, position_y, position_z, orientation FROM playercreateinfo WHERE race = {} LIMIT 1", 
                player->getRace()
            );
            
            if (result)
            {
                Field* fields = result->Fetch();
                mapId = fields[0].Get<uint32>();
                x = fields[1].Get<float>();
                y = fields[2].Get<float>();
                z = fields[3].Get<float>();
                o = fields[4].Get<float>();
            }
            else
            {
                LOG_WARN("scripts", "Prestige: No playercreateinfo entry found for race {}, using hardcoded fallback", 
                    player->getRace());
                    
                // Fallback to hardcoded defaults
                switch (player->getRace())
                {
                    case RACE_HUMAN:
                        mapId = 0; x = -8949.95f; y = -132.493f; z = 83.6112f;
                        break;
                    case RACE_ORC:
                        mapId = 1; x = 1676.64f; y = -4308.64f; z = -10.4536f;
                        break;
                    case RACE_DWARF:
                        mapId = 0; x = -6240.32f; y = 336.457f; z = 383.376f;
                        break;
                    case RACE_GNOME:
                        mapId = 0; x = -5023.58f; y = -1528.51f; z = 1327.59f;
                        break;
                    case RACE_NIGHTELF:
                        mapId = 1; x = 10311.2f; y = 832.463f; z = 1326.41f;
                        break;
                    case RACE_TAUREN:
                        mapId = 1; x = -2917.58f; y = -257.346f; z = 52.9957f;
                        break;
                    case RACE_UNDEAD_PLAYER:
                        mapId = 0; x = 1919.33f; y = 238.470f; z = 60.7029f;
                        break;
                    case RACE_BLOODELF:
                        mapId = 530; x = 10349.6f; y = -6357.29f; z = 33.4026f;
                        break;
                    case RACE_DRAENEI:
                        mapId = 530; x = -4149.21f; y = -12345.6f; z = 36.05f;
                        break;
                    default:
                        LOG_ERROR("scripts", "Prestige: Unknown race {} for teleport fallback", player->getRace());
                        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Unable to determine starting location.|r");
                        return;
                }
            }
        }

        // Teleport player
        player->TeleportTo(mapId, x, y, z, o);
        LOG_INFO("scripts", "Prestige: Teleported player {} to starting location (Map: {}, {:.2f}, {:.2f}, {:.2f})", 
            player->GetName(), mapId, x, y, z);
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        uint32 prestigeLevel = GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;
        
        uint32 spellId = GetPrestigeSpell(prestigeLevel);
        if (!spellId)
            return;
            
        // Validate spell exists in DBC
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            LOG_ERROR("scripts", "Prestige: Spell {} not found in DBC for prestige level {}", spellId, prestigeLevel);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Prestige spell not found!|r");
            return;
        }
        
        // Remove any existing prestige buffs first
        RemovePrestigeBuffs(player);
        
        // Cast prestige aura with triggered flags to ensure it sticks
        player->CastSpell(player, spellId, TriggerCastFlags(TRIGGERED_CAST_DIRECTLY | TRIGGERED_IGNORE_GCD));
        
        // Verify aura application
        if (!player->HasAura(spellId))
        {
            LOG_WARN("scripts", "Prestige: Aura {} may not have applied to player {}", spellId, player->GetName());
        }
        
        LOG_INFO("scripts", "Prestige: Applied prestige buff (spell {}) to player {}", spellId, player->GetName());
    }

    void RemovePrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        // Remove all prestige auras
        for (uint32 i = SPELL_PRESTIGE_BONUS_1; i <= SPELL_PRESTIGE_BONUS_10; ++i)
        {
            player->RemoveAura(i);
        }
    }

    uint32 GetPrestigeSpell(uint32 prestigeLevel)
    {
        if (prestigeLevel == 0 || prestigeLevel > MAX_PRESTIGE_LEVEL)
            return 0;
        return PRESTIGE_SPELLS[prestigeLevel - 1]; // Array index is 0-based
    }

    uint32 GetPrestigeTitle(uint32 prestigeLevel)
    {
        if (prestigeLevel == 0 || prestigeLevel > MAX_PRESTIGE_LEVEL)
            return 0;
        return PRESTIGE_TITLES[prestigeLevel - 1]; // Array index is 0-based
    }
    
    // Helper: Clear player flags that prevent XP gain or cause display issues
    void ClearPrestigePlayerFlags(Player* player)
    {
        if (!player)
            return;
            
        // Resurrect if dead
        if (player->isDead())
        {
            player->ResurrectPlayer(1.0f);
            if (DEBUG_MODE)
                LOG_DEBUG("scripts", "Prestige: Player {} was dead, resurrecting", player->GetName());
        }
        
        // Clear flags that prevent XP bar from showing or XP gain
        if (player->HasPlayerFlag(PLAYER_FLAGS_GHOST))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_GHOST);
            if (DEBUG_MODE)
                LOG_DEBUG("scripts", "Prestige: Removed GHOST flag from {}", player->GetName());
        }
        
        if (player->HasPlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS);
            if (DEBUG_MODE)
                LOG_DEBUG("scripts", "Prestige: Removed OUT_OF_BOUNDS flag from {}", player->GetName());
        }
        
        // CRITICAL: Clear NO_XP_GAIN flag - allows player to gain experience
        if (player->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_NO_XP_GAIN);
            if (DEBUG_MODE)
                LOG_DEBUG("scripts", "Prestige: Removed NO_XP_GAIN flag from {}", player->GetName());
        }
    }

    void UpdatePrestigeAchievements(Player* player, uint32 prestigeLevel)
    {
        if (!player)
            return;

        // Grant prestige achievement (IDs 10300-10309 from dc_achievements.sql)
        uint32 achievementId = 10300 + (prestigeLevel - 1); // 10300 = Prestige Level 1, etc.
        
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant achievement ID: {}", achievementId);
        AchievementEntry const* achievementEntry = sAchievementStore.LookupEntry(achievementId);
        if (achievementEntry)
        {
            player->CompletedAchievement(achievementEntry);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Prestige achievement granted!|r");
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000WARNING: Prestige achievement ID {} not found!|r", achievementId);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00Run the SQL: Custom/Custom feature SQLs/Achievements/dc_achievements.sql|r");
        }
    }

private:
    bool enabled;
    uint32 requireLevel;
    uint32 maxPrestigeLevel;
    uint32 statBonusPercent;
    uint32 resetLevel;
    bool keepGear;
    bool keepProfessions;
    bool keepGold;
    bool grantStarterGear;
    bool announcePrestige;
    std::unordered_map<uint32, std::vector<PrestigeReward>> prestigeRewards;
    std::unordered_map<uint32, uint32> prestigeCache;

    void LoadPrestigeRewards()
    {
        prestigeRewards.clear();

        // Load from config - format: "prestigeLevel:itemEntry:count;prestigeLevel:itemEntry:count"
        std::string rewardsStr = sConfigMgr->GetOption<std::string>("Prestige.Rewards", "");
        if (rewardsStr.empty())
            return;

        std::stringstream ss(rewardsStr);
        std::string token;
        while (std::getline(ss, token, ';'))
        {
            std::stringstream tokenSS(token);
            std::string part;
            std::vector<std::string> parts;
            while (std::getline(tokenSS, part, ':'))
                parts.push_back(part);
                
            if (parts.size() == 3)
            {
                if (Optional<uint32> prestigeLevel = Acore::StringTo<uint32>(parts[0]))
                if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(parts[1]))
                if (Optional<uint32> count = Acore::StringTo<uint32>(parts[2]))
                {
                    prestigeRewards[*prestigeLevel].push_back({*itemEntry, *count});
                }
            }
        }
    }

    void GrantPrestigeRewards(Player* player, uint32 prestigeLevel)
    {
        auto it = prestigeRewards.find(prestigeLevel);
        if (it == prestigeRewards.end())
            return;

        for (const PrestigeReward& reward : it->second)
        {
            player->AddItem(reward.itemEntry, reward.count);
        }
    }

    void GrantPrestigeTitle(Player* player, uint32 prestigeLevel)
    {
        uint32 titleId = GetPrestigeTitle(prestigeLevel);
        if (titleId)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant title ID: {}", titleId);
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
            if (titleEntry)
            {
                player->SetTitle(titleEntry);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Title granted!|r");
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Title ID {} not found in CharTitles.dbc!|r", titleId);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00Titles need to be added to CharTitles.dbc for 3.3.5a|r");
            }
        }
    }

    void RemoveAllGear(Player* player)
    {
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
        {
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // Remove bags and bag contents
        for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
        {
            if (Bag* bag = player->GetBagByPos(i))
            {
                for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                {
                    if (Item* item = bag->GetItemByPos(j))
                    {
                        player->DestroyItem(i, j, true);
                    }
                }
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // Remove bank items if configured
        if (sConfigMgr->GetOption<bool>("Prestige.ClearBank", false))
        {
            for (uint8 i = BANK_SLOT_ITEM_START; i < BANK_SLOT_ITEM_END; ++i)
            {
                if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
                {
                    player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
                }
            }
        }
    }

    void GrantStarterGear(Player* player)
    {
        // Grant basic starter gear based on class
        // This would need to be configured via database or config
        std::string starterGearList = sConfigMgr->GetOption<std::string>("Prestige.StarterGear." + std::to_string(player->getClass()), "");
        if (starterGearList.empty())
            return;

        std::stringstream ss(starterGearList);
        std::string itemStr;
        while (std::getline(ss, itemStr, ','))
        {
            if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(itemStr))
            {
                player->AddItem(*itemEntry, 1);
            }
        }
    }

    void ResetProfessions(Player* player)
    {
        player->SetSkill(SKILL_ALCHEMY, 0, 0, 0);
        player->SetSkill(SKILL_BLACKSMITHING, 0, 0, 0);
        player->SetSkill(SKILL_ENCHANTING, 0, 0, 0);
        player->SetSkill(SKILL_ENGINEERING, 0, 0, 0);
        player->SetSkill(SKILL_HERBALISM, 0, 0, 0);
        player->SetSkill(SKILL_INSCRIPTION, 0, 0, 0);
        player->SetSkill(SKILL_JEWELCRAFTING, 0, 0, 0);
        player->SetSkill(SKILL_LEATHERWORKING, 0, 0, 0);
        player->SetSkill(SKILL_MINING, 0, 0, 0);
        player->SetSkill(SKILL_SKINNING, 0, 0, 0);
        player->SetSkill(SKILL_TAILORING, 0, 0, 0);
    }
};

// PlayerScript for applying prestige bonuses on login
class PrestigePlayerScript : public PlayerScript
{
private:
    // Throttle aura checking to once per 30 seconds instead of every frame
    std::unordered_map<uint32, uint32> lastAuraCheckTime;
    
public:
    PrestigePlayerScript() : PlayerScript("PrestigePlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Clear player flags that might prevent XP gain or cause display issues
        PrestigeSystem::instance()->ClearPrestigePlayerFlags(player);

        // Apply prestige buffs on login
        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        
        if (prestigeLevel > 0)
        {
            PrestigeSystem::instance()->ApplyPrestigeBuffs(player);

            // Notify player of their prestige level
            ChatHandler(player->GetSession()).PSendSysMessage("Welcome back! You are Prestige Level {} with {}% bonus stats.",
                prestigeLevel, prestigeLevel * PrestigeSystem::instance()->GetStatBonusPercent());
        }

        // Check if player can prestige
        if (PrestigeSystem::instance()->CanPrestige(player))
        {
            uint32 currentPrestige = PrestigeSystem::instance()->GetPrestigeLevel(player);
            if (currentPrestige < PrestigeSystem::instance()->GetMaxPrestigeLevel())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700You have reached the required level! Type .prestige confirm to ascend!|r");
            }
        }
    }
    
    void OnPlayerLogout(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Clear cached prestige level to prevent memory leak
        PrestigeSystem::instance()->ClearPrestigeCache(player->GetGUID());
        
        // Clean up throttle map
        uint32 guid = player->GetGUID().GetCounter();
        auto it = lastAuraCheckTime.find(guid);
        if (it != lastAuraCheckTime.end())
        {
            lastAuraCheckTime.erase(it);
        }
    }

    void OnPlayerUpdate(Player* player, uint32 /*p_time*/) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;

        // Throttle aura check to once per 30 seconds (30000ms)
        uint32 guid = player->GetGUID().GetCounter();
        uint32 currentTime = GameTime::GetGameTimeMS().count();
        
        auto it = lastAuraCheckTime.find(guid);
        if (it != lastAuraCheckTime.end())
        {
            if (currentTime - it->second < 30000)
                return; // Too soon, skip this check
        }
        
        lastAuraCheckTime[guid] = currentTime;

        // Check if prestige aura is missing and reapply it
        uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(prestigeLevel);
        if (spellId && !player->HasAura(spellId))
        {
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (spellInfo)
            {
                player->AddAura(spellId, player);
                LOG_INFO("scripts", "Prestige: Reapplied missing prestige aura {} to player {}", 
                    spellId, player->GetName());
            }
        }
    }
};

// Command script for .prestige command
class PrestigeCommandScript : public CommandScript
{
public:
    PrestigeCommandScript() : CommandScript("PrestigeCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable prestigeCommandTable =
        {
            ChatCommandBuilder("info",    HandlePrestigeInfoCommand,    SEC_PLAYER,      Console::No),
            ChatCommandBuilder("reset",   HandlePrestigeResetCommand,   SEC_PLAYER,      Console::No),
            ChatCommandBuilder("confirm", HandlePrestigeConfirmCommand, SEC_PLAYER,      Console::No),
            ChatCommandBuilder("disable", HandlePrestigeDisableCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("admin",   HandlePrestigeAdminCommand,   SEC_ADMINISTRATOR, Console::No),
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("prestige", prestigeCommandTable),
        };

        return commandTable;
    }

    static bool HandlePrestigeInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeSystem::instance()->IsEnabled())
        {
            handler->SendSysMessage("Prestige system is currently disabled.");
            return true;
        }

        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        uint32 maxPrestige = PrestigeSystem::instance()->GetMaxPrestigeLevel();
        uint32 requiredLevel = PrestigeSystem::instance()->GetRequiredLevel();
        uint32 statBonus = prestigeLevel * PrestigeSystem::instance()->GetStatBonusPercent();

        handler->PSendSysMessage("=== Prestige System ===");
        handler->PSendSysMessage("Your Prestige Level: {}/{}", prestigeLevel, maxPrestige);
        handler->PSendSysMessage("Current Stat Bonus: {}%", statBonus);
        handler->PSendSysMessage("Required Level to Prestige: {}", requiredLevel);

        if (PrestigeSystem::instance()->CanPrestige(player))
        {
            handler->PSendSysMessage("|cFF00FF00You can prestige! Type .prestige reset to begin.|r");
        }
        else if (player->GetLevel() < requiredLevel)
        {
            handler->PSendSysMessage("You need to be level {} to prestige. Current level: {}", requiredLevel, player->GetLevel());
        }
        else if (prestigeLevel >= maxPrestige)
        {
            handler->PSendSysMessage("|cFFFFD700You have reached maximum prestige level!|r");
        }

        return true;
    }

    static bool HandlePrestigeResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeSystem::instance()->IsEnabled())
        {
            handler->SendSysMessage("Prestige system is currently disabled.");
            return true;
        }

        if (!PrestigeSystem::instance()->CanPrestige(player))
        {
            handler->SendSysMessage("You cannot prestige at this time.");
            return true;
        }

        uint32 nextPrestige = PrestigeSystem::instance()->GetPrestigeLevel(player) + 1;
        uint32 newBonus = nextPrestige * PrestigeSystem::instance()->GetStatBonusPercent();

        handler->PSendSysMessage("|cFFFF0000WARNING: Prestiging will:|r");
        handler->PSendSysMessage("- Reset you to level 1");
        handler->PSendSysMessage("- Grant you Prestige Level {} with {}% permanent stat bonus", nextPrestige, newBonus);
        handler->PSendSysMessage("- Grant you an exclusive title");
        handler->PSendSysMessage("|cFFFFD700Type .prestige confirm to proceed.|r");

        return true;
    }

    static bool HandlePrestigeConfirmCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->PSendSysMessage("DEBUG: HandlePrestigeConfirmCommand called");
        
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->PSendSysMessage("DEBUG: Player is NULL!");
            return false;
        }

        handler->PSendSysMessage("DEBUG: Player found: {}", player->GetName());

        if (!PrestigeSystem::instance()->CanPrestige(player))
        {
            handler->SendSysMessage("You cannot prestige at this time.");
            return true;
        }

        handler->PSendSysMessage("DEBUG: CanPrestige passed, calling PerformPrestige...");
        
    // No need to store player GUID here; session's player pointer will be re-queried after PerformPrestige
        
        try
        {
            PrestigeSystem::instance()->PerformPrestige(player);
            
            // Re-get player after prestige in case of any issues
            player = handler->GetSession()->GetPlayer();
            if (player)
            {
                handler->PSendSysMessage("DEBUG: PerformPrestige completed successfully");
            }
        }
        catch (std::exception const& e)
        {
            handler->PSendSysMessage("DEBUG: EXCEPTION in PerformPrestige: {}", e.what());
            return false;
        }
        catch (...)
        {
            handler->PSendSysMessage("DEBUG: UNKNOWN EXCEPTION in PerformPrestige!");
            return false;
        }
        
        return true;
    }

    static bool HandlePrestigeDisableCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage("Usage: .prestige disable <playername>");
            return true;
        }

        std::string playerName = args;
        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        
        if (!target)
        {
            handler->PSendSysMessage("Player {} not found.", playerName);
            return true;
        }

        // Remove all prestige buffs
        PrestigeSystem::instance()->RemovePrestigeBuffs(target);
        
        handler->PSendSysMessage("Removed prestige buffs from {}.", playerName);
        ChatHandler(target->GetSession()).PSendSysMessage("Your prestige buffs have been removed by a GM.");
        
        return true;
    }

    static bool HandlePrestigeAdminCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
            return false;

        std::stringstream ss(args);
        std::string token;
        std::vector<std::string> tokens;
        while (ss >> token)
            tokens.push_back(token);
            
        if (tokens.empty())
            return false;

        std::string subCommand = tokens[0];

        if (subCommand == "set" && tokens.size() == 3)
        {
            std::string playerName = tokens[1];
            if (Optional<uint32> level = Acore::StringTo<uint32>(tokens[2]))
            {
                Player* target = ObjectAccessor::FindPlayerByName(playerName);
                if (!target)
                {
                    handler->PSendSysMessage("Player {} not found.", playerName);
                    return true;
                }

                PrestigeSystem::instance()->SetPrestigeLevel(target, *level);
                PrestigeSystem::instance()->RemovePrestigeBuffs(target);
                PrestigeSystem::instance()->ApplyPrestigeBuffs(target);

                handler->PSendSysMessage("Set {}'s prestige level to {}.", playerName, *level);
                ChatHandler(target->GetSession()).PSendSysMessage("Your prestige level has been set to {} by a GM.", *level);
                return true;
            }
        }

        handler->SendSysMessage("Usage: .prestige admin set <player> <level>");
        return true;
    }
};

// World script for loading config
class PrestigeWorldScript : public WorldScript
{
public:
    PrestigeWorldScript() : WorldScript("PrestigeWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        PrestigeSystem::instance()->LoadConfig();
    }
    
    void OnStartup() override
    {
        // Validate that all prestige spells exist in DBC
        LOG_INFO("scripts", "Prestige: Validating prestige spells in DBC...");
        bool allSpellsValid = true;
        
        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(i);
            if (!sSpellMgr->GetSpellInfo(spellId))
            {
                LOG_ERROR("scripts", "Prestige: CRITICAL - Spell {} for prestige level {} not found in DBC!", spellId, i);
                allSpellsValid = false;
            }
        }
        
        if (allSpellsValid)
        {
            LOG_INFO("scripts", "Prestige: All {} prestige spells validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts", "Prestige: CRITICAL - Some prestige spells are missing! System may not work correctly.");
        }
        
        // Validate that all prestige titles exist in DBC
        LOG_INFO("scripts", "Prestige: Validating prestige titles in DBC...");
        bool allTitlesValid = true;
        
        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 titleId = PrestigeSystem::instance()->GetPrestigeTitle(i);
            if (!sCharTitlesStore.LookupEntry(titleId))
            {
                LOG_ERROR("scripts", "Prestige: CRITICAL - Title {} for prestige level {} not found in DBC!", titleId, i);
                allTitlesValid = false;
            }
        }
        
        if (allTitlesValid)
        {
            LOG_INFO("scripts", "Prestige: All {} prestige titles validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts", "Prestige: CRITICAL - Some prestige titles are missing! Players may not receive titles.");
        }
    }
};

void AddSC_dc_prestige_system()
{
    new PrestigePlayerScript();
    new PrestigeCommandScript();
    new PrestigeWorldScript();
}

namespace PrestigeAPI
{
    bool IsEnabled()
    {
        return PrestigeSystem::instance()->IsEnabled();
    }

    uint32 GetPrestigeLevel(Player* player)
    {
        return PrestigeSystem::instance()->GetPrestigeLevel(player);
    }

    uint32 GetMaxPrestigeLevel()
    {
        return PrestigeSystem::instance()->GetMaxPrestigeLevel();
    }

    uint32 GetRequiredLevel()
    {
        return PrestigeSystem::instance()->GetRequiredLevel();
    }

    uint32 GetStatBonusPercent()
    {
        return PrestigeSystem::instance()->GetStatBonusPercent();
    }

    bool CanPrestige(Player* player)
    {
        return PrestigeSystem::instance()->CanPrestige(player);
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        PrestigeSystem::instance()->ApplyPrestigeBuffs(player);
    }

    void PerformPrestige(Player* player)
    {
        PrestigeSystem::instance()->PerformPrestige(player);
    }
}
