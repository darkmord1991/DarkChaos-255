/*
 * ============================================================================
 * Dungeon Enhancement System - Bolstering Affix
 * ============================================================================
 * Purpose: Trash affix - when one mob dies, nearby trash gain +20% HP/damage
 * Tier: 2 (M+4)
 * Type: Trash
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "DungeonEnhancementManager.h"
#include "Creature.h"
#include "SpellInfo.h"
#include "Log.h"

namespace DungeonEnhancement
{
    // Custom spell ID for Bolstering buff (configure in database)
    const uint32 SPELL_BOLSTERING_BUFF = 800010;  // Custom spell - +20% HP/damage stacking aura

    class Affix_Bolstering : public MythicAffixHandler
    {
    public:
        Affix_Bolstering(AffixData* data) : MythicAffixHandler(data) { }

        void OnCreatureDeath(Creature* creature, Unit* killer, uint8 keystoneLevel) override
        {
            // Only trigger on trash deaths
            if (!creature || IsBoss(creature))
                return;

            // Get nearby friendly trash mobs (within 30 yards)
            std::list<Creature*> nearbyCreatures = GetNearbyFriendlyCreatures(creature, 30.0f);

            uint32 buffedCount = 0;
            for (Creature* nearby : nearbyCreatures)
            {
                // Skip bosses and dead creatures
                if (IsBoss(nearby) || nearby->isDead())
                    continue;

                // Apply Bolstering buff
                ApplyBolsteringBuff(nearby);
                buffedCount++;
            }

            if (buffedCount > 0)
            {
                LOG_INFO(LogCategory::AFFIXES, 
                         "Bolstering triggered: %u nearby trash mobs buffed (+20%% HP/damage)",
                         buffedCount);
            }
        }

    private:
        void ApplyBolsteringBuff(Creature* creature)
        {
            if (!creature)
                return;

            // Increase HP by 20%
            uint32 currentMaxHealth = creature->GetMaxHealth();
            uint32 newMaxHealth = static_cast<uint32>(currentMaxHealth * 1.20f);
            creature->SetMaxHealth(newMaxHealth);
            
            // Heal to new max (to make the buff noticeable)
            uint32 currentHealth = creature->GetHealth();
            uint32 healthIncrease = newMaxHealth - currentMaxHealth;
            creature->SetHealth(currentHealth + healthIncrease);

            // Increase damage by 20%
            uint32 currentMultiplier = creature->GetData(0);
            float currentDamageMultiplier = (currentMultiplier > 0) ? (currentMultiplier / 100.0f) : 1.0f;
            float bolsteringMultiplier = currentDamageMultiplier * 1.20f;
            creature->SetData(0, static_cast<uint32>(bolsteringMultiplier * 100.0f));

            // Apply visual buff aura (stacking)
            if (SPELL_BOLSTERING_BUFF > 0)
            {
                creature->AddAura(SPELL_BOLSTERING_BUFF, creature);
            }

            // Optional: Store bolstering stack count for visual feedback
            uint32 stackCount = creature->GetData(1);  // Using data slot 1 for stack count
            creature->SetData(1, stackCount + 1);
        }
    };

    // Factory function for registration
    MythicAffixHandler* CreateBolsteringHandler(AffixData* data)
    {
        return new Affix_Bolstering(data);
    }

} // namespace DungeonEnhancement
