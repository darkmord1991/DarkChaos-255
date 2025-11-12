/*
 * ============================================================================
 * Dungeon Enhancement System - Tyrannical Affix
 * ============================================================================
 * Purpose: Boss-only affix (+40% HP, +15% damage)
 * Tier: 1 (M+2)
 * Type: Boss
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "DungeonEnhancementManager.h"
#include "Creature.h"
#include "SpellInfo.h"

namespace DungeonEnhancement
{
    class Affix_Tyrannical : public MythicAffixHandler
    {
    public:
        Affix_Tyrannical(AffixData* data) : MythicAffixHandler(data) { }

        void OnCreatureSpawn(Creature* creature, uint8 keystoneLevel) override
        {
            if (!ShouldAffectCreature(creature) || !IsBoss(creature))
                return;

            // Apply Tyrannical scaling
            uint32 baseMaxHealth = creature->GetMaxHealth();
            uint32 newMaxHealth = static_cast<uint32>(baseMaxHealth * 1.40f);  // +40% HP
            creature->SetMaxHealth(newMaxHealth);
            creature->SetHealth(newMaxHealth);

            // Store damage multiplier in creature data
            uint32 currentMultiplier = creature->GetData(0);
            float currentDamageMultiplier = (currentMultiplier > 0) ? (currentMultiplier / 100.0f) : 1.0f;
            float tyrannicalMultiplier = currentDamageMultiplier * 1.15f;  // +15% damage
            creature->SetData(0, static_cast<uint32>(tyrannicalMultiplier * 100.0f));

            // Apply visual aura if configured
            if (GetAffixSpellId() > 0)
            {
                ApplyAffixAura(creature);
            }

            LOG_INFO(LogCategory::AFFIXES, 
                     "Tyrannical affix applied to boss %u (M+%u): +40%% HP, +15%% damage",
                     creature->GetEntry(), keystoneLevel);
        }

        void OnDamageDealt(Creature* attacker, Unit* victim, uint32& damage, uint8 keystoneLevel) override
        {
            if (!IsBoss(attacker))
                return;

            // Damage multiplier already stored in creature data (applied in OnCreatureSpawn)
            // This method is here for additional dynamic damage modifications if needed
        }
    };

    // Factory function for registration
    MythicAffixHandler* CreateTyrannicalHandler(AffixData* data)
    {
        return new Affix_Tyrannical(data);
    }

} // namespace DungeonEnhancement
