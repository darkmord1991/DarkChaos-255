/*
 * Independent Seasonal System Implementation - DarkChaos
 *
 * Core implementation of the generic seasonal system that can be used
 * by multiple game systems (Item Upgrades, HLBG, M+, Mythic, etc.).
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "SeasonalSystem.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "World.h"
#include <sstream>
#include <algorithm>

namespace DarkChaos
{
    namespace Seasonal
    {
        // =====================================================================
        // Seasonal Manager Implementation
        // =====================================================================

        class SeasonalManagerImpl : public SeasonalManager
        {
        private:
            std::map<uint32, SeasonDefinition> seasons_;
            std::map<uint32, PlayerSeasonData> player_data_;
            std::map<std::string, SystemRegistration> registered_systems_;
            uint32 active_season_id_;

        public:
            SeasonalManagerImpl() : active_season_id_(0)
            {
                LoadSeasons();
                LoadActiveSeason();
            }

            virtual ~SeasonalManagerImpl() = default;

            // =================================================================
            // Season Management
            // =================================================================

            bool CreateSeason(const SeasonDefinition& season) override
            {
                if (seasons_.find(season.season_id) != seasons_.end())
                    return false; // Season already exists

                std::string safeName = season.season_name;
                std::string safeDesc = season.season_description;
                std::string safeTheme = season.theme_name;
                std::string safeBanner = season.banner_path;
                CharacterDatabase.EscapeString(safeName);
                CharacterDatabase.EscapeString(safeDesc);
                CharacterDatabase.EscapeString(safeTheme);
                CharacterDatabase.EscapeString(safeBanner);

                // Insert into database
                std::ostringstream oss;
                oss << "INSERT INTO dc_seasons (season_id, season_name, season_description, season_type, "
                    << "start_timestamp, end_timestamp, allow_carryover, carryover_percentage, reset_on_end, "
                    << "theme_name, banner_path) VALUES ("
                    << season.season_id << ", '" << safeName << "', '" << safeDesc << "', "
                    << (int)season.season_type << ", " << season.start_timestamp << ", " << season.end_timestamp << ", "
                    << (season.allow_carryover ? 1 : 0) << ", " << season.carryover_percentage << ", "
                    << (season.reset_on_end ? 1 : 0) << ", '" << safeTheme << "', '" << safeBanner << "')";

                CharacterDatabase.Execute(oss.str().c_str());

                seasons_[season.season_id] = season;
                LOG_INFO("seasonal", "Created season {}: {}", season.season_id, season.season_name);
                return true;
            }

            bool UpdateSeason(uint32 season_id, const SeasonDefinition& season) override
            {
                auto it = seasons_.find(season_id);
                if (it == seasons_.end())
                    return false;

                std::string safeName = season.season_name;
                std::string safeDesc = season.season_description;
                std::string safeTheme = season.theme_name;
                std::string safeBanner = season.banner_path;
                CharacterDatabase.EscapeString(safeName);
                CharacterDatabase.EscapeString(safeDesc);
                CharacterDatabase.EscapeString(safeTheme);
                CharacterDatabase.EscapeString(safeBanner);

                // Update database
                std::ostringstream oss;
                oss << "UPDATE dc_seasons SET season_name = '" << safeName << "', "
                    << "season_description = '" << safeDesc << "', "
                    << "season_type = " << (int)season.season_type << ", "
                    << "start_timestamp = " << season.start_timestamp << ", "
                    << "end_timestamp = " << season.end_timestamp << ", "
                    << "allow_carryover = " << (season.allow_carryover ? 1 : 0) << ", "
                    << "carryover_percentage = " << season.carryover_percentage << ", "
                    << "reset_on_end = " << (season.reset_on_end ? 1 : 0) << ", "
                    << "theme_name = '" << safeTheme << "', "
                    << "banner_path = '" << safeBanner << "' "
                    << "WHERE season_id = " << season_id;

                CharacterDatabase.Execute(oss.str().c_str());

                seasons_[season_id] = season;
                LOG_INFO("seasonal", "Updated season {}", season_id);
                return true;
            }

            bool DeleteSeason(uint32 season_id) override
            {
                auto it = seasons_.find(season_id);
                if (it == seasons_.end())
                    return false;

                // Delete from database
                std::ostringstream oss;
                oss << "DELETE FROM dc_seasons WHERE season_id = " << season_id;

                CharacterDatabase.Execute(oss.str().c_str());

                seasons_.erase(it);
                LOG_INFO("seasonal", "Deleted season {}", season_id);
                return true;
            }

            SeasonDefinition* GetSeason(uint32 season_id) override
            {
                auto it = seasons_.find(season_id);
                return (it != seasons_.end()) ? &it->second : nullptr;
            }

            SeasonDefinition* GetActiveSeason() override
            {
                return GetSeason(active_season_id_);
            }

            std::vector<SeasonDefinition*> GetAllSeasons() override
            {
                std::vector<SeasonDefinition*> result;
                for (auto& pair : seasons_)
                    result.push_back(&pair.second);
                return result;
            }

            // =================================================================
            // Season Control
            // =================================================================

            bool StartSeason(uint32 season_id) override
            {
                auto season = GetSeason(season_id);
                if (!season)
                    return false;

                // Update database
                std::ostringstream oss;
                oss << "UPDATE dc_seasons SET season_state = " << (int)SEASON_STATE_ACTIVE
                    << " WHERE season_id = " << season_id;

                CharacterDatabase.Execute(oss.str().c_str());

                season->season_state = SEASON_STATE_ACTIVE;
                active_season_id_ = season_id;

                // Fire season start event
                FireSeasonEvent(season_id, SEASON_EVENT_START);

                LOG_INFO("seasonal", "Started season {}", season_id);
                return true;
            }

            bool EndSeason(uint32 season_id) override
            {
                auto season = GetSeason(season_id);
                if (!season)
                    return false;

                // Update database
                std::ostringstream oss;
                oss << "UPDATE dc_seasons SET season_state = " << (int)SEASON_STATE_INACTIVE
                    << " WHERE season_id = " << season_id;

                CharacterDatabase.Execute(oss.str().c_str());

                season->season_state = SEASON_STATE_INACTIVE;

                // Fire season end event
                FireSeasonEvent(season_id, SEASON_EVENT_END);

                LOG_INFO("seasonal", "Ended season {}", season_id);
                return true;
            }

            bool TransitionSeason(uint32 from_season_id, uint32 to_season_id) override
            {
                auto from_season = GetSeason(from_season_id);
                auto to_season = GetSeason(to_season_id);

                if (!from_season || !to_season)
                {
                    LOG_ERROR("seasonal", "TransitionSeason: Invalid season IDs (from={}, to={})",
                             from_season_id, to_season_id);
                    return false;
                }

                // Use SQLTransaction for atomicity - both operations succeed or both fail
                SQLTransaction trans = CharacterDatabase.BeginTransaction();

                try
                {
                    // End the old season
                    trans->Append("UPDATE dc_seasons SET season_state = {} WHERE season_id = {}",
                                 (int)SEASON_STATE_INACTIVE, from_season_id);

                    // Start the new season
                    trans->Append("UPDATE dc_seasons SET season_state = {} WHERE season_id = {}",
                                 (int)SEASON_STATE_ACTIVE, to_season_id);

                    // Commit the transaction - both updates happen atomically
                    CharacterDatabase.CommitTransaction(trans);
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("seasonal", "TransitionSeason: Transaction failed: {}", e.what());
                    // Transaction automatically rolls back on exception
                    return false;
                }

                // Update in-memory state only after successful DB commit
                from_season->season_state = SEASON_STATE_INACTIVE;
                to_season->season_state = SEASON_STATE_ACTIVE;
                active_season_id_ = to_season_id;

                // Fire events after successful transition
                FireSeasonEvent(from_season_id, SEASON_EVENT_END);
                FireSeasonEvent(to_season_id, SEASON_EVENT_START);

                LOG_INFO("seasonal", "Atomically transitioned from season {} to {}", from_season_id, to_season_id);
                return true;
            }

            // =================================================================
            // System Registration
            // =================================================================

            bool RegisterSystem(const SystemRegistration& system) override
            {
                if (registered_systems_.find(system.system_name) != registered_systems_.end())
                    return false; // Already registered

                registered_systems_[system.system_name] = system;
                LOG_INFO("seasonal", "Registered seasonal system: {}", system.system_name);
                return true;
            }

            bool UnregisterSystem(const std::string& system_name) override
            {
                auto it = registered_systems_.find(system_name);
                if (it == registered_systems_.end())
                    return false;

                registered_systems_.erase(it);
                LOG_INFO("seasonal", "Unregistered seasonal system: {}", system_name);
                return true;
            }

            std::vector<SystemRegistration> GetRegisteredSystems() override
            {
                std::vector<SystemRegistration> result;
                for (auto& pair : registered_systems_)
                    result.push_back(pair.second);
                return result;
            }

            // =================================================================
            // Player Management
            // =================================================================

            PlayerSeasonData* GetPlayerSeasonData(uint32 player_guid) override
            {
                // Check cache first
                auto it = player_data_.find(player_guid);
                if (it != player_data_.end())
                    return &it->second;

                // Load from database
                QueryResult result = CharacterDatabase.Query(
                    "SELECT current_season_id, joined_season_at, last_activity_at, "
                    "total_seasons_played, seasons_completed, first_season_joined "
                    "FROM dc_player_season_data WHERE player_guid = {}", player_guid);

                if (!result)
                    return nullptr;

                Field* fields = result->Fetch();
                PlayerSeasonData data;
                data.player_guid = player_guid;
                data.current_season_id = fields[0].Get<uint32>();
                data.joined_season_at = fields[1].Get<time_t>();
                data.last_activity_at = fields[2].Get<time_t>();
                data.total_seasons_played = fields[3].Get<uint32>();
                data.seasons_completed = fields[4].Get<uint32>();
                data.first_season_joined = fields[5].Get<time_t>();

                player_data_[player_guid] = data;
                return &player_data_[player_guid];
            }

            bool UpdatePlayerSeasonData(uint32 player_guid, const PlayerSeasonData& data) override
            {
                std::ostringstream oss;
                oss << "INSERT INTO dc_player_season_data (player_guid, current_season_id, "
                    << "joined_season_at, last_activity_at, total_seasons_played, seasons_completed, first_season_joined) "
                    << "VALUES (" << data.player_guid << ", " << data.current_season_id << ", "
                    << data.joined_season_at << ", " << data.last_activity_at << ", "
                    << data.total_seasons_played << ", " << data.seasons_completed << ", " << data.first_season_joined << ") "
                    << "ON DUPLICATE KEY UPDATE "
                    << "current_season_id = " << data.current_season_id << ", "
                    << "joined_season_at = " << data.joined_season_at << ", "
                    << "last_activity_at = " << data.last_activity_at << ", "
                    << "total_seasons_played = " << data.total_seasons_played << ", "
                    << "seasons_completed = " << data.seasons_completed;

                CharacterDatabase.Execute(oss.str().c_str());

                player_data_[player_guid] = data;
                return true;
            }

            bool TransitionPlayerSeason(uint32 player_guid, uint32 new_season_id) override
            {
                auto old_data = GetPlayerSeasonData(player_guid);
                uint32 old_season = old_data ? old_data->current_season_id : 0;

                // Validate transition with all registered systems
                for (auto& pair : registered_systems_)
                {
                    if (pair.second.validate_season_transition &&
                        !pair.second.validate_season_transition(player_guid, new_season_id))
                    {
                        LOG_WARN("seasonal", "System {} rejected season transition for player {}",
                                pair.first, player_guid);
                        return false;
                    }
                }

                // Archive old season data
                for (auto& pair : registered_systems_)
                {
                    if (pair.second.archive_player_data)
                        pair.second.archive_player_data(player_guid, old_season);
                }

                // Update player data
                PlayerSeasonData new_data;
                if (old_data)
                    new_data = *old_data;
                else
                    new_data.player_guid = player_guid;

                new_data.current_season_id = new_season_id;
                new_data.joined_season_at = time(nullptr);
                new_data.last_activity_at = time(nullptr);
                new_data.total_seasons_played++;

                if (new_data.first_season_joined == 0)
                    new_data.first_season_joined = new_data.joined_season_at;

                if (!UpdatePlayerSeasonData(player_guid, new_data))
                    return false;

                // Initialize new season data
                for (auto& pair : registered_systems_)
                {
                    if (pair.second.initialize_player_data)
                        pair.second.initialize_player_data(player_guid, new_season_id);
                }

                // Notify systems of the change
                for (auto& pair : registered_systems_)
                {
                    if (pair.second.on_player_season_change)
                        pair.second.on_player_season_change(player_guid, old_season, new_season_id);
                }

                LOG_INFO("seasonal", "Transitioned player {} from season {} to {}",
                        player_guid, old_season, new_season_id);
                return true;
            }

            // =================================================================
            // Event System
            // =================================================================

            void FireSeasonEvent(uint32 season_id, SeasonEventType event_type) override
            {
                LOG_INFO("seasonal", "Firing season event: season={}, type={}", season_id, (int)event_type);

                // Sort systems by priority (higher priority first)
                std::vector<SystemRegistration> sorted_systems;
                for (auto& pair : registered_systems_)
                    sorted_systems.push_back(pair.second);

                std::sort(sorted_systems.begin(), sorted_systems.end(),
                         [](const SystemRegistration& a, const SystemRegistration& b) {
                             return a.priority > b.priority;
                         });

                // Fire event to each system
                for (auto& system : sorted_systems)
                {
                    if (system.on_season_event)
                    {
                        try
                        {
                            system.on_season_event(season_id, event_type);
                        }
                        catch (const std::exception& e)
                        {
                            LOG_ERROR("seasonal", "Exception in system {} during season event: {}",
                                     system.system_name, e.what());
                        }
                    }
                }
            }

            void ProcessSeasonTransitions() override
            {
                time_t now = time(nullptr);

                for (auto& pair : seasons_)
                {
                    SeasonDefinition& season = pair.second;

                    // Check for season start
                    if (season.season_state == SEASON_STATE_INACTIVE &&
                        season.start_timestamp <= now && season.start_timestamp > 0)
                    {
                        StartSeason(season.season_id);
                    }

                    // Check for season end
                    if (season.season_state == SEASON_STATE_ACTIVE &&
                        season.end_timestamp <= now && season.end_timestamp > 0)
                    {
                        EndSeason(season.season_id);
                    }
                }
            }

            // =================================================================
            // Utility
            // =================================================================

            uint32 GetCurrentSeasonId() override
            {
                return active_season_id_;
            }

            bool IsSeasonActive(uint32 season_id) override
            {
                auto season = GetSeason(season_id);
                return season && season->season_state == SEASON_STATE_ACTIVE;
            }

            time_t GetSeasonTimeRemaining(uint32 season_id) override
            {
                auto season = GetSeason(season_id);
                if (!season || season->end_timestamp == 0)
                    return 0;

                time_t now = time(nullptr);
                return (season->end_timestamp > now) ? (season->end_timestamp - now) : 0;
            }

            // =================================================================
            // Cache Management
            // =================================================================

            void InvalidatePlayerData(uint32 player_guid)
            {
                auto it = player_data_.find(player_guid);
                if (it != player_data_.end())
                {
                    player_data_.erase(it);
                    LOG_DEBUG("seasonal", "Cleaned up cached season data for player {}", player_guid);
                }
            }

            size_t GetPlayerCacheSize() const { return player_data_.size(); }

        private:
            void LoadSeasons()
            {
                QueryResult result = CharacterDatabase.Query(
                    "SELECT season_id, season_name, season_description, season_type, season_state, "
                    "start_timestamp, end_timestamp, created_timestamp, allow_carryover, "
                    "carryover_percentage, reset_on_end, theme_name, banner_path "
                    "FROM dc_seasons ORDER BY season_id");

                if (!result)
                    return;

                do
                {
                    Field* fields = result->Fetch();
                    SeasonDefinition season;

                    season.season_id = fields[0].Get<uint32>();
                    season.season_name = fields[1].Get<std::string>();
                    season.season_description = fields[2].Get<std::string>();
                    season.season_type = (SeasonType)fields[3].Get<uint8>();
                    season.season_state = (SeasonState)fields[4].Get<uint8>();
                    season.start_timestamp = fields[5].Get<time_t>();
                    season.end_timestamp = fields[6].Get<time_t>();
                    season.created_timestamp = fields[7].Get<time_t>();
                    season.allow_carryover = fields[8].Get<bool>();
                    season.carryover_percentage = fields[9].Get<float>();
                    season.reset_on_end = fields[10].Get<bool>();
                    season.theme_name = fields[11].Get<std::string>();
                    season.banner_path = fields[12].Get<std::string>();

                    seasons_[season.season_id] = season;
                } while (result->NextRow());

                LOG_INFO("seasonal", "Loaded {} seasons", seasons_.size());
            }

            void LoadActiveSeason()
            {
                QueryResult result = CharacterDatabase.Query(
                    "SELECT season_id FROM dc_seasons WHERE season_state = {} ORDER BY season_id DESC LIMIT 1",
                    (int)SEASON_STATE_ACTIVE);

                if (result)
                    active_season_id_ = result->Fetch()[0].Get<uint32>();
            }
        };

        // =====================================================================
        // Singleton Implementation
        // =====================================================================

        static SeasonalManagerImpl* _seasonal_manager = nullptr;

        SeasonalManager* GetSeasonalManager()
        {
            if (!_seasonal_manager)
                _seasonal_manager = new SeasonalManagerImpl();

            return _seasonal_manager;
        }

        // =====================================================================
        // System Registration Helpers
        // =====================================================================

        // =====================================================================
        // System Registration Helpers - DEPRECATED
        // Systems should now register themselves via GetSeasonalManager()->RegisterSystem()
        // =====================================================================

        // Legacy helpers removed to enforce self-registration pattern


        // =====================================================================
        // Utility Functions
        // =====================================================================

        std::string FormatSeasonTimeRemaining(time_t seconds)
        {
            if (seconds <= 0)
                return "Ended";

            uint32 days = seconds / 86400;
            uint32 hours = (seconds % 86400) / 3600;
            uint32 minutes = (seconds % 3600) / 60;

            std::ostringstream oss;
            if (days > 0)
                oss << days << "d ";
            if (hours > 0 || days > 0)
                oss << hours << "h ";
            oss << minutes << "m";

            return oss.str();
        }

        std::string GetSeasonStatusText(uint32 season_id)
        {
            auto manager = GetSeasonalManager();
            auto season = manager->GetSeason(season_id);

            if (!season)
                return "Unknown";

            switch (season->season_state)
            {
                case SEASON_STATE_ACTIVE: return "Active";
                case SEASON_STATE_INACTIVE: return "Inactive";
                case SEASON_STATE_TRANSITIONING: return "Transitioning";
                case SEASON_STATE_MAINTENANCE: return "Maintenance";
                default: return "Unknown";
            }
        }

        bool IsValidSeasonTransition(uint32 /*from_season*/, uint32 /*to_season*/)
        {
            // TODO: Implement season transition validation logic
            return true;
        }

    } // namespace Seasonal
} // namespace DarkChaos
