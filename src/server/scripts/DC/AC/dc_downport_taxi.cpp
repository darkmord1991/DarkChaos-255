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
#include "GossipDef.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
#include "DC/CrossSystem/CrossSystemCommon.h"
#include <algorithm>
#include <cmath>
#include <iterator>
#include <string>
#include <utility>
#include <vector>

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

    // Keep in sync with Custom/CSV DBC/TaxiNodes.csv (ids 339-367, 421-437,
    // 446-447). Names and coordinates are the matched retail Cata taxi nodes
    // (gen_taxi.py -- its NODEMAP is the source of truth; add a node there
    // first, re-run it, then mirror the entry here or the flight master will
    // fail the 100-yard guard below and silently offer nothing).
    //
    // That failure mode is not hypothetical: the round-45 expansion added the
    // eleven Ashenvale/Azshara nodes to NODEMAP but not here, and every one of
    // those flight masters sold nothing at all until this table caught up.
    //
    // Map 750 is a coordinate-preserving copy of the Hyjal corner of Kalimdor,
    // so it also contains the surrounding Winterspring / Felwood / Ashenvale /
    // Azshara / Darkshore / Moonglade flight points. Those got their own node
    // ids (339-367, 446-447) because the stock Kalimdor nodes (44/52/53/65/166)
    // must keep pointing at continent 1. Everlook and Moonglade have the usual
    // per-faction node pair, labelled here so the gossip list does not show two
    // identical entries.
    constexpr FlightNode kNodes[] =
    {
        // Mount Hyjal (map 750)
        { 421, 750, 5163.51f, -1760.58f, 1338.47f, "Grove of Aessina, Hyjal" },
        { 422, 750, 4397.79f, -2107.53f, 1204.34f, "Sanctuary of Malorne, Hyjal" },
        { 423, 750, 4987.87f, -2676.19f, 1426.36f, "Shrine of Aviana, Hyjal" },
        { 424, 750, 5584.06f, -3569.84f, 1570.60f, "Nordrassil, Hyjal" },
        { 425, 750, 4059.40f, -3966.75f,  970.15f, "Gates of Sothann, Hyjal" },
        // Kalimdor edge of map 750 -- reachable by flight from the Hyjal nodes
        // (node 338, the pre-Cata Valormok, was retired in round 43 -- Cata
        //  removed that flight point and Bilgewater Harbor replaced it. It is
        //  gone from TaxiNodes.dbc, so it must not be listed here either.)
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

        // Ashenvale + Azshara, added with the round-45 279-tile expansion.
        // These zones only became whole with the terrain expansion, and every
        // one of their flight masters matched a CATA node within 6 yards. CATA
        // rather than STOCK because both zones were revamped -- the stock nodes
        // sit on pre-Cata ground here, which is exactly why 338 was retired.
        { 354, 750, 2827.34f,  -289.24f,  107.16f, "Astranaar, Ashenvale" },
        { 355, 750, 1905.11f,  -321.99f,  118.25f, "Stardust Spire, Ashenvale" },
        { 356, 750, 3000.25f, -3202.41f,  189.77f, "Forest Song, Ashenvale" },
        { 360, 750, 3049.08f,  -498.95f,  205.64f, "Hellscream's Watch, Ashenvale" },
        { 361, 750, 2302.39f, -2524.55f,  104.40f, "Splintertree Post, Ashenvale" },
        { 362, 750, 2159.62f, -1144.05f,   97.87f, "Silverwind Refuge, Ashenvale" },
        { 367, 750, 3351.82f,  1052.30f,    3.07f, "Zoram'gar Outpost, Ashenvale" },
        { 363, 750, 4611.38f, -7041.80f,  153.84f, "Northern Rocketway, Azshara" },
        { 364, 750, 2647.79f, -6214.40f,  100.11f, "Southern Rocketway, Azshara" },
        { 365, 750, 3547.20f, -6294.66f,    0.75f, "Bilgewater Harbor, Azshara" },
        { 366, 750, 2988.13f, -4161.36f,  101.27f, "Valormok, Azshara" },

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

        // Lordaeron extension (map 751), added with the 8-zone build.
        // These 19 nodes went into TaxiNodes.dbc with the extension but NOT into
        // this table, and CurrentNode() only matches within MAX_NODE_DISTANCE.
        // Every one of their flight masters therefore resolved to nullptr and
        // offered an EMPTY gossip list -- Karos Razok sat 2,965 yds from the
        // nearest listed node. 13 of 32 map-751 flight masters worked before this
        // block; all 32 do with it.
        { 368, 751, 2272.68f,   372.06f,   35.76f, "Brill, Tirisfal Glades" },
        { 369, 751, 1568.62f,   267.97f,  -43.10f, "Undercity, Tirisfal" },
        { 370, 751, 1726.62f,  -740.98f,   59.93f, "The Bulwark, Tirisfal" },
        { 371, 751, 1056.06f,  1518.90f,   30.14f, "Forsaken Rear Guard, Silverpine Forest" },
        { 372, 751,  478.86f,  1536.59f,  131.32f, "The Sepulcher, Silverpine Forest" },
        { 373, 751, -114.14f,  1312.32f,   56.74f, "The Forsaken Front, Silverpine Forest" },
        { 374, 751, -661.84f,  -536.49f,   28.21f, "Ruins of Southshore, Hillsbrad" },
        { 378, 751, -566.89f, -1051.20f,   59.41f, "Eastpoint Tower, Hillsbrad" },
        { 385, 751, -605.18f,   435.46f,   79.44f, "Southpoint Gate, Hillsbrad" },
        { 386, 751,  622.85f,  -979.58f,  169.62f, "Strahnbrad, Alterac Mountains" },
        { 387, 751,  -17.71f,  -874.20f,   59.01f, "Tarren Mill, Hillsbrad" },
        { 388, 751,  312.33f, -4105.36f,  118.29f, "Stormfeather Outpost, The Hinterlands" },
        { 389, 751, -635.26f, -4720.50f,    5.38f, "Revantusk Village, The Hinterlands" },
        { 390, 751,  283.74f, -2002.76f,  194.74f, "Aerie Peak, The Hinterlands" },
        { 391, 751,  -25.78f, -2821.78f,  125.17f, "Hiri'watha Research Station, The Hinterlands" },
        { 396, 751, -1240.53f, -2515.11f,  22.16f, "Refuge Pointe, Arathi" },
        { 397, 751, -952.38f, -1585.74f,   51.30f, "Galen's Fall, Arathi" },
        { 398, 751, -916.29f, -3496.89f,   70.45f, "Hammerfall, Arathi" },
        { 399, 751, -910.22f,  1638.60f,   68.37f, "Forsaken Forward Command, Gilneas" },
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

    // Sort key for the gossip list. Node names read "Place, Zone" ("Astranaar,
    // Ashenvale"), so ordering by the zone half and then the place half groups
    // every destination in a zone together instead of leaving the list in
    // whatever order kNodes happens to be written in. Names with no comma
    // ("Acherus: The Ebon Hold") sort under their whole name.
    std::pair<std::string, std::string> SortKey(char const* name)
    {
        std::string const full(name);
        std::size_t const split = full.rfind(", ");
        if (split == std::string::npos)
        {
            return { full, full };
        }

        return { full.substr(split + 2), full.substr(0, split) };
    }

    // The gossip frame holds GOSSIP_MAX_MENU_ITEMS (32) entries and
    // GossipMenu::AddMenuItem ASSERTs above that -- an assert that is live in
    // release builds, so overrunning it takes the worldserver down rather than
    // truncating the list. Map 750 is at 26 destinations and has grown twice
    // already, so the list is capped here instead of trusting it to stay small.
    // Quest entries live in a separate menu and do not count against this.
    constexpr std::size_t MAX_DESTINATIONS = GOSSIP_MAX_MENU_ITEMS - 1;

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
            float const discount = player->GetReputationPriceDiscount(creature);

            // Collect first, then sort: the gossip frame renders items in the
            // order they are added, so building the list up front is what lets
            // it come out grouped by zone rather than in kNodes order.
            struct Destination
            {
                FlightNode const* node;
                uint32 cost;
            };

            std::vector<Destination> destinations;
            destinations.reserve(std::size(kNodes));

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

                destinations.push_back({ &dest, uint32(std::ceil(cost * discount)) });
            }

            std::sort(destinations.begin(), destinations.end(),
                [](Destination const& left, Destination const& right)
                {
                    return SortKey(left.node->name) < SortKey(right.node->name);
                });

            if (destinations.size() > MAX_DESTINATIONS)
            {
                LOG_ERROR("scripts.dc", "npc_dc_downport_flightmaster: node {} has {} reachable "
                    "destinations, over the {} the gossip frame can show; the list is truncated. "
                    "Split the network or page it.",
                    current->nodeId, destinations.size(), MAX_DESTINATIONS);
                destinations.resize(MAX_DESTINATIONS);
            }

            for (Destination const& dest : destinations)
            {
                std::string const text = DCUtils::MakeLargeGossipText(TAXI_ICON,
                    Acore::StringFormat("Fly to {} ({})", dest.node->name, FormatCost(dest.cost)));
                AddGossipItemFor(player, GOSSIP_ICON_TAXI, text, GOSSIP_SENDER_MAIN,
                    GOSSIP_ACTION_INFO_DEF + dest.node->nodeId);
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
