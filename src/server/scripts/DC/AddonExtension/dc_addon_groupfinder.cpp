/*
 * Dark Chaos - Group Finder Addon Module Handler
 * ===============================================
 *
 * Handles DC|GRPF|... messages for Group Finder system.
 * Supports M+ group finding, Raid Finder, and difficulty switching.
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "Common.h"
#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "dc_addon_groupfinder_mgr.h"
#include "Group.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "GameTime.h"
#include "DBCEnums.h"
#include "CharacterCache.h"
#include "dc_addon_groupfinder.h"
#include "../MythicPlus/dc_mythicplus_spectator.h"

#include <mutex>
#include <sstream>
#include <unordered_map>

namespace DCAddon
{
namespace GroupFinder
{
    // ========================================================================
    // PUBLIC API
    // ========================================================================

    void SendOpenGroupFinder(Player* player)
    {
        if (!player)
            return;

        Message(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_OPEN_UI)
            .Send(player);
    }

    // ========================================================================
    // JSON HELPER FUNCTIONS
    // ========================================================================

    // Helper to safely get int from JSON with default value
    inline int32 JsonGetInt(const JsonValue& json, const std::string& key, int32 defaultVal = 0)
    {
        return json[key].IsNumber() ? json[key].AsInt32() : defaultVal;
    }

    // Helper to safely get uint32 from JSON with default value
    inline uint32 JsonGetUInt(const JsonValue& json, const std::string& key, uint32 defaultVal = 0)
    {
        return json[key].IsNumber() ? json[key].AsUInt32() : defaultVal;
    }

    // Helper to safely get string from JSON with default value
    inline std::string JsonGetString(const JsonValue& json, const std::string& key, const std::string& defaultVal = "")
    {
        return json[key].IsString() ? json[key].AsString() : defaultVal;
    }

    // Helper to safely get bool from JSON with default value
    inline bool JsonGetBool(const JsonValue& json, const std::string& key, bool defaultVal = false)
    {
        return json[key].IsBool() ? json[key].AsBool() : defaultVal;
    }

    static std::string CategoryFromListingType(uint8 listingType);
    static std::string DifficultyNameFromListing(uint8 listingType,
        uint8 difficulty);

    namespace
    {
        constexpr uint64 GROUP_FINDER_SEARCH_CACHE_TTL_MS = 1000;

        struct SearchListingsCacheKey
        {
            std::string category;
            uint8 listingType = 0;
            uint32 dungeonId = 0;
            uint8 minLevel = 0;
            uint8 maxLevel = 0;
            uint16 minRating = 0;

            bool operator==(SearchListingsCacheKey const& other) const
            {
                return category == other.category
                    && listingType == other.listingType
                    && dungeonId == other.dungeonId
                    && minLevel == other.minLevel
                    && maxLevel == other.maxLevel
                    && minRating == other.minRating;
            }
        };

        struct SearchListingsCacheKeyHash
        {
            size_t operator()(SearchListingsCacheKey const& key) const
            {
                size_t hash = std::hash<std::string>{}(key.category);
                hash ^= static_cast<size_t>(key.listingType) + 0x9e3779b9u + (hash << 6) + (hash >> 2);
                hash ^= static_cast<size_t>(key.dungeonId) + 0x9e3779b9u + (hash << 6) + (hash >> 2);
                hash ^= static_cast<size_t>(key.minLevel) + 0x9e3779b9u + (hash << 6) + (hash >> 2);
                hash ^= static_cast<size_t>(key.maxLevel) + 0x9e3779b9u + (hash << 6) + (hash >> 2);
                hash ^= static_cast<size_t>(key.minRating) + 0x9e3779b9u + (hash << 6) + (hash >> 2);
                return hash;
            }
        };

        struct CachedSearchListingsPayload
        {
            uint64 expiresAtMs = 0;
            std::string encodedJson;
        };

        std::mutex sSearchListingsCacheMutex;
        std::unordered_map<SearchListingsCacheKey, CachedSearchListingsPayload,
            SearchListingsCacheKeyHash> sSearchListingsPayloads;

        uint64 GetGroupFinderSearchCacheNowMs()
        {
            return GameTime::GetGameTimeMS().count();
        }

        void InvalidateSearchListingsCache()
        {
            std::lock_guard<std::mutex> lock(sSearchListingsCacheMutex);
            sSearchListingsPayloads.clear();
        }

        void SendSpectateListEmpty(Player* player)
        {
            JsonMessage(Module::GROUP_FINDER,
                Opcode::GroupFinder::SMSG_SPECTATE_LIST)
                .Set("runs", "[]")
                .Set("count", 0)
                .Send(player);
        }

        uint32 GetPublicSpectateRunId(DCMythicSpectator::SpectateableRun const& run)
        {
            return run.runId != 0 ? run.runId : run.instanceId;
        }

        std::string FormatSpectateTimer(uint32 seconds)
        {
            uint32 minutes = seconds / 60;
            uint32 remainingSeconds = seconds % 60;

            std::ostringstream ss;
            if (minutes >= 60)
            {
                uint32 hours = minutes / 60;
                minutes %= 60;
                ss << hours << ":";
            }

            ss << std::setw(2) << std::setfill('0') << minutes
                << ":" << std::setw(2) << remainingSeconds;
            return ss.str();
        }

        bool ResolveRuntimeSpectateRun(uint32 publicRunId,
            DCMythicSpectator::SpectateableRun& outRun)
        {
            auto runs = DCMythicSpectator::MythicSpectatorManager::Get().GetSpectateableRuns();
            for (DCMythicSpectator::SpectateableRun const& run : runs)
            {
                uint32 runtimeRunId = GetPublicSpectateRunId(run);
                if (runtimeRunId == publicRunId || run.instanceId == publicRunId)
                {
                    outRun = run;
                    return true;
                }
            }

            return false;
        }

        std::string BuildSearchListingsJson(
            std::string const& category,
            uint8 listingType,
            std::vector<GroupFinderListing> const& results)
        {
            JsonValue groupsArray;
            groupsArray.SetArray();

            for (GroupFinderListing const& listing : results)
            {
                JsonValue group;
                group.SetObject();

                std::string leaderName = "Unknown";
                sCharacterCache->GetCharacterNameByGuid(
                    ObjectGuid::Create<HighGuid::Player>(listing.leaderGuid),
                    leaderName);

                std::string listingCategory = !category.empty()
                    ? category
                    : CategoryFromListingType(listing.listingType);

                group.Set("id", JsonValue(static_cast<int32>(listing.id)));
                group.Set("leaderGuid", JsonValue(static_cast<int32>(listing.leaderGuid)));
                group.Set("dungeonId", JsonValue(static_cast<int32>(listing.dungeonId)));
                group.Set("dungeon", JsonValue(listing.dungeonName));
                group.Set("dungeonName", JsonValue(listing.dungeonName));
                group.Set("raid", JsonValue(listing.dungeonName));
                group.Set("difficulty", JsonValue(static_cast<int32>(listing.difficulty)));
                group.Set("difficultyName", JsonValue(DifficultyNameFromListing(
                    listing.listingType, listing.difficulty)));
                group.Set("level", JsonValue(static_cast<int32>(listing.keystoneLevel)));
                group.Set("keystoneLevel", JsonValue(static_cast<int32>(listing.keystoneLevel)));
                group.Set("minIlvl", JsonValue(static_cast<int32>(listing.minIlvl)));
                group.Set("tank", JsonValue(listing.currentTank > 0));
                group.Set("healer", JsonValue(listing.currentHealer > 0));
                group.Set("dps", JsonValue(static_cast<int32>(listing.currentDps)));
                group.Set("needTank", JsonValue(static_cast<int32>(listing.needTank)));
                group.Set("needHealer", JsonValue(static_cast<int32>(listing.needHealer)));
                group.Set("needDps", JsonValue(static_cast<int32>(listing.needDps)));
                group.Set("spots", JsonValue(static_cast<int32>(
                    listing.needTank + listing.needHealer + listing.needDps)));
                group.Set("note", JsonValue(listing.note));
                group.Set("progress", JsonValue(listing.note));
                group.Set("type", JsonValue(static_cast<int32>(listing.listingType)));
                group.Set("category", JsonValue(listingCategory));
                group.Set("leader", JsonValue(leaderName));
                groupsArray.Push(group);
            }

            JsonValue payload;
            payload.SetObject();
            payload.Set("groups", JsonValue(groupsArray.Encode()));
            payload.Set("count", JsonValue(static_cast<int32>(groupsArray.Size())));

            if (!category.empty())
                payload.Set("category", JsonValue(category));
            else if (listingType > 0)
                payload.Set("category", JsonValue(CategoryFromListingType(listingType)));

            return payload.Encode();
        }

        std::string GetCachedSearchListingsJson(
            SearchListingsCacheKey const& cacheKey,
            std::vector<GroupFinderListing> const& results)
        {
            uint64 const nowMs = GetGroupFinderSearchCacheNowMs();

            {
                std::lock_guard<std::mutex> lock(sSearchListingsCacheMutex);
                auto itr = sSearchListingsPayloads.find(cacheKey);
                if (itr != sSearchListingsPayloads.end()
                    && itr->second.expiresAtMs > nowMs)
                {
                    return itr->second.encodedJson;
                }
            }

            CachedSearchListingsPayload cacheEntry;
            cacheEntry.encodedJson = BuildSearchListingsJson(
                cacheKey.category, cacheKey.listingType, results);
            cacheEntry.expiresAtMs = nowMs + GROUP_FINDER_SEARCH_CACHE_TTL_MS;

            std::lock_guard<std::mutex> lock(sSearchListingsCacheMutex);
            sSearchListingsPayloads[cacheKey] = cacheEntry;
            return cacheEntry.encodedJson;
        }
    }

    // ========================================================================
    // CONFIGURATION
    // ========================================================================

    static uint32 s_MaxListingsPerPlayer = 3;
    static uint32 s_ListingExpireMinutes = 120;
    static uint32 s_MaxApplicationsPerPlayer = 10;

    static void LoadConfig()
    {
        s_MaxListingsPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.MaxListingsPerPlayer", 3);
        s_ListingExpireMinutes = sConfigMgr->GetOption<uint32>("DC.GroupFinder.ListingExpireMinutes", 120);
        s_MaxApplicationsPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.MaxApplicationsPerPlayer", 10);
    }

    // ========================================================================
    // LISTING TYPES
    // ========================================================================

    enum ListingType : uint8
    {
        LISTING_MYTHIC_PLUS = 1,
        LISTING_RAID        = 2,
        LISTING_PVP         = 3,
        LISTING_OTHER       = 4,
        LISTING_QUEST       = 5
    };

    enum ApplicationStatus : uint8
    {
        APP_STATUS_PENDING  = 0,
        APP_STATUS_ACCEPTED = 1,
        APP_STATUS_DECLINED = 2,
        APP_STATUS_CANCELLED = 3
    };

    static uint8 ListingTypeFromCategory(std::string const& category)
    {
        if (category == "dungeon" || category == "mythic" ||
            category == "mythic+")
            return LISTING_MYTHIC_PLUS;

        if (category == "raid")
            return LISTING_RAID;

        if (category == "pvp")
            return LISTING_PVP;

        if (category == "quest")
            return LISTING_QUEST;

        if (category == "other" || category == "world")
            return LISTING_OTHER;

        return 0;
    }

    static std::string CategoryFromListingType(uint8 listingType)
    {
        switch (listingType)
        {
            case LISTING_MYTHIC_PLUS:
                return "dungeon";
            case LISTING_RAID:
                return "raid";
            case LISTING_PVP:
                return "pvp";
            case LISTING_QUEST:
                return "quest";
            case LISTING_OTHER:
                return "other";
            default:
                return "other";
        }
    }

    static std::string DifficultyNameFromListing(uint8 listingType,
        uint8 difficulty)
    {
        if (listingType == LISTING_RAID)
        {
            switch (difficulty)
            {
                case RAID_DIFFICULTY_10MAN_NORMAL:
                    return "10 Normal";
                case RAID_DIFFICULTY_25MAN_NORMAL:
                    return "25 Normal";
                case RAID_DIFFICULTY_10MAN_HEROIC:
                    return "10 Heroic";
                case RAID_DIFFICULTY_25MAN_HEROIC:
                    return "25 Heroic";
                default:
                    return "Raid";
            }
        }

        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                return "Heroic";
            case DUNGEON_DIFFICULTY_EPIC:
                return "Mythic";
            default:
                return "Normal";
        }
    }

    // ========================================================================
    // HANDLERS: LISTING MANAGEMENT
    // ========================================================================

    // Create a new group listing
    static void HandleCreateListing(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        // Player GUID used to check limits, ownership and DB queries
        uint32 guid = player->GetGUID().GetCounter();

        // Check if player already has max listings
        QueryResult countResult = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_group_finder_listings WHERE leader_guid = {} AND status = 1",
            guid);

        if (countResult)
        {
            uint32 count = (*countResult)[0].Get<uint32>();
            if (count >= s_MaxListingsPerPlayer)
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Maximum listings reached")
                    .Set("max", static_cast<int32>(s_MaxListingsPerPlayer))
                    .Send(player);
                return;
            }
        }

        std::string category = JsonGetString(json, "category", "");
        // Extract listing data
        uint8 listingType = static_cast<uint8>(JsonGetInt(json, "listingType", 0));
        if (!category.empty())
        {
            if (uint8 categoryType = ListingTypeFromCategory(category))
                listingType = categoryType;
        }

        if (listingType == 0)
            listingType = LISTING_MYTHIC_PLUS;

        uint32 dungeonId = static_cast<uint32>(JsonGetInt(json, "dungeonId", 0));
        std::string dungeonName = JsonGetString(json, "dungeonName", "Unknown");
        uint8 keystoneLevel = static_cast<uint8>(JsonGetInt(json, "keyLevel", 0));
        uint16 minIlvl = static_cast<uint16>(JsonGetInt(json, "minIlvl", 0));
        uint8 needTank = static_cast<uint8>(JsonGetInt(json, "needTank", 1));
        uint8 needHealer = static_cast<uint8>(JsonGetInt(json, "needHealer", 1));
        uint8 needDps = static_cast<uint8>(JsonGetInt(json, "needDps", 3));
        std::string note = JsonGetString(json, "note", "");
        int32 difficultyId = JsonGetInt(json, "difficultyId", -1);
        if (difficultyId < 0 && json["difficulty"].IsNumber())
            difficultyId = json["difficulty"].AsInt32();

        if (difficultyId < 0)
        {
            difficultyId = listingType == LISTING_RAID
                ? static_cast<int32>(player->GetRaidDifficulty())
                : static_cast<int32>(player->GetDungeonDifficulty());
        }

        // Get group GUID if in a group
        uint32 groupGuid = 0;
        if (Group* group = player->GetGroup())
            groupGuid = group->GetGUID().GetCounter();

        // Create listing object
        DCAddon::GroupFinderListing listing;
        listing.listingType = listingType;
        listing.dungeonId = dungeonId;
        listing.dungeonName = dungeonName;
        listing.difficulty = static_cast<uint8>(difficultyId);
        listing.keystoneLevel = keystoneLevel;
        listing.minIlvl = minIlvl;
        listing.needTank = needTank;
        listing.needHealer = needHealer;
        listing.needDps = needDps;
        listing.note = note;
        listing.groupGuid = groupGuid;

        // Create listing via manager (handles DB and cache)
        uint32 listingId = sGroupFinderMgr.CreateListing(player, listing);

        if (listingId > 0)
        {
            InvalidateSearchListingsCache();

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_LISTING_CREATED)
                .Set("success", true)
                .Set("listingId", static_cast<int32>(listingId))
                .Send(player);

            LOG_DEBUG("dc.groupfinder", "Player {} created listing #{}", player->GetName(), listingId);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to create listing")
                .Send(player);
        }
    }

    // Search for available listings
    static void HandleSearchListings(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        // Optional filters
        std::string category = JsonGetString(json, "category", "");
        int32 listingType = JsonGetInt(json, "listingType", 0);  // 0 = all
        int32 dungeonId = JsonGetInt(json, "dungeonId", 0);      // 0 = all
        int32 minLevel = JsonGetInt(json, "minLevel", 0);
        int32 maxLevel = JsonGetInt(json, "maxLevel", 0);
        int32 minRating = JsonGetInt(json, "minRating", 0);

        if (listingType <= 0 && !category.empty())
            listingType = ListingTypeFromCategory(category);

        SearchListingsCacheKey cacheKey;
        cacheKey.category = category;
        cacheKey.listingType = static_cast<uint8>(listingType > 0 ? listingType : 0);
        cacheKey.dungeonId = static_cast<uint32>(dungeonId > 0 ? dungeonId : 0);
        cacheKey.minLevel = static_cast<uint8>(minLevel > 0 ? minLevel : 0);
        cacheKey.maxLevel = static_cast<uint8>(maxLevel > 0 ? maxLevel : 0);
        cacheKey.minRating = static_cast<uint16>(minRating > 0 ? minRating : 0);

        auto results = sGroupFinderMgr.SearchListings(
            cacheKey.listingType,
            cacheKey.dungeonId,
            cacheKey.minLevel,
            cacheKey.maxLevel,
            cacheKey.minRating);

        JsonMessage jsonMsg(Module::GROUP_FINDER,
            Opcode::GroupFinder::SMSG_SEARCH_RESULTS);
        jsonMsg.SetPreEncodedJson(GetCachedSearchListingsJson(cacheKey, results));
        jsonMsg.Send(player);
    }

    // Apply to join a group
    static void HandleApplyToGroup(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        int32 listingId = JsonGetInt(json, "listingId", 0);
        // Support both string (legacy) and int (mask) for role
        uint8 roleMask = 4; // Default DPS

        if (json["role"].IsString())
        {
            std::string roleStr = json["role"].AsString();
            if (roleStr == "tank") roleMask = 1;
            else if (roleStr == "healer") roleMask = 2;
        }
        else if (json["role"].IsNumber())
        {
            roleMask = static_cast<uint8>(json["role"].AsInt32());
        }

        std::string message = JsonGetString(json, "message", "");

        if (listingId <= 0)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid listing ID")
                .Send(player);
            return;
        }

        // Validate role against class
        uint8 classId = player->getClass();
        bool roleValid = true;

        // Check Tank role
        if (roleMask & 1) // GF_ROLE_TANK
        {
            if (classId != CLASS_WARRIOR && classId != CLASS_PALADIN &&
                classId != CLASS_DEATH_KNIGHT && classId != CLASS_DRUID)
                roleValid = false;
        }

        // Check Healer role
        if (roleMask & 2) // GF_ROLE_HEALER
        {
            if (classId != CLASS_PALADIN && classId != CLASS_PRIEST &&
                classId != CLASS_SHAMAN && classId != CLASS_DRUID)
                roleValid = false;
        }

        // Check DPS role (everyone can DPS)
        if (roleMask & 4) // GF_ROLE_DPS
        {
            // All classes can DPS
        }

        if (!roleValid)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid role selection for your class")
                .Send(player);
            return;
        }

        if (sGroupFinderMgr.ApplyToListing(player, listingId, roleMask, message))
        {
            InvalidateSearchListingsCache();

            uint8 applicationStatus = GF_APP_PENDING;
            QueryResult appResult = CharacterDatabase.Query(
                "SELECT status FROM dc_group_finder_applications "
                "WHERE listing_id = {} AND player_guid = {} "
                "ORDER BY id DESC LIMIT 1",
                listingId, player->GetGUID().GetCounter());

            if (appResult)
                applicationStatus = (*appResult)[0].Get<uint8>();

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_APPLICATION_STATUS)
                .Set("success", true)
                .Set("status", applicationStatus == GF_APP_ACCEPTED ? "accepted" : "pending")
                .Set("message", applicationStatus == GF_APP_ACCEPTED
                    ? "Application accepted"
                    : "Application submitted")
                .Send(player);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_APPLICATION_STATUS)
                .Set("success", false)
                .Set("status", "failed")
                .Set("message", "Failed to apply (already applied, requirements not met, or listing expired)")
                .Send(player);
        }
    }

    static void HandleGetMyApplications(Player* player, const ParsedMessage& /*msg*/)
    {
        auto apps = sGroupFinderMgr.GetPlayerApplications(player->GetGUID().GetCounter());

        JsonValue appsArray;
        appsArray.SetArray();

        for (auto const& app : apps)
        {
            JsonValue appObj;
            appObj.SetObject();
            appObj.Set("id", JsonValue(static_cast<int32>(app.id)));
            appObj.Set("listingId", JsonValue(static_cast<int32>(app.listingId)));
            appObj.Set("role", JsonValue(static_cast<int32>(app.role)));
            appObj.Set("status", JsonValue(static_cast<int32>(app.status)));
            appObj.Set("note", JsonValue(app.note));

            // Get listing details for context
            if (auto listingOpt = sGroupFinderMgr.GetListing(app.listingId))
            {
                std::string leaderName = "Unknown";
                sCharacterCache->GetCharacterNameByGuid(
                    ObjectGuid::Create<HighGuid::Player>(listingOpt->leaderGuid),
                    leaderName);

                appObj.Set("dungeonName", JsonValue(listingOpt->dungeonName));
                appObj.Set("dungeon", JsonValue(listingOpt->dungeonName));
                appObj.Set("dungeonId", JsonValue(static_cast<int32>(listingOpt->dungeonId)));
                appObj.Set("keystoneLevel", JsonValue(static_cast<int32>(listingOpt->keystoneLevel)));
                appObj.Set("difficulty", JsonValue(static_cast<int32>(listingOpt->difficulty)));
                appObj.Set("difficultyName", JsonValue(DifficultyNameFromListing(
                    listingOpt->listingType, listingOpt->difficulty)));
                appObj.Set("listingType", JsonValue(static_cast<int32>(listingOpt->listingType)));
                appObj.Set("category", JsonValue(CategoryFromListingType(
                    listingOpt->listingType)));
                appObj.Set("leader", JsonValue(leaderName));
            }

            appsArray.Push(appObj);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_MY_APPLICATIONS)
            .Set("applications", appsArray.Encode())
            .Send(player);
    }

    // Accept an application (leader only)
    static void HandleAcceptApplication(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        uint32 listingId = JsonGetUInt(json, "listingId", 0);
        uint32 applicationId = JsonGetUInt(json, "applicationId", 0);
        uint32 applicantGuid = static_cast<uint32>(JsonGetInt(json, "applicantGuid", 0));

        if (listingId == 0 && applicationId > 0)
            listingId = sGroupFinderMgr.FindListingIdForApplication(applicationId);

        // Use manager to accept application (handles DB, cache, and notifications)
        if (listingId != 0 && sGroupFinderMgr.AcceptApplication(player, listingId, applicantGuid))
        {
            InvalidateSearchListingsCache();

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                .Set("action", "accepted")
                .Set("playerGuid", static_cast<int32>(applicantGuid))
                .Send(player);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to accept application (not found or not leader)")
                .Send(player);
        }
    }

    // Decline an application (leader only)
    static void HandleDeclineApplication(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        uint32 listingId = JsonGetUInt(json, "listingId", 0);
        uint32 applicationId = JsonGetUInt(json, "applicationId", 0);
        uint32 applicantGuid = static_cast<uint32>(JsonGetInt(json, "applicantGuid", 0));

        // Use manager to decline application
        if (listingId == 0 && applicationId > 0)
            listingId = sGroupFinderMgr.FindListingIdForApplication(applicationId);

        if (listingId != 0 && sGroupFinderMgr.DeclineApplication(player, listingId, applicantGuid))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                .Set("action", "declined")
                .Set("playerGuid", static_cast<int32>(applicantGuid))
                .Send(player);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to decline application")
                .Send(player);
        }
    }

    static void HandleCancelApplication(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);
        uint32 listingId = JsonGetUInt(json, "listingId", 0);

        if (listingId == 0)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid listing ID")
                .Send(player);
            return;
        }

        if (sGroupFinderMgr.CancelApplication(player, listingId))
        {
            JsonMessage(Module::GROUP_FINDER,
                Opcode::GroupFinder::SMSG_APPLICATION_STATUS)
                .Set("success", true)
                .Set("status", "cancelled")
                .Set("listingId", static_cast<int32>(listingId))
                .Set("message", "Application withdrawn")
                .Send(player);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to withdraw application")
                .Send(player);
        }
    }

    // Remove a listing
    static void HandleDelistGroup(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        int32 listingId = JsonGetInt(json, "listingId", 0);

        // Use manager to delete listing
        if (sGroupFinderMgr.DeleteListing(player, listingId))
        {
            InvalidateSearchListingsCache();

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_GROUP_UPDATED)
                .Set("action", "delisted")
                .Set("listingId", listingId)
                .Send(player);
        }
        else
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to delist group (not found or not leader)")
                .Send(player);
        }
    }

    // ========================================================================
    // HANDLERS: KEYSTONE & DIFFICULTY
    // ========================================================================

    // Get player's keystone and difficulty info
    static void HandleGetMyKeystone(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 guid = player->GetGUID().GetCounter();

        // Get keystone info
        QueryResult keyResult = CharacterDatabase.Query(
            "SELECT k.map_id, k.level, d.dungeon_name "
            "FROM dc_mplus_keystones k "
            "LEFT JOIN dc_mplus_dungeons d ON k.map_id = d.map_id "
            "WHERE k.character_guid = {}",
            guid);

        // Get current difficulty
        uint8 dungeonDiff = player->GetDungeonDifficulty();
        uint8 raidDiff = player->GetRaidDifficulty();

        std::string dungeonDiffName = "Normal";
        if (dungeonDiff == DUNGEON_DIFFICULTY_HEROIC) dungeonDiffName = "Heroic";
        else if (dungeonDiff == DUNGEON_DIFFICULTY_EPIC) dungeonDiffName = "Mythic";

        std::string raidDiffName = "10-man Normal";
        switch (raidDiff)
        {
            case RAID_DIFFICULTY_10MAN_NORMAL: raidDiffName = "10-man Normal"; break;
            case RAID_DIFFICULTY_25MAN_NORMAL: raidDiffName = "25-man Normal"; break;
            case RAID_DIFFICULTY_10MAN_HEROIC: raidDiffName = "10-man Heroic"; break;
            case RAID_DIFFICULTY_25MAN_HEROIC: raidDiffName = "25-man Heroic"; break;
        }

        JsonMessage json(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_KEYSTONE_INFO);
        json.Set("dungeonDifficulty", static_cast<int32>(dungeonDiff));
        json.Set("dungeonDifficultyName", dungeonDiffName);
        json.Set("raidDifficulty", static_cast<int32>(raidDiff));
        json.Set("raidDifficultyName", raidDiffName);

        if (keyResult)
        {
            json.Set("hasKeystone", true);
            json.Set("keystoneDungeonId", (*keyResult)[0].Get<int32>());
            json.Set("keystoneLevel", (*keyResult)[1].Get<int32>());
            json.Set("keystoneDungeonName", (*keyResult)[2].Get<std::string>());
        }
        else
        {
            json.Set("hasKeystone", false);
        }

        json.Send(player);
    }

    // Set dungeon/raid difficulty
    static void HandleSetDifficulty(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        std::string diffType = JsonGetString(json, "type", "dungeon");
        std::string diffValue = JsonGetString(json, "difficulty", "normal");

        // Check if player is in a group and is the leader
        Group* group = player->GetGroup();
        if (group && !group->IsLeader(player->GetGUID()))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Only the group leader can change difficulty")
                .Send(player);
            return;
        }

        uint8 difficulty = 0;
        std::string diffName;

        if (diffType == "dungeon")
        {
            if (diffValue == "normal")
            {
                difficulty = DUNGEON_DIFFICULTY_NORMAL;
                diffName = "Normal";
            }
            else if (diffValue == "heroic")
            {
                difficulty = DUNGEON_DIFFICULTY_HEROIC;
                diffName = "Heroic";
            }
            else if (diffValue == "mythic")
            {
                difficulty = DUNGEON_DIFFICULTY_EPIC;
                diffName = "Mythic";
            }
            else
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Unknown dungeon difficulty")
                    .Send(player);
                player->SendDungeonDifficulty(group != nullptr);
                return;
            }

            if (group)
            {
                for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
                {
                    Player* member = itr->GetSource();
                    if (!member || !member->IsInWorld())
                    {
                        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                            .Set("error", "All group members must be online to change difficulty")
                            .Send(player);
                        player->SendDungeonDifficulty(true);
                        return;
                    }

                    if (member->GetGUID() == player->GetGUID() ? member->GetMap()->IsDungeon() : member->GetMap()->IsNonRaidDungeon())
                    {
                        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                            .Set("error", "Leave the current dungeon before changing difficulty")
                            .Send(player);
                        player->SendDungeonDifficulty(true);
                        return;
                    }
                }

                group->ResetInstances(INSTANCE_RESET_CHANGE_DIFFICULTY, false, player);
                group->SetDungeonDifficulty(Difficulty(difficulty));
            }
            else
            {
                if (Map* map = player->FindMap())
                {
                    if (map->IsDungeon())
                    {
                        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                            .Set("error", "Leave the current dungeon before changing difficulty")
                            .Send(player);
                        player->SendDungeonDifficulty(false);
                        return;
                    }
                }

                Player::ResetInstances(player->GetGUID(), INSTANCE_RESET_CHANGE_DIFFICULTY, false);
                player->SetDungeonDifficulty(Difficulty(difficulty));
            }

            player->SendDungeonDifficulty(group != nullptr);
        }
        else if (diffType == "raid")
        {
            if (diffValue == "10n")
            {
                difficulty = RAID_DIFFICULTY_10MAN_NORMAL;
                diffName = "10-man Normal";
            }
            else if (diffValue == "25n")
            {
                difficulty = RAID_DIFFICULTY_25MAN_NORMAL;
                diffName = "25-man Normal";
            }
            else if (diffValue == "10h")
            {
                difficulty = RAID_DIFFICULTY_10MAN_HEROIC;
                diffName = "10-man Heroic";
            }
            else if (diffValue == "25h")
            {
                difficulty = RAID_DIFFICULTY_25MAN_HEROIC;
                diffName = "25-man Heroic";
            }
            else
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Unknown raid difficulty")
                    .Send(player);
                player->SendRaidDifficulty(group != nullptr);
                return;
            }

            if (group)
                group->SetRaidDifficulty(Difficulty(difficulty));
            else
                player->SetRaidDifficulty(Difficulty(difficulty));

            player->SendRaidDifficulty(group != nullptr);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_DIFFICULTY_CHANGED)
            .Set("type", diffType)
            .Set("difficultyId", static_cast<int32>(difficulty))
            .Set("difficultyName", diffName)
            .Send(player);

        ChatHandler(player->GetSession()).PSendSysMessage("{} difficulty set to {}.",
            diffType == "dungeon" ? "Dungeon" : "Raid", diffName.c_str());
    }

    // ========================================================================
    // HANDLERS: SPECTATING
    // ========================================================================

    // Get list of spectatable runs
    static void HandleGetSpectateList(Player* player, const ParsedMessage& /*msg*/)
    {
        auto& spectatorMgr = DCMythicSpectator::MythicSpectatorManager::Get();
        if (!spectatorMgr.GetConfig().enabled)
        {
            SendSpectateListEmpty(player);
            return;
        }
        std::vector<DCMythicSpectator::SpectateableRun> runs = spectatorMgr.GetSpectateableRuns();

        JsonValue runsArray;
        runsArray.SetArray();

        uint32 count = 0;
        for (DCMythicSpectator::SpectateableRun const& liveRun : runs)
        {
            if (count >= 20)
                break;

            uint32 publicRunId = GetPublicSpectateRunId(liveRun);
            if (publicRunId == 0)
                continue;

            JsonValue run;
            run.SetObject();
            run.Set("runId", JsonValue(static_cast<int32>(publicRunId)));
            run.Set("instanceId", JsonValue(static_cast<int32>(liveRun.instanceId)));
            run.Set("mapId", JsonValue(static_cast<int32>(liveRun.mapId)));
            run.Set("keyLevel", JsonValue(static_cast<int32>(liveRun.keystoneLevel)));
            run.Set("level", JsonValue(static_cast<int32>(liveRun.keystoneLevel)));
            run.Set("startTime", JsonValue(static_cast<int32>(liveRun.startedAt)));
            run.Set("dungeonName", JsonValue(liveRun.dungeonName.empty()
                ? std::string("Unknown Dungeon")
                : liveRun.dungeonName));
            run.Set("dungeon", JsonValue(liveRun.dungeonName.empty()
                ? std::string("Unknown Dungeon")
                : liveRun.dungeonName));
            run.Set("leaderName", JsonValue(liveRun.leaderName.empty()
                ? std::string("Unknown")
                : liveRun.leaderName));
            run.Set("leader", JsonValue(liveRun.leaderName.empty()
                ? std::string("Unknown")
                : liveRun.leaderName));
            run.Set("timerRemaining", JsonValue(static_cast<int32>(liveRun.timerRemaining)));
            run.Set("timer", JsonValue(FormatSpectateTimer(liveRun.timerRemaining)));
            run.Set("bossesKilled", JsonValue(static_cast<int32>(liveRun.bossesKilled)));
            run.Set("bossesTotal", JsonValue(static_cast<int32>(liveRun.bossesTotal)));
            run.Set("progress", JsonValue(Acore::StringFormat("{}/{} bosses",
                static_cast<uint32>(liveRun.bossesKilled),
                static_cast<uint32>(liveRun.bossesTotal))));
            run.Set("deaths", JsonValue(static_cast<int32>(liveRun.deaths)));
            run.Set("spectators", JsonValue(static_cast<int32>(liveRun.spectators.size())));
            run.Set("maxSpectators", JsonValue(static_cast<int32>(spectatorMgr.GetConfig().maxSpectatorsPerRun)));
            runsArray.Push(run);
            ++count;
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SPECTATE_LIST)
            .Set("runs", runsArray.Encode())
            .Set("count", static_cast<int32>(runsArray.Size()))
            .Send(player);
    }

    // ========================================================================
    // HANDLERS: SCHEDULED EVENTS
    // ========================================================================

    // Create a new scheduled event
    static void HandleCreateEvent(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        uint32 guid = player->GetGUID().GetCounter();

        // Check if player already has max scheduled events
        QueryResult countResult = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_group_finder_scheduled_events WHERE leader_guid = {} AND status IN (1, 2)",
            guid);

        if (countResult)
        {
            uint32 count = (*countResult)[0].Get<uint32>();
            if (count >= 5) // Max 5 active events per player
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Maximum scheduled events reached")
                    .Set("max", 5)
                    .Send(player);
                return;
            }
        }

        // Extract event data
        uint8 eventType = static_cast<uint8>(JsonGetInt(json, "eventType", LISTING_MYTHIC_PLUS));
        uint32 dungeonId = static_cast<uint32>(JsonGetInt(json, "dungeonId", 0));
        std::string dungeonName = JsonGetString(json, "dungeonName", "Unknown");
        uint8 keystoneLevel = static_cast<uint8>(JsonGetInt(json, "keyLevel", 0));
        uint32 scheduledTime = static_cast<uint32>(JsonGetInt(json, "scheduledTime", 0));
        uint8 maxSignups = static_cast<uint8>(JsonGetInt(json, "maxSignups", 5));
        std::string note = JsonGetString(json, "note", "");

        // Validate scheduled time (must be in the future)
        time_t now = GameTime::GetGameTime().count();
        if (scheduledTime <= now)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Scheduled time must be in the future")
                .Send(player);
            return;
        }

        // Escape user-provided strings to prevent SQL injection
        std::string safeDungeonName = dungeonName;
        std::string safeNote = note;
        CharacterDatabase.EscapeString(safeDungeonName);
        CharacterDatabase.EscapeString(safeNote);

        // Insert the event
        CharacterDatabase.Execute(
            "INSERT INTO dc_group_finder_scheduled_events "
            "(leader_guid, event_type, dungeon_id, dungeon_name, keystone_level, scheduled_time, max_signups, note, status) "
            "VALUES ({}, {}, {}, '{}', {}, FROM_UNIXTIME({}), {}, '{}', 1)",
            guid, eventType, dungeonId, safeDungeonName, keystoneLevel, scheduledTime, maxSignups, safeNote);

        // Get the event ID
        QueryResult idResult = CharacterDatabase.Query("SELECT LAST_INSERT_ID()");
        uint32 eventId = idResult ? (*idResult)[0].Get<uint32>() : 0;

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_EVENT_CREATED)
            .Set("success", eventId > 0)
            .Set("eventId", static_cast<int32>(eventId))
            .Set("message", eventId > 0 ? "Event created successfully" : "Failed to create event")
            .Send(player);
    }

    // Sign up for a scheduled event
    static void HandleSignupEvent(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        uint32 eventId = static_cast<uint32>(JsonGetInt(json, "eventId", 0));
        uint8 role = static_cast<uint8>(JsonGetInt(json, "role", 0));
        std::string note = JsonGetString(json, "note", "");
        uint32 guid = player->GetGUID().GetCounter();

        // Check if event exists and is open
        QueryResult eventResult = CharacterDatabase.Query(
            "SELECT leader_guid, max_signups, current_signups, status FROM dc_group_finder_scheduled_events WHERE id = {}",
            eventId);

        if (!eventResult)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Event not found")
                .Send(player);
            return;
        }

        uint32 leaderGuid = (*eventResult)[0].Get<uint32>();
        uint8 maxSignups = (*eventResult)[1].Get<uint8>();
        uint8 currentSignups = (*eventResult)[2].Get<uint8>();
        uint8 status = (*eventResult)[3].Get<uint8>();

        // Can't signup for own event
        if (leaderGuid == guid)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Cannot sign up for your own event")
                .Send(player);
            return;
        }

        // Check if event is still open
        if (status != 1) // 1 = open
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Event is no longer accepting signups")
                .Send(player);
            return;
        }

        // Check if full
        if (currentSignups >= maxSignups)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Event is full")
                .Send(player);
            return;
        }

        // Check if already signed up
        QueryResult signupCheck = CharacterDatabase.Query(
            "SELECT id FROM dc_group_finder_event_signups WHERE event_id = {} AND player_guid = {} AND status IN (0, 1)",
            eventId, guid);

        if (signupCheck)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Already signed up for this event")
                .Send(player);
            return;
        }

        // Escape user-provided note to prevent SQL injection
        std::string safeNote = note;
        CharacterDatabase.EscapeString(safeNote);

        // Insert signup
        CharacterDatabase.Execute(
            "INSERT INTO dc_group_finder_event_signups (event_id, player_guid, player_name, role, note, status) "
            "VALUES ({}, {}, '{}', {}, '{}', 0)",
            eventId, guid, player->GetName(), role, safeNote);

        // Update current signups count
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET current_signups = current_signups + 1 WHERE id = {}",
            eventId);

        // Check if event is now full
        if (currentSignups + 1 >= maxSignups)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_group_finder_scheduled_events SET status = 2 WHERE id = {}",
                eventId);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_EVENT_SIGNUP_RESULT)
            .Set("success", true)
            .Set("eventId", static_cast<int32>(eventId))
            .Set("message", "Successfully signed up for event")
            .Send(player);
    }

    // Cancel signup for a scheduled event
    static void HandleCancelSignup(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        uint32 eventId = static_cast<uint32>(JsonGetInt(json, "eventId", 0));
        uint32 guid = player->GetGUID().GetCounter();

        // Check if signed up
        QueryResult signupResult = CharacterDatabase.Query(
            "SELECT id FROM dc_group_finder_event_signups WHERE event_id = {} AND player_guid = {} AND status = 0",
            eventId, guid);

        if (!signupResult)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Not signed up for this event")
                .Send(player);
            return;
        }

        uint32 signupId = (*signupResult)[0].Get<uint32>();

        // Cancel signup
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_event_signups SET status = 3 WHERE id = {}",
            signupId);

        // Decrement signup count
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET current_signups = current_signups - 1 WHERE id = {}",
            eventId);

        // Re-open event if it was full
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET status = 1 WHERE id = {} AND status = 2",
            eventId);

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_EVENT_SIGNUP_RESULT)
            .Set("success", true)
            .Set("eventId", static_cast<int32>(eventId))
            .Set("cancelled", true)
            .Set("message", "Signup cancelled successfully")
            .Send(player);
    }

    // Get upcoming scheduled events
    static void HandleGetScheduledEvents(Player* player, const ParsedMessage& msg)
    {
        uint8 eventType = 0;
        if (IsJsonMessage(msg))
        {
            eventType = static_cast<uint8>(JsonGetInt(GetJsonData(msg), "eventType", 0));
        }

        auto events = sGroupFinderMgr.GetUpcomingEvents(eventType);

        JsonValue eventsArray;
        eventsArray.SetArray();
        size_t eventCount = 0;

        for (ScheduledEvent const& scheduledEvent : events)
        {
            if (eventCount >= 50)
                break;

            std::string leaderName = "Unknown";
            sCharacterCache->GetCharacterNameByGuid(
                ObjectGuid::Create<HighGuid::Player>(scheduledEvent.leaderGuid),
                leaderName);

            JsonValue event;
            event.SetObject();
            event.Set("eventId", JsonValue(static_cast<int32>(scheduledEvent.id)));
            event.Set("leaderGuid", JsonValue(static_cast<int32>(scheduledEvent.leaderGuid)));
            event.Set("eventType", JsonValue(static_cast<int32>(scheduledEvent.eventType)));
            event.Set("dungeonId", JsonValue(static_cast<int32>(scheduledEvent.dungeonId)));
            event.Set("dungeonName", JsonValue(scheduledEvent.title));
            event.Set("keyLevel", JsonValue(static_cast<int32>(scheduledEvent.keystoneLevel)));
            event.Set("scheduledTime", JsonValue(static_cast<int32>(scheduledEvent.scheduledTime)));
            event.Set("maxSignups", JsonValue(static_cast<int32>(scheduledEvent.maxSignups)));
            event.Set("currentSignups", JsonValue(static_cast<int32>(scheduledEvent.currentSignups)));
            event.Set("note", JsonValue(scheduledEvent.description));
            event.Set("status", JsonValue(static_cast<int32>(scheduledEvent.status)));
            event.Set("leaderName", JsonValue(leaderName));
            eventsArray.Push(event);
            ++eventCount;
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SCHEDULED_EVENTS)
            .Set("events", eventsArray.Encode())
            .Set("count", static_cast<int32>(eventsArray.Size()))
            .Send(player);
    }

    // Get my signups
    static void HandleGetMySignups(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 guid = player->GetGUID().GetCounter();
        auto signups = sGroupFinderMgr.GetPlayerEventSignups(guid);

        JsonValue signupsArray;
        signupsArray.SetArray();

        for (PlayerEventSignup const& playerSignup : signups)
        {
            std::string leaderName = "Unknown";
            sCharacterCache->GetCharacterNameByGuid(
                ObjectGuid::Create<HighGuid::Player>(playerSignup.event.leaderGuid),
                leaderName);

            JsonValue signup;
            signup.SetObject();
            signup.Set("signupId", JsonValue(static_cast<int32>(playerSignup.signup.id)));
            signup.Set("eventId", JsonValue(static_cast<int32>(playerSignup.signup.eventId)));
            signup.Set("role", JsonValue(static_cast<int32>(playerSignup.signup.role)));
            signup.Set("status", JsonValue(static_cast<int32>(playerSignup.signup.status)));
            signup.Set("dungeonName", JsonValue(playerSignup.event.title));
            signup.Set("keyLevel", JsonValue(static_cast<int32>(playerSignup.event.keystoneLevel)));
            signup.Set("scheduledTime", JsonValue(static_cast<int32>(playerSignup.event.scheduledTime)));
            signup.Set("leaderName", JsonValue(leaderName));
            signupsArray.Push(signup);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_MY_SIGNUPS)
            .Set("signups", signupsArray.Encode())
            .Set("count", static_cast<int32>(signupsArray.Size()))
            .Send(player);
    }

    // Cancel an event (leader only)
    static void HandleCancelEvent(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        uint32 eventId = static_cast<uint32>(JsonGetInt(json, "eventId", 0));
        uint32 guid = player->GetGUID().GetCounter();

        // Check if player is the event leader
        QueryResult eventResult = CharacterDatabase.Query(
            "SELECT leader_guid FROM dc_group_finder_scheduled_events WHERE id = {} AND status IN (1, 2)",
            eventId);

        if (!eventResult)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Event not found")
                .Send(player);
            return;
        }

        uint32 leaderGuid = (*eventResult)[0].Get<uint32>();
        if (leaderGuid != guid)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "You are not the event leader")
                .Send(player);
            return;
        }

        // Cancel event
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_scheduled_events SET status = 4 WHERE id = {}",
            eventId);

        // Cancel all signups
        CharacterDatabase.Execute(
            "UPDATE dc_group_finder_event_signups SET status = 3 WHERE event_id = {} AND status IN (0, 1)",
            eventId);

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_EVENT_CREATED)
            .Set("success", true)
            .Set("eventId", static_cast<int32>(eventId))
            .Set("cancelled", true)
            .Set("message", "Event cancelled successfully")
            .Send(player);
    }

    // ========================================================================
    // HANDLERS: SPECTATING (EXTENDED)
    // ========================================================================

    // Start spectating a run
    static void HandleStartSpectate(Player* player, const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid request format")
                .Send(player);
            return;
        }

        auto json = GetJsonData(msg);
        uint32 runId = static_cast<uint32>(JsonGetInt(json, "runId", 0));
        if (runId == 0)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Invalid run id")
                .Send(player);
            return;
        }

        auto& spectatorMgr = DCMythicSpectator::MythicSpectatorManager::Get();

        DCMythicSpectator::SpectateableRun liveRun;
        if (!ResolveRuntimeSpectateRun(runId, liveRun))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Run not found or spectating not allowed")
                .Send(player);
            return;
        }

        uint32 instanceId = liveRun.instanceId;
        uint32 publicRunId = GetPublicSpectateRunId(liveRun);

        if (instanceId == 0)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Run not found or spectating not allowed")
                .Send(player);
            return;
        }

        if (!spectatorMgr.StartSpectating(player, instanceId))
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Failed to start spectating")
                .Send(player);
            return;
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SPECTATE_STARTED)
            .Set("success", true)
            .Set("runId", static_cast<int32>(publicRunId))
            .Set("message", "Now spectating the run")
            .Send(player);

        spectatorMgr.SendRunSnapshot(player, instanceId);
    }

    // Stop spectating a run
    static void HandleStopSpectate(Player* player, const ParsedMessage& msg)
    {
        uint32 runId = 0;
        uint32 instanceId = 0;

        auto& spectatorMgr = DCMythicSpectator::MythicSpectatorManager::Get();
        if (!spectatorMgr.IsSpectating(player))
        {
            JsonMessage(Module::GROUP_FINDER,
                Opcode::GroupFinder::SMSG_SPECTATE_ENDED)
                .Set("success", false)
                .Set("message", "Not currently spectating")
                .Send(player);
            return;
        }

        if (DCMythicSpectator::SpectatorState* state =
                spectatorMgr.GetSpectatorState(player->GetGUID()))
        {
            instanceId = state->targetInstanceId;
        }

        if (IsJsonMessage(msg))
        {
            runId = static_cast<uint32>(JsonGetInt(GetJsonData(msg), "runId", 0));
        }

        if (runId == 0 && instanceId > 0)
        {
            if (DCMythicSpectator::SpectateableRun const* run = spectatorMgr.GetRun(instanceId))
                runId = GetPublicSpectateRunId(*run);
            else
                runId = instanceId;
        }

        spectatorMgr.StopSpectating(player);

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SPECTATE_ENDED)
            .Set("success", true)
            .Set("runId", static_cast<int32>(runId))
            .Set("message", "Stopped spectating")
            .Send(player);
    }

    // ========================================================================
    // HANDLERS: DUNGEON & RAID LISTS
    // ========================================================================

    // Get M+ dungeon list from database (current season)
    static void HandleGetDungeonList(Player* player, const ParsedMessage& /*msg*/)
    {
        // Query dungeons enabled for current season
        // Note: dungeon_id IS the map_id in this table
        QueryResult result = WorldDatabase.Query(
            "SELECT dungeon_id, dungeon_name, short_name, base_timer, boss_count, difficulty_rating "
            "FROM dc_mplus_dungeons WHERE season_enabled = 1 ORDER BY dungeon_name");

        JsonMessage json(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_DUNGEON_LIST);

        if (!result)
        {
            // Send empty list
            json.Set("count", 0);
            json.Set("dungeons", "[]");
            json.Send(player);
            return;
        }

        std::ostringstream dungeonArray;
        dungeonArray << "[";
        uint32 count = 0;

        do
        {
            Field* fields = result->Fetch();
            if (count > 0) dungeonArray << ",";

            uint32 dungeonId = fields[0].Get<uint32>();

            dungeonArray << "{";
            dungeonArray << "\"id\":" << dungeonId << ",";
            dungeonArray << "\"name\":\"" << fields[1].Get<std::string>() << "\",";
            dungeonArray << "\"short\":\"" << fields[2].Get<std::string>() << "\",";
            dungeonArray << "\"timer\":" << fields[3].Get<uint32>() << ",";
            dungeonArray << "\"bosses\":" << fields[4].Get<uint32>() << ",";
            dungeonArray << "\"difficulty\":" << fields[5].Get<uint32>() << ",";
            dungeonArray << "\"mapId\":" << dungeonId;  // dungeon_id IS the map_id
            dungeonArray << "}";

            count++;
        } while (result->NextRow());

        dungeonArray << "]";

        json.Set("count", static_cast<int32>(count));
        json.Set("dungeons", dungeonArray.str());
        json.Send(player);

        LOG_DEBUG("dc.addon", "Sent {} M+ dungeons to player {}", count, player->GetName());
    }

    // Get raid list from database (all eras)
    static void HandleGetRaidList(Player* player, const ParsedMessage& /*msg*/)
    {
        // Hardcoded raid list with proper difficulties per era
        // Era: 0=Classic, 1=TBC, 2=WotLK
        // Difficulties vary by era:
        //   Classic: 40-man only (diff 0)
        //   TBC: 10/25 Normal only (diff 0/1)
        //   WotLK: 10N/25N/10H/25H (diff 0/1/2/3)

        struct RaidInfo {
            uint32 id;
            const char* name;
            uint32 mapId;
            uint8 era;          // 0=Classic, 1=TBC, 2=WotLK
            uint8 bosses;
            uint8 minDiff;      // Minimum difficulty available
            uint8 maxDiff;      // Maximum difficulty available
        };

        static const RaidInfo raids[] = {
            // Classic Raids (40-man only, difficulty 0)
            { 101, "Molten Core",            409, 0, 10, 0, 0 },
            { 102, "Blackwing Lair",         469, 0, 8,  0, 0 },
            { 103, "Temple of Ahn'Qiraj",    531, 0, 9,  0, 0 },
            { 104, "Ruins of Ahn'Qiraj",     509, 0, 6,  0, 0 },  // 20-man
            { 105, "Zul'Gurub",              309, 0, 10, 0, 0 },  // 20-man

            // TBC Raids (10/25 Normal only)
            { 201, "Karazhan",               532, 1, 12, 0, 0 },  // 10-man only
            { 202, "Gruul's Lair",           565, 1, 2,  1, 1 },  // 25-man only
            { 203, "Magtheridon's Lair",     544, 1, 1,  1, 1 },  // 25-man only
            { 204, "Serpentshrine Cavern",   548, 1, 6,  1, 1 },  // 25-man
            { 205, "Tempest Keep",           550, 1, 4,  1, 1 },  // 25-man
            { 206, "Mount Hyjal",            534, 1, 5,  1, 1 },  // 25-man
            { 207, "Black Temple",           564, 1, 9,  1, 1 },  // 25-man
            { 208, "Zul'Aman",               568, 1, 6,  0, 0 },  // 10-man
            { 209, "Sunwell Plateau",        580, 1, 6,  1, 1 },  // 25-man

            // WotLK Raids (10N/25N/10H/25H)
            { 301, "Naxxramas",              533, 2, 15, 0, 1 },  // 10/25 Normal only
            { 302, "Obsidian Sanctum",       615, 2, 1,  0, 1 },
            { 303, "Eye of Eternity",        616, 2, 1,  0, 1 },
            { 304, "Vault of Archavon",      624, 2, 4,  0, 1 },
            { 305, "Ulduar",                 603, 2, 14, 0, 1 },  // Hard modes, not heroic diff
            { 306, "Trial of the Crusader",  649, 2, 5,  0, 3 },  // Full heroic support
            { 307, "Onyxia's Lair",          249, 2, 1,  0, 1 },
            { 308, "Icecrown Citadel",       631, 2, 12, 0, 3 },  // Full heroic support
            { 309, "Ruby Sanctum",           724, 2, 1,  0, 3 },  // Full heroic support
        };

        static const uint32 raidCount = sizeof(raids) / sizeof(raids[0]);

        std::ostringstream raidArray;
        raidArray << "[";

        for (uint32 i = 0; i < raidCount; i++)
        {
            if (i > 0) raidArray << ",";
            auto const& r = raids[i];

            raidArray << "{";
            raidArray << "\"id\":" << r.id << ",";
            raidArray << "\"name\":\"" << r.name << "\",";
            raidArray << "\"mapId\":" << r.mapId << ",";
            raidArray << "\"era\":" << static_cast<int>(r.era) << ",";
            raidArray << "\"bosses\":" << static_cast<int>(r.bosses) << ",";
            raidArray << "\"minDiff\":" << static_cast<int>(r.minDiff) << ",";
            raidArray << "\"maxDiff\":" << static_cast<int>(r.maxDiff);
            raidArray << "}";
        }

        raidArray << "]";

        JsonMessage json(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_RAID_LIST);
        json.Set("count", static_cast<int32>(raidCount));
        json.Set("raids", raidArray.str());
        json.Send(player);

        LOG_DEBUG("dc.addon", "Sent {} raids to player {}", raidCount, player->GetName());
    }

    // Get system configuration (rewards, etc)
    static void HandleGetSystemInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        JsonMessage json(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SYSTEM_INFO);

        // Reward config
        json.Set("rewardEnabled", sGroupFinderMgr.IsRewardEnabled());
        json.Set("rewardItemId", static_cast<int32>(sGroupFinderMgr.GetRewardItemId()));
        json.Set("rewardItemCount", static_cast<int32>(sGroupFinderMgr.GetRewardItemCount()));
        json.Set("rewardCurrencyId", static_cast<int32>(sGroupFinderMgr.GetRewardCurrencyId()));
        json.Set("rewardCurrencyCount", static_cast<int32>(sGroupFinderMgr.GetRewardCurrencyCount()));
        json.Set("rewardDailyLimit", static_cast<int32>(sGroupFinderMgr.GetRewardDailyLimit()));

        json.Send(player);
    }

    // ========================================================================
    // REGISTRATION
    // ========================================================================

    void RegisterHandlers()
    {
        LoadConfig();

        // Listing management
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_CREATE_LISTING, HandleCreateListing);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_SEARCH_LISTINGS, HandleSearchListings);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_APPLY_TO_GROUP, HandleApplyToGroup);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_CANCEL_APPLICATION, HandleCancelApplication);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_ACCEPT_APPLICATION, HandleAcceptApplication);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_DECLINE_APPLICATION, HandleDeclineApplication);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_DELIST_GROUP, HandleDelistGroup);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_MY_APPLICATIONS, HandleGetMyApplications);

        // Keystone & difficulty
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_MY_KEYSTONE, HandleGetMyKeystone);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_SET_DIFFICULTY, HandleSetDifficulty);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_DUNGEON_LIST, HandleGetDungeonList);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_RAID_LIST, HandleGetRaidList);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_SYSTEM_INFO, HandleGetSystemInfo);

        // Spectating
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_SPECTATE_LIST, HandleGetSpectateList);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_START_SPECTATE, HandleStartSpectate);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_STOP_SPECTATE, HandleStopSpectate);

        // Scheduled events
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_CREATE_EVENT, HandleCreateEvent);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_SIGNUP_EVENT, HandleSignupEvent);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_CANCEL_SIGNUP, HandleCancelSignup);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_SCHEDULED_EVENTS, HandleGetScheduledEvents);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_MY_SIGNUPS, HandleGetMySignups);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_CANCEL_EVENT, HandleCancelEvent);

        LOG_INFO("dc.addon", "Group Finder module handlers registered");
    }

}  // namespace GroupFinder
}  // namespace DCAddon

// ============================================================================
// WORLD SCRIPT: Manages GroupFinderMgr lifecycle
// ============================================================================

class GroupFinderWorldScript : public WorldScript
{
public:
    GroupFinderWorldScript() : WorldScript("GroupFinderWorldScript") {}

    void OnStartup() override
    {
        LOG_INFO("dc.groupfinder", "Initializing Group Finder Manager...");
        DCAddon::sGroupFinderMgr.Initialize();
    }

    void OnUpdate(uint32 diff) override
    {
        DCAddon::sGroupFinderMgr.Update(diff);
    }
};

// ============================================================================
// PLAYER SCRIPT: Cleanup player data on logout
// ============================================================================

class GroupFinderPlayerScript : public PlayerScript
{
public:
    GroupFinderPlayerScript() : PlayerScript("GroupFinderPlayerScript") {}

    void OnPlayerLogout(Player* player) override
    {
        if (player)
        {
            DCAddon::sGroupFinderMgr.CleanupPlayerData(player->GetGUID().GetCounter());
        }
    }
};

void AddSC_dc_addon_groupfinder()
{
    DCAddon::GroupFinder::RegisterHandlers();
    new GroupFinderWorldScript();
    new GroupFinderPlayerScript();
}
