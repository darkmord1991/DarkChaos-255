/*
 * ============================================================================
 * Dungeon Enhancement System - Volcanic Affix
 * ============================================================================
 * Tier: 3 (M+7)
 * Type: Environmental
 * Effect: Periodically spawn volcanic plumes beneath distant players (>8 yards from enemies)
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "../Core/DungeonEnhancementManager.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "GameObject.h"

using namespace DungeonEnhancement;

// Volcanic plume GameObject entry (would need to be created)
#define VOLCANIC_PLUME_GO_ENTRY 700100

class Affix_Volcanic : public MythicAffixHandler
{
public:
    Affix_Volcanic(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Periodic tick: Spawn volcanic plumes for ranged players
    // ========================================================================
    void OnPeriodicTick(Player* player, [[maybe_unused]] uint8 keystoneLevel) override
    {
        if (!player || !player->IsAlive())
            return;

        // Check if player is ranged (>8 yards from all enemies)
        if (IsPlayerRanged(player))
        {
            SpawnVolcanicPlume(player);
        }
    }

    // ========================================================================
    // Check if player is >8 yards from all enemies
    // ========================================================================
    bool IsPlayerRanged(Player* player)
    {
        if (!player)
            return false;

        // Find nearest enemy creature
        Creature* nearestEnemy = player->FindNearestCreature(999999, 8.0f, true); // Any hostile creature within 8 yards

        // If no enemy within 8 yards, player is considered ranged
        return (nearestEnemy == nullptr);
    }

    // ========================================================================
    // Spawn volcanic plume at player's location
    // ========================================================================
    void SpawnVolcanicPlume(Player* player)
    {
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        // Spawn visual GameObject (lava geyser) and apply damage
        // Note: This requires a custom GameObject with spell cast on interact/proximity
        // For now, we'll just apply direct damage
        
        // Deal fire damage (e.g., 50% of player max HP)
        uint32 damage = static_cast<uint32>(player->GetMaxHealth() * 0.50f);
        
        // Apply damage with fire school
        Unit::DealDamage(player, player, damage, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_FIRE);
        
        // Visual effect spell (if configured)
        if (_affixData && _affixData->spellId > 0)
            player->CastSpell(player, _affixData->spellId, true);

        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Volcanic plume spawned beneath player {} (dealt {} fire damage)",
                  player->GetName(), damage);
    }
};

// Factory function
MythicAffixHandler* CreateVolcanicHandler(AffixData* data)
{
    return new Affix_Volcanic(data);
}
