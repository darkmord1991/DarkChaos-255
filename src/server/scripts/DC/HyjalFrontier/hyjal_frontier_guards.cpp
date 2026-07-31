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
    // NOTE: the GOSSIP_FLIGHTMASTER / GOSSIP_INNKEEPER / GOSSIP_QUARTERMASTER
    // action ids that used to live here were never referenced by anything --
    // the "directions" gossip they were meant for was never written. Removed
    // rather than left as dangling constants; re-add them WITH the menu when
    // the directions feature is actually implemented.
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

    // Return false: let the core build the menu (quests + any npcflag options).
    // Overriding it to send a bare menu and return true suppressed
    // Player::PrepareGossipMenu() -- harmless while these guards carry npcflag 0,
    // but the same defect that broke the innkeeper and flightmaster stubs, so it
    // is not left lying around. TODO (unchanged): add directional gossip items
    // once the Hyjal Frontier service-NPC positions are settled -- and when doing
    // so, keep returning false or call PrepareGossipMenu() explicitly first.
    bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override
    {
        return false;
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

    // See the Alliance guard above -- same reason for returning false.
    bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override
    {
        return false;
    }
};

void AddSC_npc_hyjal_guard_alliance() { new npc_hyjal_guard_alliance(); }
void AddSC_npc_hyjal_guard_horde()    { new npc_hyjal_guard_horde(); }
