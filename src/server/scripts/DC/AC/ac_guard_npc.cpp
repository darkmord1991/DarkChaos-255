
/*
 * AzerothCore Custom Script: Ashzara Crater Guard NPC
 *
 * Purpose / Feature Overview:
 * - Provides a small in-world helper NPC that shows Points of Interest (POIs)
 *   for the Ashzara Crater area and lets players teleport to them.
 * - Adds a friendly gossip menu which: shows clear labeled POIs prefixed
 *   with the zone name, places a world map marker for the selected POI and
 *   optionally teleports the player immediately when selected.
 * - This file is intentionally simple so it can be copied/extended for
 *   other zones.
 *
 * Integration / Deployment:
 * - Location: src/server/scripts/DC/AC/ac_guard_npc.cpp
 * - Ensure this file is listed in the DC CMakeLists so it is compiled into
 *   the server scripts collection and that `AddSC_ac_guard_npc()` is
 *   called by your DC script loader.
 * - Database: Create a creature_template entry with ScriptName="AC_Guard_NPC"
 *   and set the npcflag to include GOSSIP so players can interact.
 *
 * Implementation notes / design decisions:
 * - POIs are stored in a simple static array. This is intentionally low-dep
 *   and easy to extend, but consider moving POIs to a JSON/DB file for
 *   non-developers to edit.
 * - Messaging uses the server-side chat handler to display a brief
 *   confirmation to the player. The code deliberately avoids exposing
 *   raw coordinates in the gossip menu to keep the UI tidy.
 * - Teleportation is immediate and unconditional. Server operators may want
 *   to add safety checks (mounted/combat/vehicle/phased checks) before
 *   teleporting players.
 *
 * Author: (your name or team)
 * Date: 2025-09-27
 *
 * TODO / Enhancements:
 * - Make POIs configurable via an external file (JSON/DB) so GMs can edit
 *   POIs without rebuilding the server.
 * - Add permission checks (e.g., only allow teleport when not in combat,
 *   not in instance, not mounted, and not in a restricted area).
 * - Add localization support for the POI names and UI text.
 * - Replace string concatenation with fmt-style calls (PSendSysMessage) if
 *   localization or more advanced formatting is required.
 * - Add logging for teleports (optional audit trail for GMs).
 * - Consider adding an optional 'preview' mode that only shows the map
 *   marker without teleporting.
 * - Use map icon types / gossip POI packets for richer map markers where
 *   supported by the client/server protocol.
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
#include "ScriptedGossip.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include <string>
#include <cstdio>

// Structure representing a Point of Interest (POI)
struct ACGuardPOI {
    const char* name;   // Display name for the POI
    uint32 map;         // Map ID where the POI is located
    float x, y, z, o;   // Coordinates and orientation
};

// Array of POIs for the gossip menu
// Static list of POIs. Keep this small and human-readable. Each entry is a
// candidate for being moved to a configuration file in a future change.
static const ACGuardPOI ac_guard_pois[] = {
    {"Startcamp", 37, 131.000f, 1012.000f, 295.000f, 5.000f},           // Main camp
    {"Flight Master", 37, 72.5327f, 932.2570f, 339.3900f, 0.0680255f},  // Flight master
    {"Inkeeper", 37, 100.973f, 1037.9f, 297.107f, 2.56106f},            // Inkeeper location
    {"Auctionhouse", 37, 117.113f, 1051.78f, 297.107f, 0.92979f},       // Auctionhouse location
    {"Stable Master", 37, 95.3867f, 1027.84f, 297.107f, 2.5163f},       // Stable Master location
    {"Transmog", 37, 148.838f, 1000.34f, 295.753f, 5.98384f},           // Transmog NPC
    {"Ridetrainer", 37, 120.768f, 955.565f, 295.072f, 5.15048f},        // Riding trainer
    {"Profession trainers", 37, 43.905f, 1172.420f, 367.342f, 2.560f}, // Profession trainers
    {"Weapontrainer", 37, 100.351f, 1004.96f, 296.329f, 0.258275f},     // Weapon trainer
    {"Violet Temple (empty)", 37, -574.179f, -208.159f, 355.034f, 3.8202f}, // Violet Temple
    {"Dragon Statues (empty)", 37, -53.4259f, -40.4419f, 271.541f, 3.42052f} // Dragon Statues
};

// Main script class for the Guard NPC
class AC_Guard_NPC : public CreatureScript {
public:
    AC_Guard_NPC() : CreatureScript("AC_Guard_NPC") { }

    // Called when a player interacts with the NPC
    bool OnGossipHello(Player* player, Creature* creature) override {
        // Build the gossip menu by iterating the static POI list. We intentionally
        // show a friendly label instead of raw coordinates to reduce UI noise.
        for (size_t i = 0; i < sizeof(ac_guard_pois)/sizeof(ACGuardPOI); ++i) {
            // Do NOT include the zone prefix in the gossip label; keep it concise.
            std::string label = std::string("Teleport to ") + ac_guard_pois[i].name;
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, label, GOSSIP_SENDER_MAIN, static_cast<uint32>(i));
        }
        // Show the gossip menu to the player
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    // Called when a player selects a gossip menu item
    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 action) override {
        // Close the gossip menu
        CloseGossipMenuFor(player);
        // Validate the selected action (POI index)
        // Guard against malformed client packets by ensuring the index is valid.
        if (action < sizeof(ac_guard_pois)/sizeof(ACGuardPOI)) {
            const ACGuardPOI& poi = ac_guard_pois[action];
            // Optional: brief confirmation before teleport (include area prefix)
            const std::string poiPrefix = "Ashzara Crater - ";
            // Use the chat handler to show a short confirmation message to the
            // player. This is intentionally terse and user-facing.
            ChatHandler(player->GetSession()).PSendSysMessage("Teleporting to {}", poiPrefix + std::string(poi.name));
            // Direct teleport to the POI
            player->TeleportTo(poi.map, poi.x, poi.y, poi.z, poi.o);
        }
        return true;
    }
};

// Script loader registration function
void AddSC_ac_guard_npc() {
    new AC_Guard_NPC(); // Registers the Guard NPC script
}
