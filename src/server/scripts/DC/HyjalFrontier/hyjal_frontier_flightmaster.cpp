/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier - flightmaster stub.
 *
 * STATUS (audited 2026-07-20): the remaining work is DATA, not code. The core's
 * own flightmaster flow handles the menu, known/unknown nodes and the taxi map
 * once the data exists -- this hook does not need to build any of it (and must
 * not try; see OnGossipHello below for what happened when it did).
 *   - Register per-tier flight nodes in TaxiNodes.dbc (IDs 350-359 reserved)
 *     and wire them to these NPCs.
 *   - Gate destinations by level (Foothills at 80, Summit at 110, etc.).
 *   - None of the five templates (830020, 830145, 830158, 830159, 830160) are
 *     spawned yet, so nothing here is player-visible today.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptedGossip.h"

class npc_hyjal_flightmaster : public CreatureScript
{
public:
    npc_hyjal_flightmaster() : CreatureScript("npc_hyjal_flightmaster") { }

    bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override
    {
        // MUST return false -- same trap as the innkeeper stub.
        //
        // The old body sent its own menu and returned true, which stops
        // WorldSession::HandleGossipHelloOpcode from calling
        // Player::PrepareGossipMenu(). That call is what turns NPCFLAG_FLIGHTMASTER
        // (these templates carry npcflag 8193 = GOSSIP|FLIGHTMASTER) into the
        // taxi option, so the script silently ate the flight menu and left an
        // NPC you could talk to but never fly from. It has not bitten anyone yet
        // only because all five templates (830020, 830145, 830158, 830159,
        // 830160) currently have zero spawns -- it would have broken the moment
        // they were placed.
        //
        // The core's default flightmaster flow (SendTaxiMenu, known/unknown node
        // handling, the taxi map) is complete and correct on its own; this stub
        // never needed to replace it. The old TODO about enumerating nodes is
        // also moot for the menu itself -- nodes are DB/DBC data (TaxiNodes.dbc
        // + npc_taxi wiring), not something this hook has to build.
        return false;
    }

    // OnGossipSelect deliberately NOT overridden any more. The old override
    // swallowed EVERY selection (it just cleared and closed the window), which
    // would also have blocked the core's own taxi-node selection handling.
};

void AddSC_npc_hyjal_flightmaster()
{
    new npc_hyjal_flightmaster();
}
