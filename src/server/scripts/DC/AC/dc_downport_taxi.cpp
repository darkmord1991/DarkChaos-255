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

    // Keep in sync with Custom/CSV DBC/TaxiNodes.csv (ids 421-437). Names and
    // coordinates are the matched retail Cata taxi nodes (gen_taxi.py).
    constexpr FlightNode kNodes[] =
    {
        // Mount Hyjal (map 750)
        { 421, 750, 5163.51f, -1760.58f, 1338.47f, "Grove of Aessina, Hyjal" },
        { 422, 750, 4397.79f, -2107.53f, 1204.34f, "Sanctuary of Malorne, Hyjal" },
        { 423, 750, 4987.87f, -2676.19f, 1426.36f, "Shrine of Aviana, Hyjal" },
        { 424, 750, 5584.06f, -3569.84f, 1570.60f, "Nordrassil, Hyjal" },
        { 425, 750, 4059.40f, -3966.75f,  970.15f, "Gates of Sothann, Hyjal" },
        // Plaguelands (map 751)
        { 426, 751,  931.32f, -1430.11f,   64.67f, "Chillwind Camp, Western Plaguelands" },
        { 427, 751, 2270.20f, -5343.11f,   86.97f, "Light's Hope Chapel, Eastern Plaguelands" },
        { 428, 751, 2352.37f, -5666.91f,  382.24f, "Acherus: The Ebon Hold" },
        { 429, 751, 1935.97f, -2694.48f,   61.95f, "Thondroril River, Eastern Plaguelands" },
        { 430, 751, 2524.44f, -4769.56f,  104.09f, "Eastwall Tower, Eastern Plaguelands" },
        { 431, 751, 2262.10f, -4411.52f,  111.65f, "Light's Shield Tower, Eastern Plaguelands" },
        { 432, 751, 1876.40f, -3693.32f,  157.69f, "Crown Guard Tower, Eastern Plaguelands" },
        { 433, 751, 2965.55f, -3033.61f,  126.93f, "Plaguewood Tower, Eastern Plaguelands" },
        { 434, 751, 1511.80f, -1586.95f,   64.34f, "Andorhal (Forsaken), Western Plaguelands" },
        { 435, 751, 1374.23f, -1281.94f,   59.17f, "Andorhal (Alliance), Western Plaguelands" },
        { 436, 751, 1864.32f, -1755.82f,   59.66f, "The Menders' Stead, Western Plaguelands" },
        { 437, 751, 2839.78f, -1500.51f,  146.09f, "Hearthglen, Western Plaguelands" },
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
