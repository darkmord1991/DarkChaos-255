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
#include "Config.h"
#include "Chat.h"
#include "Log.h"

// NPC Entry Ranges for Dungeon Quest Masters
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_START = 700000;
constexpr uint32 NPC_DUNGEON_QUEST_MASTER_END = 700052;

// Base phase mask (avoid conflicts with other systems)
constexpr uint32 PHASE_BASE_DUNGEON_QUEST = 10000;

// Dungeon map IDs (Classic, TBC, WotLK)
// Classic Dungeons
constexpr uint32 MAP_RAGEFIRE_CHASM = 389;
constexpr uint32 MAP_WAILING_CAVERNS = 43;
constexpr uint32 MAP_DEADMINES = 36;
constexpr uint32 MAP_SHADOWFANG_KEEP = 33;
constexpr uint32 MAP_BLACKFATHOM_DEEPS = 48;
constexpr uint32 MAP_STOCKADE = 34;
constexpr uint32 MAP_GNOMEREGAN = 90;
constexpr uint32 MAP_RAZORFEN_KRAUL = 47;
constexpr uint32 MAP_SCARLET_MONASTERY = 189;
constexpr uint32 MAP_RAZORFEN_DOWNS = 129;
constexpr uint32 MAP_ULDAMAN = 70;
constexpr uint32 MAP_ZULFARRAK = 209;
constexpr uint32 MAP_MARAUDON = 349;
constexpr uint32 MAP_SUNKEN_TEMPLE = 109;
constexpr uint32 MAP_BLACKROCK_DEPTHS = 230;
constexpr uint32 MAP_DIRE_MAUL = 429;
constexpr uint32 MAP_SCHOLOMANCE = 289;
constexpr uint32 MAP_STRATHOLME = 329;
constexpr uint32 MAP_BLACKROCK_SPIRE = 229;

// TBC Dungeons
constexpr uint32 MAP_HELLFIRE_RAMPARTS = 543;
constexpr uint32 MAP_BLOOD_FURNACE = 542;
constexpr uint32 MAP_SHATTERED_HALLS = 540;
constexpr uint32 MAP_SLAVE_PENS = 547;
constexpr uint32 MAP_UNDERBOG = 546;
constexpr uint32 MAP_STEAMVAULT = 545;
constexpr uint32 MAP_MANA_TOMBS = 557;
constexpr uint32 MAP_AUCHENAI_CRYPTS = 558;
constexpr uint32 MAP_SETHEKK_HALLS = 556;
constexpr uint32 MAP_SHADOW_LABYRINTH = 555;
constexpr uint32 MAP_OLD_HILLSBRAD = 560;
constexpr uint32 MAP_BLACK_MORASS = 269;
constexpr uint32 MAP_MECHANAR = 554;
constexpr uint32 MAP_BOTANICA = 553;
constexpr uint32 MAP_ARCATRAZ = 552;
constexpr uint32 MAP_MAGISTERS_TERRACE = 585;

