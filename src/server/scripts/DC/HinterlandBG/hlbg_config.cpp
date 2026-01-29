// -----------------------------------------------------------------------------
// hlbg_config.cpp
// -----------------------------------------------------------------------------
// Loads configuration values for Hinterland BG from worldserver.conf or
// configs/modules/hinterlandbg.conf(.dist). All values have sensible defaults
// in the constructor; this function overrides them if keys are present.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "Config.h"
#include <unordered_map>
#include <string>
#include <vector>

// Entry point called during SetupOutdoorPvP() and constructor to refresh settings.
void OutdoorPvPHL::LoadConfig()
{
    // Read options that may come from worldserver.conf or modules configs.
    // Note: The modules config loader (modules/CMakeLists CONFIG_LIST) handles copying
    // and loading hinterlandbg.conf(.dist) under configs/modules automatically.
    if (sConfigMgr)
    {
        _matchDurationSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.MatchDuration", _matchDurationSeconds);
        _minLevel = sConfigMgr->GetOption<uint32>("HinterlandBG.MinLevel", _minLevel);  // minimum level to join (default 1)
        _warmupDurationSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.WarmupDuration", _warmupDurationSeconds);
        _queueEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Queue.Enabled", _queueEnabled);
        _minPlayersToStart = sConfigMgr->GetOption<uint32>("HinterlandBG.Queue.MinPlayers", _minPlayersToStart);
        _maxGroupSize = sConfigMgr->GetOption<uint32>("HinterlandBG.Queue.MaxGroupSize", _maxGroupSize);
        _afkWarnSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.WarnSeconds", _afkWarnSeconds);
        _afkTeleportSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.TeleportSeconds", _afkTeleportSeconds);
        _statusBroadcastEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Broadcast.Enabled", _statusBroadcastEnabled);
        uint32 periodSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Broadcast.Period", _statusBroadcastPeriodMs / IN_MILLISECONDS);
        _statusBroadcastPeriodMs = periodSec * IN_MILLISECONDS;
        _autoResetTeleport = sConfigMgr->GetOption<bool>("HinterlandBG.AutoReset.Teleport", _autoResetTeleport);
        _expiryUseTiebreaker = sConfigMgr->GetOption<bool>("HinterlandBG.Expiry.Tiebreaker", _expiryUseTiebreaker);
        _initialResourcesAlliance = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Alliance", _initialResourcesAlliance);
        _initialResourcesHorde = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Horde", _initialResourcesHorde);
    _season = sConfigMgr->GetOption<uint32>("HinterlandBG.Season", _season);
        // Optional configurable base coordinates
        auto getf = [](char const* key, float defv){ return sConfigMgr->GetOption<float>(key, defv); };
        auto geti = [](char const* key, uint32 defv){ return sConfigMgr->GetOption<uint32>(key, defv); };
        _baseAlliance.map = geti("HinterlandBG.Base.Alliance.Map", _baseAlliance.map);
        _baseAlliance.x   = getf("HinterlandBG.Base.Alliance.X",   _baseAlliance.x);
        _baseAlliance.y   = getf("HinterlandBG.Base.Alliance.Y",   _baseAlliance.y);
        _baseAlliance.z   = getf("HinterlandBG.Base.Alliance.Z",   _baseAlliance.z);
        _baseAlliance.o   = getf("HinterlandBG.Base.Alliance.O",   _baseAlliance.o);
        _baseHorde.map    = geti("HinterlandBG.Base.Horde.Map",    _baseHorde.map);
        _baseHorde.x      = getf("HinterlandBG.Base.Horde.X",      _baseHorde.x);
        _baseHorde.y      = getf("HinterlandBG.Base.Horde.Y",      _baseHorde.y);
        _baseHorde.z      = getf("HinterlandBG.Base.Horde.Z",      _baseHorde.z);
        _baseHorde.o      = getf("HinterlandBG.Base.Horde.O",      _baseHorde.o);
        _rewardMatchHonor = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonor", _rewardMatchHonor);
        _rewardMatchHonorDepletion = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorDepletion", _rewardMatchHonorDepletion);
        _rewardMatchHonorTiebreaker = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorTiebreaker", _rewardMatchHonorTiebreaker);
    _worldAnnounceOnExpiry = sConfigMgr->GetOption<bool>("HinterlandBG.Announce.ExpiryWorld", _worldAnnounceOnExpiry);
        _worldAnnounceOnDepletion = sConfigMgr->GetOption<bool>("HinterlandBG.Announce.DepletionWorld", _worldAnnounceOnDepletion);
    _rewardMatchHonorLoser = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorLoser", _rewardMatchHonorLoser);
        _rewardKillItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemId", _rewardKillItemId);
        _rewardKillItemCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemCount", _rewardKillItemCount);
        _rewardNpcTokenItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemId", _rewardNpcTokenItemId);
        _rewardNpcTokenCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemCount", _rewardNpcTokenCount);
    // Persistence and lock
    _persistenceEnabled   = sConfigMgr->GetOption<bool>("HinterlandBG.Persistence.Enabled", true);
    _lockEnabled          = sConfigMgr->GetOption<bool>("HinterlandBG.Lock.Enabled", false);
    _lockDurationSeconds  = sConfigMgr->GetOption<uint32>("HinterlandBG.Lock.Duration", 0u);
    _lockDurationExpirySec    = sConfigMgr->GetOption<uint32>("HinterlandBG.Lock.Duration.Expiry", _lockDurationSeconds);
    _lockDurationDepletionSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Lock.Duration.Depletion", _lockDurationSeconds);
    // Per-kill spell feedback (optional)
    _killSpellOnPlayerKillAlliance = sConfigMgr->GetOption<uint32>("HinterlandBG.KillSpell.PlayerKillAlliance", _killSpellOnPlayerKillAlliance);
    _killSpellOnPlayerKillHorde    = sConfigMgr->GetOption<uint32>("HinterlandBG.KillSpell.PlayerKillHorde", _killSpellOnPlayerKillHorde);
    _killSpellOnNpcKill            = sConfigMgr->GetOption<uint32>("HinterlandBG.KillSpell.NpcKill", _killSpellOnNpcKill);
    // Affix system (optional)
    _affixEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Enabled", _affixEnabled);
    _affixWeatherEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Weather.Enabled", _affixWeatherEnabled);
    _affixPeriodSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Period", _affixPeriodSec);
    _affixRandomOnStart = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.RandomOnStart", _affixRandomOnStart);
    _affixAnnounce = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Announce", _affixAnnounce);
    _affixWorldstateEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Worldstate", _affixWorldstateEnabled);

    // Populate default spell/weather mappings (can be overridden below)
    InitAffixDefaults();

    // Optional overrides for affix spells
    _affixPlayerSpell[AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.PlayerSpell.Sunlight", _affixPlayerSpell[AFFIX_SUNLIGHT]);
    _affixPlayerSpell[AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.PlayerSpell.ClearSkies", _affixPlayerSpell[AFFIX_CLEAR_SKIES]);
    _affixPlayerSpell[AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.PlayerSpell.GentleBreeze", _affixPlayerSpell[AFFIX_GENTLE_BREEZE]);
    _affixNpcSpell[AFFIX_STORM] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.NpcSpell.Storm", _affixNpcSpell[AFFIX_STORM]);
    _affixNpcSpell[AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.NpcSpell.HeavyRain", _affixNpcSpell[AFFIX_HEAVY_RAIN]);
    _affixNpcSpell[AFFIX_FOG] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.NpcSpell.Fog", _affixNpcSpell[AFFIX_FOG]);

    // Optional overrides for affix weather
    _affixWeatherType[AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.Sunlight", _affixWeatherType[AFFIX_SUNLIGHT]);
    _affixWeatherType[AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.ClearSkies", _affixWeatherType[AFFIX_CLEAR_SKIES]);
    _affixWeatherType[AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.GentleBreeze", _affixWeatherType[AFFIX_GENTLE_BREEZE]);
    _affixWeatherType[AFFIX_STORM] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.Storm", _affixWeatherType[AFFIX_STORM]);
    _affixWeatherType[AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.HeavyRain", _affixWeatherType[AFFIX_HEAVY_RAIN]);
    _affixWeatherType[AFFIX_FOG] = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.WeatherType.Fog", _affixWeatherType[AFFIX_FOG]);

    _affixWeatherIntensity[AFFIX_SUNLIGHT] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.Sunlight", _affixWeatherIntensity[AFFIX_SUNLIGHT]);
    _affixWeatherIntensity[AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.ClearSkies", _affixWeatherIntensity[AFFIX_CLEAR_SKIES]);
    _affixWeatherIntensity[AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.GentleBreeze", _affixWeatherIntensity[AFFIX_GENTLE_BREEZE]);
    _affixWeatherIntensity[AFFIX_STORM] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.Storm", _affixWeatherIntensity[AFFIX_STORM]);
    _affixWeatherIntensity[AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.HeavyRain", _affixWeatherIntensity[AFFIX_HEAVY_RAIN]);
    _affixWeatherIntensity[AFFIX_FOG] = sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensity.Fog", _affixWeatherIntensity[AFFIX_FOG]);
    _statsIncludeManualResets = sConfigMgr->GetOption<bool>("HinterlandBG.Stats.IncludeManual", _statsIncludeManualResets);
    // Resource loss amounts
    _resourcesLossPlayerKill = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.PlayerKill", _resourcesLossPlayerKill);
    _resourcesLossNpcNormal  = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.NpcNormal",  _resourcesLossNpcNormal);
    _resourcesLossNpcBoss    = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.NpcBoss",    _resourcesLossNpcBoss);
        std::string csv = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.KillHonorValues", "");
        if (!csv.empty())
        {
            std::vector<uint32> parsed;
            size_t start = 0;
            while (start < csv.size())
            {
                size_t comma = csv.find(',', start);
                std::string token = csv.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
                try { uint32 v = static_cast<uint32>(std::stoul(token)); parsed.push_back(v); }
                catch (std::exception const&) { /* Skip invalid numeric token */ }
                catch (...) { /* Skip unknown parse error */ }
                if (comma == std::string::npos) break; else start = comma + 1;
            }
            if (!parsed.empty())
                _killHonorValues = std::move(parsed);
        }
    }
    // Parse Alliance NPC reward entries (CSV of entry IDs)
    auto parseCsvU32 = [](std::string const& in) -> std::vector<uint32>
    {
        std::vector<uint32> out;
        size_t start = 0;
        while (start < in.size())
        {
            size_t comma = in.find(',', start);
            std::string token = in.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            try { if (!token.empty()) out.push_back(static_cast<uint32>(std::stoul(token))); }
            catch (std::exception const&) { /* Skip invalid numeric token */ }
            catch (...) { /* Skip unknown parse error */ }
            if (comma == std::string::npos) break; else start = comma + 1;
        }
        return out;
    };
    std::string aList = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesAlliance", "");
    std::string hList = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesHorde", "");
    if (!aList.empty()) _npcRewardEntriesAlliance = parseCsvU32(aList);
    if (!hList.empty()) _npcRewardEntriesHorde = parseCsvU32(hList);

    // Optional per-NPC token counts: CSV "entry:count" pairs per team
    auto parseEntryCounts = [](std::string const& in) -> std::unordered_map<uint32, uint32>
    {
        std::unordered_map<uint32, uint32> out;
        size_t start = 0;
        while (start < in.size())
        {
            size_t comma = in.find(',', start);
            std::string pair = in.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            size_t colon = pair.find(':');
            if (colon != std::string::npos)
            {
                try {
                    uint32 entry = static_cast<uint32>(std::stoul(pair.substr(0, colon)));
                    uint32 count = static_cast<uint32>(std::stoul(pair.substr(colon + 1)));
                    if (entry && count)
                        out[entry] = count;
                }
                catch (std::exception const&) { /* Skip invalid entry:count pair */ }
                catch (...) { /* Skip unknown parse error */ }
            }
            if (comma == std::string::npos) break; else start = comma + 1;
        }
        return out;
    };
    std::string aCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsAlliance", "");
    std::string hCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsHorde", "");
    if (!aCounts.empty()) _npcRewardCountsAlliance = parseEntryCounts(aCounts);
    if (!hCounts.empty()) _npcRewardCountsHorde = parseEntryCounts(hCounts);

    // NPC classification for resource loss (CSV lists of entries)
    auto parseCsvSet = [&](char const* key, std::unordered_set<uint32>& outSet)
    {
        std::string list = sConfigMgr->GetOption<std::string>(key, "");
        if (list.empty()) return;
        auto v = parseCsvU32(list);
        outSet.clear();
        for (auto const& e : v)
            outSet.insert(e);
    };
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCBossEntriesAlliance", _npcBossEntriesAlliance);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCBossEntriesHorde",    _npcBossEntriesHorde);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCNormalEntriesAlliance", _npcNormalEntriesAlliance);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCNormalEntriesHorde",    _npcNormalEntriesHorde);
}
