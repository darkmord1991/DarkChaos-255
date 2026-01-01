/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_PLUS_RUN_MANAGER_H
#define MYTHIC_PLUS_RUN_MANAGER_H

#include "Config.h"
#include "GameObject.h"
#include "MythicDifficultyScaling.h"
#include "MythicPlusConstants.h"
#include "ObjectGuid.h"
#include "Optional.h"
#include "SharedDefines.h"
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <vector>

class Creature;
class GameObject;
class Map;
class Player;
class Unit;
struct DungeonProfile;

struct KeystoneDescriptor
{
    uint32 mapId = 0;
    uint8 level = 0;
    uint32 seasonId = 0;
    uint64 expiresOn = 0;
    ObjectGuid ownerGuid;
};

class MythicPlusRunManager
{
public:
    // Define InstanceState first so it can be used in method signatures
    struct InstanceState
    {
        uint64 instanceKey = 0;
        uint32 mapId = 0;
        uint32 instanceId = 0;
        Difficulty difficulty = DUNGEON_DIFFICULTY_NORMAL;
        uint8 keystoneLevel = 0;
        uint32 seasonId = 0;
        ObjectGuid ownerGuid;
        uint64 startedAt = 0;
        uint8 deaths = 0;
        uint8 wipes = 0;
        uint32 npcsKilled = 0;         // Total non-boss hostile creatures killed
        uint32 bossesKilled = 0;       // Boss creatures killed
        uint32 tokensAwarded = 0;      // Total tokens awarded to keystone owner
        std::vector<uint64> bossDeathTimes; // Timestamps of boss deaths for statistics
        std::map<uint32, uint32> deathsByPlayer; // Player GUID Low -> Count
        std::map<uint32, uint32> deathsByBoss;   // Boss Entry -> Count (deaths during encounter)
        uint8 upgradeLevel = 0;        // New keystone level after upgrade
        bool failed = false;
        bool completed = false;
        bool tokensGranted = false;
        bool keystoneUpgraded = false; // Tracks if keystone was upgraded
        uint64 abandonedAt = 0;  // Timestamp when last player left
        bool cancellationPending = false;
        uint64 countdownStarted = 0;  // Timestamp when countdown began
        bool countdownActive = false;
        std::unordered_set<ObjectGuid::LowType> participants;
        std::unordered_set<ObjectGuid::LowType> cancellationVotes;  // Players who voted to cancel
        uint64 cancellationVoteStarted = 0;  // Timestamp when first vote was cast
        std::unordered_set<uint32> lootGrantedBosses; // Prevent duplicate loot generation per boss (spawnId fallback to entry)
        bool finalBossLootGranted = false;
        std::unordered_map<uint32, uint64> recentBossEvades; // Tracks per-boss reset timestamps
        uint64 timerEndsAt = 0;
        uint64 lastHudBroadcast = 0;
        uint64 lastAioBroadcast = 0;
        uint32 hudTimerDuration = 0;
        bool hudInitialized = false;
        std::unordered_map<uint32, uint32> hudWorldStates;
        std::vector<uint32> bossOrder;
        std::unordered_map<uint32, uint8> bossIndexLookup;
        std::unordered_map<uint32, uint64> bossKillStamps;
        std::vector<uint32> activeAffixes;
        std::string lastHudPayload;
    };

    // Public methods
    static MythicPlusRunManager* instance();

    void Reset();

    // Keystone lifecycle
    bool TryActivateKeystone(Player* player, GameObject* font);
    bool CanActivateKeystone(Player* player, GameObject* font, KeystoneDescriptor& outDescriptor, std::string& outErrorText);
    uint32 GetKeystoneLevel(Map* map) const;

    // Participation tracking
    void RegisterPlayerEnter(Player* player);
    void HandlePlayerDeath(Player* player, Creature* killer);
    void HandleBossEvade(Creature* creature);
    void HandleBossDeath(Creature* creature, Unit* killer);
    void HandleCreatureKill(Creature* creature, Unit* killer);
    void HandleInstanceReset(Map* map);
    bool IsBossCreature(const Creature* creature) const;
    bool IsRecognizedBoss(uint32 mapId, uint32 bossEntry) const;

    // Weekly vault + statistics NPC support
    void BuildVaultMenu(Player* player, Creature* creature);
    void HandleVaultSelection(Player* player, Creature* creature, uint32 actionId);
    void BuildStatisticsMenu(Player* player, Creature* creature);
    void ResetWeeklyVaultProgress();
    void ResetWeeklyVaultProgress(Player* player);

