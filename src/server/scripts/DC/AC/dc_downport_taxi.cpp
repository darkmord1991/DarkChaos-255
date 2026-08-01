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

    // Keep in sync with Custom/CSV DBC/TaxiNodes.csv (ids 338-351, 421-437,
    // 446-447). Names and coordinates are the matched retail Cata taxi nodes
    // (gen_taxi.py -- its NODEMAP is the source of truth; add a node there
    // first, re-run it, then mirror the entry here or the flight master will
    // fail the 100-yard guard below and silently offer nothing).
    //
    // Map 750 is a coordinate-preserving copy of the Hyjal corner of Kalimdor,
    // so it also contains the surrounding Winterspring / Felwood / Azshara /
    // Moonglade flight points. Those got their own node ids (338-345, 446-447)
    // because the stock Kalimdor nodes (44/52/53/65/166) must keep pointing at
    // continent 1. Everlook and Moonglade have the usual per-faction node pair,
    // labelled here so the gossip list does not show two identical entries.
    constexpr FlightNode kNodes[] =
    {
        // Mount Hyjal (map 750)
        { 421, 750, 5163.51f, -1760.58f, 1338.47f, "Grove of Aessina, Hyjal" },
        { 422, 750, 4397.79f, -2107.53f, 1204.34f, "Sanctuary of Malorne, Hyjal" },
        { 423, 750, 4987.87f, -2676.19f, 1426.36f, "Shrine of Aviana, Hyjal" },
        { 424, 750, 5584.06f, -3569.84f, 1570.60f, "Nordrassil, Hyjal" },
        { 425, 750, 4059.40f, -3966.75f,  970.15f, "Gates of Sothann, Hyjal" },
        // Kalimdor edge of map 750 -- reachable by flight from the Hyjal nodes
        { 338, 750, 3661.52f, -4390.38f,  113.05f, "Valormok, Azshara" },
        { 339, 750, 3978.74f, -1316.42f,  250.11f, "Emerald Sanctuary, Felwood" },
        { 343, 750, 6205.88f, -1949.63f,  571.29f, "Talonbranch Glade, Felwood" },
        { 344, 750, 6796.80f, -4742.39f,  701.50f, "Everlook, Winterspring (Alliance)" },
        { 345, 750, 6813.06f, -4611.12f,  710.67f, "Everlook, Winterspring (Horde)" },
        { 446, 750, 7458.45f, -2487.21f,  462.33f, "Moonglade (Alliance)" },
        { 447, 750, 7470.39f, -2123.38f,  492.34f, "Moonglade (Horde)" },

        // Cataclysm-only Felwood points, added with the Cata creature layer
        // (HyjalCata/181_). Unlike the border zones above these come from the
        // CATA tables -- Cata replaced Bloodvenom Post with Whisperwind Grove
        // and added Irontree Clearing, so they have no stock counterpart.
        // 438-445 are stock nodes, and node ids cannot exceed 448
        // (TaxiMaskSize = 14 uint32 = 448 bits), hence the low 346/347.
        { 346, 750, 6078.51f,  -845.00f,  412.27f, "Whisperwind Grove, Felwood" },
        { 347, 750, 6892.69f, -1620.41f,  503.11f, "Irontree Clearing, Felwood" },
        { 349, 750, 4734.16f,  -883.81f,  342.93f, "Wildheart Point, Felwood" },
        // With 343 and 339 that is the complete Cata Felwood network of FIVE
        // flight points. Cata node 48 "Bloodvenom Post" is deliberately absent:
        // TaxiNodes.dbc flags it "[DISABLED in 4.x]", so having no flight master
        // there is correct Cataclysm behaviour, not a gap. Wildheart Point
        // (~700 yds away) is its replacement.

        // Darkshore, added with the Cata Darkshore layer (HyjalCata/184_).
        // Both come from the CATA tables because Blizzard REUSED node id 26 in
        // the revamp -- stock 26 is Auberdine, cata 26 is Lor'danel, and they
        // are 1,428 yards apart since Auberdine was destroyed. Grove of the
        // Ancients has no stock counterpart at all; it only became a flight
        // point in Cataclysm.
        { 350, 750, 7459.90f,  -326.56f,    8.09f, "Lor'danel, Darkshore" },
        { 351, 750, 4970.50f,   147.65f,   51.64f, "Grove of the Ancients, Darkshore" },

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

    // A flight master must actually be standing AT its node. Without this a
    // flight master far from every listed node would silently adopt the nearest
    // one (however distant) and sell flights departing from somewhere else.
    constexpr float MAX_NODE_DISTANCE = 100.0f;
    constexpr float MAX_NODE_DISTANCE_SQ = MAX_NODE_DISTANCE * MAX_NODE_DISTANCE;

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

        if (best && bestDist > MAX_NODE_DISTANCE_SQ)
        {
            return nullptr;
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
