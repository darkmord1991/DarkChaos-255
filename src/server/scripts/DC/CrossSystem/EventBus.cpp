/*
 * DarkChaos Cross-System Event Bus Implementation
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#include "EventBus.h"
#include "CrossSystemManager.h"
#include "Creature.h"
#include "GameTime.h"
#include "Log.h"
#include "Player.h"
#include "Timer.h"
#include <algorithm>
#include <chrono>

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // EventSubscription
    // =========================================================================

    bool EventSubscription::Matches(EventData const& event) const
    {
        if (!enabled)
            return false;

        if (eventType != event.type)
            return false;

        // Optional filters
        // (Content type and difficulty filters would require the event to have this info)

        if (mapIdFilter.has_value() && mapIdFilter.value() != event.mapId)
            return false;

        return true;
    }

    // =========================================================================
    // EventBus Implementation
    // =========================================================================

    EventBus* EventBus::instance()
    {
        static EventBus instance;
        return &instance;
    }

    // =========================================================================
    // Subscription Management
    // =========================================================================

    uint64 EventBus::Subscribe(IEventHandler* handler, EventType eventType, uint8 priority)
    {
        if (!handler || eventType == EventType::None)
            return 0;

        std::lock_guard<std::mutex> lock(mutex_);

        EventSubscription sub;
        sub.id = nextSubscriptionId_++;
        sub.subscriberSystem = handler->GetSystemId();
        sub.eventType = eventType;
        sub.handler = handler;
        sub.priority = priority;
        sub.enabled = true;

        subscriptions_[eventType].push_back(sub);

        // Sort by priority
        std::sort(subscriptions_[eventType].begin(), subscriptions_[eventType].end(),
            [](EventSubscription const& a, EventSubscription const& b) {
                return a.priority < b.priority;
            });

        if (verboseLogging_)
        {
            LOG_DEBUG("dc.crosssystem.events", "System {} subscribed to event {} with priority {}",
                      handler->GetSystemName(), static_cast<uint16>(eventType), priority);
        }

        return sub.id;
    }

    void EventBus::SubscribeMultiple(IEventHandler* handler, std::vector<EventType> const& eventTypes, uint8 priority)
    {
        for (EventType type : eventTypes)
        {
            Subscribe(handler, type, priority);
        }
    }

    void EventBus::SubscribeHandler(IEventHandler* handler)
    {
        if (!handler)
            return;

        auto events = handler->GetSubscribedEvents();
        SubscribeMultiple(handler, events, handler->GetPriority());
    }

    void EventBus::Unsubscribe(uint64 subscriptionId)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [type, subs] : subscriptions_)
        {
            subs.erase(
                std::remove_if(subs.begin(), subs.end(),
                    [subscriptionId](EventSubscription const& s) {
                        return s.id == subscriptionId;
                    }),
                subs.end());
        }
    }

    void EventBus::UnsubscribeHandler(IEventHandler* handler)
    {
        if (!handler)
            return;

        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [type, subs] : subscriptions_)
        {
            subs.erase(
                std::remove_if(subs.begin(), subs.end(),
                    [handler](EventSubscription const& s) {
                        return s.handler == handler;
                    }),
                subs.end());
        }
    }

    void EventBus::UnsubscribeSystem(SystemId system)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [type, subs] : subscriptions_)
        {
            subs.erase(
                std::remove_if(subs.begin(), subs.end(),
                    [system](EventSubscription const& s) {
                        return s.subscriberSystem == system;
                    }),
                subs.end());
        }
    }

    void EventBus::SetSubscriptionEnabled(uint64 subscriptionId, bool enabled)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [type, subs] : subscriptions_)
        {
            for (auto& sub : subs)
            {
                if (sub.id == subscriptionId)
                {
                    sub.enabled = enabled;
                    return;
                }
            }
        }
    }

    void EventBus::SetSystemEnabled(SystemId system, bool enabled)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [type, subs] : subscriptions_)
        {
            for (auto& sub : subs)
            {
                if (sub.subscriberSystem == system)
                    sub.enabled = enabled;
            }
        }
    }

    // =========================================================================
    // Event Publishing
    // =========================================================================

    void EventBus::Publish(EventData const& event, SystemId sourceSystem)
    {
        // steady_clock, not high_resolution_clock: the latter is permitted to
        // be non-monotonic, which can yield negative processing times.
        auto const startTime = std::chrono::steady_clock::now();

        std::vector<EventSubscription> const handlers = GetHandlersForEvent(event.type);

        // Tally locally and apply once. This loop used to re-acquire mutex_ on
        // every single handler invocation just to bump two counters, so a
        // publish cost 2N+1 lock acquisitions. Publish is reached from
        // creature-kill and quest hooks running on map update threads, so that
        // contention was real rather than theoretical.
        uint32 handlerCount = 0;
        uint64 errorCount = 0;
        std::vector<SystemId> invokedSystems;
        invokedSystems.reserve(handlers.size());

        for (auto const& sub : handlers)
        {
            if (!sub.Matches(event))
                continue;

            try
            {
                sub.handler->OnEvent(event);
                ++handlerCount;
                invokedSystems.push_back(sub.subscriberSystem);
            }
            catch (std::exception const& e)
            {
                LOG_ERROR("dc.crosssystem.events", "Exception in event handler {}: {}",
                          sub.handler->GetSystemName(), e.what());
                ++errorCount;
            }
        }

        auto const duration = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - startTime);

        bool recordHistory = false;

        {
            std::lock_guard<std::mutex> lock(mutex_);

            stats_.totalHandlersInvoked += handlerCount;
            for (SystemId system : invokedSystems)
                stats_.systemHandlerCounts[system]++;

            stats_.errors += errorCount;
            stats_.totalEventsPublished++;
            stats_.totalEventsProcessed++;
            stats_.eventCounts[event.type]++;

            // Read under the lock; EnableHistory() writes it concurrently.
            recordHistory = historyEnabled_;
        }

        if (recordHistory)
        {
            RecordHistory(event, sourceSystem, handlerCount, duration.count());
        }

        if (verboseLogging_)
        {
            LOG_DEBUG("dc.crosssystem.events", "Published event {} to {} handlers in {} us",
                      static_cast<uint16>(event.type), handlerCount, duration.count());
        }
    }

    void EventBus::PublishSimple(EventType type, ObjectGuid playerGuid, uint32 mapId,
                                 uint32 instanceId, SystemId sourceSystem)
    {
        EventData event;
        event.type = type;
        event.timestamp = GameTime::GetGameTime().count();
        event.playerGuid = playerGuid;
        event.mapId = mapId;
        event.instanceId = instanceId;

        Publish(event, sourceSystem);
    }

    // PublishAsync()/ProcessAsyncEvents() lived here. Nothing ever called
    // PublishAsync, so the queue was permanently empty while
    // CrossSystemManager::Update() drained it every 100 ms - a lock acquisition
    // per tick to find nothing. Removed Aug 2026; every publisher is
    // synchronous. If async dispatch is genuinely needed later, add it with a
    // caller in the same change.

    // =========================================================================
    // Typed Event Publishers
    // =========================================================================

    void EventBus::PublishCreatureKill(Player* player, Creature* creature, bool isBoss,
                                       uint8 keystoneLevel, uint32 partySize)
    {
        if (!player || !creature)
            return;

        auto event = std::make_unique<CreatureKillEvent>();
        event->type = isBoss ? EventType::BossKill : EventType::CreatureKill;
        event->timestamp = GameTime::GetGameTime().count();
        event->playerGuid = player->GetGUID();
        event->mapId = player->GetMapId();
        event->instanceId = player->GetInstanceId();
        event->creatureEntry = creature->GetEntry();
        event->isBoss = isBoss;
        event->isRare = creature->isWorldBoss();  // Simplification
        event->isElite = creature->isElite();
        event->keystoneLevel = keystoneLevel;
        event->partySize = partySize;

        Publish(*event, SystemId::None);
    }

    void EventBus::PublishDungeonComplete(DungeonCompleteEvent const& event)
    {
        Publish(event, SystemId::MythicPlus);
    }

    void EventBus::PublishQuestComplete(Player* player, uint32 questId, bool isDaily, bool isWeekly)
    {
        if (!player)
            return;

        auto event = std::make_unique<QuestCompleteEvent>();
        event->type = isDaily ? EventType::DailyQuestComplete
                     : (isWeekly ? EventType::WeeklyQuestComplete : EventType::QuestComplete);
        event->timestamp = GameTime::GetGameTime().count();
        event->playerGuid = player->GetGUID();
        event->mapId = player->GetMapId();
        event->instanceId = player->GetInstanceId();
        event->questId = questId;
        event->isDaily = isDaily;
        event->isWeekly = isWeekly;

        Publish(*event, SystemId::DungeonQuests);
    }

    void EventBus::PublishItemUpgrade(Player* player, uint32 itemGuid, uint32 itemEntry,
                                      uint8 fromLevel, uint8 toLevel, uint8 tierId,
                                      uint32 tokensCost, uint32 essenceCost)
    {
        if (!player)
            return;

        auto event = std::make_unique<ItemUpgradeEvent>();
        event->type = EventType::ItemUpgraded;
        event->timestamp = GameTime::GetGameTime().count();
        event->playerGuid = player->GetGUID();
        event->mapId = player->GetMapId();
        event->instanceId = player->GetInstanceId();
        event->itemGuid = itemGuid;
        event->itemEntry = itemEntry;
        event->fromLevel = fromLevel;
        event->toLevel = toLevel;
        event->tierId = tierId;
        event->tokensCost = tokensCost;
        event->essenceCost = essenceCost;

        Publish(*event, SystemId::ItemUpgrade);
    }

    void EventBus::PublishPrestige(Player* player, uint8 fromPrestige, uint8 toPrestige,
                                   uint8 fromLevel, bool keptGear)
    {
        if (!player)
            return;

        auto event = std::make_unique<PrestigeEvent>();
        event->type = EventType::PlayerPrestige;
        event->timestamp = GameTime::GetGameTime().count();
        event->playerGuid = player->GetGUID();
        event->mapId = player->GetMapId();
        event->instanceId = player->GetInstanceId();
        event->fromPrestige = fromPrestige;
        event->toPrestige = toPrestige;
        event->fromLevel = fromLevel;
        event->keptGear = keptGear;

        Publish(*event, SystemId::Prestige);
    }

    void EventBus::PublishVaultClaim(Player* player, uint32 seasonId, uint8 slotClaimed,
                                     uint32 itemId, uint32 tokens, uint32 essence)
    {
        if (!player)
            return;

        auto event = std::make_unique<VaultClaimEvent>();
        event->type = EventType::VaultClaimed;
        event->timestamp = GameTime::GetGameTime().count();
        event->playerGuid = player->GetGUID();
        event->mapId = player->GetMapId();
        event->instanceId = player->GetInstanceId();
        event->seasonId = seasonId;
        event->slotClaimed = slotClaimed;
        event->itemId = itemId;
        event->tokensClaimed = tokens;
        event->essenceClaimed = essence;

        Publish(*event, SystemId::MythicPlus);
    }

    // =========================================================================
    // Event History
    // =========================================================================

    void EventBus::RecordHistory(EventData const& event, SystemId source,
                                 uint32 handlerCount, uint64 processingTimeUs)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        EventHistoryEntry entry;
        entry.eventId = nextEventId_++;
        entry.type = event.type;
        entry.playerGuid = event.playerGuid;
        entry.mapId = event.mapId;
        entry.timestamp = event.timestamp;
        entry.sourceSystem = source;
        entry.handlerCount = handlerCount;
        entry.processingTimeUs = processingTimeUs;

        eventHistory_.push_back(entry);

        // Trim history if too large
        while (eventHistory_.size() > historyMaxSize_)
        {
            eventHistory_.erase(eventHistory_.begin());
        }
    }

    std::vector<EventHistoryEntry> EventBus::GetHistoryForPlayer(ObjectGuid guid) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<EventHistoryEntry> result;
        for (auto const& entry : eventHistory_)
        {
            if (entry.playerGuid == guid)
                result.push_back(entry);
        }
        return result;
    }

    std::vector<EventHistoryEntry> EventBus::GetHistoryForEventType(EventType type) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<EventHistoryEntry> result;
        for (auto const& entry : eventHistory_)
        {
            if (entry.type == type)
                result.push_back(entry);
        }
        return result;
    }

    void EventBus::ClearHistory()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        eventHistory_.clear();
    }

    // =========================================================================
    // Private Helpers
    // =========================================================================

    std::vector<EventSubscription> EventBus::GetHandlersForEvent(EventType type)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<EventSubscription> result;

        auto it = subscriptions_.find(type);
        if (it != subscriptions_.end())
        {
            for (auto const& sub : it->second)
            {
                if (sub.enabled)
                    result.push_back(sub);
            }
        }

        return result;
    }

    void EventBus::ResetStatistics()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        stats_ = Statistics();
    }

    std::string EventBus::GetDebugInfo() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string info = "=== Event Bus Debug Info ===\n";
        info += "Total Events Published: " + std::to_string(stats_.totalEventsPublished) + "\n";
        info += "Total Handlers Invoked: " + std::to_string(stats_.totalHandlersInvoked) + "\n";
        info += "History Size: " + std::to_string(eventHistory_.size()) + "\n";
        info += "Errors: " + std::to_string(stats_.errors) + "\n";

        return info;
    }

    std::string EventBus::GetSubscriptionSummary() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string summary = "=== Event Subscriptions ===\n";

        for (auto const& [type, subs] : subscriptions_)
        {
            summary += "Event " + std::to_string(static_cast<uint16>(type))
                     + ": " + std::to_string(subs.size()) + " handlers\n";
        }

        return summary;
    }

} // namespace CrossSystem
} // namespace DarkChaos
