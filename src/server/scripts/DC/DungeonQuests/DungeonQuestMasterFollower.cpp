/*
 * DarkChaos-WoW Dungeon Quest Master Follower System
 * Copyright (C) 2025 DarkChaos-WoW
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * Pet-like follower system for dungeon quest masters:
 * - Spawns near group leader when entering dungeon
 * - Follows leader like a pet
 * - Despawns when leader enters combat
 * - Can be re-summoned via .dcquest summon command when out of combat
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "TemporarySummon.h"
#include "Map.h"
#include "MapMgr.h"
#include "Group.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "ChatCommand.h"
#include "DatabaseEnv.h"
#include "DungeonQuestConstants.h"
#include "DungeonQuestHelpers.h"
#include <mutex>
#include <unordered_map>

using namespace Acore::ChatCommands;
using namespace DungeonQuest;
using namespace DungeonQuestHelpers;

// Info needed to resolve a follower creature that may live on a DIFFERENT map
// than the player's current one (e.g. the player instant-transferred straight
// from one quest-master dungeon into another).
struct QuestMasterFollowerInfo
{
    ObjectGuid creatureGuid;
    uint32 mapId = 0;
    uint32 instanceId = 0;
};

// Storage for active quest master followers
// Key: Player GUID (leader), Value: follower location info
// Mutex-guarded: PlayerScript/GroupScript hooks run on map-update threads, and
// with MapUpdate.Threads > 1 different maps' hooks can touch these shared maps concurrently.
static std::mutex sQuestMasterFollowersMutex;
static std::unordered_map<ObjectGuid, QuestMasterFollowerInfo> sQuestMasterFollowers;
static std::mutex sDungeonDisplayIdCacheMutex;
static std::unordered_map<uint32, uint32> sDungeonDisplayIdCache;

// Helper: Get the appropriate quest master entry for a map.
// Returns 0 (no follower) when the map has no enabled dc_dungeon_npc_mapping row — maps like
// Blackwing Descent (669) opt out of the dungeon-quest system and run their own questgiver.
static uint32 GetQuestMasterEntryForMap(uint32 mapId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_dungeon_npc_mapping WHERE map_id = {} AND enabled = 1 LIMIT 1",
        mapId
    );

    if (!result)
    {
        LOG_DEBUG("scripts.dc", "DungeonQuestMaster: No mapping for map ID {} - no follower", mapId);
        return 0;
    }

    return NPC_UNIVERSAL_QUEST_MASTER;
}

// Helper: Get display ID for a map (cached)
static uint32 GetDisplayIdForMap(uint32 mapId)
{
    {
        std::lock_guard<std::mutex> lock(sDungeonDisplayIdCacheMutex);
        auto it = sDungeonDisplayIdCache.find(mapId);
        if (it != sDungeonDisplayIdCache.end())
            return it->second;
    }

    uint32 displayId = 16466; // Default display: Human Male Quest Giver
    QueryResult displayResult = WorldDatabase.Query(
        "SELECT display_id FROM dc_dungeon_npc_mapping WHERE map_id = {} AND display_id IS NOT NULL AND display_id > 0",
        mapId
    );
    if (displayResult)
        displayId = (*displayResult)[0].Get<uint32>();

    {
        std::lock_guard<std::mutex> lock(sDungeonDisplayIdCacheMutex);
        sDungeonDisplayIdCache[mapId] = displayId;
    }
    return displayId;
}

// Helper: is this map at a difficulty the quest master should stay out of?
//
// "Mythic" is a DUNGEON concept. Map::GetDifficulty() is just the raw spawn mode
// (Map.h:294 -- `return Difficulty(GetSpawnMode())`), and the Difficulty enum is overloaded by
// map type (DBCEnums.h): on a RAID map, mode 2 is 10-man Heroic and mode 3 is 25-man Heroic --
// neither is Mythic, and there is no Mythic raid difficulty at all on 3.3.5.
//
// So a bare `GetDifficulty() == DUNGEON_DIFFICULTY_EPIC` was wrong in BOTH directions on every
// registered raid map: it suppressed the follower on 10-man Heroic (which is not Mythic) while
// letting 25-man Heroic through (mode 3 never equals 2). Guarding with !IsRaid() is the core's
// own idiom for this exact overload -- see ScriptedAI::ScriptedAI, ScriptedCreature.cpp:215.
static bool IsQuestMasterBlockedDifficulty(Map const* map)
{
    return map && !map->IsRaid() && map->GetDifficulty() == DUNGEON_DIFFICULTY_EPIC;
}

// Helper: Spawn quest master follower for player.
// On success, if outEntry is non-null, receives the resolved quest-master NPC
// entry so callers don't need to re-query GetQuestMasterEntryForMap themselves.
static Creature* SpawnQuestMasterFollower(Player* player, uint32* outEntry = nullptr)
{
    if (!player || !player->GetMap())
        return nullptr;

    uint32 entry = GetQuestMasterEntryForMap(player->GetMapId());
    if (!entry)
        return nullptr;

    if (outEntry)
        *outEntry = entry;

    uint32 const mapId = player->GetMapId();
    uint32 const instanceId = player->GetInstanceId();

    // If the player still has a follower recorded on a DIFFERENT map/instance
    // (e.g. they instant-transferred straight from one quest-master dungeon
    // into another), despawn the stale one first. ObjectAccessor is scoped to
    // the player's CURRENT map, so it can never reach a creature left behind on
    // the old map - resolve it via sMapMgr instead.
    QuestMasterFollowerInfo stale;
    bool hasStale = false;
    {
        std::lock_guard<std::mutex> lock(sQuestMasterFollowersMutex);
        auto it = sQuestMasterFollowers.find(player->GetGUID());
        if (it != sQuestMasterFollowers.end() &&
            (it->second.mapId != mapId || it->second.instanceId != instanceId))
        {
            stale = it->second;
            hasStale = true;
            sQuestMasterFollowers.erase(it);
        }
    }

    if (hasStale)
    {
        if (Map* oldMap = sMapMgr->FindMap(stale.mapId, stale.instanceId))
        {
            if (Creature* oldFollower = oldMap->GetCreature(stale.creatureGuid))
            {
                oldFollower->DespawnOrUnsummon(0ms);
                LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Despawned stale follower on map {} for player {}",
                          stale.mapId, player->GetName());
            }
        }
    }

    // Check if one is already nearby (handling grid unload/reload edge cases).
    //
    // ONLY re-link a follower THIS player summoned. Followers are per-player, so on a map where
    // several players arrive together -- any raid, but also a 5-man that zones in as a group --
    // a bare proximity match makes players 2..N adopt player 1's follower. Every one of them
    // then has the same creature GUID recorded, and the first OnPlayerEnterCombat despawns that
    // single shared creature and leaves the rest pointing at a dead GUID: no follower, and
    // GetQuestMasterFollower() returning null means they cannot even re-summon cleanly.
    //
    // The summon is created with `player` as the summoner (see SummonCreature below), so the
    // summoner GUID is the ownership record. A creature that fails this test belongs to someone
    // else and we fall through and summon our own.
    if (Creature* existing = player->FindNearestCreature(entry, 50.0f))
    {
        TempSummon const* existingSummon = existing->ToTempSummon();
        if (existingSummon && existingSummon->GetSummonerGUID() == player->GetGUID())
        {
            // Re-link it if we lost track
            std::lock_guard<std::mutex> lock(sQuestMasterFollowersMutex);
            sQuestMasterFollowers[player->GetGUID()] = QuestMasterFollowerInfo{ existing->GetGUID(), mapId, instanceId };
            return existing;
        }
    }

    // Get spawn position near player
    float x, y, z, o;
    player->GetPosition(x, y, z, o);

    // Offset slightly behind player
    float angle = o + M_PI; // 180 degrees behind
    x += 2.0f * cos(angle);
    y += 2.0f * sin(angle);

    // Spawn quest master follower for player (visible to all players in dungeon)
    Position pos(x, y, z, o);
    if (TempSummon* summon = player->GetMap()->SummonCreature(entry, pos, nullptr, 0, player))
    {
        // Configure follower behavior
        summon->SetReactState(REACT_PASSIVE); // Don't attack
        summon->ReplaceAllNpcFlags(UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER);

        // Set display ID for this dungeon (AI constructor may not run for temp summons)
        uint32 displayId = GetDisplayIdForMap(player->GetMapId());
        summon->SetNativeDisplayId(displayId);
        summon->SetDisplayId(displayId);
        LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Set DisplayId to {} for map {}",
                  displayId, player->GetMapId());

        // Debug logging
        LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Spawned entry={} for player {} at ({:.2f},{:.2f},{:.2f})",
                  entry, player->GetName(), x, y, z);
        LOG_DEBUG("scripts.dc", "DungeonQuestMaster: NPC Flags set to {} (GOSSIP=1 | QUESTGIVER=2)",
                  static_cast<uint32>(summon->GetNpcFlags()));

        // Make it follow the player
        summon->GetMotionMaster()->MoveFollow(player, 2.0f, M_PI); // 2 yards behind

        // Store mapping
        {
            std::lock_guard<std::mutex> lock(sQuestMasterFollowersMutex);
            sQuestMasterFollowers[player->GetGUID()] = QuestMasterFollowerInfo{ summon->GetGUID(), mapId, instanceId };
        }

        LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Follower {} stored for player {}",
                  summon->GetGUID().ToString(), player->GetName());

        return summon;
    }

    return nullptr;
}

// Helper: Despawn quest master follower for player
static void DespawnQuestMasterFollower(Player* player, bool notify = false)
{
    if (!player)
        return;

    QuestMasterFollowerInfo info;
    {
        std::lock_guard<std::mutex> lock(sQuestMasterFollowersMutex);
        auto it = sQuestMasterFollowers.find(player->GetGUID());
        if (it == sQuestMasterFollowers.end())
            return;

        info = it->second;
        sQuestMasterFollowers.erase(it);
    }

    // Resolve via the follower's OWN recorded map/instance, not the player's
    // current one - the player may already have moved on by the time this runs.
    if (Map* followerMap = sMapMgr->FindMap(info.mapId, info.instanceId))
    {
        if (Creature* follower = followerMap->GetCreature(info.creatureGuid))
        {
            follower->DespawnOrUnsummon(0ms);
            LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Despawned follower for player {}", player->GetName());
        }
    }

    if (notify)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("Quest Master dismissed.");
    }
}

// Helper: Get active follower for player (only if it's still on the player's CURRENT map)
static Creature* GetQuestMasterFollower(Player* player)
{
    if (!player)
        return nullptr;

    std::lock_guard<std::mutex> lock(sQuestMasterFollowersMutex);
    auto it = sQuestMasterFollowers.find(player->GetGUID());
    if (it == sQuestMasterFollowers.end())
        return nullptr;

    if (it->second.mapId != player->GetMapId() || it->second.instanceId != player->GetInstanceId())
        return nullptr; // stale entry left behind on a previous map

    return ObjectAccessor::GetCreature(*player, it->second.creatureGuid);
}

// PlayerScript to handle automatic spawn/despawn
class DungeonQuestMasterFollowerScript : public PlayerScript
{
public:
    DungeonQuestMasterFollowerScript() : PlayerScript("DungeonQuestMasterFollowerScript",
    {
        PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_PLAYER_ENTER_COMBAT
    }) { }

    // Spawn follower when player enters dungeon (solo or group)
    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.FollowerEnable", true))
            return;

        uint32 mapId = player->GetMapId();
        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        if (!mapEntry || !mapEntry->IsDungeon())
        {
            // Player left dungeon -> Despawn follower if exists
            DespawnQuestMasterFollower(player);
            return;
        }

        // Guild houses are dungeon-type instances (for per-guild isolation) but
        // are not quest dungeons -> never spawn the quest master there (covers 1409 and 1413).
        if (IsGuildHouseQuestExcludedMap(mapId))
        {
            DespawnQuestMasterFollower(player);
            return;
        }

        // Don't spawn quest masters in Mythic or Mythic+ difficulties (dungeons only -- see
        // IsQuestMasterBlockedDifficulty for why raids must not use this comparison).
        if (IsQuestMasterBlockedDifficulty(player->GetMap()))
        {
            LOG_DEBUG("scripts.dc", "DungeonQuestMaster: Skipping spawn in Mythic difficulty for player {}",
                      player->GetName());
            return;
        }

        // Check if follower already exists
        if (GetQuestMasterFollower(player))
            return;

        // Spawn follower for solo players or any dungeon participant
        uint32 entry = 0;
        if (Creature* follower = SpawnQuestMasterFollower(player, &entry))
        {
            if (sConfigMgr->GetOption<bool>(CONFIG_DEBUG_ENABLE, false))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[DungeonQuest DEBUG]|r Master spawned - Entry: {} Flags: {} Follow: YES",
                                                                   entry, static_cast<uint32>(follower->GetNpcFlags()));
            }
            ChatHandler(player->GetSession()).PSendSysMessage("A Quest Master has joined you!");
        }
    }

    // Despawn follower when leader enters combat
    void OnPlayerEnterCombat(Player* player, Unit* /*enemy*/) override
    {
        if (!player)
            return;

        // Check if this player has an active follower
        Creature* follower = GetQuestMasterFollower(player);
        if (!follower)
            return;

        DespawnQuestMasterFollower(player);
        ChatHandler(player->GetSession()).PSendSysMessage("Quest Master retreated to safety!");
    }

    // Clean up follower on logout
    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        DespawnQuestMasterFollower(player);
    }
};

