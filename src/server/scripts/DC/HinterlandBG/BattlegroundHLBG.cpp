#include "BattlegroundHLBG.h"

#include "Config.h"
#include "Creature.h"
#include "Chat.h"
#include "Group.h"
#include "Map.h"
#include "MapMgr.h"
#include "Player.h"
#include "Time/GameTime.h"
#include "Weather.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "WorldStateDefines.h"

#include "DC/AddonExtension/dc_addon_hlbg.h"
#include "DC/CrossSystem/CrossSystemCommon.h"
#include "ObjectGuid.h"
#include "HLBGService.h"
#include "hlbg.h"
#include "hlbg_constants.h"
#include "hlbg_reset_worker.h"

#include <algorithm>
#include <sstream>

BattlegroundTypeId BATTLEGROUND_HLBG = BattlegroundTypeId(20);
BattlegroundQueueTypeId BATTLEGROUND_QUEUE_HLBG = BattlegroundQueueTypeId(14);

using namespace HinterlandBGConstants;

namespace
{
    constexpr uint32 HLBGQuestCreditWin = 920102;
    constexpr uint32 HLBGQuestCreditParticipation = 920103;
    constexpr uint32 HLBGHudSyncIntervalMs = 1000;
    constexpr uint32 HLBGHudHeartbeatIntervalMs = 30000;
    constexpr uint32 HLBGAfkTickIntervalMs = 2000;
    constexpr uint32 WORLD_STATE_HL_AFFIX_TEXT = 0xDD1010;
    constexpr uint32 HLBGAffixSlotCount = 3u;

    struct BattlegroundHLBGScore final : BattlegroundScore
    {
        explicit BattlegroundHLBGScore(ObjectGuid playerGuid) : BattlegroundScore(playerGuid) { }

        void BuildObjectivesBlock(WorldPacket& data) final
        {
            data << uint32(3);
            data << uint32(ResourcesCaptured);
            data << uint32(NpcKills);
            data << uint32(BossKills);
        }

        uint32 GetAttr1() const final { return ResourcesCaptured; }
        uint32 GetAttr2() const final { return NpcKills; }
        uint32 GetAttr3() const final { return BossKills; }

        // BattlegroundScore keeps these protected; a derived member function
        // can read them, BattlegroundHLBG cannot. Expose what the participant
        // rows need.
        [[nodiscard]] uint32 GetKillingBlowCount() const { return KillingBlows; }
        [[nodiscard]] uint32 GetDeathCount() const { return Deaths; }
        [[nodiscard]] uint32 GetHealingDoneTotal() const { return HealingDone; }
        [[nodiscard]] uint32 GetDamageDoneTotal() const { return DamageDone; }

        uint32 ResourcesCaptured = 0;
        uint32 NpcKills = 0;
        uint32 BossKills = 0;
    };

    // HLBGHudMetrics lives in BattlegroundHLBG.h so member signatures can
    // pass it around (single CollectHudMetrics pass per HUD tick).

    uint32 NowSec()
    {
        return static_cast<uint32>(GameTime::GetGameTime().count());
    }

    DCAddon::HLBG::HLBGStatus GetAddonStatus(BattlegroundHLBG const* bg)
    {
        if (!bg)
            return DCAddon::HLBG::STATUS_NONE;

        switch (bg->GetStatus())
        {
            case STATUS_WAIT_JOIN:
                return DCAddon::HLBG::STATUS_PREP;
            case STATUS_IN_PROGRESS:
                return DCAddon::HLBG::STATUS_ACTIVE;
            case STATUS_WAIT_LEAVE:
                return DCAddon::HLBG::STATUS_ENDED;
            default:
                return DCAddon::HLBG::STATUS_NONE;
        }
    }

    HLBGHudMetrics CollectHudMetrics(BattlegroundHLBG const* bg)
    {
        HLBGHudMetrics metrics;
        if (!bg)
            return metrics;

        for (auto const& playerEntry : bg->GetPlayers())
        {
            Player* player = playerEntry.second;
            if (!player || !player->IsInWorld())
                continue;

            if (player->GetBgTeamId() == TEAM_ALLIANCE)
            {
                ++metrics.alliancePlayers;
                metrics.alliancePlayerKills += bg->GetPlayerHKDelta(player);
            }
            else if (player->GetBgTeamId() == TEAM_HORDE)
            {
                ++metrics.hordePlayers;
                metrics.hordePlayerKills += bg->GetPlayerHKDelta(player);
            }
        }

        metrics.allianceNpcKills = bg->GetNpcKillCount(TEAM_ALLIANCE);
        metrics.hordeNpcKills = bg->GetNpcKillCount(TEAM_HORDE);
        return metrics;
    }

    std::string BuildAffixNameList(BattlegroundHLBG const* bg)
    {
        if (!bg)
            return "None";

        std::ostringstream out;
        bool first = true;
        for (uint32 slot = 0; slot < HLBGAffixSlotCount; ++slot)
        {
            uint8 affixCode = bg->GetActiveAffixCode(slot);
            if (!affixCode)
                continue;

            if (!first)
                out << ", ";

            first = false;
            out << GetAffixName(affixCode);
        }

        return first ? std::string("None") : out.str();
    }

    std::vector<uint32> ParseCsvU32(std::string const& input)
    {
        return DCUtils::ParseUInt32List(input);
    }

    std::unordered_map<uint32, uint32> ParseEntryCounts(std::string const& input)
    {
        std::unordered_map<uint32, uint32> values;
        std::size_t start = 0;
        while (start < input.size())
        {
            std::size_t comma = input.find(',', start);
            std::string token = input.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            std::size_t colon = token.find(':');
            if (colon != std::string::npos)
            {
                try
                {
                    uint32 entry = static_cast<uint32>(std::stoul(token.substr(0, colon)));
                    uint32 count = static_cast<uint32>(std::stoul(token.substr(colon + 1)));
                    if (entry && count)
                        values[entry] = count;
                }
                catch (...)
                {
                }
            }

            if (comma == std::string::npos)
                break;

            start = comma + 1;
        }

        return values;
    }

    std::unordered_set<uint32> ToSet(std::vector<uint32> const& values)
    {
        std::unordered_set<uint32> out;
        for (uint32 value : values)
            out.insert(value);
        return out;
    }

    template <typename Worker>
    void VisitBattlegroundMap(BattlegroundHLBG const* battleground, Worker& worker)
    {
        if (!battleground)
            return;

        Map* map = sMapMgr->FindMap(battleground->GetMapId(), battleground->GetInstanceID());
        auto* battlegroundMap = dynamic_cast<BattlegroundMap*>(map);
        if (!battlegroundMap)
            return;

        TypeContainerVisitor<Worker, MapStoredObjectTypesContainer> visitor(worker);
        visitor.Visit(battlegroundMap->GetObjectsStore());
    }

    // Applies or removes a whole set of affix auras in a single pass over the
    // battleground map's object store - one traversal per affix spell used to
    // cost a full map walk each.
    struct HLBGNpcAuraWorker
    {
        uint32 areaId = HLBG_AREA_ID;
        std::vector<uint32> spellIds;
        bool remove = false;

        void Visit(std::unordered_map<ObjectGuid, Creature*>& creatureMap)
        {
            if (spellIds.empty())
                return;

            for (auto const& creatureEntry : creatureMap)
            {
                Creature* creature = creatureEntry.second;
                if (!creature || !creature->IsInWorld() || creature->GetAreaId() != areaId)
                    continue;

                if (creature->IsPlayer() || creature->IsPet() || creature->IsGuardian()
                    || creature->IsSummon() || creature->IsTotem())
                {
                    continue;
                }

                for (uint32 spellId : spellIds)
                {
                    if (remove)
                        creature->RemoveAurasDueToSpell(spellId);
                    else if (!creature->HasAura(spellId))
                        creature->CastSpell(creature, spellId, true);
                }
            }
        }

        template <class T>
        void Visit(std::unordered_map<ObjectGuid, T*>&)
        {
        }
    };

    // Runs `worker` over the battleground map once, if the map is loaded.
    void ApplyNpcAuras(BattlegroundHLBG const* battleground, std::vector<uint32> spellIds, bool remove)
    {
        if (spellIds.empty())
            return;

        HLBGNpcAuraWorker worker;
        worker.areaId = HLBG_AREA_ID;
        worker.spellIds = std::move(spellIds);
        worker.remove = remove;
        VisitBattlegroundMap(battleground, worker);
    }
}

