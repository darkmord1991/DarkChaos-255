/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Hinterland BG spectating - Implementation
 *
 * Visibility mirrors the M+ spectator: GM-invisible, never a participant.
 * Placement follows the core arena spectator (ArenaSpectator.cpp): the
 * spectator carries the match's battleground id with no team and no invite.
 *   - A battleground map is only created for a player whose battleground id
 *     names it (MapInstanced::CreateInstanceForPlayer). Without the id the
 *     worldport ack cannot create the map and ports the player to homebind.
 *   - Not being invited, the worldport ack never adds them to the match.
 *   - They hold the core spectator flag (DCSpectator::HoldSpectatorFlag),
 *     which refuses their spell casts and attacks.
 * Live HUD data reuses the HLBG native snapshot builder via
 * DCAddon::HLBG::BuildSpectatorLiveSnapshot and is pushed by the unified
 * spectator core (change-gated + heartbeat).
 */

#include "dc_hlbg_spectator.h"
#include "BattlegroundHLBG.h"
#include "BattlegroundMgr.h"
#include "Chat.h"
#include "GameTime.h"
#include "HLBGService.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Opcodes.h"
#include "Player.h"
#include "Position.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "DC/AddonExtension/dc_addon_hlbg.h"
#include "DC/Spectator/dc_spectator_core.h"

#include <mutex>
#include <unordered_map>
#include <vector>
#include "dc_update_profiler.h"

namespace DCHLBGSpectator
{

namespace
{
    constexpr uint32 SESSION_CHECK_INTERVAL_MS = 1000;
    // A session whose teleport never reached the match is dropped after this.
    constexpr uint64 ARRIVAL_TIMEOUT_SECONDS = 30;

    struct SpectatorSession
    {
        uint32 bgInstanceId = 0;
        uint32 savedMapId = 0;
        Position savedPosition;
        uint64 startedAt = 0;
        bool arrived = false;
        // Stop asked for mid-teleport; finished by the session check once the
        // player has landed (see StopSpectating).
        bool stopRequested = false;
    };

    // Guarded: the native live-snapshot request reaches the spectator core
    // from the packet path, and the zone hook runs on map threads.
    std::mutex sSessionsMutex;
    std::unordered_map<ObjectGuid, SpectatorSession> sSessions;

    BattlegroundHLBG* FindMatch(uint32 instanceId)
    {
        Battleground* battleground = sBattlegroundMgr->GetBattleground(instanceId,
            BATTLEGROUND_TYPE_NONE);
        if (!battleground || battleground->GetBgTypeID(true) != BATTLEGROUND_HLBG)
            return nullptr;

        return dynamic_cast<BattlegroundHLBG*>(battleground);
    }

    bool IsWatchable(Battleground const* bg)
    {
        return bg && (bg->GetStatus() == STATUS_WAIT_JOIN
            || bg->GetStatus() == STATUS_IN_PROGRESS);
    }

    bool IsOnMatchMap(Player* player, uint32 bgInstanceId)
    {
        Map* map = player ? player->FindMap() : nullptr;
        return map && map->IsBattlegroundOrArena()
            && map->GetInstanceId() == bgInstanceId;
    }

    // A participant already standing on the match map; the living ones first.
    Player* FindParticipantOnMap(BattlegroundHLBG* bg)
    {
        Player* fallback = nullptr;
        for (auto const& [guid, bgPlayer] : bg->GetPlayers())
        {
            (void)guid;
            if (!bgPlayer || !bgPlayer->IsInWorld()
                || !IsOnMatchMap(bgPlayer, bg->GetInstanceID()))
                continue;

            if (bgPlayer->IsAlive())
                return bgPlayer;

            if (!fallback)
                fallback = bgPlayer;
        }

        return fallback;
    }

