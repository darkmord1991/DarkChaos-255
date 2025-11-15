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

// Gossip menu actions
enum DifficultyGossipActions
{
    GOSSIP_ACTION_NORMAL  = 1,
    GOSSIP_ACTION_HEROIC  = 2,
    GOSSIP_ACTION_MYTHIC  = 3,
    GOSSIP_ACTION_INFO    = 4
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
        \"SELECT entrance_map, entrance_x, entrance_y, entrance_z, entrance_o \"\n        \"FROM dc_dungeon_entrances WHERE dungeon_map = {}\", mapId);\n    \n    if (!result)\n    {\n        ChatHandler(player->GetSession()).PSendSysMessage(\n            \"Error: Dungeon entrance coordinates not found in database.\");\n        LOG_ERROR(\"mythic.portal\", \"No entrance found for dungeon map {}\", mapId);\n        return;\n    }\n    \n    Field* fields = result->Fetch();\n    uint32 entranceMap = fields[0].Get<uint32>();\n    float x = fields[1].Get<float>();\n    float y = fields[2].Get<float>();\n    float z = fields[3].Get<float>();\n    float o = fields[4].Get<float>();\n    \n    // Teleport player to entrance\n    if (player->TeleportTo(entranceMap, x, y, z, o))\n    {\n        ChatHandler(player->GetSession()).PSendSysMessage(\n            \"|cff00ff00Teleporting to dungeon entrance...|r\");\n        LOG_INFO(\"mythic.portal\", \"Player {} teleported to dungeon {} entrance\",\n            player->GetName(), mapId);\n    }\n    else\n    {\n        ChatHandler(player->GetSession()).PSendSysMessage(\n            \"Error: Failed to teleport to dungeon entrance.\");\n        LOG_ERROR(\"mythic.portal\", \"Failed to teleport player {} to dungeon {}\",\n            player->GetName(), mapId);\n    }\n}

// Generic portal creature script for all dungeon entrances
class npc_dungeon_portal_selector : public CreatureScript
{
public:
    npc_dungeon_portal_selector() : CreatureScript("npc_dungeon_portal_selector") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Get dungeon info from creature's AI data or database
        uint32 mapId = creature->GetEntry(); // TODO: Map entry to dungeon mapId properly
        
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(mapId);
        if (!profile)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "This dungeon is not configured for difficulty selection.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }
        
        uint8 expansion = profile->expansion;
        std::string dungeonName = profile->name;
        
        // Build gossip menu
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cFF00FF00[Information]|r View difficulty details", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        
        // Normal difficulty (always available)
        DifficultyRequirements normalReq = GetDifficultyRequirements(expansion, DIFFICULTY_NORMAL);
        if (player->GetLevel() >= normalReq.minLevel)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cFFFFFFFF[Normal]|r Enter " + dungeonName, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_NORMAL);
        }
        else
        {
            std::string lockMsg = "|cFF808080[Normal]|r Requires level " + std::to_string(normalReq.minLevel);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, lockMsg, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        }
        
