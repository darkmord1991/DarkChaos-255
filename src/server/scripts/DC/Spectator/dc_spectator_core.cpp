/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Unified Spectator Core - Implementation
 */

#include "dc_spectator_core.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Opcodes.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>
#include <atomic>
#include <functional>
#include <mutex>
#include <unordered_set>
#include "dc_update_profiler.h"

namespace DCSpectator
{

namespace
{
    constexpr uint32 PUSH_INTERVAL_MS = 1000;
    constexpr uint32 PUSH_HEARTBEAT_MS = 5000;

    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_LIVE_SNAPSHOT = ::CMSG_REQUEST_SPECTATOR_LIVE_SNAPSHOT,
            SMSG_LIVE_SNAPSHOT = ::SMSG_SPECTATOR_LIVE_SNAPSHOT,
        };
    }

    DCAddon::TransportPolicyDecision ResolveLiveTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "spectator-live";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::SPECTATOR_LIVE_NATIVE;
        return DCAddon::ResolveTransportPolicy(player, request);
    }

    void SendNativeSnapshot(Player* spectator, std::string const& encoded)
    {
        if (!spectator || !spectator->GetSession() || encoded.empty())
            return;

        WorldPacket data(BridgeOpcode::SMSG_LIVE_SNAPSHOT, encoded.size() + 1);
        data << encoded;
        spectator->GetSession()->SendPacket(&data);
        std::string preview = "bytes=" + std::to_string(encoded.size());
        DCAddon::LogNativeS2CMessage(spectator, DCAddon::Module::SPECTATOR,
            0, BridgeOpcode::SMSG_LIVE_SNAPSHOT, data.size(), preview, true,
            0);
    }

    void SendAddonSnapshot(Player* spectator,
        DCAddon::JsonValue const& payload)
    {
        if (!spectator)
            return;

        DCAddon::JsonMessage(DCAddon::Module::GROUP_FINDER,
            DCAddon::Opcode::GroupFinder::SMSG_SPECTATE_DATA, payload)
            .Send(spectator);
    }

    // Players whose spectator flag the core keeps applied. Guarded: the zone
    // hook that re-applies it runs on map threads as well as the world thread.
    std::mutex sFlagHoldersMutex;
    std::unordered_set<ObjectGuid> sFlagHolders;
    std::atomic<uint32> sFlagHolderCount{0};

    bool IsFlagHolder(ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(sFlagHoldersMutex);
        return sFlagHolders.find(guid) != sFlagHolders.end();
    }

    void ForgetFlagHolder(ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(sFlagHoldersMutex);
        if (sFlagHolders.erase(guid))
            --sFlagHolderCount;
    }
}

void HoldSpectatorFlag(Player* spectator)
{
    if (!spectator)
        return;

    {
        std::lock_guard<std::mutex> lock(sFlagHoldersMutex);
        if (sFlagHolders.insert(spectator->GetGUID()).second)
            ++sFlagHolderCount;
    }

    if (!spectator->IsSpectator())
        spectator->SetIsSpectator(true);
}

void ReleaseSpectatorFlag(Player* spectator)
{
    if (!spectator)
        return;

    ForgetFlagHolder(spectator->GetGUID());

    if (spectator->IsSpectator())
        spectator->SetIsSpectator(false);
}

bool IsHoldingSpectatorFlag(Player const* player)
{
    if (!player || sFlagHolderCount.load(std::memory_order_relaxed) == 0)
        return false;

    return IsFlagHolder(player->GetGUID());
}

char const* SystemName(SystemId id)
{
    switch (id)
    {
        case SystemId::MythicPlus: return "mplus";
        case SystemId::Duel: return "duel";
        case SystemId::HLBG: return "hlbg";
    }
    return "unknown";
}

bool ParseSystemName(std::string const& name, SystemId& out)
{
    for (SystemId id : { SystemId::MythicPlus, SystemId::Duel, SystemId::HLBG })
    {
        if (name == SystemName(id))
        {
            out = id;
            return true;
        }
    }

    return false;
}

void NotifySessionStarted(Player* spectator, SystemId id, uint32 sessionId,
    std::string const& message)
{
    if (!spectator || !spectator->GetSession())
        return;

    DCAddon::JsonMessage(DCAddon::Module::GROUP_FINDER,
        DCAddon::Opcode::GroupFinder::SMSG_SPECTATE_STARTED)
        .Set("success", true)
        .Set("system", std::string(SystemName(id)))
        .Set("id", static_cast<int32>(sessionId))
        .Set("runId", static_cast<int32>(sessionId))
        .Set("message", message)
        .Send(spectator);
}

