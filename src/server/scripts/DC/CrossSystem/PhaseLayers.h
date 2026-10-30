/*
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef DC_CROSSSYSTEM_PHASE_LAYERS_H
#define DC_CROSSSYSTEM_PHASE_LAYERS_H

#include "Define.h"

// The phase layers DarkChaos systems own on a player (Player::SetPhaseLayer): one id per system, so a
// system takes off only what it put on and never saves or restores another system's mask.
//
// Phase bits the systems hand out, and where. A bit only means something on one map, so two systems
// may share a bit on different maps; Phased Duels keeps clear of every reservation on its map.
//   Phased Duels      bits 1-29, per map instance, never a bit spawned content uses there
//   Training grounds  bits 20-30, map 745 (Jade Forest), one per training session
//   World bosses      bit 30, map 1405 (Giant Isles), anti-grief fights (off by default)
namespace DarkChaos::PhaseLayers
{
    enum : uint32
    {
        PhasedDuel          = 1,   // exclusive: the duel's bit
        PhasedDuelSpectator = 2,   // exclusive: the watched duel's bit
        TrainingGrounds     = 3,   // additive: the session's personal bit
        WorldBossFight      = 4,   // exclusive: the fight's bit
    };

    constexpr uint32 TRAINING_GROUNDS_MAP = 745;
    constexpr uint32 TRAINING_GROUNDS_BITS = 0x7FF00000;   // bits 20-30

    // The bits a system reserves on a map, for allocators that must keep clear of them
    inline uint32 ReservedBitsOnMap(uint32 mapId)
    {
        return mapId == TRAINING_GROUNDS_MAP ? TRAINING_GROUNDS_BITS : 0;
    }
}

#endif
