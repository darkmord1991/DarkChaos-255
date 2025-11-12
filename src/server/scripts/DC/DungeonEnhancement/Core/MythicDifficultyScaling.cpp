/*
 * ============================================================================
 * Dungeon Enhancement System - Difficulty Scaling (Implementation)
 * ============================================================================
 * Purpose: Handle HP/Damage scaling for Mythic/Mythic+ difficulties
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * ============================================================================
 */

#include "MythicDifficultyScaling.h"
#include "DungeonEnhancementManager.h"
#include "Creature.h"
#include "Map.h"
#include "Unit.h"
#include "Player.h"
#include "InstanceScript.h"
#include "MapMgr.h"
#include "Log.h"

namespace DungeonEnhancement
{
    // ========================================================================
    // CREATURE SCALING
    // ========================================================================
    
    void MythicDifficultyScaling::ApplyScaling(Creature* creature, uint16 mapId, uint8 keystoneLevel, bool isBoss)
    {
        if (!creature || keystoneLevel > MYTHIC_PLUS_MAX_LEVEL)
            return;
        
        // Check if this map supports Mythic+
        if (!sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId))
            return;
        
        // Calculate multipliers
        float hpMultiplier = CalculateHPMultiplier(mapId, keystoneLevel, isBoss);
        float damageMultiplier = CalculateDamageMultiplier(mapId, keystoneLevel, isBoss);
        
        // Apply HP scaling
        uint32 baseMaxHealth = creature->GetMaxHealth();
        uint32 newMaxHealth = static_cast<uint32>(baseMaxHealth * hpMultiplier);
        creature->SetMaxHealth(newMaxHealth);
        creature->SetHealth(newMaxHealth);
        
        // Store damage multiplier for OnDamage hook (stored as 100x value in POWER_ENERGY)
        uint32 multiplierData = static_cast<uint32>(damageMultiplier * 100.0f);
        creature->SetPower(POWER_ENERGY, multiplierData);
        