void NotifySessionEnded(Player* spectator, SystemId id,
    std::string const& message)
{
    if (!spectator || !spectator->GetSession()
        || spectator->GetSession()->PlayerLogout())
        return;

    DCAddon::JsonMessage(DCAddon::Module::GROUP_FINDER,
        DCAddon::Opcode::GroupFinder::SMSG_SPECTATE_ENDED)
        .Set("success", true)
        .Set("system", std::string(SystemName(id)))
        .Set("message", message)
        .Send(spectator);
}

void SendSnapshotPayload(Player* spectator, DCAddon::JsonValue const& payload,
    std::string const* preEncoded)
{
    if (!spectator)
        return;

    if (ResolveLiveTransport(spectator).UsesNative())
    {
        SendNativeSnapshot(spectator, preEncoded ? *preEncoded : payload.Encode());
        return;
    }

    SendAddonSnapshot(spectator, payload);
}

Registry& Registry::Get()
{
    static Registry instance;
    return instance;
}

void Registry::RegisterContext(ISpectatableContext* context)
{
    if (!context)
        return;

    _contexts.push_back(context);
    LOG_INFO("scripts.dc", "SpectatorCore: Registered context '{}'",
        SystemName(context->GetSystemId()));
}

ISpectatableContext* Registry::FindContextFor(ObjectGuid guid) const
{
    for (ISpectatableContext* context : _contexts)
        if (context->IsSpectating(guid))
            return context;

    return nullptr;
}

ISpectatableContext* Registry::FindContext(SystemId id) const
{
    for (ISpectatableContext* context : _contexts)
        if (context->GetSystemId() == id)
            return context;

    return nullptr;
}

bool Registry::IsSpectating(ObjectGuid guid) const
{
    return FindContextFor(guid) != nullptr;
}

DCAddon::JsonValue Registry::BuildListings(Player* viewer) const
{
    DCAddon::JsonValue listings;
    listings.SetArray();

    for (ISpectatableContext* context : _contexts)
        context->AppendListings(viewer, listings);

    return listings;
}

bool Registry::StartById(Player* player, SystemId id, uint32 sessionId,
    std::string& error)
{
    ISpectatableContext* context = FindContext(id);
    if (!context)
    {
        error = "That spectator system is not available.";
        return false;
    }

    // One session at a time across all systems: each system's own checks
    // only see its own sessions.
    if (player && IsSpectating(player->GetGUID()))
    {
        error = "You are already spectating. Leave first.";
        return false;
    }

    return context->StartById(player, sessionId, error);
}

void Registry::StopAll(Player* player)
{
    if (!player)
        return;

    for (ISpectatableContext* context : _contexts)
        if (context->IsSpectating(player->GetGUID()))
            context->StopSpectating(player);

    _pushState.erase(player->GetGUID());
}

bool Registry::SendLiveSnapshot(Player* spectator)
{
    if (!spectator)
        return false;

    ISpectatableContext* context = FindContextFor(spectator->GetGUID());
    if (!context)
        return false;

    DCAddon::JsonValue payload;
    if (!context->BuildLiveSnapshot(spectator, payload))
        return false;

    SendSnapshotPayload(spectator, payload);
    return true;
}

void Registry::Update(uint32 diff)
{
    _pushTimer += diff;
    if (_pushTimer < PUSH_INTERVAL_MS)
        return;

    uint32 const elapsed = _pushTimer;
    _pushTimer = 0;

    std::vector<ObjectGuid> active;
    for (ISpectatableContext* context : _contexts)
    {
        if (!context->WantsPeriodicPush())
            continue;

        std::vector<ObjectGuid> spectators;
        context->CollectSpectators(spectators);
        for (ObjectGuid guid : spectators)
        {
            active.push_back(guid);

            Player* spectator = ObjectAccessor::FindConnectedPlayer(guid);
            if (!spectator || !spectator->IsInWorld())
                continue;

            DCAddon::JsonValue payload;
            if (!context->BuildLiveSnapshot(spectator, payload))
                continue;

            std::string encoded = payload.Encode();
            size_t const hash = std::hash<std::string>{}(encoded);

            PushState& state = _pushState[guid];
            state.msSincePush += elapsed;
            if (hash == state.lastHash
                && state.msSincePush < PUSH_HEARTBEAT_MS)
                continue;

            state.lastHash = hash;
            state.msSincePush = 0;
            // Reuse the encoding computed for the hash above.
            SendSnapshotPayload(spectator, payload, &encoded);
        }
    }

    // Drop change-gating state for players no longer spectating.
    std::unordered_set<ObjectGuid> activeSet(active.begin(), active.end());
    for (auto it = _pushState.begin(); it != _pushState.end();)
    {
        bool const stillActive = activeSet.find(it->first) != activeSet.end();
        if (!stillActive && !IsSpectating(it->first))
            it = _pushState.erase(it);
        else
            ++it;
    }
}

