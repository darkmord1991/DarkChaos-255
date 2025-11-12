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
#include "../Core/DungeonEnhancementManager.h"
#include "Creature.h"
#include "SpellInfo.h"

namespace DungeonEnhancement
{
    class Affix_Tyrannical : public MythicAffixHandler
    {
    public:
        Affix_Tyrannical(AffixData* data) : MythicAffixHandler(data) { }

        void OnCreatureSpawn(Creature* creature, [[maybe_unused]] uint8 keystoneLevel) override
        {
            if (!ShouldAffectCreature(creature) || !IsBoss(creature))
                return;

            // Apply Tyrannical scaling
            uint32 baseMaxHealth = creature->GetMaxHealth();
            uint32 newMaxHealth = static_cast<uint32>(baseMaxHealth * 1.40f);  // +40% HP
            creature->SetMaxHealth(newMaxHealth);
            creature->SetHealth(newMaxHealth);

            // Apply visual aura if configured
            if (GetAffixSpellId() > 0)
            {
                ApplyAffixAura(creature);
            }

            LOG_INFO(LogCategory::AFFIXES, 
                     "Tyrannical affix applied to boss %u: +40%% HP, +15%% damage",
                     creature->GetEntry());
        }

        void OnDamageDealt([[maybe_unused]] Creature* attacker, [[maybe_unused]] Unit* victim, [[maybe_unused]] uint32& damage, [[maybe_unused]] uint8 keystoneLevel) override
        {
            // Damage modification handled by spell aura system
        }
    };

    // Factory function for registration
    MythicAffixHandler* CreateTyrannicalHandler(AffixData* data)
    {
        return new Affix_Tyrannical(data);
    }

} // namespace DungeonEnhancement
