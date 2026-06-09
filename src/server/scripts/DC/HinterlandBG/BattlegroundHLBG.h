#ifndef DC_BATTLEGROUND_HLBG_H
#define DC_BATTLEGROUND_HLBG_H

#include "Battleground.h"
#include "Position.h"
#include "hlbg_constants.h"

#include <array>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <vector>

extern BattlegroundTypeId BATTLEGROUND_HLBG;
extern BattlegroundQueueTypeId BATTLEGROUND_QUEUE_HLBG;

class BattlegroundHLBG final : public Battleground
{
public:
    BattlegroundHLBG();
    ~BattlegroundHLBG() override = default;

    [[nodiscard]] bool ShouldUseBattlegroundRaid() const override { return false; }
    void AddPlayer(Player* player) override;
    void RemovePlayer(Player* player) override;
    void HandleKillPlayer(Player* player, Player* killer) override;
    void HandleKillUnit(Creature* unit, Player* killer) override;
    void StartingEventCloseDoors() override;
    void StartingEventOpenDoors() override;
    bool SetupBattleground() override;
    void Init() override;
    void EndBattleground(TeamId winnerTeamId) override;
    void FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet) override;
    TeamId GetPrematureWinner() override;

    void NotePlayerMovement(Player* player);
    void AdminSetResources(TeamId teamId, uint32 amount);
    void AdminResetMatch(bool recordManualReset = true);
    void AdminFinishMatch(TeamId winnerTeamId);

    bool IsPlayerAfkFlagged(Player* player) const;
    uint32 GetTimeRemainingSeconds() const;
    uint32 GetMatchStartEpoch() const { return _matchStartEpoch; }
    uint32 GetCurrentMatchDurationSeconds() const;
    uint32 GetResources(TeamId teamId) const;
    uint32 GetPlayerContributionScore(ObjectGuid const& guid) const;
    uint32 GetPlayerHKDelta(Player* player) const;
    uint32 GetNpcKillCount(TeamId teamId) const;
    uint8 GetActiveAffixCode() const { return GetActiveAffixCode(0u); }
    uint8 GetActiveAffixCode(uint32 slot) const { return slot < _activeAffixes.size() ? _activeAffixes[slot] : 0u; }
    bool IsAffixEnabled() const { return _affixEnabled; }
    bool IsAffixWeatherEnabled() const { return _affixWeatherEnabled; }
    bool IsAffixWorldstateEnabled() const { return _affixWorldstateEnabled; }
    bool IsAffixAnnounceEnabled() const { return _affixAnnounce; }
    bool IsAffixRandomOnStart() const { return _affixRandomOnStart; }
    uint32 GetAffixPeriodSec() const { return _affixPeriodSec; }
    uint32 GetAffixNextChangeEpoch() const { return _affixNextChangeEpoch; }
    uint32 GetAffixPlayerSpell(uint8 code) const;
    uint32 GetAffixNpcSpell(uint8 code) const;
    uint32 GetAffixWeatherType(uint8 code) const;
    float GetAffixWeatherIntensity(uint8 code) const;

