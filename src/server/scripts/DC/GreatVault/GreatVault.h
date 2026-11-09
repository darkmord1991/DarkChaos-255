#ifndef DC_GREAT_VAULT_H
#define DC_GREAT_VAULT_H

#include "Common.h"
#include "ObjectGuid.h"
#include <string>
#include <vector>
#include <tuple>

class Player;

namespace DarkChaos
{
namespace GreatVault
{
    // Weekly raid and PvP progress for the vault, as parenthesised scalar
    // subqueries over the week that starts at weekStart. Both rows are written
    // by the vault's own hooks (GreatVault.cpp): unique raid bosses per week in
    // dc_vault_raid_kills, battleground/arena/HLBG wins in dc_vault_pvp_wins.
    // While a table is missing (its pending SQL not applied yet) the fragment
    // is the literal 0, so the rest of the vault query still runs.
    std::string RaidBossCountSql(uint32 guidLow, uint32 weekStart);
    std::string PvpWinCountSql(uint32 guidLow, uint32 weekStart);
}
}

class GreatVaultMgr
{
public:
    static GreatVaultMgr* instance();

    // Generates the weekly reward pool for a player based on their progress.
    // seasonId only tags the rows it inserts; progress and existing slots are
    // read by week_start, whatever season they were written under.
    bool GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);

    // Retrieves the current reward pool (slot, itemId, itemLevel)
    std::vector<std::tuple<uint8, uint32, uint32>> GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart);

    // Claims a reward from the vault. The claim week is last week; its pool,
    // claim state and runs are matched by week_start alone, so a week that
    // ran under the previous season stays claimable after a season change.
    bool ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId);

    // Helper to get threshold for a specific slot (1, 2, 3)
    uint8 GetVaultThreshold(uint8 slotIndex) const;

private:
    GreatVaultMgr() = default;
    ~GreatVaultMgr() = default;
};

#define sGreatVault GreatVaultMgr::instance()

#endif // DC_GREAT_VAULT_H
