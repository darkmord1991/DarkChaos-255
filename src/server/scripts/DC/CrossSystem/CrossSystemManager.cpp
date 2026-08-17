/*
 * DarkChaos Cross-System Manager Implementation
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#include "CrossSystemManager.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "Map.h"
#include "MapMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Timer.h"
#include "World.h"
#include "CrossSystemWorldBossMgr.h"

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // Singleton
    // =========================================================================

    CrossSystemManager* CrossSystemManager::instance()
    {
        static CrossSystemManager instance;
        return &instance;
    }

    // =========================================================================
    // Initialization
    // =========================================================================

    void CrossSystemManager::Initialize()
    {
        if (initialized_)
            return;

        LOG_INFO("dc.crosssystem", "Initializing DarkChaos Cross-System Integration...");

        // Initialize subsystems
        eventBus_ = EventBus::instance();
        rewardDistributor_ = RewardDistributor::instance();
        sessionManager_ = SessionManager::instance();

        // Load configuration
        LoadConfiguration();

        // Initialize reward distributor
        rewardDistributor_->LoadConfiguration();

        initialized_ = true;

        LOG_INFO("dc.crosssystem", "Cross-System Integration initialized");
    }

    void CrossSystemManager::Shutdown()
    {
        if (!initialized_)
            return;

        LOG_INFO("dc.crosssystem", "Shutting down Cross-System Integration...");

        // Save any dirty sessions
        if (sessionManager_)
            sessionManager_->SaveDirtySessions();

        initialized_ = false;
    }

    // =========================================================================
    // Player Session Hooks
    // =========================================================================

    void CrossSystemManager::OnPlayerLogin(Player* player, bool firstLogin)
    {
        if (!globalEnabled_ || !player)
            return;

        // Create session
        auto* session = sessionManager_->CreateSession(player);
        if (session)
        {
            session->RefreshProgression(player);
        }

        // Publish event
        eventBus_->PublishSimple(EventType::PlayerLogin, player->GetGUID(),
                                player->GetMapId(), player->GetInstanceId());

        LOG_DEBUG("dc.crosssystem", "Player {} logged in (first: {})",
                  player->GetName(), firstLogin);
    }

    void CrossSystemManager::OnPlayerLogout(Player* player)
    {
        if (!globalEnabled_ || !player)
            return;

        // Publish event before destroying session
        eventBus_->PublishSimple(EventType::PlayerLogout, player->GetGUID(),
                                player->GetMapId(), player->GetInstanceId());

        // Destroy session
        sessionManager_->DestroySession(player->GetGUID());

        LOG_DEBUG("dc.crosssystem", "Player {} logged out", player->GetName());
    }

    void CrossSystemManager::OnPlayerLevelChanged(Player* player, uint8 oldLevel, uint8 newLevel)
    {
        if (!globalEnabled_ || !player)
            return;

        if (newLevel > oldLevel)
        {
            eventBus_->PublishSimple(EventType::PlayerLevelUp, player->GetGUID(),
                                    player->GetMapId(), player->GetInstanceId());
        }

        // Update session
        if (auto* session = sessionManager_->GetSession(player))
        {
            session->RefreshProgression(player);
        }
    }

    void CrossSystemManager::OnPlayerDeath(Player* player, Player* /*killer*/)
    {
        if (!globalEnabled_ || !player)
            return;

        // Update session
        if (auto* session = sessionManager_->GetSession(player))
        {
            session->IncrementDeaths();
        }

        eventBus_->PublishSimple(EventType::PlayerDeath, player->GetGUID(),
                                player->GetMapId(), player->GetInstanceId());
    }

    // =========================================================================
    // Content Hooks
    // =========================================================================

    void CrossSystemManager::OnPlayerEnterMap(Player* player, Map* map)
    {
        if (!globalEnabled_ || !player || !map)
            return;

        auto* session = sessionManager_->GetSession(player);
        if (!session)
            return;

        // Determine content type
        ContentType contentType = ContentType::OpenWorld;
        ContentDifficulty difficulty = ContentDifficulty::Normal;

        if (map->IsDungeon())
        {
            contentType = ContentType::Dungeon;

            switch (map->GetDifficulty())
            {
                case DUNGEON_DIFFICULTY_NORMAL:
                    difficulty = ContentDifficulty::Normal;
                    break;
                case DUNGEON_DIFFICULTY_HEROIC:
                case DUNGEON_DIFFICULTY_EPIC:
                    difficulty = ContentDifficulty::Heroic;
                    break;
                default:
                    break;
            }
        }
        else if (map->IsRaid())
        {
            contentType = ContentType::Raid;

            switch (map->GetDifficulty())
            {
                case RAID_DIFFICULTY_10MAN_NORMAL:
                    difficulty = ContentDifficulty::Raid10N;
                    break;
                case RAID_DIFFICULTY_10MAN_HEROIC:
                    difficulty = ContentDifficulty::Raid10H;
                    break;
                case RAID_DIFFICULTY_25MAN_NORMAL:
                    difficulty = ContentDifficulty::Raid25N;
                    break;
                case RAID_DIFFICULTY_25MAN_HEROIC:
                    difficulty = ContentDifficulty::Raid25H;
                    break;
                default:
                    break;
            }
        }
        else if (map->IsBattleground())
        {
            contentType = ContentType::Battleground;
        }
        else if (map->IsBattleArena())
        {
            contentType = ContentType::Arena;
        }

        session->SetActiveContent(contentType, difficulty, map->GetId(),
                                  map->GetInstanceId(), 0);

        eventBus_->PublishSimple(EventType::DungeonEnter, player->GetGUID(),
                                map->GetId(), map->GetInstanceId());
    }

    void CrossSystemManager::OnPlayerLeaveMap(Player* player, Map* map)
    {
        if (!globalEnabled_ || !player || !map)
            return;

        eventBus_->PublishSimple(EventType::DungeonLeave, player->GetGUID(),
                                map->GetId(), map->GetInstanceId());

        if (auto* session = sessionManager_->GetSession(player))
        {
            session->ClearActiveContent();
        }
    }

    void CrossSystemManager::OnPlayerEnterDungeon(Player* /*player*/, Map* /*map*/, Difficulty /*difficulty*/)
    {
        // More specific dungeon handling is done in OnPlayerEnterMap
    }

    void CrossSystemManager::OnPlayerLeaveDungeon(Player* /*player*/, Map* /*map*/)
    {
        // Handled by OnPlayerLeaveMap
    }

    // =========================================================================
    // Combat Hooks
    // =========================================================================

    void CrossSystemManager::OnCreatureKilled(Player* player, Creature* creature)
    {
        if (!globalEnabled_ || !player || !creature)
            return;

        auto* session = sessionManager_->GetSession(player);
        uint8 keystoneLevel = session ? session->GetActiveContent().keystoneLevel : 0;

        if (session)
            session->IncrementTrashKills(1);

        eventBus_->PublishCreatureKill(player, creature, false, keystoneLevel,
                                       player->GetGroup() ? player->GetGroup()->GetMembersCount() : 1);
    }

    void CrossSystemManager::OnBossKilled(Player* player, Creature* boss, bool isRaidBoss)
    {
        if (!globalEnabled_ || !player || !boss)
            return;

        auto* session = sessionManager_->GetSession(player);
        uint8 keystoneLevel = session ? session->GetActiveContent().keystoneLevel : 0;

        if (session)
        {
            session->IncrementBossKills();
        }

        eventBus_->PublishCreatureKill(player, boss, true, keystoneLevel,
                                       player->GetGroup() ? player->GetGroup()->GetMembersCount() : 1);

        // Also publish specific boss event
        EventType eventType = isRaidBoss ? EventType::WorldBossKill : EventType::BossKill;
        eventBus_->PublishSimple(eventType, player->GetGUID(),
                                player->GetMapId(), player->GetInstanceId());
    }

    // =========================================================================
    // Quest Hooks
    // =========================================================================

    void CrossSystemManager::OnQuestComplete(Player* player, uint32 questId)
    {
        if (!globalEnabled_ || !player)
            return;

        eventBus_->PublishQuestComplete(player, questId, false, false);

        if (auto* session = sessionManager_->GetSession(player))
        {
            session->IncrementSessionStat("quests");
        }
    }

    void CrossSystemManager::OnDailyQuestComplete(Player* player, uint32 questId)
    {
        if (!globalEnabled_ || !player)
            return;

        eventBus_->PublishQuestComplete(player, questId, true, false);
    }

    void CrossSystemManager::OnWeeklyQuestComplete(Player* player, uint32 questId)
    {
        if (!globalEnabled_ || !player)
            return;

        eventBus_->PublishQuestComplete(player, questId, false, true);
    }

    // =========================================================================
    // Item Hooks
    // =========================================================================

    void CrossSystemManager::OnItemUpgrade(Player* player, uint32 itemGuid, uint8 fromLevel, uint8 toLevel)
    {
        if (!globalEnabled_ || !player)
            return;

        // Item entry would need to be looked up
        eventBus_->PublishItemUpgrade(player, itemGuid, 0, fromLevel, toLevel, 0, 0, 0);

        if (auto* session = sessionManager_->GetSession(player))
        {
            session->IncrementSessionStat("items_upgraded");
        }
    }

    // =========================================================================
    // Periodic Update
    // =========================================================================

    void CrossSystemManager::Update(uint32 diff)
    {
        if (!globalEnabled_ || !initialized_)
            return;

        saveTimer_ += diff;

        // Save dirty sessions every 5 minutes
        if (saveTimer_ >= 5 * 60 * 1000)
        {
            sessionManager_->SaveDirtySessions();
            sessionManager_->CleanupExpiredRewards();
            saveTimer_ = 0;
        }
    }

    void CrossSystemManager::OnWorldUpdate(uint32 diff)
    {
        Update(diff);

        // Tick WorldBossMgr so addon timers/countdowns remain accurate.
        sWorldBossMgr->Update(diff);
    }

    // =========================================================================
    // Weekly/Seasonal
    // =========================================================================

    void CrossSystemManager::OnWeeklyReset()
    {
        if (!globalEnabled_)
            return;

        LOG_INFO("dc.crosssystem", "Processing weekly reset...");

        // Publish to all listening systems
        EventData event;
        event.type = EventType::WeeklyResetOccurred;
        event.timestamp = GameTime::GetGameTime().count();
        eventBus_->Publish(event);
    }

    void CrossSystemManager::OnSeasonStart(uint32 seasonId)
    {
        if (!globalEnabled_)
            return;

        LOG_INFO("dc.crosssystem", "Season {} started", seasonId);

        EventData event;
        event.type = EventType::SeasonStart;
        event.timestamp = GameTime::GetGameTime().count();
        event.mapId = seasonId;  // Repurposing mapId for seasonId
        eventBus_->Publish(event);
    }

    void CrossSystemManager::OnSeasonEnd(uint32 seasonId)
    {
        if (!globalEnabled_)
            return;

        LOG_INFO("dc.crosssystem", "Season {} ended", seasonId);

        EventData event;
        event.type = EventType::SeasonEnd;
        event.timestamp = GameTime::GetGameTime().count();
        event.mapId = seasonId;
        eventBus_->Publish(event);
    }

    // =========================================================================
    // Configuration
    // =========================================================================

    void CrossSystemManager::LoadConfiguration()
    {
        // Load from dc_cross_system_config table (to be created)
        LOG_DEBUG("dc.crosssystem", "Loading cross-system configuration...");

        globalEnabled_ = true;  // Default enabled
    }

} // namespace CrossSystem
} // namespace DarkChaos
