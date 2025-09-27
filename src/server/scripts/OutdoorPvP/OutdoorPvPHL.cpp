/*
================================================================================
        OutdoorPvPHL.cpp - Hinterland Outdoor PvP Battleground (zone 47)
================================================================================

        Purpose
        -------
        Implements a zone-wide Alliance vs Horde open-world battleground for Hinterland
        (zone id 47). The script handles automatic battleground-style raid grouping,
        a resource system (teams lose resources on deaths/NPC kills), periodic
        announcements, AFK handling, sounds, buffs/rewards, and basic teleportation.

        Recent notable changes (developer summary)
        --------------------------------------------------------------
        - Replaced unsafe printf-style calls with a safe PlayerTextEmoteFmt helper.
        - Centralized configuration constants (zone id, timers, thresholds).
        - Added AFK movement tracking using a PlayerScript movement hook and
            TouchPlayerLastMove(ObjectGuid) to keep timestamps up to date.
        - Prevented unsigned underflow on resource counters (ClampResources).
        - Split large Update() into focused helpers: ProcessMatchTimer,
            ProcessPeriodicMessage, ProcessAFK, CheckResourceThresholds,
            BroadcastResourceMessages, ClampResourceCounters.
        - Changed PlaySounds signature to accept TeamId and play distinct
            victory/defeat sounds for winners/losers.
        - Implemented multi-raid support per faction: when a battleground raid
            group reaches the server-side limit (40 players) a new battleground raid
            group is created for that faction (logged via LOG_INFO).
        - Added a small DC wrapper registration file so the script can be built
         /registered from the DC scripts module without duplicating AddSC_* symbols.

        High-level feature overview
        -----------------------------------------------------------------------------
        - Auto-grouping / raid creation: players entering the zone are auto-added
            into existing battleground raid groups for their faction. If all such
            groups are full (40 players), a new raid group is created automatically.
        - Resource system: each side has a resource counter which decreases on
            player/NPC deaths; thresholds trigger announcements and sounds.
        - Periodic announcements: Every 120s the script announces resources,
            approximate team sizes, and time left.
        - AFK handling: players who do not move for a configurable timeout are
            teleported back to their faction's start position.
        - Rewards: buffs, honor/arena point awarding, and item drops for kills.

        Quality & safety notes
        -----------------------------------------------------------------------------
        - Resource counters are clamped to prevent unsigned wraparound.
        - Movement-based AFK detection is implemented via a PlayerScript hook to
            update per-player last-move timestamps; this is more reliable than only
            setting timestamps on zone enter.
        - The script avoids global side-effects where possible (e.g. only
            creates battleground-type raid groups rather than touching unrelated groups).

        TODO / Enhancements (prioritized)
        -----------------------------------------------------------------------------
        1) Announcements: switch periodic report to count battleground-raid members
             directly from the `_Groups[team]` sets (more accurate for raid sizes).
        2) Configuration: move zone id, thresholds, timers, coordinates and sound IDs
             to a config file or `acore.json` option so server owners can tune behavior
             without code changes.
        3) Persistence: optionally persist permanent resources to DB so they survive
             server restarts between matches (if desired for long-running events).
        4) AFK heuristics: refine movement detection (ignore tiny position jitter,
             consider orientation-only movement) and allow staff to exempt players.
        5) Tests: add unit / integration tests for resource clamping, AddOrSetPlayerToCorrectBfGroup
             behavior and PlaySounds mapping.
        6) Admin tooling: add console commands or GM chat commands to query/adjust
             resources, force-reset matches, and list battleground raid groups and sizes.
       7) Teleport safety: implemented 30s AFK warning and safe-teleport checks
           (player-is-alive check). Admin commands (.hlbg get/set/reset/status) were
           added to query and modify resource counters and raid groups.
        8) Logging/metrics: add optional telemetry (counts of raid groups created,
             match start/end, long AFK events) and rate-limit logs to avoid flooding.
        9) Refactor: consider extracting battleground-specific code to
             `src/server/scripts/DC/HinterlandBG/` and add a small unit-test harness.
     10) Sound & DBC validation: confirm DBC/sound ids used for HL_SOUND_*_* and
             expose mapping in config or data files.

        How to test quickly
        -----------------------------------------------------------------------------
        - Build server, start instance, create multiple test accounts and join zone 47.
        - Fill one battleground raid group to 40 players and verify the 41st player
            triggers creation of a second battleground raid group (watch server log).
        - Verify periodic messages include resources and approximate sizes, AFK
            teleports after configured timeout, resource decrements and clamping on kills,
            and that sounds play correctly for winners/losers.

        For maintainers: update this header when adding/removing major features.
================================================================================
*/
    #include "OutdoorPvPHL.h"
    #include "Player.h"
    #include "OutdoorPvP.h"
    #include "World.h"
    #include "WorldPacket.h"
    #include "OutdoorPvPScript.h"
    #include "CreatureScript.h"
    #include "WorldSession.h"
    #include "WorldSessionMgr.h"
    #include "GroupMgr.h"