BattlegroundHLBG::BattlegroundHLBG()
{
    InitAffixDefaults();
    _killHonorValues = { 17u, 11u, 19u, 22u };
    _npcRewardEntriesAlliance = {
        Alliance_Boss, Alliance_Healer, Alliance_Infantry, Alliance_Squadleader,
        Alliance_Battlewarden, Alliance_Sentry, Alliance_Scout, Alliance_GryphonHerald,
        Alliance_BannerBearer, Alliance_WatchCaptain, Alliance_Marksman,
        Alliance_Pathfinder, Alliance_RoostTender
    };
    _npcRewardEntriesHorde = {
        Horde_Boss, Horde_Heal, Horde_Infantry, Horde_Squadleader, Horde_Warcaller,
        Horde_Watchblade, Horde_Spiritmender, Horde_BannerSinger, Horde_Drumkeeper,
        Horde_FiresideShaman, Horde_Headhunter, Horde_Ritespeaker, Horde_BonfireTender
    };
    _npcBossEntriesAlliance = { Alliance_Boss };
    _npcBossEntriesHorde = { Horde_Boss };
    _npcNormalEntriesAlliance = {
        Alliance_Healer, Alliance_Infantry, Alliance_Squadleader, Alliance_Battlewarden,
        Alliance_Sentry, Alliance_Scout, Alliance_GryphonHerald, Alliance_BannerBearer,
        Alliance_WatchCaptain, Alliance_Marksman, Alliance_Pathfinder, Alliance_RoostTender
    };
    _npcNormalEntriesHorde = {
        Horde_Heal, Horde_Infantry, Horde_Squadleader, Horde_Warcaller,
        Horde_Watchblade, Horde_Spiritmender, Horde_BannerSinger, Horde_Drumkeeper,
        Horde_FiresideShaman, Horde_Headhunter, Horde_Ritespeaker, Horde_BonfireTender
    };

    LoadConfig();
}

void BattlegroundHLBG::InitAffixDefaults()
{
    for (uint8 affixCode = HLBG_AFFIX_NONE; affixCode <= HLBG_AFFIX_LAST; ++affixCode)
    {
        _affixPlayerSpell[affixCode] = GetDefaultAffixPlayerSpell(affixCode);
        _affixNpcSpell[affixCode] = GetDefaultAffixNpcSpell(affixCode);
        _affixWeatherState[affixCode] = GetDefaultAffixWeatherState(affixCode);
        _affixWeatherIntensity[affixCode] = GetDefaultAffixWeatherIntensity(affixCode);
    }
}