// WotLK Dungeons
constexpr uint32 MAP_UTGARDE_KEEP = 574;
constexpr uint32 MAP_NEXUS = 576;
constexpr uint32 MAP_AZJOL_NERUB = 601;
constexpr uint32 MAP_AHNKAHET = 619;
constexpr uint32 MAP_DRAK_THARON = 600;
constexpr uint32 MAP_VIOLET_HOLD = 608;
constexpr uint32 MAP_GUNDRAK = 604;
constexpr uint32 MAP_HALLS_OF_STONE = 599;
constexpr uint32 MAP_HALLS_OF_LIGHTNING = 602;
constexpr uint32 MAP_OCULUS = 578;
constexpr uint32 MAP_CULLING_OF_STRATHOLME = 595;
constexpr uint32 MAP_UTGARDE_PINNACLE = 575;
constexpr uint32 MAP_TRIAL_OF_CHAMPION = 650;
constexpr uint32 MAP_FORGE_OF_SOULS = 632;
constexpr uint32 MAP_PIT_OF_SARON = 658;
constexpr uint32 MAP_HALLS_OF_REFLECTION = 668;

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
        // Classic dungeons
        if (mapId == MAP_RAGEFIRE_CHASM || mapId == MAP_WAILING_CAVERNS ||
            mapId == MAP_DEADMINES || mapId == MAP_SHADOWFANG_KEEP ||
            mapId == MAP_BLACKFATHOM_DEEPS || mapId == MAP_STOCKADE ||
            mapId == MAP_GNOMEREGAN || mapId == MAP_RAZORFEN_KRAUL ||
            mapId == MAP_SCARLET_MONASTERY || mapId == MAP_RAZORFEN_DOWNS ||
            mapId == MAP_ULDAMAN || mapId == MAP_ZULFARRAK ||
            mapId == MAP_MARAUDON || mapId == MAP_SUNKEN_TEMPLE ||
            mapId == MAP_BLACKROCK_DEPTHS || mapId == MAP_DIRE_MAUL ||
            mapId == MAP_SCHOLOMANCE || mapId == MAP_STRATHOLME ||
            mapId == MAP_BLACKROCK_SPIRE)
            return true;

        // TBC dungeons
        if (mapId == MAP_HELLFIRE_RAMPARTS || mapId == MAP_BLOOD_FURNACE ||
            mapId == MAP_SHATTERED_HALLS || mapId == MAP_SLAVE_PENS ||
            mapId == MAP_UNDERBOG || mapId == MAP_STEAMVAULT ||
            mapId == MAP_MANA_TOMBS || mapId == MAP_AUCHENAI_CRYPTS ||
            mapId == MAP_SETHEKK_HALLS || mapId == MAP_SHADOW_LABYRINTH ||
            mapId == MAP_OLD_HILLSBRAD || mapId == MAP_BLACK_MORASS ||
            mapId == MAP_MECHANAR || mapId == MAP_BOTANICA ||
            mapId == MAP_ARCATRAZ || mapId == MAP_MAGISTERS_TERRACE)
            return true;

        // WotLK dungeons
        if (mapId == MAP_UTGARDE_KEEP || mapId == MAP_NEXUS ||
            mapId == MAP_AZJOL_NERUB || mapId == MAP_AHNKAHET ||
            mapId == MAP_DRAK_THARON || mapId == MAP_VIOLET_HOLD ||
            mapId == MAP_GUNDRAK || mapId == MAP_HALLS_OF_STONE ||
            mapId == MAP_HALLS_OF_LIGHTNING || mapId == MAP_OCULUS ||
            mapId == MAP_CULLING_OF_STRATHOLME || mapId == MAP_UTGARDE_PINNACLE ||
            mapId == MAP_TRIAL_OF_CHAMPION || mapId == MAP_FORGE_OF_SOULS ||
            mapId == MAP_PIT_OF_SARON || mapId == MAP_HALLS_OF_REFLECTION)
            return true;

        return false;
    }

    // Update player phase when entering a map
    void OnMapChanged(Player* player) override
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true))
            return;

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

    // Update phase when joining a group
    void OnGroupJoin(Player* player, Group* group) override
    {
        if (!player || !group)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true))
            return;

        // If in a dungeon, update to group phase
        if (IsDungeonMap(player->GetMapId()))
        {
            uint32 newPhase = CalculatePhaseForPlayer(player);
            player->SetPhaseMask(newPhase, true);

            if (sConfigMgr->GetOption<uint32>("DungeonQuest.Debug.Enable", 0) >= 1)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Joined group phase for dungeon quests.");
            }
        }
    }

    // Update phase when leaving a group
    void OnGroupRemove(Player* player, Group* /*group*/, RemoveMethod /*method*/, ObjectGuid /*kicker*/, char const* /*reason*/) override
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>("DungeonQuest.Enable", true))
            return;

        // If in a dungeon, update to solo phase
        if (IsDungeonMap(player->GetMapId()))
        {
            uint32 newPhase = CalculatePhaseForPlayer(player);
            player->SetPhaseMask(newPhase, true);

            if (sConfigMgr->GetOption<uint32>("DungeonQuest.Debug.Enable", 0) >= 1)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Switched to solo phase for dungeon quests.");
            }
        }
    }

    // Reset phase when leaving dungeon
    void OnPlayerLeaveArea(Player* player, uint32 /*newArea*/, uint32 /*oldArea*/) override
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

// Creature script to ensure quest master NPCs use the correct phase
class DungeonQuestMasterPhasing : public CreatureScript
{
public:
    DungeonQuestMasterPhasing() : CreatureScript("DungeonQuestMasterPhasing") { }

    struct DungeonQuestMasterPhasingAI : public ScriptedAI
    {
        DungeonQuestMasterPhasingAI(Creature* creature) : ScriptedAI(creature) { }

        void JustAppeared() override
        {
            // Quest masters should be visible in all dungeon phases
            // Set a broad phase mask that covers all possible dungeon quest phases
            if (me->GetEntry() >= NPC_DUNGEON_QUEST_MASTER_START && 
                me->GetEntry() <= NPC_DUNGEON_QUEST_MASTER_END)
            {
                // Use a very high phase mask to be visible across multiple phases
                // This is intentional - NPCs need to be accessible to all players/groups
                me->SetPhaseMask(0xFFFFFFFF, true); // All phases
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
}
