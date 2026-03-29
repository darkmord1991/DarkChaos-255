// -----------------------------------------------------------------------------
// hlbg_queue.cpp
// -----------------------------------------------------------------------------
// Queue system for Hinterland BG - allows players to register for the next
// battle and get automatically teleported when warmup phase starts.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "Player.h"
#include "Group.h"
#include "ObjectMgr.h"
#include "Chat.h"
#include "Language.h"
#include "ScriptMgr.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "hlbg_constants.h"
#include "../AddonExtension/dc_addon_hlbg.h"

#include <algorithm>

namespace
{
constexpr uint32 HLBG_QUEUE_JOIN_THROTTLE_SECONDS = 3;
}

void OutdoorPvPHL::RemoveQueueEntryAtIndex(size_t index)
{
    if (index >= _queuedPlayers.size())
        return;

    QueueEntry removed = _queuedPlayers[index];
    uint32 removedLow = removed.playerGuid.GetCounter();

    if (removed.teamId == TEAM_ALLIANCE && _queuedAllianceCount > 0)
        --_queuedAllianceCount;
    else if (removed.teamId == TEAM_HORDE && _queuedHordeCount > 0)
        --_queuedHordeCount;

    size_t lastIndex = _queuedPlayers.size() - 1;
    if (index != lastIndex)
    {
        QueueEntry moved = _queuedPlayers[lastIndex];
        _queuedPlayers[index] = moved;
        _queuedIndexByGuid[moved.playerGuid.GetCounter()] = index;
    }

    _queuedPlayers.pop_back();
    _queuedIndexByGuid.erase(removedLow);
}

// Player queue management
void OutdoorPvPHL::AddPlayerToQueue(Player* player)
{
    if (!player)
        return;

    // If warmup is already running, treat this as a late-join for the upcoming match:
    // teleport immediately to the faction base and don't persist them in the queue.
    if (_bgState == BG_STATE_WARMUP)
    {
        if (player->GetAreaId() != OutdoorPvPHLBattleAreaId)
        {
            TeleportToTeamBase(player);
        }
        uint32 warmupSec = static_cast<uint32>(_warmupTimeRemaining / IN_MILLISECONDS);
        ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cff00ccff[HLBG Queue]|r |cffffff00Warmup active.|r |cff98fb98You were moved to your base.|r |cffffff00Battle starts in|r |cffffffff{}|r |cffffff00seconds.|r", warmupSec);
        return;
    }

    ObjectGuid playerGuid = player->GetGUID();
    uint32 playerLow = playerGuid.GetCounter();
    uint32 nowSec = static_cast<uint32>(GameTime::GetGameTime().count());

    auto joinAttemptIt = _lastQueueJoinAttemptSec.find(playerLow);
    if (joinAttemptIt != _lastQueueJoinAttemptSec.end() && nowSec >= joinAttemptIt->second)
    {
        if (nowSec - joinAttemptIt->second < HLBG_QUEUE_JOIN_THROTTLE_SECONDS)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_02:16|t |cff00ccff[HLBG Queue]|r |cffff8080Please wait a few seconds before trying again.|r");
            return;
        }
    }
    _lastQueueJoinAttemptSec[playerLow] = nowSec;

    // Check if player is already in queue
    if (IsPlayerInQueue(player))
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cff00ccff[HLBG Queue]|r |cffffff00You are already in the queue.|r");
        SendQueueStatusAIO(player);
        DCAddon::HLBG::SendStatus(player, DCAddon::HLBG::STATUS_QUEUED, player->GetMapId(), GetTimeRemainingSeconds());
        return;
    }

    // Check if battle is in progress
    if (_bgState == BG_STATE_IN_PROGRESS)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_DualWield:16|t |cff00ccff[HLBG Queue]|r |cffff7f00Battle in progress.|r |cffffff00You are joining the queue for the next battle.|r");
    }

    // Add player to queue
    QueueEntry entry;
    entry.playerGuid = playerGuid;
    // GameTime::GetGameTime() returns a duration (Seconds). Store the
    // integral count into the uint32 joinTime field.
    entry.joinTime = nowSec;
    entry.teamId = player->GetTeamId();
    entry.active = true;

    _queuedPlayers.push_back(entry);
    _queuedIndexByGuid[playerLow] = _queuedPlayers.size() - 1;
    if (entry.teamId == TEAM_ALLIANCE)
        ++_queuedAllianceCount;
    else if (entry.teamId == TEAM_HORDE)
        ++_queuedHordeCount;

    // Announce queue join
    std::string playerName = player->GetName();
    uint32 queueSize = GetQueuedPlayerCount();

    ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cff00ccff[HLBG Queue]|r |cff98fb98Joined queue.|r |cffffff00Position:|r |cffffffff{}|r", queueSize);
    SendQueueStatusAIO(player);
    DCAddon::HLBG::SendStatus(player, DCAddon::HLBG::STATUS_QUEUED, player->GetMapId(), GetTimeRemainingSeconds());

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

    auto indexIt = _queuedIndexByGuid.find(playerGuid.GetCounter());
    if (indexIt != _queuedIndexByGuid.end())
    {
        RemoveQueueEntryAtIndex(indexIt->second);
        ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\Spell_Shadow_Teleport:16|t |cff00ccff[HLBG Queue]|r |cffff8080You left the queue.|r");
        SendQueueStatusAIO(player);
        DCAddon::HLBG::HLBGStatus statusAfterLeave = (player->GetZoneId() == OutdoorPvPHLBuffZones[0])
            ? DCAddon::HLBG::STATUS_ACTIVE
            : DCAddon::HLBG::STATUS_NONE;
        DCAddon::HLBG::SendStatus(player, statusAfterLeave, player->GetMapId(), GetTimeRemainingSeconds());
        LOG_DEBUG("bg.battleground", "Player {} left HLBG queue", player->GetName());
    }
    else
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_02:16|t |cff00ccff[HLBG Queue]|r |cffffff00You are not in the queue.|r");
        SendQueueStatusAIO(player);
        DCAddon::HLBG::HLBGStatus statusWhenNotQueued = (player->GetZoneId() == OutdoorPvPHLBuffZones[0])
            ? DCAddon::HLBG::STATUS_ACTIVE
            : DCAddon::HLBG::STATUS_NONE;
        DCAddon::HLBG::SendStatus(player, statusWhenNotQueued, player->GetMapId(), GetTimeRemainingSeconds());
    }
}

