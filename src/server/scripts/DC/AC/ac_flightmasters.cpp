#include "CreatureScript.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"

// Custom DBC taxi nodes (must match your client+DBC import)
enum : uint32
{
    DBC_TAXI_NODE_CAMP = 441,
    DBC_TAXI_NODE_L30  = 442,
    DBC_TAXI_NODE_L50  = 443,
    DBC_TAXI_NODE_L65  = 444,
    DBC_TAXI_NODE_L70  = 445
};

// Gossip action IDs (stable values, used only server-side)
enum GossipAction : uint32
{
    // Camp (StartCamp)
    GA_TOUR_30    = 1,
    GA_L50_DIRECT = 2,
    GA_L0_TO_65   = 3,
    GA_L0_TO_70   = 13,

    // Level 30+
    GA_RETURN_STARTCAMP = 4,
    GA_L30_TO_50        = 5,
    GA_L30_TO_65        = 6,
    GA_L30_TO_70        = 14,

    // Level 50+
    GA_L50_BACK_TO_30   = 7,
    GA_L50_TO_65        = 8,
    GA_L50_BACK_TO_0    = 12,
    GA_L50_TO_70        = 15,

    // Level 65+
    GA_L65_BACK_TO_50 = 9,
    GA_L65_BACK_TO_30 = 10,
    GA_L65_BACK_TO_0  = 11,
    GA_L65_TO_70      = 16,

    // Level 70+
    GA_L70_BACK_TO_0  = 17,
    GA_L70_BACK_TO_30 = 18,
    GA_L70_BACK_TO_50 = 19,
    GA_L70_BACK_TO_65 = 20
};

static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
{
    return "|T" + icon + ":40:40:-18|t " + text;
}

static std::string MakeFlightText(std::string const& text)
{
    return MakeLargeGossipText("Interface\\Icons\\Ability_Mount_Wyvern_01", text);
}

static bool StartDbcTaxiFlight(Player* player, Creature* creature, std::initializer_list<uint32> nodeList)
{
    if (!player || !creature)
        return false;

    if (nodeList.size() < 2)
        return false;

    // SpellId must be non-zero to avoid InstantTaxi teleport behavior.
    std::vector<uint32> nodes;
    nodes.reserve(nodeList.size());
    for (uint32 node : nodeList)
    {
        if (!node)
            return false;
        nodes.push_back(node);
    }
    if (nodes.front() == nodes.back())
        return false;
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

        AddGossipItemFor(player, 0, MakeFlightText("Camp to Level 30+"), GOSSIP_SENDER_MAIN, GA_TOUR_30);
        AddGossipItemFor(player, 0, MakeFlightText("Camp to Level 50+"), GOSSIP_SENDER_MAIN, GA_L50_DIRECT);
        AddGossipItemFor(player, 0, MakeFlightText("Camp to Level 65+"), GOSSIP_SENDER_MAIN, GA_L0_TO_65);
        AddGossipItemFor(player, 0, MakeFlightText("Camp to Level 70+"), GOSSIP_SENDER_MAIN, GA_L0_TO_70);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action == GA_TOUR_30)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_CAMP, DBC_TAXI_NODE_L30 });
        else if (action == GA_L50_DIRECT)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_CAMP, DBC_TAXI_NODE_L50 });
        else if (action == GA_L0_TO_65)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_CAMP, DBC_TAXI_NODE_L65 });
        else if (action == GA_L0_TO_70)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_CAMP, DBC_TAXI_NODE_L30, DBC_TAXI_NODE_L70 });
        else
            return true;
        return true;
    }
};

// Level 30+ flightmaster (NPC 800012)
class acflightmaster30 : public CreatureScript
{
public:
    acflightmaster30() : CreatureScript("acflightmaster30") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, MakeFlightText("Level 30+ to Camp"), GOSSIP_SENDER_MAIN, GA_RETURN_STARTCAMP);
        AddGossipItemFor(player, 0, MakeFlightText("Level 30+ to Level 50+"), GOSSIP_SENDER_MAIN, GA_L30_TO_50);
        AddGossipItemFor(player, 0, MakeFlightText("Level 30+ to Level 65+"), GOSSIP_SENDER_MAIN, GA_L30_TO_65);
        AddGossipItemFor(player, 0, MakeFlightText("Level 30+ to Level 70+"), GOSSIP_SENDER_MAIN, GA_L30_TO_70);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action == GA_RETURN_STARTCAMP)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L30, DBC_TAXI_NODE_CAMP });
        else if (action == GA_L30_TO_50)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L30, DBC_TAXI_NODE_L50 });
        else if (action == GA_L30_TO_65)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L30, DBC_TAXI_NODE_L65 });
        else if (action == GA_L30_TO_70)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L30, DBC_TAXI_NODE_L70 });
        else
            return true;
        return true;
    }
};

