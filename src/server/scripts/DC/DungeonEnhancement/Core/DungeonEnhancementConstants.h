/*
 * ============================================================================
 * Dungeon Enhancement System - Core Constants Header
 * ============================================================================
 * Purpose: Define all enums, IDs, action offsets, and constants for the
 *          Dungeon Enhancement system (Mythic+, Mythic raids, Heroic legacy)
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * Namespace: DungeonEnhancement::
 * ============================================================================
 */

#ifndef DUNGEON_ENHANCEMENT_CONSTANTS_H
#define DUNGEON_ENHANCEMENT_CONSTANTS_H

#include "Define.h"
#include <cstdint>

namespace DungeonEnhancement
{
    // ========================================================================
    // SYSTEM VERSION
    // ========================================================================
    constexpr const char* SYSTEM_VERSION = "1.0.0";
    constexpr const char* SYSTEM_NAME = "DungeonEnhancement";
    
    // ========================================================================
    // NPC IDS (190003-190006 range)
    // ========================================================================
    enum NPCIds : uint32
    {
        NPC_MYTHIC_PLUS_DUNGEON_TELEPORTER = 190003,  // Mythic+ dungeon teleporter
        NPC_MYTHIC_RAID_TELEPORTER         = 190004,  // Mythic raid teleporter
        NPC_MYTHIC_TOKEN_VENDOR            = 190005,  // Token vendor NPC
        NPC_KEYSTONE_MASTER                = 190006   // Keystone acquisition NPC
    };

    // ========================================================================
    // GAMEOBJECT IDS (700000-700099 range)
    // ========================================================================
    enum GameObjectIds : uint32
    {
        GAMEOBJECT_GREAT_VAULT         = 700000,  // Weekly vault (major cities)
        GAMEOBJECT_FONT_OF_POWER_BASE  = 700001,  // Font of Power base ID
        
        // Font of Power (per dungeon) - 700001 to 700008
        GAMEOBJECT_FONT_UTGARDE_PINNACLE      = 700001,
        GAMEOBJECT_FONT_HALLS_OF_LIGHTNING    = 700002,
        GAMEOBJECT_FONT_GUNDRAK               = 700003,
        GAMEOBJECT_FONT_HALLS_OF_STONE        = 700004,
        GAMEOBJECT_FONT_BLOOD_FURNACE         = 700005,
        GAMEOBJECT_FONT_SLAVE_PENS            = 700006,
        GAMEOBJECT_FONT_GNOMEREGAN            = 700007,
        GAMEOBJECT_FONT_BLACKROCK_DEPTHS      = 700008,
        
        // Reserved range
        GAMEOBJECT_MYTHIC_PLUS_RESERVED_MAX = 700099
    };

    // ========================================================================
    // ITEM IDS
    // ========================================================================
    enum ItemIds : uint32
    {
        // Keystones (100000-100008 range) - M+2 to M+10
        ITEM_KEYSTONE_BASE = 100000,  // Base keystone item ID
        ITEM_KEYSTONE_M2   = 100000,  // Mythic+2 keystone
        ITEM_KEYSTONE_M3   = 100001,  // Mythic+3 keystone
        ITEM_KEYSTONE_M4   = 100002,  // Mythic+4 keystone
        ITEM_KEYSTONE_M5   = 100003,  // Mythic+5 keystone
        ITEM_KEYSTONE_M6   = 100004,  // Mythic+6 keystone
        ITEM_KEYSTONE_M7   = 100005,  // Mythic+7 keystone
        ITEM_KEYSTONE_M8   = 100006,  // Mythic+8 keystone
        ITEM_KEYSTONE_M9   = 100007,  // Mythic+9 keystone
        ITEM_KEYSTONE_M10  = 100008,  // Mythic+10 keystone
        
        // Tokens
        ITEM_MYTHIC_DUNGEON_TOKEN = 100020,  // Mythic Dungeon Tokens
        ITEM_MYTHIC_RAID_TOKEN    = 100021   // Mythic Raid Tokens
    };

    // ========================================================================
    // ACHIEVEMENT IDS (60001-60999 range)
    // ========================================================================
    enum AchievementIds : uint32
    {
        // Completion Tier Achievements (60001-60004)
        ACHIEVEMENT_MYTHIC_INITIATE       = 60001,  // Complete any M+2
        ACHIEVEMENT_MYTHIC_CHALLENGER     = 60002,  // Complete all 8 at M+2
        ACHIEVEMENT_MYTHIC_CONTENDER      = 60003,  // Complete all 8 at M+5
        ACHIEVEMENT_KEYSTONE_MASTER_S1    = 60004,  // Complete all 8 at M+10
        
