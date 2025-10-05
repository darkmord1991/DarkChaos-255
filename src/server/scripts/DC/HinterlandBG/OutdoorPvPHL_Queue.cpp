// -----------------------------------------------------------------------------
// OutdoorPvPHL_Queue.cpp
// -----------------------------------------------------------------------------
// Queue system for Hinterland BG - allows players to register for the next
// battle and get automatically teleported when warmup phase starts.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "Player.h"
#include "Group.h"
#include "ObjectMgr.h"
#include "Chat.h"
#include "Language.h"
#include "ScriptMgr.h"
#include "GameTime.h"
#include "ObjectAccessor.h"

// Player queue management
void OutdoorPvPHL::AddPlayerToQueue(Player* player)
{
    if (!player)
        return;

    ObjectGuid playerGuid = player->GetGUID();
    
    // Check if player is already in queue
    if (IsPlayerInQueue(player))
    {
        ChatHandler(player->GetSession()).PSendSysMessage("You are already in the Hinterland BG queue.");
        return;
    }

    // Check if battle is in progress
    if (_bgState == BG_STATE_IN_PROGRESS)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("A battle is currently in progress. You can join the queue for the next battle.");
    }

    // Add player to queue
    QueueEntry entry;
    entry.playerGuid = playerGuid;
    // GameTime::GetGameTime() returns a duration (Seconds). Store the
    // integral count into the uint32 joinTime field.
    entry.joinTime = static_cast<uint32>(GameTime::GetGameTime().count());
    entry.teamId = player->GetTeamId();
    
    _queuedPlayers.push_back(entry);

    // Announce queue join
    std::string playerName = player->GetName();
    uint32 queueSize = GetQueuedPlayerCount();
    
    ChatHandler(player->GetSession()).PSendSysMessage("You have joined the Hinterland BG queue. Position: %u", queueSize);
    
    // Notify zone if we're getting close to battle start
    if (queueSize >= _minPlayersToStart && _bgState == BG_STATE_CLEANUP)
    {
        BroadcastToZone("Players are gathering for the next Hinterland Battle! Type '.hlbg queue' to join!");
    }

    LOG_DEBUG("bg.battleground", "Player {} joined HLBG queue. Queue size: {}", playerName, queueSize);
}

void OutdoorPvPHL::RemovePlayerFromQueue(Player* player)
{
    if (!player)
        return;

    ObjectGuid playerGuid = player->GetGUID();
    
    auto it = std::find_if(_queuedPlayers.begin(), _queuedPlayers.end(),
        [playerGuid](const QueueEntry& entry) {
            return entry.playerGuid == playerGuid;
        });

    if (it != _queuedPlayers.end())
    {
        _queuedPlayers.erase(it);
        ChatHandler(player->GetSession()).PSendSysMessage("You have left the Hinterland BG queue.");
        LOG_DEBUG("bg.battleground", "Player {} left HLBG queue", player->GetName());
    }
    else
    {
        ChatHandler(player->GetSession()).PSendSysMessage("You are not in the Hinterland BG queue.");
    }
}

bool OutdoorPvPHL::IsPlayerInQueue(Player* player)
{
    if (!player)
        return false;

    ObjectGuid playerGuid = player->GetGUID();
    
    return std::find_if(_queuedPlayers.begin(), _queuedPlayers.end(),
        [playerGuid](const QueueEntry& entry) {
            return entry.playerGuid == playerGuid;
        }) != _queuedPlayers.end();
}

uint32 OutdoorPvPHL::GetQueuedPlayerCount()
{
    return static_cast<uint32>(_queuedPlayers.size());
}

uint32 OutdoorPvPHL::GetQueuedPlayerCountByTeam(TeamId teamId)
{
    return static_cast<uint32>(std::count_if(_queuedPlayers.begin(), _queuedPlayers.end(),
        [teamId](const QueueEntry& entry) {
            return entry.teamId == teamId;
        }));
}

void OutdoorPvPHL::ShowQueueStatus(Player* player)
{
    if (!player)
        return;

    uint32 totalQueued = GetQueuedPlayerCount();
    uint32 allianceQueued = GetQueuedPlayerCountByTeam(TEAM_ALLIANCE);
    uint32 hordeQueued = GetQueuedPlayerCountByTeam(TEAM_HORDE);
    
    ChatHandler ch(player->GetSession());
    ch.PSendSysMessage("=== Hinterland BG Queue Status ===");
    ch.PSendSysMessage("Total players in queue: %u", totalQueued);
    ch.PSendSysMessage("Alliance: %u | Horde: %u", allianceQueued, hordeQueued);
    ch.PSendSysMessage("Minimum players to start: %u", _minPlayersToStart);
    
    if (IsPlayerInQueue(player))
    {
        // Find player's position in queue
        auto it = std::find_if(_queuedPlayers.begin(), _queuedPlayers.end(),
            [player](const QueueEntry& entry) {
                return entry.playerGuid == player->GetGUID();
            });
        
        if (it != _queuedPlayers.end())
        {
            uint32 position = static_cast<uint32>(std::distance(_queuedPlayers.begin(), it) + 1);
            // Use .count() to get an integral seconds value and compute wait time
            // against the stored uint32 joinTime.
            uint32 waitTime = static_cast<uint32>(GameTime::GetGameTime().count() - it->joinTime);
            ch.PSendSysMessage("Your position: %u | Wait time: %u seconds", position, waitTime);
        }
    }
    
    // Show battle state
    switch (_bgState)
    {
        case BG_STATE_WARMUP:
            ch.PSendSysMessage("Status: Warmup phase - Battle starting soon!");
            break;
        case BG_STATE_IN_PROGRESS:
            ch.PSendSysMessage("Status: Battle in progress");
            break;
        case BG_STATE_PAUSED:
            ch.PSendSysMessage("Status: Battle paused");
            break;
        case BG_STATE_FINISHED:
            ch.PSendSysMessage("Status: Battle finished");
            break;
        case BG_STATE_CLEANUP:
            ch.PSendSysMessage("Status: Waiting for players");
            break;
    }
}

