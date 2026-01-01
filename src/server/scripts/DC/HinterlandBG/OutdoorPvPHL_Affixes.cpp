// -----------------------------------------------------------------------------
// OutdoorPvPHL_Affixes.cpp
// -----------------------------------------------------------------------------
// Affix helpers: worldstate label, per-affix spell/weather mapping, and weather sync.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "WeatherMgr.h"
#include "Weather.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "Chat.h"
#include "HinterlandBGConstants.h"
#include "../AddonExtension/dc_addon_hlbg.h"
#include <algorithm>
#include <string>

using namespace HinterlandBGConstants;

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
    if (!player)
        return;

    // Determine status
    DCAddon::HLBG::HLBGStatus status = DCAddon::HLBG::STATUS_NONE;
    if (GetBGState() == BG_STATE_WARMUP)
        status = DCAddon::HLBG::STATUS_PREP;
    else if (GetBGState() == BG_STATE_IN_PROGRESS)
        status = DCAddon::HLBG::STATUS_ACTIVE;
    else if (GetBGState() == BG_STATE_FINISHED)
        status = DCAddon::HLBG::STATUS_ENDED;

    // Map ID and Time Remaining
    uint32 mapId = player->GetMapId();
    uint32 timeRemaining = GetTimeRemainingSeconds();

    // Send Status Packet
    DCAddon::HLBG::SendStatus(player, status, mapId, timeRemaining);

    // Send Resources Packet
    DCAddon::HLBG::SendResources(player, _ally_gathered, _horde_gathered, 0, 0);

    // Note: apc/hpc (player counts) are not currently sent in the new compact packets.
    // If needed, we can add a new SMSG_PLAYER_COUNTS or extend Resources.
    // For now, we omit them as they were mostly for debug/overlay.
}

void OutdoorPvPHL::SendStatusAddonToZone() const
{
    // Calculation of APC/HPC is preserved if we restore sending them later,
    // or we can simplify this loop.
    uint32 apc = 0;
    uint32 hpc = 0;
    
    // Just reuse the per-player logic
    ForEachPlayerInZone([&](Player* p){ SendStatusAddonToPlayer(p, apc, hpc); });
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

    // Choose a candidate affix. If random-on-start is enabled choose randomly,
    // otherwise pick the next non-none affix in round-robin fashion.
    AffixType newAffix = AFFIX_NONE;
    const uint8 affixCount = static_cast<uint8>(AFFIX_FOG); // Last affix is FOG (6)
    if (_affixRandomOnStart)
    {
        // Prefer non-zero affixes; allow NONE only if randomness yields 0 rarely.
        uint32 idx = urand(0, affixCount); // 0..affixCount
        newAffix = static_cast<AffixType>(idx);
    }
    else
    {
        // Round-robin: advance to next affix code, wrap and allow NONE as a rest state
        uint8 current = static_cast<uint8>(_activeAffix);
        uint8 candidate = (current + 1) % (affixCount + 1);
        newAffix = static_cast<AffixType>(candidate);
    }

    // Avoid repeating the same affix consecutively when possible
    if (newAffix == _activeAffix)
    {
        // try next value once more
        uint8 cur = static_cast<uint8>(newAffix);
        cur = (cur + 1) % (affixCount + 1);
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
        if (Map* m = GetMap())
        {
            char buf[128];
            snprintf(buf, sizeof(buf), "Hinterland BG: New affix active — %s", name);
            m->SendZoneText(OutdoorPvPHLBuffZones[0], buf);
        }
    }
}
