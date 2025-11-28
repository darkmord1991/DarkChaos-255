# Performance Optimization Strategy - Technical Deep Dive

## Executive Summary

This document analyzes performance considerations for DarkChaos custom systems running on AzerothCore. It covers database optimization, memory management, CPU profiling, network efficiency, and specific optimizations for each custom system.

---

## Performance Baseline: AzerothCore

### Typical Server Load Points

| Component | Load Source | Baseline |
|-----------|------------|----------|
| World Update | Creature AI, spell processing | 50-100ms diff cycles |
| Database | Character saves, queries | 100-500 queries/sec |
| Network | Packet processing | 1000-5000 packets/sec |
| Memory | Maps, creatures, players | 2-8 GB typical |

### DarkChaos Custom Systems Load

| System | Primary Load | Frequency |
|--------|--------------|-----------|
| Mythic+ Scaling | Creature stat recalculation | On spawn |
| AoE Loot | Corpse searching, loot merging | On loot |
| Phased Duels | Phase management, stat tracking | On duel start/end |
| M+ Spectator | Position updates, broadcasts | Every 1 second |
| Hinterland BG | Score updates, state machine | Every 5 seconds |

---

## Database Optimization

### Current Query Patterns

#### High-Frequency Queries

| System | Query Pattern | Frequency | Concern |
|--------|--------------|-----------|---------|
| Duel Stats | SELECT on login | Per login | Low |
| Duel Stats | UPDATE on duel end | Per duel | Medium |
| AoE Prefs | SELECT on login | Per login | Low |
| AoE Stats | UPDATE on logout | Per logout | Low |
| M+ Replays | INSERT on run end | Per run | Medium (large data) |
| Seasonal | SELECT leaderboards | Per request | High (complex) |

#### Query Optimization Strategies

### 1. Prepared Statements

**Issue:** Repeated query parsing overhead.

**Current:**
```cpp
CharacterDatabase.Query("SELECT wins FROM dc_duel_statistics WHERE player_guid = {}", guid);
```

**Optimized:**
```cpp
// Prepare once at startup
stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DUEL_STATS);
stmt->setUInt32(0, guid);
CharacterDatabase.Query(stmt);
```

**Requires:**
- Define statement IDs in `CharacterDatabase.h`
- Add SQL strings to `CharacterDatabase.cpp`

### 2. Async Queries for Non-Critical Data

**Issue:** Blocking main thread on database queries.

**Current:**
```cpp
QueryResult result = CharacterDatabase.Query(...);  // BLOCKING
```

**Optimized:**
```cpp
CharacterDatabase.AsyncQuery(...)
    .via(&_queryProcessor)
    .then([](QueryResult result) {
        // Process result on callback
    });
```

**Suitable for:**
- Statistics loading (non-critical)
- Leaderboard fetches
- Replay data retrieval

### 3. Batch Operations

**Issue:** Many small INSERTs/UPDATEs create overhead.

**Current:**
```cpp
for (auto& stat : stats)
    CharacterDatabase.Execute("UPDATE ... WHERE guid = {}", stat.guid);
```

**Optimized:**
```cpp
CharacterDatabase.BeginTransaction();
for (auto& stat : stats)
    CharacterDatabase.Execute("UPDATE ... WHERE guid = {}", stat.guid);
CharacterDatabase.CommitTransaction();
```

**Or use bulk INSERT:**
```sql
INSERT INTO table VALUES (1, 'a'), (2, 'b'), (3, 'c')
ON DUPLICATE KEY UPDATE ...
```

### 4. Index Analysis

**Tables requiring indexes:**

| Table | Recommended Indexes |
|-------|---------------------|
| `dc_duel_statistics` | `player_guid` (PK), `wins DESC` (leaderboard) |
| `dc_aoeloot_preferences` | `player_guid` (PK) |
| `dc_aoeloot_detailed_stats` | `player_guid` (PK) |
| `dc_mythic_spectator_replays` | `id` (PK), `start_time DESC` |
| `dc_seasonal_*` | `season_id`, `player_guid`, composite indexes |

