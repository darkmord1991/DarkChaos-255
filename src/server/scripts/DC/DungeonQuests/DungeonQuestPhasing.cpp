/*
 * DarkChaos-WoW Dungeon Quest Phasing System
 * Copyright (C) 2025 DarkChaos-WoW
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * Group-based phasing system for dungeon quest NPCs
 * - Solo players: Individual phase per player (based on GUID)
 * - Group members: Shared phase based on group leader's GUID
 * - Dungeon-specific: Phase includes dungeon map ID to prevent cross-dungeon conflicts
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Map.h"
#include "InstanceScript.h"
#include "Group.h"
#include "ObjectAccessor.h"
#include "Config.h"
#include "Chat.h"
#include "Log.h"

// NPC Entry Ranges for Dungeon Quest Masters
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_START = 700000;
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_END = 700052;

// Base phase mask (avoid conflicts with other systems)
constexpr uint32 PHASE_BASE_DUNGEON_QUEST = 10000;

// Dungeon map IDs are provided by AreaDefines.h (MAP_* constants)

class DungeonQuestPhasing : public PlayerScript
{
public:
    DungeonQuestPhasing() : PlayerScript("DungeonQuestPhasing") { }

    // Calculate phase mask for a player based on group status and map
    uint32 CalculatePhaseForPlayer(Player* player)
    {
        if (!player)
            return 1; // Default phase

        uint32 mapId = player->GetMapId();
        
        // Check if player is in a dungeon
        if (!IsDungeonMap(mapId))
            return 1; // Not in dungeon, use default phase

        // Get base phase from group or player GUID
        uint32 basePhase = PHASE_BASE_DUNGEON_QUEST;
        
        Group* group = player->GetGroup();
        if (group && group->GetMembersCount() > 1)
        {
            // Use group leader's GUID as base for shared phase
            ObjectGuid leaderGuid = group->GetLeaderGUID();
            basePhase += (leaderGuid.GetCounter() % 10000); // Modulo to keep numbers reasonable
        }
        else
        {
            // Solo player: use own GUID
            basePhase += (player->GetGUID().GetCounter() % 10000);
        }

        // Add map ID to make phase unique per dungeon
        // This prevents issues if the same player/group enters multiple dungeons
        uint32 mapPhaseModifier = (mapId % 1000) * 100000;
        
        return basePhase + mapPhaseModifier;
    }

    // Check if a map ID is a dungeon
    bool IsDungeonMap(uint32 mapId)
    {
        // Use DBC map entry to determine whether a map is a dungeon.
        // This is more robust than hard-coded MAP_* constants and avoids
        // missing symbol errors if certain MAP_* defines are not present.
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(mapId))
            return mapEntry->IsDungeon();

        return false;
    }

    // Update player phase when entering a map
    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true))
            return;

        // CRITICAL: Do NOT phase players in Mythic/Mythic+ difficulties
        // Quest NPCs should NOT appear in Mythic (difficulty 3) or higher
        Map* map = player->GetMap();
        if (map && map->IsDungeon())
        {
            Difficulty difficulty = map->GetDifficulty();
            if (difficulty >= DUNGEON_DIFFICULTY_EPIC) // Epic = Mythic (3)
            {
                // Keep default phase (1) for Mythic+ runs - no quest NPCs
                if (player->GetPhaseMask() != 1)
                {
                    player->SetPhaseMask(1, true);
                    
                    if (sConfigMgr->GetOption<uint32>("DungeonQuest.Debug.Enable", 0) >= 2)
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Mythic+ detected, phase reset to default (no quest NPCs)");
                    }
                }
                return; // Don't apply dungeon quest phasing
            }
        }

        uint32 newPhase = CalculatePhaseForPlayer(player);
        
        // Only update if phase actually changed
        if (player->GetPhaseMask() != newPhase)
        {
            player->SetPhaseMask(newPhase, true);
            
            if (sConfigMgr->GetOption<uint32>("DungeonQuest.Debug.Enable", 0) >= 2)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Dungeon phase updated to %u (Map: %u)", 
                    newPhase, player->GetMapId());
            }
        }
    }

    // NOTE: Group join/remove events are handled by GroupScript hooks. PlayerScript does not provide
    // direct OnGroupJoin/OnGroupRemove virtuals, so those were removed from here to avoid override errors.

    // Reset phase when leaving dungeon
    void OnPlayerUpdateArea(Player* player, uint32 /*oldArea*/, uint32 /*newArea*/) override
    {
        if (!player)
            return;

        // If leaving a dungeon, reset to default phase
        if (!IsDungeonMap(player->GetMapId()) && player->GetPhaseMask() >= PHASE_BASE_DUNGEON_QUEST)
        {
            player->SetPhaseMask(1, true); // Reset to default phase
            
            if (sConfigMgr->GetOption<uint32>("DungeonQuest.Debug.Enable", 0) >= 2)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Phase reset to default (left dungeon)");
            }
        }
    }
};

