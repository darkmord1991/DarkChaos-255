#ifndef AZEROTHCORE_DC_PRESTIGE_API_H
#define AZEROTHCORE_DC_PRESTIGE_API_H

#include "Common.h"
#include <string>
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
}

#endif // AZEROTHCORE_DC_PRESTIGE_API_H