    uint32 CountSpectators(uint32 bgInstanceId)
    {
        std::lock_guard<std::mutex> lock(sSessionsMutex);
        uint32 count = 0;
        for (auto const& [guid, session] : sSessions)
        {
            (void)guid;
            if (session.bgInstanceId == bgInstanceId)
                ++count;
        }

        return count;
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

        // The spectator flag's attack check covers the player, not their pet.
        if (!player->m_Controlled.empty())
        {
            error = "Dismiss your pet before spectating.";
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

    void DetachFromMatch(Player* player, uint32 bgInstanceId)
    {
        DCSpectator::ReleaseSpectatorFlag(player);

        if (player->GetBattlegroundId() == bgInstanceId)
        {
            player->SetBattlegroundId(0, BATTLEGROUND_TYPE_NONE,
                PLAYER_MAX_BATTLEGROUND_QUEUES, false, false, TEAM_NEUTRAL);
        }

        player->SetGameMaster(false);
        player->SetGMVisible(true);
    }

    bool EndSession(Player* player, std::string const& reason)
    {
        if (!player)
            return false;

        SpectatorSession session;
        {
            std::lock_guard<std::mutex> lock(sSessionsMutex);
            auto it = sSessions.find(player->GetGUID());
            if (it == sSessions.end())
                return false;

            session = it->second;
            sSessions.erase(it);
        }

        bool const onMatchMap = IsOnMatchMap(player, session.bgInstanceId);
        bool const loggingOut = !player->GetSession()
            || player->GetSession()->PlayerLogout();

        // Clear the battleground id before anything else: a logout with it
        // still set runs LeaveBattleground (deserter tracking) against a match
        // the player never joined.
        DetachFromMatch(player, session.bgInstanceId);

        // Only port back from the match map itself. When the match closed,
        // BattlegroundMap::RemoveAllPlayers has already sent the spectator to
        // the entry point; on logout the character is saved on a battleground
        // map, and login places it at that entry point (SetEntryPoint).
        if (onMatchMap && !loggingOut)
        {
            player->TeleportTo(session.savedMapId,
                session.savedPosition.GetPositionX(),
                session.savedPosition.GetPositionY(),
                session.savedPosition.GetPositionZ(),
                session.savedPosition.GetOrientation());
        }

        if (!loggingOut)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ff00[HLBG Spectator]|r {}",
                reason.empty() ? std::string("You have stopped spectating.") : reason);
        }

        DCSpectator::NotifySessionEnded(player, DCSpectator::SystemId::HLBG,
            reason.empty() ? std::string("Stopped spectating.") : reason);

        LOG_DEBUG("scripts.dc", "HLBGSpectator: {} stopped spectating match {}",
            player->GetName(), session.bgInstanceId);
        return true;
    }

