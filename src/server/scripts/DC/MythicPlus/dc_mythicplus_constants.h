/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * dc_mythicplus_constants.h - Shared constants for Mythic+ system
 * Eliminates code duplication across multiple files
 */

#ifndef DC_MYTHICPLUS_CONSTANTS_H
#define DC_MYTHICPLUS_CONSTANTS_H

#include <algorithm>
#include <cstdint>
#include <string>

namespace MythicPlusConstants
{
    // Keystone item IDs (M+2 through M+20)
    constexpr uint32 KEYSTONE_ITEM_IDS[19] = {
        300313, 300314, 300315, 300316, 300317, // M+2 to M+6
        300318, 300319, 300320, 300321, 300322, // M+7 to M+11
        300323, 300324, 300325, 300326, 300327, // M+12 to M+16
        300328, 300329, 300330, 300331          // M+17 to M+20
    };

    constexpr uint8 MIN_KEYSTONE_LEVEL = 2;
    constexpr uint8 MAX_KEYSTONE_LEVEL = 20;
    constexpr uint32 KEYSTONE_DURATION_SECONDS = 604800; // 7 days

    // NPC entries
    constexpr uint32 NPC_KEYSTONE_VENDOR = 100100;
    constexpr uint32 NPC_PORTAL_SELECTOR = 100101;
    constexpr uint32 NPC_GREAT_VAULT = 100050;
    constexpr uint32 NPC_STATISTICS = 100060;
    // NOTE: numerically equal to the M+6 keystone ITEM id above. Different id
    // spaces (creature_template vs item_template), so this is legal - but do not
    // "simplify" one into the other.
    constexpr uint32 NPC_TOKEN_VENDOR = 300317;

    // GameObject entries
    constexpr uint32 GO_FONT_OF_POWER = 700001;  // Keystone activation pedestal
    constexpr uint32 GO_KEYSTONE_PEDESTAL = 700001;

    // Difficulty multiplier curve used for token payouts. Shared so the
    // keystone tooltip, the .mplus commands and the actual award all quote the
    // same number - they used to carry three different formulas.
    constexpr float MYTHIC_BASE_MULTIPLIER = 2.0f;
    constexpr float KEYSTONE_LEVEL_STEP = 0.25f;

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
     * Simplified tier system:
     * M+2-4: 239 ilvl
     * M+5-7: 252 ilvl
     * M+8-11: 264 ilvl
     * M+12+: 277+ ilvl (13 per tier)
     * @param keystoneLevel Keystone level (2-20)
     * @return Item level
     */
    inline uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel)
    {
        if (keystoneLevel < MIN_KEYSTONE_LEVEL)
            return 226; // Base Mythic ilvl
        if (keystoneLevel > MAX_KEYSTONE_LEVEL)
            keystoneLevel = MAX_KEYSTONE_LEVEL;

        if (keystoneLevel <= 4)
            return 239; // M+2-4: Tier 1
        if (keystoneLevel <= 7)
            return 252; // M+5-7: Tier 2
        if (keystoneLevel <= 11)
            return 264; // M+8-11: Tier 3

        // M+12+: 277 + 13 per tier
        return 277 + (((keystoneLevel - 12) / 4) * 13);
    }

    /**
     * Token payout multiplier for a Mythic (EPIC) run at the given key level.
     * @param keystoneLevel Keystone level, 0 for plain Mythic with no key
     */
    inline float GetTokenKeystoneMultiplier(uint8 keystoneLevel)
    {
        if (keystoneLevel == 0)
            return MYTHIC_BASE_MULTIPLIER;

        return MYTHIC_BASE_MULTIPLIER + (keystoneLevel * KEYSTONE_LEVEL_STEP);
    }

    /**
     * Base token pool before the difficulty multiplier is applied. Scales past
     * level 70 so a 255 character is not paid like a fresh 70.
     * @param playerLevel Character level
     */
    inline uint32 GetBaseTokenReward(uint8 playerLevel)
    {
        uint32 baseTokens = 10;
        if (playerLevel > 70)
            baseTokens += (playerLevel - 70) * 2;

        return baseTokens;
    }

    /**
     * The single source of truth for "how many tokens does this run pay".
     * MythicPlusRunManager::AwardTokens, the keystone tooltip and the .mplus
     * commands all route through here so they can never disagree again.
     * @param playerLevel Character level
     * @param keystoneLevel Keystone level (0 for plain Mythic)
     * @return Token count, never below 1
     */
    inline uint32 CalculateTokenReward(uint8 playerLevel, uint8 keystoneLevel)
    {
        float multiplier = GetTokenKeystoneMultiplier(keystoneLevel);
        uint32 tokenCount = static_cast<uint32>(
            GetBaseTokenReward(playerLevel) * multiplier);

        return std::max<uint32>(tokenCount, 1);
    }

    namespace Hud
    {
        // Keep custom world states in a high, isolated range to avoid clashing
        // with Blizzard-native world states that can spawn unwanted UI widgets.
        constexpr uint32 WORLD_STATE_BASE      = 0xF100;
        constexpr uint32 ACTIVE                = WORLD_STATE_BASE + 0;
        constexpr uint32 TIMER_REMAINING       = WORLD_STATE_BASE + 1;
        constexpr uint32 TIMER_ELAPSED         = WORLD_STATE_BASE + 2;
        constexpr uint32 BOSSES_TOTAL          = WORLD_STATE_BASE + 3;
        constexpr uint32 BOSSES_KILLED         = WORLD_STATE_BASE + 4;
        constexpr uint32 DEATHS                = WORLD_STATE_BASE + 5;
        constexpr uint32 WIPES                 = WORLD_STATE_BASE + 6;
        constexpr uint32 KEYSTONE_LEVEL        = WORLD_STATE_BASE + 7;
        constexpr uint32 DUNGEON_ID            = WORLD_STATE_BASE + 8;
        constexpr uint32 RESULT                = WORLD_STATE_BASE + 9;
        constexpr uint32 AFFIX_ONE             = WORLD_STATE_BASE + 10;
        constexpr uint32 AFFIX_TWO             = WORLD_STATE_BASE + 11;
        constexpr uint32 CHEST_TIER            = WORLD_STATE_BASE + 12;
        constexpr uint32 OWNER_GUID_LOW        = WORLD_STATE_BASE + 13;
        constexpr uint32 TIMER_DURATION        = WORLD_STATE_BASE + 14;
        constexpr uint32 COUNTDOWN_REMAINING   = WORLD_STATE_BASE + 15;

        constexpr uint32 BOSS_ENTRY_BASE       = WORLD_STATE_BASE + 32;
        constexpr uint32 BOSS_KILLTIME_BASE    = WORLD_STATE_BASE + 64;
        constexpr uint32 MAX_TRACKED_BOSSES    = 12;

        constexpr char const* AIO_ADDON_NAME   = "DCMythicPlusHUD";
        constexpr char const* AIO_MSG_UPDATE   = "HUD";
    }
}

#endif // DC_MYTHICPLUS_CONSTANTS_H