### 5. Query Caching

**Issue:** Repeated identical queries.

**Strategy:**
- Cache leaderboard results for N seconds
- Invalidate on relevant data change
- Use memory cache, not database cache

---

## Memory Optimization

### Current Memory Patterns

| Data Structure | Per-Player Size | 1000 Players |
|----------------|-----------------|--------------|
| DuelStats | ~64 bytes | 64 KB |
| PlayerLootPreferences | ~128 bytes | 128 KB |
| DetailedLootStats | ~96 bytes | 96 KB |
| SpectatorState | ~128 bytes | 128 KB (spectators only) |

**Total overhead per player:** ~300-400 bytes (acceptable)

### Memory Leak Prevention

**Common patterns to audit:**

1. **Map cleanup on logout:**
```cpp
void OnLogout(Player* player) {
    sPlayerDuelStats.erase(player->GetGUID());  // ✓ Cleanup
    sActiveDuels.erase(player->GetGUID());      // ✓ Cleanup
}
```

2. **Container growth limits:**
```cpp
// Limit replay events
if (events.size() >= REPLAY_MAX_EVENTS)
    events.pop_front();  // ✓ Bounded
```

3. **String allocations:**
- Avoid `std::string` copies in hot paths
- Use `std::string_view` where possible
- Pre-allocate ostringstream buffers

### Memory Pooling (Advanced)

For high-frequency allocations:
```cpp
// Object pool for SpectatorState
class SpectatorStatePool {
    std::vector<SpectatorState> pool;
    std::queue<size_t> freeList;
    // ...
};
```

**Candidates:**
- ActiveDuel objects
- Replay events
- Broadcast packets

---

## CPU Optimization

### Hot Path Analysis

#### 1. Creature Scaling (Mythic+)

**Hook:** `OnCreatureSpawn`, `OnCreatureRespawn`

**Current flow:**
1. Check if dungeon is M+
2. Load scaling config
3. Calculate new stats
4. Apply to creature

**Optimization opportunities:**
- Cache config per map (avoid repeated lookups)
- Early exit for non-dungeon maps
- Batch spawn processing if possible

**Config flag:** `MythicPlus.OptimizeHooks = 1`

#### 2. AoE Loot Corpse Search

**Hook:** `OnLootOpen` (or similar)

**Current flow:**
1. Find nearby corpses
2. Filter by tapped state
3. Check line of sight (if enabled)
4. Merge loot tables

**Optimization opportunities:**
- Use spatial indexing (grid cells)
- Cache corpse positions per update tick
- Limit search to reasonable radius
- Skip LoS check for performance

#### 3. Spectator Updates

**Hook:** `WorldScript::OnUpdate`

**Current flow:**
1. Iterate all active runs
2. For each run, iterate spectators
3. Broadcast updates

**Optimization opportunities:**
- Only update if data changed (dirty flag)
- Batch broadcast construction
- Use shared packet for same data

### CPU Profiling Approach

#### 1. Built-in Timing

```cpp
#define PROFILE_START auto _start = std::chrono::high_resolution_clock::now()
#define PROFILE_END(name) \
    auto _end = std::chrono::high_resolution_clock::now(); \
    LOG_DEBUG("perf", "{}: {}μs", name, \
        std::chrono::duration_cast<std::chrono::microseconds>(_end - _start).count())
```

#### 2. AzerothCore Metric System

Use existing metric infrastructure:
```cpp
METRIC_TIMER("dc_aoeloot_search");
// ... operation ...
METRIC_TIMER_STOP("dc_aoeloot_search");
```

#### 3. External Profilers

| Tool | Platform | Use Case |
|------|----------|----------|
| perf | Linux | System-wide profiling |
| gprof | Linux | Function-level timing |
| VTune | Cross | Detailed analysis |
| VS Profiler | Windows | Visual Studio integration |

