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
    TITLE_PRESTIGE_1  = 300,  // Custom title IDs (must add to CharTitles.dbc)
    TITLE_PRESTIGE_2  = 301,
    TITLE_PRESTIGE_3  = 302,
    TITLE_PRESTIGE_4  = 303,
    TITLE_PRESTIGE_5  = 304,
    TITLE_PRESTIGE_6  = 305,
    TITLE_PRESTIGE_7  = 306,
    TITLE_PRESTIGE_8  = 307,
    TITLE_PRESTIGE_9  = 308,
    TITLE_PRESTIGE_10 = 309,
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
        QueryResult result = CharacterDatabase.Query("SELECT prestige_level FROM character_prestige WHERE guid = {}", player->GetGUID().GetCounter());
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

        CharacterDatabase.Execute("REPLACE INTO character_prestige (guid, prestige_level, prestige_date) VALUES ({}, {}, NOW())", 
            player->GetGUID().GetCounter(), level);
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

        // Remove old prestige buffs
        RemovePrestigeBuffs(player);

        // Reset level
        player->SetLevel(resetLevel);
        player->InitStatsForLevel(true);
        player->UpdateSkillsForLevel();

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

        // Apply new prestige buffs
        ApplyPrestigeBuffs(player);

        // Grant title
        GrantPrestigeTitle(player, newPrestige);

        // Grant prestige rewards
        GrantPrestigeRewards(player, newPrestige);

        // Update achievements/statistics
        UpdatePrestigeAchievements(player, newPrestige);

        // Announce
        if (announcePrestige)
        {
            std::string announcement = Acore::StringFormat("Player {} has achieved Prestige Level {}!", playerName, newPrestige);
            sWorld->SendWorldText(LANG_SYSTEMMESSAGE, announcement.c_str());
        }

        // Notify player
        ChatHandler(player->GetSession()).PSendSysMessage("Congratulations! You have reached Prestige Level {}!", newPrestige);
        ChatHandler(player->GetSession()).PSendSysMessage("You now have {}% bonus to all stats!", newPrestige * statBonusPercent);

        // Log to database
        CharacterDatabase.Execute(
            "INSERT INTO character_prestige_log (guid, prestige_level, old_level, new_level, timestamp) VALUES ({}, {}, {}, {}, NOW())",
            player->GetGUID().GetCounter(), newPrestige, oldLevel, resetLevel
        );

        // Save player
        player->SaveToDB();
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        uint32 prestigeLevel = GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;

        // Apply appropriate prestige spell based on level
        uint32 spellId = GetPrestigeSpell(prestigeLevel);
        if (spellId && !player->HasAura(spellId))
        {
            player->CastSpell(player, spellId, true);
        }
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

        std::vector<std::string> rewardTokens = Acore::Tokenize(rewardsStr, ';', false);
        for (const std::string& token : rewardTokens)
        {
            std::vector<std::string> parts = Acore::Tokenize(token, ':', false);
            if (parts.size() == 3)
            {
                uint32 prestigeLevel = Acore::StringTo<uint32>(parts[0]).value_or(0);
                uint32 itemEntry = Acore::StringTo<uint32>(parts[1]).value_or(0);
                uint32 count = Acore::StringTo<uint32>(parts[2]).value_or(1);

                if (prestigeLevel > 0 && itemEntry > 0)
                {
                    prestigeRewards[prestigeLevel].push_back({itemEntry, count});
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
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
            if (titleEntry)
                player->SetTitle(titleEntry);
        }
    }

    void UpdatePrestigeAchievements(Player* player, uint32 prestigeLevel)
    {
        // Update custom achievement criteria if configured
        // Achievement IDs should be added to achievement_dbc.sql
        uint32 achievementBase = sConfigMgr->GetOption<uint32>("Prestige.AchievementBase", 10000);
        if (achievementBase > 0)
        {
            player->CompletedAchievement(sAchievementStore.LookupEntry(achievementBase + prestigeLevel));
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

        std::vector<std::string> items = Acore::Tokenize(starterGearList, ',', false);
        for (const std::string& itemStr : items)
        {
            uint32 itemEntry = Acore::StringTo<uint32>(itemStr).value_or(0);
            if (itemEntry)
                player->AddItem(itemEntry, 1);
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

    void OnLogin(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Apply prestige buffs on login
        PrestigeSystem::instance()->ApplyPrestigeBuffs(player);

        // Notify player of their prestige level
        uint32 prestigeLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        if (prestigeLevel > 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Welcome back! You are Prestige Level {} with {}% bonus stats.",
                prestigeLevel, prestigeLevel * PrestigeSystem::instance()->GetStatBonusPercent());
        }

        // Check if player can prestige
        if (PrestigeSystem::instance()->CanPrestige(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700You have reached level {}! Type .prestige to ascend to the next prestige level!|r",
                PrestigeSystem::instance()->GetRequiredLevel());
        }
    }

    void OnLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Notify when player can prestige
        if (player->GetLevel() == PrestigeSystem::instance()->GetRequiredLevel())
        {
            uint32 currentPrestige = PrestigeSystem::instance()->GetPrestigeLevel(player);
            if (currentPrestige < PrestigeSystem::instance()->GetMaxPrestigeLevel())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700Congratulations! You can now prestige to level {}! Type .prestige to begin.|r",
                    currentPrestige + 1);
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
            { "info",    HandlePrestigeInfoCommand,    SEC_PLAYER,      Console::No },
            { "reset",   HandlePrestigeResetCommand,   SEC_PLAYER,      Console::No },
            { "confirm", HandlePrestigeConfirmCommand, SEC_PLAYER,      Console::No },
            { "admin",   HandlePrestigeAdminCommand,   SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "prestige", prestigeCommandTable },
        };

        return commandTable;
    }

    static bool HandlePrestigeInfoCommand(ChatHandler* handler, const char* /*args*/)
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

    static bool HandlePrestigeResetCommand(ChatHandler* handler, const char* /*args*/)
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

    static bool HandlePrestigeConfirmCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeSystem::instance()->CanPrestige(player))
        {
            handler->SendSysMessage("You cannot prestige at this time.");
            return true;
        }

        PrestigeSystem::instance()->PerformPrestige(player);
        return true;
    }

    static bool HandlePrestigeAdminCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
            return false;

        std::vector<std::string> tokens = Acore::Tokenize(std::string(args), ' ', false);
        if (tokens.empty())
            return false;

        std::string subCommand = tokens[0];

        if (subCommand == "set" && tokens.size() == 3)
        {
            std::string playerName = tokens[1];
            uint32 level = Acore::StringTo<uint32>(tokens[2]).value_or(0);

            Player* target = ObjectAccessor::FindPlayerByName(playerName);
            if (!target)
            {
                handler->PSendSysMessage("Player {} not found.", playerName);
                return true;
            }

            PrestigeSystem::instance()->SetPrestigeLevel(target, level);
            PrestigeSystem::instance()->RemovePrestigeBuffs(target);
            PrestigeSystem::instance()->ApplyPrestigeBuffs(target);

            handler->PSendSysMessage("Set {}'s prestige level to {}.", playerName, level);
            ChatHandler(target->GetSession()).PSendSysMessage("Your prestige level has been set to {} by a GM.", level);
            return true;
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
