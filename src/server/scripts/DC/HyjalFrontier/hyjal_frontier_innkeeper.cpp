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

    bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override
    {
        // MUST return false.
        //
        // The old body built its own menu and returned true. That is what broke
        // the innkeeper: WorldSession::HandleGossipHelloOpcode only calls
        // Player::PrepareGossipMenu() + SendPreparedGossip() when the script
        // returns FALSE, and PrepareGossipMenu() is what turns the npcflag bits
        // into menu entries. Returning true therefore suppressed the
        // NPCFLAG_INNKEEPER "Make this inn your home" option entirely -- players
        // could not set their hearthstone at Innkeeper Cerelina (830023) at all.
        // The comment that used to sit here claimed the npcflag handled itself;
        // it does not, and nothing in this file ever added the bind option back.
        //
        // Returning false hands the whole menu (quests AND the innkeeper bind,
        // vendor, etc.) back to the core, which is exactly the default flow this
        // stub always meant to inherit. The hook is kept so tier-progression
        // flavour text can be added later -- but anything added here must either
        // keep returning false, or call PrepareGossipMenu() itself before
        // sending, or it will re-break the bind option the same way.
        return false;
    }
};

void AddSC_npc_hyjal_innkeeper()
{
    new npc_hyjal_innkeeper();
}
