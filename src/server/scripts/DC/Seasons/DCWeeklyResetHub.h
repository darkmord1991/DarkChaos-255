#pragma once

#include "Define.h"

namespace DarkChaos
{
namespace Seasons
{
    // Uses the same week boundary logic as Great Vault/Mythic+ (week_start columns).
    uint32 GetVaultWeekStartTimestamp();

    // Runs the global weekly reset tasks if the stored week_start differs from current.
    // Safe to call periodically; persisted via `dc_weekly_reset_state`.
    void RunWeeklyResetIfNeeded();

    // Runs Great Vault table cleanup (keeps last week reward pool; keeps 52 weeks of history rows).
    void CleanupGreatVaultTables(uint32 currentWeekStart);

    // Resets ItemUpgrades weekly-earned counters.
    void ResetItemUpgradeWeeklyEarned();
}
}
