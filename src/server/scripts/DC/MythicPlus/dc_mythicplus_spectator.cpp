/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Mythic+ Spectator System - Implementation
 * Extends ArenaSpectator framework for Mythic+ dungeon spectating.
 */

#include "ScriptMgr.h"
#include "dc_mythicplus_spectator.h"
#include "Player.h"
#include "Pet.h"
#include "Config.h"
#include "Chat.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "Group.h"
#include "ObjectAccessor.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectMgr.h"
#include "InstanceScript.h"
#include "Log.h"
#include "WorldPacket.h"
#include "dc_mythicplus_run_manager.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "Guild.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/Spectator/dc_spectator_core.h"
#include "Random.h"

#include <algorithm>
#include <cmath>
#include <sstream>
#include "dc_update_profiler.h"

using namespace Acore::ChatCommands;

namespace DCMythicSpectator
{

namespace
{
    std::string FormatTimerText(uint32 seconds)
    {
        std::ostringstream ss;
        uint32 minutes = seconds / 60;
        uint32 remainingSeconds = seconds % 60;

        if (minutes >= 60)
        {
            uint32 hours = minutes / 60;
            minutes %= 60;
            ss << hours << ":" << std::setw(2) << std::setfill('0')
               << minutes << ":" << std::setw(2) << remainingSeconds;
            return ss.str();
        }

        ss << std::setw(2) << std::setfill('0') << minutes
           << ":" << std::setw(2) << remainingSeconds;
        return ss.str();
    }

    // ------------------------------------------------------------
    // Dungeon floor plans
    // ------------------------------------------------------------
    // The client's dungeon map (3.3) is split into floors whose world-space
    // bounds live in DungeonMap.dbc; DungeonMapChunk.dbc says which WMO group
    // is on which floor. The spectator addon draws run members on the map the
    // spectator is looking at, so every snapshot carries the floor bounds and
    // each member's floor.
    struct FloorBounds
    {
        uint32 floorIndex = 0;
        float minX = 0.f;   // world Y range: the map's horizontal axis, west on the left
        float maxX = 0.f;
        float minY = 0.f;   // world X range: the map's vertical axis, north on top
        float maxY = 0.f;
    };

    struct DungeonFloorPlan
    {
        std::vector<FloorBounds> floors;
        std::unordered_map<int32, uint32> floorByWmoGroup;   // VMAP groupId -> floor index
    };

    std::unordered_map<uint32, DungeonFloorPlan> BuildFloorPlans()
    {
        std::unordered_map<uint32, DungeonFloorPlan> plans;
        std::unordered_map<uint32, uint32> floorByDungeonMapId;

        for (DungeonMapEntry const* entry : sDungeonMapStore)
        {
            FloorBounds bounds;
            bounds.floorIndex = entry->FloorIndex;
            bounds.minX = entry->MinX;
            bounds.maxX = entry->MaxX;
            bounds.minY = entry->MinY;
            bounds.maxY = entry->MaxY;
            plans[entry->MapID].floors.push_back(bounds);
            floorByDungeonMapId[entry->ID] = entry->FloorIndex;
        }

        for (DungeonMapChunkEntry const* chunk : sDungeonMapChunkStore)
        {
            auto floor = floorByDungeonMapId.find(chunk->DungeonMapID);
            if (floor == floorByDungeonMapId.end())
                continue;

            plans[chunk->MapID].floorByWmoGroup[static_cast<int32>(chunk->WmoGroupID)] = floor->second;
        }

        for (auto& [mapId, plan] : plans)
        {
            (void)mapId;
            std::sort(plan.floors.begin(), plan.floors.end(),
                [](FloorBounds const& a, FloorBounds const& b) { return a.floorIndex < b.floorIndex; });
        }

        return plans;
    }

    // Built once on first use and read-only after that (snapshots are built on
    // the world thread, but the magic static makes any first caller safe).
    DungeonFloorPlan const* GetFloorPlan(uint32 mapId)
    {
        static std::unordered_map<uint32, DungeonFloorPlan> const plans = BuildFloorPlans();
        auto it = plans.find(mapId);
        return it != plans.end() ? &it->second : nullptr;
    }

    // The floor a position is on: the WMO group it stands in when the chunk
    // table knows it, else the lowest floor whose bounds contain the point,
    // else the first floor. 0 when the map has no dungeon map at all.
    uint32 ResolveFloor(Map* map, uint32 phaseMask, float x, float y, float z)
    {
        DungeonFloorPlan const* plan = GetFloorPlan(map->GetId());
        if (!plan || plan->floors.empty())
            return 0;

        uint32 mogpFlags = 0;
        int32 adtId = 0;
        int32 rootId = 0;
        int32 groupId = 0;
        if (map->GetAreaInfo(phaseMask, x, y, z, mogpFlags, adtId, rootId, groupId))
        {
            auto it = plan->floorByWmoGroup.find(groupId);
            if (it != plan->floorByWmoGroup.end())
                return it->second;
        }

        for (FloorBounds const& floor : plan->floors)
            if (y >= floor.minX && y <= floor.maxX && x >= floor.minY && x <= floor.maxY)
                return floor.floorIndex;

        return plan->floors.front().floorIndex;
    }

    double RoundCoord(float value)
    {
        return std::round(static_cast<double>(value) * 10.0) / 10.0;
    }

    // Run members and the spectator's own position, so the addon can draw the
    // group on the minimap (yard offsets from the spectator) and on the dungeon
    // map (fractions of the floor bounds). Stream mode hides the names here as
    // everywhere else.
    void AppendPositions(DCAddon::JsonValue& payload, SpectateableRun const& run, Player* spectator)
    {
        Map* map = sMapMgr->FindMap(run.mapId, run.instanceId);
        if (!map)
            return;

        MythicSpectatorManager& manager = MythicSpectatorManager::Get();
        SpectatorState const* state = spectator ? manager.GetSpectatorState(spectator->GetGUID()) : nullptr;
        ObjectGuid const watching = state ? state->watchingPlayer : ObjectGuid::Empty;
        bool const hideNames = run.streamMode != STREAM_MODE_NONE;

        DCAddon::JsonValue floors;
        floors.SetArray();
        if (DungeonFloorPlan const* plan = GetFloorPlan(run.mapId))
        {
            for (FloorBounds const& floor : plan->floors)
            {
                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("index", static_cast<int32>(floor.floorIndex));
                entry.Set("minX", static_cast<double>(floor.minX));
                entry.Set("maxX", static_cast<double>(floor.maxX));
                entry.Set("minY", static_cast<double>(floor.minY));
                entry.Set("maxY", static_cast<double>(floor.maxY));
                floors.Push(std::move(entry));
            }
        }
        payload.Set("floors", std::move(floors));

        DCAddon::JsonValue players;
        players.SetArray();
        uint32 index = 0;
        for (auto const& ref : map->GetPlayers())
        {
            Player* member = ref.GetSource();
            if (!member || member->IsSpectator() || manager.IsSpectating(member))
                continue;

            ++index;
            Group const* group = member->GetGroup();

            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("name", hideNames ? Acore::StringFormat("Player {}", index) : member->GetName());
            // UnitGUID() spelling: the addon hands it to the client extension's
            // ResolveEntityPositionByGUID for an exact, per-frame position while
            // the member is in view; the x/y/z below cover the rest.
            entry.Set("guid", Acore::StringFormat("0x{:016X}", member->GetGUID().GetRawValue()));
            entry.Set("class", static_cast<int32>(member->getClass()));
            entry.Set("x", RoundCoord(member->GetPositionX()));
            entry.Set("y", RoundCoord(member->GetPositionY()));
            entry.Set("z", RoundCoord(member->GetPositionZ()));
            entry.Set("floor", static_cast<int32>(ResolveFloor(map, member->GetPhaseMask(),
                member->GetPositionX(), member->GetPositionY(), member->GetPositionZ())));
            entry.Set("health", static_cast<int32>(member->GetHealthPct()));
            entry.Set("alive", member->IsAlive());
            entry.Set("leader", group && group->GetLeaderGUID() == member->GetGUID());
            entry.Set("watched", watching == member->GetGUID());
            players.Push(std::move(entry));
        }
        payload.Set("players", std::move(players));

        if (spectator && spectator->GetMapId() == run.mapId && spectator->GetInstanceId() == run.instanceId)
        {
            DCAddon::JsonValue me;
            me.SetObject();
            me.Set("x", RoundCoord(spectator->GetPositionX()));
            me.Set("y", RoundCoord(spectator->GetPositionY()));
            me.Set("z", RoundCoord(spectator->GetPositionZ()));
            me.Set("floor", static_cast<int32>(ResolveFloor(map, spectator->GetPhaseMask(),
                spectator->GetPositionX(), spectator->GetPositionY(), spectator->GetPositionZ())));
            payload.Set("me", std::move(me));
        }
    }

    uint32 ElapsedSeconds(SpectateableRun const& run)
    {
        uint64 const now = GameTime::GetGameTime().count();
        return now > run.startedAt ? static_cast<uint32>(now - run.startedAt) : 0;
    }

