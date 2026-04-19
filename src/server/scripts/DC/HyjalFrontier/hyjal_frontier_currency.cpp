/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier - Emberwood Sap vendor (stub).
 *
 * The "Emberwood Sap" currency is a drop token from all Hyjal Frontier mobs.
 * This NPC redeems sap for tiered reward items in the 400000-400999 block.
 *
 * Implementation plan:
 *   - Backing currency: item entry 400000 "Emberwood Sap" (stackable 5000).
 *   - Tier unlocks gated by the zone-wide "Tree Health" server variable
 *     (hooked via SessionContext / DC.sav world state later).
 *   - For now: direct vendor_items list pulled from `npc_vendor` once the
 *     tier catalog is designed.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptedGossip.h"

class npc_hyjal_emberwood_vendor : public CreatureScript
{
public:
    npc_hyjal_emberwood_vendor() : CreatureScript("npc_hyjal_emberwood_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Present the stock list via standard vendor flow.
        // TODO: filter by current "Tree Health" tier.
        if (creature->IsVendor())
            player->GetSession()->SendListInventory(creature->GetGUID());

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }
};

void AddSC_npc_hyjal_emberwood_vendor()
{
    new npc_hyjal_emberwood_vendor();
}