void BattlegroundHLBG::LoadConfig()
{
    if (!sConfigMgr)
        return;

    _matchDurationSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.MatchDuration", _matchDurationSeconds);
    _afkWarnSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.WarnSeconds", _afkWarnSeconds);
    _afkTeleportSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.TeleportSeconds", _afkTeleportSeconds);
    _initialResourcesAlliance = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Alliance", _initialResourcesAlliance);
    _initialResourcesHorde = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Horde", _initialResourcesHorde);
    _rewardMatchHonorDepletion = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorDepletion", _rewardMatchHonorDepletion);
    _rewardMatchHonorTiebreaker = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorTiebreaker", _rewardMatchHonorTiebreaker);
    _rewardMatchHonorLoser = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonorLoser", _rewardMatchHonorLoser);
    _rewardKillItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemId", _rewardKillItemId);
    _rewardKillItemCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemCount", _rewardKillItemCount);
    _rewardNpcTokenItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemId", _rewardNpcTokenItemId);
    _rewardNpcTokenCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemCount", _rewardNpcTokenCount);
    _resourcesLossPlayerKill = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.PlayerKill", _resourcesLossPlayerKill);
    _resourcesLossNpcNormal = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.NpcNormal", _resourcesLossNpcNormal);
    _resourcesLossNpcBoss = sConfigMgr->GetOption<uint32>("HinterlandBG.ResourcesLoss.NpcBoss", _resourcesLossNpcBoss);
    _affixEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Enabled", _affixEnabled);
    _affixWeatherEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Weather.Enabled", _affixWeatherEnabled);
    _affixPeriodSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.Period", _affixPeriodSec);
    _affixRandomOnStart = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.RandomOnStart", _affixRandomOnStart);
    _affixAnnounce = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Announce", _affixAnnounce);
    _affixWorldstateEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Affix.Worldstate", _affixWorldstateEnabled);
    _affixConcurrentCount = std::clamp(
        sConfigMgr->GetOption<uint32>("HinterlandBG.Affix.ConcurrentCount", _affixConcurrentCount),
        1u, HLBGAffixSlotCount);
    _affixWarlordsBossMultiplier = std::max(1u, sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.Warlords.BossMultiplier", _affixWarlordsBossMultiplier));
    _affixBloodlustKillMultiplier = std::max(1u, sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.Bloodlust.KillMultiplier", _affixBloodlustKillMultiplier));
    _affixNightfallLightId = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.Nightfall.LightId", _affixNightfallLightId);
    _affixNightfallFadeSec = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.Nightfall.FadeSeconds", _affixNightfallFadeSec);
    _affixWeatherIntensityVariance = std::clamp(
        sConfigMgr->GetOption<float>("HinterlandBG.Affix.WeatherIntensityVariance", _affixWeatherIntensityVariance),
        0.0f, 1.0f);

    _affixPlayerSpell[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.Sunlight", _affixPlayerSpell[HLBG_AFFIX_SUNLIGHT]);
    _affixPlayerSpell[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.ClearSkies", _affixPlayerSpell[HLBG_AFFIX_CLEAR_SKIES]);
    _affixPlayerSpell[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.GentleBreeze", _affixPlayerSpell[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixPlayerSpell[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.Storm", _affixPlayerSpell[HLBG_AFFIX_STORM]);
    _affixPlayerSpell[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.HeavyRain", _affixPlayerSpell[HLBG_AFFIX_HEAVY_RAIN]);
    _affixPlayerSpell[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.Fog", _affixPlayerSpell[HLBG_AFFIX_FOG]);

    // Optional per-affix aura for the guard camps. Defaults to 0 (unused) for
    // every affix; the map traversal in ApplyAffixEffects is skipped entirely
    // while none is set, so leaving these at 0 costs nothing.
    _affixNpcSpell[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Sunlight", _affixNpcSpell[HLBG_AFFIX_SUNLIGHT]);
    _affixNpcSpell[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.ClearSkies", _affixNpcSpell[HLBG_AFFIX_CLEAR_SKIES]);
    _affixNpcSpell[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.GentleBreeze", _affixNpcSpell[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixNpcSpell[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Storm", _affixNpcSpell[HLBG_AFFIX_STORM]);
    _affixNpcSpell[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.HeavyRain", _affixNpcSpell[HLBG_AFFIX_HEAVY_RAIN]);
    _affixNpcSpell[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Fog", _affixNpcSpell[HLBG_AFFIX_FOG]);
    _affixNpcSpell[HLBG_AFFIX_NIGHTFALL] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Nightfall", _affixNpcSpell[HLBG_AFFIX_NIGHTFALL]);

    _affixWeatherState[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.Sunlight", _affixWeatherState[HLBG_AFFIX_SUNLIGHT]);
    _affixWeatherState[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.ClearSkies", _affixWeatherState[HLBG_AFFIX_CLEAR_SKIES]);
    _affixWeatherState[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.GentleBreeze", _affixWeatherState[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixWeatherState[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.Storm", _affixWeatherState[HLBG_AFFIX_STORM]);
    _affixWeatherState[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.HeavyRain", _affixWeatherState[HLBG_AFFIX_HEAVY_RAIN]);
    _affixWeatherState[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherState.Fog", _affixWeatherState[HLBG_AFFIX_FOG]);

    _affixWeatherIntensity[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.Sunlight", _affixWeatherIntensity[HLBG_AFFIX_SUNLIGHT]);
    _affixWeatherIntensity[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.ClearSkies", _affixWeatherIntensity[HLBG_AFFIX_CLEAR_SKIES]);
    _affixWeatherIntensity[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.GentleBreeze", _affixWeatherIntensity[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixWeatherIntensity[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.Storm", _affixWeatherIntensity[HLBG_AFFIX_STORM]);
    _affixWeatherIntensity[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.HeavyRain", _affixWeatherIntensity[HLBG_AFFIX_HEAVY_RAIN]);
    _affixWeatherIntensity[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<float>(
        "HinterlandBG.Affix.WeatherIntensity.Fog", _affixWeatherIntensity[HLBG_AFFIX_FOG]);

    std::string killHonorCsv = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.KillHonorValues", "");
    if (!killHonorCsv.empty())
    {
        std::vector<uint32> parsed = ParseCsvU32(killHonorCsv);
        if (!parsed.empty())
            _killHonorValues = std::move(parsed);
    }

    std::string allianceRewardEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesAlliance", "");
    std::string hordeRewardEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesHorde", "");
    if (!allianceRewardEntries.empty())
        _npcRewardEntriesAlliance = ToSet(ParseCsvU32(allianceRewardEntries));
    if (!hordeRewardEntries.empty())
        _npcRewardEntriesHorde = ToSet(ParseCsvU32(hordeRewardEntries));

    std::string allianceRewardCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsAlliance", "");
    std::string hordeRewardCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsHorde", "");
    if (!allianceRewardCounts.empty())
        _npcRewardCountsAlliance = ParseEntryCounts(allianceRewardCounts);
    if (!hordeRewardCounts.empty())
        _npcRewardCountsHorde = ParseEntryCounts(hordeRewardCounts);

    std::string allianceBossEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.ResourcesLoss.NPCBossEntriesAlliance", "");
    std::string hordeBossEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.ResourcesLoss.NPCBossEntriesHorde", "");
    std::string allianceNormalEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.ResourcesLoss.NPCNormalEntriesAlliance", "");
    std::string hordeNormalEntries = sConfigMgr->GetOption<std::string>("HinterlandBG.ResourcesLoss.NPCNormalEntriesHorde", "");

    if (!allianceBossEntries.empty())
        _npcBossEntriesAlliance = ToSet(ParseCsvU32(allianceBossEntries));
    if (!hordeBossEntries.empty())
        _npcBossEntriesHorde = ToSet(ParseCsvU32(hordeBossEntries));
    if (!allianceNormalEntries.empty())
        _npcNormalEntriesAlliance = ToSet(ParseCsvU32(allianceNormalEntries));
    if (!hordeNormalEntries.empty())
        _npcNormalEntriesHorde = ToSet(ParseCsvU32(hordeNormalEntries));
}

void BattlegroundHLBG::Init()
{
    Battleground::Init();
    ResetMatchState();
}

void BattlegroundHLBG::ResetMatchState()
{
    ClearAffixEffects();
    // ClearAffixEffects only removes auras. The zone weather and light are
    // separate overrides, and AdminResetMatch skips SelectAffixForNewBattle
    // unless the match is already running - without these an admin reset during
    // warmup left the previous affix's weather and darkness in place. Both are
    // no-ops before the instance map exists.
    ClearAffixWeather();
    ClearAffixLight();
    m_TeamScores[TEAM_ALLIANCE] = _initialResourcesAlliance;
    m_TeamScores[TEAM_HORDE] = _initialResourcesHorde;
    _matchStartEpoch = 0;
    _matchEndEpoch = 0;
    _hudSyncTimerMs = 0;
    _afkCheckTimerMs = 0;
    _affixRotationTimerMs = 0;
    _affixNextChangeEpoch = 0;
    _allianceNpcKills = 0;
    _hordeNpcKills = 0;
    _endedByDepletion = false;
    _matchRewardsGranted = false;
    _matchResultRecorded = false;
    _activeAffixes.fill(HLBG_AFFIX_NONE);
    _activeAffixWeatherIntensity = 0.0f;
    _hudDirty = true;
    _lastHudSnapshotKey = 0u;
    _afkFlagged.clear();
    // Infractions are per-match: keeping them across a reset made returning
    // players eligible for an immediate kick on their first strike.
    _afkInfractions.clear();
    _playerLastMove.clear();
    _playerWarnedBeforeTeleport.clear();
    _playerLastPos.clear();
    _playerScores.clear();
    _playerHKBaseline.clear();

    for (auto const& playerEntry : GetPlayers())
        ResetPlayerTracking(playerEntry.second);
}

bool BattlegroundHLBG::SetupBattleground()
{
    ResetMatchState();
    return true;
}

void BattlegroundHLBG::StartingEventCloseDoors()
{
    ResetMatchState();
    UpdateWorldStatesForAll();
    SendAffixSnapshotToAll();
    SendStatusSnapshotToAll();
}

void BattlegroundHLBG::StartingEventOpenDoors()
{
    _matchStartEpoch = NowSec();
    _matchEndEpoch = _matchStartEpoch + _matchDurationSeconds;
    _endedByDepletion = false;
    _matchRewardsGranted = false;
    _matchResultRecorded = false;
    _hudSyncTimerMs = 0;
    SelectAffixForNewBattle();
    UpdateWorldStatesForAll();
    SendAffixSnapshotToAll();
    SendStatusSnapshotToAll();
}

void BattlegroundHLBG::AddPlayer(Player* player)
{
    Battleground::AddPlayer(player);

    if (!player)
        return;

    // Re-entry after a disconnect would otherwise leak the previous score.
    uint32 lowGuid = player->GetGUID().GetCounter();
    if (PlayerScores.find(lowGuid) == PlayerScores.end())
        PlayerScores.emplace(lowGuid, new BattlegroundHLBGScore(player->GetGUID()));

    ResetPlayerTracking(player);
    ApplyAffixAurasToPlayer(player);

    HLBGPlayerStats::OnPlayerEnterBG(player);
    UpdateWorldStatesForPlayer(player);
    SendAffixSnapshotToPlayer(player);
    SendStatusSnapshotToPlayer(player);
}

void BattlegroundHLBG::RemovePlayer(Player* player)
{
    if (!player)
        return;

    // Affix buffs are battleground-scoped; without this they follow the player
    // back into the open world until they expire or relog.
    RemoveAffixAurasFromPlayer(player);

    SendHudHidden(player);
    ClearPlayerTracking(player);
    SyncResourceState();
}

void BattlegroundHLBG::ResetPlayerTracking(Player* player)
{
    if (!player)
        return;

    _playerLastMove[player->GetGUID()] = NowSec();
    _playerWarnedBeforeTeleport[player->GetGUID()] = false;
    _playerLastPos[player->GetGUID()] = player->GetPosition();
    _playerHKBaseline[player->GetGUID()] = player->GetUInt32Value(PLAYER_FIELD_LIFETIME_HONORABLE_KILLS);
}

void BattlegroundHLBG::ClearPlayerTracking(Player* player)
{
    if (!player)
        return;

    uint32 lowGuid = player->GetGUID().GetCounter();
    _afkFlagged.erase(lowGuid);
    _playerLastMove.erase(player->GetGUID());
    _playerWarnedBeforeTeleport.erase(player->GetGUID());
    _playerLastPos.erase(player->GetGUID());
    _playerHKBaseline.erase(player->GetGUID());
    _playerScores.erase(player->GetGUID());
}

void BattlegroundHLBG::NotePlayerMovement(Player* player)
{
    if (!player || player->GetBattleground() != this)
        return;

    Position const& current = player->GetPosition();
    Position& last = _playerLastPos[player->GetGUID()];
    float dx = last.GetPositionX() - current.GetPositionX();
    float dy = last.GetPositionY() - current.GetPositionY();
    float dz = last.GetPositionZ() - current.GetPositionZ();
    float dist2d = std::sqrt(dx * dx + dy * dy);
    if (dist2d > 0.5f || std::fabs(dz) > 0.5f)
    {
        _playerLastMove[player->GetGUID()] = NowSec();
        _playerWarnedBeforeTeleport[player->GetGUID()] = false;
        last = current;

        if (_afkFlagged.erase(player->GetGUID().GetCounter()) > 0)
        {
            UpdateWorldStatesForPlayer(player);
            SendStatusSnapshotToPlayer(player);
        }
    }
}

bool BattlegroundHLBG::IsPlayerAfkFlagged(Player* player) const
{
    return player && _afkFlagged.count(player->GetGUID().GetCounter()) > 0;
}

void BattlegroundHLBG::SetTeamResources(TeamId teamId, uint32 amount)
{
    if (teamId != TEAM_ALLIANCE && teamId != TEAM_HORDE)
        return;

    m_TeamScores[teamId] = static_cast<int32>(std::min<uint32>(amount, INT32_MAX));
}

void BattlegroundHLBG::ModifyTeamResources(TeamId teamId, int32 delta)
{
    if (teamId != TEAM_ALLIANCE && teamId != TEAM_HORDE)
        return;

    int64 updated = static_cast<int64>(m_TeamScores[teamId]) + delta;
    if (updated < 0)
        updated = 0;
    else if (updated > INT32_MAX)
        updated = INT32_MAX;

    m_TeamScores[teamId] = static_cast<int32>(updated);
}

bool BattlegroundHLBG::TryEndOnDepletedResources()
{
    if (GetStatus() != STATUS_IN_PROGRESS)
        return false;

    TeamId depletedTeam = TEAM_NEUTRAL;
    if (GetResources(TEAM_ALLIANCE) == 0)
        depletedTeam = TEAM_ALLIANCE;
    else if (GetResources(TEAM_HORDE) == 0)
        depletedTeam = TEAM_HORDE;

    if (depletedTeam == TEAM_NEUTRAL)
        return false;

    _endedByDepletion = true;
    EndBattleground(GetOtherTeamId(depletedTeam));
    return true;

}

void BattlegroundHLBG::SyncResourceState()
{
    // The actual broadcast happens on the next HUD tick (<= 1s), so a burst of
    // kills coalesces into a single update instead of one per kill.
    _hudDirty = true;
}

void BattlegroundHLBG::AdminSetResources(TeamId teamId, uint32 amount)
{
    if (teamId != TEAM_ALLIANCE && teamId != TEAM_HORDE)
        return;

    SetTeamResources(teamId, amount);
    if (TryEndOnDepletedResources())
        return;

    SyncResourceState();
}

void BattlegroundHLBG::ResetMapActors() const
{
    HLZoneResetWorker worker;
    worker.areaId = HLBG_AREA_ID;
    VisitBattlegroundMap(this, worker);
}

void BattlegroundHLBG::AdminResetMatch(bool recordManualReset)
{
    if (recordManualReset)
    {
        HLBGService::Instance().RecordManualReset(GetMapId(),
            GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE),
            GetActiveAffixCode(0u), GetActiveAffixCode(1u), GetActiveAffixCode(2u),
            GetAffixWeatherState(GetActiveAffixCode()),
            GetAffixWeatherIntensity(GetActiveAffixCode()),
            GetCurrentMatchDurationSeconds());
    }

    ResetMapActors();
    ResetMatchState();

    if (GetStatus() == STATUS_IN_PROGRESS)
    {
        _matchStartEpoch = NowSec();
        _matchEndEpoch = _matchStartEpoch + _matchDurationSeconds;
        SelectAffixForNewBattle();
    }

    for (auto const& playerEntry : GetPlayers())
    {
        Player* player = playerEntry.second;
        if (!player)
            continue;

        if (!player->IsAlive())
        {
            player->ResurrectPlayer(1.0f);
            player->SpawnCorpseBones();
        }

        if (player->IsInWorld())
            TeleportPlayerToTeamStart(player);

        UpdateWorldStatesForPlayer(player);
        SendAffixSnapshotToPlayer(player);
        SendStatusSnapshotToPlayer(player);
    }

    UpdateWorldStatesForAll();
    SendAffixSnapshotToAll();
    SendStatusSnapshotToAll();
}

void BattlegroundHLBG::AdminFinishMatch(TeamId winnerTeamId)
{
    _endedByDepletion = false;
    EndBattleground(winnerTeamId);
}

uint32 BattlegroundHLBG::GetTimeRemainingSeconds() const
{
    if (GetStatus() == STATUS_WAIT_JOIN)
        return GetStartDelayTime() > 0 ? static_cast<uint32>(GetStartDelayTime() / IN_MILLISECONDS) : 0u;

    if (GetStatus() == STATUS_IN_PROGRESS)
    {
        uint32 now = NowSec();
        return (_matchEndEpoch > now) ? (_matchEndEpoch - now) : 0u;
    }

    return 0u;
}

uint32 BattlegroundHLBG::GetCurrentMatchDurationSeconds() const
{
    if (_matchStartEpoch == 0u)
        return 0u;

    uint32 now = NowSec();
    return now > _matchStartEpoch ? (now - _matchStartEpoch) : 0u;
}

uint32 BattlegroundHLBG::GetResources(TeamId teamId) const
{
    return GetTeamScore(teamId);
}

uint32 BattlegroundHLBG::GetPlayerContributionScore(ObjectGuid const& guid) const
{
    auto itr = _playerScores.find(guid);
    return itr != _playerScores.end() ? itr->second : 0u;
}

uint32 BattlegroundHLBG::GetPlayerHKDelta(Player* player) const
{
    if (!player)
        return 0u;

    uint32 current = player->GetUInt32Value(PLAYER_FIELD_LIFETIME_HONORABLE_KILLS);
    auto itr = _playerHKBaseline.find(player->GetGUID());
    if (itr == _playerHKBaseline.end())
    {
        _playerHKBaseline[player->GetGUID()] = current;
        return 0u;
    }

    return current > itr->second ? (current - itr->second) : 0u;
}

uint32 BattlegroundHLBG::GetNpcKillCount(TeamId teamId) const
{
    switch (teamId)
    {
        case TEAM_ALLIANCE:
            return _allianceNpcKills;
        case TEAM_HORDE:
            return _hordeNpcKills;
        default:
            return 0u;
    }
}

uint32 BattlegroundHLBG::GetAffixPlayerSpell(uint8 code) const
{
    return code < _affixPlayerSpell.size() ? _affixPlayerSpell[code] : 0u;
}

uint32 BattlegroundHLBG::GetAffixNpcSpell(uint8 code) const
{
    return code < _affixNpcSpell.size() ? _affixNpcSpell[code] : 0u;
}

uint32 BattlegroundHLBG::GetAffixWeatherState(uint8 code) const
{
    return code < _affixWeatherState.size() ? _affixWeatherState[code] : 0u;
}

float BattlegroundHLBG::GetAffixWeatherIntensity(uint8 code) const
{
    if (code == GetActiveAffixCode() && _activeAffixWeatherIntensity > 0.0f)
        return _activeAffixWeatherIntensity;

    return code < _affixWeatherIntensity.size() ? _affixWeatherIntensity[code] : 0.0f;
}

uint32 BattlegroundHLBG::GetHudEndEpoch() const
{
    if (GetStatus() == STATUS_WAIT_JOIN)
        return NowSec() + GetTimeRemainingSeconds();

    if (GetStatus() == STATUS_IN_PROGRESS)
        return _matchEndEpoch;

    return 0u;
}

TeamId BattlegroundHLBG::GetPrematureWinner()
{
    if (GetResources(TEAM_ALLIANCE) > GetResources(TEAM_HORDE))
        return TEAM_ALLIANCE;

    return GetResources(TEAM_HORDE) > GetResources(TEAM_ALLIANCE) ? TEAM_HORDE : Battleground::GetPrematureWinner();
}

void BattlegroundHLBG::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
{
    uint32 endEpoch = GetHudEndEpoch();
    uint32 hordeResources = GetResources(TEAM_HORDE);
    uint32 allianceResources = GetResources(TEAM_ALLIANCE);
    uint32 maxValue = std::max(hordeResources, allianceResources);

    packet.Worldstates.reserve(12);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, hordeResources);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, allianceResources);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxValue);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxValue);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0);
    packet.Worldstates.emplace_back(WORLD_STATE_HL_AFFIX_TEXT,
        _affixWorldstateEnabled ? GetActiveAffixCode() : 0u);
}

// The five states below never change while the battleground runs, so they are
// only sent when a player (re)gains the HUD rather than on every tick.
void BattlegroundHLBG::SendFullWorldStates(Player* player) const
{
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0);
    SendDynamicWorldStates(player);
}

void BattlegroundHLBG::SendDynamicWorldStates(Player* player) const
{
    uint32 endEpoch = GetHudEndEpoch();
    uint32 hordeResources = GetResources(TEAM_HORDE);
    uint32 allianceResources = GetResources(TEAM_ALLIANCE);
    uint32 maxValue = std::max(hordeResources, allianceResources);

    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, hordeResources);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, allianceResources);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxValue);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxValue);
    player->SendUpdateWorldState(WORLD_STATE_HL_AFFIX_TEXT,
        _affixWorldstateEnabled ? GetActiveAffixCode() : 0u);
}

void BattlegroundHLBG::UpdateWorldStatesForPlayer(Player* player) const
{
    if (!player)
        return;

    if (IsPlayerAfkFlagged(player))
    {
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 0);
        return;
    }

    SendFullWorldStates(player);
}

void BattlegroundHLBG::UpdateWorldStatesForAll() const
{
    for (auto const& playerEntry : GetPlayers())
    {
        Player* player = playerEntry.second;
        if (!player)
            continue;

        if (IsPlayerAfkFlagged(player))
        {
            player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 0);
            continue;
        }

        SendDynamicWorldStates(player);
    }
}

void BattlegroundHLBG::SendHudHidden(Player* player) const
{
    if (!player)
        return;

    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 0);
    DCAddon::HLBG::SendStatus(player, DCAddon::HLBG::STATUS_NONE, 0, 0);
    DCAddon::HLBG::SendResources(player, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    DCAddon::HLBG::SendAffixInfo(player, 0, 0, 0, HLBGService::Instance().GetSeason());
}

void BattlegroundHLBG::SendAffixSnapshotToPlayer(Player* player) const
{
    if (!player)
        return;

    DCAddon::HLBG::SendAffixInfo(player,
        GetActiveAffixCode(0u), GetActiveAffixCode(1u), GetActiveAffixCode(2u),
        HLBGService::Instance().GetSeason());
}

void BattlegroundHLBG::SendAffixSnapshotToAll() const
{
    for (auto const& playerEntry : GetPlayers())
        SendAffixSnapshotToPlayer(playerEntry.second);
}

void BattlegroundHLBG::SendStatusSnapshotToPlayer(Player* player) const
{
    if (!player)
        return;

    if (IsPlayerAfkFlagged(player))
    {
        SendHudHidden(player);
        return;
    }

    HLBGHudMetrics metrics = CollectHudMetrics(this);
    DCAddon::HLBG::SendStatus(player, GetAddonStatus(this), GetMapId(), GetTimeRemainingSeconds());
    DCAddon::HLBG::SendResources(player,
        GetResources(TEAM_ALLIANCE),
        GetResources(TEAM_HORDE),
        0, 0,
        metrics.alliancePlayers,
        metrics.hordePlayers,
        metrics.alliancePlayerKills,
        metrics.hordePlayerKills,
        metrics.allianceNpcKills,
        metrics.hordeNpcKills);
}

void BattlegroundHLBG::SendStatusSnapshotToAll() const
{
    SendStatusSnapshotToAll(CollectHudMetrics(this));
}

void BattlegroundHLBG::SendStatusSnapshotToAll(HLBGHudMetrics const& metrics) const
{
    for (auto const& playerEntry : GetPlayers())
    {
        Player* player = playerEntry.second;
        if (!player)
            continue;

        if (IsPlayerAfkFlagged(player))
        {
            SendHudHidden(player);
            continue;
        }

        DCAddon::HLBG::SendStatus(player, GetAddonStatus(this), GetMapId(), GetTimeRemainingSeconds());
        DCAddon::HLBG::SendResources(player,
            GetResources(TEAM_ALLIANCE),
            GetResources(TEAM_HORDE),
            0, 0,
            metrics.alliancePlayers,
            metrics.hordePlayers,
            metrics.alliancePlayerKills,
            metrics.hordePlayerKills,
            metrics.allianceNpcKills,
            metrics.hordeNpcKills);
    }
}

uint64 BattlegroundHLBG::ComputeHudSnapshotKey(HLBGHudMetrics const& metrics) const
{
    // Everything the periodic HUD broadcast carries except the per-second
    // countdown, which the client derives locally from the end epoch.
    uint64 key = 14695981039346656037ULL;
    auto mix = [&key](uint64 value)
    {
        key ^= value;
        key *= 1099511628211ULL;
    };

    mix(static_cast<uint64>(GetAddonStatus(this)));
    mix(GetHudEndEpoch());
    mix(GetResources(TEAM_ALLIANCE));
    mix(GetResources(TEAM_HORDE));
    mix(metrics.alliancePlayers);
    mix(metrics.hordePlayers);
    mix(metrics.alliancePlayerKills);
    mix(metrics.hordePlayerKills);
    mix(metrics.allianceNpcKills);
    mix(metrics.hordeNpcKills);
    mix(GetActiveAffixCode());
    mix(_afkFlagged.size());
    return key;
}

bool BattlegroundHLBG::IsEligibleForRewards(Player* player) const
{
    return player && !player->HasAura(BG_DESERTER_SPELL);
}

void BattlegroundHLBG::RewardRandomKillHonor(Player* player)
{
    if (!player || _killHonorValues.empty())
        return;

    uint32 honor = _killHonorValues[urand(0u, static_cast<uint32>(_killHonorValues.size() - 1))];
    if (honor > 0)
    {
        player->RewardHonor(nullptr, 0, static_cast<float>(honor));
        UpdatePlayerScore(player, SCORE_BONUS_HONOR, honor, false);
    }
}

void BattlegroundHLBG::AddPlayerContributionScore(ObjectGuid const& guid, uint32 points)
{
    if (!guid || points == 0)
        return;

    _playerScores[guid] += points;

    auto const& itr = PlayerScores.find(guid.GetCounter());
    if (itr != PlayerScores.end())
        static_cast<BattlegroundHLBGScore*>(itr->second)->ResourcesCaptured += points;
}

void BattlegroundHLBG::RewardPlayerKill(Player* killer, Player* victim, uint32 scorePoints)
{
    if (!killer || !victim)
        return;

    auto rewardMember = [this, scorePoints](Player* player)
    {
        if (!player || !IsEligibleForRewards(player) || IsPlayerAfkFlagged(player))
            return;

        RewardRandomKillHonor(player);
        if (_rewardKillItemId && _rewardKillItemCount)
            player->AddItem(_rewardKillItemId, _rewardKillItemCount);

        AddPlayerContributionScore(player->GetGUID(), scorePoints);
        HLBGPlayerStats::OnResourceCapture(player, scorePoints);
    };

    if (Group* group = killer->GetGroup())
    {
        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member || member->GetBattleground() != this)
                continue;
            if (!member->IsAtGroupRewardDistance(victim) && member != killer)
                continue;

            rewardMember(member);
        }
    }
    else
    {
        rewardMember(killer);
    }
}

void BattlegroundHLBG::RewardNpcKill(Player* killer, Creature* unit, uint32 scorePoints, TeamId victimTeam, bool isBossKill)
{
    if (!killer || !unit)
        return;

    if (victimTeam == TEAM_HORDE)
        ++_allianceNpcKills;
    else if (victimTeam == TEAM_ALLIANCE)
        ++_hordeNpcKills;

    // Skirmish is "players only": zeroing the resource drain alone still left
    // guards worth farming for honor and tokens, which is the behaviour the
    // affix exists to remove. Kill counters keep ticking - the kill happened -
    // but it pays nothing.
    if (IsAffixActive(HLBG_AFFIX_SKIRMISH))
        return;

    if (IsEligibleForRewards(killer) && !IsPlayerAfkFlagged(killer))
    {
        RewardRandomKillHonor(killer);
        AddPlayerContributionScore(killer->GetGUID(), scorePoints);
        HLBGPlayerStats::OnResourceCapture(killer, scorePoints);

        auto const& scoreItr = PlayerScores.find(killer->GetGUID().GetCounter());
        if (scoreItr != PlayerScores.end())
        {
            auto* score = static_cast<BattlegroundHLBGScore*>(scoreItr->second);
            ++score->NpcKills;
            if (isBossKill)
                ++score->BossKills;
        }

        auto const& rewardEntries = killer->GetBgTeamId() == TEAM_ALLIANCE ? _npcRewardEntriesHorde : _npcRewardEntriesAlliance;
        auto const& rewardCounts = killer->GetBgTeamId() == TEAM_ALLIANCE ? _npcRewardCountsHorde : _npcRewardCountsAlliance;
        if (_rewardNpcTokenItemId && rewardEntries.count(unit->GetEntry()) > 0)
        {
            uint32 count = _rewardNpcTokenCount;
            auto itr = rewardCounts.find(unit->GetEntry());
            if (itr != rewardCounts.end())
                count = itr->second;

            if (count)
                killer->AddItem(_rewardNpcTokenItemId, count);
        }
    }
}

bool BattlegroundHLBG::ClassifyNpc(uint32 entry, TeamId& victimTeam, uint32& scorePoints, bool& isBoss) const
{
    if (_npcBossEntriesAlliance.count(entry))
    {
        victimTeam = TEAM_ALLIANCE;
        scorePoints = _resourcesLossNpcBoss;
        isBoss = true;
        return true;
    }

    if (_npcBossEntriesHorde.count(entry))
    {
        victimTeam = TEAM_HORDE;
        scorePoints = _resourcesLossNpcBoss;
        isBoss = true;
        return true;
    }

    if (_npcNormalEntriesAlliance.count(entry))
    {
        victimTeam = TEAM_ALLIANCE;
        scorePoints = _resourcesLossNpcNormal;
        isBoss = false;
        return true;
    }

    if (_npcNormalEntriesHorde.count(entry))
    {
        victimTeam = TEAM_HORDE;
        scorePoints = _resourcesLossNpcNormal;
        isBoss = false;
        return true;
    }

    return false;
}

void BattlegroundHLBG::HandleKillPlayer(Player* victim, Player* killer)
{
    if (GetStatus() != STATUS_IN_PROGRESS || !victim)
        return;

    Battleground::HandleKillPlayer(victim, killer);

    if (!killer || killer == victim)
        return;

    HLBGPlayerStats::OnPlayerKill(killer, victim);

    TeamId victimTeam = victim->GetBgTeamId();
    if (victimTeam != TEAM_ALLIANCE && victimTeam != TEAM_HORDE)
        victimTeam = victim->GetTeamId();

    uint32 killLoss = GetEffectivePlayerKillLoss();
    ModifyTeamResources(victimTeam, -static_cast<int32>(killLoss));
    RewardPlayerKill(killer, victim, killLoss);
    SyncResourceState();
}

void BattlegroundHLBG::HandleKillUnit(Creature* unit, Player* killer)
{
    if (GetStatus() != STATUS_IN_PROGRESS || !unit || !killer)
        return;

    TeamId victimTeam = TEAM_NEUTRAL;
    uint32 scorePoints = 0;
    bool isBossKill = false;
    if (!ClassifyNpc(unit->GetEntry(), victimTeam, scorePoints, isBossKill))
        return;

    scorePoints = GetEffectiveNpcLoss(scorePoints, isBossKill);
    ModifyTeamResources(victimTeam, -static_cast<int32>(scorePoints));
    RewardNpcKill(killer, unit, scorePoints, victimTeam, isBossKill);
    SyncResourceState();
}

void BattlegroundHLBG::TeleportPlayerToTeamStart(Player* player) const
{
    if (!player)
        return;

    if (Position const* startPosition = GetTeamStartPosition(player->GetBgTeamId()))
        player->TeleportTo(GetMapId(), startPosition->GetPositionX(), startPosition->GetPositionY(), startPosition->GetPositionZ(), startPosition->GetOrientation());
}

// Flags the player as AFK and applies the escalating penalty: the first
// infraction teleports them back to their base, any further one removes them
// from the battleground.
void BattlegroundHLBG::FlagPlayerAfk(Player* player)
{
    if (!player)
        return;

    uint32 lowGuid = player->GetGUID().GetCounter();
    _afkFlagged.insert(lowGuid);

    uint8& infractions = _afkInfractions[lowGuid];
    ++infractions;

    if (player->GetSession())
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            infractions == 1
                ? "|cffff0000[HLBG]|r You were flagged as inactive and returned to your base."
                : "|cffff0000[HLBG]|r You were flagged as inactive again and removed from the battleground.");
    }

    if (infractions > 1)
    {
        // RemovePlayer clears the tracking state and hides the HUD.
        player->LeaveBattleground();
        return;
    }

    TeleportPlayerToTeamStart(player);
    UpdateWorldStatesForPlayer(player);
    SendStatusSnapshotToPlayer(player);
}

void BattlegroundHLBG::TickAfk(uint32 diff)
{
    if (_afkCheckTimerMs > diff)
    {
        _afkCheckTimerMs -= diff;
        return;
    }

    _afkCheckTimerMs = HLBGAfkTickIntervalMs;
    uint32 now = NowSec();

    // FlagPlayerAfk can remove the player from the battleground, which mutates
    // GetPlayers(); snapshot the guids first.
    std::vector<ObjectGuid> guids;
    guids.reserve(GetPlayers().size());
    for (auto const& playerEntry : GetPlayers())
        guids.push_back(playerEntry.first);

    for (ObjectGuid const& guid : guids)
    {
        auto playerItr = GetPlayers().find(guid);
        if (playerItr == GetPlayers().end())
            continue;

        Player* player = playerItr->second;
        if (!player || !player->IsInWorld() || player->IsGameMaster())
            continue;

        uint32 lowGuid = guid.GetCounter();
        bool wasAfk = _afkFlagged.count(lowGuid) > 0;

        auto lastMoveItr = _playerLastMove.find(guid);
        if (lastMoveItr == _playerLastMove.end())
        {
            ResetPlayerTracking(player);
            lastMoveItr = _playerLastMove.find(guid);
            if (lastMoveItr == _playerLastMove.end())
                continue;
        }

        // Guard against a clock that moved backwards, which would otherwise
        // underflow into an instant AFK flag.
        uint32 idleSeconds = now > lastMoveItr->second ? (now - lastMoveItr->second) : 0u;
        bool afkFromChat = player->isAFK();

        if (wasAfk)
        {
            // Only chat-AFK can clear here; movement clears via NotePlayerMovement.
            if (!afkFromChat && idleSeconds < _afkTeleportSeconds)
            {
                _afkFlagged.erase(lowGuid);
                UpdateWorldStatesForPlayer(player);
                SendStatusSnapshotToPlayer(player);
            }

            continue;
        }

        // Idle and chat-AFK are the same offence: counting both in one tick
        // used to burn two infractions and kick on the first strike.
        if (idleSeconds >= _afkTeleportSeconds || afkFromChat)
        {
            FlagPlayerAfk(player);
            continue;
        }

        // Single warning as the idle timer crosses the warn threshold.
        if (idleSeconds >= _afkWarnSeconds)
        {
            bool& warned = _playerWarnedBeforeTeleport[guid];
            if (!warned)
            {
                warned = true;
                if (player->GetSession())
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cffffd700[HLBG]|r You look inactive. Move within {} seconds or you will be returned to your base.",
                        _afkTeleportSeconds > idleSeconds ? (_afkTeleportSeconds - idleSeconds) : 0u);
                }
            }
        }
    }
}