        // Challenge Achievements (60005-60009)
        ACHIEVEMENT_FLAWLESS_VICTORY      = 60005,  // M+5 with 0 deaths
        ACHIEVEMENT_DEATHLESS_ASCENT      = 60006,  // M+10 with 0 deaths
        ACHIEVEMENT_SPEED_DEMON           = 60007,  // 10 M+ in one day
        ACHIEVEMENT_CENTURY_CLUB          = 60008,  // 100 M+ total
        ACHIEVEMENT_MYTHIC_VETERAN        = 60009,  // 500 M+ total
        
        // Seasonal Achievements (60010-60011)
        ACHIEVEMENT_SEASON1_CONQUEROR     = 60010,  // Top 100 leaderboard
        ACHIEVEMENT_SEASON1_CHAMPION      = 60011,  // Top 10 overall rating
        
        // Dungeon-Specific Achievements (60012-60019)
        ACHIEVEMENT_UTGARDE_PINNACLE_MASTER   = 60012,
        ACHIEVEMENT_HALLS_OF_LIGHTNING_MASTER = 60013,
        ACHIEVEMENT_GUNDRAK_MASTER            = 60014,
        ACHIEVEMENT_HALLS_OF_STONE_MASTER     = 60015,
        ACHIEVEMENT_BLOOD_FURNACE_MASTER      = 60016,
        ACHIEVEMENT_SLAVE_PENS_MASTER         = 60017,
        ACHIEVEMENT_GNOMEREGAN_MASTER         = 60018,
        ACHIEVEMENT_BLACKROCK_DEPTHS_MASTER   = 60019,
        
        // Hidden Achievements (60020-60022)
        ACHIEVEMENT_SOLO_MYTHIC_PLUS      = 60020,  // Solo M+2
        ACHIEVEMENT_MYTHIC_MARATHON       = 60021,  // All 8 in one day at M+5
        ACHIEVEMENT_PERFECTLY_BALANCED    = 60022   // M+10 with exactly 5 deaths
    };

    // ========================================================================
    // SPELL IDS (Custom affix spells)
    // ========================================================================
    enum SpellIds : uint32
    {
        SPELL_BOLSTERING         = 800010,  // Bolstering affix spell
        SPELL_NECROTIC_WOUND     = 800011,  // Necrotic Wound affix spell
        SPELL_GRIEVOUS_WOUND     = 800012   // Grievous Wound affix spell
    };

    // ========================================================================
    // AFFIX IDS (Mythic+ affixes)
    // ========================================================================
    enum AffixIds : uint32
    {
        AFFIX_TYRANNICAL    = 1,  // Boss affix (+40% HP, +15% damage)
        AFFIX_FORTIFIED     = 2,  // Trash affix (+20% HP, +30% damage)
        AFFIX_BOLSTERING    = 3,  // Trash affix (20% HP/damage stacking)
        AFFIX_RAGING        = 4,  // Trash affix (+50% damage at 30% HP)
        AFFIX_SANGUINE      = 5,  // Trash affix (blood pools on death)
        AFFIX_NECROTIC      = 6,  // Debuff affix (stacking melee damage)
        AFFIX_VOLCANIC      = 7,  // Environmental affix (volcanic plumes)
        AFFIX_GRIEVOUS      = 8   // Debuff affix (DoT below 90% HP)
    };
    enum TitleIds : uint32
    {
        TITLE_S1_KEYSTONE_MASTER = 600,  // "S1 Keystone Master"
        TITLE_THE_DEATHLESS      = 601,  // "the Deathless"
        TITLE_S1_CHAMPION        = 602   // "S1 Champion"
    };

    // ========================================================================
    // GOSSIP ACTION OFFSETS (following DC pattern: GOSSIP_ACTION_INFO_DEF + offset)
    // ========================================================================
    constexpr uint32 GOSSIP_ACTION_BASE = 10000;  // Mythic+ base offset
    
    enum GossipActions : uint32
    {
        // Dungeon Teleporter Actions
        GOSSIP_ACTION_TELEPORT_DUNGEON_BASE   = GOSSIP_ACTION_BASE + 0,   // 10000
        GOSSIP_ACTION_TELEPORT_BACK_TO_CITY   = GOSSIP_ACTION_BASE + 100, // 10100
        
