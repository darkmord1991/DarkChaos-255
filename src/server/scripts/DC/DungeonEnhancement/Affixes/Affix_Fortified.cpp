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
    void OnCreatureSpawn(Creature* creature, bool isBoss) override
    {
        if (!creature || isBoss)
            return; // Only affects trash

        // +20% HP
        uint32 baseMaxHealth = creature->GetMaxHealth();
        uint32 newMaxHealth = static_cast<uint32>(baseMaxHealth * 1.20f);
        creature->SetMaxHealth(newMaxHealth);
        creature->SetHealth(newMaxHealth);

        // +30% damage (store multiplier for ModifyCreatureDamage)
        float damageMultiplier = 1.30f;
        creature->SetData(0, static_cast<uint32>(damageMultiplier * 100)); // Store as percentage

        // Apply visual aura if configured
        if (_affixData && _affixData->spellId > 0)
            ApplyAffixAura(creature, creature);

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
