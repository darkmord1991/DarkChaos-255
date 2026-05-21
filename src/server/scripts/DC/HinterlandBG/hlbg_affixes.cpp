// -----------------------------------------------------------------------------
// hlbg_affixes.cpp
// -----------------------------------------------------------------------------
// Affix helpers: worldstate label, per-affix spell/weather mapping, and weather sync.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "WeatherMgr.h"
#include "Weather.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "Chat.h"
#include "hlbg_constants.h"
#include "../AddonExtension/dc_addon_hlbg.h"
#include <algorithm>
#include <string>

using namespace HinterlandBGConstants;

namespace
{
    struct HLBGHudMetrics
    {
        uint32 alliancePlayers = 0;
        uint32 hordePlayers = 0;
        uint32 alliancePlayerKills = 0;
        uint32 hordePlayerKills = 0;
        uint32 allianceNpcKills = 0;
        uint32 hordeNpcKills = 0;
    };

    HLBGHudMetrics CollectHudMetrics(OutdoorPvPHL const* hl)
    {
        HLBGHudMetrics metrics;
        if (!hl)
            return metrics;

        hl->ForEachPlayerInZone([&](Player* zonePlayer)
        {
            if (!zonePlayer)
                return;

            if (zonePlayer->GetTeamId() == TEAM_ALLIANCE)
            {
                ++metrics.alliancePlayers;
                metrics.alliancePlayerKills += hl->GetPlayerHKDelta(zonePlayer);
            }
            else if (zonePlayer->GetTeamId() == TEAM_HORDE)
            {
                ++metrics.hordePlayers;
                metrics.hordePlayerKills += hl->GetPlayerHKDelta(zonePlayer);
            }
        });

        metrics.allianceNpcKills = hl->GetNpcKillCount(TEAM_ALLIANCE);
        metrics.hordeNpcKills = hl->GetNpcKillCount(TEAM_HORDE);
        return metrics;
    }

    void SendStatusSnapshotToPlayer(OutdoorPvPHL const* hl, Player* player,
        HLBGHudMetrics const& metrics)
    {
        if (!hl || !player)
            return;

        DCAddon::HLBG::HLBGStatus status = DCAddon::HLBG::STATUS_NONE;
        if (hl->GetBGState() == OutdoorPvPHL::BG_STATE_WARMUP)
            status = DCAddon::HLBG::STATUS_PREP;
        else if (hl->GetBGState() == OutdoorPvPHL::BG_STATE_IN_PROGRESS)
            status = DCAddon::HLBG::STATUS_ACTIVE;
        else if (hl->GetBGState() == OutdoorPvPHL::BG_STATE_FINISHED)
            status = DCAddon::HLBG::STATUS_ENDED;

        DCAddon::HLBG::SendStatus(player, status, player->GetMapId(),
            hl->GetTimeRemainingSeconds());
        DCAddon::HLBG::SendResources(player,
            hl->GetResources(TEAM_ALLIANCE),
            hl->GetResources(TEAM_HORDE),
            0, 0,
            metrics.alliancePlayers,
            metrics.hordePlayers,
            metrics.alliancePlayerKills,
            metrics.hordePlayerKills,
            metrics.allianceNpcKills,
            metrics.hordeNpcKills);
    }
}

// Return a short code for affix to show via worldstate or announcements
static const char* HL_AffixName(OutdoorPvPHL::AffixType a)
{
    return GetAffixName(static_cast<uint8>(a));
}

// Emit affix worldstate for clients/addons to display a label
void OutdoorPvPHL::UpdateAffixWorldstateForPlayer(Player* player)
{
    if (!player || !_affixWorldstateEnabled)
        return;
    player->SendUpdateWorldState(WORLD_STATE_HL_AFFIX_TEXT, static_cast<uint32>(_activeAffix));
}

void OutdoorPvPHL::UpdateAffixWorldstateAll()
{
    if (!_affixWorldstateEnabled)
        return;
    ForEachPlayerInZone([&](Player* p){ UpdateAffixWorldstateForPlayer(p); });
}

// Initialize default affix spell/weather mappings (can be overridden by config)
void OutdoorPvPHL::InitAffixDefaults()
{
    // Player buffs
    _affixPlayerSpell[AFFIX_SUNLIGHT] = HLBG_AFFIX_SUNLIGHT_SPELL;
    _affixPlayerSpell[AFFIX_CLEAR_SKIES] = HLBG_AFFIX_CLEAR_SKIES_SPELL;
    _affixPlayerSpell[AFFIX_GENTLE_BREEZE] = HLBG_AFFIX_GENTLE_BREEZE_SPELL;

    // NPC buffs
    _affixNpcSpell[AFFIX_STORM] = HLBG_AFFIX_STORM_NPC_SPELL;
    _affixNpcSpell[AFFIX_HEAVY_RAIN] = HLBG_AFFIX_HEAVY_RAIN_NPC_SPELL;
    _affixNpcSpell[AFFIX_FOG] = HLBG_AFFIX_FOG_NPC_SPELL;

    // Weather mapping (0=Fine, 1=Rain, 2=Snow/Fog, 3=Storm)
    _affixWeatherType[AFFIX_SUNLIGHT] = 0;
    _affixWeatherIntensity[AFFIX_SUNLIGHT] = 0.35f;

    _affixWeatherType[AFFIX_CLEAR_SKIES] = 0;
    _affixWeatherIntensity[AFFIX_CLEAR_SKIES] = 0.20f;

    _affixWeatherType[AFFIX_GENTLE_BREEZE] = 1;
    _affixWeatherIntensity[AFFIX_GENTLE_BREEZE] = 0.30f;

    _affixWeatherType[AFFIX_STORM] = 3;
    _affixWeatherIntensity[AFFIX_STORM] = 0.60f;

    _affixWeatherType[AFFIX_HEAVY_RAIN] = 1;
    _affixWeatherIntensity[AFFIX_HEAVY_RAIN] = 0.80f;

    _affixWeatherType[AFFIX_FOG] = 2;
    _affixWeatherIntensity[AFFIX_FOG] = 0.40f;
}