void BattlegroundHLBG::RewardMatchOutcome(TeamId winnerTeamId)
{
    if (_matchRewardsGranted)
        return;

    _matchRewardsGranted = true;

    uint32 winnerHonor = _endedByDepletion ? _rewardMatchHonorDepletion : _rewardMatchHonorTiebreaker;
    uint32 loserHonor = _rewardMatchHonorLoser;

    for (auto const& playerEntry : GetPlayers())
    {
        Player* player = playerEntry.second;
        if (!player)
            continue;

        bool victory = winnerTeamId != TEAM_NEUTRAL && player->GetBgTeamId() == winnerTeamId;
        uint32 honorReward = 0;
        uint32 tokenReward = 0;

        if (winnerTeamId != TEAM_NEUTRAL && IsEligibleForRewards(player) && !IsPlayerAfkFlagged(player))
        {
            honorReward = victory ? winnerHonor : loserHonor;
            if (honorReward > 0)
            {
                player->RewardHonor(nullptr, 0, static_cast<float>(honorReward));
                UpdatePlayerScore(player, SCORE_BONUS_HONOR, honorReward, false);
            }

            player->KilledMonsterCredit(HLBGQuestCreditParticipation);
            if (victory)
            {
                player->KilledMonsterCredit(HLBGQuestCreditWin);
                HLBGPlayerStats::OnPlayerWin(player);
                if (_rewardNpcTokenItemId && _rewardNpcTokenCount)
                {
                    tokenReward = _rewardNpcTokenCount;
                    player->AddItem(_rewardNpcTokenItemId, tokenReward);
                }
            }
        }

        DCAddon::HLBG::SendMatchEnd(player, victory, GetPlayerContributionScore(player->GetGUID()), honorReward, 0, tokenReward);
        DCAddon::HLBG::SendStatus(player, DCAddon::HLBG::STATUS_ENDED, GetMapId(), 0);
    }

    if (!_matchResultRecorded)
    {
        _matchResultRecorded = true;

        // One row per participant, written in the same transaction as the match
        // row. Without this dc_hlbg_match_participants stays empty and every
        // seasonal leaderboard in the addon returns nothing.
        std::vector<HLBGMatchParticipant> participants;
        participants.reserve(GetPlayers().size());
        for (auto const& playerEntry : GetPlayers())
        {
            Player* player = playerEntry.second;
            if (!player)
                continue;

            HLBGMatchParticipant participant;
            participant.guid = player->GetGUID().GetCounter();
            participant.playerName = player->GetName();
            participant.accountId = player->GetSession() ? player->GetSession()->GetAccountId() : 0u;
            participant.team = static_cast<uint8>(player->GetBgTeamId());
            participant.resourcesCaptured = GetPlayerContributionScore(player->GetGUID());

            auto const& scoreItr = PlayerScores.find(participant.guid);
            if (scoreItr != PlayerScores.end() && scoreItr->second)
            {
                auto const* score = static_cast<BattlegroundHLBGScore const*>(scoreItr->second);
                participant.kills = score->GetKillingBlowCount();
                participant.deaths = score->GetDeathCount();
                participant.healingDone = score->GetHealingDoneTotal();
                participant.damageDone = score->GetDamageDoneTotal();
            }

            participants.push_back(std::move(participant));
        }

        HLBGService::Instance().RecordWinner(winnerTeamId, GetMapId(),
            GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE),
            _endedByDepletion ? "depletion" : "tiebreaker",
            GetActiveAffixCode(0u), GetActiveAffixCode(1u), GetActiveAffixCode(2u),
            GetAffixWeatherState(GetActiveAffixCode()), GetAffixWeatherIntensity(GetActiveAffixCode()),
            GetCurrentMatchDurationSeconds(), participants);
    }
}

