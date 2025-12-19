
/*
 * AzerothCore Custom Script: Ashzara Crater Guard NPC
 *
 * Purpose / Feature Overview:
 * - Provides a small in-world helper NPC that shows Points of Interest (POIs)
 *   for the Ashzara Crater area.
 * - Adds a friendly gossip menu which: shows clear labeled POIs prefixed
 *   with the zone name, places a world map marker for the selected POI and
 *   only teleports for a small subset of entries (Startcamp + Flight Master).
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
#include "GossipDef.h"
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
    bool teleport;      // If true, selecting this entry teleports instead of marking
    uint32 poiIcon;     // Poi_Icon (map/minimap marker)
    uint32 menuIcon;    // GossipOptionIcon (menu icon)
};

// Array of POIs for the gossip menu
// Static list of POIs. Keep this small and human-readable. Each entry is a
// candidate for being moved to a configuration file in a future change.
static const ACGuardPOI ac_guard_pois[] = {
    // Teleport entries
    {"Startcamp",            37,  131.000f, 1012.000f, 295.000f, 5.000f,      true,  ICON_POI_SMALL_HOUSE, GOSSIP_ICON_TAXI},
    {"Flight Master",        37,   72.5327f, 932.2570f, 339.3900f, 0.0680255f, true,  ICON_POI_BLUETOWER,   GOSSIP_ICON_TAXI},

    // Map/minimap POI entries
    {"Innkeeper",            37,  100.973f, 1037.9f,  297.107f, 2.56106f,     false, ICON_POI_SMALL_HOUSE, GOSSIP_ICON_TALK},
    {"Auction House",        37,  117.113f, 1051.78f, 297.107f, 0.92979f,     false, ICON_POI_SMALL_HOUSE, GOSSIP_ICON_MONEY_BAG},
    {"Stable Master",        37,   95.3867f, 1027.84f, 297.107f, 2.5163f,     false, ICON_POI_SMALL_HOUSE, GOSSIP_ICON_VENDOR},
    {"Riding Trainer",       37,  120.768f, 955.565f, 295.072f, 5.15048f,     false, ICON_POI_GREYTOWER,   GOSSIP_ICON_TRAINER},
    {"Profession Trainers",  37,   43.905f, 1172.420f, 367.342f, 2.560f,      false, ICON_POI_BWTOWER,     GOSSIP_ICON_TRAINER},
    {"Weapon Trainer",       37,  100.351f, 1004.96f, 296.329f, 0.258275f,    false, ICON_POI_GREYTOWER,   GOSSIP_ICON_TRAINER},
    {"Violet Temple",        37, -574.179f, -208.159f, 355.034f, 3.8202f,     false, ICON_POI_BWTOWER,     GOSSIP_ICON_CHAT},
    {"Dragon Statues",       37,  -53.4259f, -40.4419f, 271.541f, 3.42052f,   false, ICON_POI_TOMBSTONE,   GOSSIP_ICON_DOT}
};

namespace
{
    void SendPoiMarker(Player* player, float x, float y, uint32 icon, uint32 flags, uint32 importance, std::string const& name)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(SMSG_GOSSIP_POI, 4 + 4 + 4 + 4 + 4 + 20);
        data << uint32(flags);
        data << float(x);
        data << float(y);
        data << uint32(icon);
        data << uint32(importance);
        data << name;

        player->GetSession()->SendPacket(&data);
    }
}

// Main script class for the Guard NPC
class AC_Guard_NPC : public CreatureScript {
public:
    AC_Guard_NPC() : CreatureScript("AC_Guard_NPC") { }

    // Called when a player interacts with the NPC
    bool OnGossipHello(Player* player, Creature* creature) override {
        // Build the gossip menu by iterating the static POI list. We intentionally
        // show a friendly label instead of raw coordinates to reduce UI noise.
        for (size_t i = 0; i < sizeof(ac_guard_pois) / sizeof(ACGuardPOI); ++i)
        {
            uint32 idx = static_cast<uint32>(i);
            ACGuardPOI const& poi = ac_guard_pois[i];
            std::string label = (poi.teleport ? "Teleport: " : "Show on map: ") + std::string(poi.name);
            AddGossipItemFor(player, poi.menuIcon, label, GOSSIP_SENDER_MAIN, idx);
        }
        // Show the gossip menu to the player
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    // Called when a player selects a gossip menu item
    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override {
        
        // Validate the selected action (POI index)
        // Guard against malformed client packets by ensuring the index is valid.
        if (action >= sizeof(ac_guard_pois) / sizeof(ACGuardPOI))
        {
            ChatHandler(player->GetSession()).SendSysMessage("Invalid destination selected.");
            return true;
        }

        const ACGuardPOI& poi = ac_guard_pois[action];
        const std::string poiPrefix = "Ashzara Crater - ";

        // Default behavior: just show a POI marker on the map/minimap.
        if (!poi.teleport)
        {
            SendPoiMarker(player, poi.x, poi.y, poi.poiIcon, 0, 0, poiPrefix + std::string(poi.name));
            ChatHandler(player->GetSession()).PSendSysMessage("Marked on map: {}", poiPrefix + std::string(poi.name));

            // Keep the menu open for quick browsing.
            ClearGossipMenuFor(player);
            return OnGossipHello(player, creature);
        }

        // Teleport entries only (Startcamp + Flight Master).
        CloseGossipMenuFor(player);
        
        // === SAFETY CHECKS ===
        // Prevent teleportation in unsafe conditions
        
        // 1. Combat check - cannot teleport while in combat
        if (player->IsInCombat()) {
            ChatHandler(player->GetSession()).SendSysMessage("You cannot teleport while in combat.");
            return true;
        }
        
        // 2. Mount check - cannot teleport while mounted
        if (player->IsMounted()) {
            ChatHandler(player->GetSession()).SendSysMessage("You must dismount before teleporting.");
            return true;
        }
        
        // 3. Vehicle check - cannot teleport while in a vehicle
        if (player->GetVehicle()) {
            ChatHandler(player->GetSession()).SendSysMessage("You cannot teleport while in a vehicle.");
            return true;
        }
        
        // 4. Instance check - cannot teleport from inside an instance (optional, can be removed if desired)
        if (player->GetMap() && player->GetMap()->IsDungeon()) {
            ChatHandler(player->GetSession()).SendSysMessage("You cannot teleport from inside an instance.");
            return true;
        }
        
        // 5. Dead check - cannot teleport while dead (ghost form)
        if (!player->IsAlive()) {
            ChatHandler(player->GetSession()).SendSysMessage("You cannot teleport while dead.");
            return true;
        }
        
        // 6. Falling check - cannot teleport while falling
        if (player->IsFalling()) {
            ChatHandler(player->GetSession()).SendSysMessage("You cannot teleport while falling.");
            return true;
        }
        
        // All safety checks passed - proceed with teleport
        // Brief confirmation message before teleport
        ChatHandler(player->GetSession()).PSendSysMessage("Teleporting to {}", poiPrefix + std::string(poi.name));
        
        // Execute teleport
        player->TeleportTo(poi.map, poi.x, poi.y, poi.z, poi.o);
        
        return true;
    }
};

// Script loader registration function
void AddSC_ac_guard_npc() {
    new AC_Guard_NPC(); // Registers the Guard NPC script
}
