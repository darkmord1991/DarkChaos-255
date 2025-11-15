/*
 * Mythic+ Keystone Pedestal GameObject Script
 * Handles keystone item consumption and M+ run activation
 * When player uses keystone item on this GO, the M+ run is initialized
 * Entry: 300200
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "GameObject.h"
#include "ScriptedCreature.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusConstants.h"
#include "Chat.h"

using namespace MythicPlusConstants;

class go_keystone_pedestal : public GameObjectScript
{
public:
    go_keystone_pedestal() : GameObjectScript("go_keystone_pedestal") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        // Check if player has a keystone item
        uint8 keystoneLevel = 0;
        Item* keystoneItem = nullptr;

        for (uint32 i = 0; i < 9; ++i)
        {
            keystoneItem = player->GetItemByEntry(KEYSTONE_ITEM_IDS[i]);
            if (keystoneItem)
            {
                keystoneLevel = i + 2;  // M+2 = i+2
                break;
            }
        }

        if (!keystoneLevel || !keystoneItem)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000Error:|r You do not have a Mythic+ Keystone in your inventory!");
            return false;
        }

        // Verify player is party leader
        if (!player->GetGroup() || player->GetGroup()->GetLeaderGUID() != player->GetGUID())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000Error:|r Only the party leader can start a Mythic+ run!");
            return false;
        }

        // Verify party is in the correct dungeon
        // TODO: Add dungeon validation logic
        
        // Consume the keystone item
        player->DestroyItemCount(keystoneItem->GetEntry(), 1, true);

        // Initialize the M+ run
        auto runManager = MythicPlusRunManager::instance();
        if (runManager)
        {
            // TODO: Initialize run with keystoneLevel
            // runManager->InitializeRun(player->GetGroup(), keystoneLevel, dungeonId);
        }

        // Notify party and apply barrier effect
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00Mythic+:|r Starting run with %s keystone!", 
            GetKeystoneColoredName(keystoneLevel).c_str());

        if (player->GetGroup())
        {
            for (GroupReference* ref = player->GetGroup()->GetFirstMember(); ref != nullptr; ref = ref->next())
            {
                Player* groupMember = ref->GetSource();
                if (groupMember)
                {
                    // Send start message
                    ChatHandler(groupMember->GetSession()).PSendSysMessage(
                        "|cff00ff00Mythic+:|r Starting run with %s keystone!", 
                        GetKeystoneColoredName(keystoneLevel).c_str());
                    
                    // Apply 10-second barrier to all group members
                    if (groupMember->GetMap() && groupMember->GetMap()->GetDifficulty() == DUNGEON_DIFFICULTY_EPIC)
                    {
                        ChatHandler(groupMember->GetSession()).PSendSysMessage("|cffff8000[Mythic+ Activated]|r Entry barrier activated!");
                        ChatHandler(groupMember->GetSession()).PSendSysMessage("|cffffa500You cannot move for 10 seconds.|r");
                        
                        // Apply root aura for 10 seconds
                        groupMember->CastSpell(groupMember, 33786, true);
                        
                        // Send countdown messages at 10, 5, 4, 3, 2, 1
                        for (uint8 i = 1; i <= 10; ++i)
                        {
                            uint8 seconds_left = 11 - i;
                            if (seconds_left <= 5 || seconds_left == 10)
                            {
                                ChatHandler(groupMember->GetSession()).PSendSysMessage("|cffff0000%u|r seconds", seconds_left);
                            }
                        }
                    }
                }
            }
        }

        return true;
    }

    bool OnUse(Player* player, GameObject* go)
    {
        return OnGossipHello(player, go);
    }
};

// Script registration
void AddSC_go_keystone_pedestal()
{
    new go_keystone_pedestal();
}
