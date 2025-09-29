// -----------------------------------------------------------------------------
// OutdoorPvPHL_Admin.cpp
// -----------------------------------------------------------------------------
// Admin/inspection helpers used by GM commands and status displays.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"

// --- Admin/inspection helpers ---

// Remaining seconds until the current match window expires (0 if expired/disabled).
uint32 OutdoorPvPHL::GetTimeRemainingSeconds() const
{
    if (_matchEndTime == 0)
        return 0u;
    uint32 now = NowSec();
    if (now >= _matchEndTime)
        return 0u;
    return _matchEndTime - now;
}

// Current resource total for the specified team.
uint32 OutdoorPvPHL::GetResources(TeamId team) const
{
    return (team == TEAM_ALLIANCE) ? _ally_gathered : _horde_gathered;
}

// Set resources for the specified team and refresh HUD for participants.
void OutdoorPvPHL::SetResources(TeamId team, uint32 amount)
{
    if (team == TEAM_ALLIANCE)
        _ally_gathered = amount;
    else
        _horde_gathered = amount;
    // Reflect changes on clients in-zone
    UpdateWorldStatesAllPlayers();
}

// Return tracked battleground raid group GUIDs for the team (may be empty).
std::vector<ObjectGuid> const& OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
{
    if (team > TEAM_HORDE)
    {
        static const std::vector<ObjectGuid> empty;
        return empty;
    }
    return _teamRaidGroups[team];
}

// Force an immediate zone reset (admin/commands).
void OutdoorPvPHL::ForceReset()
{
    HandleReset();
}
