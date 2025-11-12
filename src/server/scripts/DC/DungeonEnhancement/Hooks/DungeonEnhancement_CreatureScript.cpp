/*
 * ============================================================================
 * Dungeon Enhancement System - Creature Hooks
 * ============================================================================
 * Purpose: Integrate scaling, affixes, and run tracking with creature events
 * Location: src/server/scripts/DC/DungeonEnhancement/Hooks/
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "InstanceScript.h"
#include "DungeonEnhancementManager.h"
#include "DungeonEnhancementConstants.h"
#include "MythicDifficultyScaling.h"
#include "MythicRunTracker.h"
#include "MythicAffixFactory.h"

using namespace DungeonEnhancement;

class DungeonEnhancement_CreatureScript : public CreatureScript
{
public:
    DungeonEnhancement_CreatureScript() : CreatureScript("DungeonEnhancement_CreatureScript") { }

    // ========================================================================
    // CREATURE SPAWN HOOK
    // ========================================================================
    void OnCreatureCreate(Creature* creature) override
    {
        if (!creature || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint16 mapId = map->GetId();
        uint32 instanceId = map->GetInstanceId();

        // Check if this dungeon is Mythic+ enabled
        if (!sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId))
            return;

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Get keystone level from run data
        MythicRunData* runData = MythicRunTracker::GetRunData(instanceId);
        if (!runData)
            return;

        uint8 keystoneLevel = runData->keystoneLevel;

        // Determine if creature is a boss
        bool isBoss = (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS ||
                       creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE);

        // Apply difficulty scaling
        MythicDifficultyScaling::ApplyScaling(creature, mapId, keystoneLevel, isBoss);

        // Apply affix effects on spawn via factory
        sAffixFactory->OnCreatureSpawn(instanceId, creature, isBoss);
    }

    // ========================================================================
    // CREATURE DEATH HOOK
    // ========================================================================
    void OnCreatureKill(Creature* creature, Unit* killer) override
    {
        if (!creature || !killer || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Get run data
        MythicRunData* runData = MythicRunTracker::GetRunData(instanceId);
        if (!runData)
            return;

        // Check if this is a boss kill
        bool isBoss = (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS ||
                       creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE);

        if (isBoss)
        {
            // Record boss kill
            MythicRunTracker::OnBossKilled(map, creature->GetEntry());
        }

        // Apply affix death effects via factory
        sAffixFactory->OnCreatureDeath(instanceId, creature, isBoss);
    }

    // ========================================================================
    // DAMAGE MODIFICATION HOOK
    // ========================================================================
    void ModifyCreatureDamage(Creature* creature, Unit* victim, uint32& damage) override
    {
        if (!creature || !victim || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Apply scaling damage modifier
        MythicDifficultyScaling::ModifyCreatureDamage(creature, victim, damage);

        // Apply affix damage modifiers via factory
        sAffixFactory->OnDamageDealt(instanceId, creature, victim, damage);
    }

    // ========================================================================
    // COMBAT HOOKS
    // ========================================================================
    void OnCreatureEnterCombat(Creature* creature, Unit* target) override
    {
        if (!creature || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Determine if boss
        bool isBoss = (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS ||
                       creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE);

        // Notify affixes about combat start via factory
        sAffixFactory->OnEnterCombat(instanceId, creature, isBoss);
    }

    // ========================================================================
    // HEALTH CHANGE HOOK (for Raging affix)
    // ========================================================================
    void OnCreatureHealthChange(Creature* creature, uint32 /*oldHealth*/, uint32 newHealth) override
    {
        if (!creature || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Calculate health percentage
        uint32 maxHealth = creature->GetMaxHealth();
        if (maxHealth == 0)
            return;

        uint8 healthPct = static_cast<uint8>((newHealth * 100) / maxHealth);

        // Determine if boss
        bool isBoss = (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS ||
                       creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE);

        // Notify affixes about health change via factory
        sAffixFactory->OnHealthPctChanged(instanceId, creature, isBoss, static_cast<float>(healthPct));
    }
};

void AddSC_DungeonEnhancement_CreatureScript()
{
    new DungeonEnhancement_CreatureScript();
}
