/*
 * Dark Chaos - Group Finder Manager
 * ==================================
 *
 * Singleton manager for the Group Finder system.
 * Handles matchmaking, queue management, scheduled events, and notifications.
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#ifndef DC_GROUP_FINDER_MGR_H
#define DC_GROUP_FINDER_MGR_H

#include "Common.h"
#include "Player.h"
#include "Group.h"
#include "ObjectGuid.h"
#include <unordered_map>
#include <vector>
#include <mutex>
#include <set>
#include <optional>
#include <algorithm>

namespace DCAddon
{
    // ========================================================================
    // ENUMS & CONSTANTS
    // ========================================================================

    enum GroupFinderListingType : uint8
    {
        GF_LISTING_MYTHIC_PLUS = 1,
        GF_LISTING_RAID        = 2,
        GF_LISTING_PVP         = 3,
        GF_LISTING_OTHER       = 4
    };

    enum GroupFinderApplicationStatus : uint8
    {
        GF_APP_PENDING   = 0,
        GF_APP_ACCEPTED  = 1,
        GF_APP_DECLINED  = 2,
        GF_APP_CANCELLED = 3,
        GF_APP_EXPIRED   = 4
    };

    enum GroupFinderRole : uint8
    {
        GF_ROLE_NONE   = 0,
        GF_ROLE_TANK   = 1,
        GF_ROLE_HEALER = 2,
        GF_ROLE_DPS    = 4
    };

    enum ScheduledEventStatus : uint8
    {
        GF_EVENT_OPEN      = 1,
        GF_EVENT_FULL      = 2,
        GF_EVENT_STARTED   = 3,
        GF_EVENT_CANCELLED = 4,
        GF_EVENT_COMPLETED = 5
    };

    // ========================================================================
    // DATA STRUCTURES
    // ========================================================================

    struct GroupFinderListing
    {
        uint32 id = 0;
        uint32 leaderGuid = 0;
        uint32 groupGuid = 0;
        uint8 listingType = GF_LISTING_MYTHIC_PLUS;
        uint32 dungeonId = 0;
        std::string dungeonName;
        uint8 difficulty = 0;
        uint8 keystoneLevel = 0;
        uint16 minIlvl = 0;
        uint16 minRating = 0;
        uint8 currentTank = 0;
        uint8 currentHealer = 0;
        uint8 currentDps = 0;
        uint8 needTank = 1;
        uint8 needHealer = 1;
        uint8 needDps = 3;
        std::string note;
        time_t createdAt = 0;
        time_t expiresAt = 0;
        bool active = true;
    };

    struct GroupFinderApplication
    {
        uint32 id = 0;
        uint32 listingId = 0;
        uint32 playerGuid = 0;
        std::string playerName;
        uint8 role = GF_ROLE_DPS;
        uint8 playerClass = 0;
        uint8 playerLevel = 80;
        uint16 playerIlvl = 0;
        uint16 playerRating = 0;
        std::string note;
        uint8 status = GF_APP_PENDING;
        time_t createdAt = 0;
    };

    struct ScheduledEvent
    {
        uint32 id = 0;
        uint32 leaderGuid = 0;
        uint8 eventType = GF_LISTING_RAID;
        uint32 dungeonId = 0;
        std::string title;
        std::string description;
        uint8 keystoneLevel = 0;
        time_t scheduledTime = 0;
        uint8 maxSignups = 25;
        uint8 currentSignups = 0;
        uint8 status = GF_EVENT_OPEN;
        time_t createdAt = 0;
    };

    struct EventSignup
    {
        uint32 id = 0;
        uint32 eventId = 0;
        uint32 playerGuid = 0;
        std::string playerName;
        uint8 role = GF_ROLE_DPS;
        uint8 status = GF_APP_PENDING;
        std::string note;
        time_t createdAt = 0;
    };

    // ========================================================================
    // GROUP FINDER MANAGER
    // ========================================================================

    class GroupFinderMgr
    {
    private:
        GroupFinderMgr();
        ~GroupFinderMgr() = default;

        // Caches
        std::unordered_map<uint32, GroupFinderListing> _listings;
        std::unordered_map<uint32, std::vector<GroupFinderApplication>> _applications;  // listingId -> apps
        std::unordered_map<uint32, ScheduledEvent> _events;
        std::unordered_map<uint32, std::vector<EventSignup>> _eventSignups;  // eventId -> signups

        // Player lookup (guid -> listings they lead)
        std::unordered_map<uint32, std::set<uint32>> _playerListings;

        // Configuration
        bool _enabled = true;
        bool _crossFaction = false;
        uint32 _listingExpireMinutes = 120;
        uint32 _applicationExpireMinutes = 30;
        uint32 _maxListingsPerPlayer = 3;
        uint32 _maxApplicationsPerPlayer = 10;
        uint32 _ratingMatchRange = 200;
        uint32 _keyLevelMatchRange = 3;
        uint32 _cleanupIntervalMs = 60000;  // 1 minute

        // Reward Config
        bool _rewardEnabled = true;
        uint32 _rewardItemId = 49426;
        uint32 _rewardItemCount = 2;
        uint32 _rewardCurrencyId = 0;
        uint32 _rewardCurrencyCount = 0;
        uint32 _rewardDailyLimit = 1;

        std::mutex _mutex;
        uint32 _lastCleanupTime = 0;

    public:
        static GroupFinderMgr& Instance();

        // Initialization
        void LoadConfig();
        void LoadFromDatabase();
        void Initialize();

        // Cleanup
        void Update(uint32 diff);
        void CleanupExpiredListings();
        void CleanupExpiredApplications();
        void CleanupExpiredEvents();

        // Listing Management
        uint32 CreateListing(Player* player, const GroupFinderListing& listing);
        bool UpdateListing(Player* player, uint32 listingId, const GroupFinderListing& updates);
        bool DeleteListing(Player* player, uint32 listingId);
        std::optional<GroupFinderListing> GetListing(uint32 listingId);
        std::vector<GroupFinderListing> SearchListings(uint8 listingType, uint32 dungeonId,
                                                        uint8 minLevel, uint8 maxLevel, uint16 minRating);

        // Application Management
        bool ApplyToListing(Player* player, uint32 listingId, uint8 role, const std::string& note);
        bool AcceptApplication(Player* leader, uint32 listingId, uint32 applicantGuid);
        bool DeclineApplication(Player* leader, uint32 listingId, uint32 applicantGuid);
        bool CancelApplication(Player* player, uint32 listingId);
        std::vector<GroupFinderApplication> GetApplicationsForListing(uint32 listingId);
        std::vector<GroupFinderApplication> GetPlayerApplications(uint32 playerGuid);

        // Player Data Cleanup (call on logout to prevent memory leaks)
        void CleanupPlayerData(uint32 playerGuid);

        // Rewards
        void HandleDungeonCompletion(Player* player, uint32 dungeonId, uint8 difficulty);
        bool CanReceiveReward(Player* player);
        void GiveReward(Player* player);

        // Matchmaking
        void TryAutoMatch(uint32 listingId);
        bool CheckRoleRequirements(const GroupFinderListing& listing);
        void FormGroupFromListing(uint32 listingId);

        // Scheduled Events
        uint32 CreateEvent(Player* player, const ScheduledEvent& event);
        bool CancelEvent(Player* player, uint32 eventId);
        bool SignupForEvent(Player* player, uint32 eventId, uint8 role, const std::string& note);
        bool CancelEventSignup(Player* player, uint32 eventId);
        bool ConfirmEventSignup(Player* leader, uint32 eventId, uint32 playerGuid);
        std::vector<ScheduledEvent> GetUpcomingEvents(uint8 eventType);
        std::vector<EventSignup> GetEventSignups(uint32 eventId);

        // Player Rating
        uint16 GetPlayerMythicRating(uint32 playerGuid);
        uint16 GetPlayerItemLevel(Player* player);

        // Notifications
        void NotifyNewListing(const GroupFinderListing& listing);
        void NotifyApplicationStatus(uint32 playerGuid, uint32 listingId, uint8 status, const std::string& message);
        void NotifyNewApplication(uint32 leaderGuid, const GroupFinderApplication& app);
        void NotifyGroupReady(uint32 listingId);
        void NotifyEventReminder(uint32 eventId);

        // Getters
        bool IsEnabled() const { return _enabled; }
        bool IsCrossFaction() const { return _crossFaction; }
        uint32 GetListingExpireMinutes() const { return _listingExpireMinutes; }

        // Reward Getters
        bool IsRewardEnabled() const { return _rewardEnabled; }
        uint32 GetRewardItemId() const { return _rewardItemId; }
        uint32 GetRewardItemCount() const { return _rewardItemCount; }
        uint32 GetRewardCurrencyId() const { return _rewardCurrencyId; }
        uint32 GetRewardCurrencyCount() const { return _rewardCurrencyCount; }
        uint32 GetRewardDailyLimit() const { return _rewardDailyLimit; }

        // Utility
        uint32 FindListingIdForApplication(uint32 applicationId);
    };

    #define sGroupFinderMgr GroupFinderMgr::Instance()

}  // namespace DCAddon

#endif // DC_GROUP_FINDER_MGR_H
