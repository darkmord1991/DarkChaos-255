/*
 * ItemUpgradeApiProvider.cpp
 *
 * Implements the game-library façade (src/server/game/DC/DCItemUpgradeApi.h) so
 * callers outside the scripts library -- mod-playerbots, specifically -- can
 * drive the upgrade system without a client.
 *
 * Bots already EARN the upgrade currencies: the quest, creature-kill, PvP and
 * achievement hooks in ItemUpgradeTokenHooks.cpp run for every Player, and a bot
 * is a Player. What they had no way to reach was the spend half, because the
 * only entry points were the addon handler (dc_addon_upgrade.cpp) and the gossip
 * NPCs. This exposes the facts (tier, level, cost, balance) and the one mutating
 * operation (buy a level); the POLICY -- which bot, how often, how far -- lives
 * on the module side, in the bot's own AI.
 *
 * Cost discipline, since callers run on the world thread:
 *   - GetItemUpgradeState() issues a BLOCKING select on a cache miss, so nothing
 *     here calls it. A cold item is reported with stateKnown=false and the caller
 *     is expected to WarmItemStates() and revisit.
 *   - UpgradeOnce() ends in ForcePlayerStatUpdate(), a full stat re-apply, so it
 *     is deliberately one level per call -- the caller paces itself.
 */

#include "ScriptMgr.h"
#include "DCItemUpgradeApi.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Player.h"
#include "ItemUpgradeManager.h"
#include "DC/CrossSystem/SeasonResolver.h"