bool OutdoorPvPHL::IsPlayerInQueue(Player* player)
{
    if (!player)
        return false;

    return _queuedIndexByGuid.find(player->GetGUID().GetCounter()) != _queuedIndexByGuid.end();
}

uint32 OutdoorPvPHL::GetQueuedPlayerCount()
{
    return _queuedAllianceCount + _queuedHordeCount;
}

uint32 OutdoorPvPHL::GetQueuedPlayerCountByTeam(TeamId teamId)
{
    if (teamId == TEAM_ALLIANCE)
        return _queuedAllianceCount;
    if (teamId == TEAM_HORDE)
        return _queuedHordeCount;
    return 0u;
}

void OutdoorPvPHL::ShowQueueStatus(Player* player)
{
    if (!player)
        return;

    uint32 totalQueued = GetQueuedPlayerCount();
    uint32 allianceQueued = GetQueuedPlayerCountByTeam(TEAM_ALLIANCE);
    uint32 hordeQueued = GetQueuedPlayerCountByTeam(TEAM_HORDE);

    ChatHandler ch(player->GetSession());
    ch.PSendSysMessage("|TInterface\\Icons\\INV_Misc_Map_01:16|t |cff00ccff=== HLBG Queue Status ===|r");
    ch.PSendSysMessage("|cffffff00Total queued:|r |cffffffff{}|r", totalQueued);
    ch.PSendSysMessage("|cff1e90ffAlliance|r: |cffffffff{}|r |cffffff00| |r |cffff2020Horde|r: |cffffffff{}|r", allianceQueued, hordeQueued);
    ch.PSendSysMessage("|cffffff00Minimum to start:|r |cffffffff{}|r", _minPlayersToStart);

    if (IsPlayerInQueue(player))
    {
        auto indexIt = _queuedIndexByGuid.find(player->GetGUID().GetCounter());
        if (indexIt != _queuedIndexByGuid.end())
        {
            size_t index = indexIt->second;
            uint32 position = 0;
            for (size_t i = 0; i <= index && i < _queuedPlayers.size(); ++i)
            {
                if (_queuedPlayers[i].active)
                    ++position;
            }

            QueueEntry const& entry = _queuedPlayers[index];
            uint32 waitTime = static_cast<uint32>(GameTime::GetGameTime().count() - entry.joinTime);
            ch.PSendSysMessage("|cffffff00Your position:|r |cffffffff{}|r |cffffff00Wait time:|r |cffffffff{}s|r", position, waitTime);
        }
    }

    // Show battle state
    switch (_bgState)
    {
        case BG_STATE_WARMUP:
            ch.PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:14|t |cffffff00Status:|r |cffffd700Warmup phase - battle starting soon!|r");
            break;
        case BG_STATE_IN_PROGRESS:
            ch.PSendSysMessage("|TInterface\\Icons\\Ability_DualWield:14|t |cffffff00Status:|r |cffff7f00Battle in progress|r");
            break;
        case BG_STATE_PAUSED:
            ch.PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_02:14|t |cffffff00Status:|r |cffff8080Battle paused|r");
            break;
        case BG_STATE_FINISHED:
            ch.PSendSysMessage("|TInterface\\Icons\\Achievement_BG_winAB:14|t |cffffff00Status:|r |cff98fb98Battle finished|r");
            break;
        case BG_STATE_CLEANUP:
            ch.PSendSysMessage("|TInterface\\Icons\\INV_Misc_GroupLooking:14|t |cffffff00Status:|r |cff98fb98Waiting for players|r");
            break;
    }

    SendQueueStatusAIO(player);
    DCAddon::HLBG::HLBGStatus snapshotStatus = IsPlayerInQueue(player)
        ? DCAddon::HLBG::STATUS_QUEUED
        : (player->GetZoneId() == OutdoorPvPHLBuffZones[0] ? DCAddon::HLBG::STATUS_ACTIVE : DCAddon::HLBG::STATUS_NONE);
    DCAddon::HLBG::SendStatus(player, snapshotStatus, player->GetMapId(), GetTimeRemainingSeconds());
}

