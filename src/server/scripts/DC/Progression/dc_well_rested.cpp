/*
 * DarkChaos: Well Rested (spell 800030).
 *
 * Staying in an inn gives Well Rested: more XP from kills and quests for a
 * stretch of play time. Defaults (DC.WellRested.*): 10 minutes in the inn,
 * +10%, 2 hours.
 *
 * - Inn = REST_FLAG_IN_TAVERN (stock inns and the DC tavern areatriggers in
 *   areatrigger_tavern) or REST_FLAG_IN_FACTION_AREA (areas whose AreaTable
 *   flags make the whole area an inn: Westguard Inn, Warsong Hold, and every
 *   id in DC.RestAreas.ExtraAreaIds). A capital city on its own does not
 *   count; its inns do.
 * - Inn time is counted in 5-second steps while online. Being out of the inn
 *   for more than a minute starts it over, so stepping out of a trigger box
 *   for a moment costs nothing.
 * - Logging out in an inn: the time offline counts as time in the inn, so a
 *   character that stays logged out in an inn for InnMinutes logs back in
 *   Well Rested (and a quick relog does not skip the wait). Kept in
 *   character_settings, source "dc-well-rested", which needs
 *   EnablePlayerSettings = 1 (on for the live realm).
 * - While the character stays in an inn the aura is kept at full duration.
 * - The aura is a positive DUMMY aura saved with the character. Positive
 *   auras do not tick while offline (Player::_LoadAuras), so the duration is
 *   play time. The spell row keeps it through death and arena entry.
 * - The XP goes through OnPlayerGiveXP like the hotspot bonus, not through
 *   SPELL_AURA_MOD_XP_PCT / SPELL_AURA_MOD_XP_QUEST_PCT, so `.dc xp bonus off`
 *   drops it (DCXPRate::IsBonusXPOptedOut). The challenge-mode multipliers and
 *   the quest-XP-only mode run in their own hook; percentages multiply, so the
 *   hook order does not matter. A character that opted out, is at its max
 *   level or carries the Experience Eliminator flag is not given the aura,
 *   and loses it at the next check if it has one.
 * - Playerbots get nothing unless DC.WellRested.IncludeBots = 1.
 *
 * The tooltip number ($s1) comes from the spell row (EffectBasePoints_1 = 9,
 * i.e. 10%), not from DC.WellRested.XPPercent: change both together.
 * Spell rows: Custom/CSV DBC/Spell.csv (client) and spell_dbc (server,
 * pending world SQL).
 */

#include "dc_xp_rate.h"

#include "Chat.h"
#include "Config.h"
#include "DataMap.h"
#include "GameTime.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"

#include <algorithm>
#include <atomic>
#include <limits>
#include <string>

namespace
{
    constexpr uint32 SPELL_WELL_RESTED = 800030;

    constexpr char const* STATE_KEY = "dc_well_rested";
    constexpr char const* CHAT_PREFIX = "|cff00ccff[Well Rested]|r ";

    // character_settings: index 0 = unix time of a logout inside an inn (0 = none),
    // index 1 = inn seconds counted before that logout.
    constexpr char const* SETTING_SOURCE = "dc-well-rested";
    constexpr uint32 SETTING_LOGOUT_TIME = 0;
    constexpr uint32 SETTING_INN_SECONDS = 1;

    constexpr uint32 CHECK_INTERVAL_MS = 5 * IN_MILLISECONDS;
    constexpr uint32 OUTSIDE_GRACE_MS = MINUTE * IN_MILLISECONDS;
    // While in an inn the aura is topped up once it has lost this much.
    constexpr int32 REFRESH_SLACK_MS = MINUTE * IN_MILLISECONDS;
    // One week: keeps every duration inside an int32 of milliseconds.
    constexpr uint32 MAX_MINUTES = 7 * 24 * 60;

    // Written on the world thread at config (re)load and startup, read on map threads.
    std::atomic<bool> s_enabled{true};
    std::atomic<bool> s_spellExists{true};
    std::atomic<uint32> s_innMs{10 * MINUTE * IN_MILLISECONDS};
    std::atomic<uint32> s_durationMinutes{120};
    std::atomic<uint32> s_xpPercent{10};
    std::atomic<bool> s_includeQuests{true};
    std::atomic<bool> s_includeBots{false};

