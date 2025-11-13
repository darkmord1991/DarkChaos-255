/*
 * ============================================================================
 * Dungeon Enhancement System - Font of Power GameObject
 * ============================================================================
 * Purpose: Activate keystones to start Mythic+ runs
 * GameObject IDs: 700001-700008 (one per dungeon)
 * Location: Inside dungeon entrances
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Group.h"
#include "Map.h"
#include "InstanceScript.h"
#include "ScriptedGossip.h"
#include "GameObject.h"
#include "../Core/DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"
#include "../Core/MythicDifficultyScaling.h"
#include "../Core/MythicRunTracker.h"
#include "../Affixes/MythicAffixFactory.h"

using namespace DungeonEnhancement;

class go_mythic_plus_font_of_power : public GameObjectScript
{
public:
    go_mythic_plus_font_of_power() : GameObjectScript("go_mythic_plus_font_of_power") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Dungeon Enhancement system is currently disabled.");
            return true;
        }

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000Font of Power can only be used inside dungeons.|r"
            );
            return true;
        }

        uint16 mapId = map->GetId();
        uint32 instanceId = map->GetInstanceId();

        // Check if run already active
        if (MythicRunTracker::IsRunActive(instanceId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000A Mythic+ run is already in progress in this instance.|r"
            );
            return true;
        }

        // Check if dungeon is in seasonal rotation
        if (!sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000This dungeon is not available in the current Mythic+ season.|r"
            );
            return true;
        }

        // Check if player has keystone
        if (!sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You need a Mythic+ Keystone to activate the Font of Power.|r"
            );
            ChatHandler(player->GetSession()).PSendSysMessage(
                "Visit the Keystone Master to obtain a keystone."
            );
            return true;
        }

        uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);
        DungeonConfig* config = sDungeonEnhancementMgr->GetDungeonConfig(mapId);

        // Build gossip menu
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                         "|cFF00FF00Font of Power|r - Activate Mythic+ Run", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        
        AddGossipItemFor(player, GOSSIP_ICON_DOT, "----------------------------------------", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                         "Your Keystone: |cFFFFAA00Mythic+" + std::to_string(keystoneLevel) + "|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        
        if (config)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                             "Dungeon: |cFFFFAA00" + config->dungeonName + "|r", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        }

        AddGossipItemFor(player, GOSSIP_ICON_DOT, "----------------------------------------", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);

        // Show current affixes
        ShowAffixes(player, keystoneLevel);

        AddGossipItemFor(player, GOSSIP_ICON_DOT, "----------------------------------------", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);

        // Activate button
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                         "|cFF00FF00[Activate Keystone] Start Mythic+|r" + std::to_string(keystoneLevel), 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_ACTIVATE_KEYSTONE);

        // Info option
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "How does this work?", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_FONT_INFO);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, [[maybe_unused]] uint32 sender, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        switch (action)
        {
            case GOSSIP_ACTION_ACTIVATE_KEYSTONE:
                HandleActivateKeystone(player, go);
                break;

            case GOSSIP_ACTION_FONT_INFO:
                ShowFontInfo(player, go);
                break;

            case GOSSIP_ACTION_BACK:
                OnGossipHello(player, go);
                break;

            default:
                CloseGossipMenuFor(player);
                break;
        }

        return true;
    }

private:
    // ========================================================================
    // KEYSTONE ACTIVATION
    // ========================================================================

    void HandleActivateKeystone(Player* player, [[maybe_unused]] GameObject* go)
    {
        CloseGossipMenuFor(player);

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000Font of Power can only be used inside dungeons.|r"
            );
            return;
        }

        uint16 mapId = map->GetId();
        uint32 instanceId = map->GetInstanceId();

        // Validate dungeon is available
        if (!sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000This dungeon is not available in the current Mythic+ season.|r"
            );
            return;
        }

        // Validate player has keystone
        if (!sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You don't have a Mythic+ Keystone.|r"
            );
            return;
        }

        uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);

        // Check if run already active
        if (MythicRunTracker::IsRunActive(instanceId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000A Mythic+ run is already in progress.|r"
            );
            return;
        }

        // Validate group (if in group)
        Group* group = player->GetGroup();
        if (group)
        {
            // Check if all group members are in the same instance
            uint8 membersInInstance = 0;
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                if (member && member->GetMapId() == mapId && member->GetInstanceId() == instanceId)
                {
                    membersInInstance++;
                }
            }

            if (membersInInstance < 2)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00Warning: Some group members are not in this instance.|r"
                );
            }
        }

        // Start the run
        MythicRunTracker::StartRun(map, keystoneLevel, player);

        // Initialize affix handlers for this instance
        sAffixFactory->InitializeInstanceHandlers(instanceId, keystoneLevel);

        // Apply scaling to all creatures in dungeon
        ApplyDungeonScaling(map, keystoneLevel);

        // Store keystone level in instance data
        MythicDifficultyScaling::SetMapKeystoneLevel(map, keystoneLevel);

        // Success message
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00Mythic+%u run activated! Defeat all bosses before reaching 15 deaths.|r",
            keystoneLevel
        );

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s activated M+%u keystone in dungeon %u (Instance %u)",
                 player->GetName().c_str(), keystoneLevel, mapId, instanceId);
    }

    // ========================================================================
    // DUNGEON SCALING
    // ========================================================================

    void ApplyDungeonScaling(Map* map, uint8 keystoneLevel)
    {
        if (!map)
            return;

        uint16 mapId = map->GetId();

        // Iterate all creatures in the map and apply scaling
        Map::PlayerList const& players = map->GetPlayers();

        // Apply scaling to all creatures
        // Note: This is a simplified version. In production, use proper creature iteration
        for (auto itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player)
                continue;

            // Get all creatures in player's view range
            std::list<Creature*> creatures;
            player->GetCreatureListWithEntryInGrid(creatures, 0, 200.0f);  // 200 yard radius

            for (Creature* creature : creatures)
            {
                if (!creature || creature->IsPet() || creature->IsTotem())
                    continue;

                // Determine if creature is a boss
                bool isBoss = (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS ||
                               creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE);

                // Apply scaling
                MythicDifficultyScaling::ApplyScaling(creature, mapId, keystoneLevel, isBoss);
            }

            break;  // Only need to process once
        }

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Applied M+%u scaling to dungeon map %u", keystoneLevel, mapId);
    }

    // ========================================================================
    // AFFIX DISPLAY
    // ========================================================================

    void ShowAffixes(Player* player, uint8 keystoneLevel)
    {
        std::vector<AffixData*> affixes = sDungeonEnhancementMgr->GetCurrentActiveAffixes(keystoneLevel);

        if (affixes.empty())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                             "Active Affixes: |cFF888888None (M+0 or M+1)|r", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
            return;
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                         "|cFFFFAA00Active Affixes:|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);

        for (AffixData* affix : affixes)
        {
            if (!affix)
                continue;

            std::string affixText = "  [M+" + std::to_string(affix->minKeystoneLevel) + "+] " + 
                                    affix->affixName + " (" + affix->affixType + ")";
            
            AddGossipItemFor(player, GOSSIP_ICON_DOT, affixText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        }
    }

    // ========================================================================
    // INFO DISPLAY
    // ========================================================================

    void ShowFontInfo(Player* player, [[maybe_unused]] GameObject* go)
    {
        CloseGossipMenuFor(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Font of Power Guide ===|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00What is the Font of Power?|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "The Font of Power is a mystical font that activates Mythic+ keystones."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "It is located at the entrance of every Mythic+ dungeon."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00How to Use:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "1. Form a group (or go solo if you're brave!)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "2. Enter the dungeon with a Mythic+ Keystone"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "3. Interact with the Font of Power"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "4. Activate your keystone to start the M+ run"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00What Happens:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - All creatures scale to your keystone level"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Weekly affixes are applied"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Death counter starts (max 15 deaths)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Timer begins (30 minutes)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Important:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Only ONE player needs to activate their keystone"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - The entire group benefits from the run"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Deaths count for the entire group"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - The 15th death instantly fails the run"
        );
    }
};

void AddSC_go_mythic_plus_font_of_power()
{
    new go_mythic_plus_font_of_power();
}
