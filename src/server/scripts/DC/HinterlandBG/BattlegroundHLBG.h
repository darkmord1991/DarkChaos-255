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

// One pass over GetPlayers() per collection; the HUD tick collects once and
// feeds both the snapshot key and the broadcast (previously two passes).
struct HLBGHudMetrics
{
    uint32 alliancePlayers = 0;
    uint32 hordePlayers = 0;
    uint32 alliancePlayerKills = 0;
    uint32 hordePlayerKills = 0;
    uint32 allianceNpcKills = 0;
    uint32 hordeNpcKills = 0;
};

class BattlegroundHLBG final : public Battleground
{
public:
    BattlegroundHLBG();
    ~BattlegroundHLBG() override = default;

    // Inherited "false" from the OutdoorPvP conversion, which left HLBG the only
    // battleground whose players are never grouped. Everything in the bot AI that
    // helps a teammate resolves through PartyMemberValue::FindPartyMember, and
    // that falls back to a party of one when the bot has no group - so buffs,
    // heals, dispels and resurrects were all self-only here. See RewardPlayerKill
    // for the payout change that had to go with this.
    [[nodiscard]] bool ShouldUseBattlegroundRaid() const override { return true; }
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
    uint32 GetAffixWeatherState(uint8 code) const;
    float GetAffixWeatherIntensity(uint8 code) const;
    // True when the code occupies any of the active affix slots.
    bool IsAffixActive(uint8 code) const;

private:
    void PostUpdateImpl(uint32 diff) override;

    void LoadConfig();
    void InitAffixDefaults();
    void ResetMatchState();
    void ResetMapActors() const;
    void SetTeamResources(TeamId teamId, uint32 amount);
    void ModifyTeamResources(TeamId teamId, int32 delta);
    bool TryEndOnDepletedResources();
    // Marks the HUD dirty. The broadcast itself is coalesced into the next
    // HUD tick so a burst of kills costs one update, not one per kill.
    void SyncResourceState();
    void TickAfk(uint32 diff);
    void FlagPlayerAfk(Player* player);
    // Static world states only change when a player (re)enters the HUD; the
    // periodic broadcast sends the dynamic subset to keep packet volume down.
    void SendFullWorldStates(Player* player) const;
    void SendDynamicWorldStates(Player* player) const;
    void UpdateWorldStatesForPlayer(Player* player) const;
    void UpdateWorldStatesForAll() const;
    void SendStatusSnapshotToPlayer(Player* player) const;
    void SendStatusSnapshotToAll() const;
    void SendStatusSnapshotToAll(HLBGHudMetrics const& metrics) const;
    void SendHudHidden(Player* player) const;
    void SendAffixSnapshotToPlayer(Player* player) const;
    void SendAffixSnapshotToAll() const;
    void ClearAffixEffects();
    void ApplyAffixEffects();
    void ApplyAffixWeather() const;
    void ClearAffixWeather() const;
    void ApplyAffixLight() const;
    void ClearAffixLight() const;
    // Rule affixes retune the resource economy instead of casting a spell.
    uint32 GetEffectivePlayerKillLoss() const;
    uint32 GetEffectiveNpcLoss(uint32 baseLoss, bool isBoss) const;
    void ApplyAffixAurasToPlayer(Player* player) const;
    void RemoveAffixAurasFromPlayer(Player* player) const;
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
    bool ClassifyNpc(uint32 entry, TeamId& victimTeam, uint32& scorePoints, bool& isBoss) const;
    uint32 GetHudEndEpoch() const;
    uint64 ComputeHudSnapshotKey(HLBGHudMetrics const& metrics) const;

    uint32 _matchDurationSeconds = 30u * 60u;
    uint32 _afkWarnSeconds = 120u;
    uint32 _afkTeleportSeconds = 180u;
    uint32 _initialResourcesAlliance = 2500u;
    // Deliberately above the Alliance pool. The Horde camp fields 41 guards to
    // the Alliance camp's 35, and a guard kill drains its OWN team's pool, so
    // Horde bleeds 205 per respawn cycle against Alliance's 175 purely for being
    // better defended. See HinterlandBG.Resources.* in the config for the sizing.
    uint32 _initialResourcesHorde = 2600u;
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
    bool _hudDirty = false;
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
    uint32 _affixNightfallLightId = 2508u;
    uint32 _affixNightfallFadeSec = 5u;
    uint32 _affixWarlordsBossMultiplier = 2u;
    uint32 _affixBloodlustKillMultiplier = 2u;
    float _affixWeatherIntensityVariance = 0.20f;
    float _activeAffixWeatherIntensity = 0.0f;

    std::unordered_set<uint32> _afkFlagged;
    std::unordered_map<uint32, uint8> _afkInfractions;
    std::map<ObjectGuid, uint32> _playerLastMove;
    std::map<ObjectGuid, bool> _playerWarnedBeforeTeleport;
    std::map<ObjectGuid, Position> _playerLastPos;
    mutable std::map<ObjectGuid, uint32> _playerHKBaseline;
    std::map<ObjectGuid, uint32> _playerScores;

    std::unordered_set<uint32> _npcRewardEntriesAlliance;
    std::unordered_set<uint32> _npcRewardEntriesHorde;
    std::unordered_map<uint32, uint32> _npcRewardCountsAlliance;
    std::unordered_map<uint32, uint32> _npcRewardCountsHorde;
    std::unordered_set<uint32> _npcBossEntriesAlliance;
    std::unordered_set<uint32> _npcBossEntriesHorde;
    std::unordered_set<uint32> _npcNormalEntriesAlliance;
    std::unordered_set<uint32> _npcNormalEntriesHorde;
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixPlayerSpell{};
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixNpcSpell{};
    std::array<uint32, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixWeatherState{};
    std::array<float, HinterlandBGConstants::HLBG_AFFIX_STORAGE_SIZE> _affixWeatherIntensity{};
};

#endif