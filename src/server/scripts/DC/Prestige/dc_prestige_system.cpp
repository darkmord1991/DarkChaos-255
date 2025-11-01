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
#include "ObjectAccessor.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"
#include "AchievementMgr.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include <sstream>

using namespace Acore::ChatCommands;

enum PrestigeConfig
{
    MAX_PRESTIGE_LEVEL = 10,
    REQUIRED_LEVEL = 255,
    STAT_BONUS_PER_PRESTIGE = 1,  // 1% per prestige level
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

        // Query from database
        QueryResult result = CharacterDatabase.Query("SELECT prestige_level FROM dc_character_prestige WHERE guid = {}", player->GetGUID().GetCounter());
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }

    void SetPrestigeLevel(Player* player, uint32 level)
    {
        if (!player)
            return;

        CharacterDatabase.Execute("REPLACE INTO dc_character_prestige (guid, prestige_level, total_prestiges, last_prestige_time) VALUES ({}, {}, {}, UNIX_TIMESTAMP())", 
            player->GetGUID().GetCounter(), level, level);
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
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: CanPrestige failed in PerformPrestige");
            return;
        }

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Starting prestige process...");

        uint32 currentPrestige = GetPrestigeLevel(player);
        uint32 newPrestige = currentPrestige + 1;

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Current prestige: {}, New prestige: {}", currentPrestige, newPrestige);

        // Save current state for logging
        std::string playerName = player->GetName();
        uint32 oldLevel = player->GetLevel();

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Removing old buffs...");
        // Remove old prestige buffs
        RemovePrestigeBuffs(player);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Setting level to {}...", resetLevel);
        // Reset level
        player->SetLevel(resetLevel);
        
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Calling InitStatsForLevel...");
        player->InitStatsForLevel(true);
        
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Calling UpdateSkillsForLevel...");
        player->UpdateSkillsForLevel();
        
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Calling UpdateAllStats...");
        player->UpdateAllStats();

        // Handle gear
        if (!keepGear)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Removing gear...");
            RemoveAllGear(player);
            if (grantStarterGear)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Granting starter gear...");
                GrantStarterGear(player);
            }
        }

        // Handle gold
        if (!keepGold)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Removing gold...");
            player->SetMoney(0);
        }

        // Handle professions
        if (!keepProfessions)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Resetting professions...");
            ResetProfessions(player);
        }

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Setting prestige level...");
        // Update prestige level
        SetPrestigeLevel(player, newPrestige);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Granting title...");
        // Grant title
        GrantPrestigeTitle(player, newPrestige);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Granting rewards...");
        // Grant prestige rewards
        GrantPrestigeRewards(player, newPrestige);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Updating achievements...");
        // Update achievements/statistics
        UpdatePrestigeAchievements(player, newPrestige);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Saving to database...");
        // Save player first before applying buffs
        player->SaveToDB(false, false);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Applying prestige buffs...");
        // Apply new prestige buffs (after save to ensure level is updated)
        ApplyPrestigeBuffs(player);
        
        // Force update player to ensure buffs stick
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Updating player stats...");
        player->UpdateAllStats();
        player->SetFullHealth();
        if (player->getPowerType() == POWER_MANA)
            player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
        
        // Save again after applying buffs
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Saving after buffs...");
        player->SaveToDB(false, false);

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Announcing prestige...");
        // Announce
        if (announcePrestige)
        {
            std::string announcement = Acore::StringFormat("|cFFFFD700[Prestige]|r Player {} has achieved Prestige Level {}!", playerName, newPrestige);
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, announcement);
        }

        // Notify player
        ChatHandler(player->GetSession()).PSendSysMessage("Congratulations! You have reached Prestige Level {}!", newPrestige);
        ChatHandler(player->GetSession()).PSendSysMessage("You now have {}% bonus to all stats!", newPrestige * statBonusPercent);
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000You will be teleported to your hearthstone location in 5 seconds...|r");

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Logging to database...");
        // Log to database with error checking
        try
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_prestige_log (guid, prestige_level, prestige_time, from_level, kept_gear) VALUES ({}, {}, UNIX_TIMESTAMP(), {}, {})",
                player->GetGUID().GetCounter(), newPrestige, oldLevel, keepGear ? 1 : 0
            );
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Database log successful");
        }
        catch (...)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Database log failed (non-fatal)");
        }
        
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: PerformPrestige completed!");
        
        // Teleport to starting location
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000Teleporting to your starting location...|r");
        TeleportToStartingLocation(player);
    }

    void TeleportToStartingLocation(Player* player)
    {
        if (!player)
            return;

        uint32 mapId = 0;
        float x = 0, y = 0, z = 0, o = 0;
        
        // Get starting location from playercreation table based on race AND class
        QueryResult result = WorldDatabase.Query(
            "SELECT map, position_x, position_y, position_z, orientation FROM playercreation WHERE race = {} AND class = {} LIMIT 1", 
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
            
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Found starting location for race {} class {} in playercreation table", 
                player->getRace(), player->getClass());
        }
        else
        {
            // Try to find any entry for this race as fallback
            result = WorldDatabase.Query(
                "SELECT map, position_x, position_y, position_z, orientation FROM playercreation WHERE race = {} LIMIT 1", 
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
                
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Using fallback location for race {} from playercreation table", 
                    player->getRace());
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000WARNING: No entry found in playercreation table for race {}|r", player->getRace());
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
                        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Unknown race for prestige teleport!|r");
                        return;
                }
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Using hardcoded fallback location");
            }
        }

        // Teleport player
        player->TeleportTo(mapId, x, y, z, o);
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Teleported to your starting location!|r");
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        uint32 prestigeLevel = GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;

        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Applying prestige bonuses for level {}", prestigeLevel);
        
        // Apply visual aura for display purposes
        uint32 spellId = GetPrestigeSpell(prestigeLevel);
        if (spellId)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to cast prestige spell ID: {}", spellId);
            
            // Check if spell exists in DBC
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Prestige spell {} not found in spell DBC!|r", spellId);
                return;
            }
            
            // Remove any existing prestige buffs first
            RemovePrestigeBuffs(player);
            
            // Cast the prestige spell with AddAura for permanent effect
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Adding aura for spell {}", spellId);
            Aura* aura = player->AddAura(spellId, player);
            
            // Verify the aura was applied
            if (aura || player->HasAura(spellId))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Prestige buff aura applied! (Spell ID: {})|r", spellId);
            }
        }
        
        // Apply stat bonuses via visual aura
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Prestige bonuses applied ({}% bonus per level)", 
            PrestigeSystem::instance()->GetStatBonusPercent());
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
        switch (prestigeLevel)
        {
            case 1:  return SPELL_PRESTIGE_BONUS_1;
            case 2:  return SPELL_PRESTIGE_BONUS_2;
            case 3:  return SPELL_PRESTIGE_BONUS_3;
            case 4:  return SPELL_PRESTIGE_BONUS_4;
            case 5:  return SPELL_PRESTIGE_BONUS_5;
            case 6:  return SPELL_PRESTIGE_BONUS_6;
            case 7:  return SPELL_PRESTIGE_BONUS_7;
            case 8:  return SPELL_PRESTIGE_BONUS_8;
            case 9:  return SPELL_PRESTIGE_BONUS_9;
            case 10: return SPELL_PRESTIGE_BONUS_10;
            default: return 0;
        }
    }

    uint32 GetPrestigeTitle(uint32 prestigeLevel)
    {
        if (prestigeLevel == 0 || prestigeLevel > 10)
            return 0;
        return TITLE_PRESTIGE_1 + (prestigeLevel - 1);
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

    void UpdatePrestigeAchievements(Player* player, uint32 prestigeLevel)
    {
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
public:
    PrestigePlayerScript() : PlayerScript("PrestigePlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG PRESTIGE LOGIN: System disabled");
            return;
        }

        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700=== PRESTIGE SYSTEM LOGIN DEBUG ===|r");

        // Apply prestige buffs on login
        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Player prestige level from DB: {}", prestigeLevel);
        
        if (prestigeLevel > 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Calling ApplyPrestigeBuffs for level {}", prestigeLevel);
            PrestigeSystem::instance()->ApplyPrestigeBuffs(player);
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: No prestige level, skipping buff application");
        }

        // Notify player of their prestige level
        if (prestigeLevel > 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Welcome back! You are Prestige Level {} with {}% bonus stats.",
                prestigeLevel, prestigeLevel * PrestigeSystem::instance()->GetStatBonusPercent());
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: You are not yet prestige");
        }

        // Check if player can prestige
        if (PrestigeSystem::instance()->CanPrestige(player))
        {
            uint32 currentPrestige = PrestigeSystem::instance()->GetPrestigeLevel(player);
            if (currentPrestige < PrestigeSystem::instance()->GetMaxPrestigeLevel())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700You have reached level {}! Type .prestige to ascend to the next prestige level!|r",
                    currentPrestige + 1);
            }
        }
        
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700=== END PRESTIGE LOGIN DEBUG ===|r");
    }

    void OnPlayerUpdate(Player* player, uint32 /*p_time*/) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;

        // Check if prestige aura is missing and reapply it
        // This ensures the buff persists even if something removes it
        uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(prestigeLevel);
        if (spellId && !player->HasAura(spellId))
        {
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (spellInfo)
            {
                // Reapply silently
                player->AddAura(spellId, player);
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
        
        // Store player GUID to prevent issues if session gets invalidated
        ObjectGuid playerGuid = player->GetGUID();
        
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
};

void AddSC_dc_prestige_system()
{
    new PrestigePlayerScript();
    new PrestigeCommandScript();
    new PrestigeWorldScript();
}
