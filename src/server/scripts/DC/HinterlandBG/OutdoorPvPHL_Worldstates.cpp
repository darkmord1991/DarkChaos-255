// -----------------------------------------------------------------------------
// OutdoorPvPHL_Worldstates.cpp
// -----------------------------------------------------------------------------
// WG-style HUD helpers:
// - FillInitialWorldStates(): initial packet to prime client HUD state.
// - UpdateWorldStatesForPlayer(): refresh states for a specific player.
// - UpdateWorldStatesAllPlayers(): refresh for all participants in zone.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "WorldSessionMgr.h"
#include "WorldPacket.h"
#include <algorithm>

// Initialize the WG-like HUD states when a client first loads the worldstates
// Seed initial worldstates so clients render the Wintergrasp-like HUD elements.
void OutdoorPvPHL::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
{
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = GetHudEndEpoch();
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
    // Optional affix code worldstate for addon display
    if (_affixWorldstateEnabled)
        packet.Worldstates.emplace_back(WORLD_STATE_HL_AFFIX_TEXT, static_cast<uint32>(_activeAffix));
}

// Update HUD indicators (timer/resources) for a single player.
void OutdoorPvPHL::UpdateWorldStatesForPlayer(Player* player)
{
    if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
        return;
    player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
    uint32 endEpoch = GetHudEndEpoch();
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
    if (_affixWorldstateEnabled)
        player->SendUpdateWorldState(WORLD_STATE_HL_AFFIX_TEXT, static_cast<uint32>(_activeAffix));
}

// Refresh HUD for all players currently in the Hinterlands zone.
void OutdoorPvPHL::UpdateWorldStatesAllPlayers()
{
    // Use optimized version that avoids expensive GetAllSessions()
    UpdateWorldStatesAllPlayersOptimized();
}
