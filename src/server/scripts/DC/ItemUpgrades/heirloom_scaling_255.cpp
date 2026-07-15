/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Bag.h"
#include "SharedDefines.h"
#include "DBCStores.h"
#include "DBCStructure.h"
#include "DatabaseEnv.h"
#include "Chat.h"

#include <vector>

/*
 * Heirloom Scaling Extension to Level 255
 *
 * This script extends heirloom item scaling beyond the default DBC cap (level 80)
 * up to level 255 for custom high-level servers.
 *
 * IMPORTANT: For Tier 3 Heirloom Upgrade System Integration:
 * - Primary stats (STR/AGI/INT/STA/SPI) scale with player level (handled here)
 * - Secondary stats (Crit/Haste/Hit/Expertise/ArmorPen) scale with upgrade level (handled by upgrade system)
 * - Item level NEVER changes (stays at 80) - tier 3 items use upgrade level only
 * - Upgrade system adds secondary stats via permanent enchantments
 *
 * Features:
 * - Scales heirloom armor/weapons PRIMARY stats (Strength, Stamina, etc.) with player level
 * - Scales heirloom weapon DPS beyond the last available ScalingStatValues row
 * - Scales heirloom bag slots (containers get more slots at higher levels)
 * - Respects upgrade system for secondary stat bonuses
 *
 * How it works:
 * - Uses the nearest available ScalingStatValues row as a baseline
 * - Extrapolates scaling with a gentle progressive curve when player level exceeds that baseline
 * - Maintains proper stat scaling ratios while extending the level range
 * - For bags: increases ContainerSlots based on player level
 */

namespace {
    constexpr uint32 HEIRLOOM_SHIRT_ITEM      = 300365; // Heirloom Adventurer's Shirt (quest reward)
    constexpr float HEIRLOOM_MAX_SCALING_BOOST = 4.0f;
    constexpr float HEIRLOOM_PROGRESSIVE_CURVE = 0.08f;

    // Heirloom bag slot growth is tiered items, not a live-growing field: the 3.3.5
    // client's bag window (and its tooltip) read a container's slot count from the
    // static per-itemID item-info cache, not the live per-instance object field, so
    // resizing an existing bag in place never renders more slots client-side even
    // though the server-side field updates correctly (confirmed against the client's
    // own tooltip code and independently by TrinityCore devs - "the slots are quite
    // hardcoded", https://talk.trinitycore.org/t/how-to-get-larger-bags/30730). Each
    // tier below is a real, separate item_template row; leveling up swaps the
    // equipped bag for the next tier via UpgradeHeirloomBagIfNeeded.
    struct HeirloomBagTier
    {
        uint32 entry;
        uint32 slots;
        uint32 minLevel;
    };

    constexpr HeirloomBagTier HEIRLOOM_BAG_TIERS[] = {
        { 300366, 16,   1 },
        { 302607, 20,  26 },
        { 302608, 24,  51 },
        { 302609, 28,  76 },
        { 302610, 32, 101 },
        { 302611, 36, 126 },
    };
    constexpr size_t HEIRLOOM_BAG_TIER_COUNT = sizeof(HEIRLOOM_BAG_TIERS) / sizeof(HEIRLOOM_BAG_TIERS[0]);

    int32 FindHeirloomBagTierIndex(uint32 itemEntry)
    {
        for (size_t i = 0; i < HEIRLOOM_BAG_TIER_COUNT; ++i)
            if (HEIRLOOM_BAG_TIERS[i].entry == itemEntry)
                return static_cast<int32>(i);

        return -1;
    }

    int32 DesiredHeirloomBagTierIndex(uint32 playerLevel)
    {
        int32 tier = 0;
        for (size_t i = 0; i < HEIRLOOM_BAG_TIER_COUNT; ++i)
            if (playerLevel >= HEIRLOOM_BAG_TIERS[i].minLevel)
                tier = static_cast<int32>(i);

        return tier;
    }

