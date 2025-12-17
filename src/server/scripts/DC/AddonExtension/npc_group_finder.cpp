/*
 * Dark Chaos - Group Finder NPC
 * =============================
 * 
 * Simplified to only trigger the client-side addon interface.
 * 
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "DCAddonGroupFinder.h"

namespace DCAddon
{

// NPC Entry ID - Update this in SQL to match your creature template
[[maybe_unused]] constexpr uint32 NPC_GROUP_FINDER = 600100;

class npc_group_finder : public CreatureScript
{
public:
    npc_group_finder() : CreatureScript("npc_group_finder") {}

    bool OnGossipHello(Player* player, Creature* /*creature*/) override
    {
        if (!player)
            return false;

        // Trigger the addon interface
        DCAddon::GroupFinder::SendOpenGroupFinder(player);
        
        // Close any existing gossip menu just in case
        CloseGossipMenuFor(player);
        
        return true;
    }
};

} // namespace DCAddon

void AddSC_npc_group_finder()
{
    new DCAddon::npc_group_finder();
}
