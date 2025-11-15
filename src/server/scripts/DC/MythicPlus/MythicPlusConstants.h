/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * MythicPlusConstants.h - Shared constants for Mythic+ system
 * Eliminates code duplication across multiple files
 */

#ifndef MYTHIC_PLUS_CONSTANTS_H
#define MYTHIC_PLUS_CONSTANTS_H

#include <cstdint>
#include <string>

namespace MythicPlusConstants
{
    // Keystone item IDs (M+2 through M+20)
    constexpr uint32 KEYSTONE_ITEM_IDS[19] = {
        190001, 190002, 190003, 190004, 190005, // M+2 to M+6
        190006, 190007, 190008, 190009, 190010, // M+7 to M+11
        190011, 190012, 190013, 190014, 190015, // M+12 to M+16
        190016, 190017, 190018, 190019          // M+17 to M+20
    };
    
    constexpr uint8 MIN_KEYSTONE_LEVEL = 2;
    constexpr uint8 MAX_KEYSTONE_LEVEL = 20;
    constexpr uint32 KEYSTONE_DURATION_SECONDS = 604800; // 7 days
    
    // NPC entries
    constexpr uint32 NPC_KEYSTONE_VENDOR = 100100;
    constexpr uint32 NPC_GREAT_VAULT = 100050;
    constexpr uint32 NPC_STATISTICS = 100060;
    constexpr uint32 NPC_TOKEN_VENDOR = 190005;
    
    // GameObject entries
    constexpr uint32 GO_FONT_OF_POWER_START = 700001;
    constexpr uint32 GO_FONT_OF_POWER_END = 700008;
    constexpr uint32 GO_KEYSTONE_PEDESTAL = 300200;
    
    // Token items
    constexpr uint32 ITEM_MYTHIC_TOKEN = 101000;
    constexpr uint32 ITEM_UPGRADE_TOKEN = 100999;
    
    /**
     * Get keystone level from item ID
     * @param itemId Item entry from item_template
     * @return Keystone level (2-20) or 0 if invalid
     */
    inline uint8 GetKeystoneLevelFromItemId(uint32 itemId)
    {
        for (uint8 i = 0; i < 19; ++i)
        {
            if (KEYSTONE_ITEM_IDS[i] == itemId)
                return i + MIN_KEYSTONE_LEVEL;
        }
        return 0;
    }
    
    /**
     * Get item ID from keystone level
     * @param level Keystone level (2-20)
     * @return Item entry or 0 if invalid
     */
    inline uint32 GetItemIdFromKeystoneLevel(uint8 level)
    {
        if (level < MIN_KEYSTONE_LEVEL || level > MAX_KEYSTONE_LEVEL)
            return 0;
        return KEYSTONE_ITEM_IDS[level - MIN_KEYSTONE_LEVEL];
    }
    
    /**
     * Get colored keystone name for display
     * @param keystoneLevel Keystone level (2-20)
     * @return Colored string with WoW color codes
     */
    inline std::string GetKeystoneColoredName(uint8 keystoneLevel)
    {
        if (keystoneLevel < MIN_KEYSTONE_LEVEL || keystoneLevel > MAX_KEYSTONE_LEVEL)
            return "|cffaaaaaa[Unknown]|r";
        
        // Color progression: Blue (2-4), Green (5-7), Purple (8-13), Orange (14-20)
        if (keystoneLevel >= 2 && keystoneLevel <= 4)
            return "|cff0070dd[Mythic +" + std::to_string(keystoneLevel) + "]|r"; // Blue (Rare)
        else if (keystoneLevel >= 5 && keystoneLevel <= 7)
            return "|cff1eff00[Mythic +" + std::to_string(keystoneLevel) + "]|r"; // Green (Uncommon)
        else if (keystoneLevel >= 8 && keystoneLevel <= 13)
            return "|cffa335ee[Mythic +" + std::to_string(keystoneLevel) + "]|r"; // Purple (Epic)
        else
            return "|cffff8000[Mythic +" + std::to_string(keystoneLevel) + "]|r"; // Orange (Legendary)
    }
    
    /**
     * Calculate item level for a given keystone level
     * Formula: 213 + (level × 3)
     * @param keystoneLevel Keystone level (2-20)
     * @return Item level
     */
    inline uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel)
    {
        if (keystoneLevel < MIN_KEYSTONE_LEVEL)
            return 213; // Base Mythic ilvl
        if (keystoneLevel > MAX_KEYSTONE_LEVEL)
            keystoneLevel = MAX_KEYSTONE_LEVEL;
        
        return 213 + (keystoneLevel * 3);
    }
    
    /**
     * Calculate token reward for a given keystone level
     * Formula: 20 + (level × 5)
     * @param keystoneLevel Keystone level (2-20)
     * @return Token count
     */
    inline uint32 GetTokenRewardForKeystoneLevel(uint8 keystoneLevel)
    {
        if (keystoneLevel < MIN_KEYSTONE_LEVEL)
            return 20;
        if (keystoneLevel > MAX_KEYSTONE_LEVEL)
            keystoneLevel = MAX_KEYSTONE_LEVEL;
        
        return 20 + (keystoneLevel * 5);
    }
    
    /**
     * Calculate death budget for keystone level
     * Formula: base_budget - (level × 1), minimum 5
     * @param keystoneLevel Keystone level (2-20)
     * @param baseBudget Base death budget from dungeon profile
     * @return Adjusted death budget
     */
    inline uint8 CalculateDeathBudget(uint8 keystoneLevel, uint8 baseBudget)
    {
        int32 adjusted = static_cast<int32>(baseBudget) - keystoneLevel;
        return static_cast<uint8>(std::max(5, adjusted));
    }
    
    /**
     * Check if GameObject is a Font of Power
     * @param entry GameObject entry
     * @return True if Font of Power
     */
    inline bool IsFontOfPower(uint32 entry)
    {
        return entry >= GO_FONT_OF_POWER_START && entry <= GO_FONT OF_POWER_END;
    }
}

#endif // MYTHIC_PLUS_CONSTANTS_H
