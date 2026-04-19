/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier - base camp guards (Alliance + Horde).
 *
 * Implementation plan (stubbed):
 *   - Reuse GuardAI for basic aggro/assist behaviour.
 *   - Add a directions gossip menu: flightmaster / innkeeper / quartermaster.
 *   - Optional: assist any non-hostile faction in Jaina's / Thrall's camps so
 *     CFBG cross-faction players aren't attacked by their own guards.
 */

#include "ScriptMgr.h"
#include "GuardAI.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptedGossip.h"

namespace
{
    enum HyjalGuardGossip
    {
        GOSSIP_FLIGHTMASTER   = 1,
        GOSSIP_INNKEEPER      = 2,
        GOSSIP_QUARTERMASTER  = 3,
    };
}

class npc_hyjal_guard_alliance : public CreatureScript
{
public:
    npc_hyjal_guard_alliance() : CreatureScript("npc_hyjal_guard_alliance") { }

    struct npc_hyjal_guard_allianceAI : public GuardAI
    {
        npc_hyjal_guard_allianceAI(Creature* creature) : GuardAI(creature) { }
        // TODO: extend with assist logic once faction layout is finalized.
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hyjal_guard_allianceAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // TODO: add directional gossip items once NPC positions are known.
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }
};

class npc_hyjal_guard_horde : public CreatureScript
{
public:
    npc_hyjal_guard_horde() : CreatureScript("npc_hyjal_guard_horde") { }

    struct npc_hyjal_guard_hordeAI : public GuardAI
    {
        npc_hyjal_guard_hordeAI(Creature* creature) : GuardAI(creature) { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hyjal_guard_hordeAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }
};

void AddSC_npc_hyjal_guard_alliance() { new npc_hyjal_guard_alliance(); }
void AddSC_npc_hyjal_guard_horde()    { new npc_hyjal_guard_horde(); }
