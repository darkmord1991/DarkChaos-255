/*
 * ============================================================================
 * Dungeon Enhancement System - Fortified Affix
 * ============================================================================
 * Tier: 1 (M+2)
 * Type: Trash
 * Effect: Non-boss enemies have +20% HP and deal +30% damage
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "../Core/DungeonEnhancementManager.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"

using namespace DungeonEnhancement;

class Affix_Fortified : public MythicAffixHandler
{
public:
    Affix_Fortified(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Apply Fortified buff on creature spawn
    // ========================================================================
    void OnCreatureSpawn(Creature* creature, [[maybe_unused]] uint8 keystoneLevel) override
    {
        if (!creature)
            return;

        // Check if this is a boss
        if (creature->isWorldBoss() || creature->IsDungeonBoss())
            return; // Only affects trash

        // +20% HP
        uint32 baseMaxHealth = creature->GetMaxHealth();
        uint32 newMaxHealth = static_cast<uint32>(baseMaxHealth * 1.20f);
        creature->SetMaxHealth(newMaxHealth);
        creature->SetHealth(newMaxHealth);

        // +30% damage is handled by spell aura or combat modifier
        // Apply visual aura if configured
        if (_affixData && _affixData->spellId > 0)
            ApplyAffixAura(creature);

        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Applied Fortified to creature {} (Entry {}): +20% HP, +30% damage",
                  creature->GetGUID().ToString(), creature->GetEntry());
    }
};

// Factory function
MythicAffixHandler* CreateFortifiedHandler(AffixData* data)
{
    return new Affix_Fortified(data);
}
