# Performance Optimization Framework

**Priority:** A-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** Very High  
**Target System:** All DC Systems

---

## Overview

Comprehensive performance optimizations for all DC systems, focusing on database efficiency, memory management, and update scheduling.

---

## 1. Database Optimization

### Connection Pooling Enhancement

```cpp
// DCDatabasePool.h
#pragma once

#include <queue>
#include <mutex>
#include <condition_variable>

namespace DC
{

class AsyncQueryProcessor
{
public:
    static AsyncQueryProcessor* instance();
    
    // Queue async queries
    void QueueQuery(const std::string& sql, 
        std::function<void(QueryResult)> callback = nullptr);
    
    // Batch queries (execute together in single transaction)
    void QueueBatch(const std::vector<std::string>& queries,
        std::function<void(bool)> callback = nullptr);
    
    // Priority queries (executed before normal queue)
    void QueuePriority(const std::string& sql,
        std::function<void(QueryResult)> callback = nullptr);
    
    // Get queue statistics
    size_t GetQueueSize() const { return _queryQueue.size(); }
    size_t GetProcessedCount() const { return _processedCount; }
    
    // Control
    void Start();
    void Stop();
    void Flush();  // Wait for all pending queries

private:
    AsyncQueryProcessor();
    void ProcessLoop();
    
    std::queue<std::pair<std::string, std::function<void(QueryResult)>>> _queryQueue;
    std::queue<std::pair<std::string, std::function<void(QueryResult)>>> _priorityQueue;
    std::mutex _mutex;
    std::condition_variable _cv;
    std::atomic<bool> _running{false};
    std::atomic<size_t> _processedCount{0};
    std::vector<std::thread> _workers;
};

#define sAsyncQuery DC::AsyncQueryProcessor::instance()

} // namespace DC
```

### Query Batching

```cpp
// DCQueryBatcher.h
namespace DC
{

class QueryBatcher
{
public:
    void Add(const std::string& sql)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _queries.push_back(sql);
    }
    
    void AddUpdate(const std::string& table, 
        const std::map<std::string, std::string>& values,
        const std::string& where)
    {
        std::string sql = "UPDATE " + table + " SET ";
        bool first = true;
        for (const auto& [col, val] : values)
        {
            if (!first) sql += ", ";
            sql += col + " = " + val;
            first = false;
        }
        sql += " WHERE " + where;
        Add(sql);
    }
    
    void AddInsert(const std::string& table,
        const std::vector<std::map<std::string, std::string>>& rows)
    {
        if (rows.empty()) return;
        
        std::string sql = "INSERT INTO " + table + " (";
        
        // Columns
        bool first = true;
        for (const auto& [col, _] : rows[0])
        {
            if (!first) sql += ", ";
            sql += col;
            first = false;
        }
        sql += ") VALUES ";
        
        // Values
        first = true;
        for (const auto& row : rows)
        {
            if (!first) sql += ", ";
            sql += "(";
            bool firstVal = true;
            for (const auto& [_, val] : row)
            {
                if (!firstVal) sql += ", ";
                sql += val;
                firstVal = false;
            }
            sql += ")";
            first = false;
        }
        
        Add(sql);
    }
    
    void Execute()
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (_queries.empty()) return;
        
        // Start transaction
        CharacterDatabase.DirectExecute("START TRANSACTION");
        
        for (const auto& sql : _queries)
        {
            CharacterDatabase.DirectExecute(sql.c_str());
        }
        
        CharacterDatabase.DirectExecute("COMMIT");
        _queries.clear();
    }
    
    void ExecuteAsync(std::function<void(bool)> callback = nullptr)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        sAsyncQuery->QueueBatch(_queries, callback);
        _queries.clear();
    }
    
    size_t Size() const { return _queries.size(); }

private:
    std::vector<std::string> _queries;
    std::mutex _mutex;
};

} // namespace DC
```

### Prepared Statement Cache

