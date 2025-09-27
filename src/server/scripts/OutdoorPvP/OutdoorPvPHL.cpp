/*
================================================================================
  OutdoorPvPHL.cpp - Hinterland Outdoor PvP Battleground (zone 47)
================================================================================

  Features & Gameplay Overview (2025):
  -----------------------------------------------------------------------------
  - Zone-wide Alliance vs Horde PvP battleground in Hinterland (zone 47)
  - Automatic group management: auto-invites, raid creation, and linking
  - Resource system: each faction starts with resources, lose them on deaths/kills
  - Permanent resource tracking: resources never reset during a run, only at reset
  - Periodic zone-wide broadcasts:
      * Every 180s: announces current resources for both factions
      * Every 5s: live resource status and match timer (via worldstate update)
  - AFK detection: teleports players who have not moved for 180s to start location
  - Battleground start and win announcements:
      * Global and zone-wide messages for start and victory
      * Sound effects for victory/defeat per faction
  - Buffs and rewards:
      * Win/lose buffs applied to players
      * Honor and arena point rewards for kills and victory
      * Item rewards for player and boss kills
  - Custom teleportation:
      * Faction-based teleport coordinates for start/end of battle
  - Handles player entry/exit, kill logic, and group linking
  - All random honor reward logic (Randomizer) has been removed for clarity
  - Respawn logic for NPCs and game objects is currently disabled

  Code Structure:
  -----------------------------------------------------------------------------
  - OutdoorPvPHL: Main class implementing battleground logic
  - GroupMgr, WorldSessionMgr: Used for group and player session management
  - Timers: For periodic messaging, match duration, and AFK detection
  - std::map<ObjectGuid, uint32>: Tracks last movement for AFK logic
  - Functions: Setup, Update, HandlePlayerEnterZone, HandlePlayerLeaveZone,
               HandleKill, HandleRewards, HandleBuffs, HandleWinMessage, etc.

  For maintainers: See function comments for details on each gameplay feature.
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

// OutdoorPvPHL.cpp: Main logic for Hinterland Outdoor PvP Battleground (zone 47)
// Implements group management, resource tracking, AFK detection, messaging, rewards, and faction-based teleportation.

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
        for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); ++itr)
        {
            // Look up the group by GUID
            Group* group = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (group && !group->IsFull())
                return group;
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
            return false;
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
            // No group exists, create a new one and add player
            group = new Group;
            Battleground *bg = (Battleground*)sOutdoorPvPMgr->GetOutdoorPvPToZoneId(47);
            group->SetBattlegroundGroup(bg);
            group->Create(plr);
            sGroupMgr->AddGroup(group);
            _Groups[plr->GetTeamId()].insert(group->GetGUID());
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
    void TeleportPlayerToStart(Player* player)
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

    // Broadcasts a win message to all players in the Hinterland zone.
    // Respawn logic for NPCs and game objects is currently disabled.
    void OutdoorPvPHL::HandleWinMessage(const char* message)
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], message);

            // Respawn logic for NPCs and game objects temporarily removed as requested.
    }

    // Plays victory/defeat sounds for all players in the zone, depending on side.
    void OutdoorPvPHL::PlaySounds(bool side)
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
                    if(itr->second->GetPlayer()->GetTeamId() == TEAM_ALLIANCE && side == true)
                        itr->second->GetPlayer()->PlayDirectSound(HL_SOUND_ALLIANCE_GOOD, itr->second->GetPlayer());
                    else
                        itr->second->GetPlayer()->PlayDirectSound(HL_SOUND_HORDE_GOOD, itr->second->GetPlayer());
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
    // AFK teleport, win/lose logic, and all match progression features.
    bool OutdoorPvPHL::Update(uint32 diff)
    {
        OutdoorPvP::Update(diff);
        if(_FirstLoad == false)
        {
            // Announce battleground start to all players on the server
            char announceMsg[256];
            snprintf(announceMsg, sizeof(announceMsg), "[Hinterland Defence]: A new battle has started in zone 47! Last winner: %s", (_LastWin == ALLIANCE ? "Alliance" : (_LastWin == HORDE ? "Horde" : "None")));
            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) {
                if (Player* player = sessionPair.second->GetPlayer())
                    player->GetSession()->SendAreaTriggerMessage(announceMsg);
            }
            LOG_INFO("misc", announceMsg);
            _FirstLoad = true;
                _matchTimer = 0; // Reset match timer
        }

            // Match duration logic: 60 minutes (3,600,000 ms)
            _matchTimer += diff;
            if (_matchTimer >= 3600000) // 60 minutes
            {
                HandleWinMessage("[Hinterland Defence]: The match has ended due to time limit! Restarting...");
                HandleReset();
                _matchTimer = 0;
                _FirstLoad = false;
                return true; // End update early to restart
            }

        // Periodic zone-wide broadcast every 120 seconds with resources and remaining timer
        _messageTimer += diff;
        if (_messageTimer >= 120000) // 120,000 ms = 120 seconds
        {
            uint32 timeRemaining = (_matchTimer >= 3600000) ? 0 : (3600000 - _matchTimer) / 1000;
            uint32 minutes = timeRemaining / 60;
            uint32 seconds = timeRemaining % 60;
            char msg[256];
            snprintf(msg, sizeof(msg), "[Hinterland Defence]: Alliance: %u | Horde: %u | Time left: %02u:%02u (Start: 60:00)", _ally_gathered, _horde_gathered, minutes, seconds);
            sWorldSessionMgr->SendZoneText(47, msg);
            _messageTimer = 0;
        }

        // AFK teleport logic: teleport players in zone 47 who have not moved for 10 minutes (600 seconds)
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        uint32 now = getMSTime();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            Player* player = itr->second ? itr->second->GetPlayer() : nullptr;
            if (!player || !player->IsInWorld() || player->GetZoneId() != 47)
                continue;
            ObjectGuid guid = player->GetGUID();
            // If player is not tracked, initialize
            if (_playerLastMove.find(guid) == _playerLastMove.end())
                _playerLastMove[guid] = now;
            // If player has not moved for 10 minutes, teleport and notify
            if (now - _playerLastMove[guid] >= 600000)
            {
                if (player->GetTeamId() == TEAM_ALLIANCE)
                    player->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
                else
                    player->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
                _playerLastMove[guid] = now; // Reset timer after teleport
                player->TextEmote("You have been summoned to your starting position due to inactivity.");
            }
        }

        if(_ally_gathered <= 50 && limit_A == 0)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true; // We allow the message to pass
            IS_RESOURCE_MESSAGE_A = true; // We allow the message to be shown
            limit_A = 1; // We set this to one to stop the spamming
            PlaySounds(false);
        }
        else if(_horde_gathered <= 50 && limit_H == 0)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true; // We allow the message to pass
            IS_RESOURCE_MESSAGE_H = true; // We allow the message to be shown
            limit_H = 1; // Same as above
            PlaySounds(true);
        }
        else if(_ally_gathered <= 0 && limit_A == 1)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true; // We allow the message to pass
            IS_RESOURCE_MESSAGE_A = true; // We allow the message to be shown
            limit_A = 2;
            PlaySounds(false);
            // Teleport all Alliance players in zone 47 to their start location
            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
            for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
            {
                if (!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != 47)
                    continue;
                if (itr->second->GetPlayer()->GetTeamId() == TEAM_ALLIANCE)
                    TeleportPlayerToStart(itr->second->GetPlayer());
            }
        }
        else if(_horde_gathered <= 0 && limit_H == 1)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true; // We allow the message to pass
            IS_RESOURCE_MESSAGE_H = true; // We allow the message to be shown
            limit_H = 2;
            PlaySounds(true);
            // Teleport all Horde players in zone 47 to their start location
            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
            for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
            {
                if (!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != 47)
                    continue;
                if (itr->second->GetPlayer()->GetTeamId() == TEAM_HORDE)
                    TeleportPlayerToStart(itr->second->GetPlayer());
            }
        }
        else if(_ally_gathered <= 300 && limit_resources_message_A == 0)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_A = 1;
            PlaySounds(false);
        }
        else if(_horde_gathered <= 300 && limit_resources_message_H == 0)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_H = 1;
            PlaySounds(true);
        }
        else if(_ally_gathered <= 200 && limit_resources_message_A == 1)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_A = 2;
            PlaySounds(false);
        }
        else if(_horde_gathered <= 200 && limit_resources_message_H == 1)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_H = 2;
            PlaySounds(true);
        }
        else if(_ally_gathered <= 100 && limit_resources_message_A == 2)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_A = 3;
            PlaySounds(false);
        }
        else if(_horde_gathered <= 100 && limit_resources_message_H == 2)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true;
            limit_resources_message_H = 3;
            PlaySounds(true);
        }
     
        if(IS_ABLE_TO_SHOW_MESSAGE == true) // This will limit the spam
        {
            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
            for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr) // We're searching for all the sessions(Players)
            {
                if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() ||
                    itr->second->GetPlayer()->GetZoneId() != 47)
                    continue;
     
                if(itr->second->GetPlayer()->GetZoneId() == 47)
                {
                    // Removed unused variable 'msg'
                    if(limit_resources_message_A == 1 || limit_resources_message_A == 2 || limit_resources_message_A == 3)
                    {
                        itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Alliance got %u resources left!");
                    }
                    else if(limit_resources_message_H == 1 || limit_resources_message_H == 2 || limit_resources_message_H == 3)
                    {
                        itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Horde got %u resources left!");
                    }
     
                    if(IS_RESOURCE_MESSAGE_A == true)
                    {
                        if(limit_A == 1)
                        {
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Alliance got %u resources left!");
                            IS_RESOURCE_MESSAGE_A = false; // Reset
                        }
                        else if(limit_A == 2)
                        {
                            // Alliance resources reached 0: Alliance loses, Horde wins
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Alliance has lost! Horde wins as Alliance resources dropped to 0.");
                            HandleWinMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                            HandleRewards(itr->second->GetPlayer(), 1500, true, false, false);
                            switch(itr->second->GetPlayer()->GetTeamId())
                            {
                                case TEAM_ALLIANCE:
                                    HandleBuffs(itr->second->GetPlayer(), true);
                                    break;
                                default: //Horde
                                    HandleBuffs(itr->second->GetPlayer(), false);
                                    break;
                            }
                            // Announce winning team to all players
                            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) {
                                if (Player* player = sessionPair.second->GetPlayer())
                                    player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                            }
                            // After battle: teleport all players in zone 47 to 'start'
                            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                            for (WorldSessionMgr::SessionMap::const_iterator itp = sessionMap.begin(); itp != sessionMap.end(); ++itp)
                            {
                                Player* p = itp->second ? itp->second->GetPlayer() : nullptr;
                                if (p && p->IsInWorld() && p->GetZoneId() == 47) {
                                    if (p->GetTeamId() == TEAM_ALLIANCE) {
                                        p->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
                                    }
                                    else
                                    {
                                        p->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
                                    }
                                }
                            }
                            _LastWin = HORDE;
                            IS_RESOURCE_MESSAGE_A = false; // Reset
                        }
                    }
                    else if(IS_RESOURCE_MESSAGE_H == true)
                    {
                        if(limit_H == 1)
                        {
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Horde got %u resources left!");
                            IS_RESOURCE_MESSAGE_H = false; // Reset
                        }
                        else if(limit_H == 2)
                        {
                            // Horde resources reached 0: Horde loses, Alliance wins
                            HandleWinMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                            HandleRewards(itr->second->GetPlayer(), 1500, true, false, false);
                            switch(itr->second->GetPlayer()->GetTeamId())
                            {
                                case TEAM_ALLIANCE:
                                    HandleBuffs(itr->second->GetPlayer(), false);
                                    break;
                                default: //Horde
                                    HandleBuffs(itr->second->GetPlayer(), true);
                                    break;
                            }
                            // Announce winning team to all players
                            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) {
                                if (Player* player = sessionPair.second->GetPlayer())
                                    player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                            }
                            // After battle: teleport all players in zone 47 to 'start'
                            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                            for (WorldSessionMgr::SessionMap::const_iterator itp = sessionMap.begin(); itp != sessionMap.end(); ++itp)
                            {
                                Player* p = itp->second ? itp->second->GetPlayer() : nullptr;
                                if (p && p->IsInWorld() && p->GetZoneId() == 47)
                                    if (p->GetTeamId() == TEAM_ALLIANCE) {
                                        p->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
                                    } else {
                                        p->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
                                    }
                            }
                            _LastWin = ALLIANCE;
                            IS_RESOURCE_MESSAGE_H = false; // Reset
                        }
                    }
                }
            }
        }

        IS_ABLE_TO_SHOW_MESSAGE = false; // Reset
        return false;
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
                    player->AddItem(40752, 1);
                    break;
                default: //Horde
                    _horde_gathered -= 5; // Remove 5 resources from Horde on player kill
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
                        break;
                    case Horde_Squadleader: // 2?
                        _horde_gathered -= PointsLoseOnPvPKill;
                        break;
                    /* Removed duplicate case for Horde_Boss (entry 810002) */
                    case Horde_Heal:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        break;
                    /*
                    case WARSONG_HONOR_GUARD:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case WARSONG_MARKSMAN:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case WARSONG_RECRUITMENT_OFFICER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case WARSONG_SCOUT:
                        _horde_gathered -= PointsLoseOnPvPKill;
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
                        break;
                    /* Removed duplicate case for Alliance_Boss (entry 810003) */
                    case Alliance_Infantry:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        break;
                    case Alliance_Squadleader: // Wrong?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        break;
                    /*
                    case VALIANCE_KEEP_FOOTMAN_2: // 2?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_OFFICER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_RIFLEMAN:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_WORKER:
                        _ally_gathered -= PointsLoseOnPvPKill;
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
	}
