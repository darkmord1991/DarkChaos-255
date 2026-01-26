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
#include "../../AddonExtension/dc_addon_prestige_notify.h"
#include <sstream>

using namespace Acore::ChatCommands;

enum PrestigeConfig
{
    MAX_PRESTIGE_LEVEL = 10,
    REQUIRED_LEVEL = 255,
    STAT_BONUS_PER_PRESTIGE = 1,  // 1% per prestige level
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

// Enums removed - using arrays as single source of truth
// See PRESTIGE_SPELLS and PRESTIGE_TITLES above

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
        debug = sConfigMgr->GetOption<bool>("Prestige.Debug", false);
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
            LOG_ERROR("scripts.dc", "Prestige: Invalid MaxLevel ({}). Must be 1-{}. Using default {}.",
                maxPrestigeLevel, MAX_PRESTIGE_LEVEL, MAX_PRESTIGE_LEVEL);
            maxPrestigeLevel = MAX_PRESTIGE_LEVEL;
            configValid = false;
        }

        if (requireLevel == 0 || requireLevel > 255)
        {
            LOG_ERROR("scripts.dc", "Prestige: Invalid RequiredLevel ({}). Must be 1-255. Using default {}.",
                requireLevel, REQUIRED_LEVEL);
            requireLevel = REQUIRED_LEVEL;
            configValid = false;
        }

        if (resetLevel == 0 || resetLevel >= requireLevel)
        {
            LOG_ERROR("scripts.dc", "Prestige: Invalid ResetLevel ({}). Must be 1-{} (less than RequiredLevel). Using default 1.",
                resetLevel, requireLevel - 1);
            resetLevel = 1;
            configValid = false;
        }

        if (statBonusPercent == 0 || statBonusPercent > 100)
        {
            LOG_WARN("scripts.dc", "Prestige: StatBonusPercent ({}) is outside recommended range 1-100. Proceeding anyway.",
                statBonusPercent);
        }

        if (configValid)
        {
            LOG_INFO("scripts.dc", "Prestige: Configuration loaded successfully");
        }
        else
        {
            LOG_WARN("scripts.dc", "Prestige: Configuration loaded with errors (see above). Some values were reset to defaults.");
        }

        // Load prestige rewards
        LoadPrestigeRewards();
    }

    bool IsEnabled() const { return enabled; }
    uint32 GetRequiredLevel() const { return requireLevel; }
    uint32 GetMaxPrestigeLevel() const { return maxPrestigeLevel; }
    uint32 GetStatBonusPercent() const { return statBonusPercent; }
    uint32 GetResetLevel() const { return resetLevel; }

    uint32 GetPrestigeLevel(Player* player)
    {
        if (!player)
            return 0;

        uint32 guid = player->GetGUID().GetCounter();
        auto it = prestigeCache.find(guid);
        if (it != prestigeCache.end())
            return it->second;

        // Query from database - guid is uint32 so SQL injection is not possible
        std::string sql = Acore::StringFormat("SELECT prestige_level FROM dc_character_prestige WHERE guid = {}", guid);
        QueryResult result = CharacterDatabase.Query(sql.c_str());
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
        std::string sql = Acore::StringFormat(
            "REPLACE INTO dc_character_prestige (guid, prestige_level, total_prestiges, last_prestige_time) VALUES ({}, {}, {}, UNIX_TIMESTAMP())",
            guid, level, level);
        CharacterDatabase.Execute(sql.c_str());

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

    bool PerformPrestige(Player* player)
    {
        if (!CanPrestige(player))
            return false;

        uint32 currentPrestige = GetPrestigeLevel(player);
        uint32 newPrestige = currentPrestige + 1;

        uint32 requiredStacks = CountRequiredRewardStacks(newPrestige);
        if (!keepGear && grantStarterGear)
            requiredStacks += CountRequiredStarterGearStacks(player);

        if (requiredStacks)
        {
            uint32 freeSlots = keepGear ? player->GetFreeInventorySpace() : GetBackpackFreeSlots(player);

            if (freeSlots < requiredStacks)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000Not enough bag space to prestige.|r");

                if (keepGear)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("Free slots: {}. Needed: {}.", freeSlots, requiredStacks);
                    return false;
                }
                else
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("Backpack free slots: {}. Needed: {}.", freeSlots, requiredStacks);
                    return false;
                }

                if (debug)
                    LOG_DEBUG("scripts.dc", "Prestige: Blocked prestige for {} due to bag space (free={}, required={})", player->GetName(), freeSlots, requiredStacks);
                return false;
            }
        }

        // Save current state for logging
        std::string playerName = player->GetName();
        uint32 oldLevel = player->GetLevel();

        LOG_INFO("scripts.dc", "Prestige: Player {} (GUID: {}) starting prestige {} -> {}",
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

        // Notify client addon (if installed/enabled) so UI can refresh immediately
        DCPrestigeAddon::NotifyPrestigeLevelUp(player, newPrestige, newPrestige * statBonusPercent);

        // Log to database
        try
        {
            std::string sql = Acore::StringFormat(
                "INSERT INTO dc_character_prestige_log (guid, prestige_level, prestige_time, from_level, kept_gear) VALUES ({}, {}, UNIX_TIMESTAMP(), {}, {})",
                player->GetGUID().GetCounter(), newPrestige, oldLevel, keepGear ? 1 : 0
            );
            CharacterDatabase.Execute(sql.c_str());
        }
        catch (...)
        {
            LOG_ERROR("scripts.dc", "Prestige: Failed to log prestige for player {} (GUID: {})",
                playerName, player->GetGUID().ToString());
        }

        LOG_INFO("scripts.dc", "Prestige: Player {} completed prestige to level {}", playerName, newPrestige);

        // Teleport to starting location
        TeleportToStartingLocation(player);

        return true;
    }

