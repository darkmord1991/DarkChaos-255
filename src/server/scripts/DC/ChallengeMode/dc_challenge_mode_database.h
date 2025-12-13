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
    // Future expansion flags (start after current setting bits)
    CHALLENGE_FLAG_SOLO             = 0x200,  // 1 << 9 (future)
    CHALLENGE_FLAG_DUNGEON_ONLY     = 0x400,  // 1 << 10 (future)
    CHALLENGE_FLAG_PVP_ONLY         = 0x800,  // 1 << 11 (future)
    CHALLENGE_FLAG_UNUSED_RESERVED  = 0x1000  // 1 << 12
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
    // Convert challenge mode setting to bitwise flag
    static uint32 SettingToBitFlag(uint8 setting);
    
    // Convert bitwise flags to readable string
    static std::string BitFlagsToString(uint32 flags);
    
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
        const std::string& details,
        Player* player = nullptr,
        uint32 killerEntry = 0,
        const std::string& killerName = ""
    );
    
    // Record hardcore death
    static void RecordHardcoreDeath(ObjectGuid guid, Player* player, uint32 killerEntry, const std::string& killerName);
    
    // Lock character (hardcore death)
    static void LockCharacter(ObjectGuid guid);
    
    // Unlock character (admin)
    static void UnlockCharacter(ObjectGuid guid);
    
    // Check if character is locked
    static bool IsCharacterLocked(ObjectGuid guid);
    
    // Increment activation counter
    static void IncrementActivations(ObjectGuid guid);
    
    // Increment deactivation counter
    static void IncrementDeactivations(ObjectGuid guid);
    
    // Update mode statistics
    static void UpdateModeStats(
        ObjectGuid guid,
        uint8 modeId,
        const std::string& modeName,
        bool isActivating
    );
    
    // Record playtime for mode
    static void RecordPlaytime(ObjectGuid guid, uint8 modeId, uint32 seconds);
    
    // Update max level for mode
    static void UpdateMaxLevel(ObjectGuid guid, uint8 modeId, uint8 level);
    
    // Increment kill counter for mode
    static void IncrementKills(ObjectGuid guid, uint8 modeId, uint32 count = 1);
    
    // Increment death counter for mode
    static void IncrementDeaths(ObjectGuid guid, uint8 modeId, uint32 count = 1);
    
    // Increment quest completion for mode
    static void IncrementQuests(ObjectGuid guid, uint8 modeId, uint32 count = 1);
    
    // Increment dungeon completion for mode
    static void IncrementDungeons(ObjectGuid guid, uint8 modeId, uint32 count = 1);
    
    // Increment PvP kills for mode
    static void IncrementPvPKills(ObjectGuid guid, uint8 modeId, uint32 count = 1);
    
    // Initialize tracking for new player (ensure row exists)
    static void InitializeTracking(ObjectGuid guid);
    
    // Sync active modes from player_settings to tracking table
    static void SyncActiveModesFromSettings(Player* player);
};

#endif // CHALLENGE_MODE_DATABASE_H
