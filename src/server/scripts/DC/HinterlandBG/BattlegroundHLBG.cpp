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
#include "WorldStateDefines.h"

#include "../AddonExtension/dc_addon_hlbg.h"
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
    constexpr uint32 HLBGDeserterSpell = 26013;
    constexpr uint32 HLBGHudSyncIntervalMs = 1000;
    constexpr uint32 HLBGAfkTickIntervalMs = 2000;
    constexpr uint32 WORLD_STATE_HL_AFFIX_TEXT = 0xDD1010;

    struct BattlegroundHLBGScore final : BattlegroundScore
    {
        explicit BattlegroundHLBGScore(ObjectGuid playerGuid) : BattlegroundScore(playerGuid) { }

        void BuildObjectivesBlock(WorldPacket& data) final
        {
            data << uint32(0);
        }
    };

    struct HLBGHudMetrics
    {
        uint32 alliancePlayers = 0;
        uint32 hordePlayers = 0;
        uint32 alliancePlayerKills = 0;
        uint32 hordePlayerKills = 0;
        uint32 allianceNpcKills = 0;
        uint32 hordeNpcKills = 0;
    };

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

    std::vector<uint32> ParseCsvU32(std::string const& input)
    {
        std::vector<uint32> values;
        std::size_t start = 0;
        while (start < input.size())
        {
            std::size_t comma = input.find(',', start);
            std::string token = input.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            try
            {
                if (!token.empty())
                    values.push_back(static_cast<uint32>(std::stoul(token)));
            }
            catch (...)
            {
            }

            if (comma == std::string::npos)
                break;

            start = comma + 1;
        }

        return values;
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

    struct HLBGNpcAuraWorker
    {
        uint32 areaId = HLBG_AREA_ID;
        uint32 spellId = 0u;
        bool remove = false;

        void Visit(std::unordered_map<ObjectGuid, Creature*>& creatureMap)
        {
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

                if (remove)
                    creature->RemoveAurasDueToSpell(spellId);
                else if (!creature->HasAura(spellId))
                    creature->CastSpell(creature, spellId, true);
            }
        }

        template <class T>
        void Visit(std::unordered_map<ObjectGuid, T*>&)
        {
        }
    };
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
    for (uint8 affixCode = HLBG_AFFIX_NONE; affixCode <= HLBG_AFFIX_FOG; ++affixCode)
    {
        _affixPlayerSpell[affixCode] = GetDefaultAffixPlayerSpell(affixCode);
        _affixNpcSpell[affixCode] = GetDefaultAffixNpcSpell(affixCode);
        _affixWeatherType[affixCode] = GetDefaultAffixWeatherType(affixCode);
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

    _affixPlayerSpell[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.Sunlight", _affixPlayerSpell[HLBG_AFFIX_SUNLIGHT]);
    _affixPlayerSpell[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.ClearSkies", _affixPlayerSpell[HLBG_AFFIX_CLEAR_SKIES]);
    _affixPlayerSpell[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.PlayerSpell.GentleBreeze", _affixPlayerSpell[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixNpcSpell[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Storm", _affixNpcSpell[HLBG_AFFIX_STORM]);
    _affixNpcSpell[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.HeavyRain", _affixNpcSpell[HLBG_AFFIX_HEAVY_RAIN]);
    _affixNpcSpell[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.NpcSpell.Fog", _affixNpcSpell[HLBG_AFFIX_FOG]);

    _affixWeatherType[HLBG_AFFIX_SUNLIGHT] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.Sunlight", _affixWeatherType[HLBG_AFFIX_SUNLIGHT]);
    _affixWeatherType[HLBG_AFFIX_CLEAR_SKIES] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.ClearSkies", _affixWeatherType[HLBG_AFFIX_CLEAR_SKIES]);
    _affixWeatherType[HLBG_AFFIX_GENTLE_BREEZE] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.GentleBreeze", _affixWeatherType[HLBG_AFFIX_GENTLE_BREEZE]);
    _affixWeatherType[HLBG_AFFIX_STORM] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.Storm", _affixWeatherType[HLBG_AFFIX_STORM]);
    _affixWeatherType[HLBG_AFFIX_HEAVY_RAIN] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.HeavyRain", _affixWeatherType[HLBG_AFFIX_HEAVY_RAIN]);
    _affixWeatherType[HLBG_AFFIX_FOG] = sConfigMgr->GetOption<uint32>(
        "HinterlandBG.Affix.WeatherType.Fog", _affixWeatherType[HLBG_AFFIX_FOG]);

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
        _npcRewardEntriesAlliance = ParseCsvU32(allianceRewardEntries);
    if (!hordeRewardEntries.empty())
        _npcRewardEntriesHorde = ParseCsvU32(hordeRewardEntries);

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
    _activeAffix = HLBG_AFFIX_NONE;
    _afkFlagged.clear();
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

    PlayerScores.emplace(player->GetGUID().GetCounter(), new BattlegroundHLBGScore(player->GetGUID()));
    ResetPlayerTracking(player);
    HLBGPlayerStats::OnPlayerEnterBG(player);
    UpdateWorldStatesForPlayer(player);
    SendAffixSnapshotToPlayer(player);
    SendStatusSnapshotToPlayer(player);
}

void BattlegroundHLBG::RemovePlayer(Player* player)
{
    if (!player)
        return;

    SendHudHidden(player);
    ClearPlayerTracking(player);
    UpdateWorldStatesForAll();
    SendStatusSnapshotToAll();
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

void BattlegroundHLBG::SyncResourceState() const
{
    UpdateWorldStatesForAll();
    SendStatusSnapshotToAll();
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
            GetActiveAffixCode(), GetAffixWeatherType(GetActiveAffixCode()),
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

uint32 BattlegroundHLBG::GetAffixWeatherType(uint8 code) const
{
    return code < _affixWeatherType.size() ? _affixWeatherType[code] : 0u;
}

float BattlegroundHLBG::GetAffixWeatherIntensity(uint8 code) const
{
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
        _affixWorldstateEnabled ? _activeAffix : 0u);
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

    uint32 endEpoch = GetHudEndEpoch();
    uint32 hordeResources = GetResources(TEAM_HORDE);
    uint32 allianceResources = GetResources(TEAM_ALLIANCE);
    uint32 maxValue = std::max(hordeResources, allianceResources);

    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, hordeResources);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, allianceResources);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxValue);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxValue);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE);
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0);
    player->SendUpdateWorldState(WORLD_STATE_HL_AFFIX_TEXT,
        _affixWorldstateEnabled ? _activeAffix : 0u);
}