void BattlegroundHLBG::EndBattleground(TeamId winnerTeamId)
{
    RewardMatchOutcome(winnerTeamId);
    ClearAffixEffects();
    ClearAffixWeather();
    ClearAffixLight();
    _activeAffixes.fill(HLBG_AFFIX_NONE);
    _activeAffixWeatherIntensity = 0.0f;
    _affixNextChangeEpoch = 0u;
    _affixRotationTimerMs = 0u;
    UpdateWorldStatesForAll();
    SendAffixSnapshotToAll();
    SendStatusSnapshotToAll();
    Battleground::EndBattleground(winnerTeamId);
}

void BattlegroundHLBG::RemoveAffixAurasFromPlayer(Player* player) const
{
    if (!player)
        return;

    // Every configured affix spell, not just the active ones: a player can
    // still carry a buff from a previous rotation.
    for (uint32 spellId : _affixPlayerSpell)
    {
        if (spellId)
            player->RemoveAurasDueToSpell(spellId);
    }
}

void BattlegroundHLBG::ApplyAffixAurasToPlayer(Player* player) const
{
    if (!player || !player->IsInWorld())
        return;

    for (uint32 slot = 0; slot < HLBGAffixSlotCount; ++slot)
    {
        if (uint32 spellId = GetAffixPlayerSpell(GetActiveAffixCode(slot)))
            if (!player->HasAura(spellId))
                player->CastSpell(player, spellId, true);
    }
}

