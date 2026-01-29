/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * dc_constants.h - Shared constants for all DC systems
 * Centralizes magic numbers and provides type-safe constants
 */

#ifndef DC_CONSTANTS_H
#define DC_CONSTANTS_H

#include <cstdint>

namespace DCConstants
{
    // =========================================================================
    // Common Spell IDs
    // =========================================================================
    constexpr uint32 SPELL_CYCLONE = 33786;                    // Crowd control effect
    constexpr uint32 SPELL_STUN_PERMANENT = 61204;             // Used for training dummies
    constexpr uint32 SPELL_PHASEMASK_NORMAL = 1;               // Normal phase mask

    // =========================================================================
    // Common NPC Entries
    // =========================================================================
    constexpr uint32 NPC_GUILD_BUTLER = 95104;                 // Guild house butler
    constexpr uint32 NPC_UNIVERSAL_QUEST_MASTER = 700100;      // Dungeon quest master

    // =========================================================================
    // Zone IDs
    // =========================================================================
    constexpr uint32 ZONE_GM_ISLAND = 876;                     // GM Island (for guildhouse)

    // =========================================================================
    // Timing Constants (in milliseconds)
    // =========================================================================
    constexpr uint32 WARMUP_ABORT_GRACE_MS = 5000;             // 5 seconds
    constexpr uint32 CLEANUP_TIMER_MS = 5000;                  // 5 seconds
    constexpr uint32 DEFAULT_HUD_TIMER_SECONDS = 2400;         // 40 minutes
    constexpr uint32 OFFLINE_GRACE_SECONDS = 45;               // Player offline grace period
    constexpr uint32 RATE_LIMIT_VIOLATION_DECAY_SECONDS = 300; // 5 minutes

    // =========================================================================
    // AoE Loot Constants
    // =========================================================================
    constexpr float DEFAULT_AOELOOT_RANGE = 30.0f;
    constexpr float MIN_AOELOOT_RANGE = 5.0f;
    constexpr float MAX_AOELOOT_RANGE = 100.0f;
    constexpr uint32 DEFAULT_MAX_CORPSES = 10;
    constexpr uint32 MAX_CORPSES_LIMIT = 50;
    constexpr uint8 DEFAULT_MAX_MERGE_SLOTS = 15;
    constexpr uint8 MAX_MERGE_SLOTS_LIMIT = 16;

    // =========================================================================
    // Protocol Constants
    // =========================================================================
    constexpr uint32 DEFAULT_REQUEST_TIMEOUT_MS = 30000;       // 30 seconds
    constexpr uint32 DEFAULT_CHUNK_TIMEOUT_MS = 60000;         // 60 seconds
    constexpr uint32 DEFAULT_MAX_MESSAGES_PER_SECOND = 30;
    constexpr uint32 DEFAULT_RATE_LIMIT_BASE_MUTE_SECONDS = 30;
    constexpr uint32 MAX_RATE_LIMIT_MUTE_SECONDS = 1800;       // 30 minutes cap

    // =========================================================================
    // Prestige System Constants
    // =========================================================================
    constexpr uint32 MAX_PRESTIGE_LEVEL = 10;
    constexpr uint32 PRESTIGE_MAX_CHALLENGES = 10;

    // =========================================================================
    // Item Upgrade Constants
    // =========================================================================
    constexpr uint32 UPGRADE_CACHE_SIZE = 20000;               // LRU cache size
    constexpr uint32 RESPEC_COOLDOWN_SECONDS = 3600;           // 1 hour

    // =========================================================================
    // Mythic+ Constants (duplicated from MythicPlus for convenience)
    // =========================================================================
    constexpr float MYTHIC_BASE_MULTIPLIER = 2.0f;
    constexpr float KEYSTONE_LEVEL_STEP = 0.25f;
    constexpr uint8 DEFAULT_VAULT_THRESHOLDS[3] = { 1, 4, 8 };
    constexpr uint32 DEFAULT_VAULT_TOKENS[3] = { 50, 100, 150 };

    // =========================================================================
    // Cache Size Limits
    // =========================================================================
    constexpr size_t MAX_NOTIFIED_APPEARANCES_PER_PLAYER = 10000;
    constexpr size_t MAX_PENDING_CHUNKS_PER_ACCOUNT = 10;

}  // namespace DCConstants

#endif // DC_CONSTANTS_H
