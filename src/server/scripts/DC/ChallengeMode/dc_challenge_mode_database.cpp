/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255
 * 
 * Challenge Mode Database Integration - Implementation
 * Uses direct SQL queries (no prepared statements needed)
 */

#include "dc_challenge_mode_database.h"
#include "dc_challenge_modes.h"
#include "Log.h"
#include "World.h"

// Convert challenge mode setting to bitwise flag
uint32 ChallengeModeDatabase::SettingToBitFlag(uint8 setting)
{
    switch(setting)
    {
        case SETTING_HARDCORE:           return CHALLENGE_FLAG_HARDCORE;
        case SETTING_SEMI_HARDCORE:      return CHALLENGE_FLAG_SEMI_HARDCORE;
        case SETTING_SELF_CRAFTED:       return CHALLENGE_FLAG_SELF_CRAFTED;
        case SETTING_IRON_MAN:           return CHALLENGE_FLAG_IRON_MAN;
        case SETTING_QUEST_XP_ONLY:      return CHALLENGE_FLAG_QUEST_ONLY;
        default:                         return 0;
    }
}

// Convert bitwise flags to readable string
std::string ChallengeModeDatabase::BitFlagsToString(uint32 flags)
{
    std::string result;
    
    if (flags & CHALLENGE_FLAG_HARDCORE)      result += "Hardcore, ";
    if (flags & CHALLENGE_FLAG_SEMI_HARDCORE) result += "Semi-Hardcore, ";
    if (flags & CHALLENGE_FLAG_SELF_CRAFTED)  result += "Self-Crafted, ";
    if (flags & CHALLENGE_FLAG_IRON_MAN)      result += "Iron Man, ";
    if (flags & CHALLENGE_FLAG_QUEST_ONLY)    result += "Quest Only, ";
    
    if (!result.empty())
        result = result.substr(0, result.length() - 2); // Remove trailing ", "
    else
        result = "None";
    
    return result;
}

// Get current active modes bitfield for player
uint32 ChallengeModeDatabase::GetActiveModesForPlayer(ObjectGuid guid)
{
    QueryResult result = CharacterDatabase.Query("SELECT active_modes FROM dc_character_challenge_modes WHERE guid = {}", guid.GetCounter());
    if (result)
    {
        Field* fields = result->Fetch();
        return fields[0].GetUInt32();
    }
    
    return 0;
}

// Update active modes in database
void ChallengeModeDatabase::UpdateActiveModes(ObjectGuid guid, uint32 activeModes)
{
    CharacterDatabase.Execute(
        "INSERT INTO dc_character_challenge_modes (guid, active_modes, activated_at) VALUES ({}, {}, NOW()) "
        "ON DUPLICATE KEY UPDATE active_modes = VALUES(active_modes), activated_at = NOW()",
        guid.GetCounter(), activeModes
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
    
    // Escape SQL strings
    std::string escapedDetails = details;
    size_t pos = 0;
    while ((pos = escapedDetails.find("'", pos)) != std::string::npos)
    {
        escapedDetails.replace(pos, 1, "''");
        pos += 2;
    }
    
    std::string escapedKillerName = killerName;
    pos = 0;
    while ((pos = escapedKillerName.find("'", pos)) != std::string::npos)
    {
        escapedKillerName.replace(pos, 1, "''");
        pos += 2;
    }
    
    // Build and execute SQL
    if (player)
    {
        if (killerEntry > 0)
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_challenge_mode_log "
                "(guid, event_type, modes_before, modes_after, event_details, character_level, map_id, zone_id, "
                "position_x, position_y, position_z, killer_entry, killer_name) VALUES "
                "({}, '{}', {}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, '{}')",
                guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, escapedDetails,
                player->GetLevel(), player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(),
                killerEntry, escapedKillerName
            );
        }
        else
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_challenge_mode_log "
                "(guid, event_type, modes_before, modes_after, event_details, character_level, map_id, zone_id, "
                "position_x, position_y, position_z) VALUES "
                "({}, '{}', {}, {}, '{}', {}, {}, {}, {}, {}, {})",
                guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, escapedDetails,
                player->GetLevel(), player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ()
            );
        }
    }
    else
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_character_challenge_mode_log (guid, event_type, modes_before, modes_after, event_details) "
            "VALUES ({}, '{}', {}, {}, '{}')",
            guid.GetCounter(), eventTypeStr, modesBefore, modesAfter, escapedDetails
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
        return fields[0].GetUInt8() == 1;
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
    std::string escapedName = modeName;
    size_t pos = 0;
    while ((pos = escapedName.find("'", pos)) != std::string::npos)
    {
        escapedName.replace(pos, 1, "''");
        pos += 2;
    }
    
    if (isActivating)
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_character_challenge_mode_stats (guid, mode_id, mode_name, times_activated, first_activated, last_activated, currently_active) "
            "VALUES ({}, {}, '{}', 1, NOW(), NOW(), 1) "
            "ON DUPLICATE KEY UPDATE times_activated = times_activated + 1, last_activated = NOW(), currently_active = 1",
            guid.GetCounter(), modeId, escapedName
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

// Initialize tracking for new player
void ChallengeModeDatabase::InitializeTracking(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "INSERT IGNORE INTO dc_character_challenge_modes (guid, active_modes) VALUES ({}, 0)",
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
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_IRON_MAN).value == 1)
        activeModes |= CHALLENGE_FLAG_IRON_MAN;
    
    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_QUEST_XP_ONLY).value == 1)
        activeModes |= CHALLENGE_FLAG_QUEST_ONLY;
    
    // Update the tracking table
    UpdateActiveModes(player->GetGUID(), activeModes);
}
