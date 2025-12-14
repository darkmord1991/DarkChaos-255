/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255
 * 
 * Challenge Mode Database Integration - Implementation
 * Uses parameterized queries to prevent SQL injection
 */

#include "dc_challenge_mode_database.h"
#include "dc_challenge_modes.h"
#include "Log.h"
#include "World.h"
#include <vector>

// Convert challenge mode setting to bitwise flag
uint32 ChallengeModeDatabase::SettingToBitFlag(uint8 setting)
{
    switch(setting)
    {
        case SETTING_HARDCORE:           return CHALLENGE_FLAG_HARDCORE;
        case SETTING_SEMI_HARDCORE:      return CHALLENGE_FLAG_SEMI_HARDCORE;
        case SETTING_SELF_CRAFTED:       return CHALLENGE_FLAG_SELF_CRAFTED;
        case SETTING_ITEM_QUALITY_LEVEL: return CHALLENGE_FLAG_ITEM_QUALITY;
        case SETTING_SLOW_XP_GAIN:       return CHALLENGE_FLAG_SLOW_XP_GAIN;
        case SETTING_VERY_SLOW_XP_GAIN:  return CHALLENGE_FLAG_VERY_SLOW_XP_GAIN;
        case SETTING_QUEST_XP_ONLY:      return CHALLENGE_FLAG_QUEST_ONLY;
        case SETTING_IRON_MAN:           return CHALLENGE_FLAG_IRON_MAN;
        default:                         return 0;
    }
}

// Convert bitwise flags to readable string
std::string ChallengeModeDatabase::BitFlagsToString(uint32 flags)
{
    if (flags == 0)
        return "None";
    
    std::vector<std::string> activeModes;
    activeModes.reserve(8); // Preallocate for typical case
    
    if (flags & CHALLENGE_FLAG_HARDCORE)      activeModes.push_back("Hardcore");
    if (flags & CHALLENGE_FLAG_SEMI_HARDCORE) activeModes.push_back("Semi-Hardcore");
    if (flags & CHALLENGE_FLAG_SELF_CRAFTED)  activeModes.push_back("Self-Crafted");
    if (flags & CHALLENGE_FLAG_ITEM_QUALITY)  activeModes.push_back("Item Quality Restricted");
    if (flags & CHALLENGE_FLAG_SLOW_XP_GAIN)  activeModes.push_back("Slow XP Gain");
    if (flags & CHALLENGE_FLAG_VERY_SLOW_XP_GAIN) activeModes.push_back("Very Slow XP Gain");
    if (flags & CHALLENGE_FLAG_IRON_MAN)      activeModes.push_back("Iron Man");
    if (flags & CHALLENGE_FLAG_QUEST_ONLY)    activeModes.push_back("Quest Only");
    
    // Join with ", " - single string allocation
    std::string result;
    for (size_t i = 0; i < activeModes.size(); ++i)
    {
        if (i > 0)
            result += ", ";
        result += activeModes[i];
    }
    
    return result;
}

// Get current active modes bitfield for player
uint32 ChallengeModeDatabase::GetActiveModesForPlayer(ObjectGuid guid)
{
    QueryResult result = CharacterDatabase.Query("SELECT active_modes FROM dc_character_challenge_modes WHERE guid = {}", guid.GetCounter());
    if (result)
    {
        Field* fields = result->Fetch();
        return fields[0].Get<uint32>();
    }
    
    return 0;
}

// Update active modes in database
void ChallengeModeDatabase::UpdateActiveModes(ObjectGuid guid, uint32 activeModes)
{
    CharacterDatabase.Execute(
        "INSERT INTO dc_character_challenge_modes (guid, active_modes, activated_at) VALUES ({}, {}, NOW()) "
        "ON DUPLICATE KEY UPDATE active_modes = {}, activated_at = NOW()",
        guid.GetCounter(), activeModes, activeModes
    );
}