    // Bosses killed and in total for a run without a keystone: the instance's
    // encounters for its difficulty (instance_encounters), each done once its
    // bit is in the completed-encounter mask. False when the map has none.
    bool GetEncounterProgress(Map* map, uint8& killed, uint8& total)
    {
        killed = 0;
        total = 0;

        DungeonEncounterList const* encounters = sObjectMgr->GetDungeonEncounterList(map->GetId(),
            map->GetDifficulty());
        if (!encounters || encounters->empty())
            return false;

        uint32 completed = 0;
        if (InstanceMap* instance = map->ToInstanceMap())
            if (InstanceScript* script = instance->GetInstanceScript())
                completed = script->GetCompletedEncounterMask();

        for (DungeonEncounter const* encounter : *encounters)
        {
            if (!encounter || !encounter->dbcEntry || encounter->dbcEntry->encounterIndex >= 32)
                continue;

            ++total;
            if (completed & (1u << encounter->dbcEntry->encounterIndex))
                ++killed;
        }

        return total > 0;
    }

    DCAddon::JsonValue BuildLiveSnapshotPayload(SpectateableRun const& run, Player* spectator)
    {
        DCAddon::JsonValue payload;
        payload.SetObject();

        uint32 progressPercent = 0;
        if (run.bossesTotal > 0)
        {
            progressPercent = std::min<uint32>(100u,
                (static_cast<uint32>(run.bossesKilled) * 100u)
                    / static_cast<uint32>(run.bossesTotal));
        }

        std::ostringstream progress;
        progress << static_cast<uint32>(run.bossesKilled) << "/"
                 << static_cast<uint32>(run.bossesTotal) << " bosses";

        payload.Set("runId", static_cast<int32>(run.runId));
        payload.Set("instanceId", static_cast<int32>(run.instanceId));
        payload.Set("mapId", static_cast<int32>(run.mapId));
        payload.Set("dungeon", run.dungeonName.empty()
            ? std::string("Unknown Dungeon")
            : run.dungeonName);
        payload.Set("level", static_cast<int32>(run.keystoneLevel));
        payload.Set("difficulty", static_cast<int32>(run.difficulty));
        // A run without a keystone has no countdown; its clock runs up.
        uint32 const elapsed = ElapsedSeconds(run);
        payload.Set("elapsed", static_cast<int32>(elapsed));
        payload.Set("timer", FormatTimerText(run.keystoneLevel ? run.timerRemaining : elapsed));
        payload.Set("timerRemaining", static_cast<int32>(run.timerRemaining));
        payload.Set("bossesKilled", static_cast<int32>(run.bossesKilled));
        payload.Set("bossesTotal", static_cast<int32>(run.bossesTotal));
        payload.Set("progress", progress.str());
        payload.Set("progressPercent", static_cast<int32>(progressPercent));
        payload.Set("deaths", static_cast<int32>(run.deaths));
        payload.Set("leader", run.leaderName);
        payload.Set("spectators",
            static_cast<int32>(run.spectators.size()));
        payload.Set("maxSpectators", static_cast<int32>(
            MythicSpectatorManager::Get().GetConfig().maxSpectatorsPerRun));
        payload.Set("active", true);
        payload.Set("system", std::string(DCSpectator::SystemName(
            DCSpectator::SystemId::MythicPlus)));
        AppendPositions(payload, run, spectator);
        return payload;
    }

    void SendLiveSnapshot(Player* spectator, SpectateableRun const& run)
    {
        DCSpectator::SendSnapshotPayload(spectator,
            BuildLiveSnapshotPayload(run, spectator));
    }
}

// ============================================================
// Replay Event Implementation
// ============================================================
void RunReplay::AddEvent(ReplayEventType type, std::string const& data)
{
    if (events.size() >= REPLAY_MAX_EVENTS)
        events.pop_front();  // Remove oldest event if at capacity

    ReplayEvent event;
    event.timestamp = GameTime::GetGameTimeMS().count() - (startTime * 1000);
    event.type = type;
    event.data = data;
    events.push_back(event);
}

std::string RunReplay::Serialize() const
{
    std::ostringstream ss;
    ss << "{\"replayId\":" << replayId
       << ",\"instanceId\":" << instanceId
       << ",\"mapId\":" << mapId
       << ",\"keystoneLevel\":" << uint32(keystoneLevel)
       << ",\"startTime\":" << startTime
       << ",\"endTime\":" << endTime
       << ",\"completed\":" << (completed ? "true" : "false")
       << ",\"leaderName\":\"" << leaderName << "\""
       << ",\"events\":[";

    bool first = true;
    for (auto const& event : events)
    {
        if (!first) ss << ",";
        ss << "{\"t\":" << event.timestamp
           << ",\"type\":" << uint32(event.type)
           << ",\"data\":" << event.data << "}";
        first = false;
    }
    ss << "]}";
    return ss.str();
}

bool RunReplay::Deserialize(std::string const& data)
{
    DCAddon::JsonValue root = DCAddon::JsonParser::Parse(data);
    if (!root.IsObject())
        return false;

    replayId = root.HasKey("replayId") ? root["replayId"].AsUInt32() : replayId;
    instanceId = root.HasKey("instanceId") ? root["instanceId"].AsUInt32() : instanceId;
    mapId = root.HasKey("mapId") ? root["mapId"].AsUInt32() : mapId;
    keystoneLevel = root.HasKey("keystoneLevel") ? static_cast<uint8>(root["keystoneLevel"].AsUInt32()) : keystoneLevel;
    startTime = root.HasKey("startTime") ? root["startTime"].AsUInt32() : startTime;
    endTime = root.HasKey("endTime") ? root["endTime"].AsUInt32() : endTime;
    completed = root.HasKey("completed") ? root["completed"].AsBool() : completed;
    leaderName = root.HasKey("leaderName") ? root["leaderName"].AsString() : leaderName;

    events.clear();
    if (root.HasKey("events") && root["events"].IsArray())
    {
        for (auto const& entry : root["events"].AsArray())
        {
            if (!entry.IsObject())
                continue;

            ReplayEvent event;
            event.timestamp = entry.HasKey("t") ? entry["t"].AsUInt32() : 0;
            event.type = entry.HasKey("type")
                ? static_cast<ReplayEventType>(entry["type"].AsUInt32())
                : ReplayEventType::RUN_START;

            if (entry.HasKey("data"))
                event.data = entry["data"].Encode();
            else
                event.data = "null";

            events.push_back(event);
        }
    }

    return true;
}

// ============================================================
// Configuration
// ============================================================
void MythicSpectatorConfig::Load()
{
    enabled = sConfigMgr->GetOption<bool>("MythicSpectator.Enable", true);
    allowWhileInProgress = sConfigMgr->GetOption<bool>("MythicSpectator.AllowWhileInProgress", true);
    requireSameRealm = sConfigMgr->GetOption<bool>("MythicSpectator.RequireSameRealm", false);
    announceNewSpectators = sConfigMgr->GetOption<bool>("MythicSpectator.AnnounceNewSpectators", true);
    maxSpectatorsPerRun = sConfigMgr->GetOption<uint32>("MythicSpectator.MaxSpectatorsPerRun", 50);
    updateIntervalMs = sConfigMgr->GetOption<uint32>("MythicSpectator.UpdateIntervalMs", 1000);
    minKeystoneLevel = sConfigMgr->GetOption<uint32>("MythicSpectator.MinKeystoneLevel", 2);
    allowPublicListing = sConfigMgr->GetOption<bool>("MythicSpectator.AllowPublicListing", true);
    streamModeEnabled = sConfigMgr->GetOption<bool>("MythicSpectator.StreamModeEnabled", true);
    defaultStreamMode = sConfigMgr->GetOption<uint32>("MythicSpectator.DefaultStreamMode", 0);

    // Invite system
    inviteLinksEnabled = sConfigMgr->GetOption<bool>("MythicSpectator.InviteLinks.Enable", true);
    inviteLinkExpireSeconds = sConfigMgr->GetOption<uint32>("MythicSpectator.InviteLinks.ExpireSeconds", 3600);

    // Replay system
    replayEnabled = sConfigMgr->GetOption<bool>("MythicSpectator.Replay.Enable", true);
    replayMaxStoredRuns = sConfigMgr->GetOption<uint32>("MythicSpectator.Replay.MaxStoredRuns", 100);
    replayRecordPositions = sConfigMgr->GetOption<bool>("MythicSpectator.Replay.RecordPositions", false);
    replayRecordCombatLog = sConfigMgr->GetOption<bool>("MythicSpectator.Replay.RecordCombatLog", false);

    // HUD sync
    syncHudToSpectators = sConfigMgr->GetOption<bool>("MythicSpectator.SyncHudToSpectators", true);
}

// ============================================================
// Manager Singleton
// ============================================================
MythicSpectatorManager& MythicSpectatorManager::Get()
{
    static MythicSpectatorManager instance;
    return instance;
}

void MythicSpectatorManager::LoadConfig()
{
    _config.Load();
}

// ============================================================
// Random Code Generator
// ============================================================
std::string MythicSpectatorManager::GenerateRandomCode(uint32 length)
{
    static const char chars[] = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";  // Excluding confusing chars (0,O,1,I)

    std::string code;
    code.reserve(length);
    for (uint32 i = 0; i < length; ++i)
        code += chars[urand(0, sizeof(chars) - 2)];
    return code;
}

// ============================================================
// Run Management
// ============================================================
void MythicSpectatorManager::RegisterActiveRun(uint32 instanceId,
    uint32 mapId, uint8 keystoneLevel, std::string const& leaderName,
    bool allowSpectators, uint32 runId, std::string const& dungeonName,
    bool botRun)
{
    if (!_config.enabled)
        return;

    if (keystoneLevel < _config.minKeystoneLevel)
        return;

    SpectateableRun run;
    run.runId = runId;
    run.instanceId = instanceId;
    run.mapId = mapId;
    run.keystoneLevel = keystoneLevel;
    run.difficulty = DUNGEON_DIFFICULTY_EPIC;
    run.startedAt = GameTime::GetGameTime().count();
    run.timerRemaining = 0;
    run.bossesKilled = 0;
    run.bossesTotal = 0;
    run.deaths = 0;
    run.dungeonName = dungeonName;
    run.leaderName = leaderName;
    run.allowsSpectators = allowSpectators && _config.allowPublicListing;
    run.streamMode = _config.defaultStreamMode;
    run.inviteCode = "";
    run.inviteCodeExpires = 0;

    _activeRuns[instanceId] = run;

    // Start recording if enabled. Bot-only runs are listed but not recorded.
    if (_config.replayEnabled && !botRun)
        StartRecording(instanceId);

    LOG_DEBUG("scripts.dc", "MythicSpectator: Registered run {} (map {}, +{})",
              instanceId, mapId, keystoneLevel);
}

// No key level to hold against MinKeystoneLevel and no replay: these runs are
// the bot runs of `.playerbots dungeon start`, which register themselves once
// the group is inside and unregister at teardown.
void MythicSpectatorManager::RegisterDungeonRun(uint32 instanceId, uint32 mapId, uint8 difficulty,
    std::string const& leaderName, std::string const& dungeonName)
{
    if (!_config.enabled)
        return;

    SpectateableRun run;
    run.instanceId = instanceId;
    run.mapId = mapId;
    run.difficulty = difficulty;
    run.startedAt = GameTime::GetGameTime().count();
    run.dungeonName = dungeonName;
    run.leaderName = leaderName;
    run.allowsSpectators = _config.allowPublicListing;
    run.streamMode = _config.defaultStreamMode;

    _activeRuns[instanceId] = run;

    LOG_DEBUG("scripts.dc", "MythicSpectator: Registered dungeon run {} (map {}, difficulty {})",
              instanceId, mapId, difficulty);
}

void MythicSpectatorManager::UnregisterActiveRun(uint32 instanceId)
{
    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
        return;

    // Stop and save replay
    if (_config.replayEnabled)
        StopRecording(instanceId, true);

    // Kick all spectators from this run. Iterate a copy: StopSpectating erases
    // from this very set. Resolve globally rather than on the run's map, so a
    // spectator still in transit is released instead of left in GM mode.
    std::vector<ObjectGuid> const spectators(it->second.spectators.begin(), it->second.spectators.end());
    for (ObjectGuid guid : spectators)
    {
        if (Player* spectator = ObjectAccessor::FindConnectedPlayer(guid))
        {
            ChatHandler(spectator->GetSession()).SendSysMessage(
                "|cffff0000[M+ Spectator]|r The run has ended. You have been returned to your previous location.");
            StopSpectating(spectator);
        }
        else
            _spectators.erase(guid);
    }

    _activeRuns.erase(it);

    LOG_DEBUG("scripts.dc", "MythicSpectator: Unregistered run {}", instanceId);
}

void MythicSpectatorManager::UpdateRunStatus(uint32 instanceId, uint32 timerRemaining,
                                              uint8 bossesKilled, uint8 bossesTotal, uint8 deaths)
{
    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
        return;

    it->second.timerRemaining = timerRemaining;
    it->second.bossesKilled = bossesKilled;
    it->second.bossesTotal = bossesTotal;
    it->second.deaths = deaths;
}

void MythicSpectatorManager::SetRunStreamMode(uint32 instanceId, uint32 mode)
{
    auto it = _activeRuns.find(instanceId);
    if (it != _activeRuns.end())
        it->second.streamMode = mode;
}

std::vector<SpectateableRun> MythicSpectatorManager::GetSpectateableRuns() const
{
    std::vector<SpectateableRun> result;
    result.reserve(_activeRuns.size());

    for (auto const& [id, run] : _activeRuns)
    {
        if (run.allowsSpectators)
            result.push_back(run);
    }

    // Sort by keystone level descending
    std::sort(result.begin(), result.end(), [](SpectateableRun const& a, SpectateableRun const& b) {
        return a.keystoneLevel > b.keystoneLevel;
    });

    return result;
}

SpectateableRun const* MythicSpectatorManager::GetRun(uint32 instanceId) const
{
    auto it = _activeRuns.find(instanceId);
    return it != _activeRuns.end() ? &it->second : nullptr;
}

// ============================================================
// Spectator Control
// ============================================================
bool MythicSpectatorManager::CanSpectate(Player* player, uint32 instanceId, std::string& error) const
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    if (!_config.enabled)
    {
        error = "M+ Spectating is currently disabled.";
        return false;
    }

