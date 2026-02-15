/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "EventProcessor.h"
#include "Errors.h"
#include "Log.h"
#include <cstring>

namespace
{
    bool IsEventAlreadyQueued(EventList const& events, BasicEvent const* event)
    {
        for (auto const& entry : events)
            if (entry.second == event)
                return true;
        return false;
    }
}

void BasicEvent::ScheduleAbort()
{
    ASSERT(IsRunning()
           && "Tried to scheduled the abortion of an event twice!");
    m_abortState = AbortState::STATE_ABORT_SCHEDULED;
}

void BasicEvent::SetAborted()
{
    ASSERT(!IsAborted()
           && "Tried to abort an already aborted event!");
    m_abortState = AbortState::STATE_ABORTED;
}

EventProcessor::~EventProcessor()
{
    KillAllEvents(true);
}

void EventProcessor::Update(uint32 p_time)
{
    std::unique_lock<std::recursive_mutex> lock(_lock);

    // update time
    m_time += p_time;

    if (m_events.empty())
        return;

    // Safety limit: prevent infinite loops on corrupted tree.
    // Events can be added during processing, so allow generous headroom.
    const size_t maxIterations = m_events.size() + 1000;
    size_t iterations = 0;

    // main event loop
    // NOTE: the loop is restructured to validate the iterator BEFORE any
    // dereference. Heap corruption (e.g. from transport data races) can
    // zero the multimap's internal leftmost pointer, yielding a null-node
    // iterator that passes != end() but crashes on dereference/erase.
    EventList::iterator i;
    while (true)
    {
        if (m_events.empty())
            break;

        i = m_events.begin();
        if (i == m_events.end())
            break;

        // Defensive: validate iterator's internal node pointer before
        // dereferencing.  In libstdc++ (GCC) an rb_tree iterator is a
        // single pointer (_M_node).  If heap corruption zeroed the tree's
        // leftmost pointer we get a null-node iterator here.
        {
            static_assert(sizeof(EventList::iterator) == sizeof(void*),
                "EventProcessor corruption guard: iterator layout assumption broken");
            void* nodePtr = nullptr;
            std::memcpy(&nodePtr, &i, sizeof(void*));
            if (!nodePtr || reinterpret_cast<uintptr_t>(nodePtr) < 0x10000)
            {
                LOG_ERROR("misc", "EventProcessor::Update: corrupted event tree "
                    "(node ptr {:p}, reported size {}). Leaking corrupted tree to avoid crash.",
                    nodePtr, m_events.size());
                // Swap internals into a heap-allocated map and intentionally
                // leak it — freeing corrupted nodes could deadlock the allocator.
                auto* leaked = new EventList();
                leaked->swap(m_events);
                return;
            }
        }

        // Now safe to dereference the iterator
        if (i->first > m_time)
            break;

        if (++iterations > maxIterations)
        {
            LOG_ERROR("misc", "EventProcessor::Update: exceeded safety limit "
                "({} iterations, {} reported size). Aborting event processing.",
                iterations, m_events.size());
            break;
        }

        // get and remove event from queue
        BasicEvent* event = i->second;

        // Validate event pointer — corrupted node data could yield garbage
        if (!event || reinterpret_cast<uintptr_t>(event) < 0x10000)
        {
            LOG_ERROR("misc", "EventProcessor::Update: corrupted event pointer {:p} in tree node. Removing entry.",
                static_cast<void*>(event));
            m_events.erase(i);
            continue;
        }

        m_events.erase(i);

        uint64 currentTime = m_time;

        lock.unlock();

        bool deleteEvent = false;

        if (event->IsRunning())
        {
            deleteEvent = event->Execute(currentTime, p_time);
        }
        else
        {
            if (event->IsAbortScheduled())
            {
                event->Abort(currentTime);
                // Mark the event as aborted
                event->SetAborted();
            }

            if (event->IsDeletable())
                deleteEvent = true;
        }

        lock.lock();

        if (deleteEvent)
        {
            delete event;
            continue;
        }

        // Reschedule non deletable events to be checked at
        // the next update tick.
        // Some events (e.g. SpellEvent delayed states) re-queue themselves
        // during Execute(). Avoid inserting the same pointer twice.
        if (!IsEventAlreadyQueued(m_events, event))
            AddEvent(event, CalculateTime(1), false);
    }
}

void EventProcessor::KillAllEvents(bool force)
{
    std::lock_guard<std::recursive_mutex> lock(_lock);

    // first, abort all existing events
    for (auto itr = m_events.begin(); itr != m_events.end();)
    {
        // Abort events which weren't aborted already
        if (!itr->second->IsAborted())
        {
            itr->second->SetAborted();
            itr->second->Abort(m_time);
        }

        // Skip non-deletable events when we are
        // not forcing the event cancellation.
        if (!force && !itr->second->IsDeletable())
        {
            ++itr;
            continue;
        }

        delete itr->second;

        if (force)
            ++itr; // Clear the whole container when forcing
        else
            itr = m_events.erase(itr);
    }

    if (force)
        m_events.clear();
}

void EventProcessor::CancelEventGroup(uint8 group)
{
    std::lock_guard<std::recursive_mutex> lock(_lock);

    for (auto itr = m_events.begin(); itr != m_events.end();)
    {
        if (itr->second->m_eventGroup != group)
        {
            ++itr;
            continue;
        }

        // Abort events which weren't aborted already
        if (!itr->second->IsAborted())
        {
            itr->second->SetAborted();
            itr->second->Abort(m_time);
        }

        delete itr->second;
        itr = m_events.erase(itr);
    }
}

void EventProcessor::AddEvent(BasicEvent* Event, uint64 e_time, bool set_addtime /*= true*/, uint8 eventGroup /*= 0*/)
{
    std::lock_guard<std::recursive_mutex> lock(_lock);

    if (set_addtime)
        Event->m_addTime = m_time;
    Event->m_execTime = e_time;
    Event->m_eventGroup = eventGroup;
    m_events.emplace(e_time, Event);
}

void EventProcessor::ModifyEventTime(BasicEvent* event, Milliseconds newTime)
{
    std::lock_guard<std::recursive_mutex> lock(_lock);

    for (auto itr = m_events.begin(); itr != m_events.end(); ++itr)
    {
        if (itr->second != event)
            continue;

        event->m_execTime = newTime.count();
        m_events.erase(itr);
        m_events.emplace(newTime.count(), event);
        break;
    }
}

uint64 EventProcessor::CalculateTime(uint64 t_offset) const
{
    std::lock_guard<std::recursive_mutex> lock(_lock);
    return (m_time + t_offset);
}

uint64 EventProcessor::CalculateQueueTime(uint64 delay) const
{
    std::lock_guard<std::recursive_mutex> lock(_lock);
    return CalculateTime(delay - (m_time % delay));
}
