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
#include "CrossSystemWorldBossMgr.h"
#include "Creature.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "World.h"

using namespace DarkChaos::CrossSystem;

// Forward declaration for world boss registration
static void RegisterGiantIslesWorldBosses();

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

        // Register world bosses with WorldBossMgr
        RegisterGiantIslesWorldBosses();
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

// =========================================================================
// World Boss Registration
// =========================================================================

static void RegisterGiantIslesWorldBosses()
{
    // Giant Isles world bosses
    // Format: RegisterBoss(entry, spawnId, displayName, zoneId, respawnTimeSeconds)
    // zoneId 5006 = Giant Isles
    sWorldBossMgr->RegisterBoss(400100, 9000190, "Oondasta, King of Dinosaurs", 5006, 1800);
    sWorldBossMgr->RegisterBoss(400101, 9000189, "Thok the Bloodthirsty", 5006, 1800);
    sWorldBossMgr->RegisterBoss(400102, 9000191, "Nalak the Storm Lord", 5006, 1800);

    LOG_INFO("dc.crosssystem", "WorldBossMgr: Registered 3 Giant Isles world bosses");
}
