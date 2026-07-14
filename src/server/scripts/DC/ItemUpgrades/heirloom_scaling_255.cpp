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

    // Level -> slot count. Delegates to Bag::GetHeirloomBagSlots so the runtime scaler and the
    // inventory loader (Player::_LoadItem) always agree - a mismatch would strand items in the
    // grown slots on relog.
    uint32 CalculateHeirloomBagSlots(uint32 playerLevel)
    {
        return Bag::GetHeirloomBagSlots(playerLevel);
    }

    void ApplyHeirloomBagScaling(Player* player, Bag* bag)
    {
        if (!player || !bag)
            return;

        ItemTemplate const* proto = bag->GetTemplate();
        if (!proto || proto->Quality != ITEM_QUALITY_HEIRLOOM || proto->Class != ITEM_CLASS_CONTAINER)
            return;

        uint32 desiredSlots = CalculateHeirloomBagSlots(player->GetLevel());
        uint32 currentSlots = bag->GetBagSize();

        if (currentSlots == desiredSlots)
            return;

        // Update the bag slot count
        bag->SetUInt32Value(CONTAINER_FIELD_NUM_SLOTS, desiredSlots);

        // Save the updated bag to database
        bag->SaveToDB(nullptr);
    }

    void ApplyHeirloomBagScaling(Player* player)
    {
        if (!player)
            return;

        auto updateRange = [player](uint8 startSlot, uint8 endSlot)
        {
            for (uint8 slot = startSlot; slot < endSlot; ++slot)
                if (Bag* bag = player->GetBagByPos(slot))
                    ApplyHeirloomBagScaling(player, bag);
        };

        updateRange(INVENTORY_SLOT_BAG_START, INVENTORY_SLOT_BAG_END);
        updateRange(BANK_SLOT_BAG_START, BANK_SLOT_BAG_END);
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

    // Hook when player equips an item to scale bag slots for heirloom bags
    void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        if (!player || !item)
            return;

        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return;

        // Only process heirloom bags
        if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
            return;

        if (proto->Class != ITEM_CLASS_CONTAINER)
            return;

        // Cast to Bag to access bag-specific functions
        Bag* bag = item->ToBag();
        if (!bag)
            return;

        ApplyHeirloomBagScaling(player, bag);
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

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (!player)
            return;

        // Scale every equipped heirloom bag and announce any that actually gained slots.
        // (Capturing before/after per bag - the old check compared against the already-applied
        // size, so it never fired.)
        auto processRange = [player](uint8 startSlot, uint8 endSlot)
        {
            for (uint8 slot = startSlot; slot < endSlot; ++slot)
            {
                Bag* bag = player->GetBagByPos(slot);
                if (!bag)
                    continue;

                ItemTemplate const* proto = bag->GetTemplate();
                if (!proto || proto->Quality != ITEM_QUALITY_HEIRLOOM || proto->Class != ITEM_CLASS_CONTAINER)
                    continue;

                uint32 const before = bag->GetBagSize();
                ApplyHeirloomBagScaling(player, bag);
                uint32 const after = bag->GetBagSize();

                if (after > before)
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cffe6cc80[Heirloom]|r Your {} grew to {} bag slots (+{})! Reopen the bag to use the new space.",
                        proto->Name1, after, after - before);
            }
        };

        processRange(INVENTORY_SLOT_BAG_START, INVENTORY_SLOT_BAG_END);
        processRange(BANK_SLOT_BAG_START, BANK_SLOT_BAG_END);
    }

    void OnPlayerLogin(Player* player) override
    {
        ApplyHeirloomBagScaling(player);
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
