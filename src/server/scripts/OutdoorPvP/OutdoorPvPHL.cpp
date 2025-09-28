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
    #include "OutdoorPvPMgr.h"
    #include "World.h"
    #include "WorldPacket.h"
    #include "OutdoorPvPScript.h"
    #include "CreatureScript.h"
    #include "WorldSession.h"
    #include "WorldSessionMgr.h"
    #include "Chat.h"
    #include "ObjectMgr.h"
    #include "ObjectAccessor.h"
    #include "DBCStores.h"
    #include "Misc/GameGraveyard.h"
    #include "Time/GameTime.h"
    
    #include "GroupMgr.h"
    #include "MapMgr.h"
    #include "ScriptDefines/MovementHandlerScript.h"
    #include <algorithm>
    #include <cmath>

    OutdoorPvPHL::OutdoorPvPHL()
    {
        _typeId = OUTDOOR_PVP_HL;

        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;
        _LastWin = 0;
        _matchEndTime = 0;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;

        limit_A = 0;
        limit_H = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;

        _playersInZone = 0;
        _npcCheckTimerMs = 0;
        _afkCheckTimerMs = 0;
        _memberOfflineSince.clear();

    }

    OutdoorPvPHL::~OutdoorPvPHL() = default;

    // Basic OutdoorPvP setup: register managed zones and derive the map id from the zone
    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        SetMapFromZone(OutdoorPvPHLBuffZones[0]);
        return true;
    }

    // Initialize the WG-like HUD states when a client first loads the worldstates
    void OutdoorPvPHL::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
    {
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = uint32(GameTime::GetGameTime().count()) + GetTimeRemainingSeconds();
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, GetResources(TEAM_HORDE));
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, GetResources(TEAM_ALLIANCE));
        uint32 maxVal = std::max(GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE));
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxVal);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxVal);
    }

    void OutdoorPvPHL::UpdateWorldStatesForPlayer(Player* player)
    {
        if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
            return;
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = uint32(GameTime::GetGameTime().count()) + GetTimeRemainingSeconds();
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, GetResources(TEAM_HORDE));
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, GetResources(TEAM_ALLIANCE));
        uint32 maxVal = std::max(GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE));
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxVal);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxVal);
    }

    void OutdoorPvPHL::UpdateWorldStatesAllPlayers()
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (auto const& it : sessionMap)
        {
            Player* p = it.second ? it.second->GetPlayer() : nullptr;
            if (!p || !p->IsInWorld() || p->GetZoneId() != OutdoorPvPHLBuffZones[0])
                continue;
            UpdateWorldStatesForPlayer(p);
        }
    }

    // small helper impls
    bool OutdoorPvPHL::IsMaxLevel(Player* player) const
    {
        if (!player)
            return false;
        return player->GetLevel() >= sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL);
    }

    bool OutdoorPvPHL::IsEligibleForRewards(Player* player) const
    {
        if (!player)
            return false;
        // Deserters or players flagged AFK do not get rewards
        static constexpr uint32 BG_DESERTER_SPELL = 26013; // "Deserter"
        if (player->HasAura(BG_DESERTER_SPELL))
            return false;
        // AFK is handled with reduction/teleport policy outside this check
        return true;
    }

    void OutdoorPvPHL::Whisper(Player* player, std::string const& msg) const
    {
        if (!player)
            return;
        if (WorldSession* session = player->GetSession())
        {
            ChatHandler(session).SendSysMessage(msg.c_str());
        }
    }

    uint8 OutdoorPvPHL::GetAfkCount(Player* player) const
    {
        if (!player)
            return 0;
        uint32 low = player->GetGUID().GetCounter();
        auto it = _afkInfractions.find(low);
        if (it == _afkInfractions.end())
            return 0;
        return it->second;
    }

    void OutdoorPvPHL::IncrementAfk(Player* player)
    {
        if (!player)
            return;
        uint32 low = player->GetGUID().GetCounter();
        _afkInfractions[low] = std::min<uint8>(255, GetAfkCount(player) + 1);
    }

    void OutdoorPvPHL::ClearAfkState(Player* player)
    {
        if (!player)
            return;
        uint32 low = player->GetGUID().GetCounter();
        _afkInfractions.erase(low);
        _afkFlagged.erase(low);
    }

    void OutdoorPvPHL::TeleportToCapital(Player* player) const
    {
        if (!player)
            return;
        // Default to Stormwind/Orgrimmar
        if (player->GetTeamId() == TEAM_ALLIANCE)
        {
            // Stormwind: Map 0, approx coords
            player->TeleportTo(0, -8833.38f, 628.628f, 94.0066f, 1.0f);
        }
        else
        {
            // Orgrimmar: Map 1 or 0 depending on core version; use EK map 1 classic ORG? For WotLK: Map 1 -> Kalimdor, coords below
            player->TeleportTo(1, 1633.33f, -4373.33f, 16.0f, 3.1f);
        }
    }

    // --- Admin/inspection helpers ---
    uint32 OutdoorPvPHL::GetTimeRemainingSeconds() const
    {
        if (_matchEndTime == 0)
            return 0u;
    uint32 now = uint32(GameTime::GetGameTime().count());
        if (now >= _matchEndTime)
            return 0u;
        return _matchEndTime - now;
    }

    uint32 OutdoorPvPHL::GetResources(TeamId team) const
    {
        return (team == TEAM_ALLIANCE) ? _ally_gathered : _horde_gathered;
    }

    void OutdoorPvPHL::SetResources(TeamId team, uint32 amount)
    {
        if (team == TEAM_ALLIANCE)
            _ally_gathered = amount;
        else
            _horde_gathered = amount;
    }

    
    std::vector<ObjectGuid> OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
    {
        if (team > TEAM_HORDE)
            return {};
        return _teamRaidGroups[team];
    }

    void OutdoorPvPHL::ForceReset()
    {
        HandleReset();
    }

    void OutdoorPvPHL::TeleportPlayersToStart()
    {
        // No-op placeholder; can be implemented to move players to start positions if needed.
    }

    bool OutdoorPvPHL::AddOrSetPlayerToCorrectBfGroup(Player* plr)
    {
        if (!plr)
            return false;
        if (plr->GetZoneId() != OutdoorPvPHLBuffZones[0])
            return false;
        // If player already in a raid group, nothing to do
        if (Group* g = plr->GetGroup())
        {
            if (g->isRaidGroup())
                return true;
        }
        // Maintain our own list of BG raids per team and enforce capacity
        TeamId tid = plr->GetTeamId();
        // Clean dead groups
        auto& vec = _teamRaidGroups[tid];
        vec.erase(std::remove_if(vec.begin(), vec.end(), [](ObjectGuid gguid)
        {
            Group* g = sGroupMgr->GetGroupByGUID(gguid.GetCounter());
            return !g || !g->isRaidGroup();
        }), vec.end());
        // Find non-full group
        Group* target = nullptr;
        for (ObjectGuid gid : vec)
        {
            Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
            if (g && g->isRaidGroup() && g->GetMembersCount() < MAXRAIDSIZE)
            {
                target = g;
                break;
            }
        }
        if (!target)
        {
            Group* g = new Group();
            if (!g->Create(plr))
            {
                delete g;
                return false;
            }
            // Ensure the group is a raid
            g->ConvertToRaid();
            sGroupMgr->AddGroup(g);
            _teamRaidGroups[tid].push_back(g->GetGUID());
            return true;
        }
        target->AddMember(plr);
        return true;
    }

    void OutdoorPvPHL::HandlePlayerEnterZone(Player* player, uint32 zone)
    {
        // Max level gate
        if (!IsMaxLevel(player))
        {
            Whisper(player, "You must be max level to join the Hinterland battle.");
            // Teleport out to nearest graveyard as a soft rejection
            if (GraveyardStruct const* g = sGraveyard->GetClosestGraveyard(player, player->GetTeamId()))
                player->TeleportTo(g->Map, g->x, g->y, g->z, player->GetOrientation());
            return; // do not register enter to PvP logic
        }

        // Welcome and current standing whisper
        Whisper(player, "Welcome to Hinterland BG!");
        Whisper(player, "Current standing — Alliance: " + std::to_string(_ally_gathered) + ", Horde: " + std::to_string(_horde_gathered) + ".");

    ++_playersInZone;
        // entering the zone clears AFK flagged edge state
    _afkFlagged.erase(player->GetGUID().GetCounter());
    // seed last-move trackers
    _playerLastMove[player->GetGUID()] = uint32(GameTime::GetGameTime().count());
    _playerWarnedBeforeTeleport[player->GetGUID()] = false;
    _playerLastPos[player->GetGUID()] = player->GetPosition();

        // Auto-invite into faction battleground-raid if available
        AddOrSetPlayerToCorrectBfGroup(player);

        // Seed HUD worldstates for the player entering
        UpdateWorldStatesForPlayer(player);
        OutdoorPvP::HandlePlayerEnterZone(player, zone);
    }

    void OutdoorPvPHL::HandlePlayerLeaveZone(Player* player, uint32 zone)
    {
         player->TextEmote(",HEY, you are leaving the zone, while a battle is on going! Shame on you!");
         if (_playersInZone > 0)
         {
             --_playersInZone;
             if (_playersInZone == 0)
                 _npcCheckTimerMs = 60 * IN_MILLISECONDS; // start 1-minute empty-zone timer
         }
         // clear AFK tracking on leave
         ClearAfkState(player);
         if (player)
         {
             _playerLastMove.erase(player->GetGUID());
             _playerWarnedBeforeTeleport.erase(player->GetGUID());
             _playerLastPos.erase(player->GetGUID());

             // If player was in one of our tracked battleground raid groups, remove them now
             if (Group* g = player->GetGroup())
             {
                 if (g->isRaidGroup())
                 {
                     ObjectGuid gid = g->GetGUID();
                     bool tracked = (std::find(_teamRaidGroups[TEAM_ALLIANCE].begin(), _teamRaidGroups[TEAM_ALLIANCE].end(), gid) != _teamRaidGroups[TEAM_ALLIANCE].end()) ||
                                    (std::find(_teamRaidGroups[TEAM_HORDE].begin(), _teamRaidGroups[TEAM_HORDE].end(), gid) != _teamRaidGroups[TEAM_HORDE].end());
                     if (tracked)
                     {
                         // Remove this player from the raid
                         g->RemoveMember(player->GetGUID());
                         // If empty afterwards, disband immediately and untrack
                         if (g->GetMembersCount() == 0)
                         {
                             g->Disband(true /*hideDestroy*/);
                             for (auto& vec : _teamRaidGroups)
                             {
                                 vec.erase(std::remove(vec.begin(), vec.end(), gid), vec.end());
                             }
                         }
                     }
                 }
             }
         }
        OutdoorPvP::HandlePlayerLeaveZone(player, zone);
    }

    void OutdoorPvPHL::NotePlayerMovement(Player* player)
    {
        if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
            return;
        // Update last move time on any movement that meaningfully changes position
        Position const& cur = player->GetPosition();
        Position& last = _playerLastPos[player->GetGUID()];
        float dx = last.GetPositionX() - cur.GetPositionX();
        float dy = last.GetPositionY() - cur.GetPositionY();
        float dz = last.GetPositionZ() - cur.GetPositionZ();
        float dist2d = std::sqrt(dx*dx + dy*dy);
        if (dist2d > 0.5f || std::fabs(dz) > 0.5f)
        {
            _playerLastMove[player->GetGUID()] = uint32(GameTime::GetGameTime().count());
            _playerWarnedBeforeTeleport[player->GetGUID()] = false; // reset warn once they move
            last = cur;
            // If previously flagged AFK due to inactivity, clear the edge flag so next AFK is a new infraction only when idle again
            _afkFlagged.erase(player->GetGUID().GetCounter());
        }
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

    void OutdoorPvPHL::HandleReset()
    {
        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;

        limit_A = 0;
        limit_H = 0;

        limit_resources_message_A = 0;
        limit_resources_message_H = 0;

        // seed a fresh timer window from now
    _matchEndTime = uint32(GameTime::GetGameTime().count()) + HL_MATCH_DURATION_SECONDS;
        //sLog->outMessage("[OutdoorPvPHL]: Hinterland: Reset Hinterland BG", 1,);
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
        if (!IsEligibleForRewards(player))
        {
            Whisper(player, "You are not eligible for rewards (deserter).");
            return;
        }
        uint32 amount = honorpointsorarena;
        // Apply AFK reward policy based on infraction count (movement or chat-based)
        if (player)
        {
            uint8 count = GetAfkCount(player);
            if (count >= 2)
            {
                Whisper(player, "AFK penalty: no rewards.");
                return;
            }
            else if (count == 1)
            {
                amount = honorpointsorarena / 2;
                Whisper(player, "AFK penalty applied: half rewards.");
            }
        }
        char msg[250];
        uint32 _GetHonorPoints = player->GetHonorPoints();
        uint32 _GetArenaPoints = player->GetArenaPoints();

        if(honor)
        {
            player->SetHonorPoints(_GetHonorPoints + amount);
            snprintf(msg, 250, "You got %u bonus honor!", amount);
        }
        else if(arena)
        {
            player->SetArenaPoints(_GetArenaPoints + amount);
            snprintf(msg, 250, "You got amount of %u additional arena points!", amount);
        }
        else if(both)
        {
            player->SetHonorPoints(_GetHonorPoints + amount);
            player->SetArenaPoints(_GetArenaPoints + amount);
            snprintf(msg, 250, "You got amount of %u additional arena points and bonus honor!", amount);
        }
        HandleWinMessage(msg);
    }

    // Movement-based AFK thresholds (in seconds)
    static constexpr uint32 HL_AFK_WARN_SECONDS = 60;      // warn after 60s idle
    static constexpr uint32 HL_AFK_TELEPORT_SECONDS = 90;  // act after 90s idle

    bool OutdoorPvPHL::Update(uint32 diff)
    {
        OutdoorPvP::Update(diff);
        if(_FirstLoad == false)
        {
            if(_LastWin == ALLIANCE) 
            {
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! Last winner: Alliance");                
            }
             
            else if(_LastWin == HORDE) 
            {
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! Last winner: Horde ");
            }
                
            else if(_LastWin == 0) 
            {
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! There was no winner last time!");
            }
                
            if (_matchEndTime == 0)
                _matchEndTime = uint32(GameTime::GetGameTime().count()) + HL_MATCH_DURATION_SECONDS;
            _FirstLoad = true;
        }

        // Note: avoid blocking sleeps here; periodic announcements are handled by timer thresholds below.
        // If zone became empty, count down ~1 minute to help diagnose NPC respawn/cleanup cycles.
        if (_playersInZone == 0 && _npcCheckTimerMs > 0)
        {
            if (diff >= _npcCheckTimerMs)
            {
                _npcCheckTimerMs = 0;
                LOG_INFO("misc", "[OutdoorPvPHL]: Zone empty for ~60s. Check NPC presence on next join.");
            }
            else
                _npcCheckTimerMs -= diff;
        }

        // Offline tracking & pruning: remove raid members offline for >=45s to cover disconnects
        {
            uint32 nowSec = uint32(GameTime::GetGameTime().count());
            // Mark newly offline members & clear marks for those who returned
            for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
            {
                for (ObjectGuid gid : _teamRaidGroups[tid])
                {
                    Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
                    if (!g || !g->isRaidGroup())
                        continue;
                    for (auto const& slot : g->GetMemberSlots())
                    {
                        Player* m = ObjectAccessor::FindPlayer(slot.guid);
                        if (m && m->IsInWorld())
                        {
                            _memberOfflineSince.erase(slot.guid);
                        }
                        else if (_memberOfflineSince.find(slot.guid) == _memberOfflineSince.end())
                        {
                            _memberOfflineSince[slot.guid] = nowSec; // first seen offline
                        }
                    }
                }
            }
            // Collect removals
            static constexpr uint32 HL_OFFLINE_GRACE_SECONDS = 45;
            std::vector<std::pair<ObjectGuid/*group*/, ObjectGuid/*member*/>> offlineRemovals;
            for (auto const& kv : _memberOfflineSince)
            {
                if (nowSec - kv.second < HL_OFFLINE_GRACE_SECONDS)
                    continue;
                for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
                {
                    for (ObjectGuid gid : _teamRaidGroups[tid])
                    {
                        Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
                        if (!g || !g->isRaidGroup())
                            continue;
                        if (g->IsMember(kv.first))
                        {
                            offlineRemovals.emplace_back(gid, kv.first);
                            break;
                        }
                    }
                }
            }
            for (auto const& rem : offlineRemovals)
            {
                if (Group* g = sGroupMgr->GetGroupByGUID(rem.first.GetCounter()))
                    g->RemoveMember(rem.second);
                _memberOfflineSince.erase(rem.second);
            }
        }

        // Stricter group lifecycle: remove empty raid groups promptly
        for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
        {
            auto& vec = _teamRaidGroups[tid];
            for (auto it = vec.begin(); it != vec.end();)
            {
                Group* g = sGroupMgr->GetGroupByGUID(it->GetCounter());
                if (!g || !g->isRaidGroup() || g->GetMembersCount() == 0)
                {
                    // Disband group if it still exists to avoid leaving empty raids hanging around
                    if (g)
                        g->Disband(true /*hideDestroy*/);
                    it = vec.erase(it);
                }
                else
                {
                    ++it;
                }
            }
        }

        // AFK tracking (movement-based + chat /afk): detect transitions and apply policy
        if (_afkCheckTimerMs <= diff)
        {
            _afkCheckTimerMs = 2000;
            WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
            for (auto const& it : sessionMap)
            {
                Player* p = it.second ? it.second->GetPlayer() : nullptr;
                if (!p || !p->IsInWorld() || p->GetZoneId() != 47)
                    continue;
                uint32 low = p->GetGUID().GetCounter();
                bool wasAfk = _afkFlagged.count(low) > 0;
                // movement-based check
                uint32 nowSec = uint32(GameTime::GetGameTime().count());
                auto itLast = _playerLastMove.find(p->GetGUID());
                if (itLast == _playerLastMove.end())
                {
                    _playerLastMove[p->GetGUID()] = nowSec;
                    _playerWarnedBeforeTeleport[p->GetGUID()] = false;
                    _playerLastPos[p->GetGUID()] = p->GetPosition();
                }
                uint32 idleSec = nowSec - _playerLastMove[p->GetGUID()];
                if (idleSec >= HL_AFK_TELEPORT_SECONDS)
                {
                    if (!wasAfk)
                    {
                        _afkFlagged.insert(low);
                        IncrementAfk(p);
                        uint8 count = GetAfkCount(p);
                        if (count == 1)
                        {
                            Whisper(p, "AFK detected due to inactivity. You receive half rewards. You'll be moved back to the starting area.");
                            if (GraveyardStruct const* g = sGraveyard->GetClosestGraveyard(p, p->GetTeamId()))
                                p->TeleportTo(g->Map, g->x, g->y, g->z, p->GetOrientation());
                        }
                        else if (count >= 2)
                        {
                            Whisper(p, "Repeated AFK detected. You will be teleported to your capital and will not receive rewards anymore.");
                            TeleportToCapital(p);
                        }
                    }
                }
                else if (idleSec >= HL_AFK_WARN_SECONDS)
                {
                    if (!_playerWarnedBeforeTeleport[p->GetGUID()])
                    {
                        uint32 secondsLeft = HL_AFK_TELEPORT_SECONDS - idleSec;
                        Whisper(p, "You seem AFK. Move now or you'll be teleported in " + std::to_string(secondsLeft) + "s.");
                        _playerWarnedBeforeTeleport[p->GetGUID()] = true;
                    }
                }

                // chat-based /afk edge tracking for those who manually toggle (kept for parity)
                bool nowAfkChat = p->isAFK();
                if (nowAfkChat && !wasAfk)
                {
                    _afkFlagged.insert(low);
                    IncrementAfk(p);
                    uint8 count = GetAfkCount(p);
                    if (count == 1)
                        Whisper(p, "AFK detected. While AFK you receive half rewards. A second AFK will teleport you to your capital and forfeit rewards.");
                    else if (count >= 2)
                    {
                        Whisper(p, "Repeated AFK detected. You will be teleported to your capital and will not receive rewards anymore.");
                        TeleportToCapital(p);
                    }
                }
                else if (!nowAfkChat && wasAfk)
                {
                    _afkFlagged.erase(low);
                }
            }
        }
        else
        {
            _afkCheckTimerMs -= diff;
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
        }
        else if(_horde_gathered <= 0 && limit_H == 1)
        {
            IS_ABLE_TO_SHOW_MESSAGE = true; // We allow the message to pass
            IS_RESOURCE_MESSAGE_H = true; // We allow the message to be shown
            limit_H = 2;
            PlaySounds(true);
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
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Alliance got no more resources left! Horde wins!");
                            //itr->second->GetPlayer()->GetGUID();
                            HandleWinMessage("For the HORDE!");
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
                            itr->second->GetPlayer()->TextEmote("[Hinterland Defence]: The Horde has no more resources left! Alliance wins!");
                            //itr->second->GetPlayer()->GetGUID();
                            HandleWinMessage("For the Alliance!");
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
    

    // marks the height of honour given for each NPC kill
    void OutdoorPvPHL::Randomizer(Player* player)
    {
        switch(urand(0, 4))
        {
            case 0:
                HandleRewards(player, 17, true, false, false); // Anpassen?
                break;
            case 1:
                HandleRewards(player, 11, true, false, false); // Anpassen?
                break;
            case 2:
                HandleRewards(player, 19, true, false, false); // Anpassen?
                break;
            case 3:
                HandleRewards(player, 22, true, false, false); // Anpassen?
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
            // prevent self-kill manipulation and ensure victim differs from killer
            if (player->GetGUID() == killed->GetGUID())
                return;
     
            switch(killed->ToPlayer()->GetTeamId())
            {
               case TEAM_ALLIANCE:
                    _ally_gathered -= PointsLoseOnPvPKill;
                    if (IsEligibleForRewards(player))
                    {
                        if (GetAfkCount(player) >= 2)
                        {
                            Whisper(player, "AFK penalty: no rewards for kills.");
                        }
                        else
                        {
					        player->AddItem(40752, 1);
                            Randomizer(player);
                        }
                    }
                    break;
               default: //Horde
                    _horde_gathered -= PointsLoseOnPvPKill;
                    if (IsEligibleForRewards(player))
                    {
                        if (GetAfkCount(player) >= 2)
                        {
                            Whisper(player, "AFK penalty: no rewards for kills.");
                        }
                        else
                        {
                            Randomizer(player);
					        player->AddItem(40752, 1);
                        }
                    }
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

    // Movement hook to feed movement-based AFK tracking
    class HLMovementHandlerScript : public MovementHandlerScript
    {
    public:
        HLMovementHandlerScript() : MovementHandlerScript("hl_movement_handler", { MOVEMENTHOOK_ON_PLAYER_MOVE }) {}

        void OnPlayerMove(Player* player, MovementInfo /*movementInfo*/, uint32 /*opcode*/) override
        {
            if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
                return;
            if (OutdoorPvP* pvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
            {
                if (auto* hl = dynamic_cast<OutdoorPvPHL*>(pvp))
                    hl->NotePlayerMovement(player);
            }
        }
    };

     
    void AddSC_outdoorpvp_hl()
    {
        new OutdoorPvP_hinterland;
        new HLMovementHandlerScript();
	}