void BattlegroundHLBG::ClearAffixEffects()
{
    for (auto const& playerEntry : GetPlayers())
        RemoveAffixAurasFromPlayer(playerEntry.second);

    std::vector<uint32> npcSpells;
    npcSpells.reserve(_affixNpcSpell.size());
    for (uint32 spellId : _affixNpcSpell)
        if (spellId)
            npcSpells.push_back(spellId);

    ApplyNpcAuras(this, std::move(npcSpells), true);
}

void BattlegroundHLBG::ApplyAffixEffects()
{
    for (auto const& playerEntry : GetPlayers())
        ApplyAffixAurasToPlayer(playerEntry.second);

    std::vector<uint32> npcSpells;
    npcSpells.reserve(HLBGAffixSlotCount);
    for (uint32 slot = 0; slot < HLBGAffixSlotCount; ++slot)
        if (uint32 npcSpellId = GetAffixNpcSpell(GetActiveAffixCode(slot)))
            npcSpells.push_back(npcSpellId);

    ApplyNpcAuras(this, std::move(npcSpells), false);

    if (_affixWeatherEnabled)
        ApplyAffixWeather();

    ApplyAffixLight();

    if (_affixAnnounce && GetActiveAffixCode() != HLBG_AFFIX_NONE)
    {
        std::ostringstream message;
        message << "HLBG affixes active: " << BuildAffixNameList(this);
        if (_affixWeatherEnabled)
        {
            message << " (" << GetWeatherName(GetAffixWeatherState(GetActiveAffixCode()))
                << ' ' << static_cast<uint32>(
                    std::lround(GetAffixWeatherIntensity(GetActiveAffixCode()) * 100.0f))
                << "%)";
        }

        for (auto const& playerEntry : GetPlayers())
        {
            Player* player = playerEntry.second;
            if (player && player->GetSession())
                ChatHandler(player->GetSession()).SendSysMessage(message.str().c_str());
        }
    }
}

