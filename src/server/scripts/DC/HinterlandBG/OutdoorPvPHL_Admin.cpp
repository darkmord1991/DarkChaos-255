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

// Return up to maxCount most recent winners in most-recent-first order.
std::vector<TeamId> OutdoorPvPHL::GetRecentWinners(size_t maxCount) const
{
    std::vector<TeamId> out;
    if (maxCount == 0 || _recentWinners.empty())
        return out;
    size_t n = std::min(maxCount, _recentWinners.size());
    out.reserve(n);
    size_t i = 0;
    for (TeamId t : _recentWinners)
    {
        if (i++ >= n) break;
        out.push_back(t);
    }
    return out;
}

// Map legacy _LastWin integer to TeamId for external consumers.
TeamId OutdoorPvPHL::GetLastWinnerTeamId() const
{
    if (_LastWin == ALLIANCE)
        return TEAM_ALLIANCE;
    if (_LastWin == HORDE)
        return TEAM_HORDE;
    return TEAM_NEUTRAL;
}

uint8 OutdoorPvPHL::GetActiveAffixCode() const
{
    return static_cast<uint8>(_activeAffix);
}

uint32 OutdoorPvPHL::GetMatchStartEpoch() const
{
    return _matchStartTime;
}

uint32 OutdoorPvPHL::GetCurrentMatchDurationSeconds() const
{
    if (_matchStartTime == 0)
        return 0;
    uint32 now = NowSec();
    if (now < _matchStartTime)
        return 0;
    return now - _matchStartTime;
}

bool OutdoorPvPHL::GetStatsIncludeManualResets() const { return _statsIncludeManualResets; }
void OutdoorPvPHL::SetStatsIncludeManualResets(bool include) { _statsIncludeManualResets = include; }

uint32 OutdoorPvPHL::GetAffixPlayerSpell(uint8 code) const
{
    return (code <= 5) ? _affixPlayerSpell[code] : 0u;
}

uint32 OutdoorPvPHL::GetAffixNpcSpell(uint8 code) const
{
    return (code <= 5) ? _affixNpcSpell[code] : 0u;
}

uint32 OutdoorPvPHL::GetAffixWeatherType(uint8 code) const
{
    return (code <= 5) ? _affixWeatherType[code] : 0u;
}

float OutdoorPvPHL::GetAffixWeatherIntensity(uint8 code) const
{
    return (code <= 5) ? _affixWeatherIntensity[code] : 0.0f;
}

// Private helper: keep an in-memory ring buffer of last ~10 winners
void OutdoorPvPHL::_recordWinner(TeamId winner)
{
    if (winner != TEAM_ALLIANCE && winner != TEAM_HORDE)
        return;
    // push front, unique-consecutive not required; keep last 10
    _recentWinners.push_front(winner);
    while (_recentWinners.size() > 10)
        _recentWinners.pop_back();

    // Persist a row in characters DB for history
    // Note: CharacterDatabase is available globally; keep SQL minimal and safe.
    uint32 zone = OutdoorPvPHLBuffZones[0];
    uint32 mapId = 0;
    if (Map* m = GetMap())
        mapId = m->GetId();
    uint8 winnerTid = static_cast<uint8>(winner);
    uint32 a = _ally_gathered;
    uint32 h = _horde_gathered;
    const char* reason = (_horde_gathered == 0 || _ally_gathered == 0) ? "depletion" : "tiebreaker";
    uint8 aff = static_cast<uint8>(_activeAffix);
    uint32 dur = GetCurrentMatchDurationSeconds();
    // Weather info at the moment of result
    uint32 weather = GetAffixWeatherType(aff);
    float wint = GetAffixWeatherIntensity(aff);
    CharacterDatabase.Execute(
        "INSERT INTO hlbg_winner_history (zone_id, map_id, season, winner_tid, score_alliance, score_horde, win_reason, affix, weather, weather_intensity, duration_seconds) VALUES({}, {}, {}, {}, {}, {}, '{}', {}, {}, {}, {})",
        zone, mapId, _season, winnerTid, a, h, reason, aff, weather, wint, dur);
}