```cpp
// DCPreparedCache.h
namespace DC
{

class PreparedStatementCache
{
public:
    static PreparedStatementCache* instance();
    
    // Register prepared statements at startup
    void Register(const std::string& name, const std::string& sql)
    {
        _statements[name] = {
            .sql = sql,
            .stmtId = CharacterDatabase.PrepareStatement(sql)
        };
    }
    
    // Execute prepared statement
    QueryResult Execute(const std::string& name, 
        const std::vector<std::variant<int32, uint32, int64, uint64, float, double, std::string>>& params)
    {
        auto it = _statements.find(name);
        if (it == _statements.end())
            return QueryResult(nullptr);
        
        auto stmt = CharacterDatabase.GetPreparedStatement(it->second.stmtId);
        
        for (size_t i = 0; i < params.size(); ++i)
        {
            std::visit([&](auto&& arg) {
                using T = std::decay_t<decltype(arg)>;
                if constexpr (std::is_same_v<T, int32>)
                    stmt->setInt32(i, arg);
                else if constexpr (std::is_same_v<T, uint32>)
                    stmt->setUInt32(i, arg);
                else if constexpr (std::is_same_v<T, int64>)
                    stmt->setInt64(i, arg);
                else if constexpr (std::is_same_v<T, uint64>)
                    stmt->setUInt64(i, arg);
                else if constexpr (std::is_same_v<T, float>)
                    stmt->setFloat(i, arg);
                else if constexpr (std::is_same_v<T, double>)
                    stmt->setDouble(i, arg);
                else if constexpr (std::is_same_v<T, std::string>)
                    stmt->setString(i, arg);
            }, params[i]);
        }
        
        return CharacterDatabase.Query(stmt);
    }

private:
    struct PreparedStmt
    {
        std::string sql;
        uint32 stmtId;
    };
    
    std::unordered_map<std::string, PreparedStmt> _statements;
};

// Register common DC statements
void RegisterDCPreparedStatements()
{
    auto* cache = PreparedStatementCache::instance();
    
    // Player profile
    cache->Register("profile_load", 
        "SELECT * FROM dc_player_profile WHERE player_guid = ?");
    cache->Register("profile_save",
        "REPLACE INTO dc_player_profile (player_guid, account_id, prestige_level, ...) "
        "VALUES (?, ?, ?, ...)");
    
    // Mythic+
    cache->Register("mythic_run_insert",
        "INSERT INTO dc_mythic_runs (player_guid, dungeon_id, key_level, completion_time, ...) "
        "VALUES (?, ?, ?, ?, ...)");
    cache->Register("mythic_vault_get",
        "SELECT * FROM dc_mythic_vault WHERE player_guid = ? AND week_start = ?");
    
    // Item upgrades
    cache->Register("upgrade_history",
        "INSERT INTO dc_item_upgrade_history (player_guid, item_guid, old_level, new_level, cost) "
        "VALUES (?, ?, ?, ?, ?)");
    
    // And more...
}

} // namespace DC
```

---

## 2. Memory Management

### Object Pooling

```cpp
// DCObjectPool.h
#pragma once

#include <vector>
#include <mutex>

namespace DC
{

template<typename T>
class ObjectPool
{
public:
    ObjectPool(size_t initialSize = 100)
    {
        _pool.reserve(initialSize);
        for (size_t i = 0; i < initialSize; ++i)
            _pool.push_back(std::make_unique<T>());
    }
    
    T* Acquire()
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        if (_pool.empty())
        {
            // Grow pool
            return new T();
        }
        
        T* obj = _pool.back().release();
        _pool.pop_back();
        return obj;
    }
    
    void Release(T* obj)
    {
        if (!obj) return;
        
        // Reset object state
        if constexpr (requires { obj->Reset(); })
            obj->Reset();
        
        std::lock_guard<std::mutex> lock(_mutex);
        _pool.push_back(std::unique_ptr<T>(obj));
    }
    
    size_t Size() const { return _pool.size(); }
    
    void Shrink(size_t targetSize)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        while (_pool.size() > targetSize)
            _pool.pop_back();
    }

private:
    std::vector<std::unique_ptr<T>> _pool;
    std::mutex _mutex;
};

// Pooled object wrapper with RAII
template<typename T>
class PooledObject
{
public:
    PooledObject(ObjectPool<T>& pool) : _pool(pool), _obj(pool.Acquire()) {}
    ~PooledObject() { _pool.Release(_obj); }
    
    T* operator->() { return _obj; }
    T& operator*() { return *_obj; }
    T* Get() { return _obj; }

private:
    ObjectPool<T>& _pool;
    T* _obj;
};

} // namespace DC
```

### Cache Manager

