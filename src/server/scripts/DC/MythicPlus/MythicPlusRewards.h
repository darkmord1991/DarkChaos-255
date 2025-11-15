/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_PLUS_REWARDS_H
#define MYTHIC_PLUS_REWARDS_H

#include <cstdint>

// Item level calculation based on keystone level (retail-style)
// Base item levels follow retail Mythic+ structure
// M+2: ilvl 200, M+3: 203, M+4: 207, etc.
inline uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel)
{
    if (keystoneLevel < 2)
        return 190; // Mythic 0 baseline
    if (keystoneLevel <= 7)
        return 200 + ((keystoneLevel - 2) * 3); // M+2-7: 200, 203, 207, 210, 213, 216
    if (keystoneLevel <= 10)
        return 216 + ((keystoneLevel - 7) * 4); // M+8-10: 220, 224, 228
    if (keystoneLevel <= 15)
        return 228 + ((keystoneLevel - 10) * 4); // M+11-15: 232, 236, 240, 244, 248
    
    // Beyond M+15: +3 ilvl per level
    return 248 + ((keystoneLevel - 15) * 3);
}

#endif // MYTHIC_PLUS_REWARDS_H