// Log a challenge mode event
void ChallengeModeDatabase::LogEvent(
    ObjectGuid guid,
    ChallengeModeEventType eventType,
    uint32 modesBefore,
    uint32 modesAfter,
    const std::string& details,
    Player* player,
    uint32 killerEntry,
    const std::string& killerName)
{
    const char* eventTypeStr = "MODIFY";
    switch(eventType)
    {
        case EVENT_ACTIVATE:   eventTypeStr = "ACTIVATE"; break;
        case EVENT_DEACTIVATE: eventTypeStr = "DEACTIVATE"; break;
        case EVENT_DEATH:      eventTypeStr = "DEATH"; break;
        case EVENT_LOCK:       eventTypeStr = "LOCK"; break;
        case EVENT_UNLOCK:     eventTypeStr = "UNLOCK"; break;
        case EVENT_MODIFY:     eventTypeStr = "MODIFY"; break;
    }
    
    // Build and execute SQL with proper parameterization
    if (player)
    {
        // Escape strings to avoid SQL injection when using direct string formatting
        std::string detailsEsc = details;
        CharacterDatabase.EscapeString(detailsEsc);

        if (killerEntry > 0)
        {
            std::string killerEsc = killerName;
            CharacterDatabase.EscapeString(killerEsc);

            CharacterDatabase.Execute(
                "INSERT INTO dc_character_challenge_mode_log "
                "(guid, event_type, modes_before, modes_after, event_details, character_level, map_id, zone_id, "
                "position_x, position_y, position_z, killer_entry, killer_name) VALUES "
                "({}, '{}', {}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, '{}')",
                guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, detailsEsc,
                player->GetLevel(), player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(),
                killerEntry, killerEsc
            );
        }
        else
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_challenge_mode_log "
                "(guid, event_type, modes_before, modes_after, event_details, character_level, map_id, zone_id, "
                "position_x, position_y, position_z) VALUES "
                "({}, '{}', {}, {}, '{}', {}, {}, {}, {}, {}, {})",
                guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, detailsEsc,
                player->GetLevel(), player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ()
            );
        }
    }
    else
    {
        std::string detailsEsc = details;
        CharacterDatabase.EscapeString(detailsEsc);

        CharacterDatabase.Execute(
            "INSERT INTO dc_character_challenge_mode_log (guid, event_type, modes_before, modes_after, event_details) "
            "VALUES ({}, '{}', {}, {}, '{}')",
            guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, detailsEsc
        );
    }
}

// Record hardcore death
void ChallengeModeDatabase::RecordHardcoreDeath(ObjectGuid guid, Player* player, uint32 killerEntry, const std::string& killerName)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET hardcore_deaths = hardcore_deaths + 1, last_hardcore_death = NOW() WHERE guid = {}",
        guid.GetCounter()
    );
    
    uint32 activeModes = GetActiveModesForPlayer(guid);
    std::string details = "Hardcore death - killed by " + killerName;
    LogEvent(guid, EVENT_DEATH, activeModes, activeModes, details, player, killerEntry, killerName);
}

// Lock character (hardcore death)
void ChallengeModeDatabase::LockCharacter(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET character_locked = 1, locked_at = NOW() WHERE guid = {}",
        guid.GetCounter()
    );
    
    uint32 activeModes = GetActiveModesForPlayer(guid);
    LogEvent(guid, EVENT_LOCK, activeModes, activeModes, "Character locked due to hardcore death");
}

// Unlock character (admin)
void ChallengeModeDatabase::UnlockCharacter(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET character_locked = 0, locked_at = NULL WHERE guid = {}",
        guid.GetCounter()
    );
    
    uint32 activeModes = GetActiveModesForPlayer(guid);
    LogEvent(guid, EVENT_UNLOCK, activeModes, activeModes, "Character unlocked by administrator");
}

// Check if character is locked
bool ChallengeModeDatabase::IsCharacterLocked(ObjectGuid guid)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT character_locked FROM dc_character_challenge_modes WHERE guid = {}",
        guid.GetCounter()
    );
    
    if (result)
    {
        Field* fields = result->Fetch();
        return fields[0].Get<uint8>() == 1;
    }
    
    return false;
}

// Increment activation counter
void ChallengeModeDatabase::IncrementActivations(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET total_activations = total_activations + 1 WHERE guid = {}",
        guid.GetCounter()
    );
}

// Increment deactivation counter
void ChallengeModeDatabase::IncrementDeactivations(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET total_deactivations = total_deactivations + 1 WHERE guid = {}",
        guid.GetCounter()
    );
}

