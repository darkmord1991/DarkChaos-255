#pragma once

#include <cstdint>
#include <string>

class Player;
class Unit;

namespace DCAddon
{
class JsonValue;

namespace DeathMarkers
{
    // Resolved killer/cause description for a player's death. Shared by the death-marker
    // JSON and any chat/log text built at the same call site, so they can never disagree.
    struct DeathContext
    {
        std::string killerType;      // "creature" | "player" | "environment" | "unknown"
        uint32_t killerEntry = 0;
        std::string killerName;      // creature/player name (empty for environment/unknown)
        std::string environmentType; // e.g. "Falling", "Lava" (only set when killerType == "environment")
        uint32_t killingBlowDamage = 0;
    };

    // Stash the environmental damage cause about to be dealt to `victim` (an EnviromentalDamage
    // enum value), so it can be recovered a moment later if this hit turns out to be lethal.
    // Call from Player::EnvironmentalDamage() before dealing the damage.
    void NotePendingEnvironmentalCause(Player* victim, uint8_t environmentalType);

    // Stash the lethal damage amount for `victim`, recoverable as "killing blow damage" a moment
    // later. Call from Unit::DealDamage() right before a lethal hit invokes Unit::Kill().
    void NotePendingKillingBlow(Player* victim, uint32_t damage);

    // Resolve who/what killed `victim`. Handles `killer == victim` (self-inflicted damage, e.g.
    // environmental damage routes through Unit::DealDamage(this, this, ...)) by falling back to
    // any environmental cause noted via NotePendingEnvironmentalCause(). Safe to call more than
    // once for the same death (does not consume the pending data).
    DeathContext ResolveDeathContext(Player* victim, Unit* killer);

    // Record a death marker for a challenge-mode (e.g., Iron Prestige / Hardcore).
    // The marker is kept for 24 hours (server time) and is pushed to online clients via WRLD updates.
    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel, char const* failureReason = "Died.");

    // Build an array of active death markers for WRLD snapshots.
    // Each entry includes: markerId, modeId/modeLabel, victimName/level/class, killer info,
    // environmentType/killingBlowDamage/failureReason, mapId/nx/ny, diedAt/expiresAt.
    DCAddon::JsonValue BuildDeathMarkersArray();

} // namespace DeathMarkers
} // namespace DCAddon
