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
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "GameObject.h"

using namespace DungeonEnhancement;

// Volcanic plume GameObject entry (would need to be created)
#define VOLCANIC_PLUME_GO_ENTRY 700100

class Affix_Volcanic : public MythicAffixHandler
{
private:
    uint32 _lastTickTime = 0;
    const uint32 VOLCANIC_TICK_INTERVAL = 5000; // 5 seconds between plume spawns

public:
    Affix_Volcanic(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Periodic tick: Spawn volcanic plumes every 5 seconds
    // ========================================================================
    void OnPeriodicTick(Map* map) override
    {
        if (!map)
            return;

        uint32 currentTime = GameTime::GetGameTimeMS();
        if (currentTime - _lastTickTime < VOLCANIC_TICK_INTERVAL)
            return;

        _lastTickTime = currentTime;

        // Get all players in the instance
        Map::PlayerList const& players = map->GetPlayers();
        if (players.isEmpty())
            return;

        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player || !player->IsAlive())
                continue;

            // Check if player is ranged (>8 yards from all enemies)
            if (IsPlayerRanged(player))
            {
                SpawnVolcanicPlume(player);
            }
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

        Position plumePos = player->GetPosition();

        // Spawn visual GameObject (lava geyser) and apply damage
        // Note: This requires a custom GameObject with spell cast on interact/proximity
        // For now, we'll just apply direct damage
        
        // Deal fire damage (e.g., 50% of player max HP)
        uint32 damage = static_cast<uint32>(player->GetMaxHealth() * 0.50f);
        
        // Apply damage with fire school
        player->DealDamage(player, damage, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_FIRE);
        
        // Visual effect spell (if configured)
        if (_affixData && _affixData->spellId > 0)
            player->CastSpell(player, _affixData->spellId, true);

        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Volcanic plume spawned beneath player {} (dealt {} fire damage)",
                  player->GetName(), damage);

        // Send warning message
        player->SendDirectMessage("|cFFFF0000Volcanic plume erupts beneath you!|r");
    }
};

// Factory function
MythicAffixHandler* CreateVolcanicHandler(AffixData* data)
{
    return new Affix_Volcanic(data);
}