```cpp
// DCCacheManager.h
#pragma once

#include <chrono>
#include <shared_mutex>

namespace DC
{

template<typename K, typename V>
class LRUCache
{
public:
    LRUCache(size_t maxSize, std::chrono::seconds ttl = std::chrono::seconds(300))
        : _maxSize(maxSize), _ttl(ttl) {}
    
    bool Get(const K& key, V& value)
    {
        std::shared_lock<std::shared_mutex> lock(_mutex);
        
        auto it = _cache.find(key);
        if (it == _cache.end())
            return false;
        
        auto& entry = it->second;
        if (IsExpired(entry))
        {
            // Will be cleaned up by maintenance
            return false;
        }
        
        entry.lastAccess = std::chrono::steady_clock::now();
        value = entry.value;
        return true;
    }
    
    void Set(const K& key, const V& value)
    {
        std::unique_lock<std::shared_mutex> lock(_mutex);
        
        // Evict if at capacity
        if (_cache.size() >= _maxSize)
            EvictOldest();
        
        _cache[key] = {
            .value = value,
            .createdAt = std::chrono::steady_clock::now(),
            .lastAccess = std::chrono::steady_clock::now()
        };
    }
    
    void Invalidate(const K& key)
    {
        std::unique_lock<std::shared_mutex> lock(_mutex);
        _cache.erase(key);
    }
    
    void Clear()
    {
        std::unique_lock<std::shared_mutex> lock(_mutex);
        _cache.clear();
    }
    
    void Maintenance()
    {
        std::unique_lock<std::shared_mutex> lock(_mutex);
        
        auto now = std::chrono::steady_clock::now();
        for (auto it = _cache.begin(); it != _cache.end(); )
        {
            if (IsExpired(it->second))
                it = _cache.erase(it);
            else
                ++it;
        }
    }
    
    size_t Size() const { return _cache.size(); }
    float HitRate() const 
    { 
        return _totalRequests > 0 
            ? float(_hits) / float(_totalRequests) * 100.0f 
            : 0.0f; 
    }

private:
    struct CacheEntry
    {
        V value;
        std::chrono::steady_clock::time_point createdAt;
        std::chrono::steady_clock::time_point lastAccess;
    };
    
    bool IsExpired(const CacheEntry& entry) const
    {
        auto age = std::chrono::steady_clock::now() - entry.createdAt;
        return age > _ttl;
    }
    
    void EvictOldest()
    {
        auto oldest = _cache.begin();
        for (auto it = _cache.begin(); it != _cache.end(); ++it)
        {
            if (it->second.lastAccess < oldest->second.lastAccess)
                oldest = it;
        }
        if (oldest != _cache.end())
            _cache.erase(oldest);
    }
    
    std::unordered_map<K, CacheEntry> _cache;
    size_t _maxSize;
    std::chrono::seconds _ttl;
    std::shared_mutex _mutex;
    std::atomic<uint64> _hits{0};
    std::atomic<uint64> _totalRequests{0};
};

// Global caches
class CacheManager
{
public:
    static CacheManager* instance();
    
    LRUCache<uint32, PlayerProfile>& PlayerProfiles() { return _playerProfiles; }
    LRUCache<uint32, std::vector<MythicRun>>& MythicHistory() { return _mythicHistory; }
    LRUCache<uint32, ItemUpgradeState>& ItemUpgrades() { return _itemUpgrades; }
    
    void MaintenanceAll()
    {
        _playerProfiles.Maintenance();
        _mythicHistory.Maintenance();
        _itemUpgrades.Maintenance();
    }
    
    void PrintStats()
    {
        LOG_INFO("dc.cache", "Cache Stats:");
        LOG_INFO("dc.cache", "  PlayerProfiles: {} entries, {:.1f}% hit rate",
            _playerProfiles.Size(), _playerProfiles.HitRate());
        LOG_INFO("dc.cache", "  MythicHistory: {} entries, {:.1f}% hit rate",
            _mythicHistory.Size(), _mythicHistory.HitRate());
        LOG_INFO("dc.cache", "  ItemUpgrades: {} entries, {:.1f}% hit rate",
            _itemUpgrades.Size(), _itemUpgrades.HitRate());
    }

private:
    LRUCache<uint32, PlayerProfile> _playerProfiles{5000, std::chrono::seconds(600)};
    LRUCache<uint32, std::vector<MythicRun>> _mythicHistory{1000, std::chrono::seconds(300)};
    LRUCache<uint32, ItemUpgradeState> _itemUpgrades{5000, std::chrono::seconds(600)};
};

#define sCache DC::CacheManager::instance()

} // namespace DC
```

---

## 3. Update Scheduling

### Tick Manager

