/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Hinterland BG spectating - Implementation
 * Visibility strategy mirrors the M+ spectator: the spectator is made
 * GM-invisible and teleported next to a live participant; they never join
 * the battleground itself. Live HUD data reuses the HLBG native snapshot
 * builder via DCAddon::HLBG::BuildSpectatorLiveSnapshot and is pushed by
 * the unified spectator core (change-gated + heartbeat).
 */

#include "dc_hlbg_spectator.h"
#include "BattlegroundHLBG.h"
#include "Chat.h"
#include "HLBGService.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Position.h"
#include "ScriptMgr.h"
#include "../AddonExtension/dc_addon_hlbg.h"
#include "../Spectator/dc_spectator_core.h"

#include <unordered_map>

namespace DCHLBGSpectator
{

namespace
{
    constexpr uint32 SESSION_CHECK_INTERVAL_MS = 2000;

    struct SpectatorSession
    {
        uint32 savedMapId = 0;
        Position savedPosition;
    };

    // World-thread only (same access model as the M+ spectator manager).
    std::unordered_map<ObjectGuid, SpectatorSession> sSessions;

    BattlegroundHLBG* GetActiveBg(Player* player)
    {
        return HLBGService::Instance().GetActiveBattleground(player);
    }

    bool CanSpectate(Player* player, std::string& error)
    {
        if (!player)
        {
            error = "Invalid player.";
            return false;
        }

        if (sSpectatorRegistry.IsSpectating(player->GetGUID()))
        {
            error = "You are already spectating.";
            return false;
        }

        if (player->IsBeingTeleported() || !player->IsInWorld())
        {
            error = "Can't spectate while being teleported.";
            return false;
        }

        if (player->InBattleground())
        {
            error = "Can't spectate while in a battleground.";
            return false;
        }

        if (player->InBattlegroundQueue())
        {
            error = "Can't spectate while queued for PvP.";
            return false;
        }

        if (player->FindMap() && player->FindMap()->Instanceable())
        {
            error = "Can't spectate while in an instance.";
            return false;
        }

        if (player->GetVehicle())
        {
            error = "Can't spectate while in a vehicle.";
            return false;
        }

        if (player->IsInCombat())
        {
            error = "Can't spectate while in combat.";
            return false;
        }

        if (player->GetGroup())
        {
            error = "Can't spectate while in a group.";
            return false;
        }

        if (!player->IsAlive())
        {
            error = "Must be alive to spectate.";
            return false;
        }

        if (player->IsMounted())
        {
            error = "Please dismount before spectating.";
            return false;
        }

        if (player->IsInFlight())
        {
            error = "Can't spectate while in flight.";
            return false;
        }

        return true;
    }
}

bool IsSpectating(ObjectGuid guid)
{
    return sSessions.find(guid) != sSessions.end();
}

bool StartSpectating(Player* player, std::string& error)
{
    if (!CanSpectate(player, error))
        return false;

    BattlegroundHLBG* bg = GetActiveBg(player);
    if (!bg)
    {
        error = "No Hinterland battleground is currently running.";
        return false;
    }

    Player* target = nullptr;
    for (auto const& [guid, bgPlayer] : bg->GetPlayers())
    {
        (void)guid;
        if (bgPlayer && bgPlayer->IsInWorld() && bgPlayer->IsAlive())
        {
            target = bgPlayer;
            break;
        }
    }

    if (!target)
    {
        error = "No active players found in the battleground.";
        return false;
    }

    SpectatorSession session;
    session.savedMapId = player->GetMapId();
    session.savedPosition = Position(player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation());
    sSessions[player->GetGUID()] = session;

    player->SetGameMaster(true);
    player->SetGMVisible(false);
    player->TeleportTo(target->GetMapId(), target->GetPositionX(),
        target->GetPositionY(), target->GetPositionZ() + 0.25f,
        target->GetOrientation());

    ChatHandler(player->GetSession()).SendSysMessage(
        "|cff00ff00[HLBG Spectator]|r Now spectating the Hinterland "
        "battleground. Use |cffffd700.hlbg spectate leave|r to stop.");

    LOG_INFO("scripts.dc", "HLBGSpectator: {} started spectating",
        player->GetName());
    return true;
}

bool StopSpectating(Player* player)
{
    if (!player)
        return false;

    auto it = sSessions.find(player->GetGUID());
    if (it == sSessions.end())
        return false;

    SpectatorSession const session = it->second;
    sSessions.erase(it);

    player->SetGameMaster(false);
    player->SetGMVisible(true);
    player->TeleportTo(session.savedMapId,
        session.savedPosition.GetPositionX(),
        session.savedPosition.GetPositionY(),
        session.savedPosition.GetPositionZ(),
        session.savedPosition.GetOrientation());

    if (player->GetSession())
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cff00ff00[HLBG Spectator]|r You have stopped spectating.");

    LOG_DEBUG("scripts.dc", "HLBGSpectator: {} stopped spectating",
        player->GetName());
    return true;
}

namespace
{
    class HLBGSpectatableContext : public DCSpectator::ISpectatableContext
    {
    public:
        DCSpectator::SystemId GetSystemId() const override
        {
            return DCSpectator::SystemId::HLBG;
        }

