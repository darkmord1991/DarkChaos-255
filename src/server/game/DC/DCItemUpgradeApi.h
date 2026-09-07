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

        // An equipped heirloom (an is_artifact tier). Deliberately separate from
        // SlotUpgradeInfo: heirlooms are priced from dc_heirloom_upgrade_costs,
        // levelled through a package-specific enchant rather than a stat
        // multiplier, and their state lives in dc_heirloom_upgrades -- none of
        // which the ordinary upgrade path touches.
        //
        // No level/cost fields here on purpose. That state is only in the DB and
        // reading it would mean a blocking query on the world thread, so the
        // level arithmetic and payment happen inside RequestHeirloomStep's async
        // continuation, where the row is already in hand.
        struct HeirloomSlotInfo
        {
            uint8 slot = 0;
            uint32 itemGuid = 0;
            uint32 itemEntry = 0;
            uint8 tier = 0;
            uint8 tierMaxLevel = 0;
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

            // --- Heirlooms -------------------------------------------------
            //
            // Heirlooms are the artifact tiers DescribeEquippedSlot refuses, and
            // they are worn in slots it skips (the starter heirloom is a SHIRT),
            // so they need their own scan.

            // Describes the heirloom equipped in `slot`, or false if there is
            // none. Synchronous and DB-free: tier data is already in memory.
            virtual bool DescribeEquippedHeirloom(Player* player, uint8 slot, HeirloomSlotInfo& out) = 0;

            // Highest valid stat-package id (packages are 1..N).
            virtual uint8 GetMaxHeirloomPackageId() = 0;

            // Advances the heirloom one upgrade level, applying `packageId`'s
            // stat enchant. Asynchronous: the current level and package come from
            // dc_heirloom_upgrades, and affordability, payment, the enchant and
            // the DB writes all happen in the continuation. Re-applies at the
            // same level (for free) when only the package changes, which is how a
            // caller switches an heirloom to a different stat package.
            //
            // Returns false only when the request could not be started; a started
            // request may still decline once the row is read (too poor, maxed).
            virtual bool RequestHeirloomStep(Player* player, uint32 itemGuid, uint8 packageId) = 0;

            // The starter heirloom item id, or 0 when none is configured.
            virtual uint32 GetStarterHeirloomItemId() = 0;

            // Adds and equips the starter heirloom. Exists because the item is
            // otherwise only obtainable from the onboarding quest chain, which
            // playerbots never run.
            virtual bool GrantStarterHeirloom(Player* player) = 0;
        };

        // Called once from the scripts side at load. Passing nullptr clears it.
        void SetProvider(Provider* provider);

        // nullptr when the DC upgrade scripts are absent -- always check.
        Provider* GetProvider();
    }
}

#endif
