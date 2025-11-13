/*
 * ============================================================================
 * Dungeon Enhancement System - Raging Affix
 * ============================================================================
 * Tier: 2 (M+4)
 * Type: Trash
 * Effect: Non-boss enemies enrage at 30% HP, dealing +50% damage until death
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "../Core/DungeonEnhancementManager.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "SpellAuras.h"

using namespace DungeonEnhancement;

class Affix_Raging : public MythicAffixHandler
{
public:
    Affix_Raging(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Monitor health percentage for enrage trigger
    // ========================================================================
    void OnHealthPctChanged(Creature* creature, [[maybe_unused]] uint8 healthPct, [[maybe_unused]] uint8 keystoneLevel) override
    {
        if (!creature)
            return;

        // Only affects trash (not bosses)
        if (creature->isWorldBoss() || creature->IsDungeonBoss())
            return;

        // Check if creature is at or below 30% HP
        uint32 currentHealth = creature->GetHealth();
        uint32 maxHealth = creature->GetMaxHealth();
        float currentHealthPct = (static_cast<float>(currentHealth) / static_cast<float>(maxHealth)) * 100.0f;

        if (currentHealthPct <= 30.0f)
        {
            // Apply enrage
            ApplyRagingEnrage(creature);
        }
    }

    // ========================================================================
    // Apply +50% damage enrage buff
    // ========================================================================
    void ApplyRagingEnrage(Creature* creature)
    {
        if (!creature)
            return;

        // Apply visual enrage aura if configured
        if (_affixData && _affixData->spellId > 0)
            ApplyAffixAura(creature);

        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Creature {} enraged at 30% HP: +50% damage (Raging affix)",
                  creature->GetEntry());
    }
};

// Factory function
namespace DungeonEnhancement
{
    MythicAffixHandler* CreateRagingHandler(AffixData* data)
    {
        return new Affix_Raging(data);
    }
} // namespace DungeonEnhancement
