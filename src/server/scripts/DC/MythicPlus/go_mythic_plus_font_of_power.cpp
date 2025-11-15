/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "GameObject.h"
#include "MythicPlusRunManager.h"
#include "Player.h"

class go_mythic_plus_font_of_power : public GameObjectScript
{
public:
    go_mythic_plus_font_of_power() : GameObjectScript("go_mythic_plus_font_of_power") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        sMythicRuns->TryActivateKeystone(player, go);
        return true;
    }
};

void AddSC_go_mythic_plus_font_of_power()
{
    new go_mythic_plus_font_of_power();
}
