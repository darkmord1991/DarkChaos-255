#ifndef AZEROTHCORE_DC_PRESTIGE_API_H
#define AZEROTHCORE_DC_PRESTIGE_API_H

#include "Common.h"
#include <string>
#include <utility>
#include <vector>

class Player;

namespace PrestigeAPI
{
    // Core System
    bool IsEnabled();
    uint32 GetPrestigeLevel(Player* player);
    void SetPrestigeLevel(Player* player, uint32 level);
    uint32 GetMaxPrestigeLevel();
    uint32 GetRequiredLevel();
    uint32 GetStatBonusPercent();
    bool CanPrestige(Player* player);
    void ApplyPrestigeBuffs(Player* player);
    void RemovePrestigeBuffs(Player* player);
    bool PerformPrestige(Player* player);

    // Challenges
    bool IsChallengesEnabled();
    bool StartChallenge(Player* player, uint8 challengeType, uint32 prestigeLevel);
    std::string GetChallengeName(uint8 challengeType);
    struct ActiveChallengeInfo
    {
        uint8 type;
        uint32 prestigeLevel;
    };
    std::vector<ActiveChallengeInfo> GetActiveChallenges(Player* player);
    uint32 GetTotalChallengeStatBonus(Player* player);
    bool IsIronEnabled();
    bool IsSpeedEnabled();
    bool IsSoloEnabled();

    // Alt Bonus
    bool IsAltBonusEnabled();
    uint32 GetAltBonusPercent(Player* player);
    uint32 GetAccountMaxLevelCount(uint32 accountId);

    // Prestige Talents (dc_prestige_talents.cpp)
    // Modelled on the WoW Forever "Legacy" system. Points are earned ACCOUNT-WIDE from
    // two sources:
    //  - every prestige level on any character (Prestige.Talents.PointsPerPrestigeLevel)
    //  - "challenges": achievements mapped to points in world.dc_prestige_talent_challenges,
    //    counted once per account
    // Every character spends that pool independently, up to Prestige.Talents.MaxSpentPoints.
    // The account total (spent or not) also unlocks the reward track
    // (world.dc_prestige_talent_rewards), claimed once per account.
    enum PrestigeTalentTree : uint8
    {
        PRESTIGE_TREE_ASCENSION = 0,
        PRESTIGE_TREE_FORTUNE   = 1,
        PRESTIGE_TREE_MIGHT     = 2,
        MAX_PRESTIGE_TREES      = 3
    };

    enum PrestigeTalentEffect : uint8
    {
        PRESTIGE_EFFECT_XP_KILL_PCT = 0,     // kill XP
        PRESTIGE_EFFECT_XP_QUEST_PCT,        // quest + exploration XP
        PRESTIGE_EFFECT_XP_ALL_PCT,          // every XP source
        PRESTIGE_EFFECT_RESET_LEVEL_BONUS,   // levels added to Prestige.ResetLevel
        PRESTIGE_EFFECT_REPUTATION_PCT,
        PRESTIGE_EFFECT_LOOT_GOLD_PCT,
        PRESTIGE_EFFECT_REPAIR_DISCOUNT_PCT,
        PRESTIGE_EFFECT_PROFESSION_CHANCE_PCT, // chance of +1 extra skill point
        PRESTIGE_EFFECT_DAMAGE_DONE_PCT,
        PRESTIGE_EFFECT_DAMAGE_TAKEN_PCT,    // damage taken reduction
        PRESTIGE_EFFECT_BOSS_DAMAGE_PCT,     // extra damage vs world/dungeon bosses
        PRESTIGE_EFFECT_KILL_RESTORE_PCT,    // % max health + mana on killing blow
        MAX_PRESTIGE_EFFECTS
    };

    constexpr uint8 MAX_PRESTIGE_TALENT_PREREQS = 2;

    struct PrestigeTalentDef
    {
        uint16 id;
        PrestigeTalentTree tree;
        uint8 row;                  // 1-based layout row (top to bottom)
        uint8 column;               // 1-based layout column (1-3)
        uint8 maxRank;
        // Talent ids this node hangs off (0 = unused). The node unlocks once ANY of
        // them is at max rank; a node without prereqs is always available.
        uint16 prereqs[MAX_PRESTIGE_TALENT_PREREQS];
        PrestigeTalentEffect effect;
        float valuePerRank;
        char const* name;
        char const* description;    // "{v}" is replaced client-side with rank * valuePerRank
        char const* icon;
    };

    struct PrestigeChallengeDef
    {
        uint32 achievementId;
        uint32 points;
        std::string category;
        uint32 sortOrder;
    };

    struct PrestigeRewardDef
    {
        uint32 threshold;           // account points needed
        uint32 itemEntry;
        uint32 itemCount;
        std::string rewardType;     // mount / pet / tabard / item (display only)
    };

    struct PrestigeTalentSnapshot
    {
        bool loaded = false;
        uint32 prestigePoints = 0;  // from prestige levels
        uint32 challengePoints = 0; // from completed challenges
        uint32 accountPoints = 0;   // prestigePoints + challengePoints
        uint32 spendCap = 0;        // min(accountPoints, MaxSpentPoints)
        uint32 spent = 0;
        uint32 treeSpent[MAX_PRESTIGE_TREES] = {};
        std::vector<std::pair<uint16, uint8>> ranks; // talent id -> rank (only rank > 0)
        std::vector<uint32> completedChallenges;     // achievement ids
        std::vector<uint32> claimedRewards;          // thresholds
    };

    enum class PrestigeTalentResult : uint8
    {
        Ok = 0,
        Disabled,
        NotLoaded,
        UnknownTalent,
        MaxRank,
        NoPoints,
        TreeLocked,
        InCombat,
        NotEnoughGold,
        NothingToReset,
        NoChanges,
        CannotRefund,
        UnknownReward,
        RewardLocked,
        RewardClaimed,
        RewardFailed
    };

    bool IsTalentsEnabled();
    std::vector<PrestigeTalentDef> const& GetTalentDefinitions();
    std::vector<PrestigeChallengeDef> const& GetChallengeDefinitions();
    std::vector<PrestigeRewardDef> const& GetRewardDefinitions();
    char const* GetTalentTreeName(uint8 tree);
    char const* GetTalentTreeIcon(uint8 tree);
    PrestigeTalentSnapshot GetTalentSnapshot(Player* player);
    PrestigeTalentResult LearnTalent(Player* player, uint16 talentId);
    // Commits a staged allocation in one go. `target` holds the wanted rank per
    // talent id; ranks may only go up (refunds go through ResetTalents).
    PrestigeTalentResult ApplyTalents(Player* player, std::vector<std::pair<uint16, uint8>> const& target);
    PrestigeTalentResult ResetTalents(Player* player);
    PrestigeTalentResult ClaimReward(Player* player, uint32 threshold);
    char const* GetTalentResultText(PrestigeTalentResult result);
    uint32 GetTalentResetCost();
    float GetTalentEffect(Player* player, PrestigeTalentEffect effect);
    // Addon asked for the talent panel before the async login load finished:
    // push SMSG_TALENTS as soon as the data arrives.
    void QueueTalentPush(Player* player);
    // Keep the cached account pool in sync when a prestige level changes.
    void OnPrestigeLevelChanged(Player* player, uint32 oldLevel, uint32 newLevel);
}

#endif // AZEROTHCORE_DC_PRESTIGE_API_H
