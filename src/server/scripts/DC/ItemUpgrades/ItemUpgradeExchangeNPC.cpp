/*
 * DarkChaos Item Upgrade System - Currency Exchange NPC
 *
 * NPC interface for the currency exchange system allowing players to
 * exchange Upgrade Tokens for Artifact Essence and vice versa.
 *
 * Refactored to use Client-Side Addon UI
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 * Updated: January 2026 - Renamed from Transmutation to Exchange
 */

#include "ItemUpgradeExchange.h"
#include "ItemUpgradeManager.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "GossipDef.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "../AddonExtension/dc_addon_transmutation.h"

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // Keep class name for DB compatibility (creature_template script name)
        class ItemUpgradeTransmutationNPC : public CreatureScript
        {
        public:
            ItemUpgradeTransmutationNPC() : CreatureScript("ItemUpgradeTransmutationNPC") { }

            bool OnGossipHello(Player* player, Creature* /*creature*/) override
            {
                if (!player)
                    return false;

                // Trigger the client-side addon UI (opens exchange window)
                DCAddon::Upgrade::SendOpenTransmutationUI(player);

                // Close the gossip menu immediately as the addon window will open
                CloseGossipMenuFor(player);

                return true;
            }
        };

     } // namespace ItemUpgrade
} // namespace DarkChaos

// Registration - keep function name for loader compatibility
void AddSC_ItemUpgradeExchange()
{
    new DarkChaos::ItemUpgrade::ItemUpgradeTransmutationNPC();
}