        bool IsSpectating(ObjectGuid guid) const override
        {
            return DCHLBGSpectator::IsSpectating(guid);
        }

        void StopSpectating(Player* player) override
        {
            DCHLBGSpectator::StopSpectating(player);
        }

        bool BuildLiveSnapshot(Player* spectator,
            DCAddon::JsonValue& payload) override
        {
            if (!DCAddon::HLBG::BuildSpectatorLiveSnapshot(spectator, payload))
                return false;

            payload.Set("system", std::string(DCSpectator::SystemName(
                DCSpectator::SystemId::HLBG)));
            payload.Set("spectators", static_cast<int32>(sSessions.size()));
            return true;
        }

        bool WantsPeriodicPush() const override { return true; }

        void CollectSpectators(std::vector<ObjectGuid>& out) const override
        {
            for (auto const& [guid, session] : sSessions)
            {
                (void)session;
                out.push_back(guid);
            }
        }
    };

    // Ends sessions whose match is over (the BG despawned) or whose player
    // vanished without a logout event.
    class HLBGSpectatorWorldScript : public WorldScript
    {
    public:
        HLBGSpectatorWorldScript()
            : WorldScript("HLBGSpectatorWorldScript") { }

        void OnUpdate(uint32 diff) override
        {
            _timer += diff;
            if (_timer < SESSION_CHECK_INTERVAL_MS)
                return;
            _timer = 0;

            std::vector<ObjectGuid> guids;
            guids.reserve(sSessions.size());
            for (auto const& [guid, session] : sSessions)
            {
                (void)session;
                guids.push_back(guid);
            }

            for (ObjectGuid guid : guids)
            {
                Player* spectator = ObjectAccessor::FindConnectedPlayer(guid);
                if (!spectator)
                {
                    sSessions.erase(guid);
                    LOG_DEBUG("scripts.dc",
                        "HLBGSpectator: Cleaned up orphaned spectator {}",
                        guid.ToString());
                    continue;
                }

                if (!GetActiveBg(spectator))
                {
                    StopSpectating(spectator);
                    ChatHandler(spectator->GetSession()).SendSysMessage(
                        "|cffffd700[HLBG Spectator]|r The battleground has "
                        "ended.");
                }
            }
        }

    private:
        uint32 _timer = 0;
    };
}

} // namespace DCHLBGSpectator

void AddSC_dc_hlbg_spectator()
{
    new DCHLBGSpectator::HLBGSpectatorWorldScript();

    static DCHLBGSpectator::HLBGSpectatableContext hlbgSpectatorContext;
    DCSpectator::Registry::Get().RegisterContext(&hlbgSpectatorContext);
}
