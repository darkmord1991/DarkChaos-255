/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier - innkeeper stub.
 *
 * Currently just inherits the default innkeeper gossip flow (set_homebind).
 * Hook exists so we can later add level-based dialogue + lore flavor.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptedGossip.h"

class npc_hyjal_innkeeper : public CreatureScript
{
public:
    npc_hyjal_innkeeper() : CreatureScript("npc_hyjal_innkeeper") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Default innkeeper menu (SetHomebind / bind point) is handled by the
        // NPCFLAG_INNKEEPER bit; we only override to optionally add
        // tier-progression flavor text here.
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }
};

void AddSC_npc_hyjal_innkeeper()
{
    new npc_hyjal_innkeeper();
}
