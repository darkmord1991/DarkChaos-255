/*
 * Dark Chaos - Group Finder Manager Implementation
 * =================================================
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "Common.h"
#include "dc_addon_groupfinder_mgr.h"
#include "dc_addon_namespace.h"
#include "DatabaseEnv.h"
#include "CharacterDatabase.h"
#include "Config.h"
#include "Log.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "MapMgr.h"
#include "World.h"
#include "Group.h"
#include "../ItemUpgrades/ItemUpgradeManager.h"
#include "../CrossSystem/CrossSystemUtilities.h"
#include "GroupMgr.h"
#include <algorithm>

namespace DCAddon
{

namespace
{
Player* FindConnectedPlayerByGuidLow(uint32 guidLow)
{
    if (!guidLow)
        return nullptr;

    return ObjectAccessor::FindConnectedPlayer(
        ObjectGuid::Create<HighGuid::Player>(guidLow));
}

std::string RoleMaskToString(uint8 roleMask)
{
    std::string role;

    if (roleMask & GF_ROLE_TANK)
        role = "tank";

    if (roleMask & GF_ROLE_HEALER)
        role += role.empty() ? "healer" : "/healer";

    if (roleMask & GF_ROLE_DPS)
        role += role.empty() ? "dps" : "/dps";

    if (role.empty())
        role = "dps";

    return role;
}

uint8 GuessLeaderRoleMask(Player* player)
{
    if (!player)
        return GF_ROLE_DPS;

    if (player->HasHealSpec())
        return GF_ROLE_HEALER;

    if (player->HasTankSpec())
        return GF_ROLE_TANK;

    return GF_ROLE_DPS;
}

uint8 SelectAcceptedRole(GroupFinderListing const& listing, uint8 roleMask)
{
    if ((roleMask & GF_ROLE_TANK) && listing.needTank > 0)
        return GF_ROLE_TANK;

    if ((roleMask & GF_ROLE_HEALER) && listing.needHealer > 0)
        return GF_ROLE_HEALER;

    if ((roleMask & GF_ROLE_DPS) && listing.needDps > 0)
        return GF_ROLE_DPS;

    return GF_ROLE_NONE;
}

void ApplyAcceptedRole(GroupFinderListing& listing, uint8 role)
{
    switch (role)
    {
        case GF_ROLE_TANK:
            ++listing.currentTank;
            --listing.needTank;
            break;
        case GF_ROLE_HEALER:
            ++listing.currentHealer;
            --listing.needHealer;
            break;
        case GF_ROLE_DPS:
            ++listing.currentDps;
            --listing.needDps;
            break;
        default:
            break;
    }
}
}

GroupFinderMgr::GroupFinderMgr()
{
    _lastCleanupTime = 0;
}

GroupFinderMgr& GroupFinderMgr::Instance()
{
    static GroupFinderMgr instance;
    return instance;
}

void GroupFinderMgr::LoadConfig()
{
    _enabled = sConfigMgr->GetOption<bool>("DC.GroupFinder.Enable", true);
    _crossFaction = sConfigMgr->GetOption<bool>("DC.GroupFinder.CrossFaction", false);
    _listingExpireMinutes = sConfigMgr->GetOption<uint32>("DC.GroupFinder.ListingExpireMinutes", 120);
    _applicationExpireMinutes = sConfigMgr->GetOption<uint32>("DC.GroupFinder.ApplicationExpireMinutes", 30);
    _maxListingsPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.MaxListingsPerPlayer", 3);
    _maxApplicationsPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.MaxApplicationsPerPlayer", 10);
    _ratingMatchRange = sConfigMgr->GetOption<uint32>("DC.GroupFinder.RatingMatchRange", 200);
    _keyLevelMatchRange = sConfigMgr->GetOption<uint32>("DC.GroupFinder.KeyLevelMatchRange", 3);
    _cleanupIntervalMs = sConfigMgr->GetOption<uint32>("DC.GroupFinder.CleanupIntervalMs", 60000);

    // Rewards
    _rewardEnabled = sConfigMgr->GetOption<bool>("DC.GroupFinder.Reward.Enable", true);
    _rewardItemId = sConfigMgr->GetOption<uint32>(
        "DC.GroupFinder.Reward.ItemID",
        DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
    _rewardItemCount = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Reward.ItemCount", 2);
    _rewardCurrencyId = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Reward.CurrencyID", 0);
    _rewardCurrencyCount = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Reward.CurrencyCount", 0);
    _rewardDailyLimit = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Reward.DailyLimit", 1);

    LOG_INFO("dc.groupfinder", "Group Finder config loaded: Enabled={}, CrossFaction={}, ExpireMin={}",
        _enabled, _crossFaction, _listingExpireMinutes);
}

void GroupFinderMgr::LoadFromDatabase()
{
    std::lock_guard<std::mutex> lock(_mutex);

    uint32 count = 0;

    // Load active listings
    QueryResult result = CharacterDatabase.Query(
        "SELECT id, leader_guid, group_guid, listing_type, dungeon_id, dungeon_name, difficulty, "
        "keystone_level, min_ilvl, current_tank, current_healer, current_dps, "
        "need_tank, need_healer, need_dps, note, UNIX_TIMESTAMP(created_at) "
        "FROM dc_group_finder_listings WHERE status = 1");

    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            GroupFinderListing listing;
            listing.id = fields[0].Get<uint32>();
            listing.leaderGuid = fields[1].Get<uint32>();
            listing.groupGuid = fields[2].Get<uint32>();
            listing.listingType = fields[3].Get<uint8>();
            listing.dungeonId = fields[4].Get<uint32>();
            listing.dungeonName = fields[5].Get<std::string>();
            listing.difficulty = fields[6].Get<uint8>();
            listing.keystoneLevel = fields[7].Get<uint8>();
            listing.minIlvl = fields[8].Get<uint16>();
            listing.currentTank = fields[9].Get<uint8>();
            listing.currentHealer = fields[10].Get<uint8>();
            listing.currentDps = fields[11].Get<uint8>();
            listing.needTank = fields[12].Get<uint8>();
            listing.needHealer = fields[13].Get<uint8>();
            listing.needDps = fields[14].Get<uint8>();
            listing.note = fields[15].Get<std::string>();
            listing.createdAt = fields[16].Get<time_t>();
            listing.expiresAt = listing.createdAt + (_listingExpireMinutes * 60);
            listing.active = true;

            _listings[listing.id] = listing;
            _playerListings[listing.leaderGuid].insert(listing.id);
            ++count;
        } while (result->NextRow());
    }

    LOG_INFO("dc.groupfinder", "Loaded {} active group finder listings", count);

    // Load pending applications
    count = 0;
    result = CharacterDatabase.Query(
        "SELECT id, listing_id, player_guid, player_name, role, player_class, player_level, "
        "player_ilvl, note, status, UNIX_TIMESTAMP(created_at) "
        "FROM dc_group_finder_applications WHERE status = 0");

    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            GroupFinderApplication app;
            app.id = fields[0].Get<uint32>();
            app.listingId = fields[1].Get<uint32>();
            app.playerGuid = fields[2].Get<uint32>();
            app.playerName = fields[3].Get<std::string>();
            app.role = fields[4].Get<uint8>();
            app.playerClass = fields[5].Get<uint8>();
            app.playerLevel = fields[6].Get<uint8>();
            app.playerIlvl = fields[7].Get<uint16>();
            app.note = fields[8].Get<std::string>();
            app.status = fields[9].Get<uint8>();
            app.createdAt = fields[10].Get<time_t>();

            _applications[app.listingId].push_back(app);
            ++count;
        } while (result->NextRow());
    }

    LOG_INFO("dc.groupfinder", "Loaded {} pending applications", count);

    // Load scheduled events
    count = 0;
    result = CharacterDatabase.Query(
        "SELECT id, leader_guid, event_type, dungeon_id, dungeon_name, keystone_level, "
        "UNIX_TIMESTAMP(scheduled_time), max_signups, current_signups, note, status "
        "FROM dc_group_finder_scheduled_events WHERE status IN (1, 2)");

    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            ScheduledEvent event;
            event.id = fields[0].Get<uint32>();
            event.leaderGuid = fields[1].Get<uint32>();
            event.eventType = fields[2].Get<uint8>();
            event.dungeonId = fields[3].Get<uint32>();
            event.title = fields[4].Get<std::string>();
            event.keystoneLevel = fields[5].Get<uint8>();
            event.scheduledTime = fields[6].Get<time_t>();
            event.maxSignups = fields[7].Get<uint8>();
            event.currentSignups = fields[8].Get<uint8>();
            event.description = fields[9].Get<std::string>();
            event.status = fields[10].Get<uint8>();

            _events[event.id] = event;
            ++count;
        } while (result->NextRow());
    }

    LOG_INFO("dc.groupfinder", "Loaded {} scheduled events", count);

    // Load active event signups
    count = 0;
    result = CharacterDatabase.Query(
        "SELECT id, event_id, player_guid, player_name, role, status, note, UNIX_TIMESTAMP(created_at) "
        "FROM dc_group_finder_event_signups WHERE status IN (0, 1)");

    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 eventId = fields[1].Get<uint32>();

            if (_events.find(eventId) == _events.end())
                continue;

            EventSignup signup;
            signup.id = fields[0].Get<uint32>();
            signup.eventId = eventId;
            signup.playerGuid = fields[2].Get<uint32>();
            signup.playerName = fields[3].Get<std::string>();
            signup.role = fields[4].Get<uint8>();
            signup.status = fields[5].Get<uint8>();
            signup.note = fields[6].Get<std::string>();
            signup.createdAt = fields[7].Get<time_t>();

            _eventSignups[eventId].push_back(signup);
            ++count;
        } while (result->NextRow());
    }

    LOG_INFO("dc.groupfinder", "Loaded {} active event signups", count);
}

void GroupFinderMgr::Initialize()
{
    LoadConfig();
    LoadFromDatabase();
    LOG_INFO("dc.groupfinder", "Group Finder Manager initialized");
}

void GroupFinderMgr::Update(uint32 diff)
{
    if (!_enabled)
        return;

    _lastCleanupTime += diff;

    if (_lastCleanupTime >= _cleanupIntervalMs)
    {
        _lastCleanupTime = 0;
        CleanupExpiredListings();
        CleanupExpiredApplications();
        CleanupExpiredEvents();
    }
}

void GroupFinderMgr::CleanupExpiredListings()
{
    std::lock_guard<std::mutex> lock(_mutex);

    time_t now = GameTime::GetGameTime().count();
    std::vector<uint32> toRemove;

    for (auto& [id, listing] : _listings)
    {
        if (listing.expiresAt > 0 && now >= listing.expiresAt)
        {
            toRemove.push_back(id);
        }
    }

    for (uint32 id : toRemove)
    {
        auto listingIt = _listings.find(id);
        if (listingIt == _listings.end())
            continue;

        GroupFinderListing const& listing = listingIt->second;

        // Notify leader
        if (Player* leader = FindConnectedPlayerByGuidLow(listing.leaderGuid))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                .Set("action", "expired")
                .Set("listingId", static_cast<int32>(id))
                .Set("message", "Your group listing has expired")
                .Send(leader);
        }

        auto appsIt = _applications.find(id);
        if (appsIt != _applications.end())
        {
            for (GroupFinderApplication const& app : appsIt->second)
            {
                if (app.status == GF_APP_PENDING)
                {
                    NotifyApplicationStatus(
                        app.playerGuid,
                        id,
                        GF_APP_EXPIRED,
                        "The group listing expired.");
                }
            }
        }

        // Update database
        CharacterDatabase.Execute("UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}", id);
        CharacterDatabase.Execute("UPDATE dc_group_finder_applications SET status = 4 WHERE listing_id = {} AND status = 0", id);

        // Remove from cache
        auto playerListingsIt = _playerListings.find(listing.leaderGuid);
        if (playerListingsIt != _playerListings.end())
        {
            playerListingsIt->second.erase(id);
            if (playerListingsIt->second.empty())
                _playerListings.erase(playerListingsIt);
        }

        _applications.erase(id);
        _listings.erase(listingIt);
    }

    if (!toRemove.empty())
        LOG_DEBUG("dc.groupfinder", "Cleaned up {} expired listings", toRemove.size());
}

void GroupFinderMgr::CleanupExpiredApplications()
{
    std::lock_guard<std::mutex> lock(_mutex);

    time_t cutoff = GameTime::GetGameTime().count() - (_applicationExpireMinutes * 60);

    for (auto appsIt = _applications.begin(); appsIt != _applications.end();)
    {
        uint32 listingId = appsIt->first;
        auto& apps = appsIt->second;

        for (GroupFinderApplication const& app : apps)
        {
            if (app.status == GF_APP_PENDING && app.createdAt < cutoff)
            {
                CharacterDatabase.Execute(
                    "UPDATE dc_group_finder_applications SET status = 4 WHERE id = {}",
                    app.id);

                NotifyApplicationStatus(
                    app.playerGuid,
                    listingId,
                    GF_APP_EXPIRED,
                    "Your application expired.");

                if (auto listingIt = _listings.find(listingId); listingIt != _listings.end())
                {
                    if (Player* leader = FindConnectedPlayerByGuidLow(
                            listingIt->second.leaderGuid))
                    {
                        JsonMessage(Module::GROUP_FINDER,
                            Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                            .Set("action", "application_cancelled")
                            .Set("listingId", static_cast<int32>(listingId))
                            .Set("playerGuid", static_cast<int32>(app.playerGuid))
                            .Send(leader);
                    }
                }
            }
        }

        apps.erase(
            std::remove_if(apps.begin(), apps.end(),
                [cutoff](GroupFinderApplication const& app)
                {
                    return app.status == GF_APP_PENDING && app.createdAt < cutoff;
                }),
            apps.end());

        if (apps.empty())
            appsIt = _applications.erase(appsIt);
        else
            ++appsIt;
    }
}

void GroupFinderMgr::CleanupExpiredEvents()
{
    std::lock_guard<std::mutex> lock(_mutex);

    time_t now = GameTime::GetGameTime().count();
    std::vector<uint32> toRemove;

    for (auto& [id, event] : _events)
    {
        // Events that have passed their scheduled time by 1 hour are marked completed
        if (event.scheduledTime + 3600 < now && event.status < GF_EVENT_STARTED)
        {
            toRemove.push_back(id);
        }
    }

    for (uint32 id : toRemove)
    {
        CharacterDatabase.Execute("UPDATE dc_group_finder_scheduled_events SET status = 5 WHERE id = {}", id);
        _events.erase(id);
    }
}

// ========================================================================
// LISTING MANAGEMENT
// ========================================================================

uint32 GroupFinderMgr::CreateListing(Player* player, const GroupFinderListing& listing)
{
    std::lock_guard<std::mutex> lock(_mutex);

    uint32 guid = player->GetGUID().GetCounter();

    // Check max listings
    if (_playerListings[guid].size() >= _maxListingsPerPlayer)
        return 0;

    // Get group GUID if in a group
    uint32 groupGuid = 0;
    if (Group* group = player->GetGroup())
        groupGuid = group->GetGUID().GetCounter();

    std::string safeNote = listing.note;
    std::string safeDungeonName = listing.dungeonName;
    CharacterDatabase.EscapeString(safeNote);
    CharacterDatabase.EscapeString(safeDungeonName);

    GroupFinderListing storedListing = listing;
    uint8 leaderRole = SelectAcceptedRole(storedListing, GuessLeaderRoleMask(player));
    if (leaderRole == GF_ROLE_NONE)
        leaderRole = SelectAcceptedRole(storedListing, GF_ROLE_TANK | GF_ROLE_HEALER | GF_ROLE_DPS);

    ApplyAcceptedRole(storedListing, leaderRole);

    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_listings "
        "(leader_guid, group_guid, listing_type, dungeon_id, dungeon_name, difficulty, "
        "keystone_level, min_ilvl, current_tank, current_healer, current_dps, "
        "need_tank, need_healer, need_dps, note, status) "
        "VALUES ({}, {}, {}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}, {}, '{}', 1)",
        guid, groupGuid, storedListing.listingType, storedListing.dungeonId, safeDungeonName,
        storedListing.difficulty, storedListing.keystoneLevel, storedListing.minIlvl,
        storedListing.currentTank, storedListing.currentHealer, storedListing.currentDps,
        storedListing.needTank, storedListing.needHealer, storedListing.needDps, safeNote);

    // Avoid LAST_INSERT_ID() here because the insert and follow-up query can use different pooled connections.
    QueryResult result = CharacterDatabase.Query(
        "SELECT id FROM dc_group_finder_listings WHERE leader_guid = {} AND group_guid = {} "
        "AND listing_type = {} AND dungeon_id = {} AND dungeon_name = '{}' AND difficulty = {} "
        "AND keystone_level = {} AND min_ilvl = {} AND current_tank = {} AND current_healer = {} "
        "AND current_dps = {} AND need_tank = {} AND need_healer = {} AND need_dps = {} "
        "AND note = '{}' AND status = 1 ORDER BY id DESC LIMIT 1",
        guid, groupGuid, storedListing.listingType, storedListing.dungeonId, safeDungeonName,
        storedListing.difficulty, storedListing.keystoneLevel, storedListing.minIlvl,
        storedListing.currentTank, storedListing.currentHealer, storedListing.currentDps,
        storedListing.needTank, storedListing.needHealer, storedListing.needDps, safeNote);
    uint32 listingId = result ? (*result)[0].Get<uint32>() : 0;

    if (listingId > 0)
    {
        storedListing.id = listingId;
        storedListing.leaderGuid = guid;
        storedListing.groupGuid = groupGuid;
        storedListing.leaderMapId = player->GetMapId();
        storedListing.leaderInstanceId = player->GetInstanceId();
        storedListing.createdAt = GameTime::GetGameTime().count();
        storedListing.expiresAt = storedListing.createdAt + (_listingExpireMinutes * 60);
        storedListing.active = true;

        _listings[listingId] = storedListing;
        _playerListings[guid].insert(listingId);

        // Notify potential matches
        NotifyNewListing(storedListing);
    }
    else
    {
        LOG_ERROR("dc.groupfinder",
            "Failed to resolve inserted listing id for leader={} dungeon='{}' type={} level={}",
            guid, listing.dungeonName, listing.listingType, listing.keystoneLevel);
    }

    return listingId;
}

bool GroupFinderMgr::DeleteListing(Player* player, uint32 listingId)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _listings.find(listingId);
    if (it == _listings.end())
        return false;

    if (it->second.leaderGuid != player->GetGUID().GetCounter())
        return false;

    // Update database
    CharacterDatabase.Execute("UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}", listingId);
    CharacterDatabase.Execute("UPDATE dc_group_finder_applications SET status = 3 WHERE listing_id = {} AND status = 0", listingId);

    // Notify applicants
    for (auto const& app : _applications[listingId])
    {
        if (app.status == GF_APP_PENDING)
        {
            NotifyApplicationStatus(app.playerGuid, listingId, GF_APP_CANCELLED, "Group listing was removed");
        }
    }

    // Remove from cache
    auto playerListingsIt = _playerListings.find(it->second.leaderGuid);
    if (playerListingsIt != _playerListings.end())
    {
        playerListingsIt->second.erase(listingId);
        if (playerListingsIt->second.empty())
            _playerListings.erase(playerListingsIt);
    }

    _applications.erase(listingId);
    _listings.erase(it);

    return true;
}

std::optional<GroupFinderListing> GroupFinderMgr::GetListing(uint32 listingId)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _listings.find(listingId);
    if (it != _listings.end())
        return it->second;
    return std::nullopt;
}

std::vector<GroupFinderListing> GroupFinderMgr::SearchListings(uint8 listingType, uint32 dungeonId,
                                                                uint8 minLevel, uint8 maxLevel, uint16 minRating)
{
    std::lock_guard<std::mutex> lock(_mutex);

    std::vector<GroupFinderListing> results;

    for (auto const& [id, listing] : _listings)
    {
        if (!listing.active)
            continue;

        if (listingType > 0 && listing.listingType != listingType)
            continue;

        if (dungeonId > 0 && listing.dungeonId != dungeonId)
            continue;

        if (minLevel > 0 && listing.keystoneLevel < minLevel)
            continue;

        if (maxLevel > 0 && listing.keystoneLevel > maxLevel)
            continue;

        if (minRating > 0 && listing.minRating < minRating)
            continue;

        results.push_back(listing);
    }

    // Sort by keystone level descending
    std::sort(results.begin(), results.end(), [](const GroupFinderListing& a, const GroupFinderListing& b) {
        return a.keystoneLevel > b.keystoneLevel;
    });

    // Limit results
    if (results.size() > 50)
        results.resize(50);

    return results;
}

// ========================================================================
// APPLICATION MANAGEMENT
// ========================================================================

bool GroupFinderMgr::ApplyToListing(Player* player, uint32 listingId, uint8 role, const std::string& note)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _listings.find(listingId);
    if (it == _listings.end() || !it->second.active)
        return false;

    uint32 guid = player->GetGUID().GetCounter();

    // Can't apply to own listing
    if (it->second.leaderGuid == guid)
        return false;

    // Check if already applied
    auto& apps = _applications[listingId];
    for (auto const& app : apps)
    {
        if (app.playerGuid == guid && app.status == GF_APP_PENDING)
            return false;
    }

    // Check item level requirement
    uint16 playerIlvl = GetPlayerItemLevel(player);
    if (it->second.minIlvl > 0 && playerIlvl < it->second.minIlvl)
        return false;

    // Check rating requirement for M+
    uint16 playerRating = 0;
    if (it->second.listingType == GF_LISTING_MYTHIC_PLUS && it->second.minRating > 0)
    {
        playerRating = GetPlayerMythicRating(guid);
        if (playerRating < it->second.minRating)
            return false;
    }

    std::string safeNote = note;
    CharacterDatabase.EscapeString(safeNote);
    std::string safePlayerName = player->GetName();
    CharacterDatabase.EscapeString(safePlayerName);

    // Insert application
    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_applications "
        "(listing_id, player_guid, player_name, role, player_class, player_level, player_ilvl, note, status) "
        "VALUES ({}, {}, '{}', {}, {}, {}, {}, '{}', 0)",
        listingId, guid, safePlayerName, role, player->getClass(), player->GetLevel(), playerIlvl, safeNote);

    // Get inserted ID
    QueryResult result = CharacterDatabase.Query("SELECT LAST_INSERT_ID()");
    uint32 appId = result ? (*result)[0].Get<uint32>() : 0;

    if (appId > 0)
    {
        GroupFinderApplication app;
        app.id = appId;
        app.listingId = listingId;
        app.playerGuid = guid;
        app.playerMapId = player->GetMapId();
        app.playerInstanceId = player->GetInstanceId();
        app.playerName = player->GetName();
        app.role = role;
        app.playerClass = player->getClass();
        app.playerLevel = player->GetLevel();
        app.playerIlvl = playerIlvl;
        app.playerRating = playerRating;
        app.note = note;
        app.status = GF_APP_PENDING;
        app.createdAt = GameTime::GetGameTime().count();

        apps.push_back(app);

        // Notify leader
        NotifyNewApplication(it->second.leaderGuid, app);
    }

    return appId > 0;
}

bool GroupFinderMgr::AcceptApplication(Player* leader, uint32 listingId, uint32 applicantGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto listingIt = _listings.find(listingId);
    if (listingIt == _listings.end())
        return false;

    if (listingIt->second.leaderGuid != leader->GetGUID().GetCounter())
        return false;

    auto& apps = _applications[listingId];
    for (auto& app : apps)
    {
        if (app.playerGuid == applicantGuid && app.status == GF_APP_PENDING)
        {
            uint8 acceptedRole = SelectAcceptedRole(listingIt->second, app.role);
            if (acceptedRole == GF_ROLE_NONE)
                return false;

            app.status = GF_APP_ACCEPTED;

            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_applications SET status = 1 WHERE id = {}",
                app.id);

            // Update listing role counts
            ApplyAcceptedRole(listingIt->second, acceptedRole);

            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_listings SET current_tank = {}, current_healer = {}, current_dps = {}, "
                "need_tank = {}, need_healer = {}, need_dps = {} WHERE id = {}",
                listingIt->second.currentTank, listingIt->second.currentHealer, listingIt->second.currentDps,
                listingIt->second.needTank, listingIt->second.needHealer, listingIt->second.needDps, listingId);

            // Notify applicant
            NotifyApplicationStatus(applicantGuid, listingId, GF_APP_ACCEPTED, "Your application was accepted!");

            // Invite to group
            if (Player* applicant = FindConnectedPlayerByGuidLow(applicantGuid))
            {
                if (Group* group = leader->GetGroup())
                {
                    group->AddMember(applicant);
                }
                else
                {
                    Group* newGroup = new Group();
                    if (newGroup->Create(leader))
                    {
                        sGroupMgr->AddGroup(newGroup);
                        newGroup->AddMember(applicant);
                    }
                    else
                    {
                        delete newGroup;
                    }
                }
            }

            // Persist the final group GUID so completion rewards can verify
            // this run was created through Group Finder.
            if (Group* group = leader->GetGroup())
            {
                uint32 groupGuid = group->GetGUID().GetCounter();
                if (groupGuid != listingIt->second.groupGuid)
                {
                    listingIt->second.groupGuid = groupGuid;
                    CharacterDatabase.Execute(
                        "UPDATE dc_group_finder_listings SET group_guid = {} WHERE id = {}",
                        groupGuid, listingId);
                }
            }

            // Check if group is now complete
            if (CheckRoleRequirements(listingIt->second))
            {
                NotifyGroupReady(listingId);
            }

            return true;
        }
    }

    return false;
}

bool GroupFinderMgr::DeclineApplication(Player* leader, uint32 listingId, uint32 applicantGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto listingIt = _listings.find(listingId);
    if (listingIt == _listings.end())
        return false;

    if (listingIt->second.leaderGuid != leader->GetGUID().GetCounter())
        return false;

    auto& apps = _applications[listingId];
    for (auto& app : apps)
    {
        if (app.playerGuid == applicantGuid && app.status == GF_APP_PENDING)
        {
            app.status = GF_APP_DECLINED;

            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_applications SET status = 2 WHERE id = {}",
                app.id);

            NotifyApplicationStatus(applicantGuid, listingId, GF_APP_DECLINED, "Your application was declined.");
            return true;
        }
    }

    return false;
}

bool GroupFinderMgr::CancelApplication(Player* player, uint32 listingId)
{
    std::lock_guard<std::mutex> lock(_mutex);

    uint32 playerGuid = player->GetGUID().GetCounter();
    auto appsIt = _applications.find(listingId);
    if (appsIt == _applications.end())
        return false;

    auto& apps = appsIt->second;
    for (auto appIt = apps.begin(); appIt != apps.end(); ++appIt)
    {
        if (appIt->playerGuid != playerGuid || appIt->status != GF_APP_PENDING)
            continue;

        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_applications SET status = 3 WHERE id = {}",
            appIt->id);

        if (auto listingIt = _listings.find(listingId); listingIt != _listings.end())
        {
            if (Player* leader = FindConnectedPlayerByGuidLow(
                    listingIt->second.leaderGuid))
            {
                JsonMessage(Module::GROUP_FINDER,
                    Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                    .Set("action", "application_cancelled")
                    .Set("listingId", static_cast<int32>(listingId))
                    .Set("playerGuid", static_cast<int32>(playerGuid))
                    .Send(leader);
            }
        }

        apps.erase(appIt);
        if (apps.empty())
            _applications.erase(appsIt);

        return true;
    }

    return false;
}

std::vector<GroupFinderApplication> GroupFinderMgr::GetApplicationsForListing(uint32 listingId)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _applications.find(listingId);
    if (it != _applications.end())
        return it->second;

    return {};
}

// ========================================================================
// MATCHMAKING
// ========================================================================

bool GroupFinderMgr::CheckRoleRequirements(const GroupFinderListing& listing)
{
    return listing.needTank == 0 && listing.needHealer == 0 && listing.needDps == 0;
}

void GroupFinderMgr::NotifyGroupReady(uint32 listingId)
{
    auto it = _listings.find(listingId);
    if (it == _listings.end())
        return;

    // Notify leader
    if (Player* leader = FindConnectedPlayerByGuidLow(it->second.leaderGuid))
    {
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
            .Set("action", "ready")
            .Set("listingId", static_cast<int32>(listingId))
            .Set("message", "Your group is now complete!")
            .Send(leader);
    }

    auto appsIt = _applications.find(listingId);
    if (appsIt != _applications.end())
    {
        for (GroupFinderApplication const& app : appsIt->second)
        {
            if (app.status == GF_APP_PENDING)
            {
                NotifyApplicationStatus(
                    app.playerGuid,
                    listingId,
                    GF_APP_CANCELLED,
                    "The group is now full.");
            }
        }
    }

    // Auto-delist since group is complete
    CharacterDatabase.Execute(
        "UPDATE dc_group_finder_applications SET status = 3 WHERE listing_id = {} AND status = 0",
        listingId);
    CharacterDatabase.Execute("UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}", listingId);

    auto playerListingsIt = _playerListings.find(it->second.leaderGuid);
    if (playerListingsIt != _playerListings.end())
    {
        playerListingsIt->second.erase(listingId);
        if (playerListingsIt->second.empty())
            _playerListings.erase(playerListingsIt);
    }

    _applications.erase(listingId);
    _listings.erase(it);
}

// ========================================================================
// SCHEDULED EVENTS
// ========================================================================

uint32 GroupFinderMgr::CreateEvent(Player* player, const ScheduledEvent& event)
{
    std::lock_guard<std::mutex> lock(_mutex);

    uint32 guid = player->GetGUID().GetCounter();

    std::string safeTitle = event.title;
    CharacterDatabase.EscapeString(safeTitle);
    std::string safeDesc = event.description;
    CharacterDatabase.EscapeString(safeDesc);

    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_scheduled_events "
        "(leader_guid, event_type, dungeon_id, dungeon_name, keystone_level, scheduled_time, max_signups, note, status) "
        "VALUES ({}, {}, {}, '{}', {}, FROM_UNIXTIME({}), {}, '{}', 1)",
        guid, event.eventType, event.dungeonId, safeTitle, event.keystoneLevel,
        event.scheduledTime, event.maxSignups, safeDesc);

    QueryResult result = CharacterDatabase.Query("SELECT LAST_INSERT_ID()");
    uint32 eventId = result ? (*result)[0].Get<uint32>() : 0;

    if (eventId > 0)
    {
        ScheduledEvent newEvent = event;
        newEvent.id = eventId;
        newEvent.leaderGuid = guid;
        newEvent.status = GF_EVENT_OPEN;
        newEvent.createdAt = GameTime::GetGameTime().count();

        _events[eventId] = newEvent;
    }

    return eventId;
}

bool GroupFinderMgr::SignupForEvent(Player* player, uint32 eventId, uint8 role, const std::string& note)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _events.find(eventId);
    if (it == _events.end() || it->second.status != GF_EVENT_OPEN)
        return false;

    if (it->second.currentSignups >= it->second.maxSignups)
        return false;

    uint32 guid = player->GetGUID().GetCounter();

    // Check if already signed up
    auto& signups = _eventSignups[eventId];
    for (auto const& signup : signups)
    {
        if (signup.playerGuid == guid)
            return false;
    }

    std::string safeNote = note;
    CharacterDatabase.EscapeString(safeNote);
    std::string safePlayerName = player->GetName();
    CharacterDatabase.EscapeString(safePlayerName);

    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_event_signups (event_id, player_guid, player_name, role, note, status) "
        "VALUES ({}, {}, '{}', {}, '{}', 0)",
        eventId, guid, safePlayerName, role, safeNote);

    QueryResult result = CharacterDatabase.Query("SELECT LAST_INSERT_ID()");
    uint32 signupId = result ? (*result)[0].Get<uint32>() : 0;

    if (signupId > 0)
    {
        EventSignup signup;
        signup.id = signupId;
        signup.eventId = eventId;
        signup.playerGuid = guid;
        signup.playerName = player->GetName();
        signup.role = role;
        signup.note = note;
        signup.status = GF_APP_PENDING;
        signup.createdAt = GameTime::GetGameTime().count();

        signups.push_back(signup);

        it->second.currentSignups++;
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET current_signups = {} WHERE id = {}",
            it->second.currentSignups, eventId);

        if (it->second.currentSignups >= it->second.maxSignups)
        {
            it->second.status = GF_EVENT_FULL;
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_scheduled_events SET status = 2 WHERE id = {}",
                eventId);
        }
    }

    return signupId > 0;
}

std::vector<ScheduledEvent> GroupFinderMgr::GetUpcomingEvents(uint8 eventType)
{
    std::lock_guard<std::mutex> lock(_mutex);

    std::vector<ScheduledEvent> results;
    time_t now = GameTime::GetGameTime().count();

    for (auto const& [id, event] : _events)
    {
        if (event.status > GF_EVENT_FULL)
            continue;

        if (event.scheduledTime < now)
            continue;

        if (eventType > 0 && event.eventType != eventType)
            continue;

        results.push_back(event);
    }

    // Sort by scheduled time
    std::sort(results.begin(), results.end(), [](const ScheduledEvent& a, const ScheduledEvent& b) {
        return a.scheduledTime < b.scheduledTime;
    });

    return results;
}

std::vector<EventSignup> GroupFinderMgr::GetEventSignups(uint32 eventId)
{
    std::lock_guard<std::mutex> lock(_mutex);

    auto it = _eventSignups.find(eventId);
    if (it != _eventSignups.end())
        return it->second;

    return {};
}

std::vector<PlayerEventSignup> GroupFinderMgr::GetPlayerEventSignups(uint32 playerGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);

    std::vector<PlayerEventSignup> results;
    time_t now = GameTime::GetGameTime().count();

    for (auto const& [eventId, signups] : _eventSignups)
    {
        auto eventIt = _events.find(eventId);
        if (eventIt == _events.end())
            continue;

        ScheduledEvent const& event = eventIt->second;
        if (event.status > GF_EVENT_FULL)
            continue;

        if (event.scheduledTime < now)
            continue;

        for (EventSignup const& signup : signups)
        {
            if (signup.playerGuid != playerGuid)
                continue;

            if (signup.status != GF_APP_PENDING && signup.status != GF_APP_ACCEPTED)
                continue;

            results.push_back({ signup, event });
        }
    }

    std::sort(results.begin(), results.end(),
        [](PlayerEventSignup const& left, PlayerEventSignup const& right)
        {
            return left.event.scheduledTime < right.event.scheduledTime;
        });

    return results;
}

// ========================================================================
// PLAYER DATA
// ========================================================================

uint16 GroupFinderMgr::GetPlayerMythicRating(uint32 playerGuid)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT rating FROM dc_mplus_player_ratings WHERE player_guid = {}",
        playerGuid);

    if (result)
        return (*result)[0].Get<uint16>();

    return 0;
}

uint16 GroupFinderMgr::GetPlayerItemLevel(Player* player)
{
    if (!player)
        return 0;

    // Calculate average equipped item level
    uint32 totalIlvl = 0;
    uint32 itemCount = 0;

    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
        {
            if (const ItemTemplate* proto = item->GetTemplate())
            {
                totalIlvl += proto->ItemLevel;
                ++itemCount;
            }
        }
    }

    return itemCount > 0 ? static_cast<uint16>(totalIlvl / itemCount) : 0;
}

// ========================================================================
// NOTIFICATIONS
// ========================================================================

void GroupFinderMgr::NotifyNewListing(const GroupFinderListing& listing)
{
    // Future: Could broadcast to players who have matching search criteria
    // For now, just log
    std::string listingType = "Other";
    switch (listing.listingType)
    {
        case GF_LISTING_MYTHIC_PLUS:
            listingType = "M+";
            break;
        case GF_LISTING_RAID:
            listingType = "Raid";
            break;
        case GF_LISTING_PVP:
            listingType = "PvP";
            break;
        case GF_LISTING_QUEST:
            listingType = "Quest";
            break;
        default:
            break;
    }

    LOG_DEBUG("dc.groupfinder", "New listing created: {} {} +{}",
        listing.dungeonName, listingType, listing.keystoneLevel);
}

void GroupFinderMgr::NotifyApplicationStatus(uint32 playerGuid, uint32 listingId, uint8 status, const std::string& message)
{
    if (Player* player = FindConnectedPlayerByGuidLow(playerGuid))
    {
        std::string statusStr;
        switch (status)
        {
            case GF_APP_ACCEPTED: statusStr = "accepted"; break;
            case GF_APP_DECLINED: statusStr = "declined"; break;
            case GF_APP_CANCELLED: statusStr = "cancelled"; break;
            case GF_APP_EXPIRED: statusStr = "expired"; break;
            default: statusStr = "pending"; break;
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_APPLICATION_STATUS)
            .Set("success", status == GF_APP_ACCEPTED)
            .Set("status", statusStr)
            .Set("listingId", static_cast<int32>(listingId))
            .Set("message", message)
            .Send(player);
    }
}

void GroupFinderMgr::NotifyNewApplication(uint32 leaderGuid, const GroupFinderApplication& app)
{
    if (Player* leader = FindConnectedPlayerByGuidLow(leaderGuid))
    {
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_NEW_APPLICATION)
            .Set("applicationId", static_cast<int32>(app.id))
            .Set("listingId", static_cast<int32>(app.listingId))
            .Set("playerGuid", static_cast<int32>(app.playerGuid))
            .Set("playerName", app.playerName)
            .Set("role", RoleMaskToString(app.role))
            .Set("playerClass", static_cast<int32>(app.playerClass))
            .Set("playerLevel", static_cast<int32>(app.playerLevel))
            .Set("playerIlvl", static_cast<int32>(app.playerIlvl))
            .Set("playerRating", static_cast<int32>(app.playerRating))
            .Set("message", app.note)
            .Send(leader);
    }
}

// Note: NotifyGroupReady is implemented above with database and cache update logic

void GroupFinderMgr::NotifyEventReminder(uint32 eventId)
{
    (void)eventId; // unused currently
    // Implementation for NotifyEventReminder
}

void GroupFinderMgr::CleanupPlayerData(uint32 playerGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);

    // Delist the player's active listings and notify pending applicants.
    auto listingIt = _playerListings.find(playerGuid);
    if (listingIt != _playerListings.end())
    {
        for (uint32 listingId : listingIt->second)
        {
            auto currentListingIt = _listings.find(listingId);
            if (currentListingIt == _listings.end())
                continue;

            auto appsIt = _applications.find(listingId);
            if (appsIt != _applications.end())
            {
                for (GroupFinderApplication const& app : appsIt->second)
                {
                    if (app.status == GF_APP_PENDING)
                    {
                        NotifyApplicationStatus(
                            app.playerGuid,
                            listingId,
                            GF_APP_CANCELLED,
                            "The listing was removed because the leader logged out.");
                    }
                }
            }

            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}",
                listingId);
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_applications SET status = 3 WHERE listing_id = {} AND status = 0",
                listingId);

            _applications.erase(listingId);
            _listings.erase(currentListingIt);
        }
        _playerListings.erase(listingIt);
    }

    // Cancel the player's pending applications and update leader queues.
    for (auto appsIt = _applications.begin(); appsIt != _applications.end();)
    {
        uint32 listingId = appsIt->first;
        auto& apps = appsIt->second;

        bool removedAny = false;
        apps.erase(
            std::remove_if(apps.begin(), apps.end(),
                [&](GroupFinderApplication const& app)
                {
                    if (app.playerGuid != playerGuid || app.status != GF_APP_PENDING)
                        return false;

                    CharacterDatabase.Execute(
                        "UPDATE dc_group_finder_applications SET status = 3 WHERE id = {}",
                        app.id);
                    removedAny = true;
                    return true;
                }),
            apps.end());

        if (removedAny)
        {
            if (auto currentListingIt = _listings.find(listingId);
                currentListingIt != _listings.end())
            {
                if (Player* leader = FindConnectedPlayerByGuidLow(
                        currentListingIt->second.leaderGuid))
                {
                    JsonMessage(Module::GROUP_FINDER,
                        Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                        .Set("action", "application_cancelled")
                        .Set("listingId", static_cast<int32>(listingId))
                        .Set("playerGuid", static_cast<int32>(playerGuid))
                        .Send(leader);
                }
            }
        }

        if (apps.empty())
            appsIt = _applications.erase(appsIt);
        else
            ++appsIt;
    }

    // Cancel the player's event signups and rebalance signup counts.
    for (auto& [eventId, signups] : _eventSignups)
    {
        uint32 removedCount = 0;

        signups.erase(
            std::remove_if(signups.begin(), signups.end(),
                [&](EventSignup const& signup)
                {
                    if (signup.playerGuid != playerGuid)
                        return false;

                    CharacterDatabase.Execute(
                        "UPDATE dc_group_finder_event_signups SET status = 3 WHERE id = {}",
                        signup.id);
                    ++removedCount;
                    return true;
                }),
            signups.end());

        if (removedCount == 0)
            continue;

        auto eventIt = _events.find(eventId);
        if (eventIt == _events.end())
            continue;

        eventIt->second.currentSignups =
            eventIt->second.currentSignups > removedCount
                ? eventIt->second.currentSignups - removedCount
                : 0;

        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET current_signups = {}, status = CASE WHEN status = {} THEN {} ELSE status END WHERE id = {}",
            eventIt->second.currentSignups,
            static_cast<uint8>(GF_EVENT_FULL),
            static_cast<uint8>(GF_EVENT_OPEN),
            eventId);

        if (eventIt->second.status == GF_EVENT_FULL &&
            eventIt->second.currentSignups < eventIt->second.maxSignups)
        {
            eventIt->second.status = GF_EVENT_OPEN;
        }
    }
}

std::vector<GroupFinderApplication> GroupFinderMgr::GetPlayerApplications(uint32 playerGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);
    std::vector<GroupFinderApplication> result;

    for (auto const& pair : _applications)
    {
        for (auto const& app : pair.second)
        {
            if (app.playerGuid == playerGuid && app.status == GF_APP_PENDING)
            {
                result.push_back(app);
            }
        }
    }
    return result;
}

uint32 GroupFinderMgr::FindListingIdForApplication(uint32 applicationId)
{
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto const& kv : _applications)
    {
        uint32 listingId = kv.first;
        auto const& apps = kv.second;
        for (auto const& app : apps)
        {
            if (app.id == applicationId)
                return listingId;
        }
    }
    return 0;
}

void GroupFinderMgr::HandleDungeonCompletion(Player* player, uint32 dungeonId, uint8 difficulty)
{
    if (!_rewardEnabled || !player)
        return;

    (void)difficulty;

    Group* group = player->GetGroup();
    if (!group)
        return;

    uint32 playerGuid = player->GetGUID().GetCounter();
    uint32 groupGuid = group->GetGUID().GetCounter();
    uint32 groupLeaderGuid = group->GetLeaderGUID().GetCounter();
    bool eligibleGroupFinderRun = false;

    {
        std::lock_guard<std::mutex> lock(_mutex);

        for (auto const& [listingId, listing] : _listings)
        {
            if (listing.listingType != GF_LISTING_MYTHIC_PLUS)
                continue;

            if (listing.dungeonId > 0 && dungeonId > 0 && listing.dungeonId != dungeonId)
                continue;

            if (listing.groupGuid > 0)
            {
                if (listing.groupGuid != groupGuid)
                    continue;
            }
            else if (listing.leaderGuid != groupLeaderGuid)
                continue;

            bool linkedPlayer = (listing.leaderGuid == playerGuid);
            if (!linkedPlayer)
            {
                auto appsIt = _applications.find(listingId);
                if (appsIt != _applications.end())
                {
                    for (GroupFinderApplication const& app : appsIt->second)
                    {
                        if (app.playerGuid == playerGuid &&
                            app.status == GF_APP_ACCEPTED)
                        {
                            linkedPlayer = true;
                            break;
                        }
                    }
                }
            }

            if (!linkedPlayer)
                continue;

            eligibleGroupFinderRun = true;
            break;
        }
    }

    if (!eligibleGroupFinderRun)
        return;

    if (CanReceiveReward(player))
        GiveReward(player);
}

bool GroupFinderMgr::CanReceiveReward(Player* player)
{
    if (!_rewardEnabled) return false;

    // Check daily limit
    if (_rewardDailyLimit > 0)
    {
        uint32 count = 0;
        QueryResult result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_group_finder_rewards WHERE player_guid = {} AND claim_time > DATE_SUB(NOW(), INTERVAL 1 DAY)", player->GetGUID().GetCounter());
        if (result)
            count = (*result)[0].Get<uint32>();

        if (count >= _rewardDailyLimit)
            return false;
    }

    return true;
}

void GroupFinderMgr::GiveReward(Player* player)
{
    if (!player) return;

    // Give Item
    if (_rewardItemId > 0 && _rewardItemCount > 0)
    {
        player->AddItem(_rewardItemId, _rewardItemCount);
    }

    // Give Currency
    if (_rewardCurrencyId > 0 && _rewardCurrencyCount > 0)
    {
        // Award currency using centralized utility
        if (!DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
            player->GetGUID().GetCounter(),
            static_cast<DarkChaos::ItemUpgrade::CurrencyType>(_rewardCurrencyId),
            _rewardCurrencyCount,
            DarkChaos::ItemUpgrade::GetCurrentSeasonId(),
            player,
            true))
        {
            // Fall back to ModifyMoney for gold-based rewards (if configured as such)
            player->ModifyMoney(static_cast<int32>(_rewardCurrencyCount));
        }
    }

    // Log reward
    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_rewards (player_guid, reward_type, dungeon_type) "
        "VALUES ({}, 0, 0) "
        "ON DUPLICATE KEY UPDATE claim_time = CURRENT_TIMESTAMP",
        player->GetGUID().GetCounter());

    player->SendSystemMessage("You have received a reward for using the Group Finder!");
}

void GroupFinderMgr::TryAutoMatch(uint32 listingId)
{
    (void)listingId; // not implemented yet
    // Placeholder for auto-match logic
}

}  // namespace DCAddon
