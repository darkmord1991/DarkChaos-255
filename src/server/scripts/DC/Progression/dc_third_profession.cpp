/*
 * DarkChaos: third primary profession slot.
 *
 * The core tracks how many more primary professions a character may learn in
 * PLAYER_CHARACTER_POINTS2 ("free primary profession points"): LoadFromDB and
 * Create start it at MaxPrimaryTradeSkill, every first-rank profession spell
 * learnt takes one away, every one unlearnt gives one back (capped at
 * MaxPrimaryTradeSkill), and the trainer refuses a new profession at zero.
 * MaxPrimaryTradeSkill stays at its realm value for everyone; this script only
 * keeps the points of an unlocked character at (MaxPrimaryTradeSkill + 1)
 * minus the professions it knows.
 *
 * Unlocked: level >= DC.ThirdProfession.UnlockLevel, or prestige level >=
 * DC.ThirdProfession.UnlockPrestige (0 turns the prestige route off).
 *
 * Recomputed at login (points first come from the core's load), on every
 * level change (prestige resets and GM level changes included), after a
 * first-rank profession spell is unlearnt (the core caps the refund at the
 * realm value, which would shut the third slot), after a spec switch, and
 * after a prestige (CrossSystem PlayerPrestige event, which carries the new
 * prestige level).
 *
 * Losing the unlock (a prestige reset below the unlock level with the prestige
 * route off) keeps the third profession: skill and recipes are progress the
 * player earned, and taking them away would also have to answer "which one".
 * Such a character simply has no free point while it holds three; unlearning
 * one closes the slot until it unlocks again.
 *
 * Playerbots keep the stock behaviour.
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "World.h"
#include "WorldSession.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/CrossSystem/EventBus.h"
#include "DC/Progression/Prestige/dc_prestige_api.h"

#include <atomic>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>

using namespace DarkChaos::CrossSystem;

namespace
{
    // Written on the world thread at config (re)load, read on map threads.
    std::atomic<bool> s_enabled{true};
    std::atomic<uint32> s_unlockLevel{80};
    std::atomic<uint32> s_unlockPrestige{0};

    struct CharacterState
    {
        uint32 prestigeLevel = 0;
        bool unlocked = false;
    };

    // Online real players only. Map threads (level change, unlearn) and the
    // world thread (login continuation) both touch it.
    std::mutex s_stateMutex;
    std::unordered_map<ObjectGuid::LowType, CharacterState> s_state;

    bool IsRealPlayer(Player const* player)
    {
        return player && player->GetSession() && !player->GetSession()->IsBot();
    }

    bool IsPrimaryProfessionFirstRank(uint32 spellId)
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(spellId);
        return info && info->IsPrimaryProfessionFirstRank();
    }

    // The same thing the core counts: first-rank primary profession spells.
    uint32 CountPrimaryProfessions(Player const* player)
    {
        uint32 count = 0;

        for (auto const& [spellId, spell] : player->GetSpellMap())
        {
            if (!spell || spell->State == PLAYERSPELL_REMOVED)
                continue;

            if (IsPrimaryProfessionFirstRank(spellId))
                ++count;
        }

        return count;
    }

    uint32 CachedPrestigeLevel(ObjectGuid::LowType guid)
    {
        std::lock_guard<std::mutex> lock(s_stateMutex);
        auto it = s_state.find(guid);
        return it != s_state.end() ? it->second.prestigeLevel : 0;
    }

    bool IsUnlocked(Player const* player)
    {
        if (player->GetLevel() >= s_unlockLevel.load())
            return true;

        uint32 const prestigeNeeded = s_unlockPrestige;
        return prestigeNeeded && CachedPrestigeLevel(player->GetGUID().GetCounter()) >= prestigeNeeded;
    }

    /**
     * Brings the free primary profession points in line with this character's
     * cap. `announce` tells the player when this call is the one that unlocked
     * the slot (level-up, prestige); login refreshes stay silent.
     */
    void Refresh(Player* player, bool announce)
    {
        if (!s_enabled || !IsRealPlayer(player))
            return;

        bool const unlocked = IsUnlocked(player);

        uint32 const cap = sWorld->getIntConfig(CONFIG_MAX_PRIMARY_TRADE_SKILL) + (unlocked ? 1 : 0);
        uint32 const known = CountPrimaryProfessions(player);
        uint32 const freePoints = known >= cap ? 0 : cap - known;

        if (player->GetFreePrimaryProfessionPoints() != freePoints)
            player->SetFreePrimaryProfessions(uint16(freePoints));

        bool wasUnlocked = false;
        {
            std::lock_guard<std::mutex> lock(s_stateMutex);
            CharacterState& state = s_state[player->GetGUID().GetCounter()];
            wasUnlocked = state.unlocked;
            state.unlocked = unlocked;
        }

        // Not when the slot is already filled (a prestige that kept three
        // professions passes through "locked" while the level drops).
        if (announce && unlocked && !wasUnlocked && freePoints > 0)
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                "|cff00ccff[Professions]|r You can now learn a third primary profession. "
                "Any profession trainer will teach it.");
        }
    }

    void SetPrestigeLevel(ObjectGuid::LowType guid, uint32 prestigeLevel)
    {
        std::lock_guard<std::mutex> lock(s_stateMutex);
        s_state[guid].prestigeLevel = prestigeLevel;
    }

    // The bus publishes on the caller's thread: the prestiging player's map thread.
    class ThirdProfessionEventHandler : public IEventHandler
    {
    public:
        SystemId GetSystemId() const override { return SystemId::None; }
        char const* GetSystemName() const override { return "ThirdProfession"; }
        std::vector<EventType> GetSubscribedEvents() const override { return { EventType::PlayerPrestige }; }

        void OnEvent(EventData const& event) override
        {
            auto const* prestige = dynamic_cast<PrestigeEvent const*>(&event);
            if (!prestige)
                return;

            Player* player = ObjectAccessor::FindConnectedPlayer(prestige->playerGuid);
            if (!IsRealPlayer(player))
                return;

            SetPrestigeLevel(player->GetGUID().GetCounter(), prestige->toPrestige);
            Refresh(player, true);
        }
    };

    std::unique_ptr<ThirdProfessionEventHandler> s_eventHandler;
}