---

## Network Optimization

### Packet Efficiency

#### Current Issues

1. **Redundant broadcasts:** Same data sent to multiple players
2. **Frequent small packets:** Many small sends vs. fewer large ones
3. **String serialization:** Text-based protocols waste bytes

#### Broadcast Optimization

**Instead of:**
```cpp
for (Player* spectator : spectators)
    spectator->SendDirectMessage(&packet);
```

**Consider:**
```cpp
// Build packet once
WorldPacket packet = BuildSpectatorUpdate(run);

// Send to all (if same data)
for (Player* spectator : spectators)
    spectator->SendDirectMessage(&packet);
```

#### Throttling Strategies

| System | Current Rate | Recommended |
|--------|--------------|-------------|
| M+ Spectator | 1000ms | 1000-2000ms |
| Score Updates | 5000ms | 5000ms (OK) |
| HUD Sync | Per change | Batch per tick |

#### Compression (Future)

For large payloads (replays, leaderboards):
- Use zlib compression
- Only if payload > 1KB
- Decompress on client (Lua)

---

## System-Specific Optimizations

### 1. Mythic+ Difficulty Scaling

**Current concern:** Per-creature stat calculation

**Optimizations:**
| Strategy | Impact | Effort |
|----------|--------|--------|
| Cache scaling factors per dungeon | High | Low |
| Pre-calculate all creature stats on run start | High | Medium |
| Use lookup tables instead of formulas | Medium | Low |
| Skip scaling for trash below threshold | Low | Low |

**Linked systems affected:**
- MythicPlusRunManager
- Creature spawn hooks
- Dungeon instance scripts

### 2. AoE Loot Extensions

**Current concern:** Corpse search radius

**Optimizations:**
| Strategy | Impact | Effort |
|----------|--------|--------|
| Spatial grid for corpse lookup | High | High |
| Cache corpses per player per tick | Medium | Medium |
| Reduce default search radius | Low | Trivial |
| Disable LoS check | Low | Trivial |

**Config impact:**
- `AoELoot.Range` - directly affects search area
- `AoELoot.MaxCorpses` - limits iteration
- `AoELoot.RequireLineOfSight` - CPU-heavy if enabled

### 3. Phased Duels

**Current concern:** Phase ID allocation

**Optimizations:**
| Strategy | Impact | Effort |
|----------|--------|--------|
| Cache free phases per zone | Medium | Low |
| Lazy phase cleanup | Low | Low |
| Limit max concurrent duels | Low | Trivial |

**Linked systems affected:**
- Player visibility updates
- GameObject phase handling

### 4. M+ Spectator

**Current concern:** Periodic updates to many spectators

**Optimizations:**
| Strategy | Impact | Effort |
|----------|--------|--------|
| Delta updates (only changed fields) | High | Medium |
| Reduce update frequency | Medium | Trivial |
| Combine HUD + run updates | Medium | Low |
| Lazy viewpoint updates | Low | Low |

**Network savings:**
- Current: ~200 bytes/spectator/second
- Optimized: ~50 bytes/spectator/second

### 5. Hinterland BG

**Current concern:** State machine overhead

**Optimizations:**
| Strategy | Impact | Effort |
|----------|--------|--------|
| Event-driven instead of polling | High | Medium |
| Cache worldstate packets | Medium | Low |
| Reduce score broadcast frequency | Low | Trivial |

---

## Testing Performance Changes

### 1. Baseline Measurement

Before any optimization:
1. Record server tick times
2. Record database query counts
3. Record network packet sizes
4. Document under specific load

### 2. Synthetic Load Testing

**Tools:**
- Custom bot scripts
- Simulated player connections
- Database load generators

**Scenarios:**
| Scenario | Players | Activity |
|----------|---------|----------|
| Idle server | 0 | Baseline overhead |
| Low load | 50 | Normal activity |
| Medium load | 200 | Mixed dungeons/BGs |
| High load | 500 | Stress test |
| Spike | 100→500 | Sudden load increase |

