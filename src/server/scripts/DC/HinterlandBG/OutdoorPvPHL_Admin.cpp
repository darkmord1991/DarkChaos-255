#include "HinterlandBG.h"

// --- Admin/inspection helpers ---

uint32 OutdoorPvPHL::GetTimeRemainingSeconds() const
{
    if (_matchEndTime == 0)
        return 0u;
    uint32 now = NowSec();
    if (now >= _matchEndTime)
        return 0u;
    return _matchEndTime - now;
}

uint32 OutdoorPvPHL::GetResources(TeamId team) const
{
    return (team == TEAM_ALLIANCE) ? _ally_gathered : _horde_gathered;
}

void OutdoorPvPHL::SetResources(TeamId team, uint32 amount)
{
    if (team == TEAM_ALLIANCE)
        _ally_gathered = amount;
    else
        _horde_gathered = amount;
    // Reflect changes on clients in-zone
    UpdateWorldStatesAllPlayers();
}

std::vector<ObjectGuid> const& OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
{
    if (team > TEAM_HORDE)
    {
        static const std::vector<ObjectGuid> empty;
        return empty;
    }
    return _teamRaidGroups[team];
}

void OutdoorPvPHL::ForceReset()
{
    HandleReset();
}
