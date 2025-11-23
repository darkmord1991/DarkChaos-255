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
 * - Scales heirloom bag slots (containers get more slots at higher levels)
 * - Respects upgrade system for secondary stat bonuses
 * 
 * How it works:
 * - Intercepts the ScalingStatValue lookup before DBC capping occurs
 * - For heirloom items (Quality 7), uses level 80 scaling data
 *   and extrapolates it with linear scaling for levels 81-255
 * - Maintains proper stat scaling ratios while extending the level range
 * - For bags: increases ContainerSlots based on player level
 */

namespace {
    constexpr uint32 HEIRLOOM_BAG_MIN_SLOTS   = 16;
    constexpr uint32 HEIRLOOM_BAG_MAX_SLOTS   = 36; // Client hard cap
    constexpr uint32 HEIRLOOM_BAG_MAX_LEVEL   = 130;

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
        
        // Force update the player's inventory to reflect changes
        player->SetUInt32Value(PLAYER_FIELD_NUM_RESPECS, player->GetUInt32Value(PLAYER_FIELD_NUM_RESPECS));
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
}

class heirloom_scaling_255 : public PlayerScript
{
public:
    heirloom_scaling_255() : PlayerScript("heirloom_scaling_255") { }

    // Hook before ScalingStatValue is processed
    void OnPlayerCustomScalingStatValueBefore(Player* player, ItemTemplate const* proto, uint8 /*slot*/, bool /*apply*/, uint32& CustomScalingStatValue) override
    {
        if (!player || !proto)
            return;

        // Only process heirloom items (Quality 7, Flags 134221824)
        if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
            return;

        // Check if item has ScalingStatDistribution (heirlooms do)
        if (!proto->ScalingStatDistribution)
            return;

        ScalingStatDistributionEntry const* ssd = sScalingStatDistributionStore.LookupEntry(proto->ScalingStatDistribution);
        if (!ssd)
            return;

        uint32 playerLevel = player->GetLevel();
        
        // If player is at or below the DBC max level, let normal scaling handle it
        if (playerLevel <= ssd->MaxLevel)
            return;

        // For levels above MaxLevel (typically 80), we need to extend scaling
        // We'll use the ScalingStatValue from MaxLevel as the base
        // and apply linear extrapolation for higher levels
        
        // The ScalingStatValue determines which row of ScalingStatValues.dbc to use
        // We want to use the level 80 entry as reference
        uint32 baseScalingValue = proto->ScalingStatValue;
        
        if (baseScalingValue == 0)
            return;

        // Get the level 80 (MaxLevel) entry as our baseline
        ScalingStatValuesEntry const* baseSSV = sScalingStatValuesStore.LookupEntry(ssd->MaxLevel);
        if (!baseSSV)
            return;

        // Calculate scaling factor: how much more powerful should the item be at this level
        // Linear scaling: normal rate for levels above 80
        // Formula: 1.0 + (current_level - max_dbc_level) / max_dbc_level
        // Examples:
        //   Level 80:  1.0x (baseline)
        //   Level 120: 1.5x
        //   Level 160: 2.0x
        //   Level 200: 2.5x
        //   Level 240: 3.0x
        float levelDifference = float(playerLevel - ssd->MaxLevel);
        float scalingBoost = 1.0f + (levelDifference / float(ssd->MaxLevel));
        
        // For extreme high levels, cap the boost to prevent absurd values
        const float MAX_SCALING_BOOST = 4.0f; // Max 4x the level 80 stats at level 255
        if (scalingBoost > MAX_SCALING_BOOST)
            scalingBoost = MAX_SCALING_BOOST;

        // We can't modify the DBC data directly, but we can influence the stat calculation
        // by overriding CustomScalingStatValue to signal our custom handler
        // We'll encode the boost information in the upper bits
        
        // Store: original value in lower 16 bits, boost multiplier * 100 in upper 16 bits
        uint32 boostEncoded = uint32(scalingBoost * 100.0f);
        CustomScalingStatValue = (boostEncoded << 16) | (baseScalingValue & 0xFFFF);
    }

    // Hook during stat calculation to apply our custom scaling
    void OnPlayerCustomScalingStatValue(Player* player, ItemTemplate const* proto, uint32& statType, int32& val, 
                                       uint8 itemProtoStatNumber, uint32 ScalingStatValue, ScalingStatValuesEntry const* ssv) override
    {
        if (!player || !proto || !ssv)
            return;

        // Only process heirloom items
        if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
            return;

        // Check if this is our custom encoded value
        if (ScalingStatValue == 0 || (ScalingStatValue >> 16) == 0)
            return;

        // Decode the boost multiplier
        uint32 boostEncoded = ScalingStatValue >> 16;
        uint32 baseScalingValue = ScalingStatValue & 0xFFFF;
        float scalingBoost = float(boostEncoded) / 100.0f;

        ScalingStatDistributionEntry const* ssd = proto->ScalingStatDistribution ? 
            sScalingStatDistributionStore.LookupEntry(proto->ScalingStatDistribution) : nullptr;
        
        if (!ssd)
            return;

        // Get player's actual level
        uint32 playerLevel = player->GetLevel();
        
        // Only apply boost for levels above MaxLevel
        if (playerLevel <= ssd->MaxLevel)
            return;

        // Get the base stats from level 80 (or whatever MaxLevel is)
        ScalingStatValuesEntry const* baseSSV = sScalingStatValuesStore.LookupEntry(ssd->MaxLevel);
        if (!baseSSV)
            return;

        // Calculate the stat value at max DBC level
        if (ssd->StatMod[itemProtoStatNumber] >= 0)
        {
            statType = ssd->StatMod[itemProtoStatNumber];
            int32 baseVal = (baseSSV->getssdMultiplier(baseScalingValue) * ssd->Modifier[itemProtoStatNumber]) / 10000;
            
            // Apply the scaling boost
            val = int32(float(baseVal) * scalingBoost);
        }
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