    // Vault reward pool management
    bool GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);
    std::vector<std::tuple<uint8, uint32, uint32>> GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);
    bool ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId);
    uint32 GetCurrentSeasonId() const;
    uint32 GetWeekStartTimestamp() const;
    uint32 GetVaultTokenReward(uint8 slot) const;
    uint8 GetVaultThreshold(uint8 slot) const;

    // Keystone item management (NEW)
    uint8 GetPlayerKeystoneLevel(ObjectGuid::LowType playerGuid) const;
    bool GiveKeystoneToPlayer(Player* player, uint8 keystoneLevel);
    void CompleteRun(Map* map, bool successful);
    void UpgradeKeystone(ObjectGuid::LowType playerGuid);
    void DowngradeKeystone(ObjectGuid::LowType playerGuid);
    void GenerateNewKeystone(ObjectGuid::LowType playerGuid, uint8 level);

    // Run cancellation and management
    void InitiateCancellation(Map* map);
    void ProcessCancellationTimers();
    void ProcessCountdowns();
    void ProcessHudUpdates();
    bool VoteToCancelRun(Player* player, Map* map);
    void ProcessCancellationVotes();
    bool IsFinalBoss(uint32 mapId, uint32 bossEntry) const;

    // Boss loot generation (retail-like spec-based drops)
    void GenerateBossLoot(Creature* boss, Map* map, InstanceState* state);
    uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel) const;
    uint32 GetTotalBossesForDungeon(uint32 mapId) const;
    bool IsMythicPlusActive(Map* map) const;
    bool IsMythicPlusDungeon(uint32 mapId) const;
    bool ShouldSuppressLoot(Creature* creature) const;
    bool ShouldSuppressReputation(Player* player) const;

    // Spectator support - read-only state access
    InstanceState const* GetRunState(Map* map) const;

    // Debug/Testing
    void SimulateRun(Player* player, uint8 level, bool success);

private:
    MythicPlusRunManager() = default;

    uint64 MakeInstanceKey(const Map* map) const;
    InstanceState* GetOrCreateState(Map* map);
    InstanceState* GetState(Map* map);
    InstanceState const* GetState(Map* map) const;
    void RegisterGroupMembers(Player* activator, InstanceState* state);
    bool LoadPlayerKeystone(Player* player, uint32 expectedMap, KeystoneDescriptor& outDescriptor);
    void ConsumePlayerKeystone(ObjectGuid::LowType playerGuidLow);
    void AnnounceToInstance(Map* map, std::string_view message) const;
    void ApplyEntryBarrier(Map* map) const;
    void ApplyCountdownRoot(Map* map) const;
    void ApplyKeystoneScaling(Map* map, uint8 keystoneLevel) const;
    void HandleFailState(InstanceState* state, std::string_view reason, bool downgradeKeystone);
    bool IsDeathBudgetEnabled() const;
    bool IsWipeBudgetEnabled() const;
    bool IsKeystoneRequirementEnabled() const;
    void CacheBossMetadata();
    void RecordRunResult(const InstanceState* state, bool success, uint32 bossEntry);
    void AwardTokens(InstanceState* state, uint32 bossEntry);
    void UpdateWeeklyVault(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds);
    void UpdateScore(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint32 score, uint32 durationSeconds);
    void InsertRunHistory(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds, uint32 score, const std::string& groupMembers);
    void SendRunSummary(InstanceState* state, Player* player);
    void AutoUpgradeKeystone(InstanceState* state);
    void ProcessAchievements(InstanceState* state, Player* player, bool success);
    void InsertTokenLog(ObjectGuid::LowType playerGuid, uint32 mapId, Difficulty difficulty, uint8 keystoneLevel, uint8 playerLevel, uint32 bossEntry, uint32 tokenCount);
    void SendVaultError(Player* player, std::string_view text);
    void SendGenericError(Player* player, std::string_view text);
    bool ClaimVaultSlot(Player* player, uint8 slot);
    std::string SerializeParticipants(const InstanceState* state) const;

    // Teleportation helpers
    void TeleportGroupToEntrance(Player* activator, Map* map);
    void TeleportPlayerToEntrance(Player* player, Map* map);
    void StartRunAfterCountdown(InstanceState* state, Map* map, Player* activator);
    bool IsFinalBossEncounter(const InstanceState* state, const Creature* creature) const;

    // Seasonal validation and affix system (NEW)
    bool IsDungeonFeaturedThisSeason(uint32 mapId, uint32 seasonId) const;
    std::vector<uint32> GetWeeklyAffixes(uint32 seasonId) const;
    void ActivateAffixes(Map* map, const std::vector<uint32>& affixes, uint8 keystoneLevel);
    void AnnounceAffixes(Player* player, const std::vector<uint32>& affixes);
    std::string GetAffixName(uint32 affixId) const;
    void InitializeHud(InstanceState* state, Map* map);
    void BuildBossTracking(InstanceState* state);
    void SetHudWorldState(InstanceState* state, Map* map, uint32 worldStateId, uint32 value);
    void SyncHudToPlayer(InstanceState* state, Player* player) const;
    void UpdateHud(InstanceState* state, Map* map, bool forceBroadcast, std::string_view reason = {});
    void ProcessHudUpdatesInternal(InstanceState* state, Map* map);
    uint32 GetHudTimerDuration(uint32 mapId, uint8 keystoneLevel) const;
    void MaybeSendAioSnapshot(InstanceState* state, Map* map, std::string_view reason);
    void EnsureHudCacheTable();
    void PersistHudSnapshot(InstanceState* state, std::string_view payload, bool forceUpdate);
    void ClearHudSnapshot(InstanceState* state);
    int32 GetBossIndex(InstanceState const* state, uint32 bossEntry) const;
    void MarkBossKilled(InstanceState* state, Map* map, uint32 bossEntry);
    std::string GetMapDisplayName(uint32 mapId) const;
    uint32 GetBestRunDuration(uint32 mapId, uint8 keystoneLevel);
    void UpdateBestRunDuration(uint32 mapId, uint8 keystoneLevel, uint32 durationSeconds);
    uint64 MakeBestRunCacheKey(uint32 mapId, uint8 keystoneLevel) const;

    std::unordered_map<uint64, InstanceState> _instanceStates;
    std::unordered_map<uint32, std::unordered_set<uint32>> _mapBossEntries;
    std::unordered_map<uint32, std::unordered_set<uint32>> _mapFinalBossEntries;
    bool _hudCacheReady = false;
    std::unordered_map<uint64, uint32> _bestRunDurationCache;
};

