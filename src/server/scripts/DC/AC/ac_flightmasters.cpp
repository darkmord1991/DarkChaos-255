#include "CreatureScript.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include <array>

// Custom DBC taxi nodes (must match your client+DBC import)
enum : uint32
{
    DBC_TAXI_NODE_CAMP = 441,
    DBC_TAXI_NODE_L30  = 442,
    DBC_TAXI_NODE_L50  = 443,
    DBC_TAXI_NODE_L65  = 444,
    DBC_TAXI_NODE_L70  = 445
};

static constexpr std::array<uint32, 5> kCraterTaxiNodes =
{
    DBC_TAXI_NODE_CAMP, DBC_TAXI_NODE_L30, DBC_TAXI_NODE_L50, DBC_TAXI_NODE_L65, DBC_TAXI_NODE_L70
};

// Right-clicking any of the five crater flight masters opens the native taxi map
// (Interface\TaxiFrame\TaxiMap37.blp, registered against the world by
// WorldMapContinent id 11) directly -- no intermediate gossip window.
//
// WHY A SCRIPT IS STILL NEEDED, when maps 750/751 got the same frame by simply
// clearing their ScriptName: the taxi frame draws only the nodes a player has
// already DISCOVERED, and the crater's camps are reachable ONLY by flying. A new
// player at the Startcamp would open a map holding one dot and nowhere to go,
// because SendLearnNewTaxiNode teaches just the node he is standing on. So the
// whole five-node local network is granted on every interaction. The gossip-list
// UI this replaced never gated on discovery either, so nothing is lost.
//
// The other route to the frame -- dropping npcflag bit 1 so the client sends
// MSG_TAXI_QUERY_AVAILABLE_NODES itself -- would open the map with no server code
// at all, but it also bypasses every hook, leaving nowhere to hand out the mask.
// These NPCs keep npcflag 8193 for that reason.
static bool OpenFlightMap(Player* player, Creature* creature)
{
    if (!player || !creature)
        return false;

    // No node resolves here (bad spawn position, or the taxi DBCs never deployed):
    // fall through to the default gossip menu, whose OptionType 4 entry still
    // reaches the taxi frame, rather than answering the client with nothing.
    if (!sObjectMgr->GetNearestTaxiNode(*creature, player->GetTeamId(true)))
        return false;

    for (uint32 node : kCraterTaxiNodes)
        player->m_taxi.SetTaximaskNode(node);

    // Deliberately no CloseGossipMenuFor: stock GOSSIP_OPTION_TAXIVENDOR calls
    // SendTaxiMenu straight from the open gossip window (PlayerGossip.cpp), and the
    // client swaps the frames itself.
    player->GetSession()->SendTaxiMenu(creature);
    return true;
}

// One behaviour, five ScriptNames -- creature_template binds each camp's flight
// master to its own name (acflightmaster0/30/50/65/70), so all five must stay
// registered even though they no longer differ.
class acflightmaster : public CreatureScript
{
public:
    acflightmaster(char const* scriptName) : CreatureScript(scriptName) { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        return OpenFlightMap(player, creature);
    }
};

void AddSC_flightmasters()
{
    new acflightmaster("acflightmaster0");
    new acflightmaster("acflightmaster30");
    new acflightmaster("acflightmaster50");
    new acflightmaster("acflightmaster65");
    new acflightmaster("acflightmaster70");
}