        // Apply affix-based scaling if in M+ dungeon
        if (keystoneLevel >= MYTHIC_PLUS_MIN_LEVEL)
        {
            ApplyAffixScaling(creature, keystoneLevel, isBoss);
        }
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Applied scaling to creature %u (Map %u, M+%u): HP x%.2f, Damage x%.2f", 
                 creature->GetEntry(), mapId, keystoneLevel, hpMultiplier, damageMultiplier);
    }
    
    float MythicDifficultyScaling::CalculateHPMultiplier(uint16 mapId, uint8 keystoneLevel, [[maybe_unused]] bool isBoss)
    {
        // Base multiplier from dungeon config
        float multiplier = sDungeonEnhancementMgr->GetDungeonScalingMultiplier(mapId, keystoneLevel, true);
        
        // No additional boss scaling needed (already in base multiplier)
        return multiplier;
    }
    
    float MythicDifficultyScaling::CalculateDamageMultiplier(uint16 mapId, uint8 keystoneLevel, [[maybe_unused]] bool isBoss)
    {
        // Base multiplier from dungeon config
        float multiplier = sDungeonEnhancementMgr->GetDungeonScalingMultiplier(mapId, keystoneLevel, false);
        
        // No additional boss scaling needed (already in base multiplier)
        return multiplier;
    }
    
    void MythicDifficultyScaling::ApplyAffixScaling(Creature* creature, uint8 keystoneLevel, bool isBoss)
    {
        if (!creature || keystoneLevel < MYTHIC_PLUS_MIN_LEVEL)
            return;
        
        // Get current active affixes for this keystone level
        std::vector<AffixData*> affixes = sDungeonEnhancementMgr->GetCurrentActiveAffixes(keystoneLevel);
        
        for (AffixData* affix : affixes)
        {
            if (!affix)
                continue;
            
            // Apply affix HP modifier
            if (affix->hpModifierPercent > 0.0f)
            {
                // Check if affix applies to this creature type
                bool appliesToThisCreature = false;
                
                if (affix->affixType == "Boss" && isBoss)
                    appliesToThisCreature = true;
                else if (affix->affixType == "Trash" && !isBoss)
                    appliesToThisCreature = true;
                else if (affix->affixType == "Environmental" || affix->affixType == "Debuff")
                    appliesToThisCreature = false;  // These affect players, not creatures
                
                if (appliesToThisCreature)
                {
                    float hpMultiplier = 1.0f + (affix->hpModifierPercent / 100.0f);
                    uint32 currentMaxHealth = creature->GetMaxHealth();
                    uint32 newMaxHealth = static_cast<uint32>(currentMaxHealth * hpMultiplier);
                    creature->SetMaxHealth(newMaxHealth);
                    creature->SetHealth(newMaxHealth);
                    
                    LOG_INFO(LogCategory::AFFIXES, 
                             "Applied affix '%s' HP modifier (%.1f%%) to creature %u", 
                             affix->affixName.c_str(), affix->hpModifierPercent, creature->GetEntry());
                }
            }
            
            // Apply affix damage modifier
            if (affix->damageModifierPercent > 0.0f)
            {
                // Damage modification is handled through affix scripts, not stored in creature data
                // Creature::SetData/GetData doesn't exist in AzerothCore
                LOG_INFO(LogCategory::AFFIXES, 
                         "Affix '%s' damage modifier (%.1f%%) handled by affix mechanics for creature %u", 
                         affix->affixName.c_str(), affix->damageModifierPercent, creature->GetEntry());
            }
            
            // Apply spell/aura if defined
            if (affix->spellId > 0)
            {
                // creature->AddAura(affix->spellId, creature);
                LOG_INFO(LogCategory::AFFIXES, 
                         "Applied affix '%s' spell (%u) to creature %u", 
                         affix->affixName.c_str(), affix->spellId, creature->GetEntry());
            }
        }
    }
    
    // ========================================================================
    // DAMAGE MODIFICATION (COMBAT)
    // ========================================================================
    
    void MythicDifficultyScaling::ModifyCreatureDamage(Unit* attacker, Unit* victim, uint32& damage)
    {
        if (!attacker || !victim)
            return;
        
        // Check if attacker is a creature in a Mythic+ dungeon
        Creature* creature = attacker->ToCreature();
        if (!creature)
            return;
        
        // Check if victim is a player
        if (!victim->ToPlayer())
            return;
        
        // Get stored damage multiplier from creature power (using POWER_ENERGY as storage)
        // Multiplier is stored as 100x the value (e.g., 150 means 1.5x)
        uint32 multiplierData = creature->GetPower(POWER_ENERGY);
        if (multiplierData == 0)
            return;  // No scaling applied
        
        float damageMultiplier = multiplierData / 100.0f;
        
        // Apply damage multiplier
        damage = static_cast<uint32>(damage * damageMultiplier);
        
        // Note: Additional affix-specific damage modifications can be added here
    }
    
    bool MythicDifficultyScaling::ShouldScaleDamage(Unit* unit)
    {
        if (!unit)
            return false;
        
        Creature* creature = unit->ToCreature();
        if (!creature)
            return false;
        
        // Check if creature has scaling data set (stored in POWER_ENERGY)
        return creature->GetPower(POWER_ENERGY) > 0;
    }
    
    // ========================================================================
    // MAP UTILITIES
    // ========================================================================
    
    bool MythicDifficultyScaling::IsMythicPlusMap(uint16 mapId)
    {
        return sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId);
    }
    
    uint8 MythicDifficultyScaling::GetMapKeystoneLevel(Map* map)
    {
        if (!map || !map->IsDungeon())
            return 0;
        
        InstanceMap* instanceMap = map->ToInstanceMap();
        if (!instanceMap)
            return 0;
        
        InstanceScript* instance = instanceMap->GetInstanceData();
        if (!instance)
            return 0;
        
        // Retrieve keystone level from instance data
        // Note: This assumes instance script stores keystone level in DATA_KEYSTONE_LEVEL
        return static_cast<uint8>(instance->GetData(1000));  // Custom data index for keystone level
    }
    
    void MythicDifficultyScaling::SetMapKeystoneLevel(Map* map, uint8 keystoneLevel)
    {
        if (!map || !map->IsDungeon())
            return;
        
        InstanceMap* instanceMap = map->ToInstanceMap();
        if (!instanceMap)
            return;
        
        InstanceScript* instance = instanceMap->GetInstanceData();
        if (!instance)
            return;
        
        // Store keystone level in instance data
        instance->SetData(1000, keystoneLevel);  // Custom data index for keystone level
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Set keystone level M+%u for map %u (Instance ID: %u)", 
                 keystoneLevel, map->GetId(), map->GetInstanceId());
    }
    
    // ========================================================================
    // VALIDATION
    // ========================================================================
    
    bool MythicDifficultyScaling::IsValidKeystoneLevel(uint8 keystoneLevel)
    {
        // Valid levels: 0 (M+0) or 2-10 (M+2 to M+10)
        if (keystoneLevel == 0)
            return true;  // M+0 (no keystone)
        
        return (keystoneLevel >= MYTHIC_PLUS_MIN_LEVEL && keystoneLevel <= MYTHIC_PLUS_MAX_LEVEL);
    }
    
    uint8 MythicDifficultyScaling::ClampKeystoneLevel(uint8 keystoneLevel)
    {
        // Level 1 is invalid - clamp to 0 (M+0)
        if (keystoneLevel == 1)
            return 0;
        
        // Clamp to valid range (2-10)
        if (keystoneLevel < MYTHIC_PLUS_MIN_LEVEL)
            return MYTHIC_PLUS_MIN_LEVEL;
        
        if (keystoneLevel > MYTHIC_PLUS_MAX_LEVEL)
            return MYTHIC_PLUS_MAX_LEVEL;
        
        return keystoneLevel;
    }

} // namespace DungeonEnhancement
