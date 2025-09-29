/*
        .__      .___.                
        [__)  .    |   _ ._ _ ._ _   .
        [__)\_|    |  (_)[ | )[ | )\_|
                        ._|                    ._|

        Hinterland BG (OutdoorPvP HL)
        ------------------------------
        - Max-level gate: under-max players are teleported to capitals with a whisper.
        - Join UX: colored welcome + current standing as whispers; no zone broadcast on join.
        - HUD: Wintergrasp worldstates for SHOW/context/timer/resources with periodic refresh.
        - Timer: 60-minute match window with absolute end time.
        - Broadcasts: zone-wide status every 60s (time/resources), branded with an item-link prefix.
        - AFK/deserter: deserters get no rewards; AFK warn at 120s, action at 180s; any AFK infraction
            denies rewards; first AFK teleports to start GY, repeat AFK teleports to capital; GMs exempt.
        - Groups: per-faction BG-like raids, prune empties/offline; when raids shrink from 2→1, keep
            the remaining player in a new raid to avoid losing BG context.
        - Reset helper: teleports all in-zone players to their team start graveyards and refreshes HUD.
        - Diagnostics: logs around a ~60s empty-zone window to help verify NPC presence after emptiness.
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
        #include "GameObject.h"
    #include "DBCStores.h"
    #include "Misc/GameGraveyard.h"
    #include "Time/GameTime.h"
    #include "Config.h"
    
    #include "GroupMgr.h"
    #include "MapMgr.h"
    #include "ScriptDefines/MovementHandlerScript.h"
    #include <algorithm>
    #include <cmath>

    OutdoorPvPHL::OutdoorPvPHL()
    {
        _typeId = OUTDOOR_PVP_HL;
        // Set defaults for configurable values (can be overridden by LoadConfig)
        _matchDurationSeconds = HL_MATCH_DURATION_SECONDS;
        _afkWarnSeconds = 120;
        _afkTeleportSeconds = 180;
        _statusBroadcastEnabled = true;
        _statusBroadcastPeriodMs = 60 * IN_MILLISECONDS;
        _initialResourcesAlliance = HL_RESOURCES_A;
        _initialResourcesHorde = HL_RESOURCES_H;
        _rewardMatchHonor = 1500;
        _killHonorValues = { 17, 11, 19, 22 };
    _rewardKillItemId = 40752;
    _rewardKillItemCount = 1;
    _rewardNpcTokenItemId = 40752; // default to same token as kill item
    _rewardNpcTokenCount = 1;
    _npcRewardEntriesAlliance.clear();
    _npcRewardEntriesHorde.clear();
    _npcRewardCountsAlliance.clear();
    _npcRewardCountsHorde.clear();
        // Load overrides from config if available
        LoadConfig();

        _ally_gathered = _initialResourcesAlliance;
        _horde_gathered = _initialResourcesHorde;
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
    _hudRefreshTimerMs = 0;
        _statusBroadcastTimerMs = 0;
    _memberOfflineSince.clear();
    _zoneWasEmpty = false;

    }

    OutdoorPvPHL::~OutdoorPvPHL() = default;

    // Basic OutdoorPvP setup: register managed zones and derive the map id from the zone
    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        SetMapFromZone(OutdoorPvPHLBuffZones[0]);
        // Re-load configuration on setup
        LoadConfig();
        return true;
    }

    // Initialize the WG-like HUD states when a client first loads the worldstates
    void OutdoorPvPHL::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
    {
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = NowSec() + GetTimeRemainingSeconds();
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, GetResources(TEAM_HORDE));
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, GetResources(TEAM_ALLIANCE));
        uint32 maxVal = std::max(GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE));
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxVal);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxVal);
        // Provide WG context so the client renders the HUD: wartime + both teams
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0); // 0 during wartime (per WG implementation)
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE);
        // Some clients require CONTROL and ICON_ACTIVE to be present for full HUD render
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0);
        packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_ICON_ACTIVE, 0);
    }

    void OutdoorPvPHL::UpdateWorldStatesForPlayer(Player* player)
    {
        if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
            return;
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = NowSec() + GetTimeRemainingSeconds();
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, GetResources(TEAM_HORDE));
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, GetResources(TEAM_ALLIANCE));
        uint32 maxVal = std::max(GetResources(TEAM_ALLIANCE), GetResources(TEAM_HORDE));
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxVal);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxVal);
        // Provide WG context so the client renders the HUD: wartime + both teams
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE);
        // Include CONTROL and ICON states to match WG expectations
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_ICON_ACTIVE, 0);
    }

    void OutdoorPvPHL::UpdateWorldStatesAllPlayers()
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (auto const& it : sessionMap)
        {
            WorldSession* sess = it.second;
            if (!sess)
                continue;
            Player* p = sess->GetPlayer();
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
        // Deserters do not get rewards. AFK denial is handled in reward sites (kills/end) to allow GM exemptions.
        static constexpr uint32 BG_DESERTER_SPELL = 26013; // "Deserter"
        if (player->HasAura(BG_DESERTER_SPELL))
            return false;
        // AFK denial handled separately so we can consider GM mode.
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
    uint32 now = NowSec();
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
        // Reflect changes on clients in-zone
        UpdateWorldStatesAllPlayers();
    }

    
    std::vector<ObjectGuid> const& OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
    {
        if (team > TEAM_HORDE)
        {
            static const std::vector<ObjectGuid> empty;
            return empty;
        }
        return _teamRaidGroups[team];
    }

    void OutdoorPvPHL::ForceReset()
    {
        HandleReset();
    }

    void OutdoorPvPHL::TeleportPlayersToStart()
    {
        // Teleport all players in Hinterlands to their team startpoints.
        // We use the team-specific nearest graveyard as the start location.
        uint32 const zoneId = OutdoorPvPHLBuffZones[0];
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        uint32 countA = 0, countH = 0;
        for (auto const& it : sessionMap)
        {
            Player* p = it.second ? it.second->GetPlayer() : nullptr;
            if (!p || !p->IsInWorld() || p->GetZoneId() != zoneId)
                continue;
            TeamId team = p->GetTeamId();
            if (GraveyardStruct const* g = sGraveyard->GetClosestGraveyard(p, team))
            {
                p->TeleportTo(g->Map, g->x, g->y, g->z, p->GetOrientation());
                if (team == TEAM_ALLIANCE) ++countA; else ++countH;
            }
        }
        // Inform the zone
        char msg[128];
        snprintf(msg, sizeof(msg), "Hinterland BG: Resetting — teleported %u Alliance and %u Horde to start.", (unsigned)countA, (unsigned)countH);
        sWorldSessionMgr->SendZoneText(zoneId, msg);
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
            g->ConvertToRaid();
                        _rewardKillItemId = 40752; // default to same token as kill item
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
            Whisper(player, "You must be max level to join the Hinterland battle. Teleporting to your capital city.");
            // Teleport under-max-level players to their faction capital
            TeleportToCapital(player);
            return; // do not register enter to PvP logic
        }

    // If we are the first player after an empty-zone period, note it for NPC checks
    if (_playersInZone == 0 && _npcCheckTimerMs == 0 && _zoneWasEmpty)
    {
        LOG_INFO("misc", "[OutdoorPvPHL]: First player entered after ~1 minute of emptiness. Verify NPCs are present.");
        _zoneWasEmpty = false; // reset flag
    }

    // Welcome and current standing whisper (colored)
    Whisper(player, "|cffffd700Welcome to Hinterland BG!|r");
    Whisper(player, "Current standing — |cff1e90ffAlliance|r: " + std::to_string(_ally_gathered) + ", |cffff0000Horde|r: " + std::to_string(_horde_gathered) + ".");

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
             {
                 _npcCheckTimerMs = 60 * IN_MILLISECONDS; // start 1-minute empty-zone timer
                 _zoneWasEmpty = true;
             }
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
                        // If the group has exactly 2 members, remember the other member so we can keep their raid alive after removal
                        ObjectGuid otherGuid;
                        if (g->GetMembersCount() == 2)
                        {
                            for (auto const& slot : g->GetMemberSlots())
                                if (slot.guid != player->GetGUID()) { otherGuid = slot.guid; break; }
                        }

                        // Remove this player from the raid
                        g->RemoveMember(player->GetGUID());

                        // If group is now empty, disband and untrack
                        if (g->GetMembersCount() == 0)
                        {
                            g->Disband(true /*hideDestroy*/);
                            for (auto& vec : _teamRaidGroups)
                                vec.erase(std::remove(vec.begin(), vec.end(), gid), vec.end());
                        }
                        else if (g->GetMembersCount() == 1 && !otherGuid.IsEmpty())
                        {
                            // Core may auto-disband groups that shrink to 1. Ensure the remaining player stays in a BG raid by recreating it.
                            if (Player* other = ObjectAccessor::FindPlayer(otherGuid))
                            {
                                // If the remaining player lost their group or it is no longer a raid, create a fresh raid for them
                                Group* og = other->GetGroup();
                                if (!og || !og->isRaidGroup())
                                {
                                    Group* ng = new Group();
                                    if (ng->Create(other))
                                    {
                                        ng->ConvertToRaid();
                                        sGroupMgr->AddGroup(ng);
                                        _teamRaidGroups[other->GetTeamId()].push_back(ng->GetGUID());
                                        Whisper(other, "|cffffd700Your battleground raid remains active.|r");
                                    }
                                    else
                                    {
                                        delete ng;
                                    }
                                }
                            }
                            // Untrack the old group (it will be auto-disbanded by core when shrinking to 1)
                            for (auto& vec : _teamRaidGroups)
                                vec.erase(std::remove(vec.begin(), vec.end(), gid), vec.end());
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
        std::string full = GetBgChatPrefix() + std::string(message);
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], full.c_str());
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

    // Cosmetic: provide a Battleground-like item link prefix for chat/notifications
    // Example: |cff0070dd|Hitem:47241:0:0:0:0:0:0:0:0|h[Hinterland Defence]|h|r
    // Note: Using a harmless vanity item ID for link formatting. Only the text is shown; clicking opens an item tooltip.
    std::string OutdoorPvPHL::GetBgChatPrefix() const
    {
        // Blue-quality color for visibility (can be tuned); item ID 47241 (Emblem of Triumph) used as a neutral link host
        return "|cff0070dd|Hitem:47241:0:0:0:0:0:0:0:0|h[Hinterland Defence]|h|r ";
    }

    void OutdoorPvPHL::HandleReset()
    {
            // Reset match state to defaults and respawn NPCs and GOs in the Hinterlands zone.
            // 1) Reset timers/resources to initial values
            _ally_gathered = _initialResourcesAlliance;
            _horde_gathered = _initialResourcesHorde;
            _LastWin = 0;
            // New match window starts now
            _matchEndTime = uint32(GameTime::GetGameTime().count()) + _matchDurationSeconds;
            // Clear AFK flags and local trackers
            _afkInfractions.clear();
            _afkFlagged.clear();
            _memberOfflineSince.clear();
            // 2) Respawn/reset all NPCs and GOs in Hinterlands
            auto RespawnZoneObjects = [this]()
            {
                uint32 const zoneId = OutdoorPvPHLBuffZones[0];
                uint32 creatureCount = 0;
                uint32 goCount = 0;
                // Reset creatures (NPCs) in-zone
                for (auto const& kv : HashMapHolder<Creature>::GetContainer())
                {
                    Creature* c = kv.second;
                    if (!c || !c->IsInWorld())
                        continue;
                    if (c->GetZoneId() != zoneId)
                        continue;
                    // Skip players/pets/guardians etc. Only true world NPCs
                    if (c->IsPlayer() || c->IsPet() || c->IsTotem())
                        continue;
                    // Clear combat and auras, move back to respawn location, and ensure alive
                    c->CombatStop(true);
                    c->DeleteThreatList();
                    c->RemoveAllAuras();
                    float x, y, z, o;
                    c->GetRespawnPosition(x, y, z, &o);
                    c->NearTeleportTo(x, y, z, o, false);
                    if (!c->IsAlive())
                        c->Respawn(true);
                    c->SetFullHealth();
                    ++creatureCount;
                }
                // Reset gameobjects in-zone
                for (auto const& kv : HashMapHolder<GameObject>::GetContainer())
                {
                    GameObject* go = kv.second;
                    if (!go || !go->IsInWorld())
                        continue;
                    if (go->GetZoneId() != zoneId)
                        continue;
                    // Force respawn to default state
                    go->Respawn();
                    ++goCount;
                }
                LOG_INFO("outdoorpvp.hl", "[HL] Reset: respawned %u creatures and %u gameobjects in zone %u", creatureCount, goCount, zoneId);
            };
            RespawnZoneObjects();
            // 3) Update HUD for anyone in zone
            UpdateWorldStatesAllPlayers();

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;

        limit_A = 0;
        limit_H = 0;

        limit_resources_message_A = 0;
        limit_resources_message_H = 0;

        // seed a fresh timer window from now
        _matchEndTime = uint32(GameTime::GetGameTime().count()) + _matchDurationSeconds;
        //sLog->outMessage("[OutdoorPvPHL]: Hinterland: Reset Hinterland BG", 1,);
        LOG_INFO("misc", "[OutdoorPvPHL]: Reset Hinterland BG");
    // Push fresh HUD state to any players already in the zone
    UpdateWorldStatesAllPlayers();
    // Kick off immediate status broadcast after reset
    _statusBroadcastTimerMs = 1; // broadcast on next update tick
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
            Whisper(player, "|cffff0000You are not eligible for rewards (Deserter).|r");
            return;
        }
        // Deny any rewards if the player has at least one AFK infraction this match (GMs exempt)
        if (player && !player->IsGameMaster() && GetAfkCount(player) >= 1)
        {
            Whisper(player, "|cffff0000AFK penalty: you receive no rewards.|r");
            return;
        }
        uint32 amount = honorpointsorarena;
        char msg[250];
        uint32 _GetHonorPoints = player->GetHonorPoints();
        uint32 _GetArenaPoints = player->GetArenaPoints();

        if(honor)
        {
            player->SetHonorPoints(_GetHonorPoints + amount);
            snprintf(msg, 250, "|cffffd700You got %u bonus honor!|r", amount);
        }
        else if(arena)
        {
            player->SetArenaPoints(_GetArenaPoints + amount);
            snprintf(msg, 250, "|cffffd700You got %u additional arena points!|r", amount);
        }
        else if(both)
        {
            player->SetHonorPoints(_GetHonorPoints + amount);
            player->SetArenaPoints(_GetArenaPoints + amount);
            snprintf(msg, 250, "|cffffd700You got %u additional arena points and bonus honor!|r", amount);
        }
        HandleWinMessage(msg);
    }

    // AFK thresholds are configurable via LoadConfig()

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
                _matchEndTime = uint32(GameTime::GetGameTime().count()) + _matchDurationSeconds;
            _FirstLoad = true;
        }

        // Note: avoid blocking sleeps here; periodic announcements are handled by timer thresholds below.
        // If zone became empty, count down ~1 minute to help diagnose NPC respawn/cleanup cycles.
        if (_playersInZone == 0 && _npcCheckTimerMs > 0)
        {
            if (diff >= _npcCheckTimerMs)
            {
                _npcCheckTimerMs = 0;
                LOG_INFO("misc", "[OutdoorPvPHL]: Zone empty for ~60s. Check NPC presence on next join (possible 1 min despawn window).");
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

        // Stricter group lifecycle: remove empty raid groups promptly, but keep raids alive for a single remaining member
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
                else if (g->GetMembersCount() == 1)
                {
                    // Ensure the last player retains a BG raid
                    ObjectGuid lastGuid;
                    for (auto const& slot : g->GetMemberSlots()) { lastGuid = slot.guid; break; }
                    if (!lastGuid.IsEmpty())
                    {
                        if (Player* last = ObjectAccessor::FindPlayer(lastGuid))
                        {
                            Group* lg = last->GetGroup();
                            if (!lg || !lg->isRaidGroup())
                            {
                                Group* ng = new Group();
                                if (ng->Create(last))
                                {
                                    ng->ConvertToRaid();
                                    sGroupMgr->AddGroup(ng);
                                    _teamRaidGroups[tid].push_back(ng->GetGUID());
                                    Whisper(last, "|cffffd700Your battleground raid remains active.|r");
                                }
                                else
                                {
                                    delete ng;
                                }
                            }
                        }
                    }
                    // Untrack the old group; let core handle its lifecycle
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
                // Exempt GMs from AFK tracking entirely
                if (p->IsGameMaster())
                {
                    ClearAfkState(p);
                    continue;
                }
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
                if (idleSec >= _afkTeleportSeconds)
                {
                    if (!wasAfk)
                    {
                        _afkFlagged.insert(low);
                        IncrementAfk(p);
                        uint8 count = GetAfkCount(p);
                        if (count == 1)
                        {
                            Whisper(p, "|cffff0000AFK detected due to inactivity. You will not receive rewards.|r You'll be moved back to the starting area.");
                            if (GraveyardStruct const* g = sGraveyard->GetClosestGraveyard(p, p->GetTeamId()))
                                p->TeleportTo(g->Map, g->x, g->y, g->z, p->GetOrientation());
                        }
                        else if (count >= 2)
                        {
                            Whisper(p, "|cffff0000Repeated AFK detected. You will be teleported to your capital and will not receive rewards.|r");
                            TeleportToCapital(p);
                        }
                    }
                }
                else if (idleSec >= _afkWarnSeconds)
                {
                    if (!_playerWarnedBeforeTeleport[p->GetGUID()])
                    {
                        uint32 secondsLeft = (_afkTeleportSeconds > idleSec) ? (_afkTeleportSeconds - idleSec) : 0u;
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
                        Whisper(p, "|cffff0000AFK detected. You will not receive rewards.|r A second AFK will teleport you to your capital.");
                    else if (count >= 2)
                    {
                        Whisper(p, "|cffff0000Repeated AFK detected. You will be teleported to your capital and will not receive rewards.|r");
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

        // Periodic HUD refresh to keep timer/resources visible (every 10s)
        if (_playersInZone > 0)
        {
            if (_hudRefreshTimerMs <= diff)
            {
                UpdateWorldStatesAllPlayers();
                _hudRefreshTimerMs = 10 * IN_MILLISECONDS;
            }
            else
            {
                _hudRefreshTimerMs -= diff;
            }
        }

        // Periodic status broadcast only if enabled and there are players in the zone
        if (_playersInZone > 0 && _statusBroadcastEnabled)
        {
            if (_statusBroadcastTimerMs <= diff)
            {
                BroadcastStatusToZone();
                _statusBroadcastTimerMs = _statusBroadcastPeriodMs;
            }
            else
            {
                _statusBroadcastTimerMs -= diff;
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
                    if(limit_resources_message_A == 1 || limit_resources_message_A == 2 || limit_resources_message_A == 3)
                    {
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cff1e90ff[Hinterland Defence]: The Alliance has resources left!|r").c_str());
                    }
                    else if(limit_resources_message_H == 1 || limit_resources_message_H == 2 || limit_resources_message_H == 3)
                    {
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cffff0000[Hinterland Defence]: The Horde has resources left!|r").c_str());
                    }
     
                    if(IS_RESOURCE_MESSAGE_A == true)
                    {
                        if(limit_A == 1)
                        {
                            itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cff1e90ff[Hinterland Defence]: The Alliance has resources left!|r").c_str());
                            IS_RESOURCE_MESSAGE_A = false; // Reset
                        }
                        else if(limit_A == 2)
                        {
                            itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cff1e90ff[Hinterland Defence]: The Alliance has no more resources left!|r |cffff0000Horde wins!|r").c_str());
                            //itr->second->GetPlayer()->GetGUID();
                            HandleWinMessage("|cffff0000For the HORDE!|r");
                            HandleRewards(itr->second->GetPlayer(), _rewardMatchHonor, true, false, false);
                            
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
                            itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cffff0000[Hinterland Defence]: The Horde has resources left!|r").c_str());
                            IS_RESOURCE_MESSAGE_H = false; // Reset
                        }
                        else if(limit_H == 2)
                        {
                            itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + "|cffff0000[Hinterland Defence]: The Horde has no more resources left!|r |cff1e90ffAlliance wins!|r").c_str());
                            //itr->second->GetPlayer()->GetGUID();
                            HandleWinMessage("|cff1e90ffFor the Alliance!|r");
                            HandleRewards(itr->second->GetPlayer(), _rewardMatchHonor, true, false, false);
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

    void OutdoorPvPHL::BroadcastStatusToZone()
    {
        // Build lines that mirror .hlbg status
        uint32 secs = GetTimeRemainingSeconds();
        uint32 min = secs / 60u;
        uint32 sec = secs % 60u;
        uint32 a = GetResources(TEAM_ALLIANCE);
        uint32 h = GetResources(TEAM_HORDE);

        // Compose strings
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + "|cffffd700Hinterland BG status:|r").c_str());
        char line1[64];
        snprintf(line1, sizeof(line1), "  Time remaining: %02u:%02u", (unsigned)min, (unsigned)sec);
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line1)).c_str());
        char line2[96];
        snprintf(line2, sizeof(line2), "  Resources: |cff1e90ffAlliance|r=%u, |cffff0000Horde|r=%u", (unsigned)a, (unsigned)h);
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line2)).c_str());

        // Optional: log for server visibility
        LOG_DEBUG("misc", "[HLBG] Broadcast status: %02u:%02u A=%u H=%u", (unsigned)min, (unsigned)sec, (unsigned)a, (unsigned)h);
    }
    

    // marks the height of honour given for each NPC kill
    void OutdoorPvPHL::Randomizer(Player* player)
    {
        switch(urand(0, 4))
        {
            case 0:
            {
                uint32 v = (_killHonorValues.size() > 0 ? _killHonorValues[0] : 17);
                HandleRewards(player, v, true, false, false);
            }
                break;
            case 1:
            {
                uint32 v = (_killHonorValues.size() > 1 ? _killHonorValues[1] : 11);
                HandleRewards(player, v, true, false, false);
            }
                break;
            case 2:
            {
                uint32 v = (_killHonorValues.size() > 2 ? _killHonorValues[2] : 19);
                HandleRewards(player, v, true, false, false);
            }
                break;
            case 3:
            {
                uint32 v = (_killHonorValues.size() > 3 ? _killHonorValues[3] : 22);
                HandleRewards(player, v, true, false, false);
            }
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
                        if (!player->IsGameMaster() && GetAfkCount(player) >= 1)
                        {
                            Whisper(player, "|cffff0000AFK penalty: no rewards for kills.|r");
                        }
                        else
                        {
					        player->AddItem(40752, 1);
                            Randomizer(player);
                            if (_rewardKillItemId && _rewardKillItemCount)
                                player->AddItem(_rewardKillItemId, _rewardKillItemCount);
                        }
                    }
                    break;
               default: //Horde
                    _horde_gathered -= PointsLoseOnPvPKill;
                    if (IsEligibleForRewards(player))
                    {
                        if (!player->IsGameMaster() && GetAfkCount(player) >= 1)
                        {
                            Whisper(player, "|cffff0000AFK penalty: no rewards for kills.|r");
                        }
                        else
                        {
                            Randomizer(player);
                            if (_rewardKillItemId && _rewardKillItemCount)
                                player->AddItem(_rewardKillItemId, _rewardKillItemCount);
                        }
                    }
                    break;
            }
            // Update HUD for all participants after resource change
            UpdateWorldStatesAllPlayers();
        }
        else // If is something besides a player
        {
            uint32 entry = killed->GetEntry();
            // Configured NPC token rewards (up to 10 entries per team via config)
            if (player->GetTeamId() == TEAM_ALLIANCE)
            {
                if (!_npcRewardEntriesHorde.empty() && std::find(_npcRewardEntriesHorde.begin(), _npcRewardEntriesHorde.end(), entry) != _npcRewardEntriesHorde.end())
                {
                    if (_rewardNpcTokenItemId)
                    {
                        uint32 count = _rewardNpcTokenCount;
                        auto itc = _npcRewardCountsHorde.find(entry);
                        if (itc != _npcRewardCountsHorde.end())
                            count = itc->second;
                        if (count)
                        {
                            player->AddItem(_rewardNpcTokenItemId, count);
                            Whisper(player, "You received " + std::to_string(count) + " token(s) for defeating a marked enemy NPC.");
                        }
                    }
                }
            }
            else // TEAM_HORDE
            {
                if (!_npcRewardEntriesAlliance.empty() && std::find(_npcRewardEntriesAlliance.begin(), _npcRewardEntriesAlliance.end(), entry) != _npcRewardEntriesAlliance.end())
                {
                    if (_rewardNpcTokenItemId)
                    {
                        uint32 count = _rewardNpcTokenCount;
                        auto itc = _npcRewardCountsAlliance.find(entry);
                        if (itc != _npcRewardCountsAlliance.end())
                            count = itc->second;
                        if (count)
                        {
                            player->AddItem(_rewardNpcTokenItemId, count);
                            Whisper(player, "You received " + std::to_string(count) + " token(s) for defeating a marked enemy NPC.");
                        }
                    }
                }
            }

            if(player->GetTeamId() == TEAM_ALLIANCE)
            {
                switch(entry) // Alliance killing horde guards
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
                switch(entry) // Horde killing alliance guards
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
            // Update HUD for all participants after resource change
            UpdateWorldStatesAllPlayers();
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

    void OutdoorPvPHL::LoadConfig()
    {
        // Read options that may come from worldserver.conf or modules configs.
        // Note: The modules config loader (modules/CMakeLists CONFIG_LIST) handles copying
        // and loading hinterlandbg.conf(.dist) under configs/modules automatically.
        if (sConfigMgr)
        {
            _matchDurationSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.MatchDuration", _matchDurationSeconds);
            _afkWarnSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.WarnSeconds", _afkWarnSeconds);
            _afkTeleportSeconds = sConfigMgr->GetOption<uint32>("HinterlandBG.AFK.TeleportSeconds", _afkTeleportSeconds);
            _statusBroadcastEnabled = sConfigMgr->GetOption<bool>("HinterlandBG.Broadcast.Enabled", _statusBroadcastEnabled);
            uint32 periodSec = sConfigMgr->GetOption<uint32>("HinterlandBG.Broadcast.Period", _statusBroadcastPeriodMs / IN_MILLISECONDS);
            _statusBroadcastPeriodMs = periodSec * IN_MILLISECONDS;
            _initialResourcesAlliance = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Alliance", _initialResourcesAlliance);
            _initialResourcesHorde = sConfigMgr->GetOption<uint32>("HinterlandBG.Resources.Horde", _initialResourcesHorde);
            _rewardMatchHonor = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.MatchHonor", _rewardMatchHonor);
            _rewardKillItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemId", _rewardKillItemId);
            _rewardKillItemCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.KillItemCount", _rewardKillItemCount);
            _rewardNpcTokenItemId = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemId", _rewardNpcTokenItemId);
            _rewardNpcTokenCount = sConfigMgr->GetOption<uint32>("HinterlandBG.Reward.NPCTokenItemCount", _rewardNpcTokenCount);
            std::string csv = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.KillHonorValues", "");
            if (!csv.empty())
            {
                std::vector<uint32> parsed;
                size_t start = 0;
                while (start < csv.size())
                {
                    size_t comma = csv.find(',', start);
                    std::string token = csv.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
                    try { uint32 v = static_cast<uint32>(std::stoul(token)); parsed.push_back(v); } catch (...) {}
                    if (comma == std::string::npos) break; else start = comma + 1;
                }
                if (!parsed.empty())
                    _killHonorValues = std::move(parsed);
            }
        }
            // Parse Alliance NPC reward entries (CSV of entry IDs)
            auto parseCsvU32 = [](std::string const& in) -> std::vector<uint32>
            {
                std::vector<uint32> out;
                size_t start = 0;
                while (start < in.size())
                {
                    size_t comma = in.find(',', start);
                    std::string token = in.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
                    try { if (!token.empty()) out.push_back(static_cast<uint32>(std::stoul(token))); } catch (...) {}
                    if (comma == std::string::npos) break; else start = comma + 1;
                }
                return out;
            };
            std::string aList = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesAlliance", "");
            std::string hList = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntriesHorde", "");
            if (!aList.empty()) _npcRewardEntriesAlliance = parseCsvU32(aList);
            if (!hList.empty()) _npcRewardEntriesHorde = parseCsvU32(hList);

            // Optional per-NPC token counts: CSV "entry:count" pairs per team
            auto parseEntryCounts = [](std::string const& in) -> std::unordered_map<uint32, uint32>
            {
                std::unordered_map<uint32, uint32> out;
                size_t start = 0;
                while (start < in.size())
                {
                    size_t comma = in.find(',', start);
                    std::string pair = in.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
                    size_t colon = pair.find(':');
                    if (colon != std::string::npos)
                    {
                        try {
                            uint32 entry = static_cast<uint32>(std::stoul(pair.substr(0, colon)));
                            uint32 count = static_cast<uint32>(std::stoul(pair.substr(colon + 1)));
                            if (entry && count)
                                out[entry] = count;
                        } catch (...) {}
                    }
                    if (comma == std::string::npos) break; else start = comma + 1;
                }
                return out;
            };
            std::string aCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsAlliance", "");
            std::string hCounts = sConfigMgr->GetOption<std::string>("HinterlandBG.Reward.NPCEntryCountsHorde", "");
            if (!aCounts.empty()) _npcRewardCountsAlliance = parseEntryCounts(aCounts);
            if (!hCounts.empty()) _npcRewardCountsHorde = parseEntryCounts(hCounts);
    }

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
