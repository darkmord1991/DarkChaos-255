/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Dungeon Portal Difficulty Selector
 * Allows players to select Normal/Heroic/Mythic difficulty before entering dungeons
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicDifficultyScaling.h"
#include "WorldSession.h"
#include "Map.h"
#include "Log.h"
#include "DC/DungeonQuests/DungeonQuestConstants.h"

namespace
{
float GetDungeonZOffset(uint32 dungeonMapId)
{
    switch (dungeonMapId)
    {
        case 599: // Halls of Stone
            return 3.0f;
        case 602: // Halls of Lightning
            return 4.0f;
        default:
            return 0.0f;
    }
}
}

// Gossip menu actions
enum DifficultyGossipActions
{
    GOSSIP_ACTION_NORMAL  = 1,
    GOSSIP_ACTION_HEROIC  = 2,
    GOSSIP_ACTION_MYTHIC  = 3,
    GOSSIP_ACTION_INFO    = 4,
    GOSSIP_ACTION_CONFIRM_NORMAL = 5,
    GOSSIP_ACTION_CONFIRM_HEROIC = 6,
    GOSSIP_ACTION_CONFIRM_MYTHIC = 7
};

using namespace DungeonQuest;

// Level and item level requirements
struct DifficultyRequirements
{
    uint8 minLevel;
    uint32 minItemLevel;
};

// Get requirements based on expansion
DifficultyRequirements GetDifficultyRequirements(uint8 expansion, uint8 difficulty)
{
    DifficultyRequirements req;
    
    switch (expansion)
    {
        case EXPANSION_VANILLA:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 55;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 60;
                req.minItemLevel = 100;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        case EXPANSION_TBC:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 68;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 70;
                req.minItemLevel = 120;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        case EXPANSION_WOTLK:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 78;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 80;
                req.minItemLevel = 150;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        default:
            req.minLevel = 1;
            req.minItemLevel = 0;
            break;
    }
    
    return req;
}

// Teleport player to dungeon entrance using dc_dungeon_entrances table
void TeleportToDungeonEntrance(Player* player, uint32 mapId)
{
    if (!player)
        return;
    
    // Query entrance coordinates from database
    QueryResult result = WorldDatabase.Query(
        "SELECT entrance_map, entrance_x, entrance_y, entrance_z, entrance_o "
        "FROM dc_dungeon_entrances WHERE dungeon_map = {}", mapId);

    if (!result)
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Error: Dungeon entrance coordinates not found in database.");
        LOG_ERROR("mythic.portal", "No entrance found for dungeon map {}", mapId);
        return;
    }

    Field* fields = result->Fetch();
    uint32 entranceMap = fields[0].Get<uint32>();
    float x = fields[1].Get<float>();
    float y = fields[2].Get<float>();
    float z = fields[3].Get<float>();
    float o = fields[4].Get<float>();

    z += GetDungeonZOffset(mapId);

    // Teleport player to entrance
    if (player->TeleportTo(entranceMap, x, y, z, o))
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00Teleporting to dungeon entrance...|r");
        LOG_INFO("mythic.portal", "Player {} teleported to dungeon {} entrance",
            player->GetName(), mapId);
    }
    else
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Error: Failed to teleport to dungeon entrance.");
        LOG_ERROR("mythic.portal", "Failed to teleport player {} to dungeon {}",
            player->GetName(), mapId);
    }
}

// Generic portal creature script for all dungeon entrances
class npc_dungeon_portal_selector : public CreatureScript
{
public:
    npc_dungeon_portal_selector() : CreatureScript("npc_dungeon_portal_selector") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        // Show dungeon selection menu - using map IDs as action values
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Select Dungeon ===|r", 
            GOSSIP_SENDER_MAIN, 0);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, 0);
        
        // WotLK Dungeons - use mapId as action
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Utgarde Keep", GOSSIP_SENDER_MAIN, 574);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Utgarde Pinnacle", GOSSIP_SENDER_MAIN, 575);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "The Nexus", GOSSIP_SENDER_MAIN, 576);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Azjol-Nerub", GOSSIP_SENDER_MAIN, 601);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Ahn'kahet", GOSSIP_SENDER_MAIN, 619);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Drak'Tharon Keep", GOSSIP_SENDER_MAIN, 600);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Halls of Stone", GOSSIP_SENDER_MAIN, 599);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Halls of Lightning", GOSSIP_SENDER_MAIN, 602);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "The Culling of Stratholme", GOSSIP_SENDER_MAIN, 595);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        // If action is 0, just close (was a header)
        if (action == 0)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // If sender is 0, this is dungeon selection - show difficulty menu
        if (sender == GOSSIP_SENDER_MAIN && action >= 574)
        {
            // Store selected dungeon map in sender for next step
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff8000=== Select Difficulty ===|r", 
                action, 0);
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", action, 0);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cffffffff[Normal]|r - Base difficulty", 
                action, GOSSIP_ACTION_NORMAL);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cff0070ff[Heroic]|r - +15% HP/Damage", 
                action, GOSSIP_ACTION_HEROIC);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cffff8000[Mythic]|r - Mythic+ difficulty", 
                action, GOSSIP_ACTION_MYTHIC);
            
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Sender now contains the dungeon mapId, action is the difficulty
        uint32 dungeonMapId = sender;
        
        Difficulty selectedDifficulty = DUNGEON_DIFFICULTY_NORMAL;
        const char* difficultyLabel = "|cffffffffNormal|r";

        switch (action)
        {
            case GOSSIP_ACTION_NORMAL:
                selectedDifficulty = DUNGEON_DIFFICULTY_NORMAL;
                difficultyLabel = "|cffffffffNormal|r";
                break;
            case GOSSIP_ACTION_HEROIC:
                selectedDifficulty = DUNGEON_DIFFICULTY_HEROIC;
                difficultyLabel = "|cff0070ffHeroic|r";
                break;
            case GOSSIP_ACTION_MYTHIC:
                selectedDifficulty = DUNGEON_DIFFICULTY_EPIC;
                difficultyLabel = "|cffff8000Mythic|r";
                break;
            default:
                break;
        }

        player->SetDungeonDifficulty(selectedDifficulty);
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00[Dungeon Portal]|r Teleporting to %s entrance...", difficultyLabel);
        
        // Teleport player after setting difficulty
        TeleportToDungeonEntrance(player, dungeonMapId);
        
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_dungeon_portal_selector()
{
    new npc_dungeon_portal_selector();
}