```cpp
// DCTickManager.h
#pragma once

#include <functional>
#include <chrono>

namespace DC
{

enum class TickPriority
{
    CRITICAL = 0,   // Every tick
    HIGH = 1,       // Every 100ms
    NORMAL = 2,     // Every 500ms
    LOW = 3,        // Every 1000ms
    BACKGROUND = 4  // Every 5000ms
};

class TickManager
{
public:
    static TickManager* instance();
    
    using TickHandler = std::function<void(uint32 diff)>;
    
    uint32 Register(const std::string& name, TickHandler handler, 
        TickPriority priority = TickPriority::NORMAL)
    {
        uint32 id = _nextId++;
        _handlers[id] = {
            .name = name,
            .handler = handler,
            .priority = priority,
            .lastTick = 0,
            .totalTime = 0,
            .tickCount = 0
        };
        return id;
    }
    
    void Unregister(uint32 id)
    {
        _handlers.erase(id);
    }
    
    void Update(uint32 diff)
    {
        _totalDiff += diff;
        
        for (auto& [id, handler] : _handlers)
        {
            uint32 interval = GetInterval(handler.priority);
            
            if (_totalDiff - handler.lastTick >= interval)
            {
                auto start = std::chrono::high_resolution_clock::now();
                
                handler.handler(diff);
                
                auto end = std::chrono::high_resolution_clock::now();
                auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
                
                handler.lastTick = _totalDiff;
                handler.totalTime += elapsed.count();
                handler.tickCount++;
                
                // Warn if handler is slow
                if (elapsed.count() > 10000)  // 10ms
                {
                    LOG_WARN("dc.tick", "Slow tick handler '{}': {}us",
                        handler.name, elapsed.count());
                }
            }
        }
    }
    
    void PrintStats()
    {
        LOG_INFO("dc.tick", "Tick Handler Stats:");
        for (const auto& [id, handler] : _handlers)
        {
            if (handler.tickCount > 0)
            {
                LOG_INFO("dc.tick", "  {}: {} ticks, avg {}us",
                    handler.name, handler.tickCount, 
                    handler.totalTime / handler.tickCount);
            }
        }
    }

private:
    uint32 GetInterval(TickPriority priority)
    {
        switch (priority)
        {
            case TickPriority::CRITICAL: return 0;
            case TickPriority::HIGH: return 100;
            case TickPriority::NORMAL: return 500;
            case TickPriority::LOW: return 1000;
            case TickPriority::BACKGROUND: return 5000;
            default: return 500;
        }
    }
    
    struct Handler
    {
        std::string name;
        TickHandler handler;
        TickPriority priority;
        uint32 lastTick;
        uint64 totalTime;
        uint32 tickCount;
    };
    
    std::unordered_map<uint32, Handler> _handlers;
    uint32 _nextId = 1;
    uint32 _totalDiff = 0;
};

#define sTick DC::TickManager::instance()

} // namespace DC
```

### Deferred Actions

```cpp
// DCDeferredActions.h
namespace DC
{

class DeferredActionQueue
{
public:
    static DeferredActionQueue* instance();
    
    using Action = std::function<void()>;
    
    // Schedule action for next update cycle
    void Defer(Action action)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _pending.push(action);
    }
    
    // Schedule action after delay (in milliseconds)
    void DeferDelayed(Action action, uint32 delayMs)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _delayed.push({
            .action = action,
            .executeAt = GameTime::GetGameTimeMS().count() + delayMs
        });
    }
    
    // Schedule action at specific game time
    void DeferAt(Action action, time_t executeAt)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _scheduled.push({
            .action = action,
            .executeAt = executeAt
        });
    }
    
    void Process()
    {
        // Process pending actions
        std::queue<Action> toProcess;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            std::swap(toProcess, _pending);
        }
        
        while (!toProcess.empty())
        {
            try { toProcess.front()(); }
            catch (const std::exception& e) 
            { 
                LOG_ERROR("dc.deferred", "Action failed: {}", e.what());
            }
            toProcess.pop();
        }
        
        // Process delayed actions
        auto nowMs = GameTime::GetGameTimeMS().count();
        {
            std::lock_guard<std::mutex> lock(_mutex);
            while (!_delayed.empty() && _delayed.top().executeAt <= nowMs)
            {
                try { _delayed.top().action(); }
                catch (const std::exception& e)
                {
                    LOG_ERROR("dc.deferred", "Delayed action failed: {}", e.what());
                }
                _delayed.pop();
            }
        }
        
        // Process scheduled actions
        auto now = GameTime::GetGameTime().count();
        {
            std::lock_guard<std::mutex> lock(_mutex);
            while (!_scheduled.empty() && _scheduled.top().executeAt <= now)
            {
                try { _scheduled.top().action(); }
                catch (const std::exception& e)
                {
                    LOG_ERROR("dc.deferred", "Scheduled action failed: {}", e.what());
                }
                _scheduled.pop();
            }
        }
    }

private:
    struct DelayedAction
    {
        Action action;
        uint64 executeAt;
        
        bool operator>(const DelayedAction& other) const
        {
            return executeAt > other.executeAt;
        }
    };
    
    struct ScheduledAction
    {
        Action action;
        time_t executeAt;
        
        bool operator>(const ScheduledAction& other) const
        {
            return executeAt > other.executeAt;
        }
    };
    
    std::queue<Action> _pending;
    std::priority_queue<DelayedAction, std::vector<DelayedAction>, std::greater<DelayedAction>> _delayed;
    std::priority_queue<ScheduledAction, std::vector<ScheduledAction>, std::greater<ScheduledAction>> _scheduled;
    std::mutex _mutex;
};

#define sDeferred DC::DeferredActionQueue::instance()

} // namespace DC
```