    // Check if already spectating
    if (IsSpectating(player))
    {
        error = "You are already spectating.";
        return false;
    }

    // Check run exists
    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
    {
        error = "That run is not available for spectating.";
        return false;
    }

    SpectateableRun const& run = it->second;

    if (!run.allowsSpectators)
    {
        error = "This run does not allow spectators.";
        return false;
    }

    if (run.spectators.size() >= _config.maxSpectatorsPerRun)
    {
        error = "Maximum spectators reached for this run.";
        return false;
    }

    // Player state checks (similar to ArenaSpectator)
    if (player->IsBeingTeleported() || !player->IsInWorld())
    {
        error = "Can't spectate while being teleported.";
        return false;
    }

    if (player->FindMap() && player->FindMap()->Instanceable())
    {
        error = "Can't spectate while in an instance.";
        return false;
    }

    if (player->GetVehicle())
    {
        error = "Can't spectate while in a vehicle.";
        return false;
    }

    // The spectator flag's attack check covers the player, not their pet.
    if (!player->m_Controlled.empty())
    {
        error = "Dismiss your pet before spectating.";
        return false;
    }

    if (player->IsInCombat())
    {
        error = "Can't spectate while in combat.";
        return false;
    }

    if (player->InBattlegroundQueue())
    {
        error = "Can't spectate while queued for PvP.";
        return false;
    }

    if (player->GetGroup())
    {
        error = "Can't spectate while in a group.";
        return false;
    }

    if (!player->IsAlive())
    {
        error = "Must be alive to spectate.";
        return false;
    }

    if (player->IsMounted())
    {
        error = "Please dismount before spectating.";
        return false;
    }

    if (player->IsInFlight())
    {
        error = "Can't spectate while in flight.";
        return false;
    }

    return true;
}

bool MythicSpectatorManager::StartSpectating(Player* player, uint32 instanceId)
{
    std::string error;
    if (!CanSpectate(player, instanceId, error))
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000[M+ Spectator]|r {}", error);
        return false;
    }

    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
        return false;

    SpectateableRun& run = it->second;

    // Find the map
    Map* targetMap = sMapMgr->FindMap(run.mapId, instanceId);
    if (!targetMap || !targetMap->IsDungeon())
    {
        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Could not find the dungeon instance.");
        return false;
    }

    // Find a participant to teleport near
    Player* targetPlayer = nullptr;
    Map::PlayerList const& players = targetMap->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* p = ref.GetSource())
        {
            if (p->IsAlive())
            {
                targetPlayer = p;
                break;
            }
        }
    }

    if (!targetPlayer)
    {
        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r No active players found in the run.");
        return false;
    }

    // Create spectator state
    SpectatorState state;
    state.spectatorGuid = player->GetGUID();
    state.targetInstanceId = instanceId;
    state.targetMapId = run.mapId;
    state.watchingPlayer.Clear();
    state.joinedAt = GameTime::GetGameTime().count();
    state.streamMode = run.streamMode;
    state.isStreamer = false;
    SaveSpectatorPosition(player, state);

    _spectators[player->GetGUID()] = state;
    run.spectators.insert(player->GetGUID());

    // Set spectator flags (GM mode for invisibility)
    player->SetGameMaster(true);
    player->SetGMVisible(false);

    // A dungeon teleport normally picks its instance from the player's own binds,
    // which know nothing about this run - and a lockout on another copy of the
    // dungeon would win. The pending spectator id sends the player into this
    // instance instead, without binding them (MapInstanced::CreateInstanceForPlayer,
    // InstanceMap::AddPlayerToMap); the worldport ack clears it on arrival.
    player->SetPendingSpectatorForBG(instanceId);

    // Teleport to the dungeon. TELE_TO_GM_MODE skips the entry requirements
    // (level, attunement, lockout checks) a spectator never has to meet.
    float z = targetPlayer->GetPositionZ() + 0.25f;
    if (!player->TeleportTo(run.mapId, targetPlayer->GetPositionX(), targetPlayer->GetPositionY(),
                            z, targetPlayer->GetOrientation(), TELE_TO_GM_MODE))
    {
        player->SetPendingSpectatorForBG(0);
        player->SetGameMaster(false);
        player->SetGMVisible(true);
        run.spectators.erase(player->GetGUID());
        _spectators.erase(player->GetGUID());
        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Could not teleport you to the run.");
        return false;
    }

    // No casting or attacking while watching. Only after the teleport was
    // accepted: TeleportTo refuses to port a flagged player into an instance.
    DCSpectator::HoldSpectatorFlag(player);

    // Free roam by default: the spectator walks the dungeon themselves (GM
    // mode, invisible). Locking the camera to a member is opt-in.
    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Now spectating +{} {}. You move freely; |cffffd700.spectate watch <player>|r "
        "locks the camera to a player and |cffffd700.spectate free|r releases it.",
        run.keystoneLevel, run.leaderName);

    // Announce to participants if enabled
    if (_config.announceNewSpectators)
    {
        for (auto const& ref : players)
        {
            if (Player* p = ref.GetSource())
            {
                ChatHandler(p->GetSession()).PSendSysMessage(
                    "|cff00ff00[M+ Spectator]|r {} has joined as a spectator.", player->GetName());
            }
        }
    }

    DCSpectator::NotifySessionStarted(player, DCSpectator::SystemId::MythicPlus,
        run.runId != 0 ? run.runId : instanceId, "Now spectating the run.");

    LOG_INFO("scripts.dc", "MythicSpectator: {} started spectating run {} (+{})",
             player->GetName(), instanceId, run.keystoneLevel);

    return true;
}

