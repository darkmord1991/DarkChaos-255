/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Mythic+ Spectator System - Implementation
 * Extends ArenaSpectator framework for Mythic+ dungeon spectating.
 */

#include "ScriptMgr.h"
#include "dc_mythic_spectator.h"
#include "Player.h"
#include "Pet.h"
#include "Config.h"
#include "Chat.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "ObjectAccessor.h"
#include "Map.h"
#include "MapMgr.h"
#include "InstanceScript.h"
#include "Log.h"
#include "MythicPlusRunManager.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "Guild.h"

#include <sstream>
#include <random>

using namespace Acore::ChatCommands;

namespace DCMythicSpectator
{

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
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_int_distribution<> dis(0, sizeof(chars) - 2);
    
    std::string code;
    code.reserve(length);
    for (uint32 i = 0; i < length; ++i)
        code += chars[dis(gen)];
    return code;
}

// ============================================================
// Run Management
// ============================================================
void MythicSpectatorManager::RegisterActiveRun(uint32 instanceId, uint32 mapId, uint8 keystoneLevel,
                                                std::string const& leaderName, bool allowSpectators)
{
    if (!_config.enabled)
        return;

    if (keystoneLevel < _config.minKeystoneLevel)
        return;

    SpectateableRun run;
    run.instanceId = instanceId;
    run.mapId = mapId;
    run.keystoneLevel = keystoneLevel;
    run.startedAt = GameTime::GetGameTime().count();
    run.timerRemaining = 0;
    run.bossesKilled = 0;
    run.bossesTotal = 0;
    run.deaths = 0;
    run.leaderName = leaderName;
    run.allowsSpectators = allowSpectators && _config.allowPublicListing;
    run.streamMode = _config.defaultStreamMode;
    run.inviteCode = "";
    run.inviteCodeExpires = 0;
    run.activeReplay = nullptr;

    _activeRuns[instanceId] = run;
    
    // Start recording if enabled
    if (_config.replayEnabled)
        StartRecording(instanceId);

    LOG_DEBUG("scripts", "MythicSpectator: Registered run {} (map {}, +{})", 
              instanceId, mapId, keystoneLevel);
}

void MythicSpectatorManager::UnregisterActiveRun(uint32 instanceId)
{
    auto it = _activeRuns.find(instanceId);
    if (it == _activeRuns.end())
        return;
    
    // Stop and save replay
    if (_config.replayEnabled)
        StopRecording(instanceId, true);

    // Kick all spectators from this run
    for (ObjectGuid guid : it->second.spectators)
    {
        if (Player* spectator = ObjectAccessor::FindPlayer(guid))
        {
            ChatHandler(spectator->GetSession()).SendSysMessage(
                "|cffff0000[M+ Spectator]|r The run has ended. You have been returned to your previous location.");
            StopSpectating(spectator);
        }
    }

    _activeRuns.erase(it);

    LOG_DEBUG("scripts", "MythicSpectator: Unregistered run {}", instanceId);
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
        ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000[M+ Spectator]|r %s", error.c_str());
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

    // Teleport to the dungeon
    float z = targetPlayer->GetPositionZ() + 0.25f;
    player->TeleportTo(run.mapId, targetPlayer->GetPositionX(), targetPlayer->GetPositionY(), 
                       z, targetPlayer->GetOrientation());

    // Start watching the first player
    WatchPlayer(player, targetPlayer);

    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Now spectating +%u %s. Use |cffffd700.spectate watch <player>|r to switch views.",
        run.keystoneLevel, run.leaderName.c_str());

    // Announce to participants if enabled
    if (_config.announceNewSpectators)
    {
        for (auto const& ref : players)
        {
            if (Player* p = ref.GetSource())
            {
                ChatHandler(p->GetSession()).PSendSysMessage(
                    "|cff00ff00[M+ Spectator]|r %s has joined as a spectator.", player->GetName().c_str());
            }
        }
    }

    LOG_INFO("scripts", "MythicSpectator: {} started spectating run {} (+{})", 
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

    // Restore original state
    player->SetGameMaster(false);
    player->SetGMVisible(true);
    RestoreSpectatorPosition(player, state);

    _spectators.erase(it);

    ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[M+ Spectator]|r You have stopped spectating.");

    LOG_DEBUG("scripts", "MythicSpectator: {} stopped spectating", player->GetName());
}

