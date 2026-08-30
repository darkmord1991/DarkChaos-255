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
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "World.h"
#include <sstream>
#include <algorithm>
#include <ctime>

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
            bool _initialized;

        public:
            SeasonalManagerImpl() : active_season_id_(0), _initialized(false)
            {
                // Defer database queries until EnsureInitialized() is called
                // to avoid crash when database connection pool isn't ready yet
            }

            virtual ~SeasonalManagerImpl() = default;

            // =================================================================
            // Season Management
            // =================================================================

            bool CreateSeason(SeasonDefinition const& season) override
            {
                EnsureInitialized();
                if (seasons_.find(season.season_id) != seasons_.end())
                    return false; // Season already exists

                std::string safeName = season.season_name;
                std::string safeDesc = season.season_description;
                std::string safeTheme = season.theme_name;
                std::string safeBanner = season.banner_path;
                WorldDatabase.EscapeString(safeName);
                WorldDatabase.EscapeString(safeDesc);
                WorldDatabase.EscapeString(safeTheme);
                WorldDatabase.EscapeString(safeBanner);

                // Insert into database
                std::ostringstream oss;
                oss << "INSERT INTO dc_seasons (season_id, season_name, season_description, season_type, "
                    << "start_timestamp, end_timestamp, allow_carryover, carryover_percentage, reset_on_end, "
                    << "theme_name, banner_path) VALUES ("
                    << season.season_id << ", '" << safeName << "', '" << safeDesc << "', "
                    << (int)season.season_type << ", " << season.start_timestamp << ", " << season.end_timestamp << ", "
                    << (season.allow_carryover ? 1 : 0) << ", " << season.carryover_percentage << ", "
                    << (season.reset_on_end ? 1 : 0) << ", '" << safeTheme << "', '" << safeBanner << "')";

                WorldDatabase.Execute(oss.str().c_str());

                seasons_[season.season_id] = season;
                LOG_INFO("seasonal", "Created season {}: {}", season.season_id, season.season_name);
                return true;
            }

            bool UpdateSeason(uint32 season_id, SeasonDefinition const& season) override
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

                WorldDatabase.Execute(oss.str().c_str());

                seasons_[season_id] = season;
                LOG_INFO("seasonal", "Updated season {}", season_id);
                return true;
            }

            bool DeleteSeason(uint32 season_id) override
            {                EnsureInitialized();                auto it = seasons_.find(season_id);
                if (it == seasons_.end())
                    return false;

                // Delete from database
                std::ostringstream oss;
                oss << "DELETE FROM dc_seasons WHERE season_id = " << season_id;

                WorldDatabase.Execute(oss.str().c_str());

                seasons_.erase(it);
                LOG_INFO("seasonal", "Deleted season {}", season_id);
                return true;
            }

            SeasonDefinition* GetSeason(uint32 season_id) override
            {
                EnsureInitialized();
                auto it = seasons_.find(season_id);
                return (it != seasons_.end()) ? &it->second : nullptr;
            }

            SeasonDefinition* GetActiveSeason() override
            {
                EnsureInitialized();

                if (!active_season_id_)
                    return nullptr;

                auto it = seasons_.find(active_season_id_);
                return (it != seasons_.end()) ? &it->second : nullptr;
            }

            std::vector<SeasonDefinition*> GetAllSeasons() override
            {                const_cast<SeasonalManagerImpl*>(this)->EnsureInitialized();                std::vector<SeasonDefinition*> result;
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

                if (active_season_id_ == season_id && season->season_state == SEASON_STATE_ACTIVE)
                    return true;

                // Keep dc_seasons state in sync and ensure only one active season.
                SQLTransaction trans = WorldDatabase.BeginTransaction();

                try
                {
                    trans->Append("UPDATE dc_seasons SET season_state = {}, is_active = 0 "
                                "WHERE season_state = {} OR is_active = 1",
                                (int)SEASON_STATE_INACTIVE, (int)SEASON_STATE_ACTIVE);

                    trans->Append("UPDATE dc_seasons SET season_state = {}, is_active = 1 WHERE season_id = {}",
                                (int)SEASON_STATE_ACTIVE, season_id);

                    WorldDatabase.CommitTransaction(trans);
                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("seasonal", "StartSeason: Transaction failed: {}", e.what());
                    return false;
                }

                for (auto& pair : seasons_)
                    pair.second.season_state = (pair.first == season_id) ? SEASON_STATE_ACTIVE : SEASON_STATE_INACTIVE;

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

                std::ostringstream oss;
                oss << "UPDATE dc_seasons SET season_state = " << (int)SEASON_STATE_INACTIVE
                    << ", is_active = 0 WHERE season_id = " << season_id;

                WorldDatabase.Execute(oss.str().c_str());

                season->season_state = SEASON_STATE_INACTIVE;

                if (active_season_id_ == season_id)
                    active_season_id_ = 0;

                // Fire season end event
                FireSeasonEvent(season_id, SEASON_EVENT_END);

                LOG_INFO("seasonal", "Ended season {}", season_id);
                return true;
            }

            bool TransitionSeason(uint32 from_season_id, uint32 to_season_id) override
            {
                if (from_season_id == to_season_id)
                    return true;

                // TransitionSeason has always required BOTH seasons to exist -- the
                // caller falls back to a direct SetActiveSeason() when this returns
                // false. IsValidSeasonTransition() is deliberately more permissive
                // (it accepts from_season 0 as "no season running"), so the stricter
                // source check stays here rather than widening this entry point.
                if (!GetSeason(from_season_id) || !GetSeason(to_season_id))
                {
                    LOG_ERROR("seasonal", "TransitionSeason: Invalid season IDs (from={}, to={})",
                             from_season_id, to_season_id);
                    return false;
                }

                if (!IsValidSeasonTransition(from_season_id, to_season_id))
                {
                    LOG_ERROR("seasonal", "TransitionSeason: Rejected transition (from={}, to={})",
                             from_season_id, to_season_id);
                    return false;
                }

                // Use SQLTransaction for atomicity - both operations succeed or both fail.
                SQLTransaction trans = WorldDatabase.BeginTransaction();

                try
                {
                    // End the old season
                    trans->Append("UPDATE dc_seasons SET season_state = {}, is_active = 0 WHERE season_id = {}",
                                 (int)SEASON_STATE_INACTIVE, from_season_id);

                    // Clear stale active flags on every other season except the target.
                    trans->Append("UPDATE dc_seasons SET season_state = {}, is_active = 0 "
                                 "WHERE season_id <> {} AND (season_state = {} OR is_active = 1)",
                                 (int)SEASON_STATE_INACTIVE, to_season_id, (int)SEASON_STATE_ACTIVE);

                    // Start the new season
                    trans->Append("UPDATE dc_seasons SET season_state = {}, is_active = 1 WHERE season_id = {}",
                                 (int)SEASON_STATE_ACTIVE, to_season_id);

                    // Commit the transaction - both updates happen atomically
                    WorldDatabase.CommitTransaction(trans);
                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("seasonal", "TransitionSeason: Transaction failed: {}", e.what());
                    // Transaction automatically rolls back on exception
                    return false;
                }

                // Update in-memory state only after successful DB commit
                for (auto& pair : seasons_)
                    pair.second.season_state = (pair.first == to_season_id) ? SEASON_STATE_ACTIVE : SEASON_STATE_INACTIVE;

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

            bool RegisterSystem(SystemRegistration const& system) override
            {
                // Do NOT call EnsureInitialized() here - this is called during script registration
                // before the database is initialized
                if (registered_systems_.find(system.system_name) != registered_systems_.end())
                    return false; // Already registered

                registered_systems_[system.system_name] = system;
                LOG_INFO("seasonal", "Registered seasonal system: {}", system.system_name);
                return true;
            }

            bool UnregisterSystem(std::string const& system_name) override
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
                EnsureInitialized();
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

            bool UpdatePlayerSeasonData(uint32 player_guid, PlayerSeasonData const& data) override
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
                         [](SystemRegistration const& a, SystemRegistration const& b) {
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
                        catch (std::exception const& e)
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
            {                const_cast<SeasonalManagerImpl*>(this)->EnsureInitialized();                return active_season_id_;
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

            void InvalidatePlayerData(uint32 player_guid) override
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
            void EnsureInitialized()
            {
                if (!_initialized)
                {
                    LoadSeasons();
                    LoadActiveSeason();
                    _initialized = true;
                }
            }

            void LoadSeasons()
            {
                QueryResult result = WorldDatabase.Query(
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
                active_season_id_ = 0;

                QueryResult result = WorldDatabase.Query(
                    "SELECT season_id FROM dc_seasons WHERE season_state = {} ORDER BY season_id DESC LIMIT 1",
                    (int)SEASON_STATE_ACTIVE);

                if (!result)
                {
                    result = WorldDatabase.Query(
                        "SELECT season_id FROM dc_seasons WHERE is_active = 1 ORDER BY season_id DESC LIMIT 1");
                }

                if (result)
                {
                    active_season_id_ = result->Fetch()[0].Get<uint32>();
                    return;
                }

                uint32 configuredSeason = sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 0);
                if (configuredSeason > 0 && seasons_.find(configuredSeason) != seasons_.end())
                {
                    active_season_id_ = configuredSeason;
                    LOG_INFO("seasonal", "No active season row found, using DarkChaos.ActiveSeasonID={}", active_season_id_);
                    return;
                }

                if (!seasons_.empty())
                {
                    active_season_id_ = seasons_.rbegin()->first;
                    LOG_WARN("seasonal", "No active season found in DB/config, falling back to latest season {}", active_season_id_);
                    return;
                }

                LOG_WARN("seasonal", "No seasons loaded; active season remains unset");
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

        bool IsValidSeasonTransition(uint32 from_season, uint32 to_season)
        {
            // Moving a season onto itself is a no-op, which TransitionSeason already
            // treats as success -- report it as valid so both agree.
            if (from_season == to_season)
                return true;

            auto manager = GetSeasonalManager();

            SeasonDefinition* from = from_season ? manager->GetSeason(from_season) : nullptr;
            SeasonDefinition* to = manager->GetSeason(to_season);

            // The target must exist; the source may legitimately be 0 (first season
            // ever started, or a realm coming up with no active season).
            if (!to)
            {
                LOG_ERROR("seasonal", "IsValidSeasonTransition: target season {} does not exist", to_season);
                return false;
            }

            if (from_season && !from)
            {
                LOG_ERROR("seasonal", "IsValidSeasonTransition: source season {} does not exist", from_season);
                return false;
            }

            // A season under maintenance is deliberately withheld from players.
            if (to->season_state == SEASON_STATE_MAINTENANCE)
            {
                LOG_ERROR("seasonal", "IsValidSeasonTransition: target season {} is in maintenance", to_season);
                return false;
            }

            // Starting a season that has already elapsed would activate a season whose
            // rewards and resets are already past due.
            time_t const now = time(nullptr);
            if (to->end_timestamp > 0 && to->end_timestamp <= now)
            {
                LOG_ERROR("seasonal", "IsValidSeasonTransition: target season {} ended at {} (now {})",
                          to_season, static_cast<uint64>(to->end_timestamp), static_cast<uint64>(now));
                return false;
            }

            // Scheduled seasons may be started early by an admin, but that is worth a
            // record in the log because the advertised start date no longer holds.
            if (to->season_type == SEASON_TYPE_TIME_BASED && to->start_timestamp > now)
            {
                LOG_WARN("seasonal", "IsValidSeasonTransition: target season {} starts at {}, activating {} seconds early",
                         to_season, static_cast<uint64>(to->start_timestamp),
                         static_cast<uint64>(to->start_timestamp - now));
            }

            // Transitioning away from a season that was not the one running means the
            // caller's view of the world is stale; allow it (the transition rewrites
            // every season's state anyway) but leave a trail.
            if (from && from->season_state != SEASON_STATE_ACTIVE)
            {
                LOG_WARN("seasonal", "IsValidSeasonTransition: source season {} was not active (state {})",
                         from_season, static_cast<uint32>(from->season_state));
            }

            return true;
        }

    } // namespace Seasonal
} // namespace DarkChaos
