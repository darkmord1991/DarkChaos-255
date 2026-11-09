/*
 * CrossSystemWorldBossMgr.h - Centralized World Boss Management System
 * ============================================================================
 * Provides a singleton manager for world boss events:
 * - Boss registration and state tracking
 * - Unified WRLD addon messaging
 * - Spawn/respawn timer management
 *
 * Usage in boss scripts:
 *   void JustRespawned() override { ScriptedAI::JustRespawned(); sWorldBossMgr->OnBossSpawned(me); }
 *   void JustEngagedWith(Unit*) { sWorldBossMgr->OnBossEngaged(me); }
 *   void JustDied(Unit*) { sWorldBossMgr->OnBossDied(me); }
 *
 * Every boss push goes to all players in the world, not only to the boss's map:
 * the InfoBar boss bar, the Group Finder world tab and the map pins show the
 * bosses wherever the player is. The hooks run on the map thread, so a push is
 * built there and queued, and Update() sends the queue from the world thread.
 * ============================================================================
 */

#pragma once

#include "Creature.h"
#include "DBCStores.h"
#include "Map.h"
#include "Player.h"

#include "DC/AddonExtension/dc_addon_namespace.h"
#include "CrossSystemMapCoords.h"

#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace DC
{
    struct WorldBossInfo
    {
        uint32 creatureEntry = 0;
        uint32 spawnId = 0;
        std::string displayName;
        uint32 zoneId = 0;
        uint32 respawnTimeSeconds = 1800; // 30 min default
        uint32 lockoutSeconds = 0;        // per-boss loot-lockout override; 0 = use global default

        // Runtime state
        bool isActive = false;
        int32 respawnCountdown = 0; // seconds until respawn (-1 if unknown)
        ObjectGuid currentGuid;
        // Players moved into the boss combat phase (anti-grief phasing), each by an exclusive phase
        // layer (PhaseLayers::WorldBossFight) that RestoreBossPhase takes off again.
        std::unordered_set<ObjectGuid> phasedPlayers;
    };

    class WorldBossMgr
    {
    public:
        static WorldBossMgr* Instance();

        // ========== Configuration ==========
        // Load loot-lockout / phasing settings from the config. Safe to call again on `.reload config`.
        void LoadConfig();

        // ========== Registration ==========
        // Call during server startup to register world bosses
        void RegisterBoss(uint32 entry, uint32 spawnId, std::string_view displayName,
                          uint32 zoneId, uint32 respawnTimeSeconds = 1800, uint32 lockoutSeconds = 0);

        // ========== Boss Script Hooks ==========
        // Call these from your boss scripts instead of building WRLD messages manually
        void OnBossSpawned(Creature* boss);
        void OnBossEngaged(Creature* boss, Unit* who = nullptr);
        void OnBossHPUpdate(Creature* boss, uint8 hpPct, uint8 threshold);
        void OnBossDied(Creature* boss);
        void OnBossDespawned(Creature* boss);

        // ========== Loot Lockout ==========
        bool IsLockoutEnabled() const { return _lockoutEnabled; }
        // True when the player has already claimed this boss within the current lockout window
        // (returns false during the post-kill grace period so the fresh corpse stays lootable).
        bool IsPlayerLockedOut(Player const* player, uint32 entry) const;
        // Seconds until the player's lockout on this boss expires (0 if not locked).
        uint32 GetLockoutRemaining(Player const* player, uint32 entry) const;
        // Clear a player's lockout on this boss (GM tooling / testing).
        void ClearPlayerLockout(Player* player, uint32 entry);
        // "1d 4h 12m" style formatter for lockout durations (shared by the loot message and commands).
        static std::string FormatDuration(uint32 seconds);

        // ========== Anti-Grief Phasing ==========
        bool IsPhasingEnabled() const { return _phaseOnEngage; }
        // Return the boss and every player it phased in back to the normal world phase.
        void RestoreBossPhase(Creature* boss);

        // ========== State Queries ==========
        WorldBossInfo* GetBossInfo(uint32 entry);
        WorldBossInfo* GetBossInfoBySpawnId(uint32 spawnId);
        std::vector<WorldBossInfo const*> GetAllBosses() const;
        bool IsBossActive(uint32 entry) const;
        // Set by whoever runs a boss's rotation. respawnIn is -1 when no timer applies;
        // a boss neither active nor on a timer is off rotation. liveBoss is the boss's
        // live creature, or nullptr while it has none (a respawn the map has not run yet,
        // or a grid nobody has loaded). When the status (active / spawning / inactive)
        // changes, the change is pushed to every client.
        void SetBossState(uint32 entry, bool active, int32 respawnIn, Creature* liveBoss = nullptr);

        // ========== Timer Management ==========
        // Call from a world script update hook (world thread): ticks respawn timers and
        // sends the boss pushes queued since the last call.
        void Update(uint32 diffMs);

        // ========== Addon Protocol ==========
        // Build full boss list for WRLD content snapshot
        DCAddon::JsonValue BuildBossesContentArray() const;

    private:
        WorldBossMgr() = default;

        void BroadcastBossUpdate(Creature* boss, std::string_view action, bool active, int32 spawnIn = -1);
        void BuildBossJson(DCAddon::JsonValue& b, Creature* boss, std::string_view action,
                           bool active, int32 spawnIn) const;
        // The snapshot's record for one boss, built from its registration and state (no creature needed).
        void BuildBossInfoJson(DCAddon::JsonValue& b, WorldBossInfo const& info) const;

        // Boss pushes: queued from any thread, sent to every player by Update() on the world thread.
        void QueueBossUpdate(DCAddon::JsonValue&& boss);
        void SendQueuedBossUpdates();

        // Lockout helpers
        static std::string GetLockSource(uint32 entry);   // player-setting source key, per boss entry
        uint32 GetLockoutSecondsFor(uint32 entry) const;  // per-boss override or global default
        void LockPlayer(Player* player, uint32 entry);    // stamp the lockout expiry for one player

        // Phasing helpers
        void PhaseGroupIn(Player* leader, Creature* boss, uint32 phaseMask);

        std::unordered_map<uint32, WorldBossInfo> _bossesByEntry;
        std::unordered_map<uint32, uint32> _spawnIdToEntry; // spawnId -> entry mapping

        // Boss records waiting for the world thread (see QueueBossUpdate), in push order.
        std::mutex _queuedUpdatesLock;
        std::vector<DCAddon::JsonValue> _queuedUpdates;

        // Milliseconds not yet taken off the respawn countdowns: a world tick is far
        // shorter than a second, so Update() counts whole seconds out of this.
        uint32 _countdownCarryMs = 0;

        // Config-driven behaviour (see LoadConfig)
        bool   _lockoutEnabled     = true;         // per-character per-boss loot lockout
        uint32 _lockoutSeconds     = 604800;       // 7 days (weekly world-boss cadence)
        uint32 _gracePeriodSeconds = 300;          // post-kill window in which a locked killer may still loot
        bool   _phaseOnEngage      = false;        // move the engaging group into a private combat phase
        uint32 _phaseMask          = 0x40000000;   // bit used for the boss combat phase (high, distinctive)
    };
}

// Canonical namespace alias
namespace DarkChaos
{
namespace CrossSystem
{
    using WorldBossInfo = ::DC::WorldBossInfo;
    using WorldBossMgr = ::DC::WorldBossMgr;
}
}

#define sWorldBossMgr DarkChaos::CrossSystem::WorldBossMgr::Instance()
