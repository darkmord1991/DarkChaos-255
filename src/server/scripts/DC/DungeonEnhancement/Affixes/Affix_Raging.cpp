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
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "SpellAuras.h"

using namespace DungeonEnhancement;

class Affix_Raging : public MythicAffixHandler
{
private:
    bool _hasEnraged = false;

public:
    Affix_Raging(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Monitor health percentage for enrage trigger
    // ========================================================================
    void OnHealthPctChanged(Creature* creature, bool isBoss, float healthPct) override
    {
        if (!creature || isBoss)
            return; // Only affects trash

        // Check if creature should enrage (30% HP threshold)
        if (healthPct <= 30.0f)
        {
            // Check if already enraged (stored in creature data slot 2)
            if (creature->GetData(2) == 1)
                return; // Already enraged

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

        // Get current damage multiplier from slot 0
        float currentMultiplier = static_cast<float>(creature->GetData(0)) / 100.0f;
        if (currentMultiplier == 0.0f)
            currentMultiplier = 1.0f;

        // Apply +50% damage on top of existing multiplier
        float enragedMultiplier = currentMultiplier * 1.50f;
        creature->SetData(0, static_cast<uint32>(enragedMultiplier * 100));

        // Mark as enraged (slot 2 = enrage flag)
        creature->SetData(2, 1);

        // Apply visual enrage aura if configured
        if (_affixData && _affixData->spellId > 0)
            ApplyAffixAura(creature, creature);

        // Broadcast enrage message
        BroadcastToInstance(creature->GetMap(), 
            "|cFFFF0000" + creature->GetName() + " becomes enraged!|r");

        LOG_DEBUG("dungeon.enhancement.affixes",
                  "Creature {} enraged at 30% HP: +50% damage (Raging affix)",
                  creature->GetEntry());
    }
};

// Factory function
MythicAffixHandler* CreateRagingHandler(AffixData* data)
{
    return new Affix_Raging(data);
}
