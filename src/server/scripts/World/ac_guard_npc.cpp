/*
 * AzerothCore module: Ashzara Crater Guard NPC
 *
 * This module adds a custom guard NPC with points of interest for Ashzara Crater.
 * Each point of interest is named and has coordinates as specified by the user.
 *
 * To use: Place this file in modules/Ashzara Crater and ensure the module is enabled in CMakeLists.txt.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Chat.h"

struct ACGuardPOI {
    const char* name;
    uint32 map;
    float x, y, z, o;
};

static const ACGuardPOI ac_guard_pois[] = {
    {"Startcamp", 37, 131.000f, 1012.000f, 295.000f, 5.000f},
    {"Level 15 - 20", 37, -117.003f, 850.815f, 294.579f, 5.585f},
    {"Level 35", 37, 147.987f, 269.417f, 273.524f, 1.227f},
    {"Level 40 - 45", 37, 902.614f, 154.535f, 285.419f, 3.561f},
    {"Level 45", 37, 865.102f, 438.741f, 281.501f, 3.796f},
    {"Level 50 - 70", 37, 896.217f, 142.282f, 285.359f, 4.090f},
    {"Level 70", 37, 1035.750f, 216.876f, 367.189f, 4.269f},
    {"Inkeeper", 37, 100.973f, 1037.9f, 297.107f, 2.56106f},
    {"Auctionhouse", 37, 117.113f, 1051.78f, 297.107f, 0.92979f},
    {"Stable Master", 37, 95.3867f, 1027.84f, 297.107f, 2.5163f},
    {"Transmog", 37, 148.838f, 1000.34f, 295.753f, 5.98384f},
    {"Ridetrainer", 37, 120.768f, 955.565f, 295.072f, 5.15048f},
    {"Profession trainers", 37, 43.905f, 1172.420f, 367.342f, 2.560f},
    {"Weapontrainer", 37, 100.351f, 1004.96f, 296.329f, 0.258275f}
};

class AC_Guard_NPC : public CreatureScript {
public:
    AC_Guard_NPC() : CreatureScript("AC_Guard_NPC") { }

    bool OnGossipHello(Player* player, Creature* creature) override {
        for (size_t i = 0; i < sizeof(ac_guard_pois)/sizeof(ACGuardPOI); ++i) {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, ac_guard_pois[i].name, GOSSIP_SENDER_MAIN, i);
        }
    SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override {
        CloseGossipMenuFor(player);
        if (action < sizeof(ac_guard_pois)/sizeof(ACGuardPOI)) {
            const ACGuardPOI& poi = ac_guard_pois[action];
            char msg[256];
            snprintf(msg, sizeof(msg), "%s: Map %u, X %.2f, Y %.2f, Z %.2f, O %.2f", poi.name, poi.map, poi.x, poi.y, poi.z, poi.o);
            ChatHandler(player->GetSession()).PSendSysMessage(msg);
            // Show a marker on the world map for this POI
            player->SendPointOfInterest(poi.x, poi.y, poi.o, 6, 6, poi.name);
        }
        return true;
    }
};

void AddSC_ac_guard_npc() {
    new AC_Guard_NPC();
}