void OutdoorPvPHL::ProcessQueueSystem()
{
    // Only process queue when we're in cleanup state
    if (_bgState != BG_STATE_CLEANUP)
        return;

    // Queue can be disabled by config/admin; if so, do not auto-start warmup from queue.
    if (!_queueEnabled)
        return;

    // Prune stale/offline entries so we don't start warmup for disconnected players.
    for (size_t i = 0; i < _queuedPlayers.size();)
    {
        QueueEntry const& entry = _queuedPlayers[i];
        if (ObjectAccessor::FindConnectedPlayer(entry.playerGuid))
        {
            ++i;
            continue;
        }

        RemoveQueueEntryAtIndex(i);
    }

    // Check if we have enough players to start warmup
    uint32 queuedPlayers = GetQueuedPlayerCount();
    uint32 requiredPlayers = std::max<uint32>(_minPlayersToStart, 1u);

    if (queuedPlayers >= requiredPlayers)
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

    if (!_queueEnabled)
        return;

    // Re-prune offline entries right before starting, and require at least one connected player.
    for (size_t i = 0; i < _queuedPlayers.size();)
    {
        QueueEntry const& entry = _queuedPlayers[i];
        if (ObjectAccessor::FindConnectedPlayer(entry.playerGuid))
        {
            ++i;
            continue;
        }

        RemoveQueueEntryAtIndex(i);
    }

    if (GetQueuedPlayerCount() == 0)
        return;

    uint32 requiredPlayers = std::max<uint32>(_minPlayersToStart, 1u);
    if (GetQueuedPlayerCount() < requiredPlayers)
        return;

    LOG_INFO("bg.battleground", "HLBG: Starting warmup phase with {} queued players", GetQueuedPlayerCount());
    // Transition first so warmup timer & announcements are initialized before players arrive.
    // This prevents a zero/old _warmupTimeRemaining value being shown in the teleport welcome message.
    TransitionToState(BG_STATE_WARMUP);

    // Teleporting + queue consumption happens in EnterWarmupState().
}

