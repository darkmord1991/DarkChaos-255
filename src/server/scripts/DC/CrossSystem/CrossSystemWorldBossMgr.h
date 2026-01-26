/*
 * CrossSystemWorldBossMgr.h - Centralized World Boss Management System
 * ============================================================================
 * Provides a singleton manager for world boss events:
 * - Boss registration and state tracking
 * - Unified WRLD addon messaging
 * - Spawn/respawn timer management
 *
 * Usage in boss scripts:
 *   void JustAppeared() { sWorldBossMgr->OnBossSpawned(me); }
 *   void JustEngagedWith(Unit*) { sWorldBossMgr->OnBossEngaged(me); }
 *   void JustDied(Unit*) { sWorldBossMgr->OnBossDied(me); }
 * ============================================================================
 */

#pragma once

#include "Creature.h"
#include "DBCStores.h"
#include "Map.h"
#include "Player.h"

#include "../AddonExtension/dc_addon_namespace.h"
#include "CrossSystemMapCoords.h"

#include <string>
#include <unordered_map>
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

        // Runtime state
        bool isActive = false;
        int32 respawnCountdown = 0; // seconds until respawn (-1 if unknown)
        ObjectGuid currentGuid;
    };

    class WorldBossMgr
    {
    public:
        static WorldBossMgr* Instance();

        // ========== Registration ==========
        // Call during server startup to register world bosses
        void RegisterBoss(uint32 entry, uint32 spawnId, std::string_view displayName,
                          uint32 zoneId, uint32 respawnTimeSeconds = 1800);

        // ========== Boss Script Hooks ==========
        // Call these from your boss scripts instead of building WRLD messages manually
        void OnBossSpawned(Creature* boss);
        void OnBossEngaged(Creature* boss);
        void OnBossHPUpdate(Creature* boss, uint8 hpPct, uint8 threshold);
        void OnBossDied(Creature* boss);

        // ========== State Queries ==========
        WorldBossInfo* GetBossInfo(uint32 entry);
        WorldBossInfo* GetBossInfoBySpawnId(uint32 spawnId);
        std::vector<WorldBossInfo const*> GetAllBosses() const;
        bool IsBossActive(uint32 entry) const;

        // ========== Timer Management ==========
        // Call from a world script update hook to tick respawn timers
        void Update(uint32 diffMs);

        // ========== Addon Protocol ==========
        // Build full boss list for WRLD content snapshot
        DCAddon::JsonValue BuildBossesContentArray() const;

    private:
        WorldBossMgr() = default;

        void BroadcastBossUpdate(Creature* boss, std::string_view action, bool active, int32 spawnIn = -1);
        void BuildBossJson(DCAddon::JsonValue& b, Creature* boss, std::string_view action,
                           bool active, int32 spawnIn) const;

        std::unordered_map<uint32, WorldBossInfo> _bossesByEntry;
        std::unordered_map<uint32, uint32> _spawnIdToEntry; // spawnId -> entry mapping
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
