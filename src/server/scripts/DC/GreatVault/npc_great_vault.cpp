/*
 * Great Vault NPC script
 * 
 * Simplified to only trigger the client-side addon interface.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "DC/AddonExtension/DCAddonMythicPlus.h"

class npc_great_vault : public CreatureScript
{
public:
    npc_great_vault() : CreatureScript("npc_great_vault") { }

    bool OnGossipHello(Player* player, Creature* /*creature*/) override
    {
        if (!player)
            return false;

        // Trigger the addon interface
        DCAddon::MythicPlus::SendOpenVault(player);
        
        // Close any existing gossip menu just in case
        CloseGossipMenuFor(player);
        
        return true;
    }
};

void AddSC_npc_great_vault()
{
    new npc_great_vault();
}