bool MythicSpectatorManager::StartSpectatingPlayer(Player* spectator, std::string const& targetName)
{
    if (!_config.enabled)
    {
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Spectating is disabled.");
        return false;
    }

    Player* target = ObjectAccessor::FindPlayerByName(targetName);
    if (!target)
    {
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Player not found.");
        return false;
    }

    if (!target->GetMap() || !target->GetMap()->IsDungeon())
    {
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r That player is not in a dungeon.");
        return false;
    }

    uint32 instanceId = target->GetInstanceId();

    // Check if this is a M+ run
    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
    {
        // Check via MythicPlusRunManager
        if (!sMythicRuns->IsMythicPlusActive(target->GetMap()))
        {
            ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r That player is not in a Mythic+ run.");
            return false;
        }

        // Try to get run info from MythicPlusRunManager and register it
        // This handles cases where the run wasn't registered yet
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r That run is not available for spectating.");
        return false;
    }

    return StartSpectating(spectator, instanceId);
}

void MythicSpectatorManager::StopSpectating(Player* player)
{
    if (!player)
        return;

    auto it = _spectators.find(player->GetGUID());
    if (it == _spectators.end())
        return;

    SpectatorState& state = it->second;

    // Remove viewpoint
    if (WorldObject* viewpoint = player->GetViewpoint())
    {
        if (Unit* unit = viewpoint->ToUnit())
        {
            unit->RemoveAurasByType(SPELL_AURA_BIND_SIGHT, player->GetGUID());
            player->RemoveAurasDueToSpell(SPECTATOR_BINDSIGHT_SPELL, player->GetGUID());
        }
    }

    // Remove from run's spectator list
    auto runIt = _activeRuns.find(state.targetInstanceId);
    if (runIt != _activeRuns.end())
        runIt->second.spectators.erase(player->GetGUID());

    // Restore original state. The pending id is normally cleared on arrival;
    // clear it here too in case the session ends before the spectator landed.
    DCSpectator::ReleaseSpectatorFlag(player);
    player->SetPendingSpectatorForBG(0);
    player->SetGameMaster(false);
    player->SetGMVisible(true);
    RestoreSpectatorPosition(player, state);

    _spectators.erase(it);

    if (player->GetSession())
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[M+ Spectator]|r You have stopped spectating.");

    DCSpectator::NotifySessionEnded(player, DCSpectator::SystemId::MythicPlus, "Stopped spectating.");

    LOG_DEBUG("scripts.dc", "MythicSpectator: {} stopped spectating", player->GetName());
}

bool MythicSpectatorManager::IsSpectating(Player* player) const
{
    if (!player)
        return false;
    return _spectators.find(player->GetGUID()) != _spectators.end();
}

void MythicSpectatorManager::RequestLeave(ObjectGuid guid)
{
    std::lock_guard<std::mutex> lock(_leaveRequestsMutex);
    _leaveRequests.insert(guid);
}

void MythicSpectatorManager::ProcessLeaveRequests()
{
    std::unordered_set<ObjectGuid> requests;
    {
        std::lock_guard<std::mutex> lock(_leaveRequestsMutex);
        if (_leaveRequests.empty())
            return;
        requests.swap(_leaveRequests);
    }

    for (ObjectGuid const& guid : requests)
        if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
            if (IsSpectating(player))
                StopSpectating(player);
}

