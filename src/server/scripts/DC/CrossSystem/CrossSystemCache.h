/*
 * DarkChaos Cache Utilities
 *
 * Generic caching utilities for all DC systems:
 * - TTLCache: Time-to-live expiry
 * - LRUCache: Least-recently-used eviction with bounded size
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#ifndef DC_CACHE_H
#define DC_CACHE_H

#include <unordered_map>
#include <list>
#include <ctime>
#include <cstdint>
#include <mutex>

namespace DarkChaos
{
namespace Cache
{

// =============================================================================
// TTL Cache - Entries expire after configurable time
// =============================================================================

template<typename K, typename V>
class TTLCache
{
public:
    struct Entry
    {
        V value;
        time_t expiresAt;
    };

private:
    std::unordered_map<K, Entry> _data;
    uint32_t _ttlSeconds;
    time_t _lastCleanup;

public:
    explicit TTLCache(uint32_t ttlSeconds = 1800) // Default 30 minutes
        : _ttlSeconds(ttlSeconds), _lastCleanup(0) {}

    // Get entry, returns nullptr if not found or expired
    V* Get(K const& key)
    {
        auto it = _data.find(key);
        if (it == _data.end())
            return nullptr;

        if (std::time(nullptr) > it->second.expiresAt)
        {
            _data.erase(it);
            return nullptr;
        }

        return &it->second.value;
    }

    // Set entry with TTL
    void Set(K const& key, V const& value)
    {
        Entry entry;
        entry.value = value;
        entry.expiresAt = std::time(nullptr) + _ttlSeconds;
        _data[key] = entry;
    }

    // Invalidate specific entry
    void Invalidate(K const& key)
    {
        _data.erase(key);
    }

    // Remove all expired entries
    size_t Cleanup()
    {
        time_t now = std::time(nullptr);
        size_t removed = 0;

        for (auto it = _data.begin(); it != _data.end(); )
        {
            if (now > it->second.expiresAt)
            {
                it = _data.erase(it);
                ++removed;
            }
            else
            {
                ++it;
            }
        }

        _lastCleanup = now;
        return removed;
    }

    // Periodic cleanup (call from Update loop, cleans max once per minute)
    size_t PeriodicCleanup()
    {
        time_t now = std::time(nullptr);
        if (now - _lastCleanup < 60)
            return 0;
        return Cleanup();
    }

    size_t Size() const { return _data.size(); }
    void Clear() { _data.clear(); }

    // Iterate for custom operations (e.g., invalidate by owner)
    template<typename Pred>
    size_t InvalidateIf(Pred pred)
    {
        size_t removed = 0;
        for (auto it = _data.begin(); it != _data.end(); )
        {
            if (pred(it->first, it->second.value))
            {
                it = _data.erase(it);
                ++removed;
            }
            else
            {
                ++it;
            }
        }
        return removed;
    }
};

// =============================================================================
// LRU Cache - Bounded size with least-recently-used eviction
//
// Internally synchronized: the ItemUpgrade instances are read from map-worker
// threads (the _ApplyItemBonuses stat hooks and the proc-scaling UnitScript
// hooks run inside Map::Update) while the world thread and async DB
// continuations write. Get() mutates the LRU list, so even lookups need the
// lock.
//
// Pointer contract: Get() returns a pointer into a std::list node, which is
// stable across splices and other inserts. It is only freed by eviction of
// that same entry, Invalidate, or Clear -- and a just-returned entry sits at
// the front of the LRU, so evicting it takes _maxSize intervening inserts.
// Callers may use the pointer within the current call/tick but must not store
// it. Set() on an existing key overwrites the value in place; concurrent
// readers of non-POD members must tolerate that (current callers only read
// PODs from worker threads).
// =============================================================================

template<typename K, typename V>
class LRUCache
{
    struct Node
    {
        K key;
        V value;
    };

    std::list<Node> _lru;
    std::unordered_map<K, typename std::list<Node>::iterator> _map;
    size_t _maxSize;
    mutable std::mutex _mutex;

public:
    explicit LRUCache(size_t maxSize = 10000)
        : _maxSize(maxSize) {}

    // Get entry, moves to front (most recently used)
    V* Get(K const& key)
    {
        std::lock_guard<std::mutex> guard(_mutex);
        auto it = _map.find(key);
        if (it == _map.end())
            return nullptr;

        // Move to front
        _lru.splice(_lru.begin(), _lru, it->second);
        return &it->second->value;
    }

    // Set entry, evicts LRU if full
    void Set(K const& key, V const& value)
    {
        std::lock_guard<std::mutex> guard(_mutex);
        auto it = _map.find(key);
        if (it != _map.end())
        {
            // Update existing
            it->second->value = value;
            _lru.splice(_lru.begin(), _lru, it->second);
            return;
        }

        // Insert new
        if (_lru.size() >= _maxSize)
        {
            // Evict LRU (back of list)
            auto& evicted = _lru.back();
            _map.erase(evicted.key);
            _lru.pop_back();
        }

        _lru.push_front({key, value});
        _map[key] = _lru.begin();
    }

    // Invalidate specific entry
    void Invalidate(K const& key)
    {
        std::lock_guard<std::mutex> guard(_mutex);
        auto it = _map.find(key);
        if (it != _map.end())
        {
            _lru.erase(it->second);
            _map.erase(it);
        }
    }

    size_t Size() const
    {
        std::lock_guard<std::mutex> guard(_mutex);
        return _map.size();
    }

    size_t MaxSize() const { return _maxSize; }

    void Clear()
    {
        std::lock_guard<std::mutex> guard(_mutex);
        _lru.clear();
        _map.clear();
    }

    // Iterate for custom operations
    template<typename Pred>
    size_t InvalidateIf(Pred pred)
    {
        std::lock_guard<std::mutex> guard(_mutex);
        size_t removed = 0;
        for (auto it = _lru.begin(); it != _lru.end(); )
        {
            if (pred(it->key, it->value))
            {
                _map.erase(it->key);
                it = _lru.erase(it);
                ++removed;
            }
            else
            {
                ++it;
            }
        }
        return removed;
    }
};

// =============================================================================
// Player-keyed cache helper
// =============================================================================

template<typename V>
class PlayerCache : public TTLCache<uint32_t, V>
{
public:
    explicit PlayerCache(uint32_t ttlSeconds = 1800)
        : TTLCache<uint32_t, V>(ttlSeconds) {}

    // Clear all entries for a specific player
    void OnPlayerLogout(uint32_t playerGuid)
    {
        this->Invalidate(playerGuid);
    }
};

} // namespace Cache
} // namespace DarkChaos

#endif // DC_CACHE_H
