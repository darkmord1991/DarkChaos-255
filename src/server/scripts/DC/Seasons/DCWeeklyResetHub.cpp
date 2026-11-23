#include "DCWeeklyResetHub.h"

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Timer.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "ScriptMgr.h"
#include "dc_update_profiler.h"

#include <algorithm>
#include <ctime>

namespace
{
    constexpr uint32 SECONDS_PER_DAY = 24u * 60u * 60u;
    constexpr uint32 SECONDS_PER_WEEK = 7u * SECONDS_PER_DAY;

    constexpr uint8 DEFAULT_WEEKLY_RESET_DAY = 2;  // Tuesday
    constexpr uint8 DEFAULT_WEEKLY_RESET_HOUR = 15; // 15:00

    constexpr char const* WEEKLY_STATE_KEY = "dc_global";

    // dc_token_transaction_log pruning: one bounded DELETE per pass, so a large backlog
    // (425k rows on 2026-11-09, mostly bots) drains over several passes instead of one
    // long statement on the character DB worker.
    constexpr uint32 TOKEN_LOG_PRUNE_INTERVAL_MS = 10u * 60u * 1000u;
    constexpr uint32 TOKEN_LOG_PRUNE_BATCH = 20000u;
    constexpr uint32 DEFAULT_TOKEN_LOG_RETENTION_WEEKS = 4u;
    constexpr uint32 MAX_TOKEN_LOG_RETENTION_WEEKS = 520u; // keeps weeks * SECONDS_PER_WEEK inside uint32

    uint32 GetCurrentWeekStart()
    {
        // Canonical weekly reset boundary for all DarkChaos systems.
        // This is intentionally aligned with SeasonalRewards.WeeklyResetDay/Hour and
        // the schema intent for dc_weekly_vault.week_start ("Unix Tuesday reset").
        time_t now = time(nullptr);
        // Thread-safe breakdown: this runs from map-thread hooks, and glibc localtime() shares one buffer.
        tm resetTm = Acore::Time::TimeBreakdown(now);

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

        // Async Execute, not DirectExecute: these are server-wide purges with no
        // player filter, so the row count is unbounded and grows with uptime.
        // DirectExecute ran them inline on the world thread during the weekly
        // reset tick; nothing reads the result, so fire-and-forget is correct.
        CharacterDatabase.Execute("DELETE FROM dc_weekly_vault WHERE week_start < {}", purgeBefore);
        CharacterDatabase.Execute("DELETE FROM dc_vault_reward_pool WHERE week_start < {}", keepFrom);

        // The raid and PvP progress rows are only read for the claim week and
        // the current week, so they keep the reward pool's window.
        if (DC::DbSchema::CharacterTableExists("dc_vault_raid_kills"))
            CharacterDatabase.Execute("DELETE FROM dc_vault_raid_kills WHERE week_start < {}", keepFrom);
        if (DC::DbSchema::CharacterTableExists("dc_vault_pvp_wins"))
            CharacterDatabase.Execute("DELETE FROM dc_vault_pvp_wins WHERE week_start < {}", keepFrom);

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

    void PruneTokenTransactionLog()
    {
        // The table gains a row for every token award and nothing ever deleted one.
        // Its only reader is the weekly token cap (SeedWeeklyEarnedAsync in
        // ItemUpgrades/ItemUpgradeTokenHooks.cpp), which sums the CURRENT week, so
        // anything older than the retention window is dead weight. The cutoff is a
        // week boundary, and at least one full week before the current one is kept.
        // 0 keeps every row.
        uint32 const retentionWeeks = std::min(
            sConfigMgr->GetOption<uint32>("DarkChaos.Seasonal.TokenLogRetentionWeeks", DEFAULT_TOKEN_LOG_RETENTION_WEEKS),
            MAX_TOKEN_LOG_RETENTION_WEEKS);
        if (retentionWeeks == 0)
            return;

        if (!DC::DbSchema::CharacterTableExists("dc_token_transaction_log"))
            return;

        uint32 const currentWeekStart = GetCurrentWeekStart();
        uint32 const span = retentionWeeks * SECONDS_PER_WEEK;
        if (currentWeekStart <= span)
            return;

        // FROM_UNIXTIME, as the cap's own seeding query compares created_at the same way.
        CharacterDatabase.Execute(
            "DELETE FROM dc_token_transaction_log WHERE created_at < FROM_UNIXTIME({}) LIMIT {}",
            currentWeekStart - span, TOKEN_LOG_PRUNE_BATCH);
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

            _pruneTimer += 60000;
            if (_pruneTimer < TOKEN_LOG_PRUNE_INTERVAL_MS)
                return;

            _pruneTimer = 0;
            DarkChaos::Seasons::PruneTokenTransactionLog();
        }

    private:
        uint32 _timer = 0;
        uint32 _pruneTimer = 0;
    };
}

void AddSC_DCWeeklyResetHub()
{
    new DCWeeklyResetWorldScript();
}