class dc_third_profession_world : public WorldScript
{
public:
    dc_third_profession_world() : WorldScript("dc_third_profession_world",
        { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_SHUTDOWN }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.ThirdProfession.Enable", true);
        s_unlockLevel = sConfigMgr->GetOption<uint32>("DC.ThirdProfession.UnlockLevel", 80);
        s_unlockPrestige = sConfigMgr->GetOption<uint32>("DC.ThirdProfession.UnlockPrestige", 0);
    }

    void OnStartup() override
    {
        s_eventHandler = std::make_unique<ThirdProfessionEventHandler>();
        EventBus::instance()->SubscribeHandler(s_eventHandler.get());
    }

    void OnShutdown() override
    {
        if (!s_eventHandler)
            return;

        EventBus::instance()->UnsubscribeHandler(s_eventHandler.get());
        s_eventHandler.reset();
    }
};

class dc_third_profession_player : public PlayerScript
{
public:
    dc_third_profession_player() : PlayerScript("dc_third_profession_player",
    {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_LEVEL_CHANGED,
        PLAYERHOOK_ON_FORGOT_SPELL, PLAYERHOOK_ON_AFTER_SPEC_SLOT_CHANGED
    }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!s_enabled || !IsRealPlayer(player))
            return;

        Refresh(player, false);

        // The prestige route needs the prestige level, which nothing has
        // loaded yet at this point; read it without blocking the world thread.
        // Read it even at the unlock level: a later prestige reset drops the
        // level, and the slot must stay open if the prestige level covers it.
        if (!s_unlockPrestige || !PrestigeAPI::IsEnabled())
            return;

        ObjectGuid const guid = player->GetGUID();
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT `prestige_level` FROM `dc_character_prestige` WHERE `guid` = {}", guid.GetCounter()))
            .WithCallback([guid](QueryResult result)
        {
            Player* target = ObjectAccessor::FindPlayer(guid);
            if (!target || !target->IsInWorld())
                return;

            SetPrestigeLevel(guid.GetCounter(), result ? result->Fetch()[0].Get<uint32>() : 0);
            Refresh(target, false);
        }));
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        std::lock_guard<std::mutex> lock(s_stateMutex);
        s_state.erase(player->GetGUID().GetCounter());
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        Refresh(player, true);
    }

    // removeSpell has already refunded (and capped) the point when this fires.
    void OnPlayerForgotSpell(Player* player, uint32 spellId) override
    {
        if (s_enabled && IsRealPlayer(player) && IsPrimaryProfessionFirstRank(spellId))
            Refresh(player, false);
    }

    void OnPlayerAfterSpecSlotChanged(Player* player, uint8 /*newSlot*/) override
    {
        Refresh(player, false);
    }
};

void AddSC_dc_third_profession()
{
    new dc_third_profession_world();
    new dc_third_profession_player();
}
