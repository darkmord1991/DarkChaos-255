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
    constexpr uint32 HEIRLOOM_BAG_MIN_SLOTS   = 16;
    constexpr uint32 HEIRLOOM_BAG_MAX_SLOTS   = 36; // Client hard cap
    constexpr uint32 HEIRLOOM_BAG_MAX_LEVEL   = 130;
    constexpr float HEIRLOOM_MAX_SCALING_BOOST = 4.0f;
    constexpr float HEIRLOOM_PROGRESSIVE_CURVE = 0.08f;

    uint32 CalculateHeirloomBagSlots(uint32 playerLevel)
    {
        if (playerLevel <= 1)
            return HEIRLOOM_BAG_MIN_SLOTS;

        if (playerLevel >= HEIRLOOM_BAG_MAX_LEVEL)
            return HEIRLOOM_BAG_MAX_SLOTS;

        float progression = float(playerLevel - 1) / float(HEIRLOOM_BAG_MAX_LEVEL - 1);
        float slotGain = float(HEIRLOOM_BAG_MAX_SLOTS - HEIRLOOM_BAG_MIN_SLOTS);
        uint32 scaledSlots = HEIRLOOM_BAG_MIN_SLOTS + uint32(progression * slotGain);

        if (scaledSlots > HEIRLOOM_BAG_MAX_SLOTS)
            return HEIRLOOM_BAG_MAX_SLOTS;

        if (scaledSlots < HEIRLOOM_BAG_MIN_SLOTS)
            return HEIRLOOM_BAG_MIN_SLOTS;

        return scaledSlots;
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
        ApplyHeirloomBagScaling(player);

        // Send a message to player about bag slots update (if changed)
        for (uint8 slot = INVENTORY_SLOT_BAG_START; slot < INVENTORY_SLOT_BAG_END; ++slot)
        {
            if (Bag* bag = player->GetBagByPos(slot))
            {
                ItemTemplate const* proto = bag->GetTemplate();
                if (proto && proto->Quality == ITEM_QUALITY_HEIRLOOM && proto->Class == ITEM_CLASS_CONTAINER)
                {
                    uint32 desiredSlots = CalculateHeirloomBagSlots(player->GetLevel());
                    if (bag->GetBagSize() != desiredSlots)
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("Your heirloom bag has been upgraded! Relog or re-equip to see the new slots.");
                    }
                }
            }
        }
    }

    void OnPlayerLogin(Player* player) override
    {
        ApplyHeirloomBagScaling(player);
    }
};

void AddSC_heirloom_scaling_255()
{
    new heirloom_scaling_255();
}
