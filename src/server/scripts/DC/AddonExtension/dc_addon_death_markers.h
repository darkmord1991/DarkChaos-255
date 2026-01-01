#pragma once

#include <cstdint>

class Player;
class Unit;

namespace DCAddon
{
class JsonValue;

namespace DeathMarkers
{
    // Record a death marker for a challenge-mode (e.g., Iron Prestige / Hardcore).
    // The marker is kept for 24 hours (server time) and is pushed to online clients via WRLD updates.
    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel);

    // Build an array of active death markers for WRLD snapshots.
    // Each entry includes: markerId, modeId/modeLabel, victimName/level/class, killer info, mapId/nx/ny, diedAt/expiresAt.
    DCAddon::JsonValue BuildDeathMarkersArray();

} // namespace DeathMarkers
} // namespace DCAddon
