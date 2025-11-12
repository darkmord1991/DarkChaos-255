/*
 * ============================================================================
 * Dungeon Enhancement System - Necrotic Affix
 * ============================================================================
 * Tier: 3 (M+7)
 * Type: Debuff
 * Effect: Enemy melee attacks apply stacking debuff (damage over time + healing reduction)
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "SpellAuras.h"
#include "SpellInfo.h"

using namespace DungeonEnhancement;

// Necrotic debuff spell ID (would need to be created in spell_dbc)
#define NECROTIC_DEBUFF_SPELL_ID 800020

class Affix_Necrotic : public MythicAffixHandler
{
public:
    Affix_Necrotic(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Apply Necrotic stacks on player damage (from melee attacks)
    // ========================================================================
    void OnPlayerDamaged(Player* player, Creature* attacker, uint32& damage) override
    {
        if (!player || !attacker)
            return;

        // Only apply from melee attacks (not spells)
        // This check would require accessing the damage source type
        // For simplicity, we apply from all damage sources for now

        // Apply or stack Necrotic debuff
        ApplyNecroticStack(player);
    }

    // ========================================================================
    // Apply stacking Necrotic debuff
    // ========================================================================
    void ApplyNecroticStack(Player* player)
    {
        if (!player)
            return;

        // Check if player already has Necrotic debuff
        Aura* necroticAura = player->GetAura(NECROTIC_DEBUFF_SPELL_ID);

        if (necroticAura)
        {
            // Stack existing aura (up to 99 stacks)
            uint8 currentStacks = necroticAura->GetStackAmount();
            if (currentStacks < 99)
            {
                necroticAura->SetStackAmount(currentStacks + 1);
                
                LOG_DEBUG("dungeon.enhancement.affixes",
                          "Necrotic stacks increased to {} on player {}",
                          currentStacks + 1, player->GetName());
            }
        }
        else
        {
            // Apply new Necrotic debuff (1 stack)
            // Note: This requires the spell to exist in spell_dbc with:
            // - Periodic damage (e.g., 1% max HP per stack per second)
            // - Healing reduction modifier (e.g., -5% healing per stack)
            // - Stacking up to 99
            
            if (_affixData && _affixData->spellId > 0)
            {
                player->CastSpell(player, _affixData->spellId, true);
                
                LOG_DEBUG("dungeon.enhancement.affixes",
                          "Applied Necrotic debuff (1 stack) to player {}",
                          player->GetName());
            }
        }
    }
};

// Factory function
MythicAffixHandler* CreateNecroticHandler(AffixData* data)
{
    return new Affix_Necrotic(data);
}
