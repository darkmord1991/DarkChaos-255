/*
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef DC_CROSSSYSTEM_QUEST_PHASE_LAYER_H
#define DC_CROSSSYSTEM_QUEST_PHASE_LAYER_H

#include "Define.h"

class Player;

// Quest-driven phasing (world.dc_quest_phase). A rule adds phase bits to a player on one map while
// one of their quests is in one of the given states, spell_area style: quest_status_mask is a mask
// of (1 << QuestStatus) -- 1 none, 2 complete, 8 incomplete, 32 failed, 64 rewarded -- plus 128 =
// turned in at least once, which also holds for repeatable and daily quests (those report NONE again
// after the turn-in, so 64 never matches them). A rule may name a second quest (quest2 /
// quest2_status_mask) that must match as well; rules with the same bit OR.
//
// The bits go on the player as an ADDITIVE phase layer (PhaseLayers::QuestPhase), so phase 1 stays
// visible: content spawned in phase 1 is untouched, and content spawned ONLY in a rule's bit is
// shown to exactly the players the rule matches. A WotLK phase aura would replace phase 1 instead,
// which is why the downported maps (every spawn in phase 1) cannot use spell_area for this.
// Server side only; the 3.3.5 client needs nothing.
namespace DarkChaos::QuestPhase
{
    // Every bit a rule can hand out on this map, for phase allocators that must keep clear of them
    [[nodiscard]] uint32 BitsOnMap(uint32 mapId);

    // Recompute the player's quest phase layer from their current map and quest log
    void Refresh(Player* player);
}

#endif
