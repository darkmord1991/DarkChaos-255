// -----------------------------------------------------------------------------
// OutdoorPvPHL_Utils.cpp
// -----------------------------------------------------------------------------
// Consolidated utility functions to eliminate duplicates across HLBG files.
// Centralizes common operations like OutdoorPvPHL instance retrieval.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "OutdoorPvPMgr.h"
#include "OutdoorPvP.h"

namespace HLBGUtils
{
    // Centralized OutdoorPvPHL instance retrieval
    // Replaces multiple GetHL() implementations across different files
    OutdoorPvPHL* GetHinterlandBG()
    {
        static OutdoorPvPHL* s_cachedHL = nullptr;
    static uint32 s_lastCheck = 0;
        
    // GameTime::GetGameTime() returns a Seconds duration; use .count()
    // to obtain an integral seconds value for uint32 timestamps.
    uint32 currentTime = static_cast<uint32>(GameTime::GetGameTime().count());
        
        // Cache the instance for 30 seconds to avoid repeated lookups
        if (!s_cachedHL || (currentTime - s_lastCheck) > 30)
        {
            if (OutdoorPvP* pvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
            {
                s_cachedHL = dynamic_cast<OutdoorPvPHL*>(pvp);
            }
            else
            {
                s_cachedHL = nullptr;
            }
            s_lastCheck = currentTime;
        }
        
        return s_cachedHL;
    }
    
    // Validate HLBG instance and provide error feedback
    bool ValidateHinterlandBG(Player* player, OutdoorPvPHL*& hl)
    {
        hl = GetHinterlandBG();
        if (!hl)
        {
            if (player)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Hinterland BG is not available.");
            }
            return false;
        }
        return true;
    }
    
    // Check if player is in Hinterlands zone
    bool IsPlayerInHinterlandsZone(Player* player)
    {
        return player && player->GetZoneId() == OutdoorPvPHLBuffZones[0];
    }
    
    // Get team name string for display
    const char* GetTeamName(TeamId teamId)
    {
        switch (teamId)
        {
            case TEAM_ALLIANCE: return "Alliance";
            case TEAM_HORDE: return "Horde";
            default: return "Neutral";
        }
    }
    
    // Get team color code for chat messages
    const char* GetTeamColorCode(TeamId teamId)
    {
        switch (teamId)
        {
            case TEAM_ALLIANCE: return "|cff0080ff"; // Blue
            case TEAM_HORDE: return "|cffff0000";    // Red
            default: return "|cffffffff";           // White
        }
    }
    
    // Format team name with color for display
    std::string FormatTeamName(TeamId teamId)
    {
        return std::string(GetTeamColorCode(teamId)) + GetTeamName(teamId) + "|r";
    }
    
    // Common eligibility checks for HLBG participation
    enum EligibilityResult
    {
        ELIGIBLE,
        NOT_MAX_LEVEL,
        HAS_DESERTER,
        NOT_ALIVE,
        IN_COMBAT,
        IN_INSTANCE,
        OTHER_ERROR
    };
    
    EligibilityResult CheckPlayerEligibility(Player* player, std::string& errorMessage)
    {
        if (!player)
        {
            errorMessage = "Player not found.";
            return OTHER_ERROR;
        }
        
        if (player->GetLevel() < sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
        {
            errorMessage = "You must be max level to participate.";
            return NOT_MAX_LEVEL;
        }
        
        if (player->HasAura(26013)) // Deserter debuff
        {
            errorMessage = "You cannot participate while flagged as deserter.";
            return HAS_DESERTER;
        }
        
        if (!player->IsAlive())
        {
            errorMessage = "You must be alive to participate.";
            return NOT_ALIVE;
        }
        
        if (player->IsInCombat())
        {
            errorMessage = "You cannot participate while in combat.";
            return IN_COMBAT;
        }
        
        if (Map* map = player->GetMap())
        {
            if (map->IsDungeon() || map->IsRaid() || map->IsBattlegroundOrArena())
            {
                errorMessage = "You cannot participate from inside an instance.";
                return IN_INSTANCE;
            }
        }
        
        return ELIGIBLE;
    }
    
    // Batch message sending to avoid repeated operations
    void SendMessageToZonePlayers(const std::string& message)
    {
        OutdoorPvPHL* hl = GetHinterlandBG();
        if (!hl)
            return;
            
        std::vector<Player*> zonePlayers;
        hl->CollectZonePlayers(zonePlayers);
        
        for (Player* player : zonePlayers)
        {
            ChatHandler(player->GetSession()).SendSysMessage(message.c_str());
        }
    }
    
    // Enhanced logging with HLBG context
    void LogHLBG(const std::string& category, const std::string& message)
    {
        LOG_INFO("bg.battleground", "HLBG [{}]: {}", category, message);
    }
    
    void LogHLBGDebug(const std::string& category, const std::string& message)
    {
        LOG_DEBUG("bg.battleground", "HLBG [{}]: {}", category, message);
    }
    
    void LogHLBGError(const std::string& category, const std::string& message)
    {
        LOG_ERROR("bg.battleground", "HLBG [{}]: {}", category, message);
    }
} // namespace HLBGUtils