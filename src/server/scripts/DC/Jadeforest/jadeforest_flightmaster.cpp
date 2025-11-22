/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2008-2021 TrinityCore <https://www.trinitycore.org/>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Player.h"

// Jadeforest Flightmaster
class jadeforest_flightmaster : public CreatureScript
{
public:
    jadeforest_flightmaster() : CreatureScript("jadeforest_flightmaster") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Prepare quest menu if this NPC offers quests
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Add your custom flight destinations here
        // Example:
        // AddGossipItemFor(player, GOSSIP_ICON_TAXI, "Fly to destination", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        // Handle gossip actions here
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1:
                // Example: Teleport or start taxi path
                // player->TeleportTo(mapId, x, y, z, o);
                break;
            default:
                break;
        }

        return true;
    }
};

void AddSC_jadeforest_flightmaster()
{
    new jadeforest_flightmaster();
}