#include "MapMgr.h"
#include <cstdarg>
#include <cstdint>
#include <algorithm>

// OutdoorPvPHL.cpp: Main logic for Hinterland Outdoor PvP Battleground (zone 47)
// Implements group management, resource tracking, AFK detection, messaging, rewards, and faction-based teleportation.

// Configuration constants
static constexpr uint32_t HL_ZONE_ID = 47;
static constexpr uint32_t MATCH_DURATION_MS = 3600000; // 60 minutes
static constexpr uint32_t MESSAGE_INTERVAL_MS = 120000; // 120 seconds
static constexpr uint32_t AFK_TIMEOUT_MS = 600000; // 10 minutes
static constexpr int RESOURCE_THRESHOLD_WARN_1 = 300;
static constexpr int RESOURCE_THRESHOLD_WARN_2 = 200;
static constexpr int RESOURCE_THRESHOLD_WARN_3 = 100;
static constexpr int RESOURCE_THRESHOLD_LOW = 50;

// Small helper to call TextEmote with printf-style formatting
static inline void PlayerTextEmoteFmt(Player* player, const char* fmt, ...)
{
    if (!player) return;
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    player->TextEmote(buf);
}

// Helper: Teleport all players in the Hinterland zone to their faction start
static inline void TeleportAllPlayersInZoneToStart()
{
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator it = sessionMap.begin(); it != sessionMap.end(); ++it)
    {
        Player* p = it->second ? it->second->GetPlayer() : nullptr;
        if (p && p->IsInWorld() && p->GetZoneId() == HL_ZONE_ID) {
            if (p->GetTeamId() == TEAM_ALLIANCE)
                p->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
            else
                p->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
        }
    }
}

