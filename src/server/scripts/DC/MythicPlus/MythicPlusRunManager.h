/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_PLUS_RUN_MANAGER_H
#define MYTHIC_PLUS_RUN_MANAGER_H

#include "ObjectGuid.h"
#include "Optional.h"
#include "SharedDefines.h"
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>

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
    static MythicPlusRunManager* instance();

    void Reset();

    // Keystone lifecycle
    bool TryActivateKeystone(Player* player, GameObject* font);
    uint32 GetKeystoneLevel(Map* map) const;

    // Participation tracking
    void RegisterPlayerEnter(Player* player);
    void HandlePlayerDeath(Player* player, Creature* killer);
    void HandleBossEvade(Creature* creature);
    void HandleBossDeath(Creature* creature, Unit* killer);
    void HandleInstanceReset(Map* map);

    // Weekly vault + statistics NPC support
    void BuildVaultMenu(Player* player, Creature* creature);
    void HandleVaultSelection(Player* player, Creature* creature, uint32 actionId);
    void BuildStatisticsMenu(Player* player, Creature* creature);
    void ResetWeeklyVaultProgress();
    void ResetWeeklyVaultProgress(Player* player);
    
    // Vault reward pool management
    bool GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart, uint8 highestKeystoneLevel);
    std::vector<std::pair<uint32, uint32>> GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);
    bool ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId);
    uint32 GetCurrentSeasonId() const;
    uint32 GetWeekStartTimestamp() const;
    uint32 GetVaultTokenReward(uint8 slot) const;
    uint8 GetVaultThreshold(uint8 slot) const;

private:
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
        bool failed = false;
        bool completed = false;
        bool tokensGranted = false;
        std::unordered_set<ObjectGuid::LowType> participants;
    };

    MythicPlusRunManager() = default;

    uint64 MakeInstanceKey(const Map* map) const;
    InstanceState* GetOrCreateState(Map* map);
    InstanceState* GetState(Map* map);
    void RegisterGroupMembers(Player* activator, InstanceState* state);
    bool LoadPlayerKeystone(Player* player, uint32 expectedMap, KeystoneDescriptor& outDescriptor);
    void ConsumePlayerKeystone(ObjectGuid::LowType playerGuidLow);
    void AnnounceToInstance(Map* map, std::string_view message) const;
    void HandleFailState(InstanceState* state, std::string_view reason, bool downgradeKeystone);
    bool IsDeathBudgetEnabled() const;
    bool IsWipeBudgetEnabled() const;
    bool IsKeystoneRequirementEnabled() const;
    void RecordRunResult(const InstanceState* state, bool success, uint32 bossEntry);
    void AwardTokens(InstanceState* state, uint32 bossEntry);
    void UpdateWeeklyVault(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds);
    void UpdateScore(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint32 score, uint32 durationSeconds);
    void InsertRunHistory(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds, uint32 score, const std::string& groupMembers);
    void InsertTokenLog(ObjectGuid::LowType playerGuid, uint32 mapId, Difficulty difficulty, uint8 keystoneLevel, uint8 playerLevel, uint32 bossEntry, uint32 tokenCount);
    void SendVaultError(Player* player, std::string_view text);
    void SendGenericError(Player* player, std::string_view text);
    bool ClaimVaultSlot(Player* player, uint8 slot);
    bool IsFinalBoss(uint32 mapId, uint32 bossEntry) const;
        std::string SerializeParticipants(const InstanceState* state) const;

    std::unordered_map<uint64, InstanceState> _instanceStates;
        std::unordered_map<uint32, std::unordered_set<uint32>> _finalBossEntries;
};

#define sMythicRuns MythicPlusRunManager::instance()

#endif // MYTHIC_PLUS_RUN_MANAGER_H