    struct WellRestedState : public DataMap::Base
    {
        uint32 TickMs = 0;
        uint32 InnMs = 0;
        uint32 OutsideMs = 0;
    };

    bool IsActive()
    {
        return s_enabled && s_spellExists;
    }

    bool IsBot(Player const* player)
    {
        return player->GetSession()->IsBot();
    }

    bool IsEligible(Player const* player)
    {
        return player->GetSession() && (s_includeBots || !IsBot(player));
    }

    bool IsInInn(Player const* player)
    {
        return player->HasRestFlag(REST_FLAG_IN_TAVERN) || player->HasRestFlag(REST_FLAG_IN_FACTION_AREA);
    }

    // Whether the bonus would do anything for this character right now.
    bool WantsBonus(Player* player)
    {
        return !player->IsMaxLevel() && !player->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN) &&
            !DCXPRate::IsBonusXPOptedOut(player);
    }

    WellRestedState* GetState(Player* player)
    {
        return player->CustomData.GetDefault<WellRestedState>(STATE_KEY);
    }

    std::string FormatMinutes(uint32 minutes)
    {
        if (minutes % 60 == 0)
            return Acore::StringFormat("{} hour{}", minutes / 60, minutes == 60 ? "" : "s");

        return Acore::StringFormat("{} minutes", minutes);
    }

    // Gives the aura, or tops it back up to full duration.
    void Grant(Player* player)
    {
        int32 const duration = int32(s_durationMinutes * MINUTE * IN_MILLISECONDS);

        Aura* aura = player->GetAura(SPELL_WELL_RESTED);
        bool const fresh = !aura;
        if (fresh)
        {
            aura = player->AddAura(SPELL_WELL_RESTED, player);
            if (!aura)
                return;
        }
        else if (aura->GetMaxDuration() == duration && aura->GetDuration() > duration - REFRESH_SLACK_MS)
            return;

        aura->SetMaxDuration(duration);
        aura->SetDuration(duration);

        if (fresh && !IsBot(player))
            ChatHandler(player->GetSession()).PSendSysMessage("{}You feel well rested: +{}% experience from kills{} "
                "for {} of play time.", CHAT_PREFIX, s_xpPercent.load(), s_includeQuests ? " and quests" : "",
                FormatMinutes(s_durationMinutes));
    }

    class dc_well_rested_world : public WorldScript
    {
    public:
        dc_well_rested_world() : WorldScript("dc_well_rested_world",
            { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            s_enabled = sConfigMgr->GetOption<bool>("DC.WellRested.Enable", true);

            uint32 const innMinutes = std::min(sConfigMgr->GetOption<uint32>("DC.WellRested.InnMinutes", 10),
                MAX_MINUTES);
            s_innMs = innMinutes * MINUTE * IN_MILLISECONDS;

            s_durationMinutes = std::clamp(sConfigMgr->GetOption<uint32>("DC.WellRested.DurationMinutes", 120),
                1u, MAX_MINUTES);
            s_xpPercent = std::min(sConfigMgr->GetOption<uint32>("DC.WellRested.XPPercent", 10), 1000u);
            s_includeQuests = sConfigMgr->GetOption<bool>("DC.WellRested.IncludeQuests", true);
            s_includeBots = sConfigMgr->GetOption<bool>("DC.WellRested.IncludeBots", false);
        }

        void OnStartup() override
        {
            s_spellExists = sSpellMgr->GetSpellInfo(SPELL_WELL_RESTED) != nullptr;
            if (!s_spellExists && s_enabled)
                LOG_ERROR("scripts.dc", "DC.WellRested: spell {} does not exist (its spell_dbc row is in the "
                    "pending world SQL). Well Rested stays off.", SPELL_WELL_RESTED);
        }
    };

    class dc_well_rested_player : public PlayerScript
    {
    public:
        dc_well_rested_player() : PlayerScript("dc_well_rested_player",
        {
            PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_BEFORE_LOGOUT, PLAYERHOOK_ON_GIVE_EXP
        }) { }

        // Map thread. Bots leave after one compare unless IncludeBots is on.
        void OnPlayerUpdate(Player* player, uint32 diff) override
        {
            if (!IsActive() || !IsEligible(player))
                return;

            WellRestedState* state = GetState(player);
            state->TickMs += diff;
            if (state->TickMs < CHECK_INTERVAL_MS)
                return;

            uint32 const elapsed = state->TickMs;
            state->TickMs = 0;

            if (!WantsBonus(player))
            {
                player->RemoveAurasDueToSpell(SPELL_WELL_RESTED);
                state->InnMs = 0;
                return;
            }

            if (!IsInInn(player))
            {
                state->OutsideMs = std::min(state->OutsideMs + elapsed, OUTSIDE_GRACE_MS);
                if (state->OutsideMs >= OUTSIDE_GRACE_MS)
                    state->InnMs = 0;

                return;
            }

            uint32 const innMs = s_innMs;
            state->OutsideMs = 0;
            state->InnMs = std::min(state->InnMs + elapsed, innMs);

            if (state->InnMs >= innMs)
                Grant(player);
        }

        void OnPlayerLogin(Player* player) override
        {
            // Rest flags are set by now: the inn trigger from the character row, the
            // rest-zone area from the zone update that runs before this hook.
            if (!IsActive() || !IsEligible(player))
            {
                // A saved aura that would do nothing only misleads.
                player->RemoveAurasDueToSpell(SPELL_WELL_RESTED);
                return;
            }

            if (!IsInInn(player))
                return;

            uint32 const logoutTime = player->GetPlayerSetting(SETTING_SOURCE, SETTING_LOGOUT_TIME).value;
            if (!logoutTime)
                return;

            uint32 const innSeconds = player->GetPlayerSetting(SETTING_SOURCE, SETTING_INN_SECONDS).value;
            player->UpdatePlayerSetting(SETTING_SOURCE, SETTING_LOGOUT_TIME, 0);
            player->UpdatePlayerSetting(SETTING_SOURCE, SETTING_INN_SECONDS, 0);

            if (!WantsBonus(player))
                return;

            uint64 const now = uint64(GameTime::GetGameTime().count());
            uint64 const offlineSeconds = now > logoutTime ? now - logoutTime : 0;
            uint64 const totalMs = (uint64(innSeconds) + offlineSeconds) * IN_MILLISECONDS;

            uint32 const innMs = s_innMs;
            WellRestedState* state = GetState(player);
            state->InnMs = uint32(std::min<uint64>(totalMs, innMs));

            if (state->InnMs >= innMs)
                Grant(player);
        }

        // Runs before the logout save, so the settings written here are stored.
        void OnPlayerBeforeLogout(Player* player) override
        {
            if (!IsActive() || !IsEligible(player) || !IsInInn(player) || !WantsBonus(player))
                return;

            WellRestedState const* state = player->CustomData.Get<WellRestedState>(STATE_KEY);
            uint32 const innSeconds = state ? state->InnMs / IN_MILLISECONDS : 0;
            player->UpdatePlayerSetting(SETTING_SOURCE, SETTING_LOGOUT_TIME, uint32(GameTime::GetGameTime().count()));
            player->UpdatePlayerSetting(SETTING_SOURCE, SETTING_INN_SECONDS, innSeconds);
        }

        // Map thread. Kills always, quests unless IncludeQuests = 0; exploration and
        // battleground XP are left alone.
        void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 xpSource) override
        {
            if (!amount || !IsActive())
                return;

            switch (xpSource)
            {
                case XPSOURCE_KILL:
                    break;
                case XPSOURCE_QUEST:
                case XPSOURCE_QUEST_DF:
                    if (!s_includeQuests)
                        return;
                    break;
                default:
                    return;
            }

            if (!IsEligible(player) || !player->HasAura(SPELL_WELL_RESTED) || DCXPRate::IsBonusXPOptedOut(player))
                return;

            uint32 const percent = s_xpPercent;
            if (!percent)
                return;

            uint64 const bonus = uint64(amount) * percent / 100;
            uint64 const headroom = std::numeric_limits<uint32>::max() - amount;
            amount += uint32(std::min(bonus, headroom));
        }
    };
}

void AddSC_dc_well_rested()
{
    new dc_well_rested_world();
    new dc_well_rested_player();
}
