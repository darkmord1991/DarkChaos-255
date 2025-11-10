/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Alt-Friendly XP Bonus
 *
 * Grants 5% XP bonus per max-level character on the account (max 25%)
 * Encourages alt play and rewards account progression
 */

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"

namespace
{
    // Configuration
    constexpr uint32 XP_BONUS_PER_MAX_CHAR = 5;  // 5% per character
    constexpr uint32 MAX_BONUS_CHARACTERS = 5;    // Max 5 characters = 25% bonus
    constexpr uint32 MAX_XP_BONUS_PERCENT = XP_BONUS_PER_MAX_CHAR * MAX_BONUS_CHARACTERS; // 25%
    
    // Visual buff spell IDs (must match DBC entries and spell_prestige_alt_bonus_aura.cpp)
    constexpr uint32 SPELL_ALT_BONUS_5  = 800020;  // 5% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_10 = 800021;  // 10% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_15 = 800022;  // 15% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_20 = 800023;  // 20% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_25 = 800024;  // 25% bonus visual
    
    // Cache for account max level character counts
    std::unordered_map<uint32, uint32> g_AccountMaxLevelCache;
    
    class PrestigeAltBonusSystem
    {
    public:
        static PrestigeAltBonusSystem* instance()
        {
            static PrestigeAltBonusSystem instance;
            return &instance;
        }
        
        void LoadConfig()
        {
            enabled = sConfigMgr->GetOption<bool>("Prestige.AltBonus.Enable", true);
            maxLevel = sConfigMgr->GetOption<uint32>("Prestige.AltBonus.MaxLevel", 255);
            bonusPerChar = sConfigMgr->GetOption<uint32>("Prestige.AltBonus.PercentPerChar", XP_BONUS_PER_MAX_CHAR);
            maxBonusChars = sConfigMgr->GetOption<uint32>("Prestige.AltBonus.MaxCharacters", MAX_BONUS_CHARACTERS);
            
            // Validate config
            if (bonusPerChar == 0 || bonusPerChar > 25)
            {
                LOG_ERROR("scripts", "Prestige Alt Bonus: Invalid PercentPerChar ({}). Must be 1-25. Using default {}.",
                    bonusPerChar, XP_BONUS_PER_MAX_CHAR);
                bonusPerChar = XP_BONUS_PER_MAX_CHAR;
            }
            
            if (maxBonusChars == 0 || maxBonusChars > 10)
            {
                LOG_ERROR("scripts", "Prestige Alt Bonus: Invalid MaxCharacters ({}). Must be 1-10. Using default {}.",
                    maxBonusChars, MAX_BONUS_CHARACTERS);
                maxBonusChars = MAX_BONUS_CHARACTERS;
            }
            
            LOG_INFO("scripts", "Prestige Alt Bonus: Loaded ({}% per char, max {} chars = {}% max bonus)",
                bonusPerChar, maxBonusChars, bonusPerChar * maxBonusChars);
        }
        
        bool IsEnabled() const { return enabled; }
        
        uint32 GetMaxLevelCharCount(uint32 accountId)
        {
            if (!enabled)
                return 0;
                
            // Check cache first
            auto it = g_AccountMaxLevelCache.find(accountId);
            if (it != g_AccountMaxLevelCache.end())
                return it->second;
            
            // Query database for max level characters on this account
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM characters WHERE account = {} AND level >= {}",
                accountId, maxLevel
            );
            
            uint32 count = 0;
            if (result)
            {
                Field* fields = result->Fetch();
                count = fields[0].Get<uint32>();
            }
            
            // Cap at max bonus characters
            if (count > maxBonusChars)
                count = maxBonusChars;
            
            // Cache the result
            g_AccountMaxLevelCache[accountId] = count;
            return count;
        }
        
        uint32 CalculateXPBonus(Player* player)
        {
            if (!enabled || !player)
                return 0;
            
            // Don't grant bonus to max level characters
            if (player->GetLevel() >= maxLevel)
                return 0;
            
            uint32 maxLevelCount = GetMaxLevelCharCount(player->GetSession()->GetAccountId());
            
            // Subtract 1 if this character is at max level (shouldn't happen due to check above, but just in case)
            if (player->GetLevel() >= maxLevel && maxLevelCount > 0)
                maxLevelCount--;
            
            return maxLevelCount * bonusPerChar;
        }
        
        void ClearAccountCache(uint32 accountId)
        {
            auto it = g_AccountMaxLevelCache.find(accountId);
            if (it != g_AccountMaxLevelCache.end())
            {
                g_AccountMaxLevelCache.erase(it);
            }
        }
        
        void InvalidateCacheForPlayer(Player* player)
        {
            if (player)
            {
                ClearAccountCache(player->GetSession()->GetAccountId());
            }
        }
        
        uint32 GetBonusSpellId(uint32 bonusPercent)
        {
            switch (bonusPercent)
            {
                case 5:  return SPELL_ALT_BONUS_5;
                case 10: return SPELL_ALT_BONUS_10;
                case 15: return SPELL_ALT_BONUS_15;
                case 20: return SPELL_ALT_BONUS_20;
                case 25: return SPELL_ALT_BONUS_25;
                default: return 0;
            }
        }
        
