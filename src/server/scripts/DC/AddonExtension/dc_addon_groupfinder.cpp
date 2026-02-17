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
#include "dc_addon_groupfinder.h"

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
        LISTING_OTHER       = 4
    };

    enum ApplicationStatus : uint8
    {
        APP_STATUS_PENDING  = 0,
        APP_STATUS_ACCEPTED = 1,
        APP_STATUS_DECLINED = 2,
        APP_STATUS_CANCELLED = 3
    };

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

        // Extract listing data
        uint8 listingType = static_cast<uint8>(JsonGetInt(json, "listingType", LISTING_MYTHIC_PLUS));
        uint32 dungeonId = static_cast<uint32>(JsonGetInt(json, "dungeonId", 0));
        std::string dungeonName = JsonGetString(json, "dungeonName", "Unknown");
        uint8 keystoneLevel = static_cast<uint8>(JsonGetInt(json, "keyLevel", 0));
        uint16 minIlvl = static_cast<uint16>(JsonGetInt(json, "minIlvl", 0));
        uint8 needTank = static_cast<uint8>(JsonGetInt(json, "needTank", 1));
        uint8 needHealer = static_cast<uint8>(JsonGetInt(json, "needHealer", 1));
        uint8 needDps = static_cast<uint8>(JsonGetInt(json, "needDps", 3));
        std::string note = JsonGetString(json, "note", "");

        // Get group GUID if in a group
        uint32 groupGuid = 0;
        if (Group* group = player->GetGroup())
            groupGuid = group->GetGUID().GetCounter();

        // Create listing object
        DCAddon::GroupFinderListing listing;
        listing.listingType = listingType;
        listing.dungeonId = dungeonId;
        listing.dungeonName = dungeonName;
        listing.difficulty = player->GetDungeonDifficulty();
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
        int32 listingType = JsonGetInt(json, "listingType", 0);  // 0 = all
        int32 dungeonId = JsonGetInt(json, "dungeonId", 0);      // 0 = all
        int32 minLevel = JsonGetInt(json, "minLevel", 0);
        int32 maxLevel = JsonGetInt(json, "maxLevel", 0);

        // Build query
        std::string query =
            "SELECT l.id, l.leader_guid, l.dungeon_id, l.dungeon_name, l.difficulty, "
            "l.keystone_level, l.min_ilvl, l.current_tank, l.current_healer, l.current_dps, "
            "l.need_tank, l.need_healer, l.need_dps, l.note, l.listing_type, c.name AS leader_name "
            "FROM dc_group_finder_listings l "
            "LEFT JOIN characters c ON l.leader_guid = c.guid "
            "WHERE l.status = 1";

        if (listingType > 0)
            query += " AND l.listing_type = " + std::to_string(listingType);
        if (dungeonId > 0)
            query += " AND l.dungeon_id = " + std::to_string(dungeonId);
        if (minLevel > 0)
            query += " AND l.keystone_level >= " + std::to_string(minLevel);
        if (maxLevel > 0)
            query += " AND l.keystone_level <= " + std::to_string(maxLevel);

        query += " ORDER BY l.keystone_level DESC, l.created_at DESC LIMIT 50";

        QueryResult result = CharacterDatabase.Query(query);

        JsonValue groupsArray;
        groupsArray.SetArray();

        if (result)
        {
            do
            {
                JsonValue group;
                group.SetObject();
                group.Set("id", JsonValue((*result)[0].Get<int32>()));
                group.Set("leaderGuid", JsonValue((*result)[1].Get<int32>()));
                group.Set("dungeonId", JsonValue((*result)[2].Get<int32>()));
                group.Set("dungeon", JsonValue((*result)[3].Get<std::string>()));
                group.Set("difficulty", JsonValue((*result)[4].Get<int32>()));
                group.Set("level", JsonValue((*result)[5].Get<int32>()));
                group.Set("minIlvl", JsonValue((*result)[6].Get<int32>()));

                bool hasTank = (*result)[7].Get<uint8>() > 0;
                bool hasHealer = (*result)[8].Get<uint8>() > 0;
                uint8 dpsCount = (*result)[9].Get<uint8>();

                group.Set("tank", JsonValue(hasTank));
                group.Set("healer", JsonValue(hasHealer));
                group.Set("dps", JsonValue(static_cast<int32>(dpsCount)));
                group.Set("needTank", JsonValue(static_cast<int32>((*result)[10].Get<uint8>())));
                group.Set("needHealer", JsonValue(static_cast<int32>((*result)[11].Get<uint8>())));
                group.Set("needDps", JsonValue(static_cast<int32>((*result)[12].Get<uint8>())));
                group.Set("note", JsonValue((*result)[13].Get<std::string>()));
                group.Set("type", JsonValue((*result)[14].Get<int32>()));
                group.Set("leader", JsonValue((*result)[15].Get<std::string>()));

                groupsArray.Push(group);
            } while (result->NextRow());
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SEARCH_RESULTS)
            .Set("groups", groupsArray.Encode())
            .Set("count", static_cast<int32>(groupsArray.Size()))
            .Send(player);
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
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_APPLICATION_STATUS)
                .Set("success", true)
                .Set("status", "pending")
                .Set("message", "Application submitted")
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
                appObj.Set("dungeonName", JsonValue(listingOpt->dungeonName));
                appObj.Set("dungeonId", JsonValue(static_cast<int32>(listingOpt->dungeonId)));
                appObj.Set("keystoneLevel", JsonValue(static_cast<int32>(listingOpt->keystoneLevel)));
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

        int32 applicationId = JsonGetInt(json, "applicationId", 0);
        uint32 applicantGuid = static_cast<uint32>(JsonGetInt(json, "applicantGuid", 0));

        // leaderGuid not required here; manager validates leader permissions internally

        uint32 listingId = sGroupFinderMgr.FindListingIdForApplication(static_cast<uint32>(applicationId));
        // Use manager to accept application (handles DB, cache, and notifications)
        if (listingId != 0 && sGroupFinderMgr.AcceptApplication(player, listingId, applicantGuid))
        {
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

        int32 applicationId = JsonGetInt(json, "applicationId", 0);
        uint32 applicantGuid = static_cast<uint32>(JsonGetInt(json, "applicantGuid", 0));

        // leaderGuid not required here; manager validates leader permissions internally

        // Use manager to decline application
        uint32 listingId = sGroupFinderMgr.FindListingIdForApplication(static_cast<uint32>(applicationId));
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

    // Remove a listing
    static void HandleDelistGroup(Player* player, const ParsedMessage& msg)
    {
        auto json = GetJsonData(msg);

        int32 listingId = JsonGetInt(json, "listingId", 0);

        // Use manager to delete listing
        if (sGroupFinderMgr.DeleteListing(player, listingId))
        {
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

            if (group)
                group->SetDungeonDifficulty(Difficulty(difficulty));
            else
                player->SetDungeonDifficulty(Difficulty(difficulty));

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
        // Query active M+ runs that allow spectating
        QueryResult result = CharacterDatabase.Query(
            "SELECT r.run_id, r.map_id, r.key_level, r.start_time, r.leader_guid, "
            "d.dungeon_name, c.name AS leader_name "
            "FROM dc_mplus_runs r "
            "LEFT JOIN dc_mplus_dungeons d ON r.map_id = d.map_id "
            "LEFT JOIN characters c ON r.leader_guid = c.guid "
            "WHERE r.status = 1 AND r.allow_spectate = 1 "
            "ORDER BY r.key_level DESC LIMIT 20");

        JsonValue runsArray;
        runsArray.SetArray();

        if (result)
        {
            do
            {
                JsonValue run;
                run.SetObject();
                run.Set("runId", JsonValue((*result)[0].Get<int32>()));
                run.Set("mapId", JsonValue((*result)[1].Get<int32>()));
                run.Set("keyLevel", JsonValue((*result)[2].Get<int32>()));
                run.Set("startTime", JsonValue((*result)[3].Get<int32>()));
                run.Set("leaderGuid", JsonValue((*result)[4].Get<int32>()));
                run.Set("dungeonName", JsonValue((*result)[5].Get<std::string>()));
                run.Set("leaderName", JsonValue((*result)[6].Get<std::string>()));
                runsArray.Push(run);
            } while (result->NextRow());
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

        std::string typeFilter = eventType > 0 ?
            Acore::StringFormat(" AND event_type = {}", eventType) : "";

        // Query upcoming events
        QueryResult result = CharacterDatabase.Query(
            "SELECT e.id, e.leader_guid, e.event_type, e.dungeon_id, e.dungeon_name, e.keystone_level, "
            "UNIX_TIMESTAMP(e.scheduled_time) as scheduled_time, e.max_signups, e.current_signups, e.note, e.status, "
            "c.name as leader_name "
            "FROM dc_group_finder_scheduled_events e "
            "LEFT JOIN characters c ON e.leader_guid = c.guid "
            "WHERE e.status IN (1, 2) AND e.scheduled_time > NOW(){} "
            "ORDER BY e.scheduled_time ASC LIMIT 50",
            typeFilter);

        JsonValue eventsArray;
        eventsArray.SetArray();

        if (result)
        {
            do
            {
                JsonValue event;
                event.SetObject();
                event.Set("eventId", JsonValue((*result)[0].Get<int32>()));
                event.Set("leaderGuid", JsonValue((*result)[1].Get<int32>()));
                event.Set("eventType", JsonValue((*result)[2].Get<int32>()));
                event.Set("dungeonId", JsonValue((*result)[3].Get<int32>()));
                event.Set("dungeonName", JsonValue((*result)[4].Get<std::string>()));
                event.Set("keyLevel", JsonValue((*result)[5].Get<int32>()));
                event.Set("scheduledTime", JsonValue((*result)[6].Get<int32>()));
                event.Set("maxSignups", JsonValue((*result)[7].Get<int32>()));
                event.Set("currentSignups", JsonValue((*result)[8].Get<int32>()));
                event.Set("note", JsonValue((*result)[9].Get<std::string>()));
                event.Set("status", JsonValue((*result)[10].Get<int32>()));
                event.Set("leaderName", JsonValue((*result)[11].Get<std::string>()));
                eventsArray.Push(event);
            } while (result->NextRow());
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

        QueryResult result = CharacterDatabase.Query(
            "SELECT s.id, s.event_id, s.role, s.status, "
            "e.dungeon_name, e.keystone_level, UNIX_TIMESTAMP(e.scheduled_time) as scheduled_time, "
            "c.name as leader_name "
            "FROM dc_group_finder_event_signups s "
            "JOIN dc_group_finder_scheduled_events e ON s.event_id = e.id "
            "LEFT JOIN characters c ON e.leader_guid = c.guid "
            "WHERE s.player_guid = {} AND s.status IN (0, 1) AND e.scheduled_time > NOW() "
            "ORDER BY e.scheduled_time ASC",
            guid);

        JsonValue signupsArray;
        signupsArray.SetArray();

        if (result)
        {
            do
            {
                JsonValue signup;
                signup.SetObject();
                signup.Set("signupId", JsonValue((*result)[0].Get<int32>()));
                signup.Set("eventId", JsonValue((*result)[1].Get<int32>()));
                signup.Set("role", JsonValue((*result)[2].Get<int32>()));
                signup.Set("status", JsonValue((*result)[3].Get<int32>()));
                signup.Set("dungeonName", JsonValue((*result)[4].Get<std::string>()));
                signup.Set("keyLevel", JsonValue((*result)[5].Get<int32>()));
                signup.Set("scheduledTime", JsonValue((*result)[6].Get<int32>()));
                signup.Set("leaderName", JsonValue((*result)[7].Get<std::string>()));
                signupsArray.Push(signup);
            } while (result->NextRow());
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
        uint32 guid = player->GetGUID().GetCounter();

        // Check if run exists and allows spectating
        QueryResult runResult = CharacterDatabase.Query(
            "SELECT map_id, key_level FROM dc_mplus_runs WHERE run_id = {} AND status = 1 AND allow_spectate = 1",
            runId);

        if (!runResult)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "Run not found or spectating not allowed")
                .Send(player);
            return;
        }

        // Add to spectators
        CharacterDatabase.Execute(
            "INSERT INTO dc_group_finder_spectators (run_id, spectator_guid, spectator_name, started_at) "
            "VALUES ({}, {}, '{}', NOW()) "
            "ON DUPLICATE KEY UPDATE started_at = NOW()",
            runId, guid, player->GetName());

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SPECTATE_STARTED)
            .Set("success", true)
            .Set("runId", static_cast<int32>(runId))
            .Set("message", "Now spectating the run")
            .Send(player);

        // TODO: Teleport player to spectator position in the dungeon
    }

    // Stop spectating a run
    static void HandleStopSpectate(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        uint32 runId = 0;

        if (IsJsonMessage(msg))
        {
            runId = static_cast<uint32>(JsonGetInt(GetJsonData(msg), "runId", 0));
        }

        if (runId > 0)
        {
            CharacterDatabase.Execute(
                "DELETE FROM dc_group_finder_spectators WHERE run_id = {} AND spectator_guid = {}",
                runId, guid);
        }
        else
        {
            // Stop spectating all runs
            CharacterDatabase.Execute(
                "DELETE FROM dc_group_finder_spectators WHERE spectator_guid = {}",
                guid);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SPECTATE_ENDED)
            .Set("success", true)
            .Set("message", "Stopped spectating")
            .Send(player);

        // TODO: Teleport player back to their previous position
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
