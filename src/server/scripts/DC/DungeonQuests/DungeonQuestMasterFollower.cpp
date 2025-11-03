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
#include "Group.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "ChatCommand.h"

using namespace Acore::ChatCommands;

// Default quest master entry (can be configured)
constexpr uint32 DEFAULT_QUEST_MASTER_ENTRY = 700000;
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_START = 700000;
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_END = 700052;

// Storage for active quest master followers
// Key: Player GUID (leader), Value: Creature GUID (follower)
static std::unordered_map<ObjectGuid, ObjectGuid> sQuestMasterFollowers;

// Helper: Get the appropriate quest master entry for a map
static uint32 GetQuestMasterEntryForMap(uint32 mapId)
{
    // You can customize this to return different NPC entries per dungeon
    // For now, return default entry
    (void)mapId;
    return DEFAULT_QUEST_MASTER_ENTRY;
}

// Helper: Spawn quest master follower for player
static Creature* SpawnQuestMasterFollower(Player* player)
{
    if (!player || !player->GetMap())
        return nullptr;

    uint32 entry = GetQuestMasterEntryForMap(player->GetMapId());
    
    // Get spawn position near player
    float x, y, z, o;
    player->GetPosition(x, y, z, o);
    
    // Offset slightly behind player
    float angle = o + M_PI; // 180 degrees behind
    x += 2.0f * cos(angle);
    y += 2.0f * sin(angle);
    
    // Summon as temporary follower
    if (TempSummon* summon = player->SummonCreature(entry, x, y, z, o, TEMPSUMMON_MANUAL_DESPAWN))
    {
        // Configure follower behavior
        summon->SetReactState(REACT_PASSIVE); // Don't attack
        summon->SetUInt32Value(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER);
        
        // Make it follow the player
        summon->GetMotionMaster()->MoveFollow(player, 2.0f, M_PI); // 2 yards behind
        
        // Store mapping
        sQuestMasterFollowers[player->GetGUID()] = summon->GetGUID();
        
        LOG_DEBUG("scripts", "DungeonQuestMaster: Spawned follower {} for player {}", 
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
        
    auto it = sQuestMasterFollowers.find(player->GetGUID());
    if (it == sQuestMasterFollowers.end())
        return;

    if (Creature* follower = ObjectAccessor::GetCreature(*player, it->second))
    {
        follower->DespawnOrUnsummon(0ms);
        LOG_DEBUG("scripts", "DungeonQuestMaster: Despawned follower for player {}", player->GetName());
    }
    
    sQuestMasterFollowers.erase(it);
    
    if (notify)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("Quest Master dismissed.");
    }
}

// Helper: Get active follower for player
static Creature* GetQuestMasterFollower(Player* player)
{
    if (!player)
        return nullptr;
        
    auto it = sQuestMasterFollowers.find(player->GetGUID());
    if (it == sQuestMasterFollowers.end())
        return nullptr;
    
    return ObjectAccessor::GetCreature(*player, it->second);
}

// PlayerScript to handle automatic spawn/despawn
class DungeonQuestMasterFollowerScript : public PlayerScript
{
public:
    DungeonQuestMasterFollowerScript() : PlayerScript("DungeonQuestMasterFollowerScript") { }

    // Spawn follower when group leader enters dungeon
    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;
            
        if (!sConfigMgr->GetOption<bool>("DungeonQuest.FollowerEnable", true))
            return;
        
        // Only spawn for group leaders in dungeons
        Group* group = player->GetGroup();
        if (!group || group->GetLeaderGUID() != player->GetGUID())
            return;
        
        uint32 mapId = player->GetMapId();
        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        if (!mapEntry || !mapEntry->IsDungeon())
            return;
        
        // Check if follower already exists
        if (GetQuestMasterFollower(player))
            return;
        
        // Spawn follower
        if (Creature* follower = SpawnQuestMasterFollower(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("A Quest Master has joined your group!");
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

    void OnLeaderChange(Group* group, ObjectGuid newLeaderGuid, ObjectGuid oldLeaderGuid) override
    {
        if (!group)
            return;
            
        if (!sConfigMgr->GetOption<bool>("DungeonQuest.FollowerEnable", true))
            return;
        
        // Despawn follower from old leader
        if (Player* oldLeader = ObjectAccessor::FindPlayer(oldLeaderGuid))
        {
            DespawnQuestMasterFollower(oldLeader, true);
        }
        
        // Spawn follower for new leader if in dungeon
        if (Player* newLeader = ObjectAccessor::FindPlayer(newLeaderGuid))
        {
            uint32 mapId = newLeader->GetMapId();
            MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
            if (mapEntry && mapEntry->IsDungeon() && !newLeader->IsInCombat())
            {
                if (SpawnQuestMasterFollower(newLeader))
                {
                    ChatHandler(newLeader->GetSession()).PSendSysMessage("A Quest Master has joined your group!");
                }
            }
        }
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
            { "dismiss",  HandleDismissQuestMasterCommand,  SEC_PLAYER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "dcquest", dcquestCommandTable },
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
        if (!mapEntry || !mapEntry->IsDungeon())
        {
            handler->PSendSysMessage("You can only summon the Quest Master inside dungeons!");
            return true;
        }
        
        // Check if player is group leader
        Group* group = player->GetGroup();
        if (!group || group->GetLeaderGUID() != player->GetGUID())
        {
            handler->PSendSysMessage("Only the group leader can summon the Quest Master!");
            return true;
        }
        
        // Check if already summoned
        if (GetQuestMasterFollower(player))
        {
            handler->PSendSysMessage("Quest Master is already with your group!");
            return true;
        }
        
        // Summon
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