void BattlegroundHLBG::ApplyAffixWeather() const
{
    Map* map = sMapMgr->FindMap(GetMapId(), GetInstanceID());
    if (!map)
        return;

    // Map::SetZoneWeather, not GetOrGenerateZoneDefaultWeather. The old call
    // *created* a natural weather generator for the zone on this instance, and
    // Map::UpdateWeather then re-rolled it every CONFIG_INTERVAL_CHANGEWEATHER
    // (10 min by default), wiping the affix weather for the rest of the match.
    // SetZoneWeather instead stores a ZoneDynamicInfo override, which
    // Map::UpdateWeather never touches (it only ticks zones that have a
    // DefaultWeather object) and which SendZoneDynamicInfo replays to anyone
    // zoning in mid-match.
    //
    // It also takes a WeatherState directly, which is the only way to reach
    // WEATHER_STATE_FOG - Weather::GetWeatherState can never produce it.
    map->SetZoneWeather(HLBG_ZONE_ID,
        static_cast<WeatherState>(GetAffixWeatherState(GetActiveAffixCode())),
        GetAffixWeatherIntensity(GetActiveAffixCode()));
}

void BattlegroundHLBG::ClearAffixWeather() const
{
    if (Map* map = sMapMgr->FindMap(GetMapId(), GetInstanceID()))
        map->SetZoneWeather(HLBG_ZONE_ID, WEATHER_STATE_FINE, 0.0f);
}

// Nightfall drives the zone light override. Light id 0 is the documented
// "restore the map default" value (see LIGHT_GET_DEFAULT_FOR_MAP in the stock
// Malygos script).
void BattlegroundHLBG::ApplyAffixLight() const
{
    Map* map = sMapMgr->FindMap(GetMapId(), GetInstanceID());
    if (!map)
        return;

    // Set *or clear*, never set-or-skip. ClearAffixEffects only removes auras,
    // so an early return here left a previous Nightfall override in place: once
    // the affix rotated away the zone stayed dark for the rest of the match.
    // Light id 0 restores the map default.
    uint32 lightId = IsAffixActive(HLBG_AFFIX_NIGHTFALL) ? _affixNightfallLightId : 0u;
    map->SetZoneOverrideLight(HLBG_ZONE_ID, lightId, Seconds(_affixNightfallFadeSec));
}

