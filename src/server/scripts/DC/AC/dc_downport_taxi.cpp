/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Gossip flight master for the downported continents Mount Hyjal (map 750) and
 * Plaguelands (map 751).
 *
 * The flight network itself lives in TaxiNodes/TaxiPath/TaxiPathNode.dbc (see
 * Custom/CSV DBC). Rather than rely on the client rendering the taxi map for a
 * custom continent (which needs WorldMapContinent bounds the client may not have
 * for these maps), every flight master presents its destinations as a gossip
 * list and starts the flight with ActivateTaxiPathTo — the same approach the
 * custom leveling-camp flight masters use (AC/ac_flightmasters.cpp).
 *
 * One script drives every flight master on both maps: the current node is
 * resolved from the creature's position against the node table below, so the
 * only per-NPC wiring is creature_template.ScriptName = 'npc_dc_downport_flightmaster'.
 */

#include "Creature.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
#include "DC/CrossSystem/CrossSystemUtilities.h"
#include <cmath>

namespace
{
    struct FlightNode
    {
        uint32 nodeId;
        uint32 mapId;
        float  x;
        float  y;
        float  z;
        char const* name;
    };

    // Keep in sync with Custom/CSV DBC/TaxiNodes.csv (ids 421-437).
    constexpr FlightNode kNodes[] =
    {
        // Mount Hyjal (map 750)
        { 421, 750, 5167.74f, -1761.50f, 1339.16f, "Sanctuary of Malorne" },
        { 422, 750, 4394.19f, -2107.44f, 1204.37f, "Nordrassil" },
        { 423, 750, 4994.58f, -2678.85f, 1426.71f, "Grove of Aessina" },
        { 424, 750, 5584.20f, -3567.47f, 1570.61f, "Shrine of Aviana" },
        { 425, 750, 4062.76f, -3969.84f,  970.40f, "Sethria's Roost" },
        // Plaguelands (map 751)
        { 426, 751,  928.66f, -1429.06f,   64.74f, "Chillwind Camp" },
        { 427, 751, 2268.80f, -5345.42f,   87.02f, "Light's Hope Chapel" },
        { 428, 751, 2348.63f, -5669.29f,  382.32f, "The Ebon Hold" },
        { 429, 751, 1939.44f, -2694.39f,   62.15f, "Thondoril River" },
        { 430, 751, 2526.09f, -4772.52f,  104.32f, "Eastwall Tower" },
        { 431, 751, 2264.55f, -4414.64f,  111.78f, "Corin's Crossing" },
        { 432, 751, 1879.72f, -3694.56f,  157.77f, "Crown Guard Tower" },
        { 433, 751, 2968.76f, -3031.63f,  126.91f, "Plaguewood Tower" },
        { 434, 751, 1511.60f, -1583.94f,   64.69f, "The Bulwark" },
        { 435, 751, 1372.11f, -1277.58f,   59.59f, "Sorrow Hill" },
        { 436, 751, 1869.61f, -1754.99f,   60.15f, "Andorhal" },
        { 437, 751, 2837.17f, -1503.59f,  146.02f, "Northdale" },
    };

    constexpr char const* TAXI_ICON = "Interface\\Icons\\Ability_Mount_Wyvern_01";

    // Resolve the flight node this creature stands on (nearest node on its map).
    FlightNode const* CurrentNode(Creature const* creature)
    {
        FlightNode const* best = nullptr;
        float bestDist = 0.0f;
        for (FlightNode const& node : kNodes)
        {
            if (node.mapId != creature->GetMapId())
            {
                continue;
            }

            float const dx = node.x - creature->GetPositionX();
            float const dy = node.y - creature->GetPositionY();
            float const dz = node.z - creature->GetPositionZ();
            float const dist = dx * dx + dy * dy + dz * dz;
            if (!best || dist < bestDist)
            {
                best = &node;
                bestDist = dist;
            }
        }
        return best;
    }

    std::string FormatCost(uint32 copper)
    {
        uint32 const gold = copper / 10000;
        uint32 const silver = (copper % 10000) / 100;
        uint32 const cop = copper % 100;
        if (gold)
        {
            return Acore::StringFormat("{}g {}s {}c", gold, silver, cop);
        }
        if (silver)
        {
            return Acore::StringFormat("{}s {}c", silver, cop);
        }
        return Acore::StringFormat("{}c", cop);
    }
}

class npc_dc_downport_flightmaster : public CreatureScript
{
public:
    npc_dc_downport_flightmaster() : CreatureScript("npc_dc_downport_flightmaster") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
        {
            player->PrepareQuestMenu(creature->GetGUID());
        }

        FlightNode const* current = CurrentNode(creature);
        if (current)
        {
            for (FlightNode const& dest : kNodes)
            {
                if (dest.mapId != current->mapId || dest.nodeId == current->nodeId)
                {
                    continue;
                }

                uint32 path = 0;
                uint32 cost = 0;
                sObjectMgr->GetTaxiPath(current->nodeId, dest.nodeId, path, cost);
                if (!path)
                {
                    continue;
                }

                float const discount = player->GetReputationPriceDiscount(creature);
                uint32 const finalCost = uint32(std::ceil(cost * discount));

                std::string const text = DCUtils::MakeLargeGossipText(TAXI_ICON,
                    Acore::StringFormat("Fly to {} ({})", dest.name, FormatCost(finalCost)));
                AddGossipItemFor(player, GOSSIP_ICON_TAXI, text, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + dest.nodeId);
            }
        }

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action < GOSSIP_ACTION_INFO_DEF)
        {
            return true;
        }

        uint32 const destNode = action - GOSSIP_ACTION_INFO_DEF;
        FlightNode const* current = CurrentNode(creature);
        if (!current || destNode == current->nodeId)
        {
            return true;
        }

        player->ActivateTaxiPathTo({ current->nodeId, destNode }, creature, 1);
        return true;
    }
};

void AddSC_dc_downport_taxi()
{
    new npc_dc_downport_flightmaster();
}
