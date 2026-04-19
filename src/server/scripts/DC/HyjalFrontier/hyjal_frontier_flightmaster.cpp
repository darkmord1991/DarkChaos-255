/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier - flightmaster stub.
 *
 * Implementation plan:
 *   - Register per-tier flight nodes in TaxiNodes.dbc (IDs 350-359 reserved).
 *   - Gate destinations by player level (Foothills at 80, Summit at 110, etc.).
 *   - Fallback gossip teleport when a node is not yet learned.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptedGossip.h"

class npc_hyjal_flightmaster : public CreatureScript
{
public:
    npc_hyjal_flightmaster() : CreatureScript("npc_hyjal_flightmaster") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // TODO: enumerate Hyjal taxi nodes and show them via
        //       SendTaxiMenu / AddGossipItemFor once DBC nodes are registered.
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 /*action*/) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_npc_hyjal_flightmaster()
{
    new npc_hyjal_flightmaster();
}