    // Swaps an equipped heirloom bag for the next tier once the owner's level
    // qualifies. Only call this from contexts outside the item-equip call stack
    // (OnPlayerLevelChanged, OnPlayerLogin) - it destroys and recreates the item,
    // and Player::EquipItem() still holds/returns its own pItem pointer to its
    // caller right after firing OnPlayerEquip, so destroying that same item from
    // inside OnPlayerEquip would hand the engine a dangling pointer.
    //
    // Contents are relocated via the same CanStoreItem/StoreItem path every other
    // item move uses (not manual Bag::StoreItem surgery), so a player with nowhere
    // else to put their stuff just skips the upgrade this pass instead of risking
    // a partial/duplicated move; it retries next trigger.
    void UpgradeHeirloomBagIfNeeded(Player* player, Bag* bag)
    {
        if (!player || !bag)
            return;

        int32 const currentTier = FindHeirloomBagTierIndex(bag->GetEntry());
        if (currentTier < 0)
            return;

        int32 const desiredTier = DesiredHeirloomBagTierIndex(player->GetLevel());
        if (desiredTier <= currentTier)
            return;

        uint8 const bagSlot = bag->GetSlot();
        if (bagSlot < INVENTORY_SLOT_BAG_START || bagSlot >= INVENTORY_SLOT_BAG_END)
            return; // equipped bag-bar slots only, never bank

        struct StagedItem
        {
            Item* item;
            uint8 originalSlot;
        };

        std::vector<StagedItem> staged;
        for (uint32 i = 0; i < bag->GetBagSize(); ++i)
            if (Item* contained = bag->GetItemByPos(static_cast<uint8>(i)))
                staged.push_back({ contained, static_cast<uint8>(i) });

        std::vector<Item*> relocated;
        relocated.reserve(staged.size());
        bool allRelocated = true;

        for (StagedItem const& entry : staged)
        {
            ItemPosCountVec dest;
            if (player->CanStoreItem(NULL_BAG, NULL_SLOT, dest, entry.item, false) != EQUIP_ERR_OK)
            {
                allRelocated = false;
                break;
            }

            player->RemoveItem(bagSlot, entry.originalSlot, true);
            player->StoreItem(dest, entry.item, true);
            relocated.push_back(entry.item);
        }

        if (!allRelocated)
        {
            // Not enough free space elsewhere to hold this bag's contents - put back
            // whatever was already moved and try again next trigger.
            for (Item* item : relocated)
            {
                ItemPosCountVec dest;
                if (player->CanStoreItem(bagSlot, NULL_SLOT, dest, item, false) == EQUIP_ERR_OK)
                {
                    player->RemoveItem(item->GetBagSlot(), item->GetSlot(), true);
                    player->StoreItem(dest, item, true);
                }
            }

            return;
        }

        HeirloomBagTier const& nextTier = HEIRLOOM_BAG_TIERS[desiredTier];
        player->DestroyItem(INVENTORY_SLOT_BAG_0, bagSlot, true);

        uint16 const pos = static_cast<uint16>((INVENTORY_SLOT_BAG_0 << 8) | bagSlot);
        if (Item* newBag = player->EquipNewItem(pos, nextTier.entry, true))
        {
            player->SendNewItem(newBag, 1, true, false);
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffe6cc80[Heirloom]|r Your bag grew to {} slots!", nextTier.slots);
        }
    }

    uint32 GetNearestAvailableScalingLevel(uint32 requestedLevel)
    {
        if (requestedLevel == 0)
            return 0;

        uint32 level = requestedLevel;
        uint32 const rowCount = sScalingStatValuesStore.GetNumRows();
        if (rowCount == 0)
            return 0;

        if (level >= rowCount)
            level = rowCount - 1;

        for (; level > 0; --level)
            if (ScalingStatValuesEntry const* ssv = sScalingStatValuesStore.LookupEntry(level))
                return ssv->Level;

        return 0;
    }

    float GetHeirloomScalingBoost(Player* player, ItemTemplate const* proto)
    {
        if (!player || !proto)
            return 1.0f;

        if (proto->Quality != ITEM_QUALITY_HEIRLOOM || !proto->ScalingStatDistribution)
            return 1.0f;

        ScalingStatDistributionEntry const* ssd =
            sScalingStatDistributionStore.LookupEntry(proto->ScalingStatDistribution);
        if (!ssd)
            return 1.0f;

        uint32 requestedLevel = player->GetLevel();
        if (requestedLevel > ssd->MaxLevel)
            requestedLevel = ssd->MaxLevel;

        uint32 referenceLevel = GetNearestAvailableScalingLevel(requestedLevel);
        if (referenceLevel == 0 || player->GetLevel() <= referenceLevel)
            return 1.0f;

        float normalizedDelta =
            float(player->GetLevel() - referenceLevel) / float(referenceLevel);
        float scalingBoost =
            1.0f + normalizedDelta + HEIRLOOM_PROGRESSIVE_CURVE * normalizedDelta * normalizedDelta;
        if (scalingBoost > HEIRLOOM_MAX_SCALING_BOOST)
            scalingBoost = HEIRLOOM_MAX_SCALING_BOOST;

        return scalingBoost;
    }
}

