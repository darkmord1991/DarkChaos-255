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
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "StringFormat.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include <functional>
#include <unordered_set>
#include <vector>

namespace
{
    // Configuration
    constexpr uint32 XP_BONUS_PER_MAX_CHAR = 5;  // 5% per character
    constexpr uint32 MAX_BONUS_CHARACTERS = 5;    // Max 5 characters = 25% bonus
    // constexpr uint32 MAX_XP_BONUS_PERCENT = XP_BONUS_PER_MAX_CHAR * MAX_BONUS_CHARACTERS; // 25%

    // Visual buff spell IDs (must match DBC entries and spell_prestige_alt_bonus_aura.cpp)
    // Spell IDs: 800040-800044 (5%-25% XP bonus in 5% increments)
    constexpr uint32 SPELL_ALT_BONUS_5  = 800040;  // 5% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_10 = 800041;  // 10% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_15 = 800042;  // 15% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_20 = 800043;  // 20% bonus visual
    constexpr uint32 SPELL_ALT_BONUS_25 = 800044;  // 25% bonus visual

    // Cache for account max level character counts. Everything here (reads,
    // writes, warm-triggers, and the async callback below) runs on the world
    // thread only, so no locking is needed.
    std::unordered_map<uint32, uint32> g_AccountMaxLevelCache;
    std::unordered_set<uint32> g_AccountMaxLevelWarmInFlight;
    std::unordered_map<uint32, std::vector<std::function<void(uint32)>>> g_AccountMaxLevelWarmWaiters;

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
                LOG_ERROR("scripts.dc", "Prestige Alt Bonus: Invalid PercentPerChar ({}). Must be 1-25. Using default {}.",
                    bonusPerChar, XP_BONUS_PER_MAX_CHAR);
                bonusPerChar = XP_BONUS_PER_MAX_CHAR;
            }

            if (maxBonusChars == 0 || maxBonusChars > 10)
            {
                LOG_ERROR("scripts.dc", "Prestige Alt Bonus: Invalid MaxCharacters ({}). Must be 1-10. Using default {}.",
                    maxBonusChars, MAX_BONUS_CHARACTERS);
                maxBonusChars = MAX_BONUS_CHARACTERS;
            }

            LOG_INFO("scripts.dc", "Prestige Alt Bonus: Loaded ({}% per char, max {} chars = {}% max bonus)",
                bonusPerChar, maxBonusChars, bonusPerChar * maxBonusChars);
        }

        bool IsEnabled() const { return enabled; }

        uint32 GetMaxLevel() const { return maxLevel; }

        // Cache-only read: never touches the database. Returns 0 (no bonus)
        // on a cold cache and kicks an async warm so the NEXT read is a hit.
        // Safe to call from hot paths (OnPlayerGiveXP fires on every kill).
        uint32 GetMaxLevelCharCount(uint32 accountId)
        {
            if (!enabled)
                return 0;

            auto it = g_AccountMaxLevelCache.find(accountId);
            if (it != g_AccountMaxLevelCache.end())
                return it->second;

            WarmMaxLevelCharCountAsync(accountId, nullptr);
            return 0;
        }

        // Load + cache the max-level character count asynchronously so the
        // world thread never blocks on this SELECT (previously observed to
        // stall World.UpdateSessions on a cold cache, e.g. right after a
        // server restart). Concurrent callers for the same account share one
        // in-flight query; every registered callback fires once it resolves.
        void WarmMaxLevelCharCountAsync(uint32 accountId, std::function<void(uint32)> onReady)
        {
            if (!enabled)
                return;

            auto cached = g_AccountMaxLevelCache.find(accountId);
            if (cached != g_AccountMaxLevelCache.end())
            {
                if (onReady)
                    onReady(cached->second);
                return;
            }

            if (onReady)
                g_AccountMaxLevelWarmWaiters[accountId].push_back(std::move(onReady));

            if (!g_AccountMaxLevelWarmInFlight.insert(accountId).second)
                return; // a warm-up query is already running for this account

            uint32 const capturedMaxLevel = maxLevel;
            uint32 const capturedMaxBonusChars = maxBonusChars;
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT COUNT(*) FROM characters WHERE account = {} AND level >= {}",
                accountId, capturedMaxLevel))
                .WithCallback([accountId, capturedMaxBonusChars](QueryResult result)
            {
                uint32 count = 0;
                if (result)
                    count = result->Fetch()[0].Get<uint32>();

                if (count > capturedMaxBonusChars)
                    count = capturedMaxBonusChars;

                g_AccountMaxLevelCache[accountId] = count;
                g_AccountMaxLevelWarmInFlight.erase(accountId);

                auto waitersIt = g_AccountMaxLevelWarmWaiters.find(accountId);
                if (waitersIt == g_AccountMaxLevelWarmWaiters.end())
                    return;

                std::vector<std::function<void(uint32)>> waiters = std::move(waitersIt->second);
                g_AccountMaxLevelWarmWaiters.erase(waitersIt);
                for (auto const& waiter : waiters)
                    if (waiter)
                        waiter(count);
            }));
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
                LOG_INFO("scripts.dc", "Prestige Alt Bonus: Applied {}% visual buff to player {}",
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

        void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
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

        void OnPlayerLogin(Player* player) override
        {
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
                return;

            // The max-level-char-count is warmed asynchronously (never blocks
            // the world thread, even on a cold cache after a server restart);
            // the buff + welcome message apply once the count is ready, which
            // is immediate on a cache hit and deferred by one DB round-trip
            // otherwise.
            uint32 accountId = player->GetSession()->GetAccountId();
            ObjectGuid const playerGuid = player->GetGUID();

            PrestigeAltBonusSystem::instance()->WarmMaxLevelCharCountAsync(accountId,
                [playerGuid](uint32 /*maxLevelCount*/)
            {
                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
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
            });
        }

        void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
        {
            if (!PrestigeAltBonusSystem::instance()->IsEnabled())
                return;

            // Clear cache and update buff when player reaches max level
            if (player->GetLevel() >= PrestigeAltBonusSystem::instance()->GetMaxLevel())
            {
                PrestigeAltBonusSystem::instance()->InvalidateCacheForPlayer(player);
                PrestigeAltBonusSystem::instance()->RemoveVisualBuff(player);

                LOG_INFO("scripts.dc", "Prestige Alt Bonus: Cleared cache and buff for account {} (player {} reached max level)",
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
            LOG_INFO("scripts.dc", "Prestige Alt Bonus: System initialized");
        }
    };
}

namespace PrestigeAPI
{
    // API Implementations
    bool IsAltBonusEnabled()
    {
        return PrestigeAltBonusSystem::instance()->IsEnabled();
    }

    uint32 GetAltBonusPercent(Player* player)
    {
        return PrestigeAltBonusSystem::instance()->CalculateXPBonus(player);
    }

    uint32 GetAccountMaxLevelCount(uint32 accountId)
    {
        return PrestigeAltBonusSystem::instance()->GetMaxLevelCharCount(accountId);
    }
}

void AddSC_dc_prestige_alt_bonus()
{
    new PrestigeAltBonusPlayerScript();
    new PrestigeAltBonusWorldScript();
}