bool MythicSpectatorManager::WatchPlayer(Player* spectator, Player* target)
{
    if (!spectator || !target)
        return false;

    auto it = _spectators.find(spectator->GetGUID());
    if (it == _spectators.end())
        return false;

    SpectatorState& state = it->second;

    // Validate target is in the same instance
    if (!target->GetMap() || target->GetInstanceId() != state.targetInstanceId)
    {
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r That player is not in this run.");
        return false;
    }

    if (target->IsSpectator() || !target->IsAlive())
    {
        ChatHandler(spectator->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Cannot watch that player.");
        return false;
    }

    // Remove old viewpoint
    if (WorldObject* oldViewpoint = spectator->GetViewpoint())
    {
        if (Unit* unit = oldViewpoint->ToUnit())
        {
            unit->RemoveAurasByType(SPELL_AURA_BIND_SIGHT, spectator->GetGUID());
            spectator->RemoveAurasDueToSpell(SPECTATOR_BINDSIGHT_SPELL, spectator->GetGUID());
        }
    }

    // Set new viewpoint if spectator has target in sight
    state.watchingPlayer = target->GetGUID();

    if (spectator->HaveAtClient(target))
        spectator->CastSpell(target, SPECTATOR_BINDSIGHT_SPELL, true);

    ChatHandler(spectator->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Now watching {}.", target->GetName());

    return true;
}

void MythicSpectatorManager::UnwatchPlayer(Player* spectator, bool moveToWatched)
{
    if (!spectator)
        return;

    auto it = _spectators.find(spectator->GetGUID());
    if (it == _spectators.end())
        return;

    ObjectGuid const watched = it->second.watchingPlayer;
    it->second.watchingPlayer.Clear();

    if (WorldObject* viewpoint = spectator->GetViewpoint())
    {
        if (Unit* unit = viewpoint->ToUnit())
        {
            unit->RemoveAurasByType(SPELL_AURA_BIND_SIGHT, spectator->GetGUID());
            spectator->RemoveAurasDueToSpell(SPECTATOR_BINDSIGHT_SPELL, spectator->GetGUID());
        }
    }

    if (!moveToWatched || watched.IsEmpty() || spectator->IsBeingTeleported())
        return;

    Player* target = ObjectAccessor::GetPlayer(spectator->GetMap(), watched);
    if (target && target->IsInWorld() && target->GetInstanceId() == spectator->GetInstanceId())
    {
        spectator->NearTeleportTo(target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(),
            target->GetOrientation());
    }
}

SpectatorState* MythicSpectatorManager::GetSpectatorState(ObjectGuid guid)
{
    auto it = _spectators.find(guid);
    return it != _spectators.end() ? &it->second : nullptr;
}

std::vector<Player*> MythicSpectatorManager::GetSpectatorsForInstance(uint32 instanceId) const
{
    std::vector<Player*> result;

    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return result;

    Map* runMap = sMapMgr->FindMap(runIt->second.mapId, instanceId);
    for (ObjectGuid guid : runIt->second.spectators)
    {
        if (runMap)
            if (Player* p = ObjectAccessor::GetPlayer(runMap, guid))
                result.push_back(p);
    }

    return result;
}

// ============================================================
// Broadcasting
// ============================================================
void MythicSpectatorManager::BroadcastToSpectators(uint32 instanceId, std::string const& message)
{
    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    Map* runMap = sMapMgr->FindMap(runIt->second.mapId, instanceId);

    WorldPacket data;
    CreatePacket(data, message);

    for (ObjectGuid guid : runIt->second.spectators)
    {
        if (runMap)
            if (Player* p = ObjectAccessor::GetPlayer(runMap, guid))
                p->SendDirectMessage(&data);
    }
}

void MythicSpectatorManager::BroadcastRunUpdate(uint32 instanceId)
{
    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    Map* runMap = sMapMgr->FindMap(runIt->second.mapId, instanceId);
    for (ObjectGuid guid : runIt->second.spectators)
    {
        if (!runMap)
            continue;

        if (Player* spectator = ObjectAccessor::GetPlayer(runMap, guid))
            SendLiveSnapshot(spectator, runIt->second);
    }
}

void MythicSpectatorManager::SendRunSnapshot(Player* spectator, uint32 instanceId)
{
    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    SendLiveSnapshot(spectator, runIt->second);
}

void MythicSpectatorManager::CreatePacket(WorldPacket& data, std::string const& message)
{
    // Use proper ChatHandler to build addon message packet
    ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, nullptr, nullptr, message);
}

std::string MythicSpectatorManager::FormatRunData(SpectateableRun const& run, uint32 streamMode)
{
    std::ostringstream ss;
    ss << ADDON_PREFIX;
    ss << "RUN|";
    ss << run.instanceId << "|";
    ss << run.mapId << "|";
    ss << uint32(run.keystoneLevel) << "|";
    ss << run.timerRemaining << "|";
    ss << uint32(run.bossesKilled) << "|";
    ss << uint32(run.bossesTotal) << "|";
    ss << uint32(run.deaths) << "|";

    if (streamMode >= STREAM_MODE_NAMES_HIDDEN)
        ss << "Group Leader|";  // Anonymous
    else
        ss << run.leaderName << "|";

    ss << run.spectators.size();

    return ss.str();
}

// ============================================================
// Periodic Updates
// ============================================================
void MythicSpectatorManager::Update(uint32 diff)
{
    // Every tick, and before the enabled check: a spectator who walked out of
    // the run is sent home even if spectating was switched off meanwhile.
    ProcessLeaveRequests();

    if (!_config.enabled)
        return;

    _updateTimer += diff;
    if (_updateTimer < _config.updateIntervalMs)
        return;
    _updateTimer = 0;

    // Update run status from MythicPlusRunManager, or for a run without a
    // keystone from the instance's encounters.
    std::vector<uint32> vanishedRuns;
    for (auto& [instanceId, run] : _activeRuns)
    {
        Map* map = sMapMgr->FindMap(run.mapId, instanceId);
        if (!map)
        {
            // The run manager unregisters a keystone run; a dungeon run is
            // dropped here too should its owner never have done it.
            if (!run.keystoneLevel)
                vanishedRuns.push_back(instanceId);
            continue;
        }

        if (!run.keystoneLevel)
        {
            uint8 killed = 0;
            uint8 total = 0;
            if (GetEncounterProgress(map, killed, total))
            {
                run.bossesKilled = killed;
                run.bossesTotal = total;
            }
        }
        else if (MythicPlusRunManager::InstanceState const* state = sMythicRuns->GetRunState(map))
        {
            uint64 now = GameTime::GetGameTime().count();
            run.timerRemaining = (state->timerEndsAt > now) ? static_cast<uint32>(state->timerEndsAt - now) : 0;
            run.bossesKilled = state->bossesKilled;
            run.bossesTotal = sMythicRuns->GetTotalBossesForDungeon(run.mapId);
            run.deaths = state->deaths;
        }

        // Broadcast updates to spectators
        if (!run.spectators.empty())
            BroadcastRunUpdate(instanceId);
    }

    for (uint32 instanceId : vanishedRuns)
        UnregisterActiveRun(instanceId);

    // Cleanup orphaned spectators (disconnected or crashed without proper logout)
    // This prevents memory leaks from accumulating over time.
    // A spectator still online but outside the run left it some way the exit
    // hook did not catch; send them back like a normal leave, rather than
    // dropping the state and leaving them invisible and flagged. Anyone on the
    // loading screen is in no map yet - that includes every spectator on the
    // way in, whom the old "not on the run map" test threw out mid-teleport.
    std::vector<ObjectGuid> orphanedGuids;
    std::vector<ObjectGuid> strayGuids;
    for (auto const& [guid, state] : _spectators)
    {
        Player* player = ObjectAccessor::FindConnectedPlayer(guid);
        if (!player)
        {
            orphanedGuids.push_back(guid);
            continue;
        }

        if (player->IsBeingTeleported() || !player->IsInWorld())
            continue;

        if (player->GetMapId() != state.targetMapId || player->GetInstanceId() != state.targetInstanceId)
            strayGuids.push_back(guid);
    }

    for (ObjectGuid const& guid : strayGuids)
        if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
            StopSpectating(player);
    for (ObjectGuid guid : orphanedGuids)
    {
        auto it = _spectators.find(guid);
        if (it != _spectators.end())
        {
            // Remove from run's spectator list
            auto runIt = _activeRuns.find(it->second.targetInstanceId);
            if (runIt != _activeRuns.end())
                runIt->second.spectators.erase(guid);

            _spectators.erase(it);
            LOG_DEBUG("scripts.dc", "MythicSpectator: Cleaned up orphaned spectator {}", guid.ToString());
        }
    }

    // Update spectator viewpoints for valid spectators
    for (auto& [guid, state] : _spectators)
    {
        Map* map = sMapMgr->FindMap(state.targetMapId, state.targetInstanceId);
        Player* spectator = map ? ObjectAccessor::GetPlayer(map, guid) : nullptr;
        if (!spectator)
            continue;

        UpdateSpectatorViewpoint(spectator);
    }

    if (!_replayPlayback.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        std::vector<ObjectGuid> finished;

        for (auto& [guid, playback] : _replayPlayback)
        {
            Map* viewerMap = sMapMgr->FindMap(playback.viewerMapId, playback.viewerInstanceId);
            Player* viewer = viewerMap ? ObjectAccessor::GetPlayer(viewerMap, guid) : nullptr;
            if (!viewer)
            {
                finished.push_back(guid);
                continue;
            }

            uint64 elapsed = nowMs - playback.playbackStartMs;

            while (playback.nextEventIndex < playback.replay.events.size())
            {
                ReplayEvent const& event = playback.replay.events[playback.nextEventIndex];
                if (event.timestamp > elapsed)
                    break;

                char const* typeLabel = "Event";
                switch (event.type)
                {
                    case ReplayEventType::RUN_START: typeLabel = "Run Start"; break;
                    case ReplayEventType::BOSS_PULL: typeLabel = "Boss Pull"; break;
                    case ReplayEventType::BOSS_KILL: typeLabel = "Boss Kill"; break;
                    case ReplayEventType::PLAYER_DEATH: typeLabel = "Player Death"; break;
                    case ReplayEventType::WIPE: typeLabel = "Wipe"; break;
                    case ReplayEventType::HUD_UPDATE: typeLabel = "HUD Update"; break;
                    case ReplayEventType::PLAYER_POSITION: typeLabel = "Position"; break;
                    case ReplayEventType::COMBAT_LOG: typeLabel = "Combat Log"; break;
                    case ReplayEventType::RUN_COMPLETE: typeLabel = "Run Complete"; break;
                    case ReplayEventType::RUN_FAIL: typeLabel = "Run Fail"; break;
                }

                ChatHandler(viewer->GetSession()).PSendSysMessage("|cff00ff00[M+ Replay]|r {}: {}",
                    typeLabel, event.data);

                playback.nextEventIndex++;
            }

            if (playback.nextEventIndex >= playback.replay.events.size())
                finished.push_back(guid);
        }

        for (ObjectGuid guid : finished)
        {
            auto it = _replayPlayback.find(guid);
            if (it != _replayPlayback.end())
            {
                Map* viewerMap = sMapMgr->FindMap(it->second.viewerMapId, it->second.viewerInstanceId);
                if (viewerMap)
                    if (Player* viewer = ObjectAccessor::GetPlayer(viewerMap, guid))
                        ChatHandler(viewer->GetSession()).SendSysMessage("|cffffd700[M+ Replay]|r Replay finished.");
                _replayPlayback.erase(it);
            }
        }
    }
}

void MythicSpectatorManager::SaveSpectatorPosition(Player* player, SpectatorState& state)
{
    state.savedMapId = player->GetMapId();
    state.savedPosition = Position(player->GetPositionX(), player->GetPositionY(),
                                    player->GetPositionZ(), player->GetOrientation());
}

void MythicSpectatorManager::RestoreSpectatorPosition(Player* player, SpectatorState const& state)
{
    player->TeleportTo(state.savedMapId, state.savedPosition.GetPositionX(),
                       state.savedPosition.GetPositionY(), state.savedPosition.GetPositionZ(),
                       state.savedPosition.GetOrientation());
}

void MythicSpectatorManager::UpdateSpectatorViewpoint(Player* spectator)
{
    if (!spectator || !IsSpectating(spectator))
        return;

    auto it = _spectators.find(spectator->GetGUID());
    if (it == _spectators.end())
        return;

    SpectatorState& state = it->second;

    // Free roam: nothing to maintain.
    if (state.watchingPlayer.IsEmpty())
        return;

    Map* map = sMapMgr->FindMap(state.targetMapId, state.targetInstanceId);
    Player* target = map ? ObjectAccessor::GetPlayer(map, state.watchingPlayer) : nullptr;
    if (target && target->IsAlive() && target->GetInstanceId() == state.targetInstanceId)
    {
        // Ensure viewpoint is maintained
        if (!spectator->GetViewpoint() || spectator->GetViewpoint()->GetGUID() != target->GetGUID())
        {
            if (spectator->HaveAtClient(target))
                spectator->CastSpell(target, SPECTATOR_BINDSIGHT_SPELL, true);
        }
        return;
    }

    // The watched player died or left: back to free roam, rather than jumping
    // to whoever happens to come first in the map's player list.
    UnwatchPlayer(spectator);
    if (spectator->GetSession())
    {
        ChatHandler(spectator->GetSession()).SendSysMessage(
            "|cff00ff00[M+ Spectator]|r The player you were watching is gone - camera released.");
    }
}

SpectateableRun* MythicSpectatorManager::GetRunMutable(uint32 instanceId)
{
    auto it = _activeRuns.find(instanceId);
    return it != _activeRuns.end() ? &it->second : nullptr;
}

// ============================================================
// Invite System
// ============================================================
std::string MythicSpectatorManager::GenerateInviteCode(Player* player, uint32 instanceId, uint32 uses)
{
    if (!_config.inviteLinksEnabled)
        return "";

    auto* run = GetRunMutable(instanceId);
    if (!run)
        return "";

    // Generate unique code
    std::string code = GenerateRandomCode(INVITE_CODE_LENGTH);

    // Ensure uniqueness
    while (_inviteCodes.find(code) != _inviteCodes.end())
        code = GenerateRandomCode(INVITE_CODE_LENGTH);

    SpectatorInvite invite;
    invite.code = code;
    invite.instanceId = instanceId;
    invite.inviterGuid = player->GetGUID();
    invite.createdAt = GameTime::GetGameTime().count();
    invite.expiresAt = invite.createdAt + _config.inviteLinkExpireSeconds;
    invite.usesRemaining = uses;

    _inviteCodes[code] = invite;
    run->inviteCode = code;
    run->inviteCodeExpires = invite.expiresAt;

    LOG_DEBUG("scripts.dc", "MythicSpectator: Generated invite code {} for run {} by {}",
              code, instanceId, player->GetName());

    return code;
}

bool MythicSpectatorManager::ValidateInviteCode(std::string const& code, uint32& outInstanceId) const
{
    auto it = _inviteCodes.find(code);
    if (it == _inviteCodes.end())
        return false;

    SpectatorInvite const& invite = it->second;

    // Check expiration
    if (static_cast<uint64>(GameTime::GetGameTime().count()) > invite.expiresAt)
        return false;

    // Check if run still exists
    if (_activeRuns.find(invite.instanceId) == _activeRuns.end())
        return false;

    outInstanceId = invite.instanceId;
    return true;
}

bool MythicSpectatorManager::StartSpectatingByCode(Player* player, std::string const& inviteCode)
{
    uint32 instanceId;
    if (!ValidateInviteCode(inviteCode, instanceId))
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cffff0000[M+ Spectator]|r Invalid or expired invite code.");
        return false;
    }

    // Decrement uses if limited
    auto it = _inviteCodes.find(inviteCode);
    if (it != _inviteCodes.end() && it->second.usesRemaining > 0)
    {
        it->second.usesRemaining--;
        if (it->second.usesRemaining == 0)
            _inviteCodes.erase(it);
    }

    return StartSpectating(player, instanceId);
}