class heirloom_scaling_255 : public PlayerScript
{
public:
    heirloom_scaling_255() : PlayerScript("heirloom_scaling_255") { }

    // Hook during stat calculation to extend heirloom scaling past the last
    // available ScalingStatValues.dbc row.
    void OnPlayerCustomScalingStatValue(Player* player, ItemTemplate const* proto, uint32& statType, int32& val,
                                       uint8 itemProtoStatNumber, uint32 ScalingStatValue, ScalingStatValuesEntry const* ssv) override
    {
        if (!player || !proto || !ssv)
            return;

        // Only process heirloom items
        if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
            return;

        if (!proto->ScalingStatDistribution || !ScalingStatValue)
            return;

        float scalingBoost = GetHeirloomScalingBoost(player, proto);
        if (scalingBoost <= 1.0f)
            return;

        ScalingStatDistributionEntry const* ssd = proto->ScalingStatDistribution ?
            sScalingStatDistributionStore.LookupEntry(proto->ScalingStatDistribution) : nullptr;

        if (!ssd)
            return;

        if (ssd->StatMod[itemProtoStatNumber] >= 0)
        {
            statType = ssd->StatMod[itemProtoStatNumber];
            val = int32(float(val) * scalingBoost);
        }
    }

    void OnPlayerApplyWeaponDamage(Player* player, uint8 /*slot*/, ItemTemplate const* proto,
        float& minDamage, float& maxDamage, uint8 /*damageIndex*/) override
    {
        float scalingBoost = GetHeirloomScalingBoost(player, proto);
        if (scalingBoost <= 1.0f)
            return;

        minDamage *= scalingBoost;
        maxDamage *= scalingBoost;
    }

    // Hook to bypass level requirements for heirloom items
    // Allows heirlooms to be equipped at any level up to 255
    bool OnPlayerCanUseItem(Player* player, ItemTemplate const* proto, InventoryResult& result) override
    {
        if (!player || !proto)
            return true;

        // Only modify behavior for heirloom items
        if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
            return true;

        // Override EQUIP_ERR_CANT_EQUIP_LEVEL_I errors (RequiredLevel check)
        // The MaxLevel check in PlayerStorage.cpp:1859 has been patched to skip heirlooms
        if (result == EQUIP_ERR_CANT_EQUIP_LEVEL_I)
        {
            result = EQUIP_ERR_OK;
        }

        return true;
    }

    // Equipped heirloom bags only (never bank) - swaps each to the tier matching the
    // player's new level. Safe here (unlike OnPlayerEquip): this isn't nested inside
    // Player::EquipItem()'s own call stack, so destroying/recreating the item can't
    // hand back a dangling pointer to anything still using it.
    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (!player)
            return;

        for (uint8 slot = INVENTORY_SLOT_BAG_START; slot < INVENTORY_SLOT_BAG_END; ++slot)
            if (Bag* bag = player->GetBagByPos(slot))
                UpgradeHeirloomBagIfNeeded(player, bag);
    }

    // Catches the case where a bag was granted (or last logged out) below the tier
    // its owner's current level now qualifies for.
    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;

        for (uint8 slot = INVENTORY_SLOT_BAG_START; slot < INVENTORY_SLOT_BAG_END; ++slot)
            if (Bag* bag = player->GetBagByPos(slot))
                UpgradeHeirloomBagIfNeeded(player, bag);
    }

    // Auto-equip the Heirloom Adventurer's Shirt into the (empty) shirt slot when a
    // quest awards it, so the player wears it immediately without opening their bags.
    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (!player || !item || item->GetEntry() != HEIRLOOM_SHIRT_ITEM)
            return;

        uint16 dest;
        // swap=false makes CanEquipItem fail if the shirt slot is already occupied,
        // so we never displace a shirt the player is intentionally wearing.
        if (player->CanEquipItem(NULL_SLOT, dest, item, false) != EQUIP_ERR_OK)
            return;

        player->RemoveItem(item->GetBagSlot(), item->GetSlot(), true);
        player->EquipItem(dest, item, true);
    }
};

void AddSC_heirloom_scaling_255()
{
    new heirloom_scaling_255();
}
