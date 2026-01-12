#include "DCWeeklyResetHub.h"

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ScriptMgr.h"

#include <ctime>

namespace
{
    constexpr uint32 SECONDS_PER_DAY = 24u * 60u * 60u;
    constexpr uint32 SECONDS_PER_WEEK = 7u * SECONDS_PER_DAY;

    constexpr uint8 DEFAULT_WEEKLY_RESET_DAY = 2;  // Tuesday
    constexpr uint8 DEFAULT_WEEKLY_RESET_HOUR = 15; // 15:00

    constexpr char const* WEEKLY_STATE_TABLE = "dc_weekly_reset_state";
    constexpr char const* WEEKLY_STATE_KEY = "dc_global";

    uint32 GetCurrentWeekStart()
    {
        // Canonical weekly reset boundary for all DarkChaos systems.
        // This is intentionally aligned with SeasonalRewards.WeeklyResetDay/Hour and
        // the schema intent for dc_weekly_vault.week_start ("Unix Tuesday reset").
        time_t now = time(nullptr);
        tm* timeInfo = localtime(&now);
        if (!timeInfo)
            return static_cast<uint32>(now);

        uint8 resetDay = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetDay", DEFAULT_WEEKLY_RESET_DAY);
        uint8 resetHour = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetHour", DEFAULT_WEEKLY_RESET_HOUR);

        // Calculate days since last reset day.
        int daysSinceReset = timeInfo->tm_wday - resetDay;
        if (daysSinceReset < 0)
            daysSinceReset += 7;

        // Calculate seconds since the start of the current day + days since reset.
        time_t secondsSinceReset = time_t(daysSinceReset) * 86400 +
            time_t(timeInfo->tm_hour) * 3600 +
            time_t(timeInfo->tm_min) * 60 +
            time_t(timeInfo->tm_sec);

        time_t resetHourOffset = time_t(resetHour) * 3600;
        time_t weekTimestamp = now - secondsSinceReset + resetHourOffset;

        // If today is reset day but we haven't reached reset hour yet, go back one week.
        if (timeInfo->tm_wday == resetDay && timeInfo->tm_hour < resetHour)
            weekTimestamp -= 604800; // 7 days

        return static_cast<uint32>(weekTimestamp);
    }

    void EnsureStateTableExists()
    {
        // Keep this lightweight and idempotent; avoids needing an out-of-band SQL migration.
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS dc_weekly_reset_state ("
            "system VARCHAR(64) NOT NULL PRIMARY KEY,"
            "week_start INT UNSIGNED NOT NULL DEFAULT 0,"
            "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
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
        // Note: `dc_player_upgrade_tokens.last_transaction_at` will update due to ON UPDATE.
        CharacterDatabase.DirectExecute(
            "UPDATE dc_player_upgrade_tokens SET weekly_earned = 0 "
            "WHERE currency_type = 'upgrade_token' AND weekly_earned <> 0");

        LOG_INFO("module.dc", "[WeeklyReset] ItemUpgrades weekly_earned reset");
    }

    void RunWeeklyResetIfNeeded()
    {
        EnsureStateTableExists();

        uint32 currentWeekStart = GetCurrentWeekStart();
        uint32 storedWeekStart = 0;

        QueryResult state = CharacterDatabase.Query(
            "SELECT week_start FROM dc_weekly_reset_state WHERE system = '{}'",
            WEEKLY_STATE_KEY);

        if (state)
            storedWeekStart = state->Fetch()[0].Get<uint32>();

        if (storedWeekStart == currentWeekStart)
            return;

        LOG_INFO("module.dc", "[WeeklyReset] Week boundary detected (stored={}, current={})", storedWeekStart, currentWeekStart);

        // Run the cross-system weekly reset tasks.
        CleanupGreatVaultTables(currentWeekStart);
        ResetItemUpgradeWeeklyEarned();

        // Persist new week start.
        CharacterDatabase.Execute(
            "INSERT INTO dc_weekly_reset_state (system, week_start) VALUES ('{}', {}) "
            "ON DUPLICATE KEY UPDATE week_start = {}",
            WEEKLY_STATE_KEY, currentWeekStart, currentWeekStart);
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