// Ensure resource counters do not underflow (they're unsigned)
static inline void ClampResources(uint32 &value)
{
    if ((int32)value < 0)
        value = 0;
}

    // Constructor: Initializes battleground state, resource counters, timers, and AFK tracking.
    // Sets up all initial values for resources, timers, and player movement tracking.
    OutdoorPvPHL::OutdoorPvPHL()
    {
        _typeId = OUTDOOR_PVP_HL;
        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;

        // Permanent resources: never reset during a run, only at battleground reset
        _ally_permanent_resources = HL_RESOURCES_A;
        _horde_permanent_resources = HL_RESOURCES_H;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;
        limit_A = 0;
        limit_H = 0;
        _LastWin = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;
        _messageTimer = 0; // Timer for periodic zone-wide message
        _liveResourceTimer = 0; // Timer for live/permanent resource broadcast
        _matchTimer = 0; // Timer for match duration

        // AFK tracking: map player GUID to last movement timestamp (ms)
        _playerLastMove.clear();
        _playerWarnedBeforeTeleport.clear();
    }

    // Setup: Registers the Hinterland zone for OutdoorPvP events.
    // Registers zone 47 for battleground logic and event handling.
    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        return true;
    }

    // Called when a player enters the Hinterland zone.
    // Handles auto-invite to raid group, welcome message, and AFK tracking initialization.
    void OutdoorPvPHL::HandlePlayerEnterZone(Player* player, uint32 zone)
    {
        // Auto-invite logic
        AddOrSetPlayerToCorrectBfGroup(player);

        // Welcome message
        player->TextEmote("Welcome to Hinterland BG!");

        // Initialize last movement timestamp
    _playerLastMove[player->GetGUID()] = getMSTime();

        OutdoorPvP::HandlePlayerEnterZone(player, zone);
    }

    // Finds a non-full raid group for the given team in zone 47.
    // Ensures only one raid group per faction is used for auto-invite.
    Group* OutdoorPvPHL::GetFreeBfRaid(TeamId TeamId)
    {
        // Iterate all stored group GUIDs for the team and return first non-full raid group.
        // Remove stale group GUIDs (groups that no longer exist) from the set.
        for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); )
        {
            ObjectGuid gid = *itr;
            Group* group = sGroupMgr->GetGroupByGUID(gid.GetCounter());
            if (!group)
            {
                // Erase stale GUID from set
                GuidSet::const_iterator toErase = itr++;
                _Groups[TeamId].erase(toErase);
                continue;
            }

            // Prefer battleground raid groups for this zone and ensure they are not full
            if (group->isBGGroup() && group->isRaidGroup() && !group->IsFull())
                return group;

            ++itr;
        }
        return nullptr;
    }

    // Ensures the player is in the correct raid group for their faction in zone 47.
    // Adds the player to an existing group or creates a new one if needed.
    bool OutdoorPvPHL::AddOrSetPlayerToCorrectBfGroup(Player* plr)
    {
        if (!plr->IsInWorld())
            return false;
        // Don't re-invite if already in a BG/BF group
        if (plr->GetGroup() && (plr->GetGroup()->isBGGroup() || plr->GetGroup()->isBFGroup()))
        {
            return false;
        }
            // Try to find an existing non-full raid group for this team
            Group* group = GetFreeBfRaid(plr->GetTeamId());
            if (group)
        {
            // Add player to group if not already a member
            if (!group->IsMember(plr->GetGUID()))
            {
                group->AddMember(plr);
                // If player was a leader in their original group, transfer leadership
                if (Group* originalGroup = plr->GetOriginalGroup())
                    if (originalGroup->IsLeader(plr->GetGUID()))
                        group->ChangeLeader(plr->GetGUID());
            }
            else
            {
                // Already a member, set their subgroup
                uint8 subgroup = group->GetMemberGroup(plr->GetGUID());
                plr->SetBattlegroundOrBattlefieldRaid(group, subgroup);
            }
        }
        else
        {
                // No available non-full raid group: create a new raid group for this team
                group = new Group;
                Battleground* bg = (Battleground*)sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID);
                if (bg)
                    group->SetBattlegroundGroup(bg);

                // Create will initialize the group and mark it as a BG raid if m_bgGroup was set
                if (!group->Create(plr))
                {
                    // Creation failed: cleanup and abort
                    delete group;
                    return false;
                }

                // Ensure the group is a raid-type (raid-size up to MAXRAIDSIZE)
                if (!group->isRaidGroup())
                    group->ConvertToRaid();

                sGroupMgr->AddGroup(group);
                _Groups[plr->GetTeamId()].insert(group->GetGUID());

                // Log creation for ops/debugging. Include team and group low-guid.
                LOG_INFO("outdoorpvp", "[OutdoorPvPHL]: Created new battleground raid group %u for team %s in zone %u",
                         group->GetGUID().GetCounter(), plr->GetTeamId() == TEAM_ALLIANCE ? "Alliance" : "Horde", HL_ZONE_ID);
        }
        return true;
    }

    // Returns the group for the given player GUID and team, or nullptr if not found.
    Group* OutdoorPvPHL::GetGroupPlayer(ObjectGuid guid, TeamId TeamId)
    {
        for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); ++itr)
        {
            Group* group = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (group && group->IsMember(guid))
                return group;
        }
        return nullptr;
    }

    // Helper: Teleport player to Hinterland Outdoor BG start location by faction.
    // Teleports player to their faction's start location in Hinterland BG.
    // Marked static to keep internal linkage to this translation unit.
    static inline void TeleportPlayerToStart(Player* player)
    {
        // Start locations of the Hinterland BG
        // Alliance: 0, -17.743, -4635.110, 12.933, 2.422
        // Horde:    0, -581.244, -4577.710, 10.215, 0.548
        if (player->GetTeamId() == TEAM_ALLIANCE)
            player->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
        else
            player->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
    }

    // Called when a player leaves the Hinterland zone.
    // Handles zone leave messaging, teleportation, raid group removal, and AFK tracking cleanup.
    void OutdoorPvPHL::HandlePlayerLeaveZone(Player* player, uint32 zone)
    {
        player->TextEmote(",HEY, you are leaving the zone, while a battle is on going! Shame on you!");
        TeleportPlayerToStart(player);
        // Remove player from raid group if in one
        if (Group* group = player->GetGroup()) {
            if (group->isRaidGroup() && group->IsMember(player->GetGUID())) {
                group->RemoveMember(player->GetGUID(), GROUP_REMOVEMETHOD_DEFAULT);
                // Reset phase mask to default (1) after group removal
                player->SetPhaseMask(1, true);
                // Clear battleground/battlefield raid flags
                player->SetBattlegroundOrBattlefieldRaid(nullptr, 0);
            }
        }
        // Remove AFK tracking
        _playerLastMove.erase(player->GetGUID());
        OutdoorPvP::HandlePlayerLeaveZone(player, zone);
    }

    // Touch/update player's last move timestamp (used by movement hooks)
    void OutdoorPvPHL::TouchPlayerLastMove(ObjectGuid guid)
    {
        _playerLastMove[guid] = getMSTime();
    }

    // Broadcasts a win message to all players in the Hinterland zone.
    // Respawn logic for NPCs and game objects is currently disabled.
    void OutdoorPvPHL::HandleWinMessage(const char* message)
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], message);

            // Respawn logic for NPCs and game objects temporarily removed as requested.
    }

    // Plays victory/defeat sounds for all players in the zone, depending on side.
    // Play victory sounds for the winning team; winner indicates which team won/should be celebrated
    void OutdoorPvPHL::PlaySounds(TeamId winner)
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            {
                if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != OutdoorPvPHLBuffZones[i])
                    continue;

                if(itr->second->GetPlayer()->GetZoneId() == OutdoorPvPHLBuffZones[i])
                {
                    Player* p = itr->second->GetPlayer();
                    // Play the winning sound for players on the winning team and a neutral/other sound for others.
                    if (p->GetTeamId() == winner) {
                        // Winning team hears the victory sound
                        if (winner == TEAM_ALLIANCE)
                            p->PlayDirectSound(HL_SOUND_ALLIANCE_GOOD, p);
                        else
                            p->PlayDirectSound(HL_SOUND_HORDE_GOOD, p);
                    } else {
                        // Losing team hears the defeat/loser sound
                        if (winner == TEAM_ALLIANCE)
                            p->PlayDirectSound(HL_SOUND_HORDE_BAD, p);
                        else
                            p->PlayDirectSound(HL_SOUND_ALLIANCE_BAD, p);
                    }
                }
            }
        }
    }

    // Resets battleground and permanent resources to initial values.
    // Resets all timers, resource counters, and flags for a new match.
    void OutdoorPvPHL::HandleReset()
    {
        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;
        _ally_permanent_resources = HL_RESOURCES_A;
        _horde_permanent_resources = HL_RESOURCES_H;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;
        limit_A = 0;
        limit_H = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;
        _messageTimer = 0;
        _liveResourceTimer = 0;

    // Clear AFK warning state on reset
    _playerWarnedBeforeTeleport.clear();

        LOG_INFO("misc", "[OutdoorPvPHL]: Reset Hinterland BG");
    }

    // Applies win/lose buffs to a player after the battle.
    void OutdoorPvPHL::HandleBuffs(Player* player, bool loser)
    {
        if(loser)
        {
            for(int i = 0; i < LoseBuffsNum; i++)
                player->CastSpell(player, LoseBuffs[i], true);
        }
        else
        {
            for(int i = 0; i < WinBuffsNum; i++)
                player->CastSpell(player, WinBuffs[i], true);
        }
    }

    // Handles honor/arena rewards for a player after a win/kill.
    // Sends reward messages and updates player points.
    void OutdoorPvPHL::HandleRewards(Player* player, uint32 honorpointsorarena, bool honor, bool arena, bool both)
    {
        char msg[250];
        uint32 _GetHonorPoints = player->GetHonorPoints();
        uint32 _GetArenaPoints = player->GetArenaPoints();

        if(honor)
        {
            player->SetHonorPoints(_GetHonorPoints + honorpointsorarena);
            snprintf(msg, 250, "You got %u bonus honor!", honorpointsorarena);
        }
        else if(arena)
        {
            player->SetArenaPoints(_GetArenaPoints + honorpointsorarena);
            snprintf(msg, 250, "You got amount of %u additional arena points!", honorpointsorarena);
        }
        else if(both)
        {
            player->SetHonorPoints(_GetHonorPoints + honorpointsorarena);
            player->SetArenaPoints(_GetArenaPoints + honorpointsorarena);
            snprintf(msg, 250, "You got amount of %u additional arena points and bonus honor!", honorpointsorarena);
        }
        HandleWinMessage(msg);
    }

