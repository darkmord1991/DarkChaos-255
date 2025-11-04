/*
 * DarkChaos Item Upgrade System - C++ Interface
 * 
 * This header defines the core upgrade system interface for the item upgrade mechanics.
 * Supports 5-tier heirloom progression with 2-token economy (Upgrade Tokens + Artifact Essence).
 * 
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#pragma once

#include "Define.h"
#include <map>
#include <memory>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Constants
        // =====================================================================
        
        enum UpgradeTier : uint8
        {
            TIER_LEVELING = 1,      // T1: Quests, 1-60
            TIER_HEROIC = 2,        // T2: Heroic Dungeons
            TIER_RAID = 3,          // T3: Heroic Raid + Mythic Dungeons
            TIER_MYTHIC = 4,        // T4: Mythic Raid + Mythic+
            TIER_ARTIFACT = 5,      // T5: Chaos Artifacts
            TIER_INVALID = 0
        };

        enum CurrencyType : uint8
        {
            CURRENCY_UPGRADE_TOKEN = 1,    // Used for T1-T4
            CURRENCY_ARTIFACT_ESSENCE = 2  // Used for T5 only
        };

        // Constants
        static const uint8 MAX_UPGRADE_LEVEL = 5;
        static const uint8 MIN_UPGRADE_LEVEL = 0;
        static const uint8 NUM_TIERS = 5;
        static const float STAT_MULTIPLIER_BASE = 1.0f;
        static const float STAT_MULTIPLIER_MAX_REGULAR = 1.5f;
        static const float STAT_MULTIPLIER_MAX_ARTIFACT = 1.75f;

        // =====================================================================
        // Upgrade Cost Structure
        // =====================================================================
        
        struct UpgradeCost
        {
            uint8 tier_id;
            uint8 upgrade_level;
            uint32 token_cost;              // Upgrade token cost
            uint32 essence_cost;            // Artifact essence cost (T5 only)
            uint16 ilvl_increase;           // iLvL increase for this upgrade
            float stat_increase_percent;    // Stat multiplier increase
            uint32 season;

            UpgradeCost() : tier_id(0), upgrade_level(0), token_cost(0), 
                           essence_cost(0), ilvl_increase(0), stat_increase_percent(0.0f), season(1) {}
        };

        // =====================================================================
        // Player Item Upgrade State
        // =====================================================================
        
        struct ItemUpgradeState
        {
            uint32 item_guid;                    // Item GUID from item_instance
            uint32 player_guid;                  // Player GUID
            uint8 upgrade_level;                 // Current upgrade level (0 = base, 1-15 = upgraded)
            uint32 essence_invested;             // Total essence invested
            uint32 tokens_invested;              // Total tokens invested
            uint16 base_item_level;              // Original item level
            uint16 upgraded_item_level;          // Current item level after upgrades
            float current_stat_multiplier;       // Current stat scaling multiplier
            uint32 last_upgraded_timestamp;      // When this item was last upgraded
            uint32 season_id;                    // Current season

            ItemUpgradeState() : item_guid(0), player_guid(0), upgrade_level(0),
                                 essence_invested(0), tokens_invested(0),
                                 base_item_level(0), upgraded_item_level(0),
                                 current_stat_multiplier(1.0f), last_upgraded_timestamp(0), season_id(1) {}

            bool IsMaxUpgraded() const { return upgrade_level >= MAX_UPGRADE_LEVEL; }
            bool CanUpgrade() const { return upgrade_level < MAX_UPGRADE_LEVEL; }
        };

        // =====================================================================
        // Chaos Artifact Definition
        // =====================================================================
        
        struct ChaosArtifact
        {
            uint32 artifact_id;             // Artifact ID
            std::string artifact_name;      // Display name
            uint32 item_id;                 // Item template ID
            uint8 cosmetic_variant;         // Cosmetic variant number
            uint8 rarity;                   // Item rarity (usually 4=epic)
            std::string location_name;      // Zone/location name
            std::string location_type;      // Zone/dungeon/raid/world
            uint32 essence_cost;            // Cost to upgrade to max
            bool is_active;                 // Is this artifact available
            uint32 season;                  // Season

            ChaosArtifact() : artifact_id(0), item_id(0), cosmetic_variant(0),
                                rarity(4), essence_cost(250), is_active(true), season(1) {}
        };

        // =====================================================================
        // Upgrade Manager Interface
        // =====================================================================
        
        class UpgradeManager
        {
        public:
            virtual ~UpgradeManager() = default;

            // Core upgrade functions
            virtual bool UpgradeItem(uint32 player_guid, uint32 item_guid) = 0;
            virtual bool AddCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season = 1) = 0;
            virtual bool RemoveCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season = 1) = 0;
            virtual uint32 GetCurrency(uint32 player_guid, CurrencyType currency, uint32 season = 1) = 0;
            
            // Item upgrade state functions
            virtual ItemUpgradeState* GetItemUpgradeState(uint32 item_guid) = 0;
            virtual bool SetItemUpgradeLevel(uint32 item_guid, uint8 level) = 0;
            virtual float GetStatMultiplier(uint32 item_guid) = 0;
            virtual uint16 GetUpgradedItemLevel(uint32 item_guid, uint16 base_ilvl) = 0;

            // Tier functions
            virtual uint8 GetItemTier(uint32 item_id) = 0;
            virtual uint32 GetUpgradeCost(uint8 tier_id, uint8 upgrade_level) = 0;
            virtual uint32 GetEssenceCost(uint8 tier_id, uint8 upgrade_level) = 0;

            // Artifact functions
            virtual ChaosArtifact* GetArtifact(uint32 artifact_id) = 0;
            virtual std::vector<ChaosArtifact*> GetArtifactsByLocation(const std::string& location) = 0;
            virtual bool DiscoverArtifact(uint32 player_guid, uint32 artifact_id) = 0;

            // Database functions
            virtual void LoadUpgradeData(uint32 season = 1) = 0;
            virtual void SaveItemUpgrade(uint32 item_guid) = 0;
            virtual void SavePlayerCurrency(uint32 player_guid, uint32 season = 1) = 0;
        };

        // =====================================================================
        // Singleton accessor
        // =====================================================================
        
        UpgradeManager* sUpgradeManager();

    } // namespace ItemUpgrade
} // namespace DarkChaos