        void ApplyVisualBuff(Player* player)
        {
            if (!player || !enabled)
                return;
            
            uint32 bonusPercent = CalculateXPBonus(player);
            if (bonusPercent == 0)
            {
                RemoveVisualBuff(player);
                return;
            }
            
            uint32 spellId = GetBonusSpellId(bonusPercent);
            if (spellId == 0)
                return;
            
            // Remove all other alt bonus buffs first
            RemoveVisualBuff(player);
            
            // Apply the appropriate buff
            if (!player->HasAura(spellId))
            {
                player->CastSpell(player, spellId, true);
                LOG_INFO("scripts", "Prestige Alt Bonus: Applied {}% visual buff to player {}", 
                    bonusPercent, player->GetName());
            }
        }
        
        void RemoveVisualBuff(Player* player)
        {
            if (!player)
                return;
            
            // Remove all possible alt bonus buffs
            player->RemoveAura(SPELL_ALT_BONUS_5);
            player->RemoveAura(SPELL_ALT_BONUS_10);
            player->RemoveAura(SPELL_ALT_BONUS_15);
            player->RemoveAura(SPELL_ALT_BONUS_20);
            player->RemoveAura(SPELL_ALT_BONUS_25);
        }
        
    private:
        bool enabled;
        uint32 maxLevel;
        uint32 bonusPerChar;
        uint32 maxBonusChars;
    };
    
    class PrestigeAltBonusPlayerScript : public PlayerScript
    {
    public:
        PrestigeAltBonusPlayerScript() : PlayerScript("PrestigeAltBonusPlayerScript") { }
        
        void OnGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
        {
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
                return;
            
            uint32 bonusPercent = PrestigeAltBonusSystem::instance()->CalculateXPBonus(player);
            if (bonusPercent > 0)
            {
                uint32 bonusXP = (amount * bonusPercent) / 100;
                amount += bonusXP;
            }
        }
        
        void OnLogin(Player* player) override
        {
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
                return;
            
            uint32 bonusPercent = PrestigeAltBonusSystem::instance()->CalculateXPBonus(player);
            
            // Apply visual buff
            PrestigeAltBonusSystem::instance()->ApplyVisualBuff(player);
            
            // Show welcome message if player has bonus
            if (bonusPercent > 0)
            {
                uint32 maxLevelCount = PrestigeAltBonusSystem::instance()->GetMaxLevelCharCount(
                    player->GetSession()->GetAccountId());
                
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFF00FF00[Alt Bonus]|r You have {}% bonus XP from {} max-level character(s) on your account!",
                    bonusPercent, maxLevelCount
                );
            }
        }
        
        void OnLevelChanged(Player* player, uint8 /*oldLevel*/) override
        {
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
                return;
            
            // Clear cache and update buff when player reaches max level
            if (player->GetLevel() >= 255)
            {
                PrestigeAltBonusSystem::instance()->InvalidateCacheForPlayer(player);
                PrestigeAltBonusSystem::instance()->RemoveVisualBuff(player);
                
                LOG_INFO("scripts", "Prestige Alt Bonus: Cleared cache and buff for account {} (player {} reached max level)",
                    player->GetSession()->GetAccountId(), player->GetName());
            }
        }
    };
    
    class PrestigeAltBonusWorldScript : public WorldScript
    {
    public:
        PrestigeAltBonusWorldScript() : WorldScript("PrestigeAltBonusWorldScript") { }
        
        void OnAfterConfigLoad(bool /*reload*/) override
        {
            PrestigeAltBonusSystem::instance()->LoadConfig();
        }
        
        void OnStartup() override
        {
            LOG_INFO("scripts", "Prestige Alt Bonus: System initialized");
        }
    };
    
    class PrestigeAltBonusCommandScript : public CommandScript
    {
    public:
        PrestigeAltBonusCommandScript() : CommandScript("PrestigeAltBonusCommandScript") { }
        
        ChatCommandTable GetCommands() const override
        {
            static ChatCommandTable altBonusCommandTable =
            {
                { "info", HandleAltBonusInfoCommand, SEC_PLAYER, Console::No },
            };
            
            static ChatCommandTable prestigeCommandTable =
            {
                { "altbonus", altBonusCommandTable },
            };
            
            static ChatCommandTable commandTable =
            {
                { "prestige", prestigeCommandTable },
            };
            
            return commandTable;
        }
        
        static bool HandleAltBonusInfoCommand(ChatHandler* handler, char const* /*args*/)
        {
            Player* player = handler->GetSession()->GetPlayer();
            if (!player)
                return false;
            
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
            {
                handler->SendSysMessage("Alt bonus system is currently disabled.");
                return true;
            }
            
            uint32 accountId = player->GetSession()->GetAccountId();
            uint32 maxLevelCount = PrestigeAltBonusSystem::instance()->GetMaxLevelCharCount(accountId);
            uint32 bonusPercent = PrestigeAltBonusSystem::instance()->CalculateXPBonus(player);
            
            handler->PSendSysMessage("|cFFFFD700=== Alt-Friendly XP Bonus ===|r");
            handler->PSendSysMessage("Max-level characters on account: |cFF00FF00{}|r", maxLevelCount);
            
            if (player->GetLevel() >= 255)
            {
                handler->PSendSysMessage("|cFFFFFF00You are max level and do not receive the bonus.|r");
            }
            else
            {
                handler->PSendSysMessage("Current XP bonus: |cFF00FF00{}%|r", bonusPercent);
                handler->PSendSysMessage("(5% per max-level character, max 25%)");
            }
            
            return true;
        }
    };
}

void AddSC_dc_prestige_alt_bonus()
{
    new PrestigeAltBonusPlayerScript();
    new PrestigeAltBonusWorldScript();
    new PrestigeAltBonusCommandScript();
}