inline bool MythicPlusRunManager::CanActivateKeystone(Player* player, GameObject* font, KeystoneDescriptor& outDescriptor, std::string& outErrorText)
{
    outErrorText.clear();

    if (!player || !font)
    {
        outErrorText = "Invalid keystone activation request.";
        return false;
    }

    if (!IsKeystoneRequirementEnabled())
    {
        outErrorText = "Mythic+ keystones are currently disabled.";
        return false;
    }

    Map* map = font->GetMap();
    if (!map || !map->IsDungeon())
    {
        outErrorText = "The Font of Power must be used inside a dungeon instance.";
        return false;
    }

    if (sMythicScaling->ResolveDungeonDifficulty(map) != DUNGEON_DIFFICULTY_EPIC)
    {
        outErrorText = "Set the instance to Mythic difficulty before activating a keystone.";
        return false;
    }

    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
    if (!profile || !profile->mythicEnabled)
    {
        outErrorText = "This dungeon is not configured for Mythic+ runs yet.";
        return false;
    }

    if (!LoadPlayerKeystone(player, map->GetId(), outDescriptor))
    {
        outErrorText = "You do not possess a valid keystone for this dungeon.";
        return false;
    }

    if (outDescriptor.level == 0)
    {
        outErrorText = "Keystone data is invalid. Please relog or contact a GM.";
        return false;
    }

    uint32 seasonId = outDescriptor.seasonId ? outDescriptor.seasonId : GetCurrentSeasonId();
    if (sConfigMgr->GetOption<bool>("MythicPlus.FeaturedOnly", true) && !IsDungeonFeaturedThisSeason(map->GetId(), seasonId))
    {
        outErrorText = "This dungeon is not featured in the current Mythic+ season.";
        return false;
    }

    if (InstanceState* state = GetState(map))
    {
        if (state->keystoneLevel > 0 && !state->failed && !state->completed)
        {
            outErrorText = "A keystone is already active in this instance.";
            return false;
        }
    }

    return true;
}

#define sMythicRuns MythicPlusRunManager::instance()

#endif // MYTHIC_PLUS_RUN_MANAGER_H