void BattlegroundHLBG::ClearAffixLight() const
{
    if (Map* map = sMapMgr->FindMap(GetMapId(), GetInstanceID()))
        map->SetZoneOverrideLight(HLBG_ZONE_ID, 0u, Seconds(_affixNightfallFadeSec));
}

bool BattlegroundHLBG::IsAffixActive(uint8 code) const
{
    if (!code)
        return false;

    for (uint8 activeAffix : _activeAffixes)
        if (activeAffix == code)
            return true;

    return false;
}

uint32 BattlegroundHLBG::GetEffectivePlayerKillLoss() const
{
    uint32 loss = _resourcesLossPlayerKill;
    if (IsAffixActive(HLBG_AFFIX_BLOODLUST))
        loss *= _affixBloodlustKillMultiplier;

    return loss;
}

uint32 BattlegroundHLBG::GetEffectiveNpcLoss(uint32 baseLoss, bool isBoss) const
{
    // Skirmish is evaluated last on purpose: if it ever rolls alongside
    // Warlords (AreAffixesCompatible forbids it, but config can force both),
    // "NPCs are worth nothing" is the safer of the two contradictory rules.
    if (isBoss && IsAffixActive(HLBG_AFFIX_WARLORDS))
        baseLoss *= _affixWarlordsBossMultiplier;

    if (IsAffixActive(HLBG_AFFIX_SKIRMISH))
        return 0u;

    return baseLoss;
}

void BattlegroundHLBG::SelectAffixForNewBattle()
{
    ClearAffixEffects();

    uint8 previousPrimaryAffix = GetActiveAffixCode();
    _activeAffixes.fill(HLBG_AFFIX_NONE);

    if (!_affixEnabled)
    {
        _activeAffixWeatherIntensity = 0.0f;
        _affixRotationTimerMs = 0u;
        _affixNextChangeEpoch = 0u;
        return;
    }

    std::vector<uint8> availableAffixes;
    for (uint8 affixCode = HLBG_AFFIX_SUNLIGHT; affixCode <= HLBG_AFFIX_LAST; ++affixCode)
        availableAffixes.push_back(affixCode);

    auto takeRandomAffix = [&availableAffixes]() -> uint8
    {
        uint32 index = urand(0u, static_cast<uint32>(availableAffixes.size() - 1));
        uint8 selectedAffix = availableAffixes[index];
        availableAffixes.erase(availableAffixes.begin() + index);
        return selectedAffix;
    };

    std::size_t desiredCount = std::min<std::size_t>(_affixConcurrentCount, availableAffixes.size());
    std::size_t selectedCount = 0u;
    if (_affixRandomOnStart)
    {
        // Draw from the pool with the previous primary excluded, so the guard
        // cannot hand back the very affix it is meant to avoid.
        uint8 nextPrimaryAffix;
        auto previousItr = std::find(availableAffixes.begin(), availableAffixes.end(), previousPrimaryAffix);
        if (previousItr != availableAffixes.end() && availableAffixes.size() > 1u)
        {
            availableAffixes.erase(previousItr);
            nextPrimaryAffix = takeRandomAffix();
            availableAffixes.push_back(previousPrimaryAffix);
        }
        else
        {
            nextPrimaryAffix = takeRandomAffix();
        }

        _activeAffixes[selectedCount++] = nextPrimaryAffix;
    }
    else
    {
        uint8 currentAffix = previousPrimaryAffix;
        if (currentAffix < HLBG_AFFIX_SUNLIGHT || currentAffix > HLBG_AFFIX_LAST)
            currentAffix = HLBG_AFFIX_LAST;

        uint8 nextPrimaryAffix = currentAffix + 1;
        if (nextPrimaryAffix > HLBG_AFFIX_LAST)
            nextPrimaryAffix = HLBG_AFFIX_SUNLIGHT;

        availableAffixes.erase(std::remove(availableAffixes.begin(), availableAffixes.end(), nextPrimaryAffix), availableAffixes.end());
        _activeAffixes[selectedCount++] = nextPrimaryAffix;
    }

    // Extra slots skip anything that would cancel or duplicate an affix already
    // chosen - e.g. Gentle Breeze (+speed) next to Heavy Rain (-speed).
    while (selectedCount < desiredCount && !availableAffixes.empty())
    {
        bool picked = false;
        for (std::size_t attempt = 0; attempt < availableAffixes.size(); ++attempt)
        {
            uint8 candidate = availableAffixes[attempt];
            bool compatible = true;
            for (std::size_t slot = 0; slot < selectedCount; ++slot)
            {
                if (!AreAffixesCompatible(_activeAffixes[slot], candidate))
                {
                    compatible = false;
                    break;
                }
            }

            if (!compatible)
                continue;

            availableAffixes.erase(availableAffixes.begin() + attempt);
            _activeAffixes[selectedCount++] = candidate;
            picked = true;
            break;
        }

        // Nothing left that fits alongside the current selection.
        if (!picked)
            break;
    }

    _activeAffixWeatherIntensity = 0.0f;
    if (GetActiveAffixCode() != HLBG_AFFIX_NONE)
    {
        float baseIntensity = _affixWeatherIntensity[GetActiveAffixCode()];
        if (baseIntensity > 0.0f)
        {
            if (_affixWeatherIntensityVariance > 0.0f)
            {
                int32 minRollPct = std::max<int32>(0, static_cast<int32>(std::lround((1.0f - _affixWeatherIntensityVariance) * 100.0f)));
                int32 maxRollPct = std::max<int32>(minRollPct, static_cast<int32>(std::lround((1.0f + _affixWeatherIntensityVariance) * 100.0f)));
                uint32 rollPct = urand(static_cast<uint32>(minRollPct), static_cast<uint32>(maxRollPct));
                _activeAffixWeatherIntensity = std::clamp(baseIntensity * (static_cast<float>(rollPct) / 100.0f), 0.0f, 1.0f);
            }
            else
            {
                _activeAffixWeatherIntensity = baseIntensity;
            }
        }
    }

    if (_affixPeriodSec > 0u)
    {
        _affixRotationTimerMs = _affixPeriodSec * IN_MILLISECONDS;
        _affixNextChangeEpoch = NowSec() + _affixPeriodSec;
    }
    else
    {
        _affixRotationTimerMs = 0u;
        _affixNextChangeEpoch = 0u;
    }

    ApplyAffixEffects();
}

void BattlegroundHLBG::PostUpdateImpl(uint32 diff)
{
    if (GetStatus() == STATUS_IN_PROGRESS)
    {
        if (TryEndOnDepletedResources())
            return;

        if (NowSec() >= _matchEndEpoch)
        {
            EndBattleground(GetPrematureWinner());
            return;
        }

        if (_affixEnabled && _affixPeriodSec > 0u)
        {
            if (_affixRotationTimerMs <= diff)
            {
                SelectAffixForNewBattle();
                UpdateWorldStatesForAll();
                SendAffixSnapshotToAll();
            }
            else
            {
                _affixRotationTimerMs -= diff;
                _affixNextChangeEpoch = NowSec() + (_affixRotationTimerMs / IN_MILLISECONDS);
            }
        }

        TickAfk(diff);
    }

    _hudMsSinceBroadcast += diff;
    if (_hudSyncTimerMs <= diff)
    {
        _hudSyncTimerMs = HLBGHudSyncIntervalMs;

        // The HUD payload only changes on resource/kill/affix/AFK events and
        // the client ticks the countdown locally, so broadcast only when the
        // snapshot differs (plus a slow heartbeat to correct client drift).
        // One CollectHudMetrics pass feeds both the key and the broadcast.
        HLBGHudMetrics metrics = CollectHudMetrics(this);
        uint64 snapshotKey = ComputeHudSnapshotKey(metrics);
        if (_hudDirty || snapshotKey != _lastHudSnapshotKey
            || _hudMsSinceBroadcast >= HLBGHudHeartbeatIntervalMs)
        {
            _lastHudSnapshotKey = snapshotKey;
            _hudMsSinceBroadcast = 0u;
            _hudDirty = false;
            UpdateWorldStatesForAll();
            SendStatusSnapshotToAll(metrics);
        }
    }
    else
        _hudSyncTimerMs -= diff;
}