void OutdoorPvPHL::ProcessQueueSystem()
{
    // Only process queue when we're in cleanup state
    if (_bgState != BG_STATE_CLEANUP)
        return;

    // Check if we have enough players to start warmup
    uint32 queuedPlayers = GetQueuedPlayerCount();
    
    if (queuedPlayers >= _minPlayersToStart)
    {
        // Start warmup phase and teleport queued players
        StartWarmupPhase();
    }
}

void OutdoorPvPHL::StartWarmupPhase()
{
    if (_bgState != BG_STATE_CLEANUP)
    {
        LOG_ERROR("bg.battleground", "HLBG: Attempted to start warmup phase from invalid state: {}", static_cast<uint32>(_bgState));
        return;
    }

    LOG_INFO("bg.battleground", "HLBG: Starting warmup phase with {} queued players", GetQueuedPlayerCount());
    
    // Teleport all queued players to the zone first
    TeleportQueuedPlayers();
    
    // Then transition to warmup state (this will initialize warmup timer and send notifications)
    TransitionToState(BG_STATE_WARMUP);
}

void OutdoorPvPHL::TeleportQueuedPlayers()
{
    uint32 teleportCount = 0;
    
    for (const QueueEntry& entry : _queuedPlayers)
    {
        Player* player = ObjectAccessor::FindConnectedPlayer(entry.playerGuid);
        if (!player)
            continue;

    // Choose spawn location based on team. Use the local HLBase struct declared
    // inside OutdoorPvPHL (map + x/y/z/o) rather than WorldLocation.
    const HLBase* spawnLoc = (entry.teamId == TEAM_ALLIANCE) ? &_baseAlliance : &_baseHorde;
        
        // Only teleport if player is not already in the zone
        if (player->GetZoneId() != OutdoorPvPHLBuffZones[0])
        {
            if (player->TeleportTo(spawnLoc->map, spawnLoc->x, spawnLoc->y, spawnLoc->z, spawnLoc->o))
            {
                teleportCount++;
                ChatHandler(player->GetSession()).PSendSysMessage("Welcome to Hinterland Battleground! Warmup phase: %u seconds remaining.", _warmupRemainingMs / IN_MILLISECONDS);
            }
        }
        else
        {
            // Player is already in zone, just send notification
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterland Battle warmup phase has started! %u seconds until battle begins.", _warmupRemainingMs / IN_MILLISECONDS);
        }
    }

    LOG_INFO("bg.battleground", "HLBG: Teleported {} players from queue to battleground", teleportCount);
}

void OutdoorPvPHL::ClearQueue()
{
    if (!_queuedPlayers.empty())
    {
        LOG_DEBUG("bg.battleground", "HLBG: Clearing queue with {} players", _queuedPlayers.size());
        _queuedPlayers.clear();
    }
}

void OutdoorPvPHL::OnPlayerDisconnected(Player* player)
{
    if (IsPlayerInQueue(player))
    {
        RemovePlayerFromQueue(player);
    }
}

// Group queue functionality
bool OutdoorPvPHL::AddGroupToQueue(Player* leader)
{
    if (!leader)
        return false;

    Group* group = leader->GetGroup();
    if (!group)
    {
        // Not in a group, add as individual
        AddPlayerToQueue(leader);
        return true;
    }

    // Check if leader is group leader
    if (group->GetLeaderGUID() != leader->GetGUID())
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("Only the group leader can add the group to queue.");
        return false;
    }

    // Check group size
    uint32 memberCount = group->GetMembersCount();
    if (memberCount > _maxGroupSize)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("Group is too large for Hinterland BG (max %u players).", _maxGroupSize);
        return false;
    }

    // Check if any member is already queued
    bool anyMemberQueued = false;
    group->DoForAllMembers([this, &anyMemberQueued](Player* member) {
        if (IsPlayerInQueue(member))
        {
            anyMemberQueued = true;
        }
    });

    if (anyMemberQueued)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("Some group members are already in the queue.");
        return false;
    }

    // Add all group members to queue
    uint32 addedCount = 0;
    group->DoForAllMembers([this, &addedCount](Player* member) {
        if (member->IsInWorld())
        {
            AddPlayerToQueue(member);
            addedCount++;
        }
    });

    ChatHandler(leader->GetSession()).PSendSysMessage("Added %u group members to Hinterland BG queue.", addedCount);
    return true;
}

bool OutdoorPvPHL::RemoveGroupFromQueue(Player* leader)
{
    if (!leader)
        return false;

    Group* group = leader->GetGroup();
    if (!group)
    {
        // Not in a group, remove individual
        RemovePlayerFromQueue(leader);
        return true;
    }

    // Check if leader is group leader
    if (group->GetLeaderGUID() != leader->GetGUID())
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("Only the group leader can remove the group from queue.");
        return false;
    }

    // Remove all group members from queue
    uint32 removedCount = 0;
    group->DoForAllMembers([this, &removedCount](Player* member) {
        if (IsPlayerInQueue(member))
        {
            RemovePlayerFromQueue(member);
            removedCount++;
        }
    });

    if (removedCount > 0)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("Removed %u group members from Hinterland BG queue.", removedCount);
    }
    else
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("No group members were in the queue.");
    }

    return true;
}