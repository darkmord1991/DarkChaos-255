/*
 * ============================================================================
 * Dungeon Enhancement System - Affix Handler Factory
 * ============================================================================
 * Purpose: Factory pattern for creating affix handler instances
 * Pattern: Registry maps affix IDs to factory functions
 * ============================================================================
 */

#ifndef MYTHIC_AFFIX_FACTORY_H
#define MYTHIC_AFFIX_FACTORY_H

#include "MythicAffixHandler.h"
#include "DungeonEnhancementManager.h"
#include <unordered_map>
#include <functional>
#include <memory>

namespace DungeonEnhancement
{
    // Factory function signature
    using AffixFactoryFunction = std::function<MythicAffixHandler*(AffixData*)>;

    /**
     * Singleton factory for creating affix handler instances
     */
    class MythicAffixFactory
    {
    private:
        MythicAffixFactory() = default;
        ~MythicAffixFactory() = default;

        // Registry: affixId -> factory function
        std::unordered_map<uint32, AffixFactoryFunction> _registry;

        // Active handlers: mapInstanceId -> list of active handlers
        std::unordered_map<uint32, std::vector<MythicAffixHandler*>> _activeHandlers;

    public:
        // Singleton access
        static MythicAffixFactory* Instance()
        {
            static MythicAffixFactory instance;
            return &instance;
        }

        /**
         * Register an affix handler factory function
         * @param affixId Database affix ID
         * @param factoryFunc Function that creates handler instance
         */
        void RegisterHandler(uint32 affixId, AffixFactoryFunction factoryFunc)
        {
            _registry[affixId] = factoryFunc;
        }

        /**
         * Create a handler instance for an affix
         * @param affixId Database affix ID
         * @param affixData Affix configuration data
         * @return New handler instance or nullptr if not registered
         */
        MythicAffixHandler* CreateHandler(uint32 affixId, AffixData* affixData)
        {
            auto it = _registry.find(affixId);
            if (it == _registry.end())
            {
                LOG_ERROR("dungeon.enhancement.affixes", 
                          "No factory registered for affix ID {}", affixId);
                return nullptr;
            }

            return it->second(affixData);
        }

        /**
         * Create all active handlers for a keystone level
         * @param keystoneLevel M+ level (determines which affixes are active)
         * @return Vector of handler instances
         */
        std::vector<MythicAffixHandler*> CreateActiveHandlers(uint8 keystoneLevel)
        {
            std::vector<MythicAffixHandler*> handlers;

            // Get current active affixes from manager
            std::vector<uint32> activeAffixIds = 
                sDungeonEnhancementMgr->GetCurrentActiveAffixes(keystoneLevel);

            for (uint32 affixId : activeAffixIds)
            {
                AffixData* affixData = sDungeonEnhancementMgr->GetAffixById(affixId);
                if (!affixData)
                    continue;

                MythicAffixHandler* handler = CreateHandler(affixId, affixData);
                if (handler)
                    handlers.push_back(handler);
            }

            return handlers;
        }

        /**
         * Initialize handlers for a map instance
         * @param instanceId Map instance ID
         * @param keystoneLevel M+ level
         */
        void InitializeInstanceHandlers(uint32 instanceId, uint8 keystoneLevel)
        {
            // Clean up existing handlers
            CleanupInstanceHandlers(instanceId);

            // Create new handlers
            _activeHandlers[instanceId] = CreateActiveHandlers(keystoneLevel);

            LOG_INFO("dungeon.enhancement.affixes",
                     "Initialized {} affix handlers for instance {}",
                     _activeHandlers[instanceId].size(), instanceId);
        }

        /**
         * Get active handlers for an instance
         * @param instanceId Map instance ID
         * @return Vector of active handler pointers
         */
        std::vector<MythicAffixHandler*> GetInstanceHandlers(uint32 instanceId)
        {
            auto it = _activeHandlers.find(instanceId);
            if (it == _activeHandlers.end())
                return {};

            return it->second;
        }

        /**
         * Cleanup handlers for an instance
         * @param instanceId Map instance ID
         */
        void CleanupInstanceHandlers(uint32 instanceId)
        {
            auto it = _activeHandlers.find(instanceId);
            if (it == _activeHandlers.end())
                return;

            // Delete all handler instances
            for (MythicAffixHandler* handler : it->second)
                delete handler;

            _activeHandlers.erase(it);

            LOG_DEBUG("dungeon.enhancement.affixes",
                      "Cleaned up affix handlers for instance {}", instanceId);
        }

        /**
         * Call OnCreatureSpawn for all active handlers
         */
        void OnCreatureSpawn(uint32 instanceId, Creature* creature, bool isBoss)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
            {
                if (handler->ShouldAffectCreature(creature, isBoss))
                    handler->OnCreatureSpawn(creature, isBoss);
            }
        }

        /**
         * Call OnCreatureDeath for all active handlers
         */
        void OnCreatureDeath(uint32 instanceId, Creature* creature, bool isBoss)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
            {
                if (handler->ShouldAffectCreature(creature, isBoss))
                    handler->OnCreatureDeath(creature, isBoss);
            }
        }

        /**
         * Call OnDamageDealt for all active handlers
         */
        void OnDamageDealt(uint32 instanceId, Creature* attacker, Unit* victim, uint32& damage)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
                handler->OnDamageDealt(attacker, victim, damage);
        }

        /**
         * Call OnPlayerDamaged for all active handlers
         */
        void OnPlayerDamaged(uint32 instanceId, Player* player, Creature* attacker, uint32& damage)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
                handler->OnPlayerDamaged(player, attacker, damage);
        }

        /**
         * Call OnPeriodicTick for all active handlers
         */
        void OnPeriodicTick(uint32 instanceId, Map* map)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
                handler->OnPeriodicTick(map);
        }

        /**
         * Call OnEnterCombat for all active handlers
         */
        void OnEnterCombat(uint32 instanceId, Creature* creature, bool isBoss)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
            {
                if (handler->ShouldAffectCreature(creature, isBoss))
                    handler->OnEnterCombat(creature, isBoss);
            }
        }

        /**
         * Call OnHealthPctChanged for all active handlers
         */
        void OnHealthPctChanged(uint32 instanceId, Creature* creature, bool isBoss, float healthPct)
        {
            for (MythicAffixHandler* handler : GetInstanceHandlers(instanceId))
            {
                if (handler->ShouldAffectCreature(creature, isBoss))
                    handler->OnHealthPctChanged(creature, isBoss, healthPct);
            }
        }

        /**
         * Cleanup all handlers (called on shutdown)
         */
        void Cleanup()
        {
            for (auto& pair : _activeHandlers)
            {
                for (MythicAffixHandler* handler : pair.second)
                    delete handler;
            }

            _activeHandlers.clear();
            _registry.clear();
        }
    };

} // namespace DungeonEnhancement

// Convenience macro
#define sAffixFactory DungeonEnhancement::MythicAffixFactory::Instance()

#endif // MYTHIC_AFFIX_FACTORY_H
