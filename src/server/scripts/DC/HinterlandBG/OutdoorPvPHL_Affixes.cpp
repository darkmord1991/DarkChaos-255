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

// Compose and send a CHAT_MSG_ADDON style packet that addons can consume via CHAT_MSG_ADDON
// Prefix kept short for 3.3.5a limits; addon listens for prefix containing "HLBG"
void OutdoorPvPHL::SendAffixAddonToPlayer(Player* player) const
{
    if (!player)
        return;

    // Build payload: "AFFIX|<name>" optionally followed by "|WEATHER|<friendly>"
    const char* aff = HL_AffixName(_activeAffix);
    std::string payload = std::string("AFFIX|") + aff;
    if (_affixWeatherEnabled)
    {
        // Try to derive a friendly weather name and percent
        if (_activeAffix >= AFFIX_NONE && _activeAffix <= AFFIX_FOG)
        {
            uint32 wtype = _affixWeatherType[_activeAffix];
            float  wint  = _affixWeatherIntensity[_activeAffix];
            if (wtype)
            {
                const char* wname = GetExtendedWeatherName(wtype);
                uint32 ipct = uint32(std::max(0.f, std::min(1.f, wint)) * 100.f + 0.5f);
                payload += "|WEATHER|";
                payload += wname;
                payload += " ";
                payload += std::to_string(ipct);
                payload += "%";
            }
        }
    }

    // Compose as addon whisper "HLBG\t<payload>" so client fires CHAT_MSG_ADDON with prefix="HLBG"
    std::string message = std::string("HLBG\t") + payload;
    if (player->GetSession())
    {
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, message);
        player->SendDirectMessage(&data);
    }
}

void OutdoorPvPHL::SendAffixAddonToZone() const
{
    ForEachPlayerInZone([&](Player* p){ SendAffixAddonToPlayer(p); });
}

void OutdoorPvPHL::SendStatusAddonToPlayer(Player* player) const
{
    if (!player)
        return;
    // LOCK=1 when in lock window (timer should show remaining lock time instead of match end)
    uint32 endEpoch = GetHudEndEpoch();
    uint32 lock = (_lockEnabled && _isLocked) ? 1u : 0u;
    std::string message = "HLBG\tSTATUS|A=" + std::to_string(_ally_gathered)
                        + "|H=" + std::to_string(_horde_gathered)
                        + "|END=" + std::to_string(endEpoch)
                        + "|LOCK=" + std::to_string(lock);
    if (player->GetSession())
    {
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, message);
        player->SendDirectMessage(&data);
    }
}

void OutdoorPvPHL::SendStatusAddonToZone() const
{
    ForEachPlayerInZone([&](Player* p){ SendStatusAddonToPlayer(p); });
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