// GroupScript to update player phases when group membership changes
class DungeonQuestGroupPhasing : public GroupScript
{
public:
    DungeonQuestGroupPhasing() : GroupScript("DungeonQuestGroupPhasing") {}

    void OnAddMember(Group* /*group*/, ObjectGuid guid) override
    {
        Player* player = ObjectAccessor::FindPlayer(guid);
        if (!player) return;
        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true)) return;

        uint32 mapId = player->GetMapId();
        // Use DBC entry to determine whether the player is in a dungeon
        bool inDungeon = false;
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(mapId))
            inDungeon = mapEntry->IsDungeon();

        if (inDungeon)
        {
            // CRITICAL: Skip phasing for Mythic/Mythic+ difficulties
            Map* map = player->GetMap();
            if (map)
            {
                Difficulty difficulty = map->GetDifficulty();
                if (difficulty >= DUNGEON_DIFFICULTY_EPIC)
                {
                    player->SetPhaseMask(1, true); // Default phase (no quest NPCs)
                    return;
                }
            }
            
            // Calculate phase similar to CalculatePhaseForPlayer
            uint32 basePhase = PHASE_BASE_DUNGEON_QUEST;
            if (Group* grp = player->GetGroup())
            {
                ObjectGuid leaderGuid = grp->GetLeaderGUID();
                basePhase += (leaderGuid.GetCounter() % 10000);
            }
            else
                basePhase += (player->GetGUID().GetCounter() % 10000);

            uint32 mapPhaseModifier = (mapId % 1000) * 100000;
            uint32 newPhase = basePhase + mapPhaseModifier;
            player->SetPhaseMask(newPhase, true);
        }
    }

    void OnRemoveMember(Group* /*group*/, ObjectGuid guid, RemoveMethod /*method*/, ObjectGuid /*kicker*/, const char* /*reason*/) override
    {
        Player* player = ObjectAccessor::FindPlayer(guid);
        if (!player) return;
        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true)) return;

        uint32 mapId = player->GetMapId();
        // If player still in dungeon, switch to solo phase
        bool inDungeon = false;
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(mapId))
            inDungeon = mapEntry->IsDungeon();

        if (inDungeon)
        {
            // CRITICAL: Skip phasing for Mythic/Mythic+ difficulties
            Map* map = player->GetMap();
            if (map)
            {
                Difficulty difficulty = map->GetDifficulty();
                if (difficulty >= DUNGEON_DIFFICULTY_EPIC)
                {
                    player->SetPhaseMask(1, true); // Default phase (no quest NPCs)
                    return;
                }
            }
            
            uint32 basePhase = PHASE_BASE_DUNGEON_QUEST + (player->GetGUID().GetCounter() % 10000);
            uint32 mapPhaseModifier = (mapId % 1000) * 100000;
            uint32 newPhase = basePhase + mapPhaseModifier;
            player->SetPhaseMask(newPhase, true);
        }
    }
};

// Creature script to ensure quest master NPCs use the correct phase
class DungeonQuestMasterPhasing : public CreatureScript
{
public:
    DungeonQuestMasterPhasing() : CreatureScript("DungeonQuestMasterPhasing") { }

    struct DungeonQuestMasterPhasingAI : public ScriptedAI
    {
        DungeonQuestMasterPhasingAI(Creature* creature) : ScriptedAI(creature) { }

        // Use Reset() which is a known virtual in ScriptedAI. This runs when the creature is initialized
        // or its state is reset by the core. We set a very broad phase mask here so dungeon quest masters
        // are visible across the dungeon-related phases.
        void Reset() override
        {
            // Quest masters should be visible in all dungeon phases
            if (me->GetEntry() >= NPC_DUNGEON_QUEST_MASTER_START &&
                me->GetEntry() <= NPC_DUNGEON_QUEST_MASTER_END)
            {
                // Visible in all phases EXCEPT default phase 1.
                // Mythic/Mythic+ players are forced into phase 1 to hide quest NPCs.
                me->SetPhaseMask(0xFFFFFFFE, true);
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new DungeonQuestMasterPhasingAI(creature);
    }
};

void AddSC_DungeonQuestPhasing()
{
    new DungeonQuestPhasing();
    new DungeonQuestMasterPhasing();
    new DungeonQuestGroupPhasing();
}
