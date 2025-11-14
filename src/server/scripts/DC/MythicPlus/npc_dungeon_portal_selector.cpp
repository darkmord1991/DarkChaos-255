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

// Gossip menu actions
enum DifficultyGossipActions
{
    GOSSIP_ACTION_NORMAL  = 1,
    GOSSIP_ACTION_HEROIC  = 2,
    GOSSIP_ACTION_MYTHIC  = 3,
    GOSSIP_ACTION_INFO    = 4
};

// Gossip menu icons
enum GossipIcons
{
    GOSSIP_ICON_CHAT      = 0,
    GOSSIP_ICON_VENDOR    = 1,
    GOSSIP_ICON_TAXI      = 2,
    GOSSIP_ICON_TRAINER   = 3,
    GOSSIP_ICON_INTERACT  = 4,
    GOSSIP_ICON_MONEY_BAG = 5,
    GOSSIP_ICON_TALK      = 6,
    GOSSIP_ICON_TABARD    = 7,
    GOSSIP_ICON_BATTLE    = 8,
    GOSSIP_ICON_DOT       = 9
};

// Level and item level requirements
struct DifficultyRequirements
{
    uint8 minLevel;
    uint32 minItemLevel;
};

// Get requirements based on expansion
DifficultyRequirements GetDifficultyRequirements(uint8 expansion, Difficulty difficulty)
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
            DifficultyRequirements mythicReq = GetDifficultyRequirements(expansion, DIFFICULTY_10_N);
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
                std::string info = "=== " + profile->name + " ===\n\n";
                
                info += "|cFFFFFFFFNormal:|r Base difficulty\n";
                
                if (profile->heroicEnabled)
                {
                    info += "|cFF0070FFHeroic:|r\n";
                    info += "  • +15% HP and +10% Damage\n";
                    if (profile->expansion == EXPANSION_VANILLA)
                        info += "  • Creature levels: 60-62\n";
                    else if (profile->expansion == EXPANSION_TBC)
                        info += "  • Creature level: 70\n";
                    else
                        info += "  • Creature level: 80\n";
                }
                
                if (profile->mythicEnabled)
                {
                    info += "|cFFFF8000Mythic:|r\n";
                    if (profile->expansion == EXPANSION_WOTLK)
                        info += "  • +80% HP and +80% Damage\n";
                    else
                        info += "  • +200% HP and +100% Damage\n";
                    info += "  • Creature levels: 80-82\n";
                    info += "  • Death budget: " + std::to_string(profile->deathBudget) + "\n";
                    info += "  • Wipe budget: " + std::to_string(profile->wipeBudget) + "\n";
                }
                
                player->SendBroadcastMessage(info.c_str());
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_NORMAL:
            {
                // Set difficulty to Normal and teleport
                player->SetDungeonDifficultyID(DIFFICULTY_NORMAL);
                // TODO: Implement teleport to dungeon entrance
                player->SendBroadcastMessage("Entering Normal difficulty...");
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_HEROIC:
            {
                // Set difficulty to Heroic and teleport
                player->SetDungeonDifficultyID(DIFFICULTY_HEROIC);
                // TODO: Implement teleport to dungeon entrance
                player->SendBroadcastMessage("Entering Heroic difficulty...");
                CloseGossipMenuFor(player);
                break;
            }
            
            case GOSSIP_ACTION_MYTHIC:
            {
                // Set difficulty to Mythic and teleport
                player->SetDungeonDifficultyID(DIFFICULTY_10_N); // Using 10_N as Mythic
                // TODO: Implement teleport to dungeon entrance
                player->SendBroadcastMessage("Entering Mythic difficulty...");
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