void MythicSpectatorManager::SendInviteLink(Player* sender, Player* recipient, uint32 instanceId)
{
    if (!_config.inviteLinksEnabled)
    {
        ChatHandler(sender->GetSession()).SendSysMessage(
            "|cffff0000[M+ Spectator]|r Invite links are disabled.");
        return;
    }

    std::string code = GenerateInviteCode(sender, instanceId, 1);  // Single-use invite
    if (code.empty())
    {
        ChatHandler(sender->GetSession()).SendSysMessage(
            "|cffff0000[M+ Spectator]|r Failed to generate invite code.");
        return;
    }

    auto* run = GetRun(instanceId);
    std::string mapName = "Unknown";
    if (run)
    {
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(run->mapId))
            mapName = mapEntry->name[0];
    }

    // Send clickable link to recipient
    ChatHandler(recipient->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r {} invites you to watch their +{} {} run! "
        "|cffffd700|Hspectate:{}|h[Click to Join]|h|r or type: .spectate code {}",
        sender->GetName(), run ? run->keystoneLevel : 0, mapName, code, code);

    ChatHandler(sender->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Invite sent to {}.", recipient->GetName());
}

void MythicSpectatorManager::BroadcastInviteToGuild(Player* sender, uint32 instanceId)
{
    if (!_config.inviteLinksEnabled)
        return;

    Guild* guild = sender->GetGuild();
    if (!guild)
    {
        ChatHandler(sender->GetSession()).SendSysMessage(
            "|cffff0000[M+ Spectator]|r You are not in a guild.");
        return;
    }

    std::string code = GenerateInviteCode(sender, instanceId, 0);  // Unlimited uses
    if (code.empty())
        return;

    auto* run = GetRun(instanceId);
    std::string mapName = "Unknown";
    if (run)
    {
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(run->mapId))
            mapName = mapEntry->name[0];
    }

    // Broadcast to guild chat
    std::ostringstream ss;
    ss << "|cff00ff00[M+ Spectator]|r " << sender->GetName() << " is running +";
    ss << uint32(run ? run->keystoneLevel : 0) << " " << mapName;
    ss << "! Watch live: |cffffd700.spectate code " << code << "|r";

    guild->BroadcastToGuild(sender->GetSession(), false, ss.str(), LANG_UNIVERSAL);

    ChatHandler(sender->GetSession()).SendSysMessage(
        "|cff00ff00[M+ Spectator]|r Spectator invite broadcast to guild.");
}

void MythicSpectatorManager::CleanupExpiredInvites()
{
    uint64 now = GameTime::GetGameTime().count();

    for (auto it = _inviteCodes.begin(); it != _inviteCodes.end(); )
    {
        if (now > it->second.expiresAt)
            it = _inviteCodes.erase(it);
        else
            ++it;
    }
}

// ============================================================
// HUD Sync for Spectators
// ============================================================
void MythicSpectatorManager::SyncHudToSpectator(Player* spectator, uint32 instanceId)
{
    if (!_config.syncHudToSpectators || !spectator)
        return;

    Map* map = sMapMgr->FindMap(_activeRuns[instanceId].mapId, instanceId);
    if (!map)
        return;

    MythicPlusRunManager::InstanceState const* state = sMythicRuns->GetRunState(map);
    if (!state)
        return;

    // Send all worldstates to spectator
    for (auto const& [worldStateId, value] : state->hudWorldStates)
        spectator->SendUpdateWorldState(worldStateId, value);

    LOG_DEBUG("scripts.dc", "MythicSpectator: Synced {} HUD worldstates to spectator {}",
              state->hudWorldStates.size(), spectator->GetName());
}

void MythicSpectatorManager::BroadcastHudUpdate(uint32 instanceId, std::unordered_map<uint32, uint32> const& worldStates)
{
    if (!_config.syncHudToSpectators)
        return;

    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    for (ObjectGuid guid : runIt->second.spectators)
    {
        Map* map = sMapMgr->FindMap(runIt->second.mapId, instanceId);
        if (!map)
            continue;

        if (Player* spectator = ObjectAccessor::GetPlayer(map, guid))
        {
            for (auto const& [worldStateId, value] : worldStates)
                spectator->SendUpdateWorldState(worldStateId, value);
        }
    }
}

// ============================================================
// Replay System
// ============================================================
void MythicSpectatorManager::StartRecording(uint32 instanceId)
{
    if (!_config.replayEnabled)
        return;

    auto* run = GetRunMutable(instanceId);
    if (!run)
        return;

    RunReplay replay;
    replay.replayId = 0;  // Will be assigned on save
    replay.instanceId = instanceId;
    replay.mapId = run->mapId;
    replay.keystoneLevel = run->keystoneLevel;
    replay.startTime = GameTime::GetGameTime().count();
    replay.endTime = 0;
    replay.completed = false;
    replay.leaderName = run->leaderName;

    _activeReplays[instanceId] = replay;

    // Record start event
    std::ostringstream ss;
    ss << "{\"mapId\":" << run->mapId << ",\"level\":" << uint32(run->keystoneLevel)
       << ",\"leader\":\"" << run->leaderName << "\"}";
    RecordEvent(instanceId, ReplayEventType::RUN_START, ss.str());

    LOG_DEBUG("scripts.dc", "MythicSpectator: Started recording replay for run {}", instanceId);
}

void MythicSpectatorManager::StopRecording(uint32 instanceId, bool save)
{
    auto it = _activeReplays.find(instanceId);
    if (it == _activeReplays.end())
        return;

    it->second.endTime = GameTime::GetGameTime().count();

    if (save)
        SaveReplay(instanceId);

    _activeReplays.erase(it);

    LOG_DEBUG("scripts.dc", "MythicSpectator: Stopped recording replay for run {}", instanceId);
}

void MythicSpectatorManager::RecordEvent(uint32 instanceId, ReplayEventType type, std::string const& data)
{
    auto it = _activeReplays.find(instanceId);
    if (it == _activeReplays.end())
        return;

    it->second.AddEvent(type, data);
}

bool MythicSpectatorManager::SaveReplay(uint32 instanceId)
{
    auto it = _activeReplays.find(instanceId);
    if (it == _activeReplays.end())
        return false;

    RunReplay& replay = it->second;
    std::string serialized = replay.Serialize();

    // NOTE: Even if these strings are typically derived from player names / internal JSON,
    // escape them before embedding into SQL to avoid malformed queries.
    std::string leaderNameEscaped = replay.leaderName;
    CharacterDatabase.EscapeString(leaderNameEscaped);
    std::string serializedEscaped = serialized;
    CharacterDatabase.EscapeString(serializedEscaped);

    // Save to database
    CharacterDatabase.Execute(
        "INSERT INTO dc_mplus_spec_replays "
        "(map_id, keystone_level, leader_name, start_time, end_time, completed, replay_data) "
        "VALUES ({}, {}, '{}', {}, {}, {}, '{}')",
        replay.mapId, uint32(replay.keystoneLevel), leaderNameEscaped,
        replay.startTime, replay.endTime, replay.completed ? 1 : 0, serializedEscaped);

    // Cleanup old replays if over limit
    CharacterDatabase.Execute(
        "DELETE FROM dc_mplus_spec_replays WHERE id NOT IN "
        "(SELECT id FROM (SELECT id FROM dc_mplus_spec_replays ORDER BY start_time DESC LIMIT {}) AS t)",
        _config.replayMaxStoredRuns);

    LOG_INFO("scripts.dc", "MythicSpectator: Saved replay for run {} ({} events)",
             instanceId, replay.events.size());

    return true;
}

