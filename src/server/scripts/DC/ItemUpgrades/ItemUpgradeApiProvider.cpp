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
#include "ItemUpgradeUIHelpers.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ObjectAccessor.h"

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

            bool IsBlockedByCombat(Player* player)
            {
                if (!player || player->IsGameMaster())
                    return false;

                if (!sConfigMgr->GetOption<bool>("ItemUpgrade.BlockInCombat", true))
                    return false;

                return player->IsInCombat();
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

                // --- Heirlooms ---------------------------------------------

                bool DescribeEquippedHeirloom(Player* player, uint8 slot, Api::HeirloomSlotInfo& out) override
                {
                    out = Api::HeirloomSlotInfo{};

                    if (!player || slot >= EQUIPMENT_SLOT_END)
                        return false;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return false;

                    // Note the absent IsUpgradableSlot() check: the starter
                    // heirloom is a SHIRT, the very slot the ordinary path skips.
                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (!item)
                        return false;

                    uint8 const tier = mgr->GetItemTier(item->GetEntry());
                    TierDefinition const* tierDef = mgr->GetTierDefinition(tier);
                    if (!tierDef || !tierDef->is_artifact)
                        return false;

                    out.slot = slot;
                    out.itemGuid = item->GetGUID().GetCounter();
                    out.itemEntry = item->GetEntry();
                    out.tier = tier;
                    out.tierMaxLevel = static_cast<uint8>(UI::GetHeirloomMaxLevel(item->GetEntry()));
                    return true;
                }

                uint8 GetMaxHeirloomPackageId() override
                {
                    return static_cast<uint8>(UI::HEIRLOOM_MAX_PACKAGE_ID);
                }

                uint32 GetStarterHeirloomItemId() override
                {
                    return sConfigMgr->GetOption<uint32>("ItemUpgrade.Heirloom.StarterItemId", 300365);
                }

                bool GrantStarterHeirloom(Player* player) override
                {
                    uint32 const itemId = GetStarterHeirloomItemId();
                    if (!player || !itemId)
                        return false;

                    // GetItemCount scans from EQUIPMENT_SLOT_START, so this counts
                    // one already being worn and the grant stays idempotent.
                    if (player->GetItemCount(itemId, true) > 0)
                        return false;

                    // Equipped straight into its slot rather than added to a bag:
                    // the heirloom scan only looks at equipment slots, so a bagged
                    // heirloom would never be upgraded.
                    uint16 dest = 0;
                    if (player->CanEquipNewItem(NULL_SLOT, dest, itemId, false) != EQUIP_ERR_OK)
                        return false;

                    if (!player->EquipNewItem(dest, itemId, true))
                        return false;

                    LOG_DEBUG("scripts.dc", "ItemUpgrade: granted starter heirloom {} to player {}",
                        itemId, player->GetGUID().GetCounter());
                    return true;
                }

                bool RequestHeirloomStep(Player* player, uint32 itemGuid, uint8 packageId) override
                {
                    if (!player || !itemGuid)
                        return false;

                    if (packageId < 1 || packageId > UI::HEIRLOOM_MAX_PACKAGE_ID)
                        return false;

                    // The same combat gate players are held to. Reimplemented
                    // rather than shared: the addon handler's copy lives in an
                    // anonymous namespace, so it is not linkable from here. The
                    // config key is the contract between them.
                    if (IsBlockedByCombat(player))
                        return false;

                    ObjectGuid const itemFullGuid = ObjectGuid::Create<HighGuid::Item>(itemGuid);
                    Item* item = player->GetItemByGuid(itemFullGuid);
                    if (!item || !UI::IsHeirloomEntry(item->GetEntry()))
                        return false;

                    UpgradeManager* mgr = GetUpgradeManager();
                    if (!mgr)
                        return false;

                    uint8 const tier = mgr->GetItemTier(item->GetEntry());
                    uint32 const maxLevel = UI::GetHeirloomMaxLevel(item->GetEntry());
                    ObjectGuid const playerGuid = player->GetGUID();

                    // The current level and package live only in the DB. Read them
                    // off-thread and do everything that depends on them in the
                    // continuation, against a re-resolved player and item.
                    DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                        "SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}", itemGuid))
                        .WithCallback([playerGuid, itemFullGuid, itemGuid, packageId, tier, maxLevel]
                            (QueryResult result)
                    {
                        Player* owner = ObjectAccessor::FindPlayer(playerGuid);
                        if (!owner)
                            return;

                        Item* heirloom = owner->GetItemByGuid(itemFullGuid);
                        if (!heirloom || !UI::IsHeirloomEntry(heirloom->GetEntry()))
                            return;

                        uint32 currentLevel = 0;
                        uint32 currentPackage = 0;
                        if (result)
                        {
                            currentLevel = (*result)[0].Get<uint32>();
                            currentPackage = (*result)[1].Get<uint32>();
                        }

                        // One level per call, so the caller paces the spend. A
                        // package switch on its own re-applies at the current level
                        // and sums an empty cost range, which is what makes
                        // changing stat package free.
                        bool const packageChanged = currentPackage != packageId;
                        uint32 targetLevel = currentLevel;
                        if (currentLevel < maxLevel)
                            targetLevel = currentLevel + 1;
                        else if (!packageChanged)
                            return;  // maxed and already on this package

                        uint32 tokensNeeded = 0;
                        uint32 essenceNeeded = 0;
                        UI::SumHeirloomUpgradeCosts(tier, currentLevel + 1, targetLevel, tokensNeeded, essenceNeeded);

                        uint32 const tokenId = GetUpgradeTokenItemId();
                        uint32 const essenceId = GetArtifactEssenceItemId();

                        if (owner->GetItemCount(tokenId) < tokensNeeded ||
                            owner->GetItemCount(essenceId) < essenceNeeded)
                            return;

                        if (tokensNeeded > 0)
                            owner->DestroyItemCount(tokenId, tokensNeeded, true);
                        if (essenceNeeded > 0)
                            owner->DestroyItemCount(essenceId, essenceNeeded, true);

                        // The enchant id encodes package and level:
                        //   standard (tier 3)  900000 + package*100 + level
                        //   frontier (tier 10) 920000 + package*100 + level
                        uint32 const enchantBase = (tier == 10)
                            ? UI::FRONTIER_HEIRLOOM_ENCHANT_BASE_ID
                            : UI::HEIRLOOM_ENCHANT_BASE_ID;
                        uint32 const enchantId = enchantBase + (packageId * 100) + targetLevel;

                        owner->ApplyEnchantment(heirloom, PERM_ENCHANTMENT_SLOT, false);
                        heirloom->SetEnchantment(PERM_ENCHANTMENT_SLOT, enchantId, 0, 0, owner->GetGUID());
                        owner->ApplyEnchantment(heirloom, PERM_ENCHANTMENT_SLOT, true);

                        CharacterDatabase.Execute(
                            "REPLACE INTO dc_heirloom_upgrades (player_guid, item_guid, item_entry, upgrade_level, "
                            "package_id, enchant_id) VALUES ({}, {}, {}, {}, {}, {})",
                            owner->GetGUID().GetCounter(), itemGuid, heirloom->GetEntry(), targetLevel, packageId,
                            enchantId);

                        CharacterDatabase.Execute(
                            "INSERT INTO dc_heirloom_upgrade_log (player_guid, item_guid, item_entry, from_level, "
                            "to_level, from_package, to_package, enchant_id, token_cost, essence_cost) "
                            "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
                            owner->GetGUID().GetCounter(), itemGuid, heirloom->GetEntry(), currentLevel, targetLevel,
                            currentPackage, packageId, enchantId, tokensNeeded, essenceNeeded);

                        LOG_DEBUG("scripts.dc",
                            "ItemUpgrade: heirloom {} of player {} -> level {} package {} (enchant {})",
                            itemGuid, owner->GetGUID().GetCounter(), targetLevel, packageId, enchantId);
                    }));

                    return true;
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