        // Raid Teleporter Actions
        GOSSIP_ACTION_TELEPORT_RAID_BASE      = GOSSIP_ACTION_BASE + 200, // 10200
        
        // Token Vendor Actions
        GOSSIP_ACTION_VENDOR_BROWSE           = GOSSIP_ACTION_BASE + 300, // 10300
        GOSSIP_ACTION_VENDOR_INFO             = GOSSIP_ACTION_BASE + 301, // 10301
        
        // Keystone Master Actions
        GOSSIP_ACTION_KEYSTONE_REQUEST        = GOSSIP_ACTION_BASE + 400, // 10400
        GOSSIP_ACTION_KEYSTONE_INFO           = GOSSIP_ACTION_BASE + 401, // 10401
        GOSSIP_ACTION_KEYSTONE_DESTROY        = GOSSIP_ACTION_BASE + 402, // 10402
        
        // Great Vault Actions
        GOSSIP_ACTION_VAULT_OPEN              = GOSSIP_ACTION_BASE + 500, // 10500
        GOSSIP_ACTION_VAULT_CLAIM_SLOT1       = GOSSIP_ACTION_BASE + 501, // 10501
        GOSSIP_ACTION_VAULT_CLAIM_SLOT2       = GOSSIP_ACTION_BASE + 502, // 10502
        GOSSIP_ACTION_VAULT_CLAIM_SLOT3       = GOSSIP_ACTION_BASE + 503, // 10503
        GOSSIP_ACTION_VAULT_CHOOSE_TOKENS     = GOSSIP_ACTION_BASE + 510, // 10510
        
        // Font of Power Actions
        GOSSIP_ACTION_FONT_ACTIVATE_KEYSTONE  = GOSSIP_ACTION_BASE + 600, // 10600
        GOSSIP_ACTION_FONT_VIEW_AFFIXES       = GOSSIP_ACTION_BASE + 601  // 10601
    };

    // ========================================================================
    // MYTHIC+ DIFFICULTY LEVELS
    // ========================================================================
    enum MythicPlusLevel : uint8
    {
        MYTHIC_PLUS_MIN_LEVEL = 2,   // Mythic+2 (no Mythic+1)
        MYTHIC_PLUS_MAX_LEVEL = 10   // Mythic+10 (Season 1 cap)
    };

    // ========================================================================
    // DIFFICULTY SCALING MULTIPLIERS
    // ========================================================================
    constexpr float DIFFICULTY_MULTIPLIER_NORMAL   = 1.00f;  // Normal (baseline)
    constexpr float DIFFICULTY_MULTIPLIER_HEROIC   = 1.30f;  // Heroic (legacy content)
    constexpr float DIFFICULTY_MULTIPLIER_MYTHIC0  = 1.80f;  // Mythic+0 (no keystone)
    constexpr float DIFFICULTY_MULTIPLIER_MYTHIC_PLUS_BASE = 2.00f;  // M+2 starting point
    constexpr float DIFFICULTY_MULTIPLIER_SCALING_PER_LEVEL = 0.15f; // +15% per M+ level

    // Example: M+5 = 2.00 * (1 + (5-2) * 0.15) = 2.00 * 1.45 = 2.90x
    inline float GetMythicPlusMultiplier(uint8 keystoneLevel)
    {
        if (keystoneLevel < MYTHIC_PLUS_MIN_LEVEL)
            return DIFFICULTY_MULTIPLIER_MYTHIC0;
        
        return DIFFICULTY_MULTIPLIER_MYTHIC_PLUS_BASE * 
               (1.0f + (keystoneLevel - MYTHIC_PLUS_MIN_LEVEL) * DIFFICULTY_MULTIPLIER_SCALING_PER_LEVEL);
    }

    // ========================================================================
    // DEATH PENALTY SYSTEM (M+ DUNGEONS ONLY)
    // ========================================================================
    constexpr uint8 MAX_DEATHS_BEFORE_PENALTY = 15;  // 50% reward penalty at 15+ deaths (no auto-fail)
    constexpr float DEATH_PENALTY_TOKEN_MULTIPLIER = 0.50f;  // 50% tokens at 15+ deaths

    // Keystone upgrade thresholds (based on death count at completion)
    constexpr uint8 UPGRADE_PLUS2_MAX_DEATHS = 5;   // 0-5 deaths = +2 levels
    constexpr uint8 UPGRADE_PLUS1_MAX_DEATHS = 10;  // 6-10 deaths = +1 level
    constexpr uint8 UPGRADE_SAME_MAX_DEATHS  = 14;  // 11-14 deaths = same level
    // 15+ deaths = keystone destroyed (no upgrade)

