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
#include "DC/AddonExtension/dc_addon_namespace.h"

#include <string>
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
    bool ParseSystemName(std::string const& name, SystemId& out);

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

        // Unified live list (Group Finder "Live" view): push one object per
        // watchable session onto `out`, each carrying "system" and "id" (the
        // value StartById takes). Mythic+ keeps its own richer "runs" list
        // and leaves this empty.
        virtual void AppendListings(Player* /*viewer*/, DCAddon::JsonValue& /*out*/) const { }

        // Start watching session `id`; 0 lets the system pick where that is
        // meaningful. On failure `error` is a player-facing reason.
        virtual bool StartById(Player* /*player*/, uint32 /*id*/, std::string& error)
        {
            error = "That system cannot be spectated from the live list.";
            return false;
        }
    };

    // Client notifications shared by every system, so the spectator bar opens
    // and closes no matter which entry point (chat command, addon request,
    // match end) started or ended the session. NotifySessionEnded is a no-op
    // while the player is logging out.
    void NotifySessionStarted(Player* spectator, SystemId id, uint32 sessionId,
        std::string const& message);
    void NotifySessionEnded(Player* spectator, SystemId id,
        std::string const& message);

    // A spectator must not act on what they watch. The core's arena-spectator
    // flag (Player::SetIsSpectator) is what makes Spell::CheckCast refuse
    // every cast except bind sight and Unit::_IsValidAttackTarget refuse
    // attacks. Two engine rules shape how a system holds it:
    //   - Player::TeleportTo refuses to port a flagged player into an
    //     instanceable map, so hold it only after the teleport was accepted;
    //   - the worldport ack clears it on every port to a non-arena map, so
    //     the core re-applies it for holders on arrival.
    // Release before the teleport back. Pets are not covered (the attack check
    // looks at the player only), so systems refuse spectators with a pet out.
    void HoldSpectatorFlag(Player* spectator);
    void ReleaseSpectatorFlag(Player* spectator);
    // Whether the core holds the flag for this player. Safe from any thread.
    bool IsHoldingSpectatorFlag(Player const* player);

    // Send a snapshot payload over the negotiated transport: native
    // SMSG_SPECTATOR_LIVE_SNAPSHOT when the client capability allows it,
    // addon-channel JSON fallback otherwise. Callers that already hold the
    // encoded JSON (the periodic push hashes it for change detection) pass it
    // as `preEncoded` so the native path does not encode a second time.
    void SendSnapshotPayload(Player* spectator,
        DCAddon::JsonValue const& payload,
        std::string const* preEncoded = nullptr);

    class Registry
    {
    public:
        static Registry& Get();

        void RegisterContext(ISpectatableContext* context);

        ISpectatableContext* FindContextFor(ObjectGuid guid) const;
        ISpectatableContext* FindContext(SystemId id) const;
        bool IsSpectating(ObjectGuid guid) const;

        // Every system's AppendListings, as one JSON array.
        DCAddon::JsonValue BuildListings(Player* viewer) const;

        // Route a live-list start request to the owning system.
        bool StartById(Player* player, SystemId id, uint32 sessionId,
            std::string& error);

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
