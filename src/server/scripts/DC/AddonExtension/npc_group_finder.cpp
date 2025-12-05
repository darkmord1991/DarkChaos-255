/*
 * Dark Chaos - Group Finder NPC
 * =============================
 * 
 * Provides an in-game NPC interface for the Group Finder system.
 * Opens the DC-MythicPlus addon panel for advanced features.
 * 
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "GossipDef.h"
#include "ScriptedGossip.h"
#include "WorldSession.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "DCAddonNamespace.h"

namespace DCAddon
{

// NPC Entry ID - Update this in SQL to match your creature template
constexpr uint32 NPC_GROUP_FINDER = 600100;

// Gossip Menu IDs
constexpr uint32 GOSSIP_MENU_MAIN        = 60010;
constexpr uint32 GOSSIP_MENU_MYTHIC      = 60011;
constexpr uint32 GOSSIP_MENU_RAID        = 60012;
constexpr uint32 GOSSIP_MENU_EVENTS      = 60013;

// Gossip Option IDs
enum GroupFinderOptions
{
    OPTION_MYTHIC_DUNGEON     = 1,
    OPTION_RAID_FINDER        = 2,
    OPTION_SCHEDULED_EVENTS   = 3,
    OPTION_MY_LISTINGS        = 4,
    OPTION_MY_APPLICATIONS    = 5,
    OPTION_SET_DUNGEON_DIFF   = 10,
    OPTION_SET_RAID_DIFF      = 11,
    OPTION_SPECTATE           = 20,
    OPTION_CLOSE              = 99,
};

class npc_group_finder : public CreatureScript
{
public:
    npc_group_finder() : CreatureScript("npc_group_finder") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        
        // Main menu options
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
            "|TInterface\\Icons\\achievement_dungeon_gloryofthehero:24:24|t Mythic+ Dungeon Finder",
            GOSSIP_SENDER_MAIN, OPTION_MYTHIC_DUNGEON);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            "|TInterface\\Icons\\achievement_dungeon_icecrown:24:24|t Raid Finder",
            GOSSIP_SENDER_MAIN, OPTION_RAID_FINDER);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\inv_misc_note_05:24:24|t Scheduled Events",
            GOSSIP_SENDER_MAIN, OPTION_SCHEDULED_EVENTS);
        
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
            "|TInterface\\Icons\\inv_misc_groupneedmore:24:24|t My Active Listings",
            GOSSIP_SENDER_MAIN, OPTION_MY_LISTINGS);
        
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
            "|TInterface\\Icons\\inv_misc_note_02:24:24|t My Applications",
            GOSSIP_SENDER_MAIN, OPTION_MY_APPLICATIONS);
        
        // Difficulty settings
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER,
            "|TInterface\\Icons\\spell_nature_wispsplode:24:24|t Set Dungeon Difficulty",
            GOSSIP_SENDER_MAIN, OPTION_SET_DUNGEON_DIFF);
        
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER,
            "|TInterface\\Icons\\spell_shadow_twilight:24:24|t Set Raid Difficulty",
            GOSSIP_SENDER_MAIN, OPTION_SET_RAID_DIFF);
        
        AddGossipItemFor(player, GOSSIP_ICON_TAXI,
            "|TInterface\\Icons\\ability_hunter_snipershot:24:24|t Spectate M+ Runs",
            GOSSIP_SENDER_MAIN, OPTION_SPECTATE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, OPTION_CLOSE);
        
        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        
        switch (action)
        {
            case OPTION_MYTHIC_DUNGEON:
                ShowMythicMenu(player, creature);
                break;
                
            case OPTION_RAID_FINDER:
                ShowRaidMenu(player, creature);
                break;
                
            case OPTION_SCHEDULED_EVENTS:
                // Open the addon's event panel
                ChatHandler(player->GetSession()).PSendSysMessage("Opening Scheduled Events... Use /grpf events");
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_SCHEDULED_EVENTS)
                    .Set("openPanel", true)
                    .Send(player);
                CloseGossipMenuFor(player);
                break;
                
            case OPTION_MY_LISTINGS:
                ShowMyListings(player);
                CloseGossipMenuFor(player);
                break;
                
            case OPTION_MY_APPLICATIONS:
                ShowMyApplications(player);
                CloseGossipMenuFor(player);
                break;
                
            case OPTION_SET_DUNGEON_DIFF:
                ShowDungeonDifficultyMenu(player, creature);
                break;
                
            case OPTION_SET_RAID_DIFF:
                ShowRaidDifficultyMenu(player, creature);
                break;
                
            case OPTION_SPECTATE:
                ShowSpectateList(player);
                CloseGossipMenuFor(player);
                break;
                
            // Dungeon difficulty options (100-103)
            case 100: SetDungeonDifficulty(player, DUNGEON_DIFFICULTY_NORMAL); break;
            case 101: SetDungeonDifficulty(player, DUNGEON_DIFFICULTY_HEROIC); break;
            case 102: SetDungeonDifficulty(player, DUNGEON_DIFFICULTY_EPIC); break;
            
            // Raid difficulty options (110-113)
            case 110: SetRaidDifficulty(player, RAID_DIFFICULTY_10MAN_NORMAL); break;
            case 111: SetRaidDifficulty(player, RAID_DIFFICULTY_25MAN_NORMAL); break;
            case 112: SetRaidDifficulty(player, RAID_DIFFICULTY_10MAN_HEROIC); break;
            case 113: SetRaidDifficulty(player, RAID_DIFFICULTY_25MAN_HEROIC); break;
                
            case OPTION_CLOSE:
            default:
                CloseGossipMenuFor(player);
                break;
        }
        
        return true;
    }

private:
    void ShowMythicMenu(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            "Browse Available M+ Groups",
            GOSSIP_SENDER_MAIN, 200);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            "Create M+ Group Listing",
            GOSSIP_SENDER_MAIN, 201);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            "View My Keystone",
            GOSSIP_SENDER_MAIN, 202);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
    }
    
    void ShowRaidMenu(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            "Browse Available Raid Groups",
            GOSSIP_SENDER_MAIN, 210);
        
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            "Create Raid Group Listing",
            GOSSIP_SENDER_MAIN, 211);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
    }
    
    void ShowDungeonDifficultyMenu(Player* player, Creature* creature)
    {
        Difficulty current = player->GetDungeonDifficulty();
        
        AddGossipItemFor(player, current == DUNGEON_DIFFICULTY_NORMAL ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\spell_nature_healingtouch:24:24|t Normal (5-man)",
            GOSSIP_SENDER_MAIN, 100);
        
        AddGossipItemFor(player, current == DUNGEON_DIFFICULTY_HEROIC ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\achievement_dungeon_heroic_gloryoftheraider:24:24|t Heroic (5-man)",
            GOSSIP_SENDER_MAIN, 101);
        
        AddGossipItemFor(player, current == DUNGEON_DIFFICULTY_EPIC ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\spell_deathknight_explode_ghoul:24:24|t Mythic (5-man)",
            GOSSIP_SENDER_MAIN, 102);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
    }
    
    void ShowRaidDifficultyMenu(Player* player, Creature* creature)
    {
        Difficulty current = player->GetRaidDifficulty();
        
        AddGossipItemFor(player, current == RAID_DIFFICULTY_10MAN_NORMAL ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\achievement_dungeon_naxxramas_10man:24:24|t 10-Man Normal",
            GOSSIP_SENDER_MAIN, 110);
        
        AddGossipItemFor(player, current == RAID_DIFFICULTY_25MAN_NORMAL ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\achievement_dungeon_naxxramas_25man:24:24|t 25-Man Normal",
            GOSSIP_SENDER_MAIN, 111);
        
        AddGossipItemFor(player, current == RAID_DIFFICULTY_10MAN_HEROIC ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\achievement_dungeon_naxxramas_heroic:24:24|t 10-Man Heroic",
            GOSSIP_SENDER_MAIN, 112);
        
        AddGossipItemFor(player, current == RAID_DIFFICULTY_25MAN_HEROIC ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_CHAT,
            "|TInterface\\Icons\\achievement_dungeon_naxxramas_25man:24:24|t 25-Man Heroic",
            GOSSIP_SENDER_MAIN, 113);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
    }
    
    void SetDungeonDifficulty(Player* player, Difficulty difficulty)
    {
        if (player->GetGroup())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You cannot change difficulty while in a group.");
            return;
        }
        
        player->SetDungeonDifficulty(difficulty);
        
        std::string diffName;
        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_NORMAL: diffName = "Normal"; break;
            case DUNGEON_DIFFICULTY_HEROIC: diffName = "Heroic"; break;
            case DUNGEON_DIFFICULTY_EPIC:   diffName = "Mythic"; break;
            default: diffName = "Unknown"; break;
        }
        
        ChatHandler(player->GetSession()).PSendSysMessage("Dungeon difficulty set to: %s", diffName.c_str());
        
        // Notify addon
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_DIFFICULTY_CHANGED)
            .Set("type", "dungeon")
            .Set("difficultyId", static_cast<int32>(difficulty))
            .Set("difficultyName", diffName)
            .Send(player);
        
        CloseGossipMenuFor(player);
    }
    
    void SetRaidDifficulty(Player* player, Difficulty difficulty)
    {
        if (player->GetGroup())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You cannot change difficulty while in a group.");
            return;
        }
        
        player->SetRaidDifficulty(difficulty);
        
        std::string diffName;
        switch (difficulty)
        {
            case RAID_DIFFICULTY_10MAN_NORMAL: diffName = "10-Man Normal"; break;
            case RAID_DIFFICULTY_25MAN_NORMAL: diffName = "25-Man Normal"; break;
            case RAID_DIFFICULTY_10MAN_HEROIC: diffName = "10-Man Heroic"; break;
            case RAID_DIFFICULTY_25MAN_HEROIC: diffName = "25-Man Heroic"; break;
            default: diffName = "Unknown"; break;
        }
        
        ChatHandler(player->GetSession()).PSendSysMessage("Raid difficulty set to: %s", diffName.c_str());
        
        // Notify addon
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_DIFFICULTY_CHANGED)
            .Set("type", "raid")
            .Set("difficultyId", static_cast<int32>(difficulty))
            .Set("difficultyName", diffName)
            .Send(player);
        
        CloseGossipMenuFor(player);
    }
    
    void ShowMyListings(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT id, dungeon_name, keystone_level, current_tank + current_healer + current_dps as current, "
            "need_tank + need_healer + need_dps as needed "
            "FROM dc_group_finder_listings WHERE leader_guid = {} AND status = 1",
            guid);
        
        if (!result)
        {
            ChatHandler(player->GetSession()).SendSysMessage("You have no active listings.");
            return;
        }
        
        ChatHandler(player->GetSession()).SendSysMessage("=== Your Active Listings ===");
        do
        {
            uint32 id = (*result)[0].Get<uint32>();
            std::string dungeon = (*result)[1].Get<std::string>();
            uint8 keyLevel = (*result)[2].Get<uint8>();
            uint8 current = (*result)[3].Get<uint8>();
            uint8 needed = (*result)[4].Get<uint8>();
            
            ChatHandler(player->GetSession()).PSendSysMessage("[%u] %s +%u (%u/%u members)",
                id, dungeon.c_str(), keyLevel, current, current + needed);
        } while (result->NextRow());
    }
    
    void ShowMyApplications(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT a.listing_id, l.dungeon_name, l.keystone_level, a.status "
            "FROM dc_group_finder_applications a "
            "JOIN dc_group_finder_listings l ON a.listing_id = l.id "
            "WHERE a.player_guid = {} AND a.status = 0",
            guid);
        
        if (!result)
        {
            ChatHandler(player->GetSession()).SendSysMessage("You have no pending applications.");
            return;
        }
        
        ChatHandler(player->GetSession()).SendSysMessage("=== Your Pending Applications ===");
        do
        {
            uint32 listingId = (*result)[0].Get<uint32>();
            std::string dungeon = (*result)[1].Get<std::string>();
            uint8 keyLevel = (*result)[2].Get<uint8>();
            
            ChatHandler(player->GetSession()).PSendSysMessage("[%u] %s +%u - Pending",
                listingId, dungeon.c_str(), keyLevel);
        } while (result->NextRow());
    }
    
    void ShowSpectateList(Player* player)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT r.run_id, d.dungeon_name, r.key_level, c.name "
            "FROM dc_mythic_plus_runs r "
            "LEFT JOIN dc_mythic_plus_dungeons d ON r.map_id = d.map_id "
            "LEFT JOIN characters c ON r.leader_guid = c.guid "
            "WHERE r.status = 1 AND r.allow_spectate = 1 "
            "ORDER BY r.key_level DESC LIMIT 10");
        
        if (!result)
        {
            ChatHandler(player->GetSession()).SendSysMessage("No runs available for spectating.");
            return;
        }
        
        ChatHandler(player->GetSession()).SendSysMessage("=== Available Runs to Spectate ===");
        do
        {
            uint32 runId = (*result)[0].Get<uint32>();
            std::string dungeon = (*result)[1].Get<std::string>();
            uint8 keyLevel = (*result)[2].Get<uint8>();
            std::string leader = (*result)[3].Get<std::string>();
            
            ChatHandler(player->GetSession()).PSendSysMessage("[%u] %s +%u (Leader: %s)",
                runId, dungeon.c_str(), keyLevel, leader.c_str());
        } while (result->NextRow());
        
        ChatHandler(player->GetSession()).SendSysMessage("Use /grpf spectate <runId> to start spectating.");
    }
};

}  // namespace DCAddon

void AddSC_npc_group_finder()
{
    new DCAddon::npc_group_finder();
}
