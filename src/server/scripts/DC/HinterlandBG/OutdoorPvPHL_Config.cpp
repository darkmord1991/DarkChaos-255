// -----------------------------------------------------------------------------
// OutdoorPvPHL_Config.cpp
// -----------------------------------------------------------------------------
// Loads configuration values for Hinterland BG from worldserver.conf or
// configs/modules/hinterlandbg.conf(.dist). All values have sensible defaults
// in the constructor; this function overrides them if keys are present.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
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
        _afkWarnSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.WarnSeconds", _afkWarnSeconds);
        _afkTeleportSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.TeleportSeconds", _afkTeleportSeconds);
        _statusBroadcastEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Broadcast.Enabled", _statusBroadcastEnabled);
        uint32 periodSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Broadcast.Period", _statusBroadcastPeriodMs / IN_MILLISECONDS);
        _statusBroadcastPeriodMs = periodSec * IN_MILLISECONDS;
        _autoResetTeleport = sConfigMgr->GetOption<bool>("HinterlandBG.AutoReset.Teleport", _autoResetTeleport);
        _expiryUseTiebreaker = sConfigMgr->GetOption<bool>("HinterlandBG.Expiry.Tiebreaker", _expiryUseTiebreaker);
        _initialResourcesAlliance = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Alliance", _initialResourcesAlliance);
        _initialResourcesHorde = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Horde", _initialResourcesHorde);
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
    _affixEnabled         = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Enabled", _affixEnabled);
    _affixWeatherEnabled  = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.WeatherEnabled", _affixWeatherEnabled);
    _affixPeriodSec       = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Period", _affixPeriodSec);
    _affixSpellHaste      = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.Haste", _affixSpellHaste);
    _affixSpellSlow       = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.Slow", _affixSpellSlow);
    _affixSpellReducedHealing = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.ReducedHealing", _affixSpellReducedHealing);
    _affixSpellReducedArmor   = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.ReducedArmor", _affixSpellReducedArmor);
    _affixSpellBossEnrage     = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.BossEnrage", _affixSpellBossEnrage);
    _affixSpellBadWeatherNpcBuff = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Spell.BadWeatherNpcBuff", _affixSpellBadWeatherNpcBuff);
    _affixRandomOnStart      = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.RandomOnBattleStart", _affixRandomOnStart);
    _affixAnnounce           = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Announce", _affixAnnounce);
    _affixWorldstateEnabled  = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.WorldstateEnabled", _affixWorldstateEnabled);
    _statsIncludeManualResets = sConfigMgr->GetOption<bool>("HinterlandBG.Stats.IncludeManual", _statsIncludeManualResets);
    // Per-affix overrides: player/npc spells and weather
    auto loadAffixArrayU32 = [&](char const* base, uint32 arr[6])
    {
        // keys like base.0 .. base.5 (or by name)
        for (uint32 i = 0; i <= 5; ++i)
        {
            char key[128];
            snprintf(key, sizeof(key), "%s.%u", base, i);
            arr[i] = sConfigMgr->GetOption<uint32>(key, arr[i]);
        }
    };
    auto loadAffixArrayFloat = [&](char const* base, float arr[6])
    {
        for (uint32 i = 0; i <= 5; ++i)
        {
            char key[128];
            snprintf(key, sizeof(key), "%s.%u", base, i);
            arr[i] = sConfigMgr->GetOption<float>(key, arr[i]);
        }
    };
    loadAffixArrayU32("HinterlandBG.Affix.PlayerSpell", _affixPlayerSpell);
    loadAffixArrayU32("HinterlandBG.Affix.NpcSpell", _affixNpcSpell);
    loadAffixArrayU32("HinterlandBG.Affix.WeatherType", _affixWeatherType);
    loadAffixArrayFloat("HinterlandBG.Affix.WeatherIntensity", _affixWeatherIntensity);
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
                try { uint32 v = static_cast<uint32>(std::stoul(token)); parsed.push_back(v); } catch (...) {}
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
            try { if (!token.empty()) out.push_back(static_cast<uint32>(std::stoul(token))); } catch (...) {}
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
                } catch (...) {}
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
        outSet.insert(v.begin(), v.end());
    };
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCBossEntriesAlliance", _npcBossEntriesAlliance);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCBossEntriesHorde",    _npcBossEntriesHorde);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCNormalEntriesAlliance", _npcNormalEntriesAlliance);
    parseCsvSet("HinterlandBG.ResourcesLoss.NPCNormalEntriesHorde",    _npcNormalEntriesHorde);
}