void OutdoorPvPHL::TeleportQueuedPlayers()
{
    uint32 teleportCount = 0;

    for (const QueueEntry& entry : _queuedPlayers)
    {
        if (!entry.active)
            continue;

        Player* player = ObjectAccessor::FindConnectedPlayer(entry.playerGuid);
        if (!player)
            continue;

    // Choose spawn location based on team. Use the local HLBase struct declared
    // inside OutdoorPvPHL (map + x/y/z/o) rather than WorldLocation.
    const HLBase* spawnLoc = (entry.teamId == TEAM_ALLIANCE) ? &_baseAlliance : &_baseHorde;

        // Only teleport if player is not already in the zone
        if (player->GetAreaId() != OutdoorPvPHLBattleAreaId)
        {
            if (player->TeleportTo(spawnLoc->map, spawnLoc->x, spawnLoc->y, spawnLoc->z, spawnLoc->o))
            {
                teleportCount++;
                // _warmupTimeRemaining is stored in milliseconds. Convert to seconds for messaging.
                uint32 warmupSec = static_cast<uint32>(_warmupTimeRemaining / IN_MILLISECONDS);
                ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cff00ccff[HLBG Queue]|r |cff98fb98Welcome to Hinterland Battleground!|r |cffffff00Warmup remaining:|r |cffffffff{}s|r", warmupSec);
            }
        }
        else
        {
            // Player is already in zone, just send notification
            uint32 warmupSec = static_cast<uint32>(_warmupTimeRemaining / IN_MILLISECONDS);
            ChatHandler(player->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cff00ccff[HLBG Queue]|r |cffffd700Warmup started!|r |cffffff00Battle begins in|r |cffffffff{}s|r", warmupSec);
        }
    }

    LOG_INFO("bg.battleground", "HLBG: Teleported {} players from queue to battleground", teleportCount);
}

void OutdoorPvPHL::ClearQueue()
{
    if (!_queuedPlayers.empty())
    {
        LOG_DEBUG("bg.battleground", "HLBG: Clearing queue with {} players", GetQueuedPlayerCount());
        _queuedPlayers.clear();
        _queuedIndexByGuid.clear();
        _lastQueueJoinAttemptSec.clear();
        _queuedAllianceCount = 0;
        _queuedHordeCount = 0;
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
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_Warrior_RallyingCry:16|t |cff00ccff[HLBG Queue]|r |cffff8080Only the group leader can add the group to queue.|r");
        return false;
    }

    // Check group size
    uint32 memberCount = group->GetMembersCount();
    if (memberCount > _maxGroupSize)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_Creature_Cursed_02:16|t |cff00ccff[HLBG Queue]|r |cffff8080Group is too large|r |cffffff00(max|r |cffffffff{}|r |cffffff00players).|r", _maxGroupSize);
        return false;
    }

    // Validate member eligibility (same policy as individual queue join)
    bool hasIneligibleMember = false;
    std::string ineligibleReason;
    group->DoForAllMembers([this, &hasIneligibleMember, &ineligibleReason](Player* member)
    {
        if (hasIneligibleMember)
            return;
        if (!member || !member->IsInWorld())
            return;

        if (!IsMaxLevel(member))
        {
            hasIneligibleMember = true;
            ineligibleReason = "at least one member is below minimum level";
            return;
        }
        if (member->HasAura(HinterlandBGConstants::BG_DESERTER_SPELL))
        {
            hasIneligibleMember = true;
            ineligibleReason = "at least one member has deserter";
            return;
        }
        if (!member->IsAlive())
        {
            hasIneligibleMember = true;
            ineligibleReason = "at least one member is dead";
            return;
        }
        if (member->IsInCombat())
        {
            hasIneligibleMember = true;
            ineligibleReason = "at least one member is in combat";
            return;
        }
    });

    if (hasIneligibleMember)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_Creature_Cursed_02:16|t |cff00ccff[HLBG Queue]|r |cffff8080Cannot queue group: {}.|r", ineligibleReason);
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
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_02:16|t |cff00ccff[HLBG Queue]|r |cffffff00Some group members are already in the queue.|r");
        return false;
    }

    // Add all group members to queue
    uint32 addedCount = 0;
    group->DoForAllMembers([this, &addedCount](Player* member) {
        if (member->IsInWorld())
        {
            bool wasQueued = IsPlayerInQueue(member);
            AddPlayerToQueue(member);
            if (!wasQueued && IsPlayerInQueue(member))
                addedCount++;
        }
    });

    ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_Warrior_RallyingCry:16|t |cff00ccff[HLBG Queue]|r |cff98fb98Added|r |cffffffff{}|r |cff98fb98group members to queue.|r", addedCount);
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
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Ability_Warrior_RallyingCry:16|t |cff00ccff[HLBG Queue]|r |cffff8080Only the group leader can remove the group from queue.|r");
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
    ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\Spell_Shadow_Teleport:16|t |cff00ccff[HLBG Queue]|r |cffff8080Removed|r |cffffffff{}|r |cffff8080group members from queue.|r", removedCount);
    }
    else
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("|TInterface\\Icons\\INV_Misc_PocketWatch_02:16|t |cff00ccff[HLBG Queue]|r |cffffff00No group members were in the queue.|r");
    }

    return true;
}