void BattlegroundHLBG::UpdateWorldStatesForAll() const
{
    for (auto const& playerEntry : GetPlayers())
        UpdateWorldStatesForPlayer(playerEntry.second);
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

    DCAddon::HLBG::SendAffixInfo(player, _activeAffix, 0, 0,
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
    HLBGHudMetrics metrics = CollectHudMetrics(this);

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

bool BattlegroundHLBG::IsEligibleForRewards(Player* player) const
{
    return player && !player->HasAura(HLBGDeserterSpell);
}

void BattlegroundHLBG::RewardRandomKillHonor(Player* player) const
{
    if (!player || _killHonorValues.empty())
        return;

    uint32 honor = _killHonorValues[urand(0u, static_cast<uint32>(_killHonorValues.size() - 1))];
    if (honor > 0)
        player->RewardHonor(nullptr, 0, static_cast<float>(honor));
}

void BattlegroundHLBG::AddPlayerContributionScore(ObjectGuid const& guid, uint32 points)
{
    if (!guid || points == 0)
        return;

    _playerScores[guid] += points;
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

void BattlegroundHLBG::RewardNpcKill(Player* killer, Creature* unit, uint32 scorePoints, TeamId victimTeam)
{
    if (!killer || !unit)
        return;

    if (victimTeam == TEAM_HORDE)
        ++_allianceNpcKills;
    else if (victimTeam == TEAM_ALLIANCE)
        ++_hordeNpcKills;

    if (IsEligibleForRewards(killer) && !IsPlayerAfkFlagged(killer))
    {
        RewardRandomKillHonor(killer);
        AddPlayerContributionScore(killer->GetGUID(), scorePoints);
        HLBGPlayerStats::OnResourceCapture(killer, scorePoints);

        auto const& rewardEntries = killer->GetBgTeamId() == TEAM_ALLIANCE ? _npcRewardEntriesHorde : _npcRewardEntriesAlliance;
        auto const& rewardCounts = killer->GetBgTeamId() == TEAM_ALLIANCE ? _npcRewardCountsHorde : _npcRewardCountsAlliance;
        if (_rewardNpcTokenItemId && std::find(rewardEntries.begin(), rewardEntries.end(), unit->GetEntry()) != rewardEntries.end())
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

bool BattlegroundHLBG::ClassifyNpc(uint32 entry, TeamId& victimTeam, uint32& scorePoints) const
{
    if (_npcBossEntriesAlliance.count(entry))
    {
        victimTeam = TEAM_ALLIANCE;
        scorePoints = _resourcesLossNpcBoss;
        return true;
    }

    if (_npcBossEntriesHorde.count(entry))
    {
        victimTeam = TEAM_HORDE;
        scorePoints = _resourcesLossNpcBoss;
        return true;
    }

    if (_npcNormalEntriesAlliance.count(entry))
    {
        victimTeam = TEAM_ALLIANCE;
        scorePoints = _resourcesLossNpcNormal;
        return true;
    }

    if (_npcNormalEntriesHorde.count(entry))
    {
        victimTeam = TEAM_HORDE;
        scorePoints = _resourcesLossNpcNormal;
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

    ModifyTeamResources(victimTeam, -static_cast<int32>(_resourcesLossPlayerKill));
    RewardPlayerKill(killer, victim, _resourcesLossPlayerKill);
    SyncResourceState();
}

void BattlegroundHLBG::HandleKillUnit(Creature* unit, Player* killer)
{
    if (GetStatus() != STATUS_IN_PROGRESS || !unit || !killer)
        return;

    TeamId victimTeam = TEAM_NEUTRAL;
    uint32 scorePoints = 0;
    if (!ClassifyNpc(unit->GetEntry(), victimTeam, scorePoints))
        return;

    ModifyTeamResources(victimTeam, -static_cast<int32>(scorePoints));
    RewardNpcKill(killer, unit, scorePoints, victimTeam);
    SyncResourceState();
}

void BattlegroundHLBG::TeleportPlayerToTeamStart(Player* player) const
{
    if (!player)
        return;

    if (Position const* startPosition = GetTeamStartPosition(player->GetBgTeamId()))
        player->TeleportTo(GetMapId(), startPosition->GetPositionX(), startPosition->GetPositionY(), startPosition->GetPositionZ(), startPosition->GetOrientation());
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
    std::vector<Player*> players;
    players.reserve(GetPlayers().size());
    for (auto const& playerEntry : GetPlayers())
        players.push_back(playerEntry.second);

    for (Player* player : players)
    {
        if (!player || !player->IsInWorld() || player->IsGameMaster())
            continue;

        uint32 lowGuid = player->GetGUID().GetCounter();
        bool wasAfk = _afkFlagged.count(lowGuid) > 0;

        if (_playerLastMove.find(player->GetGUID()) == _playerLastMove.end())
            ResetPlayerTracking(player);

        uint32 idleSeconds = now - _playerLastMove[player->GetGUID()];
        if (idleSeconds >= _afkTeleportSeconds)
        {
            if (!wasAfk)
            {
                _afkFlagged.insert(lowGuid);
                uint8& infractions = _afkInfractions[lowGuid];
                ++infractions;

                if (infractions == 1)
                    TeleportPlayerToTeamStart(player);
                else
                    player->LeaveBattleground();

                UpdateWorldStatesForPlayer(player);
                SendStatusSnapshotToPlayer(player);
            }
        }
        else if (idleSeconds >= _afkWarnSeconds)
        {
            _playerWarnedBeforeTeleport[player->GetGUID()] = true;
        }

        bool afkFromChat = player->isAFK();
        if (afkFromChat && !wasAfk)
        {
            _afkFlagged.insert(lowGuid);
            uint8& infractions = _afkInfractions[lowGuid];
            ++infractions;

            if (infractions >= 2)
                player->LeaveBattleground();

            UpdateWorldStatesForPlayer(player);
            SendStatusSnapshotToPlayer(player);
        }
        else if (!afkFromChat && wasAfk && idleSeconds < _afkTeleportSeconds)
        {
            _afkFlagged.erase(lowGuid);
            UpdateWorldStatesForPlayer(player);
            SendStatusSnapshotToPlayer(player);
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
                player->RewardHonor(nullptr, 0, static_cast<float>(honorReward));

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

    if (winnerTeamId == TEAM_ALLIANCE || winnerTeamId == TEAM_HORDE)
        HLBGPlayerStats::OnTeamWin(winnerTeamId, HLBG_ZONE_ID);

    if (!_matchResultRecorded)
    {
        _matchResultRecorded = true;
        HLBGService::Instance().RecordWinner(winnerTeamId, GetMapId(),
            GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE),
            _endedByDepletion ? "depletion" : "tiebreaker", _activeAffix,
            GetAffixWeatherType(_activeAffix), GetAffixWeatherIntensity(_activeAffix),
            GetCurrentMatchDurationSeconds());
    }
}

void BattlegroundHLBG::EndBattleground(TeamId winnerTeamId)
{
    RewardMatchOutcome(winnerTeamId);
    ClearAffixEffects();
    _activeAffix = HLBG_AFFIX_NONE;
    _affixNextChangeEpoch = 0u;
    _affixRotationTimerMs = 0u;
    UpdateWorldStatesForAll();
    SendAffixSnapshotToAll();
    SendStatusSnapshotToAll();
    Battleground::EndBattleground(winnerTeamId);
}

void BattlegroundHLBG::ClearAffixEffects()
{
    for (auto const& playerEntry : GetPlayers())
    {
        Player* player = playerEntry.second;
        if (!player)
            continue;

        for (uint32 spellId : _affixPlayerSpell)
        {
            if (spellId)
                player->RemoveAurasDueToSpell(spellId);
        }
    }

    for (uint32 spellId : _affixNpcSpell)
    {
        if (!spellId)
            continue;

        HLBGNpcAuraWorker worker;
        worker.areaId = HLBG_AREA_ID;
        worker.spellId = spellId;
        worker.remove = true;
        VisitBattlegroundMap(this, worker);
    }
}

void BattlegroundHLBG::ApplyAffixEffects()
{
    uint32 playerSpellId = GetAffixPlayerSpell(_activeAffix);
    if (playerSpellId)
    {
        for (auto const& playerEntry : GetPlayers())
        {
            Player* player = playerEntry.second;
            if (player && player->IsInWorld())
                player->CastSpell(player, playerSpellId, true);
        }
    }

    uint32 npcSpellId = GetAffixNpcSpell(_activeAffix);
    if (npcSpellId)
    {
        HLBGNpcAuraWorker worker;
        worker.areaId = HLBG_AREA_ID;
        worker.spellId = npcSpellId;
        worker.remove = false;
        VisitBattlegroundMap(this, worker);
    }

    if (_affixWeatherEnabled)
        ApplyAffixWeather();

    if (_affixAnnounce && _activeAffix != HLBG_AFFIX_NONE)
    {
        std::ostringstream message;
        message << "HLBG affix active: " << GetAffixName(_activeAffix);
        if (_affixWeatherEnabled)
        {
            message << " (" << GetWeatherName(GetAffixWeatherType(_activeAffix))
                << ' ' << static_cast<uint32>(
                    std::lround(GetAffixWeatherIntensity(_activeAffix) * 100.0f))
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
    auto* battlegroundMap = dynamic_cast<BattlegroundMap*>(map);
    if (!battlegroundMap)
        return;

    if (Weather* weather = battlegroundMap->GetOrGenerateZoneDefaultWeather(HLBG_ZONE_ID))
    {
        weather->SetWeather(
            static_cast<WeatherType>(GetAffixWeatherType(_activeAffix)),
            GetAffixWeatherIntensity(_activeAffix));
    }
}

void BattlegroundHLBG::SelectAffixForNewBattle()
{
    ClearAffixEffects();

    if (!_affixEnabled)
    {
        _activeAffix = HLBG_AFFIX_NONE;
        _affixRotationTimerMs = 0u;
        _affixNextChangeEpoch = 0u;
        return;
    }

    uint8 nextAffix = HLBG_AFFIX_NONE;
    if (_affixRandomOnStart)
    {
        nextAffix = urand(HLBG_AFFIX_SUNLIGHT, HLBG_AFFIX_FOG);
    }
    else
    {
        uint8 currentAffix = _activeAffix;
        if (currentAffix < HLBG_AFFIX_SUNLIGHT || currentAffix > HLBG_AFFIX_FOG)
            currentAffix = HLBG_AFFIX_FOG;

        nextAffix = currentAffix + 1;
        if (nextAffix > HLBG_AFFIX_FOG)
            nextAffix = HLBG_AFFIX_SUNLIGHT;
    }

    if (nextAffix == _activeAffix)
        nextAffix = (nextAffix == HLBG_AFFIX_FOG) ? HLBG_AFFIX_SUNLIGHT : (nextAffix + 1);

    _activeAffix = nextAffix;
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

    if (_hudSyncTimerMs <= diff)
    {
        _hudSyncTimerMs = HLBGHudSyncIntervalMs;
        UpdateWorldStatesForAll();
        SendStatusSnapshotToAll();
    }
    else
        _hudSyncTimerMs -= diff;
}