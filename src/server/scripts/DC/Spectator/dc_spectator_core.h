/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Unified Spectator Core
 * Shared registry and native live-snapshot transport for all DC spectator
 * systems (Mythic+, Phased Duels, Hinterland BG). Each system implements
 * ISpectatableContext and registers it here; the core owns the
 * CMSG/SMSG_SPECTATOR_LIVE_SNAPSHOT opcode pair, cross-system spectator
 * queries, logout cleanup, and change-gated periodic snapshot pushes.
 */

#ifndef DC_SPECTATOR_CORE_H
#define DC_SPECTATOR_CORE_H

#include "ObjectGuid.h"
#include "../AddonExtension/dc_addon_namespace.h"

#include <unordered_map>
#include <vector>

class Player;

namespace DCSpectator
{
    enum class SystemId : uint8
    {
        MythicPlus = 0,
        Duel = 1,
        HLBG = 2
    };

    char const* SystemName(SystemId id);

    // Implemented by each spectatable system. Placement and visibility
    // strategy (GM-invisible vs phase shift) stay inside the system; the
    // core only needs membership queries, snapshot building, and a way to
    // stop a session.
    class ISpectatableContext
    {
    public:
        virtual ~ISpectatableContext() = default;

        virtual SystemId GetSystemId() const = 0;
        virtual bool IsSpectating(ObjectGuid guid) const = 0;
        virtual void StopSpectating(Player* player) = 0;

        // Fill payload for the session this player is spectating. The
        // payload must include a "system" field (see SystemName).
        virtual bool BuildLiveSnapshot(Player* spectator,
            DCAddon::JsonValue& payload) = 0;

        // Opt into the core push loop (change-gated + heartbeat). Systems
        // that already broadcast their own updates (Mythic+) leave this off.
        virtual bool WantsPeriodicPush() const { return false; }
        virtual void CollectSpectators(std::vector<ObjectGuid>& /*out*/) const { }
    };

    // Send a snapshot payload over the negotiated transport: native
    // SMSG_SPECTATOR_LIVE_SNAPSHOT when the client capability allows it,
    // addon-channel JSON fallback otherwise.
    void SendSnapshotPayload(Player* spectator,
        DCAddon::JsonValue const& payload);

    class Registry
    {
    public:
        static Registry& Get();

        void RegisterContext(ISpectatableContext* context);

        ISpectatableContext* FindContextFor(ObjectGuid guid) const;
        bool IsSpectating(ObjectGuid guid) const;

        // Stop every active session for this player (logout/cleanup path).
        void StopAll(Player* player);

        // Build + send a snapshot for whatever the player is spectating.
        bool SendLiveSnapshot(Player* spectator);

        // Drives the change-gated push loop for contexts that opted in.
        void Update(uint32 diff);

    private:
        Registry() = default;

        struct PushState
        {
            size_t lastHash = 0;
            uint32 msSincePush = 0;
        };

        std::vector<ISpectatableContext*> _contexts;
        std::unordered_map<ObjectGuid, PushState> _pushState;
        uint32 _pushTimer = 0;
    };

    #define sSpectatorRegistry DCSpectator::Registry::Get()

} // namespace DCSpectator

#endif // DC_SPECTATOR_CORE_H
