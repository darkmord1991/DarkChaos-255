/*
 * ============================================================================
 * Dungeon Enhancement System - Difficulty Scaling (Header)
 * ============================================================================
 * Purpose: Handle HP/Damage scaling for Mythic/Mythic+ difficulties
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * ============================================================================
 */

#ifndef MYTHIC_DIFFICULTY_SCALING_H
#define MYTHIC_DIFFICULTY_SCALING_H

#include "Define.h"
#include "DungeonEnhancementConstants.h"

class Creature;
class Unit;
class Map;
class Player;

namespace DungeonEnhancement
{
    // ========================================================================
    // DIFFICULTY SCALING UTILITIES
    // ========================================================================
    
    class MythicDifficultyScaling
    {
    public:
        // ====================================================================
        // CREATURE SCALING
        // ====================================================================
        
        /**
         * Apply difficulty scaling to a creature based on map and keystone level
         * @param creature The creature to scale
         * @param mapId The map ID
         * @param keystoneLevel The M+ keystone level (0 for M+0)
         * @param isBoss Whether this creature is a boss
         */
        static void ApplyScaling(Creature* creature, uint16 mapId, uint8 keystoneLevel, bool isBoss);
        
        /**
         * Calculate HP multiplier for a creature
         * @param mapId The map ID
         * @param keystoneLevel The M+ keystone level (0 for M+0)
         * @param isBoss Whether this is a boss creature
         * @return HP multiplier (e.g., 2.0 = 200% HP)
         */
        static float CalculateHPMultiplier(uint16 mapId, uint8 keystoneLevel, bool isBoss);
        
        /**
         * Calculate damage multiplier for a creature
         * @param mapId The map ID
         * @param keystoneLevel The M+ keystone level (0 for M+0)
         * @param isBoss Whether this is a boss creature
         * @return Damage multiplier (e.g., 1.5 = 150% damage)
         */
        static float CalculateDamageMultiplier(uint16 mapId, uint8 keystoneLevel, bool isBoss);
        
        /**
         * Apply affix-based scaling to a creature
         * @param creature The creature to scale
         * @param keystoneLevel The M+ keystone level
         * @param isBoss Whether this is a boss creature
         */
        static void ApplyAffixScaling(Creature* creature, uint8 keystoneLevel, bool isBoss);
        
        // ====================================================================
        // DAMAGE MODIFICATION (COMBAT)
        // ====================================================================
        
        /**
         * Modify damage dealt by a creature based on difficulty scaling
         * Called from damage calculation hooks
         * @param attacker The attacking creature
         * @param victim The victim (usually a player)
         * @param damage Reference to damage value (modified in-place)
         */
        static void ModifyCreatureDamage(Unit* attacker, Unit* victim, uint32& damage);
        
        /**
         * Check if damage should be scaled for this unit
         * @param unit The unit to check
         * @return True if scaling should be applied
         */
        static bool ShouldScaleDamage(Unit* unit);
        
        // ====================================================================
        // MAP UTILITIES
        // ====================================================================
        
        /**
         * Check if a map is a Mythic+ enabled dungeon
         * @param mapId The map ID to check
         * @return True if this map supports Mythic+
         */
        static bool IsMythicPlusMap(uint16 mapId);
        
        /**
         * Get the current keystone level for a map instance
         * @param map The map instance
         * @return Keystone level (0 if M+0, 2-10 for M+)
         */
        static uint8 GetMapKeystoneLevel(Map* map);
        
        /**
         * Set the keystone level for a map instance
         * @param map The map instance
         * @param keystoneLevel The M+ level (0-10)
         */
        static void SetMapKeystoneLevel(Map* map, uint8 keystoneLevel);
        
        // ====================================================================
        // VALIDATION
        // ====================================================================
        
        /**
         * Validate that a keystone level is within acceptable range
         * @param keystoneLevel The level to validate
         * @return True if valid (0 or 2-10)
         */
        static bool IsValidKeystoneLevel(uint8 keystoneLevel);
        
        /**
         * Clamp a keystone level to valid range
         * @param keystoneLevel The level to clamp
         * @return Clamped level (0 or 2-10)
         */
        static uint8 ClampKeystoneLevel(uint8 keystoneLevel);
    };

} // namespace DungeonEnhancement

#endif // MYTHIC_DIFFICULTY_SCALING_H