// TeleportToStartingLocation refactored to rely on DB
    void TeleportToStartingLocation(Player* player)
    {
        if (!player)
            return;

        uint32 mapId = 0;
        float x = 0, y = 0, z = 0, o = 0;
        bool found = false;

        // 1. Try exact match (Race + Class)
        std::string sql = Acore::StringFormat(
            "SELECT map, position_x, position_y, position_z, orientation FROM playercreateinfo WHERE race = {} AND class = {} LIMIT 1",
            player->getRace(), player->getClass()
        );
        QueryResult result = WorldDatabase.Query(sql.c_str());

        if (result)
        {
            Field* fields = result->Fetch();
            mapId = fields[0].Get<uint32>();
            x = fields[1].Get<float>();
            y = fields[2].Get<float>();
            z = fields[3].Get<float>();
            o = fields[4].Get<float>();
            found = true;
        }

        // 2. Try race fallback
        if (!found)
        {
            sql = Acore::StringFormat(
                "SELECT map, position_x, position_y, position_z, orientation FROM playercreateinfo WHERE race = {} LIMIT 1",
                player->getRace()
            );
            result = WorldDatabase.Query(sql.c_str());

            if (result)
            {
                Field* fields = result->Fetch();
                mapId = fields[0].Get<uint32>();
                x = fields[1].Get<float>();
                y = fields[2].Get<float>();
                z = fields[3].Get<float>();
                o = fields[4].Get<float>();
                found = true;
            }
        }

        if (found)
        {
            player->TeleportTo(mapId, x, y, z, o);
            LOG_INFO("scripts.dc", "Prestige: Teleported player {} to starting location (Map: {}, {:.2f}, {:.2f}, {:.2f})",
                player->GetName(), mapId, x, y, z);
        }
        else
        {
            LOG_ERROR("scripts.dc", "Prestige: No starting location found for Race {} Class {} in playercreateinfo!",
                player->getRace(), player->getClass());
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Could not determine starting location. Please contact a GM.|r");
        }
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
            LOG_ERROR("scripts.dc", "Prestige: Spell {} not found in DBC for prestige level {}", spellId, prestigeLevel);
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
            LOG_WARN("scripts.dc", "Prestige: Aura {} may not have applied to player {}", spellId, player->GetName());
        }

        LOG_INFO("scripts.dc", "Prestige: Applied prestige buff (spell {}) to player {}", spellId, player->GetName());
    }

    void RemovePrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        // Remove all prestige auras (do not assume contiguous spell IDs)
        for (uint32 spellId : PRESTIGE_SPELLS)
            player->RemoveAura(spellId);
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
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Player {} was dead, resurrecting", player->GetName());
        }

        // Clear flags that prevent XP bar from showing or XP gain
        if (player->HasPlayerFlag(PLAYER_FLAGS_GHOST))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_GHOST);
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Removed GHOST flag from {}", player->GetName());
        }

        if (player->HasPlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS);
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Removed OUT_OF_BOUNDS flag from {}", player->GetName());
        }

        // CRITICAL: Clear NO_XP_GAIN flag - allows player to gain experience
        if (player->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_NO_XP_GAIN);
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Removed NO_XP_GAIN flag from {}", player->GetName());
        }
    }

    void UpdatePrestigeAchievements(Player* player, uint32 prestigeLevel)
    {
        if (!player)
            return;

        // Grant prestige achievement (IDs 10300-10309 from dc_achievements.sql)
        uint32 achievementId = 10300 + (prestigeLevel - 1); // 10300 = Prestige Level 1, etc.

        if (debug && player->IsGameMaster())
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant achievement ID: {}", achievementId);
        AchievementEntry const* achievementEntry = sAchievementStore.LookupEntry(achievementId);
        if (achievementEntry)
        {
            player->CompletedAchievement(achievementEntry);
            if (debug && player->IsGameMaster())
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
    bool debug;
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

    static uint32 CountStacksForItem(uint32 itemEntry, uint32 count)
    {
        if (!count)
            return 0;

        uint32 maxStack = 1;
        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemEntry))
        {
            maxStack = proto->GetMaxStackSize();
            if (!maxStack)
                maxStack = 1;
        }

        return (count + maxStack - 1) / maxStack;
    }

    static uint32 GetBackpackFreeSlots(Player* player)
    {
        if (!player)
            return 0;

        uint32 freeSlots = 0;
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        {
            if (!player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
                ++freeSlots;
        }
        return freeSlots;
    }

    uint32 CountRequiredRewardStacks(uint32 prestigeLevel) const
    {
        auto it = prestigeRewards.find(prestigeLevel);
        if (it == prestigeRewards.end())
            return 0;

        uint32 requiredStacks = 0;
        for (PrestigeReward const& reward : it->second)
            requiredStacks += CountStacksForItem(reward.itemEntry, reward.count);

        return requiredStacks;
    }

    uint32 CountRequiredStarterGearStacks(Player* player) const
    {
        if (!player)
            return 0;

        std::string starterGearList = sConfigMgr->GetOption<std::string>("Prestige.StarterGear." + std::to_string(player->getClass()), "");
        if (starterGearList.empty())
            return 0;

        uint32 requiredStacks = 0;
        std::stringstream ss(starterGearList);
        std::string itemStr;
        while (std::getline(ss, itemStr, ','))
        {
            if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(itemStr))
                requiredStacks += CountStacksForItem(*itemEntry, 1);
        }
        return requiredStacks;
    }

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
            if (debug && player->IsGameMaster())
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant title ID: {}", titleId);
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
            if (titleEntry)
            {
                player->SetTitle(titleEntry);
                if (debug && player->IsGameMaster())
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
        // 1. Remove Equipment
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
        {
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 2. Remove Backpack Items
        for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
        {
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 3. Remove Bags and their contents
        for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
        {
            if (Bag* bag = player->GetBagByPos(i))
            {
                for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                {
                    if (bag->GetItemByPos(j))
                    {
                        player->DestroyItem(i, j, true);
                    }
                }
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 4. Remove Bank Items (Configurable)
        if (sConfigMgr->GetOption<bool>("Prestige.ClearBank", false))
        {
            // Main Bank Slots
            for (uint8 i = BANK_SLOT_ITEM_START; i < BANK_SLOT_ITEM_END; ++i)
            {
                if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
                {
                    player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
                }
            }

            // Bank Bags and their contents
            for (uint8 i = BANK_SLOT_BAG_START; i < BANK_SLOT_BAG_END; ++i)
            {
                if (Bag* bag = player->GetBagByPos(i))
                {
                     for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                     {
                         if (bag->GetItemByPos(j))
                             player->DestroyItem(i, j, true);
                     }
                     // Destroy the bank bag itself? Usually bank bags are items in generic inventory slots
                     // Wait, BANK_SLOT_BAG_START indices refer to the slots in the bank that HOLD bags.
                     // IMPORTANT: GetBagByPos(i) works for bank bag slots too.
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
        // 0 = Reset All, 1 = Keep Main, 2 = Keep All
        uint32 professionMode = sConfigMgr->GetOption<uint32>("Prestige.ProfessionResetMode", 0);

        if (professionMode == 2)
            return; // Keep all

        // Secondary skills (Fishing, Cooking, First Aid) - always reset if mode is 0 (Reset All)
        // If mode is 1 (Keep Main), we still reset secondaries? Usually "Keep Main" implies keeping primary professions only.
        // Let's assume mode 1 keeps primary, resets secondary.

        // Helper to reset a specific skill
        auto ResetSkill = [&](uint32 skillId) {
            if (player->HasSkill(skillId))
            {
                player->SetSkill(skillId, 0, 0, 0);
                player->removeSpell(GetSpellIdForSkill(skillId), 0xFF /*SPEC_MASK_ALL*/, false);
                // Actually SetSkill 0/0/0 effectively unlearns it in most cores or sets it to 0/0.
                // For a true reset, we often need to remove the spells.
                // For simplicity here, we stick to the existing SetSkill logic but applied conditionally.
            }
        };

        // Primary Professions
        std::vector<uint32> primarySkills = {
            SKILL_ALCHEMY, SKILL_BLACKSMITHING, SKILL_ENCHANTING, SKILL_ENGINEERING,
            SKILL_HERBALISM, SKILL_INSCRIPTION, SKILL_JEWELCRAFTING, SKILL_LEATHERWORKING,
            SKILL_MINING, SKILL_SKINNING, SKILL_TAILORING
        };

        // Secondary Professions
        std::vector<uint32> secondarySkills = {
            SKILL_COOKING, SKILL_FIRST_AID, SKILL_FISHING
        };

        if (professionMode == 0) // Reset All
        {
            for (uint32 skill : primarySkills) ResetSkill(skill);
            for (uint32 skill : secondarySkills) ResetSkill(skill);
        }
        else if (professionMode == 1) // Keep Main (Primary), Reset Secondary
        {
            for (uint32 skill : secondarySkills) ResetSkill(skill);
        }
    }

    uint32 GetSpellIdForSkill(uint32 /*skill*/)
    {
        // This is tricky without a full lookup table.
        // For now, SetSkill(skill, 0, 0, 0) is the best we can do without massive switch cases.
        return 0;
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
                LOG_INFO("scripts.dc", "Prestige: Reapplied missing prestige aura {} to player {}",
                    spellId, player->GetName());
            }
        }
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
        LOG_INFO("scripts.dc", "Prestige: Validating prestige spells in DBC...");
        bool allSpellsValid = true;

        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(i);
            if (!sSpellMgr->GetSpellInfo(spellId))
            {
                LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Spell {} for prestige level {} not found in DBC!", spellId, i);
                allSpellsValid = false;
            }
        }

        if (allSpellsValid)
        {
            LOG_INFO("scripts.dc", "Prestige: All {} prestige spells validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Some prestige spells are missing! System may not work correctly.");
        }

        // Validate that all prestige titles exist in DBC
        LOG_INFO("scripts.dc", "Prestige: Validating prestige titles in DBC...");
        bool allTitlesValid = true;

        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 titleId = PrestigeSystem::instance()->GetPrestigeTitle(i);
            if (!sCharTitlesStore.LookupEntry(titleId))
            {
                LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Title {} for prestige level {} not found in DBC!", titleId, i);
                allTitlesValid = false;
            }
        }

        if (allTitlesValid)
        {
            LOG_INFO("scripts.dc", "Prestige: All {} prestige titles validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Some prestige titles are missing! Players may not receive titles.");
        }
    }
};

void AddSC_dc_prestige_system()
{
    new PrestigePlayerScript();
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

    void RemovePrestigeBuffs(Player* player)
    {
        PrestigeSystem::instance()->RemovePrestigeBuffs(player);
    }

    void SetPrestigeLevel(Player* player, uint32 level)
    {
        PrestigeSystem::instance()->SetPrestigeLevel(player, level);
    }

    bool PerformPrestige(Player* player)
    {
        return PrestigeSystem::instance()->PerformPrestige(player);
    }
}
