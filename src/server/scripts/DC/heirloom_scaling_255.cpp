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

/*
 * Heirloom Scaling Extension to Level 255
 * 
 * This script extends heirloom item scaling beyond the default DBC cap (level 80)
 * up to level 255 for custom high-level servers.
 * 
 * Features:
 * - Scales heirloom armor/weapons stats (Strength, Stamina, etc.)
 * - Scales heirloom bag slots (containers get more slots at higher levels)
 * 
 * How it works:
 * - Intercepts the ScalingStatValue lookup before DBC capping occurs
 * - For heirloom items (Quality 7, Flags 134221824), uses level 80 scaling data
 *   and extrapolates it with 2x accelerated scaling for levels 81-255
 * - Maintains proper stat scaling ratios while extending the level range
 * - For bags: increases ContainerSlots based on player level
 */

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
        // Accelerated scaling: 2x the normal rate for levels above 80
        // Formula: 1.0 + 2 * (current_level - max_dbc_level) / max_dbc_level
        // Examples:
        //   Level 80:  1.0x (baseline)
        //   Level 120: 2.0x (was 1.5x with old formula)
        //   Level 160: 3.0x (was 2.0x with old formula)
        //   Level 200: 4.0x (was 2.5x with old formula)
        //   Level 240: 5.0x (was 3.0x with old formula)
        float levelDifference = float(playerLevel - ssd->MaxLevel);
        float scalingBoost = 1.0f + (2.0f * levelDifference / float(ssd->MaxLevel));
        
        // For extreme high levels, cap the boost to prevent absurd values
        // Increased cap to 8x for level 255 with accelerated scaling
        const float MAX_SCALING_BOOST = 8.0f; // Max 8x the level 80 stats at level 255
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

        uint32 playerLevel = player->GetLevel();
        
        // Heirloom bag scaling: 12 slots at level 1, scaling to 36 slots at level 130
        // Linear progression: slots = 12 + (level - 1) * (36 - 12) / (130 - 1)
        // Simplified: slots = 12 + (level - 1) * 24 / 129
        
        const uint32 MIN_SLOTS = 12;      // Starting slots at level 1
        const uint32 MAX_SLOTS = 36;      // Maximum slots at level 130 (also WoW client hard cap)
        const uint32 MAX_SCALE_LEVEL = 130; // Level at which bag reaches max size
        
        uint32 scaledSlots = MIN_SLOTS;
        
        if (playerLevel >= MAX_SCALE_LEVEL)
        {
            // At or above level 130, use max slots
            scaledSlots = MAX_SLOTS;
        }
        else if (playerLevel > 1)
        {
            // Linear scaling from level 1 to 130
            // Formula: MIN_SLOTS + (current_level - 1) * (MAX_SLOTS - MIN_SLOTS) / (MAX_SCALE_LEVEL - 1)
            float progression = float(playerLevel - 1) / float(MAX_SCALE_LEVEL - 1);
            scaledSlots = MIN_SLOTS + uint32(progression * float(MAX_SLOTS - MIN_SLOTS));
        }

        // Update bag size
        if (scaledSlots >= MIN_SLOTS && scaledSlots <= MAX_SLOTS)
        {
            bag->SetUInt32Value(CONTAINER_FIELD_NUM_SLOTS, scaledSlots);
        }
    }
};

void AddSC_heirloom_scaling_255()
{
    new heirloom_scaling_255();
}