#include <utility>
#include <vector>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        namespace
        {
            namespace Api = DarkChaos::ItemUpgradeApi;

            // The façade re-declares the currency ids so the game library needs no
            // scripts header. Keep the two in lockstep.
            static_assert(static_cast<uint8>(Api::CURRENCY_UPGRADE_TOKEN) == static_cast<uint8>(CURRENCY_UPGRADE_TOKEN),
                "DCItemUpgradeApi currency ids drifted from ItemUpgrade::CurrencyType");
            static_assert(static_cast<uint8>(Api::CURRENCY_ARTIFACT_ESSENCE) ==
                static_cast<uint8>(CURRENCY_ARTIFACT_ESSENCE),
                "DCItemUpgradeApi currency ids drifted from ItemUpgrade::CurrencyType");
            static_assert(static_cast<uint8>(Api::CURRENCY_FRONTIER_SAP) == static_cast<uint8>(CURRENCY_FRONTIER_SAP),
                "DCItemUpgradeApi currency ids drifted from ItemUpgrade::CurrencyType");

            bool IsUpgradableSlot(uint8 slot)
            {
                // Shirt and tabard carry no stats, but their item level still
                // lands inside tier 1's 1-212 band, so they would happily eat
                // currency for nothing.
                return slot != EQUIPMENT_SLOT_BODY && slot != EQUIPMENT_SLOT_TABARD;
            }

            bool CarriesStats(ItemTemplate const* proto)
            {
                if (!proto)
                    return false;

                if (proto->StatsCount > 0 || proto->Armor > 0)
                    return true;

                for (auto const& damage : proto->Damage)
                    if (damage.DamageMax > 0.0f)
                        return true;

                return false;
            }

            class UpgradeApiProvider : public Api::Provider
            {
            public:
                bool DescribeEquippedSlot(Player* player, uint8 slot, Api::SlotUpgradeInfo& out) override
                {
                    out = Api::SlotUpgradeInfo{};

                    if (!player || !IsUpgradableSlot(slot) || slot >= EQUIPMENT_SLOT_END)
                        return false;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return false;

                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (!item || !CarriesStats(item->GetTemplate()))
                        return false;

                    uint8 const tier = mgr->GetItemTier(item->GetEntry());
                    if (tier == TIER_INVALID)
                        return false;

                    // Artifact tiers (heirlooms) are priced from the heirloom cost
                    // tables, not dc_item_upgrade_costs, and are upgraded through
                    // HandleHeirloomUpgrade. The generic path reads a cost of 0 for
                    // them, which would hand out free levels.
                    TierDefinition const* tierDef = mgr->GetTierDefinition(tier);
                    if (!tierDef || tierDef->is_artifact)
                        return false;

                    out.slot = slot;
                    out.itemGuid = item->GetGUID().GetCounter();
                    out.itemEntry = item->GetEntry();
                    out.tier = tier;
                    out.tierMaxLevel = mgr->GetTierMaxLevel(tier);
                    out.currency = static_cast<Api::Currency>(GetTierCurrency(tier));

                    // Cache-only: a miss must not become a blocking read here.
                    ItemUpgradeState const* state = mgr->GetCachedItemUpgradeState(out.itemGuid);
                    if (!state)
                        return true;

                    out.stateKnown = true;
                    out.level = state->upgrade_level;
                    out.nextCost = NextStepCost(mgr, tier, out.level, out.tierMaxLevel, out.currency);
                    return true;
                }

                void WarmItemStates(Player* player, std::vector<uint32> const& itemGuids) override
                {
                    if (!player || itemGuids.empty())
                        return;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return;

                    // The prefetch wants the entry alongside the guid, otherwise its
                    // continuation falls back to a blocking item_instance lookup --
                    // the very cost the prefetch exists to avoid.
                    std::vector<std::pair<uint32, uint32>> items;
                    items.reserve(itemGuids.size());

                    for (uint32 itemGuid : itemGuids)
                    {
                        Item* item = player->GetItemByGuid(ObjectGuid::Create<HighGuid::Item>(itemGuid));
                        if (item)
                            items.emplace_back(itemGuid, item->GetEntry());
                    }

                    if (!items.empty())
                        mgr->PrefetchItemStatesAsync(std::move(items), player->GetGUID().GetCounter());
                }

                uint32 GetCurrencyAmount(Player* player, Api::Currency currency) override
                {
                    if (!player || currency == Api::CURRENCY_NONE)
                        return 0;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return 0;

                    return mgr->GetCurrency(player->GetGUID().GetCounter(),
                        static_cast<CurrencyType>(currency), GetCurrentSeasonId());
                }

                bool UpgradeOnce(Player* player, uint32 itemGuid) override
                {
                    if (!player || !itemGuid)
                        return false;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return false;

                    uint32 const playerGuid = player->GetGUID().GetCounter();

                    // UpgradeItem resolves the player through FindPlayerWithContext,
                    // which needs the map context primed.
                    CachePlayerMapContext(player);

                    // CanUpgradeItem is the ownership and max-level gate; UpgradeItem
                    // itself does not verify the item belongs to the payer.
                    if (!mgr->CanUpgradeItem(itemGuid, playerGuid))
                        return false;

                    return mgr->UpgradeItem(playerGuid, itemGuid);
                }

            private:
                // Cost of stepping level -> level + 1, or 0 when there is no step to
                // buy. A tier with no row in dc_item_upgrade_costs also reads 0, and
                // 0 always means "skip" rather than "free".
                static uint32 NextStepCost(UpgradeManager* mgr, uint8 tier, uint8 level, uint8 maxLevel,
                    Api::Currency currency)
                {
                    if (level >= maxLevel)
                        return 0;

                    uint8 const nextLevel = level + 1;

                    // T4/T5 are PRICED in the token_cost column but PAID in Emberwood
                    // Sap -- the column carries the amount, the currency decides the
                    // item. This mirrors UpgradeItem exactly.
                    return currency == Api::CURRENCY_ARTIFACT_ESSENCE
                        ? mgr->GetEssenceCost(tier, nextLevel)
                        : mgr->GetUpgradeCost(tier, nextLevel);
                }
            };

            UpgradeApiProvider s_provider;
        } // namespace
    } // namespace ItemUpgrade
} // namespace DarkChaos

void AddSC_ItemUpgradeApiProvider()
{
    DarkChaos::ItemUpgradeApi::SetProvider(&DarkChaos::ItemUpgrade::s_provider);
}
