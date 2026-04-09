/*
 * DarkChaos QoL - Looter Pet (v2)
 *
 * Binds looter role to an active companion
 * (pet/demon/guardian/charm or summoned critter companion)
 * and periodically triggers AoE loot.
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
#include "ObjectAccessor.h"

#include <unordered_map>

using namespace Acore::ChatCommands;

namespace DCAoELootExt
{
    bool IsPlayerAoELootEnabled(ObjectGuid playerGuid);
    void ReloadAoELootConfig();
    uint8 GetPlayerMinQuality(ObjectGuid playerGuid);
    bool GetPlayerGoldOnly(ObjectGuid playerGuid);
    bool GetLooterPetPathfindingEnabled();
    void SetLooterPetPathfindingEnabled(bool value);
    bool GetLooterPetPathAllowIncomplete();
    void SetLooterPetPathAllowIncomplete(bool value);
    bool GetLooterPetPathRejectShortcut();
    void SetLooterPetPathRejectShortcut(bool value);
    float GetLooterPetPathMaxLength();
    uint32 GetLooterPetPathMaxChecks();
    bool TriggerLooterPetLootPulse(Player* player, WorldObject* searchAnchor);
}

namespace
{

struct LooterPetConfig
{
    bool enabled = true;
    bool allowInCombat = false;
    uint32 pulseMs = 1500;
    bool fallbackToPlayerAnchor = true;
    bool companionLeashEnable = true;
    float companionMaxDistance = 45.0f;

    void Load()
    {
        enabled = sConfigMgr->GetOption<bool>("AoELoot.LooterPet.Enable", true);
        allowInCombat = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.AllowInCombat", false);
        pulseMs = sConfigMgr->GetOption<uint32>(
            "AoELoot.LooterPet.PulseMs", 1500);
        fallbackToPlayerAnchor = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.FallbackToPlayerAnchor", true);
        companionLeashEnable = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.CompanionLeash.Enable", true);
        companionMaxDistance = sConfigMgr->GetOption<float>(
            "AoELoot.LooterPet.CompanionLeash.MaxDistance", 45.0f);

        // Autonomous looter behavior is intentionally out-of-combat only.
        if (allowInCombat)
        {
            LOG_WARN("scripts.dc", "AoELoot.LooterPet.AllowInCombat=1 is ignored; autonomous looter pulses are forced out-of-combat.");
            allowInCombat = false;
        }

        if (pulseMs < 500)
            pulseMs = 500;
        if (pulseMs > 10000)
            pulseMs = 10000;
        if (companionMaxDistance < 5.0f)
            companionMaxDistance = 5.0f;
        if (companionMaxDistance > 150.0f)
            companionMaxDistance = 150.0f;
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

static Unit* GetActiveLooterCompanion(Player* player)
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

    if (Unit* critter = ObjectAccessor::GetUnit(*player, player->GetCritterGUID()))
    {
        if (critter->IsInWorld() && critter->IsAlive())
            return critter;
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

        // Autonomous looter pulses are intentionally out-of-combat only.
        if (player->IsInCombat())
            return;

        if (ObjectGuid const lootGuid = player->GetLootGUID())
        {
            bool hasActiveLoot = false;

            if (lootGuid.IsCreatureOrVehicle())
            {
                if (Creature* lootCreature = player->GetMap()->GetCreature(lootGuid))
                {
                    hasActiveLoot = lootCreature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
                }
            }

            if (hasActiveLoot)
                return;

            player->SendLootRelease(lootGuid);
        }

        LooterPetState& state = it->second;
        Unit* companion = GetActiveLooterCompanion(player);
        if (!companion)
        {
            state.boundCompanionGuid.Clear();
            return;
        }

        ObjectGuid const companionGuid = companion->GetGUID();
        if (state.boundCompanionGuid != companionGuid)
        {
            state.boundCompanionGuid = companionGuid;

            if (WorldSession* session = player->GetSession())
            {
                ChatHandler(session).PSendSysMessage(
                    "|cff00ff00[Looter Pet]|r New companion: {}",
                    companion->GetName());
            }
        }

        if (sLooterPetConfig.companionLeashEnable &&
            companion->GetDistance(player) > sLooterPetConfig.companionMaxDistance)
        {
            return;
        }

        uint32 const elapsed = state.elapsedMs + diff;
        if (elapsed < sLooterPetConfig.pulseMs)
        {
            state.elapsedMs = elapsed;
            return;
        }

        state.elapsedMs = 0;
        bool const didLoot = DCAoELootExt::TriggerLooterPetLootPulse(player, companion);
        if (!didLoot && sLooterPetConfig.fallbackToPlayerAnchor)
            DCAoELootExt::TriggerLooterPetLootPulse(player, player);
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
            { "fallback", HandleFallback, SEC_PLAYER, Console::No },
            { "leash", HandleLeash, SEC_PLAYER, Console::No },
            { "leashdist", HandleLeashDistance, SEC_PLAYER, Console::No },
            { "path", HandlePathfinding, SEC_PLAYER, Console::No },
            { "pathincomplete", HandlePathIncomplete, SEC_PLAYER, Console::No },
            { "pathshortcutreject", HandlePathShortcutReject, SEC_PLAYER, Console::No },
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
            "|cff00ff00[Looter Pet]|r {}",
            next ? "Enabled" : "Disabled");

        if (!next)
            return true;

        if (Unit* companion = GetActiveLooterCompanion(player))
        {
            auto stateIt = sLooterPetStates.find(player->GetGUID());
            if (stateIt != sLooterPetStates.end())
                stateIt->second.boundCompanionGuid = companion->GetGUID();

            handler->PSendSysMessage(
                "|cff00ff00[Looter Pet]|r Bound to companion: {}",
                companion->GetName());
        }
        else
        {
            handler->SendSysMessage(
                "|cff00ff00[Looter Pet]|r Waiting for an active companion "
                "(pet/demon/guardian/charm/companion pet).");
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

    static bool HandleFallback(ChatHandler* handler, Optional<bool> enabled = {})
    {
        sLooterPetConfig.fallbackToPlayerAnchor = enabled.value_or(!sLooterPetConfig.fallbackToPlayerAnchor);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Fallback anchor: {}",
            sLooterPetConfig.fallbackToPlayerAnchor ? "Player" : "Off");
        return true;
    }

    static bool HandleLeash(ChatHandler* handler, Optional<bool> enabled = {})
    {
        sLooterPetConfig.companionLeashEnable = enabled.value_or(!sLooterPetConfig.companionLeashEnable);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Companion leash: {}",
            sLooterPetConfig.companionLeashEnable ? "On" : "Off");
        return true;
    }

    static bool HandleLeashDistance(ChatHandler* handler, float distance)
    {
        if (distance < 5.0f)
            distance = 5.0f;
        if (distance > 150.0f)
            distance = 150.0f;

        sLooterPetConfig.companionMaxDistance = distance;
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Companion leash distance: {:.1f} yd",
            sLooterPetConfig.companionMaxDistance);
        return true;
    }

    static bool HandlePathfinding(ChatHandler* handler, Optional<bool> enabled = {})
    {
        bool const next = enabled.value_or(!DCAoELootExt::GetLooterPetPathfindingEnabled());
        DCAoELootExt::SetLooterPetPathfindingEnabled(next);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Pathfinding: {}",
            next ? "On" : "Off");
        return true;
    }

    static bool HandlePathIncomplete(ChatHandler* handler, Optional<bool> enabled = {})
    {
        bool const next = enabled.value_or(!DCAoELootExt::GetLooterPetPathAllowIncomplete());
        DCAoELootExt::SetLooterPetPathAllowIncomplete(next);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Path incomplete: {}",
            next ? "Allowed" : "Rejected");
        return true;
    }

    static bool HandlePathShortcutReject(ChatHandler* handler, Optional<bool> enabled = {})
    {
        bool const next = enabled.value_or(!DCAoELootExt::GetLooterPetPathRejectShortcut());
        DCAoELootExt::SetLooterPetPathRejectShortcut(next);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Path shortcut reject: {}",
            next ? "On" : "Off");
        return true;
    }

    static bool HandleStatus(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        auto it = sLooterPetStates.find(player->GetGUID());
        bool const enabled = it != sLooterPetStates.end() && it->second.enabled;
        bool const aoeEnabled = DCAoELootExt::IsPlayerAoELootEnabled(player->GetGUID());
        bool const goldOnly = DCAoELootExt::GetPlayerGoldOnly(player->GetGUID());
        uint8 const minQuality = DCAoELootExt::GetPlayerMinQuality(player->GetGUID());
        bool const pathfindingEnabled = DCAoELootExt::GetLooterPetPathfindingEnabled();
        bool const allowIncomplete = DCAoELootExt::GetLooterPetPathAllowIncomplete();
        bool const rejectShortcut = DCAoELootExt::GetLooterPetPathRejectShortcut();
        float const maxPathLength = DCAoELootExt::GetLooterPetPathMaxLength();
        uint32 const maxPathChecks = DCAoELootExt::GetLooterPetPathMaxChecks();
        bool const moveMapsEnabled = sConfigMgr->GetOption<bool>("MoveMaps.Enable", false);
        Unit* companion = GetActiveLooterCompanion(player);

        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r State: {}",
            enabled ? "Enabled" : "Disabled");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r AoE Loot: {}",
            aoeEnabled ? "Enabled" : "Disabled");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Mode: companion bound");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Companion: {}",
            companion ? companion->GetName() : "None");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Pulse: {} ms",
            sLooterPetConfig.pulseMs);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Combat: Paused (autonomous only)");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Gold-Only: {}",
            goldOnly ? "On" : "Off");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Min Quality: {}",
            minQuality);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Fallback anchor: {}",
            sLooterPetConfig.fallbackToPlayerAnchor ? "Player" : "Off");
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Companion leash: {} ({:.1f} yd)",
            sLooterPetConfig.companionLeashEnable ? "On" : "Off",
            sLooterPetConfig.companionMaxDistance);
        handler->PSendSysMessage(
            "|cff00ff00[Looter Pet]|r Pathfinding: {} (checks={}, maxLen={:.1f})",
            pathfindingEnabled ? "On" : "Off",
            maxPathChecks,
            maxPathLength);

        if (pathfindingEnabled)
        {
            handler->PSendSysMessage(
                "|cff00ff00[Looter Pet]|r Path rules: incomplete={}, shortcutReject={}",
                allowIncomplete ? "On" : "Off",
                rejectShortcut ? "On" : "Off");
        }

        if (!aoeEnabled)
            handler->SendSysMessage("|cffff9900[Looter Pet]|r AoE Loot is disabled. Enable with .lp enable");

        if (player->IsInCombat())
            handler->SendSysMessage("|cffff9900[Looter Pet]|r Pulse currently paused while in combat.");

        if (pathfindingEnabled && !moveMapsEnabled)
            handler->SendSysMessage("|cffff9900[Looter Pet]|r MoveMaps.Enable is off; pathfinding quality may be reduced.");

        if (enabled && !companion)
            handler->SendSysMessage("|cffff9900[Looter Pet]|r No active companion currently bound.");

        if (enabled)
            handler->SendSysMessage("|cffff9900[Looter Pet]|r Gold has no minimum threshold; any gold on eligible corpses is looted.");

        return true;
    }

    static bool HandleReload(ChatHandler* handler)
    {
        DCAoELootExt::ReloadAoELootConfig();
        sLooterPetConfig.Load();
        handler->SendSysMessage("Looter Pet and AoE config reloaded.");
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
