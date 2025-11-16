/*
 * Mythic+ Keystone Pedestal GameObject Script
 * Handles keystone item consumption and M+ run activation
 * When player uses keystone item on this GO, the M+ run is initialized
 * Entry: 300200
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "GameObject.h"
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
        for (uint8 i = 0; i < MAX_KEYSTONE_LEVEL - MIN_KEYSTONE_LEVEL + 1; ++i)
        {
            if (player->HasItemCount(KEYSTONE_ITEM_IDS[i], 1, false))
            {
                keystoneLevel = i + MIN_KEYSTONE_LEVEL;
                break;
            }
        }

        if (!keystoneLevel)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffff0000Error:|r You do not have a Mythic+ Keystone in your inventory!");
            return true;
        }

        // Provide guidance instead of consuming the keystone here
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00Mythic+:|r %s detected. Take your group inside the dungeon and use the Font of Power to begin the run.",
            GetKeystoneColoredName(keystoneLevel).c_str());

        if (!player->GetGroup())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffffa500Tip:|r Mythic+ runs require a party. Invite your teammates before activating the keystone.");
        }
        else if (player->GetGroup()->GetLeaderGUID() != player->GetGUID())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cffffa500Note:|r Only the party leader can activate the keystone at the Font of Power.");
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