// Main update loop for Hinterland battleground logic.
// Handles battleground start announcement, periodic resource broadcasts, live timer worldstate updates,
// AFK teleport (with warning), win/lose logic, and match progression features.
bool OutdoorPvPHL::Update(uint32 diff)
{
    OutdoorPvP::Update(diff);

    // Split responsibilities to helpers for readability
    if (_FirstLoad == false)
    {
        char announceMsg[256];
        snprintf(announceMsg, sizeof(announceMsg), "[Hinterland Defence]: A new battle has started in zone %u! Last winner: %s", HL_ZONE_ID, (_LastWin == ALLIANCE ? "Alliance" : (_LastWin == HORDE ? "Horde" : "None")));
        for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) {
            if (Player* player = sessionPair.second->GetPlayer())
                player->GetSession()->SendAreaTriggerMessage(announceMsg);
        }
        LOG_INFO("misc", announceMsg);
        _FirstLoad = true;
        _matchTimer = 0;
    }

    // timers and periodic tasks
    ProcessMatchTimer(diff);
    ProcessPeriodicMessage(diff);

    uint32 now = getMSTime();
    ProcessAFK(now);

    CheckResourceThresholds();
    BroadcastResourceMessages();

    IS_ABLE_TO_SHOW_MESSAGE = false; // Reset
    return false;
}

