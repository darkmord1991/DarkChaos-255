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
        std::string killerOwnerName; // owner of a pet/guardian/totem killer (empty otherwise)
        uint32_t killerLevel = 0;
        std::string killerRank;      // "Elite" | "Rare Elite" | "Rare" | "Boss" (empty for a normal mob)
        std::string environmentType; // e.g. "Falling", "Lava" (only set when killerType == "environment")
        uint32_t killingBlowDamage = 0;
        uint32_t spellId = 0;        // spell that landed the killing blow (0 for melee/environment)
        std::string spellName;
    };

    // Stash the environmental damage cause about to be dealt to `victim` (an EnviromentalDamage
    // enum value), so it can be recovered a moment later if this hit turns out to be lethal.
    // Call from Player::EnvironmentalDamage() before dealing the damage.
    void NotePendingEnvironmentalCause(Player* victim, uint8_t environmentalType);

    // Stash who/what is about to land the killing blow on `victim`, along with the damage and the
    // spell that dealt it (0 for melee). Call from Unit::DealDamage() right before a lethal hit
    // invokes Unit::Kill().
    //
    // This is the only point at which the killer is reliably known: Unit::Kill() reaches
    // setDeathState(JustDied) - and through it PlayerScript::OnPlayerJustDied(), which takes no
    // killer - long before it fires OnPlayerKilledByCreature()/OnPlayerPVPKill(). A death handler
    // that acts on the first hook (hardcore locks the character there) would otherwise never see
    // the killer at all.
    void NotePendingKillingBlow(Player* victim, Unit* attacker, uint32_t damage, uint32_t spellId = 0);

    // Resolve who/what killed `victim`. `killer` may be null or the victim itself (self-inflicted
    // damage, e.g. environmental damage routes through Unit::DealDamage(this, this, ...)); in that
    // case it falls back to the attacker noted via NotePendingKillingBlow(), then to any
    // environmental cause noted via NotePendingEnvironmentalCause(). Safe to call more than once
    // for the same death (does not consume the pending data).
    DeathContext ResolveDeathContext(Player* victim, Unit* killer);

    // Compose the human-readable cause of death from a resolved context - "Fell to their death.",
    // "Slain by Ragnaros (Level 63 Boss) with Sulfuras Smash.", and so on. Single source of truth
    // for the marker's failureReason, the hardcore chat broadcast and the victim's own death recap,
    // so they can never describe the same death differently.
    std::string BuildFailureReason(DeathContext const& ctx);

    // Record a death marker for a challenge-mode (e.g., Iron Prestige / Hardcore).
    // The marker is kept for 24 hours (server time) and is pushed to online clients via WRLD updates.
    // `failureReason` defaults to nullptr, meaning "compose it from the resolved death context"
    // via BuildFailureReason(); pass a string only to override that with a mode-specific one.
    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel, char const* failureReason = nullptr);

    // Build an array of active death markers for WRLD snapshots.
    // Each entry includes: markerId, modeId/modeLabel, victimName/level/class, killer info
    // (killerType/killerEntry/killerName/killerLevel/killerRank), environmentType,
    // killingBlowDamage/spellId/spellName, failureReason, mapId/nx/ny, diedAt/expiresAt.
    DCAddon::JsonValue BuildDeathMarkersArray();

} // namespace DeathMarkers
} // namespace DCAddon