    // Record that the spectator has stood on the match map; separates "left
    // the battleground" from "never arrived" in the session check.
    void MarkArrived(Player* player)
    {
        std::lock_guard<std::mutex> lock(sSessionsMutex);
        auto it = sSessions.find(player->GetGUID());
        if (it != sSessions.end() && IsOnMatchMap(player, it->second.bgInstanceId))
            it->second.arrived = true;
    }
}

bool IsSpectating(ObjectGuid guid)
{
    std::lock_guard<std::mutex> lock(sSessionsMutex);
    return sSessions.find(guid) != sSessions.end();
}

bool StartSpectating(Player* player, uint32 instanceId, std::string& error)
{
    if (!CanSpectate(player, error))
        return false;

    BattlegroundHLBG* bg = instanceId ? FindMatch(instanceId)
        : HLBGService::Instance().GetActiveBattleground(nullptr);
    if (!IsWatchable(bg))
    {
        error = instanceId
            ? "That Hinterland battleground is no longer running."
            : "No Hinterland battleground is currently running.";
        return false;
    }

    Player* target = FindParticipantOnMap(bg);
    if (!target)
    {
        error = "No players have entered the battleground yet.";
        return false;
    }

    SpectatorSession session;
    session.bgInstanceId = bg->GetInstanceID();
    session.savedMapId = player->GetMapId();
    session.savedPosition = Position(player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation());
    session.startedAt = static_cast<uint64>(GameTime::GetGameTime().count());

    player->SetGameMaster(true);
    player->SetGMVisible(false);
    // No team and not invited: the worldport ack adds only invited players to
    // the match, so this admits the spectator to the map and nothing else.
    player->SetBattlegroundId(bg->GetInstanceID(), bg->GetBgTypeID(),
        PLAYER_MAX_BATTLEGROUND_QUEUES, false, false, TEAM_NEUTRAL);
    player->SetEntryPoint();

    // TELE_TO_GM_MODE skips PlayerCannotEnter, as the core arena spectator does.
    if (!player->TeleportTo(target->GetMapId(), target->GetPositionX(),
            target->GetPositionY(), target->GetPositionZ() + 0.25f,
            target->GetOrientation(), TELE_TO_GM_MODE))
    {
        DetachFromMatch(player, session.bgInstanceId);
        error = "Could not teleport you to the battleground.";
        return false;
    }

    // Only after the teleport was accepted: TeleportTo refuses a flagged player.
    DCSpectator::HoldSpectatorFlag(player);

    {
        std::lock_guard<std::mutex> lock(sSessionsMutex);
        sSessions[player->GetGUID()] = session;
    }

    ChatHandler(player->GetSession()).SendSysMessage(
        "|cff00ff00[HLBG Spectator]|r Now spectating the Hinterland "
        "battleground. Use |cffffd700.hlbg spectate leave|r to stop.");
    DCSpectator::NotifySessionStarted(player, DCSpectator::SystemId::HLBG,
        session.bgInstanceId, "Now spectating the Hinterland battleground.");

    LOG_INFO("scripts.dc", "HLBGSpectator: {} started spectating match {}",
        player->GetName(), session.bgInstanceId);
    return true;
}

bool StopSpectating(Player* player)
{
    if (!player)
        return false;

    // Mid-teleport the player has not reached either map yet: clearing the
    // battleground id now would make the pending worldport ack fail and port
    // them home. Finish once they have landed. A logout never gets here in
    // transit, because LogoutPlayer completes pending transfers first.
    if (player->IsBeingTeleportedFar())
    {
        std::lock_guard<std::mutex> lock(sSessionsMutex);
        auto it = sSessions.find(player->GetGUID());
        if (it == sSessions.end())
            return false;

        it->second.stopRequested = true;
        return true;
    }

    return EndSession(player, std::string());
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
            uint32 bgInstanceId = 0;
            {
                std::lock_guard<std::mutex> lock(sSessionsMutex);
                auto it = sSessions.find(spectator->GetGUID());
                if (it == sSessions.end())
                    return false;

                bgInstanceId = it->second.bgInstanceId;
            }

            if (!DCAddon::HLBG::BuildSpectatorLiveSnapshot(spectator, payload))
                return false;

            payload.Set("system", std::string(DCSpectator::SystemName(
                DCSpectator::SystemId::HLBG)));
            payload.Set("id", static_cast<int32>(bgInstanceId));
            payload.Set("spectators",
                static_cast<int32>(CountSpectators(bgInstanceId)));
            return true;
        }

        bool WantsPeriodicPush() const override { return true; }

        void CollectSpectators(std::vector<ObjectGuid>& out) const override
        {
            std::lock_guard<std::mutex> lock(sSessionsMutex);
            for (auto const& [guid, session] : sSessions)
            {
                (void)session;
                out.push_back(guid);
            }
        }

        void AppendListings(Player* /*viewer*/,
            DCAddon::JsonValue& out) const override
        {
            for (Battleground const* battleground :
                    sBattlegroundMgr->GetActiveBattlegrounds())
            {
                if (!battleground
                    || battleground->GetBgTypeID(true) != BATTLEGROUND_HLBG)
                    continue;

                auto const* bg = dynamic_cast<BattlegroundHLBG const*>(battleground);
                if (!IsWatchable(bg))
                    continue;

                uint32 alliancePlayers = 0;
                uint32 hordePlayers = 0;
                for (auto const& [guid, bgPlayer] : bg->GetPlayers())
                {
                    (void)guid;
                    if (!bgPlayer)
                        continue;

                    if (bgPlayer->GetBgTeamId() == TEAM_ALLIANCE)
                        ++alliancePlayers;
                    else if (bgPlayer->GetBgTeamId() == TEAM_HORDE)
                        ++hordePlayers;
                }

                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("system", std::string(DCSpectator::SystemName(
                    DCSpectator::SystemId::HLBG)));
                entry.Set("id", static_cast<int32>(bg->GetInstanceID()));
                entry.Set("name", std::string("Hinterland Battleground"));
                entry.Set("status", std::string(
                    bg->GetStatus() == STATUS_WAIT_JOIN ? "warmup" : "in_progress"));
                entry.Set("timeRemaining",
                    static_cast<int32>(bg->GetTimeRemainingSeconds()));
                entry.Set("allianceResources",
                    static_cast<int32>(bg->GetResources(TEAM_ALLIANCE)));
                entry.Set("hordeResources",
                    static_cast<int32>(bg->GetResources(TEAM_HORDE)));
                entry.Set("alliancePlayers", static_cast<int32>(alliancePlayers));
                entry.Set("hordePlayers", static_cast<int32>(hordePlayers));
                entry.Set("spectators",
                    static_cast<int32>(CountSpectators(bg->GetInstanceID())));
                out.Push(std::move(entry));
            }
        }

