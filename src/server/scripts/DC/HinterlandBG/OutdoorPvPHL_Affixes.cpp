// -----------------------------------------------------------------------------
// OutdoorPvPHL_Affixes.cpp
// -----------------------------------------------------------------------------
// Affix helpers: worldstate label, per-affix spell/weather mapping, and weather sync.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "WeatherMgr.h"

// Return a short code for affix to show via worldstate or announcements
static const char* HL_AffixName(OutdoorPvPHL::AffixType a)
{
    switch (a)
    {
        case OutdoorPvPHL::AFFIX_HASTE_BUFF: return "Haste";
        case OutdoorPvPHL::AFFIX_SLOW: return "Slow";
        case OutdoorPvPHL::AFFIX_REDUCED_HEALING: return "Reduced Healing";
        case OutdoorPvPHL::AFFIX_REDUCED_ARMOR: return "Reduced Armor";
        case OutdoorPvPHL::AFFIX_BOSS_ENRAGE: return "Boss Enrage";
        default: return "None";
    }
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

// Compute effective spells/weather, preferring per-affix overrides
uint32 OutdoorPvPHL::GetPlayerSpellForAffix(AffixType a) const
{
    if (a >= AFFIX_NONE && a <= AFFIX_BOSS_ENRAGE)
    {
        uint32 v = _affixPlayerSpell[a];
        if (v) return v;
    }
    switch (a)
    {
        case AFFIX_HASTE_BUFF: return _affixSpellHaste;
        case AFFIX_SLOW: return _affixSpellSlow;
        case AFFIX_REDUCED_HEALING: return _affixSpellReducedHealing;
        case AFFIX_REDUCED_ARMOR: return _affixSpellReducedArmor;
        default: return 0;
    }
}

uint32 OutdoorPvPHL::GetNpcSpellForAffix(AffixType a) const
{
    if (a >= AFFIX_NONE && a <= AFFIX_BOSS_ENRAGE)
    {
        uint32 v = _affixNpcSpell[a];
        if (v) return v;
    }
    if (a == AFFIX_BOSS_ENRAGE) return _affixSpellBossEnrage;
    if (a == AFFIX_SLOW || a == AFFIX_REDUCED_ARMOR || a == AFFIX_REDUCED_HEALING || a == AFFIX_BOSS_ENRAGE)
        return _affixSpellBadWeatherNpcBuff;
    return 0;
}

void OutdoorPvPHL::ApplyAffixWeather()
{
    if (!_affixWeatherEnabled)
        return;
    uint32 weatherType = 0;
    float intensity = 0.5f;
    if (_activeAffix >= AFFIX_NONE && _activeAffix <= AFFIX_BOSS_ENRAGE)
    {
        if (_affixWeatherType[_activeAffix])
            weatherType = _affixWeatherType[_activeAffix];
        if (_affixWeatherIntensity[_activeAffix] > 0.0f)
            intensity = _affixWeatherIntensity[_activeAffix];
    }
    uint32 const zoneId = OutdoorPvPHLBuffZones[0];
    if (Weather* w = WeatherMgr::FindWeather(zoneId))
        w->SetWeather(static_cast<WeatherType>(weatherType), intensity);
    else if (Weather* w2 = WeatherMgr::AddWeather(zoneId))
        w2->SetWeather(static_cast<WeatherType>(weatherType), intensity);
}