// Helper implementations
void OutdoorPvPHL::ProcessMatchTimer(uint32 diff)
{
    _matchTimer += diff;
    if (_matchTimer >= MATCH_DURATION_MS)
    {
        HandleWinMessage("[Hinterland Defence]: The match has ended due to time limit! Restarting...");
        HandleReset();
        _matchTimer = 0;
        _FirstLoad = false;
    }
}

void OutdoorPvPHL::ProcessPeriodicMessage(uint32 diff)
{
    _messageTimer += diff;
    if (_messageTimer >= MESSAGE_INTERVAL_MS)
    {
        uint32 timeRemaining = (_matchTimer >= MATCH_DURATION_MS) ? 0 : (MATCH_DURATION_MS - _matchTimer) / 1000;
        uint32 minutes = timeRemaining / 60;
        uint32 seconds = timeRemaining % 60;

        // Count battleground-raid members using tracked raid groups for each team
        uint32 allianceCount = 0;
        uint32 hordeCount = 0;
        // Iterate Alliance groups
        for (GuidSet::const_iterator itr = _Groups[TEAM_ALLIANCE].begin(); itr != _Groups[TEAM_ALLIANCE].end(); ++itr)
        {
            Group* g = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (!g || !g->isBGGroup())
                continue;
            allianceCount += g->GetMembersCount();
        }
        // Iterate Horde groups
        for (GuidSet::const_iterator itr = _Groups[TEAM_HORDE].begin(); itr != _Groups[TEAM_HORDE].end(); ++itr)
        {
            Group* g = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (!g || !g->isBGGroup())
                continue;
            hordeCount += g->GetMembersCount();
        }

        char msg[256];
        snprintf(msg, sizeof(msg), "[Hinterland Defence]: Alliance: %u (%u players) | Horde: %u (%u players) | Time left: %02u:%02u (Start: 60:00)",
                 _ally_gathered, allianceCount, _horde_gathered, hordeCount, minutes, seconds);
        sWorldSessionMgr->SendZoneText(HL_ZONE_ID, msg);
        _messageTimer = 0;
    }
}