private:
    void PostUpdateImpl(uint32 diff) override;

    void LoadConfig();
    void InitAffixDefaults();
    void ResetMatchState();
    void ResetMapActors() const;
    void SetTeamResources(TeamId teamId, uint32 amount);
    void ModifyTeamResources(TeamId teamId, int32 delta);
    bool TryEndOnDepletedResources();
    void SyncResourceState() const;
    void TickAfk(uint32 diff);
    void UpdateWorldStatesForPlayer(Player* player) const;
    void UpdateWorldStatesForAll() const;
    void SendStatusSnapshotToPlayer(Player* player) const;
    void SendStatusSnapshotToAll() const;
    void SendHudHidden(Player* player) const;
    void SendAffixSnapshotToPlayer(Player* player) const;
    void SendAffixSnapshotToAll() const;
    void ClearAffixEffects();
    void ApplyAffixEffects();
    void ApplyAffixWeather() const;
    void SelectAffixForNewBattle();
    void RewardMatchOutcome(TeamId winnerTeamId);
    void RewardRandomKillHonor(Player* player);
    void RewardPlayerKill(Player* killer, Player* victim, uint32 scorePoints);
    void RewardNpcKill(Player* killer, Creature* unit, uint32 scorePoints, TeamId victimTeam, bool isBossKill);
    void AddPlayerContributionScore(ObjectGuid const& guid, uint32 points);
    void TeleportPlayerToTeamStart(Player* player) const;
    void ResetPlayerTracking(Player* player);
    void ClearPlayerTracking(Player* player);
    bool IsEligibleForRewards(Player* player) const;
    bool ClassifyNpc(uint32 entry, TeamId& victimTeam, uint32& scorePoints) const;
    uint32 GetHudEndEpoch() const;
    uint64 ComputeHudSnapshotKey() const;

    uint32 _matchDurationSeconds = 60u * 60u;
    uint32 _afkWarnSeconds = 120u;
    uint32 _afkTeleportSeconds = 180u;
    uint32 _initialResourcesAlliance = 450u;
    uint32 _initialResourcesHorde = 450u;
    uint32 _rewardMatchHonorDepletion = 1500u;
    uint32 _rewardMatchHonorTiebreaker = 750u;
    uint32 _rewardMatchHonorLoser = 0u;
    std::vector<uint32> _killHonorValues;
    uint32 _rewardKillItemId = 40752u;
    uint32 _rewardKillItemCount = 1u;
    uint32 _rewardNpcTokenItemId = 40752u;
    uint32 _rewardNpcTokenCount = 1u;
    uint32 _resourcesLossPlayerKill = 5u;
    uint32 _resourcesLossNpcNormal = 5u;
    uint32 _resourcesLossNpcBoss = 200u;

    uint32 _matchStartEpoch = 0u;
    uint32 _matchEndEpoch = 0u;
    uint32 _hudSyncTimerMs = 0u;
    uint32 _hudMsSinceBroadcast = 0u;
    uint64 _lastHudSnapshotKey = 0u;
    uint32 _afkCheckTimerMs = 0u;
    uint32 _allianceNpcKills = 0u;
    uint32 _hordeNpcKills = 0u;
    uint32 _affixRotationTimerMs = 0u;
    uint32 _affixNextChangeEpoch = 0u;
    bool _endedByDepletion = false;
    bool _matchRewardsGranted = false;
    bool _matchResultRecorded = false;
    bool _affixEnabled = true;
    bool _affixWeatherEnabled = true;
    bool _affixWorldstateEnabled = true;
    bool _affixAnnounce = true;
    bool _affixRandomOnStart = true;
    uint32 _affixPeriodSec = 0u;
    uint32 _affixConcurrentCount = 1u;
    std::array<uint8, 3> _activeAffixes{};
    float _affixWeatherIntensityVariance = 0.20f;
    float _activeAffixWeatherIntensity = 0.0f;

    std::unordered_set<uint32> _afkFlagged;
    std::unordered_map<uint32, uint8> _afkInfractions;
    std::map<ObjectGuid, uint32> _playerLastMove;
    std::map<ObjectGuid, bool> _playerWarnedBeforeTeleport;
    std::map<ObjectGuid, Position> _playerLastPos;
    mutable std::map<ObjectGuid, uint32> _playerHKBaseline;
    std::map<ObjectGuid, uint32> _playerScores;

    std::vector<uint32> _npcRewardEntriesAlliance;
    std::vector<uint32> _npcRewardEntriesHorde;
    std::unordered_map<uint32, uint32> _npcRewardCountsAlliance;
    std::unordered_map<uint32, uint32> _npcRewardCountsHorde;
    std::unordered_set<uint32> _npcBossEntriesAlliance;
    std::unordered_set<uint32> _npcBossEntriesHorde;
    std::unordered_set<uint32> _npcNormalEntriesAlliance;
    std::unordered_set<uint32> _npcNormalEntriesHorde;
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixPlayerSpell{};
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixNpcSpell{};
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixWeatherType{};
    std::array<float, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixWeatherIntensity{};
};

#endif