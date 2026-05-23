#ifndef DC_HLBG_SERVICE_H
#define DC_HLBG_SERVICE_H

#include "SharedDefines.h"

#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <vector>

class BattlegroundHLBG;
class Player;

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
        uint8 affixCode, uint32 weatherType, float weatherIntensity,
        uint32 durationSeconds);
    void RecordManualReset(uint32 mapId, uint32 allianceScore,
        uint32 hordeScore, uint8 affixCode, uint32 weatherType,
        float weatherIntensity, uint32 durationSeconds);

private:
    HLBGService();

    void LoadRecentWinners();
    void RecordResult(TeamId winnerTeamId, uint32 mapId,
        uint32 allianceScore, uint32 hordeScore, char const* reason,
        uint8 affixCode, uint32 weatherType, float weatherIntensity,
        uint32 durationSeconds);

    mutable std::mutex _mutex;
    uint32 _season = 1u;
    bool _statsIncludeManualResets = true;
    std::deque<TeamId> _recentWinners;
};

#endif