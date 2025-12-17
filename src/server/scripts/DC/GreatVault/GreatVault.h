#ifndef DC_GREAT_VAULT_H
#define DC_GREAT_VAULT_H

#include "Common.h"
#include "ObjectGuid.h"
#include <vector>
#include <tuple>

class Player;

class GreatVaultMgr
{
public:
    static GreatVaultMgr* instance();

    // Generates the weekly reward pool for a player based on their progress
    bool GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);

    // Retrieves the current reward pool (slot, itemId, itemLevel)
    std::vector<std::tuple<uint8, uint32, uint32>> GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);

    // Claims a reward from the vault
    bool ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId);

    // Helper to get threshold for a specific slot (1, 2, 3)
    uint8 GetVaultThreshold(uint8 slotIndex) const;

private:
    GreatVaultMgr() = default;
    ~GreatVaultMgr() = default;
};

#define sGreatVault GreatVaultMgr::instance()

#endif // DC_GREAT_VAULT_H