bool MythicSpectatorManager::LoadReplay(uint32 replayId, RunReplay& outReplay)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT id, map_id, keystone_level, leader_name, start_time, end_time, completed, replay_data "
        "FROM dc_mplus_spec_replays WHERE id = {}",
        replayId);

    if (!result)
        return false;

    Field* fields = result->Fetch();
    std::string replayData = fields[7].Get<std::string>();
    if (replayData.empty())
        return false;

    if (!outReplay.Deserialize(replayData))
        return false;

    outReplay.replayId = fields[0].Get<uint32>();
    outReplay.mapId = fields[1].Get<uint32>();
    outReplay.keystoneLevel = fields[2].Get<uint8>();
    outReplay.leaderName = fields[3].Get<std::string>();
    outReplay.startTime = fields[4].Get<uint64>();
    outReplay.endTime = fields[5].Get<uint64>();
    outReplay.completed = fields[6].Get<bool>();

    return true;
}

std::vector<std::pair<uint32, std::string>> MythicSpectatorManager::GetRecentReplays(uint32 limit)
{
    std::vector<std::pair<uint32, std::string>> result;

    QueryResult qr = CharacterDatabase.Query(
        "SELECT id, map_id, keystone_level, leader_name, start_time, completed "
        "FROM dc_mplus_spec_replays ORDER BY start_time DESC LIMIT {}",
        limit);

    if (!qr)
        return result;

    do
    {
        Field* fields = qr->Fetch();
        uint32 replayId = fields[0].Get<uint32>();
        uint32 mapId = fields[1].Get<uint32>();
        uint8 level = fields[2].Get<uint8>();
        std::string leader = fields[3].Get<std::string>();
        bool completed = fields[5].Get<bool>();

        std::string mapName = "Unknown";
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(mapId))
            mapName = mapEntry->name[0];

        std::ostringstream ss;
        ss << "+$" << uint32(level) << " " << mapName << " by " << leader;
        ss << (completed ? " (Completed)" : " (Failed)");

        result.emplace_back(replayId, ss.str());
    }
    while (qr->NextRow());

    return result;
}

bool MythicSpectatorManager::StartReplayPlayback(Player* player, uint32 replayId)
{
    if (!_config.replayEnabled || !player)
        return false;

    RunReplay replay;
    if (!LoadReplay(replayId, replay))
    {
        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000[M+ Spectator]|r Replay not found or corrupted.");
        return false;
    }

    StopReplayPlayback(player);
    if (IsSpectating(player))
        StopSpectating(player);

    ReplayPlaybackState state;
    state.replay = replay;
    state.playbackStartMs = GameTime::GetGameTimeMS().count();
    state.nextEventIndex = 0;
    if (Map* map = player->GetMap())
    {
        state.viewerMapId = map->GetId();
        state.viewerInstanceId = map->GetInstanceId();
    }
    _replayPlayback[player->GetGUID()] = state;

    std::string mapName = "Unknown";
    if (MapEntry const* mapEntry = sMapStore.LookupEntry(replay.mapId))
        mapName = mapEntry->name[0];

    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Replay {} loaded ({}, +{}). Type .spectate leave to stop.",
        replayId, mapName, uint32(replay.keystoneLevel));

    return true;
}

void MythicSpectatorManager::StopReplayPlayback(Player* player)
{
    if (!player)
        return;

    auto it = _replayPlayback.find(player->GetGUID());
    if (it == _replayPlayback.end())
        return;

    _replayPlayback.erase(it);
    ChatHandler(player->GetSession()).SendSysMessage("|cffffd700[M+ Replay]|r Replay stopped.");
}

bool MythicSpectatorManager::IsReplayPlayback(Player* player) const
{
    if (!player)
        return false;

    return _replayPlayback.find(player->GetGUID()) != _replayPlayback.end();
}

} // namespace DCMythicSpectator

// Bot dungeon runs without a keystone (mod-playerbots DCBotMythicRun) list
// themselves for spectating through these. modules.lib does not link
// scripts.lib, so the module re-declares them and the symbols resolve at the
// worldserver link, like the keystone API in dc_mythicplus_run_manager.cpp.
namespace DCMythicPlusBots
{
    void RegisterSpectatableDungeonRun(Map* map, std::string const& leaderName)
    {
        if (!map || !map->IsDungeon())
            return;

        sMythicSpectator.RegisterDungeonRun(map->GetInstanceId(), map->GetId(),
            static_cast<uint8>(map->GetDifficulty()), leaderName, map->GetMapName());
    }

    void UnregisterSpectatableDungeonRun(uint32 instanceId)
    {
        // Never a keystone run: those belong to the run manager.
        DCMythicSpectator::SpectateableRun const* run = sMythicSpectator.GetRun(instanceId);
        if (run && !run->keystoneLevel)
            sMythicSpectator.UnregisterActiveRun(instanceId);
    }
}

using namespace DCMythicSpectator;

// ============================================================
// Command Script
// ============================================================
class DCMythicSpectatorCommandScript : public CommandScript
{
public:
    DCMythicSpectatorCommandScript() : CommandScript("DCMythicSpectatorCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable spectateSubTable =
        {
            { "list",    HandleSpectateList,    SEC_PLAYER,        Console::No },
            { "join",    HandleSpectateJoin,    SEC_PLAYER,        Console::No },
            { "code",    HandleSpectateCode,    SEC_PLAYER,        Console::No },
            { "player",  HandleSpectatePlayer,  SEC_PLAYER,        Console::No },
            { "watch",   HandleSpectateWatch,   SEC_PLAYER,        Console::No },
            { "free",    HandleSpectateFree,    SEC_PLAYER,        Console::No },
            { "leave",   HandleSpectateLeave,   SEC_PLAYER,        Console::No },
            { "invite",  HandleSpectateInvite,  SEC_PLAYER,        Console::No },
            { "guild",   HandleSpectateGuild,   SEC_PLAYER,        Console::No },
            { "replays", HandleSpectateReplays, SEC_PLAYER,        Console::No },
            { "replay",  HandleSpectateReplay,  SEC_PLAYER,        Console::No },
            { "stream",  HandleSpectateStream,  SEC_MODERATOR,     Console::No },
            { "reload",  HandleSpectateReload,  SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "spectate", spectateSubTable },
            { "mspec",    spectateSubTable },  // Shortcut
        };

        return commandTable;
    }

    // List available M+ runs to spectate
    static bool HandleSpectateList(ChatHandler* handler)
    {
        if (!sMythicSpectator.GetConfig().enabled)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Spectating is currently disabled.");
            return true;
        }

        auto runs = sMythicSpectator.GetSpectateableRuns();
        if (runs.empty())
        {
            handler->SendSysMessage("|cffffd700[M+ Spectator]|r No active M+ runs available for spectating.");
            return true;
        }

        handler->SendSysMessage("|cff00ff00======== ACTIVE M+ RUNS ========|r");
        handler->SendSysMessage("|cffffd700ID    | Level | Dungeon | Leader | Progress | Spectators|r");

        for (auto const& run : runs)
        {
            std::string mapName = "Unknown";
            if (MapEntry const* mapEntry = sMapStore.LookupEntry(run.mapId))
                mapName = mapEntry->name[handler->GetSessionDbcLocale()];

            uint32 mins = run.timerRemaining / 60;
            uint32 secs = run.timerRemaining % 60;

            handler->SendSysMessage(Acore::StringFormat(
                "|cffffffff{:>5} | +{:<4} | {:<15} | {:<12} | {}/{} B {:02}:{:02} | {}|r",
                run.instanceId,
                run.keystoneLevel,
                mapName.substr(0, 15),
                run.leaderName.substr(0, 12),
                run.bossesKilled,
                run.bossesTotal,
                mins,
                secs,
                uint32(run.spectators.size())));
        }

