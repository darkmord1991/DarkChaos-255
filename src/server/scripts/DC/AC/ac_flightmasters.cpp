#include "CreatureScript.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"

// Custom DBC taxi nodes (must match your client+DBC import)
enum : uint32
{
    DBC_TAXI_NODE_CAMP = 441,
    DBC_TAXI_NODE_L25  = 442,
    DBC_TAXI_NODE_L40  = 443,
    DBC_TAXI_NODE_L60  = 444
};

// Gossip action IDs (stable values, used only server-side)
enum GossipAction : uint32
{
    // Camp (StartCamp)
    GA_TOUR_25    = 1,
    GA_L40_DIRECT = 2,
    GA_L0_TO_57   = 3,

    // Level 25+
    GA_RETURN_STARTCAMP = 4,
    GA_L25_TO_40        = 5,
    GA_L25_TO_60        = 6,

    // Level 40+
    GA_L40_BACK_TO_25      = 7,
    GA_L40_SCENIC_40_TO_57 = 8,
    GA_L40_BACK_TO_0       = 12,

    // Level 60+
    GA_L60_BACK_TO_40 = 9,
    GA_L60_BACK_TO_25 = 10,
    GA_L60_BACK_TO_0  = 11
};

static bool StartDbcTaxiFlight(Player* player, Creature* creature, uint32 sourceNode, uint32 destNode)
{
    if (!player || !creature)
        return false;

    if (!sourceNode || !destNode || sourceNode == destNode)
        return false;

    // SpellId must be non-zero to avoid InstantTaxi teleport behavior.
    std::vector<uint32> nodes;
    nodes.reserve(2);
    nodes.push_back(sourceNode);
    nodes.push_back(destNode);
    return player->ActivateTaxiPathTo(nodes, creature, 1);
}

// Camp flightmaster (NPC 800010)
class acflightmaster0 : public CreatureScript
{
public:
    acflightmaster0() : CreatureScript("acflightmaster0") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, "Camp to Level 30+", GOSSIP_SENDER_MAIN, GA_TOUR_25);
        AddGossipItemFor(player, 0, "Camp to Level 40+", GOSSIP_SENDER_MAIN, GA_L40_DIRECT);
        AddGossipItemFor(player, 0, "Camp to Level 60+", GOSSIP_SENDER_MAIN, GA_L0_TO_57);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        uint32 destNode = 0;
        if (action == GA_TOUR_25)
            destNode = DBC_TAXI_NODE_L25;
        else if (action == GA_L40_DIRECT)
            destNode = DBC_TAXI_NODE_L40;
        else if (action == GA_L0_TO_57)
            destNode = DBC_TAXI_NODE_L60;
        else
            return true;

        StartDbcTaxiFlight(player, creature, DBC_TAXI_NODE_CAMP, destNode);
        return true;
    }
};

// Level 25+ flightmaster (NPC 800012)
class acflightmaster25 : public CreatureScript
{
public:
    acflightmaster25() : CreatureScript("acflightmaster25") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, "Level 30+ to Camp", GOSSIP_SENDER_MAIN, GA_RETURN_STARTCAMP);
        AddGossipItemFor(player, 0, "Level 30+ to Level 40+", GOSSIP_SENDER_MAIN, GA_L25_TO_40);
        AddGossipItemFor(player, 0, "Level 30+ to Level 60+", GOSSIP_SENDER_MAIN, GA_L25_TO_60);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        uint32 destNode = 0;
        if (action == GA_RETURN_STARTCAMP)
            destNode = DBC_TAXI_NODE_CAMP;
        else if (action == GA_L25_TO_40)
            destNode = DBC_TAXI_NODE_L40;
        else if (action == GA_L25_TO_60)
            destNode = DBC_TAXI_NODE_L60;
        else
            return true;

        StartDbcTaxiFlight(player, creature, DBC_TAXI_NODE_L25, destNode);
        return true;
    }
};

// Level 40+ flightmaster (NPC 800013)
class acflightmaster40 : public CreatureScript
{
public:
    acflightmaster40() : CreatureScript("acflightmaster40") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, "Level 50+ to Camp", GOSSIP_SENDER_MAIN, GA_L40_BACK_TO_0);
        AddGossipItemFor(player, 0, "Level 50+ to Level 30+", GOSSIP_SENDER_MAIN, GA_L40_BACK_TO_25);
        AddGossipItemFor(player, 0, "Level 50+ to Level 60+", GOSSIP_SENDER_MAIN, GA_L40_SCENIC_40_TO_57);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        uint32 destNode = 0;
        if (action == GA_L40_BACK_TO_0)
            destNode = DBC_TAXI_NODE_CAMP;
        else if (action == GA_L40_BACK_TO_25)
            destNode = DBC_TAXI_NODE_L25;
        else if (action == GA_L40_SCENIC_40_TO_57)
            destNode = DBC_TAXI_NODE_L60;
        else
            return true;

        StartDbcTaxiFlight(player, creature, DBC_TAXI_NODE_L40, destNode);
        return true;
    }
};

// Level 60+ flightmaster (NPC 800014)
class acflightmaster60 : public CreatureScript
{
public:
    acflightmaster60() : CreatureScript("acflightmaster60") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, "Level 60+ to Camp", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_0);
        AddGossipItemFor(player, 0, "Level 60+ to Level 30+", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_25);
        AddGossipItemFor(player, 0, "Level 60+ to Level 50+", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_40);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        uint32 destNode = 0;
        if (action == GA_L60_BACK_TO_0)
            destNode = DBC_TAXI_NODE_CAMP;
        else if (action == GA_L60_BACK_TO_25)
            destNode = DBC_TAXI_NODE_L25;
        else if (action == GA_L60_BACK_TO_40)
            destNode = DBC_TAXI_NODE_L40;
        else
            return true;

        StartDbcTaxiFlight(player, creature, DBC_TAXI_NODE_L60, destNode);
        return true;
    }
};

void AddSC_flightmasters()
{
    new acflightmaster0();
    new acflightmaster25();
    new acflightmaster40();
    new acflightmaster60();
}