    // ========================================================================
    // VAULT CONFIGURATION
    // ========================================================================
    constexpr uint8 VAULT_SLOT1_REQUIRED_DUNGEONS = 1;  // Complete 1 M+ dungeon
    constexpr uint8 VAULT_SLOT2_REQUIRED_DUNGEONS = 4;  // Complete 4 M+ dungeons
    constexpr uint8 VAULT_SLOT3_REQUIRED_DUNGEONS = 8;  // Complete 8 M+ dungeons (all seasonal)

    // ========================================================================
    // SEASON CONFIGURATION
    // ========================================================================
    constexpr uint8 SEASON_DUNGEON_POOL_SIZE = 8;   // 8 dungeons per season
    constexpr uint8 AFFIX_ROTATION_WEEKS     = 12;  // 12-week affix rotation

    // ========================================================================
    // DATABASE TABLE NAMES (dc_ prefix = DarkChaos)
    // ========================================================================
    namespace Tables
    {
        // Character Database Tables
        constexpr const char* PLAYER_RATING           = "dc_mythic_player_rating";
        constexpr const char* KEYSTONES               = "dc_mythic_keystones";
        constexpr const char* RUN_HISTORY             = "dc_mythic_run_history";
        constexpr const char* VAULT_PROGRESS          = "dc_mythic_vault_progress";
        constexpr const char* ACHIEVEMENT_PROGRESS    = "dc_mythic_achievement_progress";
        
        // World Database Tables
        constexpr const char* SEASONS                 = "dc_mythic_seasons";
        constexpr const char* DUNGEONS_CONFIG         = "dc_mythic_dungeons_config";
        constexpr const char* RAID_CONFIG             = "dc_mythic_raid_config";
        constexpr const char* AFFIXES                 = "dc_mythic_affixes";
        constexpr const char* AFFIX_ROTATION          = "dc_mythic_affix_rotation";
        constexpr const char* VAULT_REWARDS           = "dc_mythic_vault_rewards";
        constexpr const char* TOKENS_LOOT             = "dc_mythic_tokens_loot";
        constexpr const char* ACHIEVEMENT_DEFS        = "dc_mythic_achievement_defs";
    }

    // ========================================================================
    // CONFIGURATION KEYS (from darkchaos-custom.conf.dist)
    // ========================================================================
    namespace ConfigKeys
    {
        constexpr const char* ENABLED                 = "DungeonEnhancement.Enabled";
        constexpr const char* AFFIX_MODE              = "MythicPlus.Affix.Mode";
        constexpr const char* DEATH_MAXIMUM           = "MythicPlus.Death.Maximum";
        constexpr const char* DEATH_TOKEN_PENALTY     = "MythicPlus.Death.TokenPenalty";
        constexpr const char* KEYSTONE_START_LEVEL    = "MythicPlus.Keystone.StartLevel";
        constexpr const char* KEYSTONE_MAX_LEVEL      = "MythicPlus.Keystone.MaxLevel";
        constexpr const char* VAULT_ENABLED           = "MythicPlus.Vault.Enabled";
    }

    // ========================================================================
    // LOGGING CATEGORIES
    // ========================================================================
    namespace LogCategory
    {
        constexpr const char* GENERAL      = "dungeon_enhancement";
        constexpr const char* MYTHIC_PLUS  = "mythic_plus";
        constexpr const char* AFFIXES      = "mythic_affixes";
        constexpr const char* VAULT        = "mythic_vault";
        constexpr const char* ACHIEVEMENTS = "mythic_achievements";
    }

    // ========================================================================
    // COLOR CODES (for player messages)
    // ========================================================================
    namespace Colors
    {
        constexpr const char* GREEN      = "|cff00ff00";  // Success messages
        constexpr const char* RED        = "|cffff0000";  // Error/failure messages
        constexpr const char* ORANGE     = "|cffff9900";  // Warning messages
        constexpr const char* YELLOW     = "|cffffff00";  // Info messages
        constexpr const char* BLUE       = "|cff0080ff";  // Mythic+ tier color
        constexpr const char* PURPLE     = "|cffa335ee";  // Epic/special items
        constexpr const char* END        = "|r";          // End color tag
    }

} // namespace DungeonEnhancement

#endif // DUNGEON_ENHANCEMENT_CONSTANTS_H