// ============================================================================
// AIO Integration for Queue and Config Info
// ============================================================================

// Send queue status to client via AIO (for HLBG addon Queue tab)
// Send queue status to client via DC Addon Protocol
void OutdoorPvPHL::SendQueueStatusAIO(Player* player)
{
    if (!player)
        return;

    // Use the optimized binary protocol
    DCAddon::HLBG::SendQueueInfo(player);
}

// Send server config info to client via AIO (for HLBG addon Info tab)
void OutdoorPvPHL::SendConfigInfoAIO(Player* player)
{
    if (!player)
        return;

#ifdef HAS_AIO
    std::ostringstream oss;
    oss << "CONFIG_INFO|";
    oss << "MATCH_DURATION=" << _matchDurationSeconds << "|";
    oss << "WARMUP_DURATION=" << _warmupDurationSeconds << "|";
    oss << "MIN_LEVEL=" << _minLevel << "|";
    oss << "RESOURCES_ALLIANCE=" << _initialResourcesAlliance << "|";
    oss << "RESOURCES_HORDE=" << _initialResourcesHorde << "|";
    oss << "SEASON=" << _season << "|";
    oss << "MIN_PLAYERS=" << _minPlayersToStart << "|";
    oss << "MAX_GROUP_SIZE=" << _maxGroupSize << "|";
    oss << "REWARD_HONOR=" << _rewardMatchHonor << "|";
    oss << "REWARD_HONOR_DEPLETION=" << _rewardMatchHonorDepletion << "|";
    oss << "REWARD_HONOR_TIEBREAKER=" << _rewardMatchHonorTiebreaker << "|";
    oss << "AFFIX_ENABLED=" << (_affixEnabled ? "1" : "0") << "|";
    oss << "AFFIX_CURRENT=" << static_cast<uint32>(_activeAffix);

    // Send via AIO
    AIO().Msg(player, "HLBG", "ConfigInfo", oss.str());

    LOG_DEBUG("hlbg.aio", "Sent config info to {}", player->GetName());
#else
    // Fallback to chat message
    ChatHandler ch(player->GetSession());
    ch.PSendSysMessage("=== Hinterland BG Configuration ===");
    ch.PSendSysMessage("Match Duration: {} seconds ({} min)", _matchDurationSeconds, _matchDurationSeconds / 60);
    ch.PSendSysMessage("Minimum Level: {}", _minLevel);
    ch.PSendSysMessage("Initial Resources: Alliance {} | Horde {}", _initialResourcesAlliance, _initialResourcesHorde);
    ch.PSendSysMessage("Season: {}", _season);
    ch.PSendSysMessage("Affixes: {}", _affixEnabled ? "Enabled" : "Disabled");
#endif
}
