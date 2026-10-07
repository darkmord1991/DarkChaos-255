/*
 * ItemUpgradeStatApplication.cpp
 *
 * Purpose: Handle stat application and updates for upgraded items
 * Ensures that upgraded item stats are properly applied to players
 *
 * This module provides the stat update functionality for the item upgrade system.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemUpgradeManager.h"
#include "DataMap.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        namespace
        {
            Item* GetEquippedItemForSlot(Player* player, uint8 slot,
                ItemTemplate const* proto = nullptr)
            {
                if (!player || slot >= EQUIPMENT_SLOT_END)
                    return nullptr;

                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!item)
                    return nullptr;

                if (proto && item->GetEntry() != proto->ItemId)
                    return nullptr;

                return item;
            }

            ItemUpgradeState* GetUpgradeStateForSlot(Player* player, uint8 slot,
                ItemTemplate const* proto = nullptr)
            {
                Item* item = GetEquippedItemForSlot(player, slot, proto);
                if (!item)
                    return nullptr;

                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                    return nullptr;

                // Cache-only on purpose: the core calls the stat hooks once per stat line
                // of _ApplyItemBonuses, so a blocking SELECT here multiplies into ~19
                // synchronous queries per player during LoadFromDB. A cold miss applies
                // base stats; PrefetchPlayerItemStatesAsync corrects it moments later via
                // ForcePlayerStatUpdate.
                ItemUpgradeState* state =
                    mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
                if (!state || state->upgrade_level == 0)
                    return nullptr;

                if (state->stat_multiplier <= 1.0f)
                    return nullptr;

                return state;
            }

            // ---------------------------------------------------------------
            // Apply/remove symmetry
            // ---------------------------------------------------------------
            // The core adds an item's stats when it is equipped and SUBTRACTS them
            // when it is removed, and it calls these hooks for both directions. The
            // modifiers are plain running sums, so the amount subtracted has to be
            // exactly the amount that was added.
            //
            // Scaling both directions by "the multiplier in the cache right now"
            // breaks that whenever the multiplier changed in between:
            //
            //  * Login. LoadFromDB applies item stats while the upgrade cache is
            //    still cold (x1.0). The prefetch then fills the cache and calls
            //    ForcePlayerStatUpdate, which removes and re-applies everything --
            //    but the removal now subtracts x*m where only x*1.0 had been added,
            //    and the re-apply adds x*m back. Net result: x*1.0. The bonus was
            //    never folded in, on every first login after a server start.
            //  * Upgrade purchase. Same shape: remove at the NEW multiplier, re-apply
            //    at the new multiplier, net unchanged. The purchase only took effect
            //    after a relog with a warm cache.
            //  * Unequipping after either of the above subtracted x*m from a sum that
            //    only held x, leaving a negative residue on the character.
            //
            // So: remember, per player and per item, the multiplier each stat block
            // was applied with, and remove with THAT. Stored in Player::CustomData,
            // which lives and dies with the Player and is only touched from that
            // player's own update context, so it needs no locking.
            //
            // The core fires the enchant hook once per STAT effect of an enchant, in both
            // directions, so a two-stat line ("+10 Stamina, +10 Agility") is applied twice and
            // must be removed twice at the same multiplier. Erasing the record on the first
            // removal sent the second one back to 1.0 and left (m - 1) x that stat on the
            // character every time the line came off -- on each unequip, and on each reroll of
            // an equipped item.
            struct AppliedEnchantMultiplier
            {
                float multiplier = 1.0f;
                uint32 effects = 0;     // stat effects applied with it and not yet removed
            };

            struct AppliedUpgradeMultipliers : public DataMap::Base
            {
                // item guid (low) -> multiplier its template stats were applied with
                std::unordered_map<uint32, float> itemStats;
                // (item guid low << 4 | enchant slot) -> multiplier for that enchant
                std::unordered_map<uint64, AppliedEnchantMultiplier> enchantStats;

                // The _ApplyItemBonuses pass in progress. The core opens every pass
                // with OnPlayerCustomScalingStatValueBefore (slot + direction) and the
                // stat hooks that follow belong to it, so they read the multiplier
                // from here instead of each resolving their own.
                uint32 passItemGuid = 0;
                float passMultiplier = 1.0f;
            };

            constexpr char const* APPLIED_MULTIPLIERS_KEY = "dc_item_upgrade_applied_multipliers";

            AppliedUpgradeMultipliers* GetAppliedMultipliers(Player* player)
            {
                return player->CustomData.GetDefault<AppliedUpgradeMultipliers>(
                    APPLIED_MULTIPLIERS_KEY);
            }

            // The multiplier the cache holds for this item right now; 1.0 when the item
            // is not upgraded or its state is not resident yet.
            float GetLiveMultiplier(Item* item)
            {
                if (!item)
                    return 1.0f;

                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                    return 1.0f;

                // Cache-only on purpose -- see the note in GetUpgradeStateForSlot.
                ItemUpgradeState* state =
                    mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
                if (!state || state->upgrade_level == 0 || state->stat_multiplier <= 1.0f)
                    return 1.0f;

                return state->stat_multiplier;
            }

            // Opens a stat pass for the item in `slot`: applying records the live
            // multiplier, removing replays whatever was recorded when it was applied.
            void BeginStatPass(Player* player, uint8 slot, bool apply)
            {
                AppliedUpgradeMultipliers* applied = GetAppliedMultipliers(player);
                applied->passItemGuid = 0;
                applied->passMultiplier = 1.0f;

                Item* item = GetEquippedItemForSlot(player, slot);
                if (!item)
                    return;

                uint32 const itemGuid = item->GetGUID().GetCounter();
                applied->passItemGuid = itemGuid;

                if (apply)
                {
                    applied->passMultiplier = GetLiveMultiplier(item);
                    applied->itemStats[itemGuid] = applied->passMultiplier;
                    return;
                }

                auto itr = applied->itemStats.find(itemGuid);
                if (itr != applied->itemStats.end())
                {
                    applied->passMultiplier = itr->second;
                    applied->itemStats.erase(itr);
                }
            }

            // Multiplier for a stat hook belonging to the pass opened above. Falls back
            // to 1.0 when the hook fires for an item no pass was opened for, which is
            // the safe direction: an unscaled stat is still symmetric.
            float GetPassMultiplier(Player* player, uint8 slot)
            {
                AppliedUpgradeMultipliers* applied = GetAppliedMultipliers(player);
                Item* item = GetEquippedItemForSlot(player, slot);
                if (!item || item->GetGUID().GetCounter() != applied->passItemGuid)
                    return 1.0f;

                return applied->passMultiplier;
            }

            float GetPassMultiplierForTemplate(Player* player, ItemTemplate const* proto)
            {
                if (!proto)
                    return 1.0f;

                AppliedUpgradeMultipliers* applied = GetAppliedMultipliers(player);
                if (!applied->passItemGuid)
                    return 1.0f;

                Item* item = player->GetItemByGuid(
                    ObjectGuid::Create<HighGuid::Item>(applied->passItemGuid));
                if (!item || item->GetEntry() != proto->ItemId)
                    return 1.0f;

                return applied->passMultiplier;
            }

            // Stats rolled INTO the item (RandomEnchants / random properties) scale with
            // it; what the player adds afterwards -- the permanent enchant, gems, temporary
            // enchants -- does not. Same line retail draws for its item-level upgrades.
            bool IsRandomEnchantSlot(EnchantmentSlot slot)
            {
                return slot >= PROP_ENCHANTMENT_SLOT_0 && slot <= PROP_ENCHANTMENT_SLOT_4;
            }

            float ResolveEnchantMultiplier(Player* player, Item* item,
                EnchantmentSlot slot, bool apply)
            {
                AppliedUpgradeMultipliers* applied = GetAppliedMultipliers(player);
                uint64 const key =
                    (uint64(item->GetGUID().GetCounter()) << 4) | uint64(slot & 0xF);

                if (apply)
                {
                    float const multiplier = GetLiveMultiplier(item);
                    AppliedEnchantMultiplier& entry = applied->enchantStats[key];
                    entry.multiplier = multiplier;
                    ++entry.effects;
                    return multiplier;
                }

                auto itr = applied->enchantStats.find(key);
                if (itr == applied->enchantStats.end())
                    return 1.0f;

                float const multiplier = itr->second.multiplier;
                if (--itr->second.effects == 0)
                    applied->enchantStats.erase(itr);
                return multiplier;
            }

            int32 ScaleSignedStatValue(int32 value, float multiplier)
            {
                if (value <= 0 || multiplier <= 1.0f)
                    return value;

                return static_cast<int32>(std::lround(value * multiplier));
            }

            uint32 ScaleUnsignedStatValue(uint32 value, float multiplier)
            {
                if (value == 0 || multiplier <= 1.0f)
                    return value;

                return static_cast<uint32>(std::lround(value * multiplier));
            }

            // Puts a resource back where it stood relative to its maximum. Nothing to do
            // when the maximum did not move -- the value was never clamped. When it did,
            // the same fraction of the new maximum comes back.
            uint32 RescaleResourceValue(uint32 value, uint32 oldMax, uint32 newMax)
            {
                if (!value || !oldMax || oldMax == newMax)
                    return value;

                double const scaled = double(value) * double(newMax) / double(oldMax);
                return std::max<uint32>(1, static_cast<uint32>(
                    std::llround(std::min(scaled, double(newMax)))));
            }
        }

        // =====================================================================
        // Stat Application Implementation
        // =====================================================================

        void ForcePlayerStatUpdate(Player* player)
        {
            if (!player)
                return;

            // _ApplyAllStatBonuses() ADDS every item and aura modifier; it does not
            // recompute from a clean slate. Calling it on a player whose modifiers are
            // already applied therefore doubles their entire item stat block (and doubles
            // again on the next call). It must be paired with the matching removal --
            // this is exactly how the core does it in
            // Player::InitStatsForLevel(reapplyMods = true).
            //
            // The removal half drops max health and max mana to the naked base for the
            // duration of the swap, and Unit::SetMaxHealth() / Unit::SetPower() clamp the
            // CURRENT value down to the new maximum. Re-applying raises the maximum back
            // but never lifts the clamped current value, so an unguarded pair leaves the
            // player sitting at their un-geared health -- about half a bar for a geared
            // character, on every login (the login prefetch always lands cache-cold).
            // The core hits the same clamp and papers over it with SetFullHealth() at the
            // end of InitStatsForLevel; a free full heal is not acceptable on a path that
            // also runs on every upgrade purchase, so preserve the ratio instead.
            uint32 const oldHealth = player->GetHealth();
            uint32 const oldMaxHealth = player->GetMaxHealth();

            uint32 oldPower[MAX_POWERS];
            uint32 oldMaxPower[MAX_POWERS];
            for (uint8 i = 0; i < MAX_POWERS; ++i)
            {
                oldPower[i] = player->GetPower(Powers(i));
                oldMaxPower[i] = player->GetMaxPower(Powers(i));
            }

            player->_RemoveAllStatBonuses();
            player->_ApplyAllStatBonuses();   // ends with UpdateAllStats()

            // oldHealth == 0 means a corpse -- restoring a ratio there would resurrect it.
            if (oldHealth)
                player->SetHealth(RescaleResourceValue(oldHealth, oldMaxHealth, player->GetMaxHealth()));

            for (uint8 i = 0; i < MAX_POWERS; ++i)
            {
                Powers const power = Powers(i);
                uint32 const newMax = player->GetMaxPower(power);
                if (newMax == oldMaxPower[i])
                    continue;

                player->SetPower(power, RescaleResourceValue(oldPower[i], oldMaxPower[i], newMax));
            }

            // Combat ratings and the outgoing unit fields still need a nudge.
            player->UpdateAllRatings();
            player->UpdateObjectVisibility();
        }

        class ItemUpgradeStatScalingScript : public PlayerScript
        {
        public:
            ItemUpgradeStatScalingScript() : PlayerScript("ItemUpgradeStatScalingScript",
            {
                PLAYERHOOK_ON_APPLY_ITEM_ARMOR_BEFORE, PLAYERHOOK_ON_APPLY_ITEM_BLOCK_VALUE_BEFORE,
                PLAYERHOOK_ON_APPLY_ITEM_MODS_BEFORE, PLAYERHOOK_ON_APPLY_ITEM_RESISTANCE_BEFORE,
                PLAYERHOOK_ON_APPLY_WEAPON_DAMAGE, PLAYERHOOK_ON_CUSTOM_SCALING_STAT_VALUE,
                PLAYERHOOK_ON_CUSTOM_SCALING_STAT_VALUE_BEFORE,
                PLAYERHOOK_ON_APPLY_ENCHANTMENT_ITEM_MODS_BEFORE,
                PLAYERHOOK_ON_GET_FERAL_AP_BONUS
            }) {}

            // First hook of every _ApplyItemBonuses pass, and the only one that carries
            // both the slot and the direction: it opens the pass the hooks below read.
            void OnPlayerCustomScalingStatValueBefore(Player* player,
                ItemTemplate const* /*proto*/, uint8 slot, bool apply,
                uint32& /*CustomScalingStatValue*/) override
            {
                if (!player)
                    return;

                BeginStatPass(player, slot, apply);
            }

            void OnPlayerApplyEnchantmentItemModsBefore(Player* player, Item* item,
                EnchantmentSlot slot, bool apply, uint32 /*enchant_spell_id*/,
                uint32& enchant_amount) override
            {
                if (!player || !item || !IsRandomEnchantSlot(slot))
                    return;

                enchant_amount = ScaleUnsignedStatValue(enchant_amount,
                    ResolveEnchantMultiplier(player, item, slot, apply));
            }

            void OnPlayerCustomScalingStatValue(Player* player,
                ItemTemplate const* proto, uint32& /*statType*/, int32& val,
                uint8 /*itemProtoStatNumber*/, uint32 /*ScalingStatValue*/,
                ScalingStatValuesEntry const* /*ssv*/) override
            {
                if (!player)
                    return;

                val = ScaleSignedStatValue(val,
                    GetPassMultiplierForTemplate(player, proto));
            }

            void OnPlayerApplyItemModsBefore(Player* player, uint8 slot,
                bool /*apply*/, uint8 /*itemProtoStatNumber*/, uint32 /*statType*/,
                int32& val) override
            {
                if (!player)
                    return;

                val = ScaleSignedStatValue(val, GetPassMultiplier(player, slot));
            }

            void OnPlayerApplyItemArmorBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint32& amount,
                bool /*isBonusArmor*/) override
            {
                if (!player || !GetEquippedItemForSlot(player, slot, proto))
                    return;

                amount = ScaleUnsignedStatValue(amount, GetPassMultiplier(player, slot));
            }

            void OnPlayerApplyItemBlockValueBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint32& amount) override
            {
                if (!player || !GetEquippedItemForSlot(player, slot, proto))
                    return;

                amount = ScaleUnsignedStatValue(amount, GetPassMultiplier(player, slot));
            }

            void OnPlayerApplyItemResistanceBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint8 /*school*/,
                uint32& amount) override
            {
                if (!player || !GetEquippedItemForSlot(player, slot, proto))
                    return;

                amount = ScaleUnsignedStatValue(amount, GetPassMultiplier(player, slot));
            }

            void OnPlayerApplyWeaponDamage(Player* player, uint8 slot,
                ItemTemplate const* proto, float& minDamage, float& maxDamage,
                uint8 /*damageIndex*/) override
            {
                // Not part of the symmetric bookkeeping above on purpose: the core only
                // fires this when applying and then SETS the base weapon damage rather
                // than adding to a running sum, so there is nothing to un-apply.
                ItemUpgradeState* state = GetUpgradeStateForSlot(player, slot, proto);
                if (!state)
                    return;

                minDamage *= state->stat_multiplier;
                maxDamage *= state->stat_multiplier;
            }

            void OnPlayerGetFeralApBonus(Player* player, int32& feral_bonus,
                int32 /*dpsMod*/, ItemTemplate const* proto,
                ScalingStatValuesEntry const* /*ssv*/) override
            {
                if (!player)
                    return;

                // Fired from the tail of _ApplyItemBonuses, so it is part of the pass
                // and the feral AP it feeds (ApplyFeralAPBonus) is a running sum too.
                feral_bonus = ScaleSignedStatValue(feral_bonus,
                    GetPassMultiplierForTemplate(player, proto));
            }
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeStatApplication()
{
    new DarkChaos::ItemUpgrade::ItemUpgradeStatScalingScript();
}
