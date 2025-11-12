/*
 * ============================================================================
 * Dungeon Enhancement System - Affix Handler Base Class
 * ============================================================================
 * Purpose: Base class for all affix implementations
 * Location: src/server/scripts/DC/DungeonEnhancement/Affixes/
 * ============================================================================
 */

#ifndef MYTHIC_AFFIX_HANDLER_H
#define MYTHIC_AFFIX_HANDLER_H

#include "Common.h"
#include "../Core/DungeonEnhancementConstants.h"
#include "Unit.h"
#include "Creature.h"
#include "Player.h"
#include <string>

namespace DungeonEnhancement
{
    // Forward declarations
    struct AffixData;

    // ========================================================================
    // AFFIX HANDLER BASE CLASS
    // ========================================================================

    class MythicAffixHandler
    {
    public:
        MythicAffixHandler(AffixData* data) : _affixData(data) { }
        virtual ~MythicAffixHandler() = default;

        // ====================================================================
        // CORE VIRTUAL METHODS (Override in derived classes)
        // ====================================================================

        /**
         * Called when a creature spawns in a Mythic+ dungeon
         * Use this to apply permanent auras, modify stats, or set flags
         * @param creature The spawned creature
         * @param keystoneLevel The active keystone level
         */
        virtual void OnCreatureSpawn([[maybe_unused]] Creature* creature, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called when a creature dies in a Mythic+ dungeon
         * Use this for mechanics that trigger on death (Bolstering, Sanguine)
         * @param creature The dying creature
         * @param killer The unit that killed the creature
         * @param keystoneLevel The active keystone level
         */
        virtual void OnCreatureDeath([[maybe_unused]] Creature* creature, [[maybe_unused]] Unit* killer, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called when a creature deals damage in a Mythic+ dungeon
         * Use this to modify damage amounts or apply special effects
         * @param attacker The attacking creature
         * @param victim The damage target
         * @param damage Reference to damage amount (modify this)
         * @param keystoneLevel The active keystone level
         */
        virtual void OnDamageDealt([[maybe_unused]] Creature* attacker, [[maybe_unused]] Unit* victim, [[maybe_unused]] uint32& damage, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called when a player takes damage in a Mythic+ dungeon
         * Use this for player-affecting mechanics (Grievous, Necrotic)
         * @param victim The player taking damage
         * @param attacker The attacking unit
         * @param damage Reference to damage amount (modify this)
         * @param keystoneLevel The active keystone level
         */
        virtual void OnPlayerDamaged([[maybe_unused]] Player* victim, [[maybe_unused]] Unit* attacker, [[maybe_unused]] uint32& damage, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called periodically (every 1 second) for environmental affixes
         * Use this for mechanics that need continuous effects (Volcanic)
         * @param player The player to affect
         * @param keystoneLevel The active keystone level
         */
        virtual void OnPeriodicTick([[maybe_unused]] Player* player, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called when a creature enters combat
         * Use this for combat-start mechanics (Raging enrage trigger setup)
         * @param creature The creature entering combat
         * @param keystoneLevel The active keystone level
         */
        virtual void OnEnterCombat([[maybe_unused]] Creature* creature, [[maybe_unused]] uint8 keystoneLevel) { }

        /**
         * Called when a creature's health percentage changes
         * Use this for health-threshold mechanics (Raging at 30%)
         * @param creature The creature
         * @param healthPct Current health percentage
         * @param keystoneLevel The active keystone level
         */
        virtual void OnHealthPctChanged([[maybe_unused]] Creature* creature, [[maybe_unused]] uint8 healthPct, [[maybe_unused]] uint8 keystoneLevel) { }

        // ====================================================================
        // HELPER METHODS (Available to all derived classes)
        // ====================================================================

        /**
         * Check if this affix should affect the given creature
         * @param creature The creature to check
         * @return True if affix applies to this creature type
         */
        virtual bool ShouldAffectCreature(Creature* creature) const;

        /**
         * Check if this affix is a boss-only affix
         * @return True if affix only affects bosses
         */
        virtual bool IsBossOnlyAffix() const;

        /**
         * Check if this affix is a trash-only affix
         * @return True if affix only affects trash mobs
         */
        virtual bool IsTrashOnlyAffix() const;

        /**
         * Get the affix name
         * @return Affix name string
         */
        std::string GetAffixName() const;

        /**
         * Get the affix description
         * @return Affix description string
         */
        std::string GetAffixDescription() const;

        /**
         * Get the affix type
         * @return Affix type (Boss, Trash, Environmental, Debuff)
         */
        std::string GetAffixType() const;

        /**
         * Get the minimum keystone level for this affix
         * @return Minimum M+ level
         */
        uint8 GetMinKeystoneLevel() const;

        /**
         * Get the affix spell ID (if any)
         * @return Spell ID or 0 if none
         */
        uint32 GetAffixSpellId() const;

        /**
         * Apply the affix spell/aura to a unit
         * @param target The target unit
         * @return True if spell was applied
         */
        bool ApplyAffixAura(Unit* target) const;

        /**
         * Remove the affix spell/aura from a unit
         * @param target The target unit
         */
        void RemoveAffixAura(Unit* target) const;

    protected:
        AffixData* _affixData;  // Pointer to affix configuration data

        // ====================================================================
        // UTILITY METHODS (For derived classes)
        // ====================================================================

        /**
         * Check if unit is a boss
         * @param creature The creature to check
         * @return True if creature is a boss
         */
        bool IsBoss(Creature* creature) const;

        /**
         * Check if unit is trash mob
         * @param creature The creature to check
         * @return True if creature is trash
         */
        bool IsTrash(Creature* creature) const;

        /**
         * Get nearby friendly creatures for the given creature
         * @param creature The center creature
         * @param range Search radius in yards
         * @return List of nearby friendly creatures
         */
        std::list<Creature*> GetNearbyFriendlyCreatures(Creature* creature, float range) const;

        /**
         * Get nearby enemy players for the given creature
         * @param creature The center creature
         * @param range Search radius in yards
         * @return List of nearby enemy players
         */
        std::list<Player*> GetNearbyEnemyPlayers(Creature* creature, float range) const;

        /**
         * Broadcast message to all players in the instance
         * @param creature Any creature in the instance (for context)
         * @param message The message to broadcast
         * @param color Message color
         */
        void BroadcastToInstance(Creature* creature, const std::string& message, uint32 color) const;
    };

} // namespace DungeonEnhancement

#endif // MYTHIC_AFFIX_HANDLER_H
