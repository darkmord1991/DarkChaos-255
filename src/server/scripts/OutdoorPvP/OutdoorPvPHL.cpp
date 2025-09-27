/*
    .__      .___.                
    [__)  .    |   _ ._ _ ._ _   .
    [__)\_|    |  (_)[ | )[ | )\_|
            ._|                    ._|

            Was for Omni-WoW
            Now: Released - 5/4/2012
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

    // Constructor: Initializes battleground state, resource counters, timers, and AFK tracking.
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

        // AFK tracking: map player GUID to last movement timestamp (ms)
        _playerLastMove.clear();
    }

    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        return true;
    }

    void OutdoorPvPHL::HandlePlayerEnterZone(Player* player, uint32 zone)
    {
        // Auto-invite logic
        AddOrSetPlayerToCorrectBfGroup(player);

        // Welcome message
        player->TextEmote("Welcome to Hinterland BG!");

        // Initialize last movement timestamp
        _playerLastMove[player->GetGUID()] = World::GetGameTimeMS();

        OutdoorPvP::HandlePlayerEnterZone(player, zone);
    }

    // Returns a non-full raid group for the given team in zone 47, or nullptr if none exists.
    // This ensures only one raid group per faction is used for auto-invite.
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
    // If a group exists, adds the player if not present. Otherwise, creates a new group.
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

    // Helper: Teleport player to race starting location
    void TeleportPlayerToStart(Player* player)
    {
        // Example: Human (race 1) -> Elwynn Forest, Orc (race 2) -> Durotar, etc.
        // You may want to refine these coordinates for your server.
    switch (player->getRace())
        {
            case RACE_HUMAN:
                player->TeleportTo(0, -8949.95f, -132.493f, 83.5312f, 0.0f); // Elwynn Forest
                break;
            case RACE_ORC:
                player->TeleportTo(1, 1676.21f, 1677.85f, 121.67f, 0.0f); // Durotar
                break;
            case RACE_DWARF:
                player->TeleportTo(0, -6240.32f, 336.23f, 382.758f, 0.0f); // Dun Morogh
                break;
            case RACE_NIGHTELF:
                player->TeleportTo(1, 10311.3f, 832.463f, 1326.41f, 0.0f); // Teldrassil
                break;
            case RACE_UNDEAD_PLAYER:
                player->TeleportTo(0, 1676.21f, 1677.85f, 121.67f, 0.0f); // Tirisfal Glades
                break;
            case RACE_TAUREN:
                player->TeleportTo(1, -2917.58f, -257.98f, 52.9968f, 0.0f); // Mulgore
                break;
            case RACE_GNOME:
                player->TeleportTo(0, -6240.32f, 336.23f, 382.758f, 0.0f); // Dun Morogh
                break;
            case RACE_TROLL:
                player->TeleportTo(1, 1676.21f, 1677.85f, 121.67f, 0.0f); // Durotar
                break;
            default:
                player->TeleportTo(0, -8949.95f, -132.493f, 83.5312f, 0.0f); // Default to Elwynn Forest
                break;
        }
    }

    void OutdoorPvPHL::HandlePlayerLeaveZone(Player* player, uint32 zone)
    {
        player->TextEmote(",HEY, you are leaving the zone, while a battle is on going! Shame on you!");
        TeleportPlayerToStart(player);
        // Remove AFK tracking
        _playerLastMove.erase(player->GetGUID());
        OutdoorPvP::HandlePlayerLeaveZone(player, zone);
    }

    void OutdoorPvPHL::HandleWinMessage(const char* message)
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], message);
    }

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
    // Handles battleground start announcement, periodic zone-wide resource broadcast, AFK teleport, and win/lose logic.
    bool OutdoorPvPHL::Update(uint32 diff)
    {
        OutdoorPvP::Update(diff);
        if(_FirstLoad == false)
        {
            // Announce battleground start to all players on the server
            char announceMsg[256];
            snprintf(announceMsg, sizeof(announceMsg), "[Hinterland BG]: A new battle has started in zone 47! Last winner: %s", (_LastWin == ALLIANCE ? "Alliance" : (_LastWin == HORDE ? "Horde" : "None")));
            sWorldSessionMgr->SendGlobalText(announceMsg);
            LOG_INFO("misc", announceMsg);
            _FirstLoad = true;
        }

        // Periodic zone-wide broadcast every 60 seconds with both teams' resources
        _messageTimer += diff;
        if (_messageTimer >= 60000) // 60,000 ms = 60 seconds
        {
            char msg[256];
            snprintf(msg, sizeof(msg), "[Hinterland Defence]: Alliance: %u resources | Horde: %u resources", _ally_gathered, _horde_gathered);
            sWorldSessionMgr->SendZoneText(47, msg);
            _messageTimer = 0;
        }

        // Live/permanent resource broadcast every 5 seconds
        _liveResourceTimer += diff;
        if (_liveResourceTimer >= 5000) // 5,000 ms = 5 seconds
        {
            char liveMsg[256];
            snprintf(liveMsg, sizeof(liveMsg), "[Hinterland BG]: LIVE: Alliance: %u/%u | Horde: %u/%u", _ally_gathered, _ally_permanent_resources, _horde_gathered, _horde_permanent_resources);
            sWorldSessionMgr->SendZoneText(47, liveMsg);
            _liveResourceTimer = 0;
        }

        // AFK teleport logic: teleport players in zone 47 who have not moved for 180 seconds
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        uint32 now = World::GetGameTimeMS();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            Player* player = itr->second ? itr->second->GetPlayer() : nullptr;
            if (!player || !player->IsInWorld() || player->GetZoneId() != 47)
                continue;
            ObjectGuid guid = player->GetGUID();
            // If player is not tracked, initialize
            if (_playerLastMove.find(guid) == _playerLastMove.end())
                _playerLastMove[guid] = now;
            // If player has not moved for 180 seconds, teleport
            if (now - _playerLastMove[guid] >= 180000)
            {
                player->TeleportTo("start");
                _playerLastMove[guid] = now; // Reset timer after teleport
                player->TextEmote("You have been teleported for being AFK!");
            }
        }
        // Call this from Player movement event (not shown here):
        // void OutdoorPvPHL::NotifyPlayerMoved(Player* player) {
        //     _playerLastMove[player->GetGUID()] = World::GetGameTimeMS();
        // }
// Add to OutdoorPvPHL.h:
// uint32 _ally_permanent_resources;
// uint32 _horde_permanent_resources;
// uint32 _liveResourceTimer;

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
                    char msg[250];
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
                            HandleWinMessage("[Hinterland BG]: Horde wins! Alliance resources dropped to 0.");
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
                            sWorldSessionMgr->SendGlobalText("[Hinterland BG]: Horde wins! Alliance resources dropped to 0.");
                            // After battle: teleport all players in zone 47 to 'start'
                            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                            for (WorldSessionMgr::SessionMap::const_iterator itp = sessionMap.begin(); itp != sessionMap.end(); ++itp)
                            {
                                Player* p = itp->second ? itp->second->GetPlayer() : nullptr;
                                if (p && p->IsInWorld() && p->GetZoneId() == 47)
                                    p->TeleportTo("start");
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
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Horde has lost! Alliance wins as Horde resources dropped to 0.");
                            HandleWinMessage("[Hinterland BG]: Alliance wins! Horde resources dropped to 0.");
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
                            sWorldSessionMgr->SendGlobalText("[Hinterland BG]: Alliance wins! Horde resources dropped to 0.");
                            // After battle: teleport all players in zone 47 to 'start'
                            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                            for (WorldSessionMgr::SessionMap::const_iterator itp = sessionMap.begin(); itp != sessionMap.end(); ++itp)
                            {
                                Player* p = itp->second ? itp->second->GetPlayer() : nullptr;
                                if (p && p->IsInWorld() && p->GetZoneId() == 47)
                                    p->TeleportTo("start");
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
    

    // Randomizes the honor reward for each NPC kill in the battleground.
    void OutdoorPvPHL::Randomizer(Player* player)
    {
        switch(urand(0, 4))
        {
            case 0:
                HandleRewards(player, 17, true, false, false);
                break;
            case 1:
                HandleRewards(player, 11, true, false, false);
                break;
            case 2:
                HandleRewards(player, 19, true, false, false);
                break;
            case 3:
                HandleRewards(player, 22, true, false, false);
                break;
        }
    }

    /*
    void outdoorPvPHL::BossReward(Player * player)
    {
        HandleRewards(player, 5000, true, false, false);
        HandleRewards(player, 200, false, true, false);   <- Anpassen?
        
        char message[250];
        if(player->GetTeam() == ALLIANCE)
            snprintf(message, 250, "Der Boss der Horde wurde soeben besiegt!");
        else
            snprintf(message, 250, "Der Boss der Allianz wurde soeben besiegt!);
    */

	void OutdoorPvPHL::HandleKill(Player* player, Unit* killed)
    {
        if(killed->GetTypeId() == TYPEID_PLAYER) // Killing players will take their Resources away. It also gives extra honor.
        {
            if(player->GetGUID() != killed->GetGUID())
                    return;
     
            switch(killed->ToPlayer()->GetTeamId())
            {
               case TEAM_ALLIANCE:
                    _ally_gathered -= PointsLoseOnPvPKill;
					player->AddItem(40752, 1);
                    Randomizer(player);					
                    break;
               default: //Horde
                    _horde_gathered -= PointsLoseOnPvPKill;					
                    Randomizer(player);
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
                    case Horde_Infantry:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case Horde_Squadleader: // 2?
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case Horde_Boss:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        /*BossReward(player); */
                        break;
                    case Horde_Heal:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    /*
                    case WARSONG_HONOR_GUARD:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case WARSONG_MARKSMAN:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case WARSONG_RECRUITMENT_OFFICER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case WARSONG_SCOUT:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
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
                    case Alliance_Healer:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case Alliance_Boss:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        /*BossReward(player); <- NEU? */
                        break;
                    case Alliance_Infantry:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case Alliance_Squadleader: // Wrong?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    /*
                    case VALIANCE_KEEP_FOOTMAN_2: // 2?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case VALIANCE_KEEP_OFFICER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case VALIANCE_KEEP_RIFLEMAN:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case VALIANCE_KEEP_WORKER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    case DURDAN_THUNDERBEAK:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    */
                }
            }
        }
    }
    
    // Add to OutdoorPvPHL.h:
    // std::map<ObjectGuid, uint32> _playerLastMove;

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

     
    void AddSC_outdoorpvp_hl()
    {
        new OutdoorPvP_hinterland;
	}