        // Heroic difficulty
        if (profile->heroicEnabled)
        {
            DifficultyRequirements heroicReq = GetDifficultyRequirements(expansion, DIFFICULTY_HEROIC);
            uint32 playerItemLevel = player->GetAverageItemLevel();
            
            if (player->GetLevel() >= heroicReq.minLevel && playerItemLevel >= heroicReq.minItemLevel)
            {
                std::string heroicText = "|cFF0070FF[Heroic]|r Enter " + dungeonName + " (Level ";
                if (expansion == EXPANSION_VANILLA)
                    heroicText += "60-62, +15% difficulty)";
                else if (expansion == EXPANSION_TBC)
                    heroicText += "70, +15% difficulty)";
                else
                    heroicText += "80, +15% difficulty)";
                    
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, heroicText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_HEROIC);
            }
            else
            {
                std::string lockMsg = "|cFF808080[Heroic]|r Requires level " + std::to_string(heroicReq.minLevel) + 
                                     ", item level " + std::to_string(heroicReq.minItemLevel);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, lockMsg, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
            }
        }
        
        // Mythic difficulty
        if (profile->mythicEnabled)
        {
            DifficultyRequirements mythicReq = GetDifficultyRequirements(expansion, DIFFICULTY_MYTHIC);
            uint32 playerItemLevel = player->GetAverageItemLevel();
            
            if (player->GetLevel() >= mythicReq.minLevel && playerItemLevel >= mythicReq.minItemLevel)
            {
                std::string mythicText = "|cFFFF8000[Mythic]|r Enter " + dungeonName + " (Level 80-82";
                if (expansion == EXPANSION_WOTLK)
                    mythicText += ", +80% difficulty)";
                else
                    mythicText += ", +200% difficulty)";
                    
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, mythicText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_MYTHIC);
            }
            else
            {
                std::string lockMsg = "|cFF808080[Mythic]|r Requires level " + std::to_string(mythicReq.minLevel) + 
                                     ", item level " + std::to_string(mythicReq.minItemLevel);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, lockMsg, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
            }
        }
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        
        uint32 mapId = creature->GetEntry(); // TODO: Map entry to dungeon mapId
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(mapId);
        
        if (!profile)
        {
            CloseGossipMenuFor(player);
            return true;
        }
        
        switch (action)
        {
            case GOSSIP_ACTION_INFO:
            {
                // Show detailed difficulty information
                ChatHandler handler(player->GetSession());
                handler.PSendSysMessage("=== %s ===", profile->name.c_str());
                handler.PSendSysMessage(" ");
                handler.PSendSysMessage("Normal: Base difficulty");
                
                if (profile->heroicEnabled)
                {
                    handler.PSendSysMessage("Heroic:");
                    handler.PSendSysMessage("  - +15%% HP and +10%% Damage");
                    if (profile->expansion == EXPANSION_VANILLA)
                        handler.PSendSysMessage("  - Creature levels: 60-62");
                    else if (profile->expansion == EXPANSION_TBC)
                        handler.PSendSysMessage("  - Creature level: 70");
                    else
                        handler.PSendSysMessage("  - Creature level: 80");
                }
                
                if (profile->mythicEnabled)
                {
                    handler.PSendSysMessage("Mythic:");
                    if (profile->expansion == EXPANSION_WOTLK)
                        handler.PSendSysMessage("  - +80%% HP and +80%% Damage");
                    else
                        handler.PSendSysMessage("  - +200%% HP and +100%% Damage");
                    handler.PSendSysMessage("  - Creature levels: 80-82");
                    handler.PSendSysMessage("  - Death budget: %u", static_cast<uint32>(profile->deathBudget));
                    handler.PSendSysMessage("  - Wipe budget: %u", static_cast<uint32>(profile->wipeBudget));
                }
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_NORMAL:
            {
                // Set difficulty to Normal and teleport
                player->SetDungeonDifficulty(Difficulty(DUNGEON_DIFFICULTY_NORMAL));
                TeleportToDungeonEntrance(player, mapId);
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_HEROIC:
            {
                // Set difficulty to Heroic and teleport
                player->SetDungeonDifficulty(Difficulty(DUNGEON_DIFFICULTY_HEROIC));
                TeleportToDungeonEntrance(player, mapId);
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_MYTHIC:
            {
                // Set difficulty to Mythic and teleport
                player->SetDungeonDifficulty(Difficulty(DUNGEON_DIFFICULTY_EPIC));
                TeleportToDungeonEntrance(player, mapId);
                CloseGossipMenuFor(player);
                break;
            }
            
            default:
                CloseGossipMenuFor(player);
                break;
        }
        
        return true;
    }
};

void AddSC_dungeon_portal_selector()
{
    new npc_dungeon_portal_selector();
}
