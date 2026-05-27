#include "HLBGService.h"

#include "DC/CrossSystem/CrossSystemSeasonHelper.h"
#include "BattlegroundHLBG.h"
#include "Battlegrounds/BattlegroundMgr.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "hlbg_constants.h"
#include "Player.h"

namespace
{
    constexpr std::size_t HLBGRecentWinnerLimit = 10;
}

HLBGService& HLBGService::Instance()
{
    static HLBGService instance;
    return instance;
}

HLBGService::HLBGService()
{
    ReloadConfig();
    LoadRecentWinners();
}

BattlegroundHLBG* HLBGService::GetActiveBattleground(Player* preferredPlayer) const
{
    if (preferredPlayer)
    {
        if (Battleground* battleground = preferredPlayer->GetBattleground())
        {
            if (battleground->GetBgTypeID(true) == BATTLEGROUND_HLBG)
                return dynamic_cast<BattlegroundHLBG*>(battleground);
        }
    }

    BattlegroundHLBG* selected = nullptr;
    for (Battleground const* battleground : sBattlegroundMgr->GetActiveBattlegrounds())
    {
        if (!battleground || battleground->GetBgTypeID(true) != BATTLEGROUND_HLBG)
            continue;

        auto* hlbg = const_cast<BattlegroundHLBG*>(
            dynamic_cast<BattlegroundHLBG const*>(battleground));
        if (!hlbg)
            continue;

        if (!selected || hlbg->GetStatus() == STATUS_IN_PROGRESS)
            selected = hlbg;

        if (hlbg->GetStatus() == STATUS_IN_PROGRESS)
            break;
    }

    return selected;
}

void HLBGService::ReloadConfig()
{
    if (!sConfigMgr)
        return;

    std::lock_guard<std::mutex> lock(_mutex);
    _season = DarkChaos::GetActiveSeasonId();
    _statsIncludeManualResets = sConfigMgr->GetOption<bool>(
        "HinterlandBG.Stats.IncludeManual", _statsIncludeManualResets);
}

uint32 HLBGService::GetSeason() const
{
    std::lock_guard<std::mutex> lock(_mutex);
    return _season;
}

bool HLBGService::GetStatsIncludeManualResets() const
{
    std::lock_guard<std::mutex> lock(_mutex);
    return _statsIncludeManualResets;
}

void HLBGService::SetStatsIncludeManualResets(bool include)
{
    std::lock_guard<std::mutex> lock(_mutex);
    _statsIncludeManualResets = include;
}

std::vector<TeamId> HLBGService::GetRecentWinners(std::size_t maxCount) const
{
    std::vector<TeamId> winners;
    std::lock_guard<std::mutex> lock(_mutex);
    maxCount = std::min(maxCount, _recentWinners.size());
    winners.reserve(maxCount);
    for (std::size_t index = 0; index < maxCount; ++index)
        winners.push_back(_recentWinners[index]);
    return winners;
}

TeamId HLBGService::GetLastWinnerTeamId() const
{
    std::lock_guard<std::mutex> lock(_mutex);
    return _recentWinners.empty() ? TEAM_NEUTRAL : _recentWinners.front();
}

void HLBGService::LoadRecentWinners()
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT winner_tid FROM dc_hlbg_winner_history "
        "WHERE winner_tid IN ({}, {}) ORDER BY id DESC LIMIT {}",
        uint8(TEAM_ALLIANCE), uint8(TEAM_HORDE), HLBGRecentWinnerLimit);

    if (!result)
        return;

    std::lock_guard<std::mutex> lock(_mutex);
    _recentWinners.clear();
    do
    {
        TeamId winnerTeamId = static_cast<TeamId>(result->Fetch()[0].Get<uint8>());
        if (winnerTeamId == TEAM_ALLIANCE || winnerTeamId == TEAM_HORDE)
            _recentWinners.push_back(winnerTeamId);
    }
    while (result->NextRow());
}

void HLBGService::RecordWinner(TeamId winnerTeamId, uint32 mapId,
    uint32 allianceScore, uint32 hordeScore, char const* reason,
    uint8 affixCodePrimary, uint8 affixCodeSecondary,
    uint8 affixCodeTertiary, uint32 weatherType, float weatherIntensity,
    uint32 durationSeconds)
{
    RecordResult(winnerTeamId, mapId, allianceScore, hordeScore, reason,
        affixCodePrimary, affixCodeSecondary, affixCodeTertiary,
        weatherType, weatherIntensity, durationSeconds);
}

void HLBGService::RecordManualReset(uint32 mapId, uint32 allianceScore,
    uint32 hordeScore, uint8 affixCodePrimary, uint8 affixCodeSecondary,
    uint8 affixCodeTertiary, uint32 weatherType,
    float weatherIntensity, uint32 durationSeconds)
{
    RecordResult(TEAM_NEUTRAL, mapId, allianceScore, hordeScore, "manual",
        affixCodePrimary, affixCodeSecondary, affixCodeTertiary,
        weatherType, weatherIntensity, durationSeconds);
}

void HLBGService::RecordResult(TeamId winnerTeamId, uint32 mapId,
    uint32 allianceScore, uint32 hordeScore, char const* reason,
    uint8 affixCodePrimary, uint8 affixCodeSecondary,
    uint8 affixCodeTertiary, uint32 weatherType, float weatherIntensity,
    uint32 durationSeconds)
{
    uint8 persistedWinner = winnerTeamId == TEAM_ALLIANCE
        ? uint8(TEAM_ALLIANCE)
        : (winnerTeamId == TEAM_HORDE ? uint8(TEAM_HORDE) : uint8(TEAM_NEUTRAL));

    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (winnerTeamId == TEAM_ALLIANCE || winnerTeamId == TEAM_HORDE)
        {
            _recentWinners.push_front(winnerTeamId);
            while (_recentWinners.size() > HLBGRecentWinnerLimit)
                _recentWinners.pop_back();
        }
    }

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(
        CHAR_INS_HLBG_WINNER_HISTORY);
    stmt->SetData(0, HinterlandBGConstants::HLBG_AREA_ID);
    stmt->SetData(1, mapId);
    stmt->SetData(2, GetSeason());
    stmt->SetData(3, persistedWinner);
    stmt->SetData(4, allianceScore);
    stmt->SetData(5, hordeScore);
    stmt->SetData(6, std::string(reason ? reason : "unknown"));
    stmt->SetData(7, affixCodePrimary);
    stmt->SetData(8, affixCodeSecondary);
    stmt->SetData(9, affixCodeTertiary);
    stmt->SetData(10, weatherType);
    stmt->SetData(11, weatherIntensity);
    stmt->SetData(12, durationSeconds);
    CharacterDatabase.Execute(stmt);
}