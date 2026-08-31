#include "DCWeeklyResetHub.h"

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "dc_update_profiler.h"

#include <ctime>

namespace
{
    constexpr uint32 SECONDS_PER_DAY = 24u * 60u * 60u;
    constexpr uint32 SECONDS_PER_WEEK = 7u * SECONDS_PER_DAY;

    constexpr uint8 DEFAULT_WEEKLY_RESET_DAY = 2;  // Tuesday
    constexpr uint8 DEFAULT_WEEKLY_RESET_HOUR = 15; // 15:00

    constexpr char const* WEEKLY_STATE_KEY = "dc_global";

    uint32 GetCurrentWeekStart()
    {
        // Canonical weekly reset boundary for all DarkChaos systems.
        // This is intentionally aligned with SeasonalRewards.WeeklyResetDay/Hour and
        // the schema intent for dc_weekly_vault.week_start ("Unix Tuesday reset").
        time_t now = time(nullptr);
        tm const* localInfo = localtime(&now);
        if (!localInfo)
            return static_cast<uint32>(now);

        tm resetTm = *localInfo;

        uint8 resetDay = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetDay", DEFAULT_WEEKLY_RESET_DAY);
        uint8 resetHour = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetHour", DEFAULT_WEEKLY_RESET_HOUR);

        // Calculate days back to the most recent reset day.
        int daysSinceReset = resetTm.tm_wday - int(resetDay);
        if (daysSinceReset < 0)
            daysSinceReset += 7;

        // If today is reset day but we haven't reached reset hour yet, the current week
        // started on the previous occurrence of the reset day.
        if (daysSinceReset == 0 && resetTm.tm_hour < int(resetHour))
            daysSinceReset = 7;

        // Rebuild the reset instant as a local calendar date rather than subtracting a
        // wall-clock offset from `now`. Deriving the key by arithmetic on localtime fields
        // shifts it by the UTC-offset delta whenever DST changes, which both fires a
        // spurious mid-week reset and orphans every row already keyed by week_start
        // (dc_weekly_vault, dc_vault_reward_pool, the weekly token cap window).
        // mktime resolves tm_isdst per-date, so the same calendar reset instant maps to
        // the same epoch before and after a transition.
        resetTm.tm_mday -= daysSinceReset;   // mktime normalizes month/year underflow
        resetTm.tm_hour = int(resetHour);
        resetTm.tm_min = 0;
        resetTm.tm_sec = 0;
        resetTm.tm_isdst = -1;               // let the C library pick the offset for that date

        time_t weekTimestamp = mktime(&resetTm);
        if (weekTimestamp == time_t(-1))
            return static_cast<uint32>(now);

        return static_cast<uint32>(weekTimestamp);
    }

}

namespace DarkChaos
{
namespace Seasons
{
    uint32 GetVaultWeekStartTimestamp()
    {
        return GetCurrentWeekStart();
    }

    void CleanupGreatVaultTables(uint32 currentWeekStart)
    {
        // Keep 52 weeks of history in dc_weekly_vault.
        uint32 purgeBefore = currentWeekStart >= (52u * SECONDS_PER_WEEK)
            ? (currentWeekStart - (52u * SECONDS_PER_WEEK))
            : 0u;

        // Retail-like grace window: keep last week's reward pool during the current week.
        uint32 keepFrom = currentWeekStart >= SECONDS_PER_WEEK
            ? (currentWeekStart - SECONDS_PER_WEEK)
            : 0u;

        CharacterDatabase.DirectExecute("DELETE FROM dc_weekly_vault WHERE week_start < {}", purgeBefore);
        CharacterDatabase.DirectExecute("DELETE FROM dc_vault_reward_pool WHERE week_start < {}", keepFrom);

        LOG_INFO("module.dc", "[WeeklyReset] GreatVault cleanup done (purgeBefore={}, keepFrom={})", purgeBefore, keepFrom);
    }

    void ResetItemUpgradeWeeklyEarned()
    {
        // Deliberately does nothing. This used to zero
        // `dc_player_upgrade_tokens.weekly_earned`, but that table was retired when
        // upgrade currency became item-based: nothing has written the column for a
        // long time, so the UPDATE was clearing a value no reader consulted and
        // logging a reset that had not happened.
        //
        // The weekly earn cap now derives its total from `dc_token_transaction_log`
        // (see IsAtWeeklyTokenCap in ItemUpgrades/ItemUpgradeTokenHooks.cpp). That
        // counter is keyed by week start and re-seeds itself when the week rolls
        // over, so it needs no reset step here.
        //
        // Kept as a named no-op rather than deleted: it is part of the documented
        // weekly-reset sequence, and a future per-week counter that does need
        // clearing belongs here.
    }

    void RunWeeklyResetIfNeeded()
    {
        uint32 currentWeekStart = GetCurrentWeekStart();

        // Use a static cache to avoid a synchronous DB query every minute.
        // storedWeekStart is loaded from DB once; after that we only re-query if the
        // in-memory value is zero (first call) or after a reset was just performed.
        static uint32 s_cachedWeekStart = 0;

        if (s_cachedWeekStart == 0)
        {
            QueryResult state = CharacterDatabase.Query(
                "SELECT week_start FROM `dc_weekly_reset_state` WHERE `system` = '{}'",
                WEEKLY_STATE_KEY);

            if (state)
                s_cachedWeekStart = state->Fetch()[0].Get<uint32>();
        }

        if (s_cachedWeekStart == currentWeekStart)
            return;

        LOG_INFO("module.dc", "[WeeklyReset] Week boundary detected (stored={}, current={})", s_cachedWeekStart, currentWeekStart);

        // Run the cross-system weekly reset tasks.
        CleanupGreatVaultTables(currentWeekStart);
        ResetItemUpgradeWeeklyEarned();

        // Persist new week start and update in-memory cache.
        CharacterDatabase.Execute(
            "INSERT INTO `dc_weekly_reset_state` (`system`, week_start) VALUES ('{}', {}) "
            "ON DUPLICATE KEY UPDATE week_start = {}",
            WEEKLY_STATE_KEY, currentWeekStart, currentWeekStart);

        s_cachedWeekStart = currentWeekStart;
    }

} // namespace Seasons
} // namespace DarkChaos

namespace
{
    class DCWeeklyResetWorldScript : public WorldScript
    {
    public:
        DCWeeklyResetWorldScript() : WorldScript("DCWeeklyResetWorldScript") {}

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            // Do a best-effort run early so week boundaries are handled even after long downtime.
            DarkChaos::Seasons::RunWeeklyResetIfNeeded();
        }

        void OnUpdate(uint32 diff) override
        {
            DarkChaos::ScopedUpdateProfiler _prof("WeeklyReset");
            _timer += diff;
            if (_timer < 60000)
                return;

            _timer = 0;
            DarkChaos::Seasons::RunWeeklyResetIfNeeded();
        }

    private:
        uint32 _timer = 0;
    };
}

void AddSC_DCWeeklyResetHub()
{
    new DCWeeklyResetWorldScript();
}