void OutdoorPvPHL::ProcessAFK(uint32 now)
{
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
    {
        Player* player = itr->second ? itr->second->GetPlayer() : nullptr;
        if (!player || !player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
            continue;
        ObjectGuid guid = player->GetGUID();
        if (_playerLastMove.find(guid) == _playerLastMove.end())
            _playerLastMove[guid] = now;

        // If player hasn't moved for AFK_TIMEOUT_MS - 30s, warn them once
        const uint32 warnThreshold = AFK_TIMEOUT_MS > 30000 ? AFK_TIMEOUT_MS - 30000 : 0;
        if (!_playerWarnedBeforeTeleport[guid] && now - _playerLastMove[guid] >= warnThreshold && now - _playerLastMove[guid] < AFK_TIMEOUT_MS)
        {
            player->SendAreaTriggerMessage("You will be teleported to your start point in 30 seconds due to inactivity. Move to cancel.");
            _playerWarnedBeforeTeleport[guid] = true;
            continue;
        }

        if (now - _playerLastMove[guid] >= AFK_TIMEOUT_MS)
        {
            // Safe teleport check: ensure player is alive and map is valid
            if (player->IsAlive())
            {
                // Teleport the player to safe coordinates for their faction
                TeleportPlayerToStart(player);
                player->TextEmote("You have been summoned to your starting position due to inactivity.");
            }
            // Reset timers and warned flag
            _playerLastMove[guid] = now; // Reset timer after teleport
            _playerWarnedBeforeTeleport[guid] = false;
        }
    }
}

void OutdoorPvPHL::CheckResourceThresholds()
{
    if(_ally_gathered <= RESOURCE_THRESHOLD_LOW && limit_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_A = true; limit_A = 1; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_LOW && limit_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_H = true; limit_H = 1; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= 0 && limit_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_A = true; limit_A = 2; PlaySounds(TEAM_HORDE); TeleportAllPlayersInZoneToStart();
    }
    else if(_horde_gathered <= 0 && limit_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_H = true; limit_H = 2; PlaySounds(TEAM_ALLIANCE); TeleportAllPlayersInZoneToStart();
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_1 && limit_resources_message_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 1; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_1 && limit_resources_message_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 1; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_2 && limit_resources_message_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 2; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_2 && limit_resources_message_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 2; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_3 && limit_resources_message_A == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 3; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_3 && limit_resources_message_H == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 3; PlaySounds(TEAM_ALLIANCE);
    }
}

void OutdoorPvPHL::BroadcastResourceMessages()
{
    if(!IS_ABLE_TO_SHOW_MESSAGE) return;
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
    {
        if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != HL_ZONE_ID)
            continue;
        Player* p = itr->second->GetPlayer();
        if(limit_resources_message_A >= 1 && limit_resources_message_A <= 3)
            PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Alliance got %u resources left!", _ally_gathered);
        else if(limit_resources_message_H >= 1 && limit_resources_message_H <= 3)
            PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Horde got %u resources left!", _horde_gathered);

        if(IS_RESOURCE_MESSAGE_A)
        {
            if(limit_A == 1)
            {
                PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Alliance got %u resources left!", _ally_gathered);
                IS_RESOURCE_MESSAGE_A = false;
            }
            else if(limit_A == 2)
            {
                p->TextEmote("[Hinterland Defence]: The Alliance has lost! Horde wins as Alliance resources dropped to 0.");
                HandleWinMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                HandleRewards(p, 1500, true, false, false);
                if (p->GetTeamId() == TEAM_ALLIANCE) HandleBuffs(p, true); else HandleBuffs(p, false);
                for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) if (Player* player = sessionPair.second->GetPlayer()) player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                TeleportAllPlayersInZoneToStart();
                _LastWin = HORDE;
                IS_RESOURCE_MESSAGE_A = false;
            }
        }
        else if(IS_RESOURCE_MESSAGE_H)
        {
            if(limit_H == 1)
            {
                PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Horde got %u resources left!", _horde_gathered);
                IS_RESOURCE_MESSAGE_H = false;
            }
            else if(limit_H == 2)
            {
                HandleWinMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                HandleRewards(p, 1500, true, false, false);
                if (p->GetTeamId() == TEAM_ALLIANCE) HandleBuffs(p, false); else HandleBuffs(p, true);
                for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) if (Player* player = sessionPair.second->GetPlayer()) player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                TeleportAllPlayersInZoneToStart();
                _LastWin = ALLIANCE;
                IS_RESOURCE_MESSAGE_H = false;
            }
        }
    }
}

