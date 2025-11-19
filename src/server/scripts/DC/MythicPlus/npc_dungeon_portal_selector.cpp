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

// Teleport player to dungeon using teleporter entry from eluna_teleporter table
void TeleportToDungeonEntrance(Player* player, uint32 teleporterEntryId)
{
    if (!player)
        return;
    
    // Query teleporter coordinates from eluna_teleporter table
    QueryResult result = WorldDatabase.Query(
        "SELECT map, x, y, z, o FROM eluna_teleporter WHERE id = {}", teleporterEntryId);

    if (!result)
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Error: Teleporter coordinates not found in database.");
        LOG_ERROR("mythic.portal", "No teleporter entry found for ID {}", teleporterEntryId);
        return;
    }

    Field* fields = result->Fetch();
    uint32 mapId = fields[0].Get<uint32>();
    float x = fields[1].Get<float>();
    float y = fields[2].Get<float>();
    float z = fields[3].Get<float>();
    float o = fields[4].Get<float>();

    z += GetDungeonZOffset(mapId);

    // Teleport player to entrance
    if (player->TeleportTo(mapId, x, y, z, o))
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00Teleporting to dungeon entrance...|r");
        LOG_INFO("mythic.portal", "Player {} teleported via teleporter entry {}",
            player->GetName(), teleporterEntryId);
    }
    else
    {
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Error: Failed to teleport to dungeon entrance.");
        LOG_ERROR("mythic.portal", "Failed to teleport player {} via entry {}",
            player->GetName(), teleporterEntryId);
    }
}

// Generic portal creature script for all dungeon entrances
class npc_dungeon_portal_selector : public CreatureScript
{
public:
    npc_dungeon_portal_selector() : CreatureScript("npc_dungeon_portal_selector") { }

    struct npc_dungeon_portal_selectorAI : public ScriptedAI
    {
        npc_dungeon_portal_selectorAI(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            // Ensure portal is always visible regardless of difficulty
            // Portals spawn in the world (not in dungeons) so they should always be visible
            me->SetPhaseMask(1, true);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_portal_selectorAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        // Show dungeon selection menu - using teleporter entry IDs
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Select Mythic+ Dungeon ===|r", 
            GOSSIP_SENDER_MAIN, 0);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, 0);
        
        // WotLK Dungeons - use teleporter entry IDs from eluna_teleporter table
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Halls of Lightning", GOSSIP_SENDER_MAIN, 151);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Utgarde Tower", GOSSIP_SENDER_MAIN, 152);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Halls of Stone", GOSSIP_SENDER_MAIN, 153);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Violet Citadel", GOSSIP_SENDER_MAIN, 155);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "AhnKahet", GOSSIP_SENDER_MAIN, 157);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Azjol Nerub", GOSSIP_SENDER_MAIN, 158);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Utgarde Keep", GOSSIP_SENDER_MAIN, 160);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Drak Tharon", GOSSIP_SENDER_MAIN, 162);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Culling of Stratholme", GOSSIP_SENDER_MAIN, 163);
        
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

        // If sender is MAIN, this is dungeon selection - show difficulty menu
        if (sender == GOSSIP_SENDER_MAIN && (action == 151 || action == 152 || action == 153 || 
                                             action == 155 || action == 157 || action == 158 || 
                                             action == 160 || action == 162 || action == 163))
        {
            // Store selected teleporter entry in sender for next step
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

        // Sender now contains the teleporter entry ID, action is the difficulty
        uint32 teleporterEntryId = sender;
        
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
        std::string message = "|cff00ff00[Dungeon Portal]|r Teleporting to " + std::string(difficultyLabel) + " entrance...";
        ChatHandler(player->GetSession()).SendSysMessage(message.c_str());
        
        // Teleport player after setting difficulty
        TeleportToDungeonEntrance(player, teleporterEntryId);
        
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_dungeon_portal_selector()
{
    new npc_dungeon_portal_selector();
}
