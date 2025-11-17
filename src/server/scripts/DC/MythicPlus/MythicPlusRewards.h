/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_PLUS_REWARDS_H
#define MYTHIC_PLUS_REWARDS_H

#include <cstdint>

// Item level calculation based on keystone level (simplified progression)
// Simplified tier system with higher rewards:
// M+2-4: 239 ilvl
// M+5-7: 252 ilvl
// M+8-11: 264 ilvl
// M+12+: 277 ilvl (+13 per tier beyond M+12)
inline uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel)
{
    if (keystoneLevel < 2)
        return 226; // Mythic 0 baseline (increased from 190)
    if (keystoneLevel <= 4)
        return 239; // M+2-4: Tier 1
    if (keystoneLevel <= 7)
        return 252; // M+5-7: Tier 2
    if (keystoneLevel <= 11)
        return 264; // M+8-11: Tier 3
    
    // M+12+: 277 base + 13 per tier (M+16=290, M+20=303, etc.)
    return 277 + (((keystoneLevel - 12) / 4) * 13);
}

#endif // MYTHIC_PLUS_REWARDS_H
