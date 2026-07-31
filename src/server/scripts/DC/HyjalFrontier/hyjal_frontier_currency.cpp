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

    bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override
    {
        // Return false and let the core drive it.
        //
        // The old body force-opened the shop with SendListInventory() AND sent a
        // gossip window in the same breath -- two overlapping frames -- then
        // returned true, which suppressed Player::PrepareGossipMenu() and with it
        // the normal "I'd like to browse your goods" entry. This NPC is
        // npcflag 129 (GOSSIP|VENDOR), so the core produces exactly the right
        // menu (quests + browse goods) on its own.
        //
        // TODO (unchanged, and NOT what the old code did): gate the stock list by
        // the zone-wide "Tree Health" tier. That belongs in `npc_vendor` +
        // `conditions` (CONDITION_SOURCE_TYPE_NPC_VENDOR), not in this hook --
        // filtering here cannot affect what the core sends and would need the
        // whole vendor flow reimplemented to work.
        return false;
    }
};

void AddSC_npc_hyjal_emberwood_vendor()
{
    new npc_hyjal_emberwood_vendor();
}