// Redirect legacy method: use new DCAddon::HLBG::SendAffixInfo
void OutdoorPvPHL::SendAffixAddonToPlayer(Player* player) const
{
    if (!player)
        return;

    // Map internal affix type to ID if needed (currently 1:1 for 1-6)
    // 3 args for affixes (primary, secondary, tertiary) + season
    // HLBG currently only uses one active affix.
    uint32 affix1 = static_cast<uint32>(_activeAffix);

    DCAddon::HLBG::SendAffixInfo(player, affix1, 0, 0, _season);
}

void OutdoorPvPHL::SendAffixAddonToZone() const
{
    ForEachPlayerInZone([&](Player* p){ SendAffixAddonToPlayer(p); });
}

// Redirect legacy method: use new DCAddon::HLBG messages for status/resources
void OutdoorPvPHL::SendStatusAddonToPlayer(Player* player, [[maybe_unused]] uint32 apc, [[maybe_unused]] uint32 hpc) const
{
    SendStatusSnapshotToPlayer(this, player, CollectHudMetrics(this));
}

void OutdoorPvPHL::SendStatusAddonToZone() const
{
    HLBGHudMetrics metrics = CollectHudMetrics(this);
    ForEachPlayerInZone([&](Player* p)
    {
        SendStatusSnapshotToPlayer(this, p, metrics);
    });
}

// Compute effective spells/weather, preferring per-affix overrides
uint32 OutdoorPvPHL::GetPlayerSpellForAffix(AffixType a) const
{
    if (a >= AFFIX_NONE && a <= AFFIX_FOG)
    {
        uint32 v = _affixPlayerSpell[a];
        if (v) return v;
    }
    // No old affix fallbacks - using new weather-based system
    return 0;
}

uint32 OutdoorPvPHL::GetNpcSpellForAffix(AffixType a) const
{
    if (a >= AFFIX_NONE && a <= AFFIX_FOG)
    {
        uint32 v = _affixNpcSpell[a];
        if (v) return v;
    }
    // No old affix fallbacks - using new weather-based system
    return 0;
}

void OutdoorPvPHL::ApplyAffixWeather()
{
    if (!_affixWeatherEnabled)
        return;
    uint32 weatherType = 0;
    float intensity = 0.5f;
    if (_activeAffix >= AFFIX_NONE && _activeAffix <= AFFIX_FOG)
    {
        if (_affixWeatherType[_activeAffix])
            weatherType = _affixWeatherType[_activeAffix];
        if (_affixWeatherIntensity[_activeAffix] > 0.0f)
            intensity = _affixWeatherIntensity[_activeAffix];
    }
    uint32 const zoneId = OutdoorPvPHLBuffZones[0];
    // Apply on all active maps where players are present in the zone
    ForEachPlayerInZone([&](Player* p)
    {
        if (Map* m = p->GetMap())
        {
            if (Weather* w = m->GetOrGenerateZoneDefaultWeather(zoneId))
                w->SetWeather(static_cast<WeatherType>(weatherType), intensity);
        }
    });
}

// Select and activate a new affix for the upcoming battle (or periodic rotation).
void OutdoorPvPHL::_selectAffixForNewBattle()
{
    // If affix system disabled, ensure none is active
    if (!_affixEnabled)
    {
        _activeAffix = AFFIX_NONE;
        _affixTimerMs = 0;
        _affixNextChangeEpoch = 0;
        return;
    }

    // Choose a candidate affix. When the system is enabled, always rotate over
    // actual affixes instead of selecting the inactive NONE state.
    AffixType newAffix = AFFIX_NONE;
    constexpr uint8 firstAffix = static_cast<uint8>(AFFIX_SUNLIGHT);
    constexpr uint8 lastAffix = static_cast<uint8>(AFFIX_FOG);
    if (_affixRandomOnStart)
    {
        uint32 idx = urand(firstAffix, lastAffix);
        newAffix = static_cast<AffixType>(idx);
    }
    else
    {
        uint8 current = static_cast<uint8>(_activeAffix);
        if (current < firstAffix || current > lastAffix)
            current = lastAffix;

        uint8 candidate = current + 1;
        if (candidate > lastAffix)
            candidate = firstAffix;
        newAffix = static_cast<AffixType>(candidate);
    }

    // Avoid repeating the same affix consecutively when possible
    if (newAffix == _activeAffix)
    {
        uint8 cur = static_cast<uint8>(newAffix);
        ++cur;
        if (cur > lastAffix)
            cur = firstAffix;
        newAffix = static_cast<AffixType>(cur);
    }

    // Apply the change
    _clearAffixEffects();
    _activeAffix = newAffix;

    // Reset timers
    if (_affixPeriodSec > 0)
        _affixTimerMs = _affixPeriodSec * IN_MILLISECONDS;
    else
        _affixTimerMs = 0;
    _affixNextChangeEpoch = (_affixTimerMs > 0) ? (NowSec() + (_affixTimerMs / IN_MILLISECONDS)) : 0;

    // Apply new effects and weather
    _applyAffixEffects();
    if (_affixWeatherEnabled)
        ApplyAffixWeather();

    // Optional announcement to zone
    if (_affixAnnounce)
    {
        const char* name = HL_AffixName(_activeAffix);
        BroadcastToZone("New affix active: %s", name);
    }
}