namespace
{
    class DCSpectatorCorePlayerScript : public PlayerScript
    {
    public:
        DCSpectatorCorePlayerScript()
            : PlayerScript("DCSpectatorCorePlayerScript",
                { PLAYERHOOK_ON_BEFORE_LOGOUT, PLAYERHOOK_ON_UPDATE_ZONE }) { }

        // Before, not on, logout: WorldSession::LogoutPlayer calls
        // LeaveBattleground right after this hook. A Hinterland spectator
        // carries the match's battleground id without being a participant,
        // and leaving it there would run the core's deserter tracking and
        // entry-point teleport against a match the player never joined.
        void OnPlayerBeforeLogout(Player* player) override
        {
            sSpectatorRegistry.StopAll(player);
            if (player)
                ForgetFlagHolder(player->GetGUID());
        }

        // The worldport ack clears the spectator flag on every port to a
        // non-arena map. SendInitialPacketsAfterAddToMap then calls UpdateZone,
        // the first point after arrival at which the flag sticks.
        void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/,
            uint32 /*newArea*/) override
        {
            if (!player || player->IsSpectator()
                || sFlagHolderCount.load(std::memory_order_relaxed) == 0)
                return;

            if (IsFlagHolder(player->GetGUID()))
                player->SetIsSpectator(true);
        }
    };

    class DCSpectatorCoreWorldScript : public WorldScript
    {
    public:
        DCSpectatorCoreWorldScript()
            : WorldScript("DCSpectatorCoreWorldScript") { }

        void OnUpdate(uint32 diff) override
        {
            DarkChaos::ScopedUpdateProfiler _prof("SpectatorCore");
            sSpectatorRegistry.Update(diff);
        }
    };

    class DCSpectatorCoreNativeServerScript : public ServerScript
    {
    public:
        DCSpectatorCoreNativeServerScript()
            : ServerScript("DCSpectatorCoreNativeServerScript",
                { SERVERHOOK_CAN_PACKET_RECEIVE })
        {
        }

    private:
        bool CanPacketReceive(WorldSession* session,
            WorldPacket const& packet) override
        {
            if (packet.GetOpcode() != BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT)
                return true;

            if (!session)
                return false;

            Player* player = session->GetPlayer();
            if (!player || !player->IsInWorld())
                return false;

            if (!ResolveLiveTransport(player).UsesNative())
            {
                DCAddon::AuditNativeC2SRequest(player,
                    DCAddon::Module::SPECTATOR, 0,
                    BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT,
                    packet.size(), "request", false,
                    "Native spectator live snapshot unavailable",
                    "native_transport_denied",
                    "Native spectator live snapshot request rejected");
                return false;
            }

            if (sSpectatorRegistry.SendLiveSnapshot(player))
            {
                DCAddon::AuditNativeC2SRequest(player,
                    DCAddon::Module::SPECTATOR, 0,
                    BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT,
                    packet.size(), "request", true);
            }
            else
            {
                DCAddon::LogNativeC2SMessageWithStatus(player,
                    DCAddon::Module::SPECTATOR, 0,
                    BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT,
                    packet.size(), "request|outside-session", "ignored",
                    "Native spectator live snapshot requested without active "
                    "spectator session",
                    false);
            }
            return false;
        }
    };
}

} // namespace DCSpectator

void AddSC_dc_spectator_core()
{
    new DCSpectator::DCSpectatorCorePlayerScript();
    new DCSpectator::DCSpectatorCoreWorldScript();
    new DCSpectator::DCSpectatorCoreNativeServerScript();
}
