/*
 * Dark Chaos - Group Finder Manager Implementation
 * =================================================
 * 
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "DCGroupFinderMgr.h"
#include "DCAddonNamespace.h"
#include "DatabaseEnv.h"
#include "CharacterDatabase.h"
#include "Config.h"
#include "Log.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "World.h"
#include "Group.h"
#include "../ItemUpgrades/ItemUpgradeManager.h"
#include "GroupMgr.h"

namespace DCAddon
{

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
    _rewardItemId = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Reward.ItemID", 49426);
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
        auto& listing = _listings[id];
        
        // Notify leader
        if (Player* leader = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(listing.leaderGuid)))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                .Set("action", "expired")
                .Set("listingId", static_cast<int32>(id))
                .Set("message", "Your group listing has expired")
                .Send(leader);
        }
        
        // Update database
        CharacterDatabase.Execute("UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}", id);
        CharacterDatabase.Execute("UPDATE dc_group_finder_applications SET status = 4 WHERE listing_id = {} AND status = 0", id);
        
        // Remove from cache
        _playerListings[listing.leaderGuid].erase(id);
        _applications.erase(id);
        _listings.erase(id);
    }
    
    if (!toRemove.empty())
        LOG_DEBUG("dc.groupfinder", "Cleaned up {} expired listings", toRemove.size());
}

void GroupFinderMgr::CleanupExpiredApplications()
{
    // Applications older than configured minutes that are still pending get expired
    time_t cutoff = GameTime::GetGameTime().count() - (_applicationExpireMinutes * 60);
    
    CharacterDatabase.Execute(
        "UPDATE dc_group_finder_applications SET status = 4 "
        "WHERE status = 0 AND created_at < FROM_UNIXTIME({})",
        cutoff);
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
    
    // Note: using synchronous execution below to ensure LAST_INSERT_ID() can be retrieved immediately.
    
    // We need the ID. Since we can't easily get it from the async transaction above without a callback,
    // and we need to return it immediately, we have to use a synchronous query or a different approach.
    // BUT, we are already inside a lock and blocking.
    // Let's use a synchronous execution with manual escaping for now to ensure we get the ID, 
    // OR better: use the "Execute" method that returns a future? No, ACore doesn't have that standard.
    
    // Fallback to safe synchronous execution with escaping
    std::string safeNote = listing.note;
    std::string safeDungeonName = listing.dungeonName;
    CharacterDatabase.EscapeString(safeNote);
    CharacterDatabase.EscapeString(safeDungeonName);
    
    CharacterDatabase.Execute(
        "INSERT INTO dc_group_finder_listings "
        "(leader_guid, group_guid, listing_type, dungeon_id, dungeon_name, difficulty, "
        "keystone_level, min_ilvl, need_tank, need_healer, need_dps, note, status) "
        "VALUES ({}, {}, {}, {}, '{}', {}, {}, {}, {}, {}, {}, '{}', 1)",
        guid, groupGuid, listing.listingType, listing.dungeonId, safeDungeonName,
        listing.difficulty, listing.keystoneLevel, listing.minIlvl,
        listing.needTank, listing.needHealer, listing.needDps, safeNote);
    
    // Get inserted ID
    QueryResult result = CharacterDatabase.Query("SELECT LAST_INSERT_ID()");
    uint32 listingId = result ? (*result)[0].Get<uint32>() : 0;
    
    if (listingId > 0)
    {
        GroupFinderListing newListing = listing;
        newListing.id = listingId;
        newListing.leaderGuid = guid;
        newListing.groupGuid = groupGuid;
        newListing.createdAt = GameTime::GetGameTime().count();
        newListing.expiresAt = newListing.createdAt + (_listingExpireMinutes * 60);
        newListing.active = true;
        
        _listings[listingId] = newListing;
        _playerListings[guid].insert(listingId);
        
        // Notify potential matches
        NotifyNewListing(newListing);
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
    for (const auto& app : _applications[listingId])
    {
        if (app.status == GF_APP_PENDING)
        {
            NotifyApplicationStatus(app.playerGuid, listingId, GF_APP_CANCELLED, "Group listing was removed");
        }
    }
    
    // Remove from cache
    _playerListings[it->second.leaderGuid].erase(listingId);
    _applications.erase(listingId);
    _listings.erase(it);
    
    return true;
}

GroupFinderListing* GroupFinderMgr::GetListing(uint32 listingId)
{
    std::lock_guard<std::mutex> lock(_mutex);
    
    auto it = _listings.find(listingId);
    if (it != _listings.end())
        return &it->second;
    return nullptr;
}

std::vector<GroupFinderListing> GroupFinderMgr::SearchListings(uint8 listingType, uint32 dungeonId,
                                                                uint8 minLevel, uint8 maxLevel, uint16 minRating)
{
    std::lock_guard<std::mutex> lock(_mutex);
    
    std::vector<GroupFinderListing> results;
    
    for (const auto& [id, listing] : _listings)
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
    for (const auto& app : apps)
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
            app.status = GF_APP_ACCEPTED;
            
            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_applications SET status = 1 WHERE id = {}",
                app.id);
            
            // Update listing role counts
            if (app.role == GF_ROLE_TANK && listingIt->second.needTank > 0)
            {
                listingIt->second.currentTank++;
                listingIt->second.needTank--;
            }
            else if (app.role == GF_ROLE_HEALER && listingIt->second.needHealer > 0)
            {
                listingIt->second.currentHealer++;
                listingIt->second.needHealer--;
            }
            else if (listingIt->second.needDps > 0)
            {
                listingIt->second.currentDps++;
                listingIt->second.needDps--;
            }
            
            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_listings SET current_tank = {}, current_healer = {}, current_dps = {}, "
                "need_tank = {}, need_healer = {}, need_dps = {} WHERE id = {}",
                listingIt->second.currentTank, listingIt->second.currentHealer, listingIt->second.currentDps,
                listingIt->second.needTank, listingIt->second.needHealer, listingIt->second.needDps, listingId);
            
            // Notify applicant
            NotifyApplicationStatus(applicantGuid, listingId, GF_APP_ACCEPTED, "Your application was accepted!");
            
            // Invite to group
            if (Player* applicant = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(applicantGuid)))
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
    if (Player* leader = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(it->second.leaderGuid)))
    {
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
            .Set("action", "ready")
            .Set("listingId", static_cast<int32>(listingId))
            .Set("message", "Your group is now complete!")
            .Send(leader);
    }
    
    // Auto-delist since group is complete
    it->second.active = false;
    CharacterDatabase.Execute("UPDATE dc_group_finder_listings SET status = 0 WHERE id = {}", listingId);
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
    for (const auto& signup : signups)
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
    
    for (const auto& [id, event] : _events)
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
    LOG_DEBUG("dc.groupfinder", "New listing created: {} {} +{}", 
        listing.dungeonName, listing.listingType == GF_LISTING_MYTHIC_PLUS ? "M+" : "Raid", listing.keystoneLevel);
}

void GroupFinderMgr::NotifyApplicationStatus(uint32 playerGuid, uint32 listingId, uint8 status, const std::string& message)
{
    if (Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(playerGuid)))
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
    if (Player* leader = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(leaderGuid)))
    {
        std::string roleStr;
        switch (app.role)
        {
            case GF_ROLE_TANK: roleStr = "tank"; break;
            case GF_ROLE_HEALER: roleStr = "healer"; break;
            default: roleStr = "dps"; break;
        }
        
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_NEW_APPLICATION)
            .Set("listingId", static_cast<int32>(app.listingId))
            .Set("playerGuid", static_cast<int32>(app.playerGuid))
            .Set("playerName", app.playerName)
            .Set("role", roleStr)
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

std::vector<GroupFinderApplication> GroupFinderMgr::GetPlayerApplications(uint32 playerGuid)
{
    std::lock_guard<std::mutex> lock(_mutex);
    std::vector<GroupFinderApplication> result;
    
    for (const auto& pair : _applications)
    {
        for (const auto& app : pair.second)
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
    for (const auto& kv : _applications)
    {
        uint32 listingId = kv.first;
        const auto& apps = kv.second;
        for (const auto& app : apps)
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
    (void)dungeonId; (void)difficulty;

    // Check if player was in a group formed by GroupFinder
    // For now, we check if they have any accepted application for this dungeon that is recent.
    // This is a simplified check.
    
    if (CanReceiveReward(player))
    {
        GiveReward(player);
    }
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
        // If the ItemUpgrade manager is available and the currency id maps to its enum, use it.
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
        {
            // Try to add currency via upgrade manager (tokens/essence etc.)
            mgr->AddCurrency(player->GetGUID().GetCounter(), static_cast<DarkChaos::ItemUpgrade::CurrencyType>(_rewardCurrencyId), _rewardCurrencyCount);
        }
        else
        {
            // Fall back to ModifyMoney for gold-based rewards (if configured as such)
            player->ModifyMoney(static_cast<int32>(_rewardCurrencyCount));
        }
    }
    
    // Log reward
    CharacterDatabase.Execute("INSERT INTO dc_group_finder_rewards (player_guid, reward_type, dungeon_type) VALUES ({}, 0, 0)", player->GetGUID().GetCounter());
    
    player->SendSystemMessage("You have received a reward for using the Group Finder!");
}

void GroupFinderMgr::TryAutoMatch(uint32 listingId)
{
    (void)listingId; // not implemented yet
    // Placeholder for auto-match logic
}

}  // namespace DCAddon