// Update mode statistics
void ChallengeModeDatabase::UpdateModeStats(
    ObjectGuid guid,
    uint8 modeId,
    const std::string& modeName,
    bool isActivating)
{
    if (isActivating)
    {
        std::string modeNameEsc = modeName;
        CharacterDatabase.EscapeString(modeNameEsc);

        CharacterDatabase.Execute(
            "INSERT INTO dc_character_challenge_mode_stats (guid, mode_id, mode_name, times_activated, first_activated, last_activated, currently_active) "
            "VALUES ({}, {}, '{}', 1, NOW(), NOW(), 1) "
            "ON DUPLICATE KEY UPDATE times_activated = times_activated + 1, last_activated = NOW(), currently_active = 1",
            guid.GetCounter(), modeId, modeNameEsc
        );
    }
    else
    {
        CharacterDatabase.Execute(
            "UPDATE dc_character_challenge_mode_stats SET currently_active = 0, last_deactivated = NOW() "
            "WHERE guid = {} AND mode_id = {}",
            guid.GetCounter(), modeId
        );
    }
}

// Record playtime for mode
void ChallengeModeDatabase::RecordPlaytime(ObjectGuid guid, uint8 modeId, uint32 seconds)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET total_playtime_seconds = total_playtime_seconds + {} "
        "WHERE guid = {} AND mode_id = {}",
        seconds, guid.GetCounter(), modeId
    );
}

// Update max level for mode
void ChallengeModeDatabase::UpdateMaxLevel(ObjectGuid guid, uint8 modeId, uint8 level)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET max_level_reached = GREATEST(max_level_reached, {}) "
        "WHERE guid = {} AND mode_id = {}",
        level, guid.GetCounter(), modeId
    );
}

// Increment kill counter for mode
void ChallengeModeDatabase::IncrementKills(ObjectGuid guid, uint8 modeId, uint32 count)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET total_kills = total_kills + {} "
        "WHERE guid = {} AND mode_id = {}",
        count, guid.GetCounter(), modeId
    );
}

// Increment death counter for mode
void ChallengeModeDatabase::IncrementDeaths(ObjectGuid guid, uint8 modeId, uint32 count)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET total_deaths = total_deaths + {} "
        "WHERE guid = {} AND mode_id = {}",
        count, guid.GetCounter(), modeId
    );
}

// Increment quest completion for mode
void ChallengeModeDatabase::IncrementQuests(ObjectGuid guid, uint8 modeId, uint32 count)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET quests_completed = quests_completed + {} "
        "WHERE guid = {} AND mode_id = {}",
        count, guid.GetCounter(), modeId
    );
}

// Increment dungeon completion for mode
void ChallengeModeDatabase::IncrementDungeons(ObjectGuid guid, uint8 modeId, uint32 count)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET dungeons_completed = dungeons_completed + {} "
        "WHERE guid = {} AND mode_id = {}",
        count, guid.GetCounter(), modeId
    );
}

// Increment PvP kills for mode
void ChallengeModeDatabase::IncrementPvPKills(ObjectGuid guid, uint8 modeId, uint32 count)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_mode_stats SET pvp_kills = pvp_kills + {} "
        "WHERE guid = {} AND mode_id = {}",
        count, guid.GetCounter(), modeId
    );
}

// Initialize tracking for a player
void ChallengeModeDatabase::InitializeTracking(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "INSERT IGNORE INTO dc_character_challenge_modes (guid, active_modes, activated_at) VALUES ({}, 0, NOW())",
        guid.GetCounter()
    );
}

// Sync active modes from player_settings to tracking table
void ChallengeModeDatabase::SyncActiveModesFromSettings(Player* player)
{
    if (!player)
        return;
    
    uint32 activeModes = 0;
    
    // Check each challenge mode setting and build bitfield
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_HARDCORE).value == 1)
        activeModes |= CHALLENGE_FLAG_HARDCORE;
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_SEMI_HARDCORE).value == 1)
        activeModes |= CHALLENGE_FLAG_SEMI_HARDCORE;
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_SELF_CRAFTED).value == 1)
        activeModes |= CHALLENGE_FLAG_SELF_CRAFTED;

    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_ITEM_QUALITY_LEVEL).value == 1)
        activeModes |= CHALLENGE_FLAG_ITEM_QUALITY;

    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_SLOW_XP_GAIN).value == 1)
        activeModes |= CHALLENGE_FLAG_SLOW_XP_GAIN;

    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_VERY_SLOW_XP_GAIN).value == 1)
        activeModes |= CHALLENGE_FLAG_VERY_SLOW_XP_GAIN;
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_IRON_MAN).value == 1)
        activeModes |= CHALLENGE_FLAG_IRON_MAN;
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_QUEST_XP_ONLY).value == 1)
        activeModes |= CHALLENGE_FLAG_QUEST_ONLY;
    
    // Update the tracking table
    UpdateActiveModes(player->GetGUID(), activeModes);
}