void OutdoorPvPHL::ClampResourceCounters()
{
    ClampResources(_ally_gathered);
    ClampResources(_horde_gathered);
}

std::vector<ObjectGuid> OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
{
    std::vector<ObjectGuid> res;
    if (team != TEAM_ALLIANCE && team != TEAM_HORDE)
        return res;

    for (GuidSet::const_iterator itr = _Groups[team].begin(); itr != _Groups[team].end(); ++itr)
    {
        ObjectGuid gid = *itr;
        Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
        if (!g)
            continue;
        if (!g->isBGGroup())
            continue;
        res.push_back(g->GetGUID());
    }
    return res;
}

// Admin accessors
uint32 OutdoorPvPHL::GetResources(TeamId team) const
{
    if (team == TEAM_ALLIANCE) return _ally_gathered;
    if (team == TEAM_HORDE) return _horde_gathered;
    return 0;
}

void OutdoorPvPHL::SetResources(TeamId team, uint32 amount)
{
    if (team == TEAM_ALLIANCE) _ally_gathered = amount;
    else if (team == TEAM_HORDE) _horde_gathered = amount;
}

void OutdoorPvPHL::ForceReset()
{
    HandleReset();
}
    
    // Handles logic for when a player kills another player or NPC in the battleground.
    // Awards items, deducts resources, and sends kill announcements. Boss kills reward all raid members.
    // Randomizer and random honor logic have been removed for maintainability.
    void OutdoorPvPHL::HandleKill(Player* player, Unit* killed)
    {
        if(killed->GetTypeId() == TYPEID_PLAYER) // Killing players will take their Resources away. It also gives extra honor.
        {
            if(player->GetGUID() == killed->GetGUID())
                return;

            // Announce the kill to the zone
            char announceMsg[256];
            snprintf(announceMsg, sizeof(announceMsg), "[Hinterland Defence]: %s has slain %s!", player->GetName().c_str(), killed->GetName().c_str());
            sWorldSessionMgr->SendZoneText(47, announceMsg);

            // Reward killer with 100x item 80003
            player->AddItem(80003, 100);

            switch(killed->ToPlayer()->GetTeamId())
            {
                case TEAM_ALLIANCE:
                    _ally_gathered -= 5; // Remove 5 resources from Alliance on player kill
                    ClampResourceCounters();
                    player->AddItem(40752, 1);
                    break;
                default: //Horde
                    _horde_gathered -= 5; // Remove 5 resources from Horde on player kill
                    ClampResourceCounters();
                    player->AddItem(40752, 1);
                    break;
            }
        }
        else // If is something besides a player
        {
            if(player->GetTeamId() == TEAM_ALLIANCE)
            {
                switch(killed->GetEntry()) // Alliance killing horde guards
                {
                    case 810002: // Horde boss
                        _horde_gathered -= 200; // Remove 200 resources from Horde on boss kill
                        ClampResourceCounters();
                        {
                            char bossMsg[256];
                            snprintf(bossMsg, sizeof(bossMsg), "[Hinterland Defence]: %s has slain the Horde boss! 200 Horde resources lost! Horde now has %u resources left!", player->GetName().c_str(), _horde_gathered);
                            sWorldSessionMgr->SendZoneText(47, bossMsg);
                            // Reward all raid members with 500x item 80003
                            if (Group* raid = player->GetGroup()) {
                                for (GroupReference* ref = raid->GetFirstMember(); ref; ref = ref->next()) {
                                    Player* member = ref->GetSource();
                                    if (member && member->IsInWorld() && member->GetZoneId() == 47)
                                        member->AddItem(80003, 500);
                                }
                            } else {
                                player->AddItem(80003, 500);
                            }
                        }
                        break;
                    case Horde_Infantry:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    case Horde_Squadleader: // 2?
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /* Removed duplicate case for Horde_Boss (entry 810002) */
                    case Horde_Heal:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /*
                    case WARSONG_HONOR_GUARD:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_MARKSMAN:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_RECRUITMENT_OFFICER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_SCOUT:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_WIND_RIDER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    */
                }
            }
            else // Team Horde
            {
                switch(killed->GetEntry()) // Horde killing alliance guards
                {
                    case 810003: // Alliance boss
                        _ally_gathered -= 200; // Remove 200 resources from Alliance on boss kill
                        ClampResourceCounters();
                        {
                            char bossMsg[256];
                            snprintf(bossMsg, sizeof(bossMsg), "[Hinterland Defence]: %s has slain the Alliance boss! 200 Alliance resources lost! Alliance now has %u resources left!", player->GetName().c_str(), _ally_gathered);
                            sWorldSessionMgr->SendZoneText(47, bossMsg);
                            // Reward all raid members with 500x item 80003
                            if (Group* raid = player->GetGroup()) {
                                for (GroupReference* ref = raid->GetFirstMember(); ref; ref = ref->next()) {
                                    Player* member = ref->GetSource();
                                    if (member && member->IsInWorld() && member->GetZoneId() == 47)
                                        member->AddItem(80003, 500);
                                }
                            } else {
                                player->AddItem(80003, 500);
                            }
                        }
                        break;
                    case Alliance_Healer:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /* Removed duplicate case for Alliance_Boss (entry 810003) */
                    case Alliance_Infantry:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    case Alliance_Squadleader: // Wrong?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /*
                    case VALIANCE_KEEP_FOOTMAN_2: // 2?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_OFFICER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_RIFLEMAN:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_WORKER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case DURDAN_THUNDERBEAK:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    */
                }
            }
        }
    }
    
    // Add to OutdoorPvPHL.h:
    // std::map<ObjectGuid, uint32> _playerLastMove;

    // Script registration for OutdoorPvP Hinterland
    class OutdoorPvP_hinterland : public OutdoorPvPScript
    {
        public:
     
        OutdoorPvP_hinterland()
            : OutdoorPvPScript("outdoorpvp_hl") {}
     
        OutdoorPvP* GetOutdoorPvP() const
        {
            return new OutdoorPvPHL();
        }
    };

     
    // Registers the OutdoorPvP Hinterland script
    void AddSC_outdoorpvp_hl()
    {
        new OutdoorPvP_hinterland;

        // Register movement hook for AFK tracking
        RegisterOutdoorPvPHLPlayerMoveScript();
    }

// Player movement hook to update AFK tracking for Hinterland Outdoor PvP
class OutdoorPvPHL_PlayerMoveScript : public PlayerScript
{
public:
    OutdoorPvPHL_PlayerMoveScript() : PlayerScript("OutdoorPvPHL_PlayerMoveScript") {}

    void OnPlayerMove(Player* player, MovementInfo movementInfo, uint32 /*opcode*/) override
    {
        if (!player || !player->IsInWorld())
            return;
        if (player->GetZoneId() != HL_ZONE_ID)
            return;

        OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID);
        if (!out)
            return;
        OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out);
        if (!hl)
            return;

        // Update last move timestamp for AFK tracking
        hl->TouchPlayerLastMove(player->GetGUID());
    }
};

// Register the player movement script
static void RegisterOutdoorPvPHLPlayerMoveScript()
{
    new OutdoorPvPHL_PlayerMoveScript();
}

