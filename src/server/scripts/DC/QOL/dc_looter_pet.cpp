/*
 * DarkChaos QoL - Looter Pet (v2)
 *
 * Binds looter role to an active class companion
 * (pet/demon/guardian/charm) and periodically triggers AoE loot.
 * No helper summon is created in this mode.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Pet.h"
#include "Unit.h"
#include "TemporarySummon.h"
#include "CommandScript.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"

#include <unordered_map>

using namespace Acore::ChatCommands;

namespace DCAoELootExt
{
    bool IsPlayerAoELootEnabled(ObjectGuid playerGuid);
    bool TriggerLooterPetLootPulse(Player* player, WorldObject const* searchAnchor);
}

namespace
{

struct LooterPetConfig
{
    bool enabled = true;
    bool allowInCombat = false;
    uint32 pulseMs = 1500;

    void Load()
    {
        enabled = sConfigMgr->GetOption<bool>("AoELoot.LooterPet.Enable", true);
        allowInCombat = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.AllowInCombat", false);
        pulseMs = sConfigMgr->GetOption<uint32>(
            "AoELoot.LooterPet.PulseMs", 1500);

        if (pulseMs < 500)
            pulseMs = 500;
        if (pulseMs > 10000)
            pulseMs = 10000;
    }
};

struct LooterPetState
{
    bool enabled = false;
    uint32 elapsedMs = 0;
    ObjectGuid boundCompanionGuid;
};

static LooterPetConfig sLooterPetConfig;
static std::unordered_map<ObjectGuid, LooterPetState> sLooterPetStates;

static bool IsLooterPetEnabled(ObjectGuid guid)
{
    auto it = sLooterPetStates.find(guid);
    return it != sLooterPetStates.end() && it->second.enabled;
}

static Unit* GetActiveClassCompanion(Player* player)
{
    if (!player || !player->IsInWorld())
        return nullptr;

    if (Pet* pet = player->GetPet())
    {
        if (pet->IsInWorld() && pet->IsAlive())
            return pet;
    }

    if (Guardian* guardian = player->GetGuardianPet())
    {
        if (guardian->IsInWorld() && guardian->IsAlive())
            return guardian;
    }

    if (Unit* charm = player->GetCharm())
    {
        if (charm->IsInWorld() && charm->IsAlive() &&
            charm->GetCharmerOrOwnerGUID() == player->GetGUID() &&
            (charm->IsPet() || charm->IsGuardian() ||
             charm->IsControlledByPlayer()))
        {
            return charm;
        }
    }

    return nullptr;
}

static void SetLooterPetEnabled(Player* player, bool enabled)
{
    if (!player)
        return;

    if (!enabled)
    {
        sLooterPetStates.erase(player->GetGUID());
        return;
    }

    LooterPetState& state = sLooterPetStates[player->GetGUID()];
    state.enabled = true;
    state.elapsedMs = 0;
    state.boundCompanionGuid.Clear();
}

} // namespace

class DCLooterPetPlayerScript : public PlayerScript
{
public:
    DCLooterPetPlayerScript() : PlayerScript("DCLooterPetPlayerScript") { }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        sLooterPetStates.erase(player->GetGUID());
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;

        auto it = sLooterPetStates.find(player->GetGUID());
        if (it == sLooterPetStates.end() || !it->second.enabled)
            return;

        it->second.boundCompanionGuid.Clear();
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!sLooterPetConfig.enabled || !player)
            return;

        auto it = sLooterPetStates.find(player->GetGUID());
        if (it == sLooterPetStates.end() || !it->second.enabled)
            return;

        if (!DCAoELootExt::IsPlayerAoELootEnabled(player->GetGUID()))
            return;

        if (!player->IsAlive() || player->IsFlying())
            return;

        if (!sLooterPetConfig.allowInCombat && player->IsInCombat())
            return;

        if (player->GetLootGUID())
            return;

        LooterPetState& state = it->second;
        Unit* companion = GetActiveClassCompanion(player);
        if (!companion)
        {
            state.boundCompanionGuid.Clear();
            return;
        }

        state.boundCompanionGuid = companion->GetGUID();

        uint32 const elapsed = state.elapsedMs + diff;
        if (elapsed < sLooterPetConfig.pulseMs)
        {
            state.elapsedMs = elapsed;
            return;
        }

        state.elapsedMs = 0;
        DCAoELootExt::TriggerLooterPetLootPulse(player, companion);
    }
};

class DCLooterPetCommandScript : public CommandScript
{
public:
    DCLooterPetCommandScript() : CommandScript("DCLooterPetCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable looterPetTable =
        {
            { "toggle", HandleToggle, SEC_PLAYER, Console::No },
            { "on", HandleOn, SEC_PLAYER, Console::No },
            { "off", HandleOff, SEC_PLAYER, Console::No },
            { "status", HandleStatus, SEC_PLAYER, Console::No },
            { "reload", HandleReload, SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "looterpet", looterPetTable },
            { "lpet", looterPetTable },
        };

        return commandTable;
    }

    static bool HandleToggle(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        bool const current = IsLooterPetEnabled(player->GetGUID());
        bool const next = enabled.value_or(!current);
        SetLooterPetEnabled(player, next);

        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r %s",
            next ? "Enabled" : "Disabled");

        if (!next)
            return true;

        if (Unit* companion = GetActiveClassCompanion(player))
        {
            handler->PSendSysMessage(
                "|cff00ff00[Looter Pet]|r Bound to companion: %s",
                companion->GetName().c_str());
        }
        else
        {
            handler->SendSysMessage(
                "|cff00ff00[Looter Pet]|r Waiting for an active class "
                "companion (pet/demon/guardian/charm).");
        }

        return true;
    }

    static bool HandleOn(ChatHandler* handler)
    {
        return HandleToggle(handler, true);
    }

    static bool HandleOff(ChatHandler* handler)
    {
        return HandleToggle(handler, false);
    }

    static bool HandleStatus(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        auto it = sLooterPetStates.find(player->GetGUID());
        bool const enabled = it != sLooterPetStates.end() && it->second.enabled;
        Unit* companion = enabled ? GetActiveClassCompanion(player) : nullptr;

        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r State: %s",
            enabled ? "Enabled" : "Disabled");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Mode: class companion bound");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Companion: %s",
            companion ? companion->GetName().c_str() : "None");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Pulse: %u ms",
            sLooterPetConfig.pulseMs);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Combat: %s",
            sLooterPetConfig.allowInCombat ? "Allowed" : "Paused");

        return true;
    }

    static bool HandleReload(ChatHandler* handler)
    {
        sLooterPetConfig.Load();
        handler->SendSysMessage("Looter Pet config reloaded.");
        return true;
    }
};

class DCLooterPetWorldScript : public WorldScript
{
public:
    DCLooterPetWorldScript() : WorldScript("DCLooterPetWorldScript") { }

    void OnStartup() override
    {
        sLooterPetConfig.Load();
        LOG_INFO(
            "scripts.dc",
            "DC Looter Pet v2 initialized (enabled={}, pulse={}ms)",
            sLooterPetConfig.enabled ? "yes" : "no",
            sLooterPetConfig.pulseMs);
    }
};

void AddSC_dc_looter_pet_qol()
{
    sLooterPetConfig.Load();
    new DCLooterPetPlayerScript();
    new DCLooterPetCommandScript();
    new DCLooterPetWorldScript();
}
