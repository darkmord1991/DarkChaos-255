/*
 * DCItemUpgradeApi.h
 *
 * Server-side façade over the DarkChaos item upgrade system, for callers that
 * have no client to drive the addon UI with -- playerbots, above all.
 *
 * Why this lives in the game library: `scripts` (which owns the upgrade system,
 * under src/server/scripts/DC/ItemUpgrades/) and `modules` (which owns the bot
 * AI) are SIBLINGS in the build graph -- both link only game-interface, neither
 * links the other. A module therefore cannot include ItemUpgradeManager.h or
 * resolve GetUpgradeManager(). The game library is the one place both can see,
 * so the interface is declared here and the implementation registers itself from
 * the scripts side at load time (ItemUpgradeApiProvider.cpp).
 *
 * GetProvider() returns nullptr when the DC upgrade scripts are not loaded, so
 * every caller must null-check; that is also what makes the module side
 * degrade cleanly in a build without them.
 */

#ifndef DC_ITEM_UPGRADE_API_H
#define DC_ITEM_UPGRADE_API_H

#include "Define.h"
#include <vector>

class Player;

namespace DarkChaos
{
    namespace ItemUpgradeApi
    {
        // Mirrors DarkChaos::ItemUpgrade::CurrencyType. The scripts-side
        // implementation static_asserts the two agree, so a change there breaks
        // the build rather than silently paying in the wrong item.
        enum Currency : uint8
        {
            CURRENCY_NONE             = 0,
            CURRENCY_UPGRADE_TOKEN    = 1,  // DC Item Upgrade Token
            CURRENCY_ARTIFACT_ESSENCE = 2,  // DC Artifact Essence
            CURRENCY_FRONTIER_SAP     = 3   // Emberwood Sap
        };

        // What one equipped piece would cost to take one level further.
        struct SlotUpgradeInfo
        {
            uint8 slot = 0;             // EQUIPMENT_SLOT_* this was read from
            uint32 itemGuid = 0;
            uint32 itemEntry = 0;
            uint8 tier = 0;
            uint8 level = 0;
            uint8 tierMaxLevel = 0;
            Currency currency = CURRENCY_NONE;
            uint32 nextCost = 0;

            // False when the item's upgrade state is not in the manager's cache
            // yet: `level` and `nextCost` are then meaningless. Reading it
            // synchronously would cost a blocking SELECT on the world thread, so
            // the caller is expected to hand the guid to WarmItemStates() and
            // come back on a later pass. See ItemUpgradeApiProvider.cpp.
            bool stateKnown = false;
        };

        class Provider
        {
        public:
            virtual ~Provider() = default;

            // Describes the piece equipped in `slot` (EQUIPMENT_SLOT_*). Returns
            // false when the slot is empty or holds something the upgrade system
            // will not touch (no stats, no tier, or an artifact/heirloom tier,
            // which is priced from a different cost table entirely).
            virtual bool DescribeEquippedSlot(Player* player, uint8 slot, SlotUpgradeInfo& out) = 0;

            // Warms the upgrade-state cache for these item guids off-thread.
            // Negative results are cached too, so a second pass never re-queries.
            virtual void WarmItemStates(Player* player, std::vector<uint32> const& itemGuids) = 0;

            // The player's balance of a currency (these are inventory items).
            virtual uint32 GetCurrencyAmount(Player* player, Currency currency) = 0;

            // Buys exactly one upgrade level: verifies ownership and the balance,
            // spends the tier's currency, persists, logs and refreshes stats.
            virtual bool UpgradeOnce(Player* player, uint32 itemGuid) = 0;
        };

        // Called once from the scripts side at load. Passing nullptr clears it.
        void SetProvider(Provider* provider);

        // nullptr when the DC upgrade scripts are absent -- always check.
        Provider* GetProvider();
    }
}

#endif
