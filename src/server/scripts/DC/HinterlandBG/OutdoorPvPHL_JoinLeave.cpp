// -----------------------------------------------------------------------------
// OutdoorPvPHL_JoinLeave.cpp
// -----------------------------------------------------------------------------
// Player zone entry/exit handlers for Hinterland BG:
// - HandlePlayerEnterZone: max-level gate, welcome whispers, AFK tracker seed,
//   auto-join faction raid, and HUD seed.
// - HandlePlayerLeaveZone: emote warning, decrement counts, AFK cleanup, and
//   raid membership maintenance (preserve 2→1 by re-creating a raid).
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "ObjectAccessor.h"
#include "GroupMgr.h"
#include <algorithm>
#include <algorithm>

// Called when a player enters the Hinterlands zone managed by this OutdoorPvP.
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

// Called when a player leaves the Hinterlands zone.
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