### 3. A/B Testing

For each optimization:
1. Run without optimization (control)
2. Run with optimization (test)
3. Compare metrics
4. Verify functionality unchanged

### 4. Regression Testing

After optimization:
- All commands still work
- Data persists correctly
- No memory leaks (valgrind)
- No crashes under load

---

## AzerothCore Modifications Required

### 1. Add Prepared Statement Definitions

**File:** `CharacterDatabase.h`
```cpp
enum CharStatements {
    // ... existing ...
    CHAR_SEL_DC_DUEL_STATS,
    CHAR_UPD_DC_DUEL_STATS,
    CHAR_SEL_DC_AOELOOT_PREFS,
    // ...
};
```

**File:** `CharacterDatabase.cpp`
```cpp
PrepareStatement(CHAR_SEL_DC_DUEL_STATS, 
    "SELECT wins, losses, ... FROM dc_duel_statistics WHERE player_guid = ?", 
    CONNECTION_SYNCH);
```

### 2. Add Metric Hooks (Optional)

**File:** `Metric.h` / `Metric.cpp`
- Add DC-specific metric categories
- Enable metric collection in config

### 3. Async Query Support

Verify async query infrastructure is enabled:
- `CharacterDatabase.AsyncQuery` available
- Callback processor running

### 4. Config Additions

**File:** `worldserver.conf.dist`
```ini
# DarkChaos Performance Settings
DC.Performance.AsyncDatabaseQueries = 1
DC.Performance.SpectatorUpdateInterval = 1000
DC.Performance.EnableQueryCaching = 1
DC.Performance.QueryCacheTTL = 30
```

---

## Monitoring & Alerting

### Key Metrics to Monitor

| Metric | Warning | Critical |
|--------|---------|----------|
| World update time | >100ms | >200ms |
| DB query time (avg) | >50ms | >100ms |
| Player count | >400 | >600 |
| Memory usage | >6GB | >8GB |
| Packet queue depth | >1000 | >5000 |

### Logging for Performance

```cpp
if (updateTime > 100)
    LOG_WARN("perf.dc", "Slow update: {}ms in {}", updateTime, __FUNCTION__);
```

### Grafana Dashboard (If Available)

Recommended panels:
- Server tick distribution
- Database query latency
- Custom system overhead
- Memory usage over time

---

## Priority Optimization Roadmap

### Phase 1: Quick Wins (Low Effort, High Impact)

1. ✅ Add `MythicPlus.OptimizeHooks` early exit
2. Add dirty flags to spectator updates
3. Reduce spectator update interval to 2000ms
4. Disable AoE loot LoS check by default

### Phase 2: Database (Medium Effort)

1. Convert to prepared statements
2. Add async queries for statistics
3. Implement query result caching
4. Add proper indexes to all DC tables

### Phase 3: Memory & CPU (Higher Effort)

1. Implement spatial indexing for AoE loot
2. Add object pooling for frequent allocations
3. Cache creature scaling factors
4. Optimize string handling in protocol

### Phase 4: Network (Ongoing)

1. Implement delta updates for spectator
2. Add message compression for large payloads
3. Batch worldstate updates
4. Consider binary protocol for high-frequency data

---

## Open Questions

1. What is acceptable server tick overhead for custom systems?
2. Should we implement query caching in-memory or use Redis?
3. Is async database worth the complexity for our scale?
4. Should spectator updates be event-driven instead of polled?
5. What's the target player count for optimization goals?

---

## References

- [AzerothCore Performance Guide](https://www.azerothcore.org/wiki/Performance)
- [MySQL Query Optimization](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [C++ Performance Best Practices](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- [WoW Server Architecture Analysis](https://wowdev.wiki/World_Server)
- [Spatial Indexing Algorithms](https://en.wikipedia.org/wiki/Spatial_index)
