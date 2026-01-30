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
#include "GuardAI.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "ScriptedGossip.h"

// Jadeforest teleport points
enum JadeforestTeleports
{
    TELEPORT_JADESTART         = 10579,
    TELEPORT_ENTRANCE_SOUTH    = 10580,
    TELEPORT_ENTRANCE_MAIN     = 10581,
    TELEPORT_ENTRANCE_NORTH    = 10582,
    TELEPORT_JADETOP           = 10583,
    TELEPORT_TRAINING_GROUNDS  = 10584
};

struct JadeforestTeleportData
{
    uint32 id;
    float x;
    float y;
    float z;
    float o;
    uint32 map;
    const char* icon;
    std::string name;
};

static const JadeforestTeleportData teleportPoints[] =
{
    { TELEPORT_JADESTART,        961.603f,   -2462.78f,   180.575f, 4.41822f,  745, "Interface\\Icons\\INV_Misc_Campfire",      "Jade Start" },
    { TELEPORT_ENTRANCE_SOUTH,   651.465f,   -2452.0f,    70.7512f, 3.05162f,  745, "Interface\\Icons\\INV_Misc_Map_01",        "Jade Entrance South" },
    { TELEPORT_ENTRANCE_MAIN,    1069.73f,   -2151.01f,   134.324f, 1.17923f,  745, "Interface\\Icons\\INV_Misc_Map_01",        "Jade Entrance Main" },
    { TELEPORT_ENTRANCE_NORTH,   1331.35f,   -2404.91f,   141.917f, 0.163741f, 745, "Interface\\Icons\\INV_Misc_Map_01",        "Jade Entrance North" },
    { TELEPORT_JADETOP,          1452.68f,   -3104.49f,   331.667f, 0.610619f, 745, "Interface\\Icons\\Spell_Nature_StormReach", "Jade Top" },
    { TELEPORT_TRAINING_GROUNDS, 1252.4359f, -2478.3853f, 143.6f,   6.201568f, 745, "Interface\\Icons\\Ability_DualWield",      "Training Grounds" }
};

// Jadeforest Guard - Template
class jadeforest_guard : public CreatureScript
{
public:
    jadeforest_guard() : CreatureScript("jadeforest_guard") { }

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Prepare quest menu if available
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Add teleport options
        for (auto const& tp : teleportPoints)
        {
            AddGossipItemFor(player, GOSSIP_ICON_TAXI,
                MakeLargeGossipText(tp.icon, tp.name),
                GOSSIP_SENDER_MAIN, tp.id);
        }

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        // Find the selected teleport point
        for (auto const& tp : teleportPoints)
        {
            if (tp.id == action)
            {
                player->TeleportTo(tp.map, tp.x, tp.y, tp.z, tp.o);
                return true;
            }
        }

        return true;
    }

    struct jadeforest_guardAI : public GuardAI
    {
        jadeforest_guardAI(Creature* creature) : GuardAI(creature) { }

        void Reset() override
        {
            // Initialize timers and variables
        }

        void JustEngagedWith(Unit* who) override
        {
            GuardAI::JustEngagedWith(who);
            // Custom combat logic
        }

        void UpdateAI(uint32 /*diff*/) override
        {
            if (!UpdateVictim())
                return;

            // Custom combat logic here
            // Example timer-based spells or abilities

            DoMeleeAttackIfReady();
        }

    private:
        // Add private member variables for timers, etc.
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new jadeforest_guardAI(creature);
    }
};

void AddSC_jadeforest_guards()
{
    new jadeforest_guard();
}