// GroupScript to handle leader changes
class DungeonQuestMasterFollowerGroupScript : public GroupScript
{
public:
    DungeonQuestMasterFollowerGroupScript() : GroupScript("DungeonQuestMasterFollowerGroupScript") { }

    void OnChangeLeader(Group* group, ObjectGuid newLeaderGuid, ObjectGuid oldLeaderGuid) override
    {
        if (!group)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.FollowerEnable", true))
            return;

        // When leader changes in a group, followers are already per-player so no special handling needed
        // Each player keeps their own follower, regardless of who the leader is
        (void)newLeaderGuid;
        (void)oldLeaderGuid;
    }

    void OnDisband(Group* group) override
    {
        if (!group)
            return;

        // Clean up all followers when group disbands
        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            if (Player* member = itr->GetSource())
            {
                DespawnQuestMasterFollower(member);
            }
        }
    }
};

// Command script to manually summon/dismiss quest master
class DungeonQuestMasterFollowerCommandScript : public CommandScript
{
public:
    DungeonQuestMasterFollowerCommandScript() : CommandScript("DungeonQuestMasterFollowerCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable dcquestCommandTable =
        {
            { "summon",   HandleSummonQuestMasterCommand,   SEC_PLAYER, Console::No },
            { "dismiss",  HandleDismissQuestMasterCommand,  SEC_PLAYER, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "dcquest", dcquestCommandTable }
        };

        return commandTable;
    }

    static bool HandleSummonQuestMasterCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Check if player is in combat
        if (player->IsInCombat())
        {
            handler->PSendSysMessage("You cannot summon the Quest Master while in combat!");
            return true;
        }

        // Check if player is in a dungeon
        uint32 mapId = player->GetMapId();
        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        if (!mapEntry || !mapEntry->IsDungeon() || IsGuildHouseQuestExcludedMap(mapId))
        {
            handler->PSendSysMessage("You can only summon the Quest Master inside dungeons!");
            return true;
        }

        // Don't allow summoning in Mythic or Mythic+ difficulties (dungeons only)
        if (IsQuestMasterBlockedDifficulty(player->GetMap()))
        {
            handler->PSendSysMessage("Quest Masters do not assist in Mythic difficulty!");
            return true;
        }

        // Check if already summoned for this player
        if (GetQuestMasterFollower(player))
        {
            handler->PSendSysMessage("Quest Master is already with you!");
            return true;
        }

        // Summon (any dungeon participant can summon, not just group leader)
        if (SpawnQuestMasterFollower(player))
        {
            handler->PSendSysMessage("Quest Master has been summoned!");
            return true;
        }

        handler->PSendSysMessage("Failed to summon Quest Master. Please try again.");
        return false;
    }

    static bool HandleDismissQuestMasterCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Check if follower exists
        if (!GetQuestMasterFollower(player))
        {
            handler->PSendSysMessage("No Quest Master is currently following you!");
            return true;
        }

        DespawnQuestMasterFollower(player, true);
        return true;
    }
};

void AddSC_DungeonQuestMasterFollower()
{
    new DungeonQuestMasterFollowerScript();
    new DungeonQuestMasterFollowerGroupScript();
    new DungeonQuestMasterFollowerCommandScript();
}
