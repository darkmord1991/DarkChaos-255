
/*
 * AzerothCore Custom Script: Ashzara Crater Guard NPC
 *
 * Feature Overview:
 * - Custom Guard NPC for Ashzara Crater zone
 * - Interactive gossip menu listing points of interest (POIs)
 * - Each POI displays a name and sends a world map marker to the player
 * - POI coordinates and orientation are shown in a system message
 * - POI marker uses AzerothCore-compatible WorldPacket (SMSG_GOSSIP_POI)
 * - Easy to extend: add more POIs to the ac_guard_pois array
 *
 * Integration:
 * - Place this file in src/server/scripts/DC/AC/
 * - Ensure CMakeLists.txt in DC/ includes AC/ac_guard_npc.cpp
 * - Register AddSC_ac_guard_npc in your script loader (dc_script_loader.cpp)
 * - Set ScriptName to "AC_Guard_NPC" in your creature_template DB entry
 * - Set npcflag to 1 (GOSSIP) for the NPC in the DB
 *
 * Author: (your name or team)
 * Date: 2025-09-27
 *
 * Usage:
 * - Talk to the guard NPC in Ashzara Crater
 * - Select a POI from the gossip menu
 * - A map marker appears and coordinates are shown in chat
 */
// --- POI Data Structure ---
// --- Main Guard NPC Script ---
    // Build gossip menu with all POIs
    // Handle POI selection, send marker and info
// --- Script Registration ---

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "Opcodes.h"

// Structure representing a Point of Interest (POI)
struct ACGuardPOI {
    const char* name;   // Display name for the POI
    uint32 map;         // Map ID where the POI is located
    float x, y, z, o;   // Coordinates and orientation
};

// Array of POIs for the gossip menu
static const ACGuardPOI ac_guard_pois[] = {
    {"Startcamp", 37, 131.000f, 1012.000f, 295.000f, 5.000f},           // Main camp
    {"Level 15 - 20", 37, -117.003f, 850.815f, 294.579f, 5.585f},       // Leveling area 15-20
    {"Level 35", 37, 147.987f, 269.417f, 273.524f, 1.227f},             // Level 35 area
    {"Level 40 - 45", 37, 902.614f, 154.535f, 285.419f, 3.561f},        // Leveling area 40-45
    {"Level 45", 37, 865.102f, 438.741f, 281.501f, 3.796f},             // Level 45 area
    {"Level 50 - 70", 37, 896.217f, 142.282f, 285.359f, 4.090f},        // Leveling area 50-70
    {"Level 70", 37, 1035.750f, 216.876f, 367.189f, 4.269f},            // Level 70 area
    {"Inkeeper", 37, 100.973f, 1037.9f, 297.107f, 2.56106f},            // Inkeeper location
    {"Auctionhouse", 37, 117.113f, 1051.78f, 297.107f, 0.92979f},       // Auctionhouse location
    {"Stable Master", 37, 95.3867f, 1027.84f, 297.107f, 2.5163f},       // Stable Master location
    {"Transmog", 37, 148.838f, 1000.34f, 295.753f, 5.98384f},           // Transmog NPC
    {"Ridetrainer", 37, 120.768f, 955.565f, 295.072f, 5.15048f},        // Riding trainer
    {"Profession trainers", 37, 43.905f, 1172.420f, 367.342f, 2.560f}, // Profession trainers
    {"Weapontrainer", 37, 100.351f, 1004.96f, 296.329f, 0.258275f}      // Weapon trainer
};

// Main script class for the Guard NPC
class AC_Guard_NPC : public CreatureScript {
public:
    AC_Guard_NPC() : CreatureScript("AC_Guard_NPC") { }

    // Called when a player interacts with the NPC
    bool OnGossipHello(Player* player, Creature* creature) override {
        // Add each POI as a gossip menu item
        for (size_t i = 0; i < sizeof(ac_guard_pois)/sizeof(ACGuardPOI); ++i) {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, ac_guard_pois[i].name, GOSSIP_SENDER_MAIN, i);
        }
        // Show the gossip menu to the player
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    // Called when a player selects a gossip menu item
    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override {
        // Close the gossip menu
        CloseGossipMenuFor(player);
        // Validate the selected action (POI index)
        if (action < sizeof(ac_guard_pois)/sizeof(ACGuardPOI)) {
            const ACGuardPOI& poi = ac_guard_pois[action];
            // Build and send a system message with POI details
            char msg[256];
            snprintf(msg, sizeof(msg), "%s: Map %u, X %.2f, Y %.2f, Z %.2f, O %.2f", poi.name, poi.map, poi.x, poi.y, poi.z, poi.o);
            ChatHandler(player->GetSession()).PSendSysMessage(msg);
            // Build and send a world map marker packet for the POI
            WorldPacket data(SMSG_GOSSIP_POI);
            data << float(poi.x); // POI X coordinate
            data << float(poi.y); // POI Y coordinate
            data << uint32(6);    // Icon type (6 = default)
            data << uint32(6);    // Flags (6 = default)
            data << uint32(0);    // Data (unused, usually 0)
            data << float(poi.o); // POI orientation
            data << std::string(poi.name); // POI name
            player->SendDirectMessage(&data);
        }
        return true;
    }
};

// Script loader registration function
void AddSC_ac_guard_npc() {
    new AC_Guard_NPC(); // Registers the Guard NPC script
}
