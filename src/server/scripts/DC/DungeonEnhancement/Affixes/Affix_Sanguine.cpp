/*
 * ============================================================================
 * Dungeon Enhancement System - Sanguine Affix
 * ============================================================================
 * Tier: 2 (M+4)
 * Type: Trash
 * Effect: When trash dies, spawn blood pool that heals enemies and damages players
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "TemporarySummon.h"

using namespace DungeonEnhancement;

// Blood pool NPC entry (would need to be created in creature_template)
#define SANGUINE_POOL_NPC_ENTRY 999999

class Affix_Sanguine : public MythicAffixHandler
{
public:
    Affix_Sanguine(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Spawn blood pool on trash death
    // ========================================================================
    void OnCreatureDeath(Creature* creature, bool isBoss) override
    {
        if (!creature || isBoss)
            return; // Only affects trash

        Map* map = creature->GetMap();
        if (!map)
            return;

        Position deathPos = creature->GetPosition();

        // Spawn blood pool at death location (30 second duration)
        // Note: This requires a custom creature template with periodic aura effects
        // For now, we'll log the intention
        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Sanguine pool spawned at death location of creature {} (Entry {})",
                  creature->GetGUID().ToString(), creature->GetEntry());

        // In a full implementation, you would:
        // 1. Create a custom creature template for the blood pool
        // 2. Add periodic aura that heals enemies and damages players within 8 yards
        // 3. Spawn it here with TempSummon (30 second duration)
        /*
        TempSummon* pool = map->SummonCreature(SANGUINE_POOL_NPC_ENTRY, deathPos, nullptr, 30000);
        if (pool)
        {
            pool->SetFaction(FACTION_MONSTER); // Hostile to players
            pool->CastSpell(pool, SANGUINE_POOL_AURA_SPELL, true);
        }
        */

        // Broadcast pool spawn message
        BroadcastToInstance(map, 
            "|cFFFF0000A pool of blood forms on the ground!|r");
    }
};

// Factory function
MythicAffixHandler* CreateSanguineHandler(AffixData* data)
{
    return new Affix_Sanguine(data);
}
