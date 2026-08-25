/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255
 *
 * Challenge Mode Database Integration
 * Provides logging and statistics tracking for challenge modes
 */

#ifndef CHALLENGE_MODE_DATABASE_H
#define CHALLENGE_MODE_DATABASE_H

#include "Player.h"
#include "DatabaseEnv.h"
#include <string>

// Challenge mode bitwise flags for database storage
enum ChallengeModeBitFlags : uint32
{
    // IMPORTANT: Keep these aligned with ChallengeModeSettings indices
    // (i.e., bitfield is 1 << setting).
    CHALLENGE_FLAG_HARDCORE         = 0x01,   // 1 << 0
    CHALLENGE_FLAG_SEMI_HARDCORE    = 0x02,   // 1 << 1
    CHALLENGE_FLAG_SELF_CRAFTED     = 0x04,   // 1 << 2
    CHALLENGE_FLAG_ITEM_QUALITY     = 0x08,   // 1 << 3
    CHALLENGE_FLAG_SLOW_XP_GAIN     = 0x10,   // 1 << 4
    CHALLENGE_FLAG_VERY_SLOW_XP_GAIN= 0x20,   // 1 << 5
    CHALLENGE_FLAG_QUEST_ONLY       = 0x40,   // 1 << 6
    CHALLENGE_FLAG_IRON_MAN         = 0x80,   // 1 << 7
    // Note: bit 1<<8 is reserved for HARDCORE_DEAD (player state, not a selectable mode).
    CHALLENGE_FLAG_IRON_MAN_PLUS    = 0x200,  // 1 << 9
    // Future expansion flags (start after current setting bits)
    CHALLENGE_FLAG_SOLO             = 0x400,  // 1 << 10 (future)
    CHALLENGE_FLAG_DUNGEON_ONLY     = 0x800,  // 1 << 11 (future)
    CHALLENGE_FLAG_PVP_ONLY         = 0x1000, // 1 << 12 (future)
    CHALLENGE_FLAG_UNUSED_RESERVED  = 0x2000  // 1 << 13
};

// Event types for logging
enum ChallengeModeEventType
{
    EVENT_ACTIVATE,      // Challenge mode activated
    EVENT_DEACTIVATE,    // Challenge mode deactivated
    EVENT_DEATH,         // Player died (any mode)
    EVENT_LOCK,          // Character locked (hardcore death)
    EVENT_UNLOCK,        // Character unlocked (admin)
    EVENT_MODIFY         // Settings modified
};

class ChallengeModeDatabase
{
public:
    // Get current active modes bitfield for player
    static uint32 GetActiveModesForPlayer(ObjectGuid guid);

    // Update active modes in database
    static void UpdateActiveModes(ObjectGuid guid, uint32 activeModes);

    // Log a challenge mode event
    static void LogEvent(
        ObjectGuid guid,
        ChallengeModeEventType eventType,
        uint32 modesBefore,
        uint32 modesAfter,
        std::string const& details,
        Player* player = nullptr,
        uint32 killerEntry = 0,
        std::string const& killerName = ""
    );

    // Record hardcore death
    static void RecordHardcoreDeath(ObjectGuid guid, Player* player, uint32 killerEntry, std::string const& killerName, uint32 activeModes);

    // Lock character (hardcore death)
    static void LockCharacter(ObjectGuid guid, uint32 activeModes);

    // Increment activation counter
    static void IncrementActivations(ObjectGuid guid);

    // Increment deactivation counter
    static void IncrementDeactivations(ObjectGuid guid);

    // Initialize tracking for new player (ensure row exists)
    static void InitializeTracking(ObjectGuid guid);

    // Sync active modes from player_settings to tracking table
    static void SyncActiveModesFromSettings(Player* player);

    // Compute active modes bitfield from in-memory player settings (no DB query)
    static uint32 ComputeActiveModesFromSettings(Player* player);
};

#endif // CHALLENGE_MODE_DATABASE_H
