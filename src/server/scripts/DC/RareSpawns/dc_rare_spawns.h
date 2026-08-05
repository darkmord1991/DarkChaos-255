#pragma once

class Player;

namespace DCAddon
{
namespace RareSpawns
{
    // Push the current up/down state of every tracked rare on the player's map as
    // a WRLD SMSG_UPDATE "rares" payload.
    //
    // The kill/respawn pushes are event-driven, so a client that just logged in
    // knows nothing about rares that have been standing there for hours. This is
    // the catch-up: call it wherever the world-content snapshot is delivered.
    //
    // Filtered to the player's current map, because the full two-map set is ~95
    // records and most of it would be for a continent the player is not on. The
    // addon re-requests world content on zone change, so moving between maps
    // refreshes naturally.
    //
    // No-op when the announcer is disabled or the player's map is not tracked.
    void SendSnapshot(Player* player);
}
}