        handler->SendSysMessage("|cff00ff00==================================|r");
        handler->SendSysMessage("Use |cffffd700.spectate join <ID>|r to start spectating.");
        return true;
    }

    // Join a run by instance ID
    static bool HandleSpectateJoin(ChatHandler* handler, uint32 instanceId)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        sMythicSpectator.StartSpectating(player, instanceId);
        return true;
    }

    // Join by player name
    static bool HandleSpectatePlayer(ChatHandler* handler, std::string const& playerName)
    {
        Player* spectator = handler->GetPlayer();
        if (!spectator)
            return true;

        sMythicSpectator.StartSpectatingPlayer(spectator, playerName);
        return true;
    }

    // Switch view to another player
    static bool HandleSpectateWatch(ChatHandler* handler, std::string const& targetName)
    {
        Player* spectator = handler->GetPlayer();
        if (!spectator)
            return true;

        if (!sMythicSpectator.IsSpectating(spectator))
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not spectating.");
            return true;
        }

        Player* target = ObjectAccessor::FindPlayerByName(targetName);
        if (!target)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Player not found.");
            return true;
        }

        sMythicSpectator.WatchPlayer(spectator, target);
        return true;
    }

    // Release the camera: back to free roam
    static bool HandleSpectateFree(ChatHandler* handler)
    {
        Player* spectator = handler->GetPlayer();
        if (!spectator)
            return true;

        if (!sMythicSpectator.IsSpectating(spectator))
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not spectating.");
            return true;
        }

        // Released where the camera was: the spectator lands on the player
        // they watched, which also frees a body stuck behind a wall.
        sMythicSpectator.UnwatchPlayer(spectator, true);
        handler->SendSysMessage("|cff00ff00[M+ Spectator]|r Camera released - you move freely from where you were watching.");
        return true;
    }

    // Leave spectating
    static bool HandleSpectateLeave(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        bool isReplay = sMythicSpectator.IsReplayPlayback(player);
        if (!sMythicSpectator.IsSpectating(player) && !isReplay)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not spectating.");
            return true;
        }

        sMythicSpectator.StopReplayPlayback(player);
        if (sMythicSpectator.IsSpectating(player))
            sMythicSpectator.StopSpectating(player);
        return true;
    }

    // Toggle stream mode (hide names)
    static bool HandleSpectateStream(ChatHandler* handler, Optional<uint32> mode)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        auto* state = sMythicSpectator.GetSpectatorState(player->GetGUID());
        if (!state)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not spectating.");
            return true;
        }

        uint32 newMode = mode.value_or((state->streamMode + 1) % 3);
        state->streamMode = newMode;

        char const* modeNames[] = { "Normal", "Names Hidden", "Full Anonymous" };
        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Stream mode: {}", modeNames[newMode]);
        return true;
    }

    // Join by invite code
    static bool HandleSpectateCode(ChatHandler* handler, std::string const& code)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        sMythicSpectator.StartSpectatingByCode(player, code);
        return true;
    }

    // Generate invite link
    static bool HandleSpectateInvite(ChatHandler* handler, Optional<uint32> durationMins, Optional<uint32> maxUses)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        // Check if player is in an active M+ run
        if (!player->GetMap() || !player->GetMap()->IsDungeon())
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You must be in a dungeon to create an invite.");
            return true;
        }

        uint32 instanceId = player->GetInstanceId();
        uint32 duration = durationMins.value_or(30); // Default 30 mins
        uint32 uses = maxUses.value_or(10); // Default 10 uses

        std::string inviteCode = sMythicSpectator.GenerateInviteCode(player, instanceId, uses);

        if (inviteCode.empty())
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Failed to create invite link.");
            return true;
        }

        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Invite Code: |cffffd700{}|r", inviteCode);
        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Valid for {} minutes, {} uses remaining.", duration, uses);
        handler->SendSysMessage("Share this code! Others can join with: |cffffd700.spectate code <CODE>|r");
        return true;
    }

    // Broadcast invite to guild
    static bool HandleSpectateGuild(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        Guild* guild = player->GetGuild();
        if (!guild)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not in a guild.");
            return true;
        }

        if (!player->GetMap() || !player->GetMap()->IsDungeon())
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You must be in a dungeon to broadcast.");
            return true;
        }

        uint32 instanceId = player->GetInstanceId();

        // Create invite code
        std::string inviteCode = sMythicSpectator.GenerateInviteCode(player, instanceId, 50);

        if (inviteCode.empty())
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Failed to create guild invite.");
            return true;
        }

        // Broadcast to guild
        std::string mapName = "Unknown Dungeon";
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(player->GetMapId()))
            mapName = mapEntry->name[0];

        std::ostringstream msg;
        msg << "|cff00ff00[M+ Spectator]|r " << player->GetName() << " invites you to watch: "
            << mapName << "! Use: .spectate code " << inviteCode;

        guild->BroadcastToGuild(player->GetSession(), false, msg.str().c_str(), LANG_UNIVERSAL);

        handler->SendSysMessage("|cff00ff00[M+ Spectator]|r Guild broadcast sent!");
        return true;
    }

    // List available replays
    static bool HandleSpectateReplays(ChatHandler* handler, Optional<uint32> limit)
    {
        uint32 replayLimit = limit.value_or(10);
        auto replays = sMythicSpectator.GetRecentReplays(replayLimit);

        if (replays.empty())
        {
            handler->SendSysMessage("|cffffd700[M+ Spectator]|r No replays available.");
            return true;
        }

        handler->SendSysMessage("|cff00ff00======== RECENT REPLAYS ========|r");
        for (auto const& [id, desc] : replays)
        {
            handler->PSendSysMessage("|cffffffff[{}]|r {}", id, desc);
        }
        handler->SendSysMessage("|cff00ff00==============================|r");
        handler->SendSysMessage("Use |cffffd700.spectate replay <ID>|r to watch.");
        return true;
    }

    // Watch a replay
    static bool HandleSpectateReplay(ChatHandler* handler, uint32 replayId)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        sMythicSpectator.StartReplayPlayback(player, replayId);
        return true;
    }

    // Reload config
    static bool HandleSpectateReload(ChatHandler* handler)
    {
        sMythicSpectator.LoadConfig();
        handler->SendSysMessage("M+ Spectator configuration reloaded.");
        return true;
    }
};

// ============================================================
// Player Script
// ============================================================
class DCMythicSpectatorPlayerScript : public PlayerScript
{
public:
    DCMythicSpectatorPlayerScript() : PlayerScript("DCMythicSpectatorPlayerScript",
        { PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_BEFORE_TELEPORT }) { }

    // Leaving the run any way but "leave" - the dungeon's exit portal, a
    // summon, an instance reset - would drop the spectator at the dungeon
    // entrance instead of where they started, still invisible and flagged.
    // Cancel that port and run the normal leave, which sends them back.
    // Teleports also start on map threads, so this reads only the core's
    // guarded holder set and queues the leave for the world update. M+ is the
    // only system whose spectators stand in a dungeon, and the leave's own
    // port home passes because StopSpectating releases the flag first.
    bool OnPlayerBeforeTeleport(Player* player, uint32 mapid, float /*x*/, float /*y*/, float /*z*/,
        float /*orientation*/, uint32 /*options*/, Unit* /*target*/) override
    {
        if (!player || mapid == player->GetMapId() || !DCSpectator::IsHoldingSpectatorFlag(player))
            return true;

        Map* map = player->FindMap();
        if (!map || !map->IsDungeon())
            return true;

        sMythicSpectator.RequestLeave(player->GetGUID());
        return false;
    }

    void OnPlayerLogout(Player* player) override
    {
        // Spectator sessions are stopped by the unified spectator core
        // (DCSpectatorCorePlayerScript); only replay playback is M+-local.
        if (sMythicSpectator.IsReplayPlayback(player))
            sMythicSpectator.StopReplayPlayback(player);
    }

    // Note: Spectator map change cleanup is handled by the spectator system itself
    // when teleportation occurs via StopSpectating/StartSpectating
};

// ============================================================
// World Script
// ============================================================
class DCMythicSpectatorWorldScript : public WorldScript
{
public:
    DCMythicSpectatorWorldScript() : WorldScript("DCMythicSpectatorWorldScript") { }

    void OnStartup() override
    {
        sMythicSpectator.LoadConfig();
        LOG_INFO("scripts.dc", "DarkChaos Mythic+ Spectator system initialized (Enabled: {})",
                 sMythicSpectator.GetConfig().enabled ? "Yes" : "No");
    }

    void OnUpdate(uint32 diff) override
    {
        DarkChaos::ScopedUpdateProfiler _prof("MythicPlusSpectator");
        sMythicSpectator.Update(diff);
    }
};

// The CMSG/SMSG_SPECTATOR_LIVE_SNAPSHOT bridge is owned by the unified
// spectator core (Spectator/dc_spectator_core.cpp); M+ plugs in through
// this context.
class MythicPlusSpectatableContext : public DCSpectator::ISpectatableContext
{
public:
    DCSpectator::SystemId GetSystemId() const override
    {
        return DCSpectator::SystemId::MythicPlus;
    }

    bool IsSpectating(ObjectGuid guid) const override
    {
        return MythicSpectatorManager::Get().GetSpectatorState(guid) != nullptr;
    }

    void StopSpectating(Player* player) override
    {
        MythicSpectatorManager::Get().StopSpectating(player);
    }

    bool BuildLiveSnapshot(Player* spectator,
        DCAddon::JsonValue& payload) override
    {
        SpectatorState* state = MythicSpectatorManager::Get()
            .GetSpectatorState(spectator->GetGUID());
        if (!state)
            return false;

        SpectateableRun const* run = MythicSpectatorManager::Get()
            .GetRun(state->targetInstanceId);
        if (!run)
            return false;

        payload = BuildLiveSnapshotPayload(*run, spectator);
        return true;
    }

    // M+ broadcasts its own run updates (BroadcastRunUpdate); the core
    // push loop stays off to keep the pre-unification cadence.
};

void AddSC_dc_mythic_spectator()
{
    sMythicSpectator.LoadConfig();
    new DCMythicSpectatorCommandScript();
    new DCMythicSpectatorPlayerScript();
    new DCMythicSpectatorWorldScript();

    static MythicPlusSpectatableContext mythicSpectatorContext;
    DCSpectator::Registry::Get().RegisterContext(&mythicSpectatorContext);
}