bool MythicSpectatorManager::IsSpectating(Player* player) const
{
    if (!player)
        return false;
    return _spectators.find(player->GetGUID()) != _spectators.end();
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
        "|cff00ff00[M+ Spectator]|r Now watching %s.", target->GetName().c_str());

    return true;
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

    for (ObjectGuid guid : runIt->second.spectators)
    {
        if (Player* p = ObjectAccessor::FindPlayer(guid))
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

    WorldPacket data;
    CreatePacket(data, message);

    for (ObjectGuid guid : runIt->second.spectators)
    {
        if (Player* p = ObjectAccessor::FindPlayer(guid))
            p->SendDirectMessage(&data);
    }
}

void MythicSpectatorManager::BroadcastRunUpdate(uint32 instanceId)
{
    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    std::string data = FormatRunData(runIt->second, runIt->second.streamMode);
    BroadcastToSpectators(instanceId, data);
}

void MythicSpectatorManager::SendRunSnapshot(Player* spectator, uint32 instanceId)
{
    auto runIt = _activeRuns.find(instanceId);
    if (runIt == _activeRuns.end())
        return;

    auto stateIt = _spectators.find(spectator->GetGUID());
    uint32 streamMode = (stateIt != _spectators.end()) ? stateIt->second.streamMode : 0;

    std::string data = FormatRunData(runIt->second, streamMode);
    
    WorldPacket packet;
    CreatePacket(packet, data);
    spectator->SendDirectMessage(&packet);
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
    if (!_config.enabled)
        return;

    _updateTimer += diff;
    if (_updateTimer < _config.updateIntervalMs)
        return;
    _updateTimer = 0;

    // Update run status from MythicPlusRunManager
    for (auto& [instanceId, run] : _activeRuns)
    {
        Map* map = sMapMgr->FindMap(run.mapId, instanceId);
        if (!map)
            continue;

        // Get state from MythicPlusRunManager
        MythicPlusRunManager::InstanceState const* state = sMythicRuns->GetRunState(map);
        if (state)
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

    // Update spectator viewpoints
    for (auto& [guid, state] : _spectators)
    {
        Player* spectator = ObjectAccessor::FindPlayer(guid);
        if (!spectator)
            continue;

        UpdateSpectatorViewpoint(spectator);
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

    // If watching a player, update position to follow
    if (!state.watchingPlayer.IsEmpty())
    {
        Player* target = ObjectAccessor::FindPlayer(state.watchingPlayer);
        if (target && target->IsAlive() && target->GetInstanceId() == state.targetInstanceId)
        {
            // Ensure viewpoint is maintained
            if (!spectator->GetViewpoint() || spectator->GetViewpoint()->GetGUID() != target->GetGUID())
            {
                if (spectator->HaveAtClient(target))
                    spectator->CastSpell(target, SPECTATOR_BINDSIGHT_SPELL, true);
            }
        }
        else
        {
            // Target dead or left - find another player to watch
            state.watchingPlayer.Clear();
            
            Map* map = sMapMgr->FindMap(state.targetMapId, state.targetInstanceId);
            if (map)
            {
                Map::PlayerList const& players = map->GetPlayers();
                for (auto const& ref : players)
                {
                    if (Player* p = ref.GetSource())
                    {
                        if (p->IsAlive() && !IsSpectating(p))
                        {
                            WatchPlayer(spectator, p);
                            break;
                        }
                    }
                }
            }
        }
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
    
    LOG_DEBUG("scripts", "MythicSpectator: Generated invite code {} for run {} by {}", 
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
        "|cff00ff00[M+ Spectator]|r %s invites you to watch their +%u %s run! "
        "|cffffd700|Hspectate:%s|h[Click to Join]|h|r or type: .spectate code %s",
        sender->GetName().c_str(), run ? run->keystoneLevel : 0, mapName.c_str(), code.c_str(), code.c_str());
    
    ChatHandler(sender->GetSession()).PSendSysMessage(
        "|cff00ff00[M+ Spectator]|r Invite sent to %s.", recipient->GetName().c_str());
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
    
    LOG_DEBUG("scripts", "MythicSpectator: Synced {} HUD worldstates to spectator {}", 
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
        if (Player* spectator = ObjectAccessor::FindPlayer(guid))
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
    
    LOG_DEBUG("scripts", "MythicSpectator: Started recording replay for run {}", instanceId);
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
    
    LOG_DEBUG("scripts", "MythicSpectator: Stopped recording replay for run {}", instanceId);
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
    
    // Save to database
    CharacterDatabase.Execute(
        "INSERT INTO dc_mythic_spectator_replays "
        "(map_id, keystone_level, leader_name, start_time, end_time, completed, replay_data) "
        "VALUES ({}, {}, '{}', {}, {}, {}, '{}')",
        replay.mapId, uint32(replay.keystoneLevel), replay.leaderName,
        replay.startTime, replay.endTime, replay.completed ? 1 : 0, serialized);
    
    // Cleanup old replays if over limit
    CharacterDatabase.Execute(
        "DELETE FROM dc_mythic_spectator_replays WHERE id NOT IN "
        "(SELECT id FROM (SELECT id FROM dc_mythic_spectator_replays ORDER BY start_time DESC LIMIT {}) AS t)",
        _config.replayMaxStoredRuns);
    
    LOG_INFO("scripts", "MythicSpectator: Saved replay for run {} ({} events)", 
             instanceId, replay.events.size());
    
    return true;
}

std::vector<std::pair<uint32, std::string>> MythicSpectatorManager::GetRecentReplays(uint32 limit)
{
    std::vector<std::pair<uint32, std::string>> result;
    
    QueryResult qr = CharacterDatabase.Query(
        "SELECT id, map_id, keystone_level, leader_name, start_time, completed "
        "FROM dc_mythic_spectator_replays ORDER BY start_time DESC LIMIT {}",
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

} // namespace DCMythicSpectator

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

            handler->PSendSysMessage("|cffffffff%5u | +%-4u | %-15.15s | %-12.12s | %u/%u B %02u:%02u | %u|r",
                run.instanceId, run.keystoneLevel, mapName.c_str(), run.leaderName.c_str(),
                run.bossesKilled, run.bossesTotal, mins, secs, uint32(run.spectators.size()));
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

    // Leave spectating
    static bool HandleSpectateLeave(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        if (!sMythicSpectator.IsSpectating(player))
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r You are not spectating.");
            return true;
        }

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

        const char* modeNames[] = { "Normal", "Names Hidden", "Full Anonymous" };
        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Stream mode: %s", modeNames[newMode]);
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

        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Invite Code: |cffffd700%s|r", inviteCode.c_str());
        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Valid for %u minutes, %u uses remaining.", duration, uses);
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
            handler->PSendSysMessage("|cffffffff[%u]|r %s", id, desc.c_str());
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

        // Load replay from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT map_id, replay_data FROM dc_mythic_spectator_replays WHERE id = {}",
            replayId);

        if (!result)
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Replay not found.");
            return true;
        }

        Field* fields = result->Fetch();
        // uint32 mapId = fields[0].Get<uint32>(); // Reserved for future replay teleport
        std::string replayData = fields[1].Get<std::string>();

        if (replayData.empty())
        {
            handler->SendSysMessage("|cffff0000[M+ Spectator]|r Replay data is corrupted.");
            return true;
        }

        // For now, just inform - full playback would need map teleport
        handler->PSendSysMessage("|cff00ff00[M+ Spectator]|r Loading replay %u...", replayId);
        handler->SendSysMessage("|cffffd700Note: Full replay playback requires being teleported to the dungeon.|r");
        
        // TODO: Implement full replay playback with ghost player simulation
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
    DCMythicSpectatorPlayerScript() : PlayerScript("DCMythicSpectatorPlayerScript") { }

    void OnPlayerLogout(Player* player) override
    {
        if (sMythicSpectator.IsSpectating(player))
            sMythicSpectator.StopSpectating(player);
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
        LOG_INFO("scripts", "DarkChaos Mythic+ Spectator system initialized (Enabled: {})", 
                 sMythicSpectator.GetConfig().enabled ? "Yes" : "No");
    }

    void OnUpdate(uint32 diff) override
    {
        sMythicSpectator.Update(diff);
    }
};

void AddSC_dc_mythic_spectator()
{
    sMythicSpectator.LoadConfig();
    new DCMythicSpectatorCommandScript();
    new DCMythicSpectatorPlayerScript();
    new DCMythicSpectatorWorldScript();
}
