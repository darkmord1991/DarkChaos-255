#ifndef DC_BATTLEGROUND_HLBG_H
#define DC_BATTLEGROUND_HLBG_H

#include "Battleground.h"
#include "Position.h"

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
    void AdminResetMatch();
    void AdminFinishMatch(TeamId winnerTeamId);

    bool IsPlayerAfkFlagged(Player* player) const;
    uint32 GetTimeRemainingSeconds() const;
    uint32 GetMatchStartEpoch() const { return _matchStartEpoch; }
    uint32 GetResources(TeamId teamId) const;
    uint32 GetPlayerContributionScore(ObjectGuid const& guid) const;
    uint32 GetPlayerHKDelta(Player* player) const;
    uint32 GetNpcKillCount(TeamId teamId) const;

private:
    void PostUpdateImpl(uint32 diff) override;

    void LoadConfig();
    void ResetMatchState();
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
    void RewardMatchOutcome(TeamId winnerTeamId);
    void RewardRandomKillHonor(Player* player) const;
    void RewardPlayerKill(Player* killer, Player* victim, uint32 scorePoints);
    void RewardNpcKill(Player* killer, Creature* unit, uint32 scorePoints, TeamId victimTeam);
    void AddPlayerContributionScore(ObjectGuid const& guid, uint32 points);
    void TeleportPlayerToTeamStart(Player* player) const;
    void ResetPlayerTracking(Player* player);
    void ClearPlayerTracking(Player* player);
    bool IsEligibleForRewards(Player* player) const;
    bool ClassifyNpc(uint32 entry, TeamId& victimTeam, uint32& scorePoints) const;
    uint32 GetHudEndEpoch() const;

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
    uint32 _afkCheckTimerMs = 0u;
    uint32 _allianceNpcKills = 0u;
    uint32 _hordeNpcKills = 0u;
    bool _endedByDepletion = false;
    bool _matchRewardsGranted = false;

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
};

#endif