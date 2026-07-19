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
#include "Chat.h"
#include "Creature.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "World.h"
#include "dc_update_profiler.h"

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

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        // Loads at startup and again on `.reload config`.
        sWorldBossMgr->LoadConfig();
    }

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
        DarkChaos::ScopedUpdateProfiler _prof("CrossSystem");
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
// World Boss Loot Lockout - Global Loot Hooks
// =========================================================================

class CrossSystemWorldBossLootScript : public GlobalScript
{
public:
    CrossSystemWorldBossLootScript() : GlobalScript("dc_world_boss_loot") {}

    // Item-level eligibility. Called many times (per item, per group viewer), so it stays SILENT.
    // Per CALL_ENABLED_BOOLEAN_HOOKS, returning true here BLOCKS the item for this player.
    bool OnAllowedForPlayerLootCheck(Player const* player, ObjectGuid source) override
    {
        return IsLockedForBoss(player, source.GetEntry());
    }

    // Corpse open. Fires once in Player::SendLoot; the natural place for the one-shot message.
    bool OnAllowedToLootContainerCheck(Player const* player, ObjectGuid source) override
    {
        uint32 const entry = source.GetEntry();
        if (!IsLockedForBoss(player, entry))
            return false; // allow

        if (player)
        {
            std::string name = "this world boss";
            if (DarkChaos::CrossSystem::WorldBossInfo* info = sWorldBossMgr->GetBossInfo(entry))
                name = info->displayName;

            uint32 const remaining = sWorldBossMgr->GetLockoutRemaining(player, entry);
            ChatHandler(player->GetSession()).SendSysMessage(
                Acore::StringFormat("|cffff2020Loot lockout:|r you have already claimed {} this reset. Available again in {}.",
                                    name, WorldBossMgr::FormatDuration(remaining)));
        }
        return true; // block opening the corpse (engine also sends LOOT_ERROR_DIDNT_KILL)
    }

private:
    // True only when the source is one of our registered world bosses AND the player is locked out.
    static bool IsLockedForBoss(Player const* player, uint32 entry)
    {
        if (!sWorldBossMgr->IsLockoutEnabled() || !player)
            return false;
        if (!sWorldBossMgr->GetBossInfo(entry)) // not a managed world boss -> never interfere
            return false;
        return sWorldBossMgr->IsPlayerLockedOut(player, entry);
    }
};

// =========================================================================
// Registration
// =========================================================================

void AddSC_dc_cross_system_scripts()
{
    new CrossSystemWorldScript();
    new CrossSystemPlayerScript();
    new CrossSystemWorldBossLootScript();
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
