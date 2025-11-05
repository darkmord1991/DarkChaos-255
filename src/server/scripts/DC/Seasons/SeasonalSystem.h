/*
 * Independent Seasonal System Architecture - DarkChaos
 *
 * This header defines a generic, independent seasonal system that can be used
 * by multiple game systems (Item Upgrades, HLBG, M+, Mythic, etc.).
 *
 * Key Features:
 * - Centralized season management
 * - System-agnostic seasonal data storage
 * - Event-driven season transitions
 * - Configurable season types and behaviors
 * - Extensible reward system
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#pragma once

#include "Define.h"
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>

namespace DarkChaos
{
    namespace Seasonal
    {
        // =====================================================================
        // Enums and Constants
        // =====================================================================

        enum SeasonType : uint8
        {
            SEASON_TYPE_TIME_BASED = 1,      // Fixed duration seasons
            SEASON_TYPE_EVENT_BASED = 2,     // Event-triggered seasons
            SEASON_TYPE_INFINITE = 3,        // No end date (legacy seasons)
            SEASON_TYPE_MANUAL = 4           // Admin-controlled seasons
        };

        enum SeasonState : uint8
        {
            SEASON_STATE_INACTIVE = 0,       // Season not active
            SEASON_STATE_ACTIVE = 1,         // Season currently running
            SEASON_STATE_TRANSITIONING = 2,  // Between seasons
            SEASON_STATE_MAINTENANCE = 3     // Season in maintenance
        };

        enum SeasonEventType : uint8
        {
            SEASON_EVENT_START = 1,          // Season begins
            SEASON_EVENT_END = 2,            // Season ends
            SEASON_EVENT_RESET = 3,          // Season data reset
            SEASON_EVENT_MAINTENANCE = 4     // Maintenance period
        };

        // =====================================================================
        // Core Season Definition
        // =====================================================================

        struct SeasonDefinition
        {
            uint32 season_id;
            std::string season_name;
            std::string season_description;
            SeasonType season_type;
            SeasonState season_state;

            // Timing
            time_t start_timestamp;
            time_t end_timestamp;
            time_t created_timestamp;

            // Configuration
            bool allow_carryover;
            float carryover_percentage;
            bool reset_on_end;
            std::string reset_behavior;

            // Metadata
            std::string theme_name;
            std::string banner_path;
            std::map<std::string, std::string> custom_properties;

            SeasonDefinition() : season_id(0), season_type(SEASON_TYPE_TIME_BASED),
                               season_state(SEASON_STATE_INACTIVE), start_timestamp(0),
                               end_timestamp(0), created_timestamp(0), allow_carryover(false),
                               carryover_percentage(0.0f), reset_on_end(true) {}
        };

        // =====================================================================
        // System Registration Interface
        // =====================================================================

        struct SystemRegistration
        {
            std::string system_name;              // "item_upgrades", "hlbg", "mythic_plus", etc.
            std::string system_version;           // Version for compatibility checking
            uint32 priority;                      // Execution priority (higher = executed first)

            // Event callbacks
            std::function<void(uint32 /*season_id*/, SeasonEventType /*event*/)> on_season_event;
            std::function<void(uint32 /*player_guid*/, uint32 /*old_season*/, uint32 /*new_season*/)> on_player_season_change;
            std::function<bool(uint32 /*player_guid*/, uint32 /*season_id*/)> validate_season_transition;

            // Data management
            std::function<void(uint32 /*player_guid*/, uint32 /*season_id*/)> archive_player_data;
            std::function<void(uint32 /*player_guid*/, uint32 /*season_id*/)> initialize_player_data;
            std::function<void(uint32 /*season_id*/)> cleanup_season_data;

            SystemRegistration() : priority(100) {}
        };

        // =====================================================================
        // Player Season Data
        // =====================================================================

        struct PlayerSeasonData
        {
            uint32 player_guid;
            uint32 current_season_id;
            time_t joined_season_at;
            time_t last_activity_at;

            // System-specific data (stored as JSON/key-value pairs)
            std::map<std::string, std::string> system_data;

            // Statistics
            uint32 total_seasons_played;
            uint32 seasons_completed;
            time_t first_season_joined;

            PlayerSeasonData() : player_guid(0), current_season_id(0), joined_season_at(0),
                               last_activity_at(0), total_seasons_played(0), seasons_completed(0),
                               first_season_joined(0) {}
        };

        // =====================================================================
        // Seasonal Manager Interface
        // =====================================================================

        class SeasonalManager
        {
        public:
            virtual ~SeasonalManager() = default;

            // Season Management
            virtual bool CreateSeason(const SeasonDefinition& season) = 0;
            virtual bool UpdateSeason(uint32 season_id, const SeasonDefinition& season) = 0;
            virtual bool DeleteSeason(uint32 season_id) = 0;
            virtual SeasonDefinition* GetSeason(uint32 season_id) = 0;
            virtual SeasonDefinition* GetActiveSeason() = 0;
            virtual std::vector<SeasonDefinition*> GetAllSeasons() = 0;

            // Season Control
            virtual bool StartSeason(uint32 season_id) = 0;
            virtual bool EndSeason(uint32 season_id) = 0;
            virtual bool TransitionSeason(uint32 from_season_id, uint32 to_season_id) = 0;

            // System Registration
            virtual bool RegisterSystem(const SystemRegistration& system) = 0;
            virtual bool UnregisterSystem(const std::string& system_name) = 0;
            virtual std::vector<SystemRegistration> GetRegisteredSystems() = 0;

            // Player Management
            virtual PlayerSeasonData* GetPlayerSeasonData(uint32 player_guid) = 0;
            virtual bool UpdatePlayerSeasonData(uint32 player_guid, const PlayerSeasonData& data) = 0;
            virtual bool TransitionPlayerSeason(uint32 player_guid, uint32 new_season_id) = 0;

            // Event System
            virtual void FireSeasonEvent(uint32 season_id, SeasonEventType event_type) = 0;
            virtual void ProcessSeasonTransitions() = 0;

            // Utility
            virtual uint32 GetCurrentSeasonId() = 0;
            virtual bool IsSeasonActive(uint32 season_id) = 0;
            virtual time_t GetSeasonTimeRemaining(uint32 season_id) = 0;
        };

        // =====================================================================
        // System-Specific Interfaces
        // =====================================================================

        // Generic seasonal participant interface
        class SeasonalParticipant
        {
        public:
            virtual ~SeasonalParticipant() = default;

            virtual std::string GetSystemName() const = 0;
            virtual uint32 GetSystemVersion() const = 0;
            virtual void OnSeasonStart(uint32 season_id) = 0;
            virtual void OnSeasonEnd(uint32 season_id) = 0;
            virtual void OnPlayerSeasonChange(uint32 player_guid, uint32 old_season, uint32 new_season) = 0;
            virtual bool ValidateSeasonTransition(uint32 player_guid, uint32 season_id) = 0;
        };

        // =====================================================================
        // Singleton Accessor
        // =====================================================================

        SeasonalManager* GetSeasonalManager();

        // =====================================================================
        // Helper Functions
        // =====================================================================

        // System registration helpers
        bool RegisterItemUpgradeSystem();
        bool RegisterHLBGSystem();
        bool RegisterMythicPlusSystem();

        // Season utilities
        std::string FormatSeasonTimeRemaining(time_t seconds);
        std::string GetSeasonStatusText(uint32 season_id);
        bool IsValidSeasonTransition(uint32 from_season, uint32 to_season);

    } // namespace Seasonal
} // namespace DarkChaos

