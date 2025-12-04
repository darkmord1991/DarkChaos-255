/*
 * DarkChaos Cross-System World Script
 *
 * Hooks into AzerothCore's world events to trigger cross-system functionality.
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#include "CrossSystemManager.h"
#include "CrossSystemAdapters.h"
#include "Creature.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "World.h"

using namespace DarkChaos::CrossSystem;

// =========================================================================
// World Script - Global Hooks
// =========================================================================

class CrossSystemWorldScript : public WorldScript
{
public:
    CrossSystemWorldScript() : WorldScript("dc_cross_system_world") {}
    
    void OnStartup() override
    {
        LOG_INFO("dc.crosssystem", "CrossSystemWorldScript: OnStartup");
        GetManager()->Initialize();
        
        // Register all system adapters
        Adapters::RegisterAllAdapters();
    }
    
    void OnShutdown() override
    {
        LOG_INFO("dc.crosssystem", "CrossSystemWorldScript: OnShutdown");
        GetManager()->Shutdown();
    }
    
    void OnUpdate(uint32 diff) override
    {
        GetManager()->OnWorldUpdate(diff);
    }
};

// =========================================================================
// Player Script - Player Lifecycle Hooks
// =========================================================================

class CrossSystemPlayerScript : public PlayerScript
{
public:
    CrossSystemPlayerScript() : PlayerScript("dc_cross_system_player") {}
    
    void OnPlayerLogin(Player* player) override
    {
        GetManager()->OnPlayerLogin(player, false);  // Note: firstLogin not available in this hook
    }
    
    void OnPlayerLogout(Player* player) override
    {
        GetManager()->OnPlayerLogout(player);
    }
    
    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        GetManager()->OnPlayerLevelChanged(player, oldLevel, player->GetLevel());
    }
    
    void OnPlayerKilledByCreature(Creature* /*killer*/, Player* player) override
    {
        GetManager()->OnPlayerDeath(player, nullptr);
    }
    
    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        GetManager()->OnPlayerDeath(killed, killer);
    }
    
    void OnPlayerMapChanged(Player* player) override
    {
        if (player && player->GetMap())
        {
            GetManager()->OnPlayerEnterMap(player, player->GetMap());
        }
    }
    
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (player && quest)
        {
            GetManager()->OnQuestComplete(player, quest->GetQuestId());
        }
    }
    
    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return;
            
        // Check if it's a boss
        bool isBoss = creature->IsDungeonBoss() || creature->isWorldBoss();
        
        if (isBoss)
        {
            GetManager()->OnBossKilled(player, creature, creature->isWorldBoss());
        }
        else
        {
            GetManager()->OnCreatureKilled(player, creature);
        }
    }
};

// =========================================================================
// Registration
// =========================================================================

void AddSC_dc_cross_system_scripts()
{
    new CrossSystemWorldScript();
    new CrossSystemPlayerScript();
}