        bool StartById(Player* player, uint32 id, std::string& error) override
        {
            return DCHLBGSpectator::StartSpectating(player, id, error);
        }
    };

    // Ends sessions whose match is over, whose spectator left the map or never
    // arrived, or whose player vanished without a logout event.
    class HLBGSpectatorWorldScript : public WorldScript
    {
    public:
        HLBGSpectatorWorldScript()
            : WorldScript("HLBGSpectatorWorldScript") { }

        void OnUpdate(uint32 diff) override
        {
            DarkChaos::ScopedUpdateProfiler _prof("HLBGSpectator");
            _timer += diff;
            if (_timer < SESSION_CHECK_INTERVAL_MS)
                return;
            _timer = 0;

            std::vector<ObjectGuid> guids;
            {
                std::lock_guard<std::mutex> lock(sSessionsMutex);
                guids.reserve(sSessions.size());
                for (auto const& [guid, session] : sSessions)
                {
                    (void)session;
                    guids.push_back(guid);
                }
            }

            uint64 const now = static_cast<uint64>(GameTime::GetGameTime().count());
            for (ObjectGuid guid : guids)
            {
                Player* spectator = ObjectAccessor::FindConnectedPlayer(guid);
                if (!spectator)
                {
                    std::lock_guard<std::mutex> lock(sSessionsMutex);
                    sSessions.erase(guid);
                    LOG_DEBUG("scripts.dc",
                        "HLBGSpectator: Cleaned up orphaned spectator {}",
                        guid.ToString());
                    continue;
                }

                if (spectator->IsBeingTeleportedFar() || !spectator->IsInWorld())
                    continue;

                MarkArrived(spectator);

                SpectatorSession session;
                {
                    std::lock_guard<std::mutex> lock(sSessionsMutex);
                    auto it = sSessions.find(guid);
                    if (it == sSessions.end())
                        continue;

                    session = it->second;
                }

                if (session.stopRequested)
                {
                    EndSession(spectator, std::string());
                    continue;
                }

                Battleground const* bg = sBattlegroundMgr->GetBattleground(
                    session.bgInstanceId, BATTLEGROUND_TYPE_NONE);
                if (!bg || bg->GetStatus() >= STATUS_WAIT_LEAVE)
                {
                    EndSession(spectator, "The battleground has ended.");
                    continue;
                }

                if (IsOnMatchMap(spectator, session.bgInstanceId))
                    continue;

                if (session.arrived)
                    EndSession(spectator, "You left the battleground.");
                else if (now > session.startedAt + ARRIVAL_TIMEOUT_SECONDS)
                    EndSession(spectator, "Could not reach the battleground.");
            }
        }

    private:
        uint32 _timer = 0;
    };

    // The client's "Leave Battleground" button sends CMSG_LEAVE_BATTLEFIELD.
    // The spectator carries the match's battleground id, so the core handler
    // would record them as a deserter of a match they never joined and port
    // them to the entry point on its own. Turn the button into a normal stop
    // instead. The opcode is thread-unsafe, so this runs on the world thread
    // like the ".hlbg spectate leave" command.
    class HLBGSpectatorServerScript : public ServerScript
    {
    public:
        HLBGSpectatorServerScript()
            : ServerScript("HLBGSpectatorServerScript", { SERVERHOOK_CAN_PACKET_RECEIVE }) { }

    private:
        bool CanPacketReceive(WorldSession* session, WorldPacket const& packet) override
        {
            if (packet.GetOpcode() != CMSG_LEAVE_BATTLEFIELD || !session)
                return true;

            Player* player = session->GetPlayer();
            if (!player || !IsSpectating(player->GetGUID()))
                return true;

            StopSpectating(player);
            return false;
        }
    };
}

} // namespace DCHLBGSpectator

void AddSC_dc_hlbg_spectator()
{
    new DCHLBGSpectator::HLBGSpectatorWorldScript();
    new DCHLBGSpectator::HLBGSpectatorServerScript();

    static DCHLBGSpectator::HLBGSpectatableContext hlbgSpectatorContext;
    DCSpectator::Registry::Get().RegisterContext(&hlbgSpectatorContext);
}