// Level 50+ flightmaster (NPC 800013)
class acflightmaster50 : public CreatureScript
{
public:
    acflightmaster50() : CreatureScript("acflightmaster50") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, MakeFlightText("Level 50+ to Camp"), GOSSIP_SENDER_MAIN, GA_L50_BACK_TO_0);
        AddGossipItemFor(player, 0, MakeFlightText("Level 50+ to Level 30+"), GOSSIP_SENDER_MAIN, GA_L50_BACK_TO_30);
        AddGossipItemFor(player, 0, MakeFlightText("Level 50+ to Level 65+"), GOSSIP_SENDER_MAIN, GA_L50_TO_65);
        AddGossipItemFor(player, 0, MakeFlightText("Level 50+ to Level 70+"), GOSSIP_SENDER_MAIN, GA_L50_TO_70);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action == GA_L50_BACK_TO_0)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L50, DBC_TAXI_NODE_CAMP });
        else if (action == GA_L50_BACK_TO_30)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L30 });
        else if (action == GA_L50_TO_65)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L65 });
        else if (action == GA_L50_TO_70)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L70 });
        else
            return true;
        return true;
    }
};

// Level 65+ flightmaster (NPC 800014)
class acflightmaster65 : public CreatureScript
{
public:
    acflightmaster65() : CreatureScript("acflightmaster65") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, MakeFlightText("Level 65+ to Camp"), GOSSIP_SENDER_MAIN, GA_L65_BACK_TO_0);
        AddGossipItemFor(player, 0, MakeFlightText("Level 65+ to Level 30+"), GOSSIP_SENDER_MAIN, GA_L65_BACK_TO_30);
        AddGossipItemFor(player, 0, MakeFlightText("Level 65+ to Level 50+"), GOSSIP_SENDER_MAIN, GA_L65_BACK_TO_50);
        AddGossipItemFor(player, 0, MakeFlightText("Level 65+ to Level 70+"), GOSSIP_SENDER_MAIN, GA_L65_TO_70);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action == GA_L65_BACK_TO_0)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L65, DBC_TAXI_NODE_CAMP });
        else if (action == GA_L65_BACK_TO_30)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L65, DBC_TAXI_NODE_L30 });
        else if (action == GA_L65_BACK_TO_50)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L65, DBC_TAXI_NODE_L50 });
        else if (action == GA_L65_TO_70)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L65, DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L70 });
        else
            return true;
        return true;
    }
};

// Level 70+ flightmaster (NPC 800015)
class acflightmaster70 : public CreatureScript
{
public:
    acflightmaster70() : CreatureScript("acflightmaster70") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        AddGossipItemFor(player, 0, MakeFlightText("Level 70+ to Camp"), GOSSIP_SENDER_MAIN, GA_L70_BACK_TO_0);
        AddGossipItemFor(player, 0, MakeFlightText("Level 70+ to Level 30+"), GOSSIP_SENDER_MAIN, GA_L70_BACK_TO_30);
        AddGossipItemFor(player, 0, MakeFlightText("Level 70+ to Level 50+"), GOSSIP_SENDER_MAIN, GA_L70_BACK_TO_50);
        AddGossipItemFor(player, 0, MakeFlightText("Level 70+ to Level 65+"), GOSSIP_SENDER_MAIN, GA_L70_BACK_TO_65);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action == GA_L70_BACK_TO_0)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L70, DBC_TAXI_NODE_L30, DBC_TAXI_NODE_CAMP });
        else if (action == GA_L70_BACK_TO_30)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L70, DBC_TAXI_NODE_L30 });
        else if (action == GA_L70_BACK_TO_50)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L70, DBC_TAXI_NODE_L50 });
        else if (action == GA_L70_BACK_TO_65)
            StartDbcTaxiFlight(player, creature, { DBC_TAXI_NODE_L70, DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L65 });
        else
            return true;

        return true;
    }
};

void AddSC_flightmasters()
{
    new acflightmaster0();
    new acflightmaster30();
    new acflightmaster50();
    new acflightmaster65();
    new acflightmaster70();
}
