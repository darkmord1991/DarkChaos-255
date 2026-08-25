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
    std::string const& details,
    Player* player,
    uint32 killerEntry,
    std::string const& killerName)
{
    char const* eventTypeStr = "MODIFY";
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
void ChallengeModeDatabase::RecordHardcoreDeath(ObjectGuid guid, Player* player, uint32 killerEntry, std::string const& killerName, uint32 activeModes)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET hardcore_deaths = hardcore_deaths + 1, last_hardcore_death = NOW() WHERE guid = {}",
        guid.GetCounter()
    );

    std::string details = "Hardcore death - killed by " + killerName;
    LogEvent(guid, EVENT_DEATH, activeModes, activeModes, details, player, killerEntry, killerName);
}

// Lock character (hardcore death)
void ChallengeModeDatabase::LockCharacter(ObjectGuid guid, uint32 activeModes)
{
    CharacterDatabase.Execute(
        "UPDATE dc_character_challenge_modes SET character_locked = 1, locked_at = NOW() WHERE guid = {}",
        guid.GetCounter()
    );

    LogEvent(guid, EVENT_LOCK, activeModes, activeModes, "Character locked due to hardcore death");
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

// Initialize tracking for a player
void ChallengeModeDatabase::InitializeTracking(ObjectGuid guid)
{
    CharacterDatabase.Execute(
        "INSERT IGNORE INTO dc_character_challenge_modes (guid, active_modes, activated_at) VALUES ({}, 0, NOW())",
        guid.GetCounter()
    );
}

// Compute active modes bitfield from in-memory player settings (no DB query)
uint32 ChallengeModeDatabase::ComputeActiveModesFromSettings(Player* player)
{
    if (!player)
        return 0;

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

    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_IRON_MAN_PLUS).value == 1)
        activeModes |= CHALLENGE_FLAG_IRON_MAN_PLUS;

    if (player->GetPlayerSetting("mod-challenge-modes", SETTING_QUEST_XP_ONLY).value == 1)
        activeModes |= CHALLENGE_FLAG_QUEST_ONLY;

    return activeModes;
}

// Sync active modes from player_settings to tracking table
void ChallengeModeDatabase::SyncActiveModesFromSettings(Player* player)
{
    if (!player)
        return;

    // Update the tracking table
    UpdateActiveModes(player->GetGUID(), ComputeActiveModesFromSettings(player));
}
