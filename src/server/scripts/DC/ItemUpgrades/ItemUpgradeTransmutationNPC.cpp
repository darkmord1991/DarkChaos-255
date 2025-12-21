/*
 * DarkChaos Item Upgrade System - Phase 5: Transmutation NPC
 *
 * NPC interface for the transmutation system allowing players to convert
 * item tiers, exchange currencies, and perform synthesis.
 *
 * Refactored to use Client-Side Addon UI
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ItemUpgradeTransmutation.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeSeasonResolver.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "GossipDef.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "../AddonExtension/DCAddonTransmutation.h"

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        class ItemUpgradeTransmutationNPC : public CreatureScript
        {
        public:
            ItemUpgradeTransmutationNPC() : CreatureScript("ItemUpgradeTransmutationNPC") { }

            bool OnGossipHello(Player* player, Creature* /*creature*/) override
            {
                if (!player)
                    return false;

                // Trigger the client-side addon UI
                DCAddon::Upgrade::SendOpenTransmutationUI(player);

                // Close the gossip menu immediately as the addon window will open
                CloseGossipMenuFor(player);

                return true;
            }
        };

     } // namespace ItemUpgrade
} // namespace DarkChaos

// Registration
void AddSC_ItemUpgradeTransmutation()
{
    new DarkChaos::ItemUpgrade::ItemUpgradeTransmutationNPC();
}