/*
 * IMPLEMENTATION NOTES:
 *
 * 1. Database Schema:
 *    - dc_seasons: Core season definitions
 *    - dc_player_season_data: Player season participation
 *    - dc_season_system_data: System-specific season data
 *    - dc_season_events: Event logging and history
 *
 * 2. System Integration Pattern:
 *    - Each system implements SeasonalParticipant interface
 *    - Registers with SeasonalManager during initialization
 *    - Receives callbacks for season events
 *    - Manages its own data within the seasonal framework
 *
 * 3. Data Isolation:
 *    - Each system stores its data in dc_season_system_data with system_name key
 *    - Data format is system-specific (JSON recommended)
 *    - SeasonalManager provides generic storage/retrieval
 *
 * 4. Event Flow:
 *    - SeasonalManager detects season transitions
 *    - Fires events to all registered systems
 *    - Systems handle their specific logic (resets, carryover, etc.)
 *    - Player data updated atomically
 *
 * 5. Example Usage for HLBG:
 *    class HLBGSeasonalParticipant : public SeasonalParticipant {
 *        void OnSeasonStart(uint32 season_id) override {
 *            // Reset HLBG resources, clear scores, etc.
 *        }
 *        void OnSeasonEnd(uint32 season_id) override {
 *            // Calculate final rankings, distribute rewards
 *        }
 *    };
 */