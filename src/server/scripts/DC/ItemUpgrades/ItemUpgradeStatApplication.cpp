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

#include <algorithm>
#include <cmath>

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

            ItemUpgradeState* GetUpgradeStateForTemplate(Player* player,
                ItemTemplate const* proto)
            {
                if (!player || !proto)
                    return nullptr;

                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                    return nullptr;

                for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                {
                    Item* item = GetEquippedItemForSlot(player, slot, proto);
                    if (!item)
                        continue;

                    // Cache-only -- see the note in GetUpgradeStateForSlot.
                    ItemUpgradeState* state =
                        mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
                    if (!state || state->upgrade_level == 0)
                        continue;

                    if (state->stat_multiplier <= 1.0f)
                        continue;

                    return state;
                }

                return nullptr;
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
                PLAYERHOOK_ON_GET_FERAL_AP_BONUS
            }) {}

            void OnPlayerCustomScalingStatValue(Player* player,
                ItemTemplate const* proto, uint32& /*statType*/, int32& val,
                uint8 /*itemProtoStatNumber*/, uint32 /*ScalingStatValue*/,
                ScalingStatValuesEntry const* /*ssv*/) override
            {
                ItemUpgradeState* state = GetUpgradeStateForTemplate(player, proto);
                if (!state)
                    return;

                val = ScaleSignedStatValue(val, state->stat_multiplier);
            }

            void OnPlayerApplyItemModsBefore(Player* player, uint8 slot,
                bool /*apply*/, uint8 /*itemProtoStatNumber*/, uint32 /*statType*/,
                int32& val) override
            {
                ItemUpgradeState* state = GetUpgradeStateForSlot(player, slot);
                if (!state)
                    return;

                val = ScaleSignedStatValue(val, state->stat_multiplier);
            }

            void OnPlayerApplyItemArmorBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint32& amount,
                bool /*isBonusArmor*/) override
            {
                ItemUpgradeState* state = GetUpgradeStateForSlot(player, slot, proto);
                if (!state)
                    return;

                amount = ScaleUnsignedStatValue(amount, state->stat_multiplier);
            }

            void OnPlayerApplyItemBlockValueBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint32& amount) override
            {
                ItemUpgradeState* state = GetUpgradeStateForSlot(player, slot, proto);
                if (!state)
                    return;

                amount = ScaleUnsignedStatValue(amount, state->stat_multiplier);
            }

            void OnPlayerApplyItemResistanceBefore(Player* player, uint8 slot,
                ItemTemplate const* proto, bool /*apply*/, uint8 /*school*/,
                uint32& amount) override
            {
                ItemUpgradeState* state = GetUpgradeStateForSlot(player, slot, proto);
                if (!state)
                    return;

                amount = ScaleUnsignedStatValue(amount, state->stat_multiplier);
            }

            void OnPlayerApplyWeaponDamage(Player* player, uint8 slot,
                ItemTemplate const* proto, float& minDamage, float& maxDamage,
                uint8 /*damageIndex*/) override
            {
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
                ItemUpgradeState* state = GetUpgradeStateForTemplate(player, proto);
                if (!state)
                    return;

                feral_bonus = ScaleSignedStatValue(feral_bonus,
                    state->stat_multiplier);
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