---

## 4. Profiling Tools

### Performance Monitor

```cpp
// DCProfiler.h
#pragma once

#include <chrono>
#include <atomic>

namespace DC
{

class ScopedTimer
{
public:
    ScopedTimer(const std::string& name)
        : _name(name), _start(std::chrono::high_resolution_clock::now()) {}
    
    ~ScopedTimer()
    {
        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - _start);
        
        DCProfiler::instance()->Record(_name, elapsed.count());
    }

private:
    std::string _name;
    std::chrono::high_resolution_clock::time_point _start;
};

class DCProfiler
{
public:
    static DCProfiler* instance();
    
    void Record(const std::string& name, uint64 microseconds)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        auto& entry = _entries[name];
        entry.totalTime += microseconds;
        entry.callCount++;
        entry.maxTime = std::max(entry.maxTime, microseconds);
        entry.minTime = std::min(entry.minTime, microseconds);
    }
    
    void Reset()
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _entries.clear();
    }
    
    void PrintReport()
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        LOG_INFO("dc.profiler", "=== Performance Report ===");
        
        // Sort by total time
        std::vector<std::pair<std::string, ProfileEntry>> sorted(
            _entries.begin(), _entries.end());
        
        std::sort(sorted.begin(), sorted.end(),
            [](const auto& a, const auto& b) 
            { return a.second.totalTime > b.second.totalTime; });
        
        for (const auto& [name, entry] : sorted)
        {
            if (entry.callCount > 0)
            {
                LOG_INFO("dc.profiler", 
                    "{}: calls={}, total={}us, avg={}us, max={}us",
                    name, entry.callCount, entry.totalTime,
                    entry.totalTime / entry.callCount, entry.maxTime);
            }
        }
    }

private:
    struct ProfileEntry
    {
        uint64 totalTime = 0;
        uint64 callCount = 0;
        uint64 maxTime = 0;
        uint64 minTime = UINT64_MAX;
    };
    
    std::unordered_map<std::string, ProfileEntry> _entries;
    std::mutex _mutex;
};

// Convenience macros
#define DC_PROFILE_SCOPE(name) DC::ScopedTimer _timer_##__LINE__(name)
#define DC_PROFILE_FUNCTION() DC_PROFILE_SCOPE(__FUNCTION__)

} // namespace DC
```

---

## 5. Configuration

### Performance Settings

```ini
# worldserver.conf additions

# DC Performance Settings
DC.Performance.AsyncWorkers = 4
DC.Performance.QueryBatchSize = 100
DC.Performance.CacheMaxSize = 10000
DC.Performance.CacheTTLSeconds = 600
DC.Performance.TickManagerEnabled = 1
DC.Performance.DeferredQueueEnabled = 1
DC.Performance.ProfilerEnabled = 0
DC.Performance.ProfilerReportIntervalSeconds = 300
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Database | 3 days | Pooling, batching, prepared statements |
| Memory | 3 days | Object pools, caching |
| Scheduling | 2 days | Tick manager, deferred actions |
| Profiling | 2 days | Performance monitoring |
| Integration | 2 days | Apply to all DC systems |
| Testing | 2 days | Load testing, benchmarks |
| **Total** | **~2 weeks** | |

---

## Expected Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| DB Queries/sec | 500 | 150 | 70% reduction |
| Memory Allocations | 10k/s | 2k/s | 80% reduction |
| Update Loop Time | 15ms | 5ms | 67% faster |
| Player Login Time | 200ms | 50ms | 75% faster |
| Peak Memory Usage | 2GB | 1.5GB | 25% reduction |
