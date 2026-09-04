#ifndef DC_HLBG_SERVICE_H
#define DC_HLBG_SERVICE_H

#include "SharedDefines.h"

#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

class BattlegroundHLBG;
class Player;

// One row of dc_hlbg_match_participants. `team` is a TeamId so it joins
// directly against dc_hlbg_winner_history.winner_tid - the column comment in
// that table claims 1=Horde/2=Alliance, but every leaderboard query in
// dc_addon_hlbg.cpp compares it to winner_tid, so TeamId is what it must hold.
struct HLBGMatchParticipant
{
    uint32 guid = 0;
    std::string playerName;
    uint32 accountId = 0;
    uint8 team = 0;
    uint32 kills = 0;
    uint32 deaths = 0;
    uint32 healingDone = 0;
    uint32 damageDone = 0;
    uint32 resourcesCaptured = 0;
};

class HLBGService
{
public:
    static HLBGService& Instance();

    BattlegroundHLBG* GetActiveBattleground(Player* preferredPlayer = nullptr) const;

    void ReloadConfig();

    uint32 GetSeason() const;
    bool GetStatsIncludeManualResets() const;
    void SetStatsIncludeManualResets(bool include);

    std::vector<TeamId> GetRecentWinners(std::size_t maxCount) const;
    TeamId GetLastWinnerTeamId() const;

    void RecordWinner(TeamId winnerTeamId, uint32 mapId,
        uint32 allianceScore, uint32 hordeScore, char const* reason,
        uint8 affixCodePrimary, uint8 affixCodeSecondary,
        uint8 affixCodeTertiary, uint32 weatherType, float weatherIntensity,
        uint32 durationSeconds,
        std::vector<HLBGMatchParticipant> const& participants = {});
    void RecordManualReset(uint32 mapId, uint32 allianceScore,
        uint32 hordeScore, uint8 affixCodePrimary, uint8 affixCodeSecondary,
        uint8 affixCodeTertiary, uint32 weatherType,
        float weatherIntensity, uint32 durationSeconds);

private:
    HLBGService();

    void LoadRecentWinners();
    void RecordResult(TeamId winnerTeamId, uint32 mapId,
        uint32 allianceScore, uint32 hordeScore, char const* reason,
        uint8 affixCodePrimary, uint8 affixCodeSecondary,
        uint8 affixCodeTertiary, uint32 weatherType, float weatherIntensity,
        uint32 durationSeconds,
        std::vector<HLBGMatchParticipant> const& participants);

    mutable std::mutex _mutex;
    uint32 _season = 1u;
    bool _statsIncludeManualResets = true;
    std::deque<TeamId> _recentWinners;
};

#endif