/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "Chat.h"
#include "GameObject.h"
#include "MythicDifficultyScaling.h"
#include "MythicPlusRunManager.h"
#include "Player.h"
#include "StringFormat.h"

namespace
{
enum FontOfPowerActions : uint32
{
    ACTION_START_RUN = 1,
    ACTION_CLOSE     = 2
};
}

class go_mythic_plus_font_of_power : public GameObjectScript
{
public:
    go_mythic_plus_font_of_power() : GameObjectScript("go_mythic_plus_font_of_power") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        KeystoneDescriptor descriptor;
        std::string error;

        ClearGossipMenuFor(player);

        bool canActivate = sMythicRuns->CanActivateKeystone(player, go, descriptor, error);

        if (!canActivate)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("|cffff0000{}|r", error), GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        DungeonProfile* profile = go->GetMap() ? sMythicScaling->GetDungeonProfile(go->GetMap()->GetId()) : nullptr;
        std::string dungeonName = profile ? profile->name : "Unknown Dungeon";

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            Acore::StringFormat("Start Mythic+ Run: +{} {}", descriptor.level, dungeonName),
            GOSSIP_SENDER_MAIN, ACTION_START_RUN);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Cancel", GOSSIP_SENDER_MAIN, ACTION_CLOSE);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) override
    {
        if (!player || !go || sender != GOSSIP_SENDER_MAIN)
            return false;

        if (action == ACTION_START_RUN)
        {
            CloseGossipMenuFor(player);
            sMythicRuns->TryActivateKeystone(player, go);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_go_mythic_plus_font_of_power()
{
    new go_mythic_plus_font_of_power();
}
