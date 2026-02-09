# Map Partitioning & Layering System

## Overview
The **Map Partitioning System** is a high-performance scalability feature designed to parallelize map updates and manage high-population density through layering. It splits large game maps into smaller, independent update units ("partitions") that can be processed concurrently by worker threads.

**Layering** is Blizzard-style: layers are **map-wide (continent-wide)**, not per-zone. A player stays on the same layer across all zones of a map. Zone changes do NOT trigger layer reassignment — only map entry and party sync do.

---

## Testing & Verification

Comprehensive testing steps to validate the system.

### 1. Basic Functionality
- **Partition Status**: Run `.dc partition status`. Verify:
  - Partitions are allocated (Count > 0).
  - Player/Creature counts match reality.
- **GPS Check**: Target yourself and run `.gps`. Verify "Map Partition: X" and "Layer: Y" are displayed.

### 2. Performance Benchmark
Run `.stresstest partition 100000` to verify calculation speed.
Use `.stresstest partition 50000 persist` only if you want to include DB-backed layer persistence during the test.
New filters: `layercache`, `boundarygrid`, `preload`.

**Latest Benchmark Results (2026-02-02):**
| Operation | Time | Per-Op Average |
|-----------|------|----------------|
| Partition ID Calc | 44,922 µs | **44.92 ns** |
| Mixed Map Calc | 42,856 µs | **42.86 ns** |
| Relocation Lock/Unlock | 13,407 µs | **134.07 ns** |
| Layer Assignment | 1,235 µs | **6.17 ns** |
| Boundary Flux | 32,110 µs | **160.55 ns** |
| Clustered Assignment | 620 µs | **6.2 ns** |
| Migration (Move) | 6,646 µs | **132.92 ns** |
| Layer Lookup | 7,057 µs | **14.11 ns** |
| Layer Cache (NPC/GO) | TBD | TBD |
| Boundary Grid Batch | TBD | TBD |
| Grid Preload Cache | TBD | TBD |

> *Note: Partition lookups are extremely cheap (simple arithmetic), meaning the spatial partitioning overhead is negligible. Layer assignments are among the fastest operations.*

### 3. Boundary Testing
- **Setup**: Find a partition boundary using `.gps` (coordinate where partition ID changes).
- **Test**: Two players stand on opposite sides of the line (e.g., 20 yards apart).
- **Verify**:
  - Players can see each other.
  - Chat/Emotes work.
  - Spells can cast across the line.
  - Duel can start across the line.

### 4. Layering Stress Test
- **Setup**: Set `MapPartitions.Layers.Capacity = 2` (low limit for testing).
- **Test**:
  - Teleport 3 players to the same map.
  - **Result**: Players 1 & 2 should be in Layer 0. Player 3 should be in Layer 1.
  - **Verify**: Players 1 & 2 see each other. Player 3 sees NO ONE.
  - Walk between zones — all three should **keep their layer** (no zone-change reassignment).

### 5. Relocation Safety
- **Test**: Player mounts and runs *quickly* across multiple partition boundaries.
- **Verify**: No disconnects, no "desyncs" (teleporting back), and position saves correctly on logout.

---

## Technical Implementation

### Grid Partitioning Logic
The map is spatially divided into a grid of partitions based on either:
- `MapPartitions.DefaultCount` (static count), or
- tile-based sizing (`MapPartitions.TileBased.*`) derived from extracted .map tiles.
- **Spatial Hashing**: Entities are assigned to partitions based on their X/Y coordinates.
- **Independence**: Each partition maintains its own object list (Players, Creatures, DynamicObjects), allowing them to update completely independently of other partitions.

### Parallel Execution Model
Instead of a single monothreaded loop iterating over all map objects:
1. **Scheduling**: The main `Map::Update` tick calculates the time difference and schedules `PartitionUpdateRequest` tasks.
2. **Worker Threads**: These tasks are picked up by the `MapUpdater` thread pool.
3. **Synchronization**: 
   - Internal partition logic runs lock-free where possible.
   - Cross-partition interactions (combat, following) are handled via **Relay Queues** (ProducerConsumerQueue) to prevent race conditions.

---

## Thread Safety Architecture

The `PartitionManager` uses **fine-grained locking** to maximize parallelism:

| Mutex | Type | Purpose |
|-------|------|---------|
| `_partitionLock` | `shared_mutex` | Protects partition maps (allows concurrent reads) |
| `_layerLock` | `shared_mutex` | Protects layer assignments (allows concurrent reads) |
| `_boundaryLock` | `mutex` (striped) | Protects boundary object sets |
| `_relocationLock` | `mutex` | Protects relocation transactions |
| `_overrideLock` | `mutex` | Protects partition overrides and ownership |
| `_visibilityLock` | `mutex` (striped) | Protects visibility sets |

### Layer Manager Singleton

Layering APIs are accessed via `sLayerMgr` (a `LayerManager` singleton):

```cpp
#include "Maps/Partitioning/LayerManager.h"

// Blizzard-style: layers are map-wide, not per-zone. No zoneId parameter.
uint32 layer = sLayerMgr->GetPlayerLayer(mapId, playerGuid);
if (sLayerMgr->IsLayeringEnabled()) {
    sLayerMgr->AutoAssignPlayerToLayer(mapId, playerGuid);
}
```

**Architecture:**
- `LayerManager` owns all layering data structures and logic
- Data layout: `_layers[mapId][layerId] → set<playerGuid>` (flat, no zone nesting)
- Lock-free reads via `AtomicLayerAssignment` packing `[mapId:32][layerId:32]` into `atomic<uint64>`
- Thread-local caches with 250ms TTL for hot-path visibility checks

### Automatic Cleanup
- **Relocation Cleanup**: Timed-out relocations are auto-rolled back via `CleanupStaleRelocations()`
- **Boundary Cleanup**: Objects leaving boundary zones are unregistered to prevent memory leaks
- **Override Cleanup**: Expired partition overrides are cleaned via `CleanupExpiredOverrides()`
- **Empty Layer Cleanup**: When the last player leaves a layer, it's automatically pruned and orphaned NPCs/GOs redistributed

### Async Reads & Batching
- **Partition ownership** is loaded via async DB read on startup.
- **Persistent layer assignment** uses async DB read on login and batched async writes.

---

## Dynamic Visibility

One of the complex challenges of partitioning is handling visibility across boundaries. If Player A is in Partition 1 and Player B is in Partition 2, but they are standing 5 yards apart (across the line), they must see each other.

### Boundary Detection
The system defines a `BorderOverlap` zone (configurable, e.g., 20 yards) along the edges of every partition.
- **Boundary Objects**: When an entity enters this overlap zone, it is flagged as a "Boundary Object".
- **Dual Registration**: The entity remains owned by its home partition but is **temporarily registered** as a "Ghost" in the adjacent partition's visibility system.
- **Duplicate Prevention**: `IsObjectInBoundarySet()` checks prevent redundant registrations per tick.

### Visibility Updates
- **Primary Update**: The home partition updates the entity normally.
- **Ghost Update**: The adjacent partition includes the ghost entity in its visibility calculations.
  - This ensures players in the adjacent partition receive update packets for the ghost entity.
  - Interaction logic (spells, trading) is routed back to the home partition via the Relay System.

---

## Layering System (Blizzard-style)

The layering system creates virtual copies of an entire **map** (continent) to prevent overcrowding. Unlike earlier zone-based implementations, layers are **map-wide** — a player on Layer 2 stays on Layer 2 whether they're in Stormwind, Elwynn Forest, or Burning Steppes.

### How it Works
1. **Assignment**: When a player enters a map, `LayerManager::AutoAssignPlayerToLayer` determines their layer.
   - If current layers are full (>= `Layer.Capacity`), a new layer is created.
   - Preference is given to filling existing layers (0, 1, 2...).
   - Party members are synced to the leader's layer.
2. **Stickiness**: Players keep their layer assignment for the **entire map session**. Zone changes do NOT reassign layers. This eliminates the "NPC pop" effect that occurred at zone boundaries in the old per-zone system.
3. **Visibility Filtering**:
   - `WorldObject::CanSeeOrDetect` checks layer compatibility using map-wide lookups.
   - **Rule**: Players can only see other players in the **same layer**.
   - **NPCs**: If NPC layering is enabled, NPCs are only visible to players on the same layer.
   - **GameObjects**: If GO layering is enabled, same isolation rules apply. Transports are always visible.
4. **Logout Cleanup**: `ForceRemovePlayerFromAllLayers()` ensures proper cleanup on disconnect.

### When Layers Change
Layer assignment is evaluated **only** in these scenarios:
- **Map entry**: `Map::AddPlayerToMap` assigns a layer.
- **Party sync**: When joining a party or the leader changes layers, members follow.
- **Manual switch**: `.dc layer join <player>` or `.dc layer <id>` (GM command).
- **Rebalancing**: Periodic consolidation of sparse layers.

Zone changes, movement, and other in-world actions do **not** trigger layer reassignment.

### Performance Optimization
- **Lock-free reads**: `AtomicLayerAssignment` packs `mapId + layerId` into a single `atomic<uint64>`, allowing `GetPlayerLayer()` to be called without any lock.
- **Thread-local caches**: `GetLayerIdCached()` on Player uses a 250ms TTL cache to avoid even the atomic load on hot paths.
- **Combined lookups**: `GetLayersForTwoPlayers()` acquires a single lock for both players instead of two separate lookups.

### GPS Integration
The `.gps` command shows detailed debug info:
- **Map Partition**: Current spatial partition ID.
- **Layer**: Current population layer ID.

### NPC & GO Layering

When NPC layering is enabled (`MapPartitions.Layers.IncludeNPCs = 1`), **each layer is a completely independent world copy** (like retail WoW layering):
- **World spawns** are cloned per layer during grid load and on new layer creation
- **Player-owned NPCs** (pets/guardians/charmed) are synced to the owner's layer on assignment
- **Complete isolation**: Players can only see other players and NPCs on the same layer
- **Orphan recovery**: When a layer is removed, orphaned NPCs are redistributed to surviving layers

When GO layering is enabled (`MapPartitions.Layers.IncludeGameObjects = 1`), GameObjects follow the same isolation rules:
- **Static world GOs** (resource nodes, chests, quest objects) are cloned per layer during grid load
- **Player-spawned GOs** (totems, traps, summoned objects) follow the owner's layer
- **Transports** (ships, zeppelins, elevators, MO_TRANSPORT) are always visible on all layers
- **Orphan recovery**: Same as NPC layering

### Layer Rebalancing

Rebalancing runs periodically via `LayerManager::Update()`:
- **Interval**: Configurable via `MapPartitions.Layers.Rebalancing.CheckIntervalMs` (default 5 minutes)
- **Logic**: If total players on a map can fit into fewer layers, excess layers are consolidated into layer 0
- **Migration**: Players receive an in-game notification and their visibility is force-refreshed
- **DB persistence**: Layer changes from rebalancing are persisted to prevent stale assignments on relog

---

## Configuration

Control the system via `darkchaos-custom.conf`:

```ini
# Enable or disable the entire partitioning system
MapPartitions.Enabled = 1

# Comma-separated list of Map IDs to partition (e.g., 0,1,530)
MapPartitions.Maps = "0,1"

# Number of partitions per map (default 4 = 2x2 grid)
MapPartitions.DefaultCount = 4

# Tile-based partition sizing (optional)
MapPartitions.TileBased.Enabled = 1
MapPartitions.TileBased.TilesPerPartition = 64
MapPartitions.TileBased.MinPartitions = 1
MapPartitions.TileBased.MaxPartitions = 16
MapPartitions.TileBased.TilesPerPartitionOverrides = "0:32,1:32,530:64,571:32"
MapPartitions.TileBased.PartitionOverrides = "0:9,1:9,530:4,571:9"

# Overlap distance for boundary detection (yards)
MapPartitions.BorderOverlap = 20.0

# Zones excluded from partitioning (cities, hubs)
MapPartitions.ExcludeZones = "1519,1637,4395,3703"

# Layering Configuration
MapPartitions.Layers.Enabled = 1
MapPartitions.Layers.Capacity = 200   # Players per layer before creating a new one
MapPartitions.Layers.CapacityOverrides = "0:150,1:200,530:100,571:250"  # Per-map overrides
MapPartitions.Layers.Max = 4          # Maximum number of layers per map (continent)
MapPartitions.Layers.IncludeNPCs = 1  # Full NPC isolation per layer
MapPartitions.Layers.IncludeGameObjects = 1 # Full GO isolation per layer
MapPartitions.Layers.SkipClonesIfNoPlayers = 1 # Skip clone loads if map has no players
MapPartitions.Layers.EmitPerLayerCloneMetrics = 0 # Log per-layer clone metrics
MapPartitions.Layers.LazyCloneLoading = 1 # Load layer clones only when needed

# Layer Rebalancing
MapPartitions.Layers.Rebalancing.Enabled = 1
MapPartitions.Layers.Rebalancing.CheckIntervalMs = 300000  # 5 minutes
MapPartitions.Layers.Rebalancing.MinPlayersPerLayer = 5
MapPartitions.Layers.Rebalancing.ImbalanceThreshold = 0.3
MapPartitions.Layers.Rebalancing.MigrationBatchSize = 10

# Hysteresis (prevent oscillation)
MapPartitions.Layers.Hysteresis.CreationWarmupMs = 60000    # 1 minute
MapPartitions.Layers.Hysteresis.DestructionCooldownMs = 120000 # 2 minutes

# Soft Transfers (queue for loading screen)
MapPartitions.Layers.SoftTransfers.Enabled = 1
MapPartitions.Layers.SoftTransfers.TimeoutMs = 600000       # 10 minutes

# Dynamic Resizing Configuration
MapPartitions.DensitySplitThreshold = 50.0
MapPartitions.DensityMergeThreshold = 5.0

# Store-only mode (for testing - partitions tracked but not utilized for updates)
MapPartitions.UsePartitionStoreOnly = 0
```

---

## Map Type Handling

The system handles different map types according to specific rules to ensure stability and performance:

### 1. Continents & World Maps (0, 1, 530, 571)
*   **Handling**: Fully partitioned and layered.
*   **Reason**: These maps are massive and host the majority of the population. Partitioning is essential here.
*   **Layering**: Map-wide (continent-wide). A player on Layer 2 in Elwynn Forest is still on Layer 2 when they ride into Stormwind or Westfall.
*   **Note**: Exceptions apply to major cities (see "Exclusion Zones").

### 2. Dungeons & Raids
*   **Handling**: **NOT partitioned** (Standard Handling).
*   **Reason**: Dungeons are already instanced (per group). The player count is low (5-40 max), so partitioning adds overhead without benefit.
*   **Config**: Do NOT add instance IDs to `MapPartitions.Maps`.

### 3. Battlegrounds & Arenas
*   **Handling**: **NOT partitioned**.
*   **Reason**: High-intensity, small-scale combat requires atomic updates. Splitting a BG into partitions could introduce latency/race conditions for critical combat events.

### 4. Exclusion Zones (Cities)
*   **Handling**: Special "Excluded" status.
*   **Logic**: While the map (e.g., Eastern Kingdoms) is partitioned, specific zones (e.g., Stormwind) are marked as excluded.
*   **Effect**:
    *   Partitioning logic is disabled for players in these zones.
    *   Layering **remains active** (critical for city population management).
    *   Players keep their layer from the continent — entering a city does NOT change layer.
*   **Config**: `MapPartitions.ExcludeZones` (IDs: 1519=Stormwind, 1637=Orgrimmar, etc.).

---

## Architecture

### 1. LayerManager (Singleton)
- **Registry**: Tracks all layered maps and their player distributions.
- **Data Layout**: `_layers[mapId][layerId] → set<playerGuid>` (flat, map-wide).
- **Lock-free Reads**: `AtomicLayerAssignment` for fast player layer lookups without locking.
- **Rebalancing**: Periodic consolidation of sparse layers via `EvaluateLayerRebalancing()`.
- **Party Sync**: Automatic layer alignment for group members.

### 2. PartitionManager (Singleton)
- **Registry**: Tracks all partitioned maps and their grid configurations.
- **Boundary Management**: Handles the registration/unregistration of boundary "ghost" objects.
- **Relocation Transactions**: Thread-safe state machine for cross-partition relocations.

### 3. Map & MapUpdater
- `Map::Update` detects if partitioning is enabled.
- Uses `MapUpdater` thread pool to schedule `PartitionUpdateRequest` tasks.
- Calls `sLayerMgr->Update(mapId, diff)` for periodic layer maintenance.
- **Legacy Fallback**: If partitioning is disabled, standard `Map::Update` runs sequentially.

### 4. PartitionUpdateWorker
- Thread-safe worker that executes the update loop for a single partition.
- Handles:
  - Object/Grid updates.
  - Visibility processing.
  - Boundary detection and cleanup.
  - Relocation queue processing (moving objects between partitions).

---

## Commands

### Layer Commands (`.dc layer`):
| Command | Description |
|---------|-------------|
| `.dc layer` or `.dc layer status` | Show your current layer, layer counts, NPC/GO counts |
| `.dc layer <id>` | Switch to a specific layer (creates if needed, GM only) |
| `.dc layer join <player>` | Join a friend/guildmate/groupmate's layer (same map required) |

### Partition Commands (`.dc partition`):
| Command | Description |
|---------|-------------|
| `.dc partition status` | Show partition stats for your current map |
| `.dc partition config` | Display partition and layer configuration settings |
| `.dc partition diag [on\|off\|status]` | Toggle runtime diagnostics |
| `.dc partition tiles` | Print ADT tile counts per map and computed partition totals |

### Other:
| Command | Description |
|---------|-------------|
| `.gps` | Displays position, Partition ID, and Layer ID |
| `.stresstest partition [iterations]` | Runs performance benchmarks |

**Anti-exploit measures for `.dc layer join`:**
- Must be friends, guildmates, or group members with the target
- Cannot switch in combat or while dead
- Escalating cooldowns: 1min → 2min → 5min → 10min max
- Only group leaders can switch while in a group

---

## Phase 10: Advanced Features (Implemented)

### 1. Dynamic Partition Resizing
- **Purpose**: Automatically balance load by splitting dense partitions and merging empty ones.
- **Config**:
  - `MapPartitions.DensitySplitThreshold` (Default: 50.0)
  - `MapPartitions.DensityMergeThreshold` (Default: 5.0)
- **Logic**: Evaluates `(Players + Creatures/10)` density metric. Resizing is throttled (about once per 10s per map).
  - **Split**: If the highest-density partition exceeds the split threshold, partition count increases.
  - **Merge**: If **all** partitions fall below the merge threshold, partition count decreases.
  - **Rebuild**: When resizing, the grid layout and partitioned object assignments are rebuilt.

### 2. Adjacent Partition Pre-caching
- **Purpose**: Eliminate spikes when crossing boundaries by pre-loading data.
- **Mechanism**:
  - `CheckBoundaryApproach()` detects players moving towards a boundary (5s lookahead).
  - Triggers async load of the adjacent partition's high-priority assets.
  - Grid GUIDs are preloaded on worker threads and reused by grid loaders.

### 3. Persistent Layering
- **Purpose**: Keep players in their assigned layer even after logout/login.
- **Storage**: `dc_character_layer_assignment` table (PK: `guid` — one row per player, stores the latest map/layer).
- **Schema**: `guid | map_id (INT UNSIGNED) | zone_id (legacy, always 0) | layer_id (INT UNSIGNED) | updated_at`
- **Cleanup**: A MySQL EVENT runs hourly to purge assignments older than 24 hours and remove orphaned GUIDs not in the `characters` table.

### 4. Cross-Zone Party Sync (Blizzard-style)
- **Purpose**: Prevent "I can't see you" issues in parties.
- **Logic**: When joining a party or entering a map, players automatically switch to the leader's layer.
- **Cross-zone**: Since layers are map-wide, party members sync regardless of which zone they're in — only same map is required.

### 5. NPC Layering
- **Purpose**: Full layer isolation with per-layer NPC populations.
- **Toggle**: `MapPartitions.Layers.IncludeNPCs`.
- **Default distribution**: Static world spawns are deterministically distributed across existing, non-empty layers.
- **Orphan recovery**: When a layer is removed (last player leaves), orphaned NPCs are automatically redistributed to surviving layers.
- **Stale layer recovery**: NPCs with defunct layer IDs are automatically reassigned during the next visibility check.

### 5b. GameObject Layering
- **Purpose**: Full layer isolation for world GameObjects (resource nodes, chests, quest objects).
- **Toggle**: `MapPartitions.Layers.IncludeGameObjects`.
- **Lifecycle**: GOs are assigned to a layer in `AddToWorld()` and removed in `RemoveFromWorld()`.
- **Player-owned GOs**: Follow the owner's layer (totems, traps, summoned objects).
- **Static world GOs**: Deterministically distributed via spawn-ID hashing.
- **Always-visible**: Transports (ships, zeppelins, elevators) bypass layer filtering.
- **Orphan recovery**: Same as NPC layering — orphaned GOs redistributed on layer cleanup.

---

## Notes & Performance Considerations
- **Layer choice is not continuous**: Players only change layers on map entry, plus party sync and rebalancing. Zone changes do NOT trigger reassignment (Blizzard-style).
- **No zone-boundary pop**: Since layers are map-wide, moving between zones never causes NPCs/players to appear or disappear.
- **Static NPC distribution** is deterministic per spawn, avoiding cross-layer duplication while keeping load balanced.
- **Dynamic resizing cost**: resizing triggers a rebuild of partitioned assignments; throttling prevents frequent churn.
- **Empty layer cleanup**: empty layers are pruned when the last player leaves; orphaned NPCs and GOs are redistributed to surviving layers, preventing stale layer IDs from causing permanent invisibility.
- **Persistent layer restore**: layer restore only succeeds if the target layer still exists; otherwise normal auto-assign applies.
- **NPC visibility**: when multiple layers exist on a map, NPCs are layer-isolated; layer `0` is not global in multi-layer scenarios.
- **GO visibility**: when GO layering is enabled, GameObjects follow the same isolation rules as NPCs; transports are always visible.
- **Stale layer recovery**: NPCs/GOs with layer IDs pointing to defunct layers are automatically reassigned during visibility checks.

---

## Diagnostics

- **Runtime diagnostics window**: `.dc partition diag on` enables metrics emission for ~60 seconds.
- **Metrics** (when enabled):
  - `player_regen_tick_ms`
  - `player_regen_timer_count_ms`
  - `player_regen_health_tick`

---

## Phase 11: Advanced Features (Implemented)

### 6. Spatial Hashing for Boundaries (Phase 2)
- **Purpose**: O(1) boundary object lookups instead of O(N) iteration.
- **Mechanism**:
  - `SpatialHashGrid` struct divides space into 100-yard cells.
  - Each cell stores a list of boundary objects with positions.
  - `GetNearbyBoundaryObjects(x, y, radius)` queries only relevant cells.
- **Performance**: 10-50x faster lookups in dense boundary areas.
- **Config**:
  - `MapPartitions.SpatialHash.Enabled = 1`
  - `MapPartitions.SpatialHash.CellSize = 100`

### 7. WoW-Style Layer Switching (Phase 5)
- **Purpose**: Allow players to manually join a friend's/guildmate's/groupmate's layer.
- **Command**: `.dc layer join <player>`
- **Requirement**: Both players must be on the **same map** (any zone is fine).
- **Anti-Exploit**:
  - Combat/death checks (cannot switch in combat or while dead).
  - Escalating cooldowns: 1min → 2min → 5min → 10min max.
  - Social requirement: Must be friends, guildmates, or groupmates.

### 8. Layer Rebalancing (Phase 6)
- **Purpose**: Automatically consolidate sparse layers to prevent "ghost" layers.
- **Mechanism**:
  - `EvaluateLayerRebalancing()` is called by `LayerManager::Update()` at configurable intervals per map.
  - If total players on a map fit into fewer layers, excess layers are merged into layer 0.
  - `ConsolidateLayers()` migrates players — either instantly or via soft transfer (see Phase 8).
- **Config**:
  - `MapPartitions.Layers.Rebalancing.Enabled = 1`
  - `MapPartitions.Layers.Rebalancing.CheckIntervalMs = 300000`
  - `MapPartitions.Layers.Rebalancing.MinPlayersPerLayer = 5`
  - `MapPartitions.Layers.Rebalancing.ImbalanceThreshold = 0.3`

### 9. Hysteresis — Layer Creation / Destruction Delays (Phase 7)
- **Purpose**: Prevent rapid layer creation/destruction oscillation on population boundaries.
- **Creation Warmup**: When all layers are at capacity, a timer starts. A new layer is created only if the condition persists for the entire warmup duration. If capacity becomes available before the timer elapses, the timer resets.
- **Destruction Cooldown**: When total population drops below a single layer's capacity, the system waits for the cooldown duration before consolidating. If population rises again before the timer elapses, the timer resets.
- **Config**:
  - `MapPartitions.Layers.Hysteresis.CreationWarmupMs = 60000` (1 minute)
  - `MapPartitions.Layers.Hysteresis.DestructionCooldownMs = 120000` (2 minutes)
  - Set to 0 to disable (instant creation/destruction)
- **Implementation**: Per-map `HysteresisState` struct tracks `creationRequestMs` and `destructionRequestMs` timestamps, guarded by `_hysteresisLock`.

### 10. Soft Transfers (Phase 8)
- **Purpose**: Queue rebalancing layer moves for the next loading screen instead of performing instant hard-switches that cause a visible "pop" effect.
- **Mechanism**:
  - When `ConsolidateLayers()` needs to move players, it queues a `SoftTransferEntry` instead of calling `AssignPlayerToLayer()` immediately.
  - Players receive a chat notification: "You will be moved from Layer X to Layer Y on your next loading screen."
  - On the next map entry (teleport, map change), `ProcessSoftTransferForPlayer()` applies the queued move during the loading screen.
  - If a player doesn't trigger a loading screen within the timeout, `ProcessPendingSoftTransfers()` forces the transfer (called from `Update()`).
  - Pending soft transfers are cleaned up when a player logs out (`ForceRemovePlayerFromAllLayers()`).
- **Config**:
  - `MapPartitions.Layers.SoftTransfers.Enabled = 1`
  - `MapPartitions.Layers.SoftTransfers.TimeoutMs = 600000` (10 minutes)
  - When disabled, rebalancing uses instant transfers (legacy behavior).

### 11. Per-Map Layer Capacity (Phase 7)
- **Purpose**: Different continents may have different player density characteristics and require different layer capacities.
- **Mechanism**:
  - `GetLayerCapacity(mapId)` checks `_perMapCapacity` for a map-specific override, falling back to the global `Layers.Capacity`.
  - Overrides are parsed from a comma-separated config string on startup and config reload.
  - All capacity checks (`AutoAssignPlayerToLayer`, `EvaluateLayerRebalancing`) use the per-map variant.
- **Config**:
  - `MapPartitions.Layers.CapacityOverrides = "0:150,1:200,530:100,571:250"`
  - Map IDs: 0 = Eastern Kingdoms, 1 = Kalimdor, 530 = Outland, 571 = Northrend
  - Default: empty (all maps use global capacity)

---

## Bug Fixes & Improvements (2026-02-06)

### Critical Fixes

#### BUG-1: Threat-Target-Action Relays Never Processed
`ProcessPartitionRelays()` handled threat relays and taunt relays but **silently dropped** threat-target-action relays. These relays are produced by `QueuePartitionThreatTargetAction()` and are essential for cross-partition aggro resolution when a target or action is involved. The relay processing loop now correctly handles threat-target-action relays alongside standard threat relays.

#### BUG-2: Taunt Relay Dead Code Path
`ProcessPartitionRelays()` called `GetVictim()` to check the taunt target but then **discarded the result**, re-calling `GetVictim()` a second time inside the taunt application block. This was likely a copy-paste artifact. The fix consolidates both calls into a single `GetVictim()` usage and adds the missing relay processing for `TauntFade`-type taunt relays.

### High-Severity Fixes

#### ConsolidateLayers() Did Not Persist to DB
When `ConsolidateLayers()` migrated players between layers during rebalancing, it updated the in-memory layer assignment but **never called `SavePersistentLayerAssignment()`**. This meant players who logged out shortly after rebalancing would be restored to their old layer on next login. The fix adds `SavePersistentLayerAssignment(guid, mapId, layerId)` after each successful migration.

#### Identical If/Else Branches in Layer Lookups
`GetPlayerAndNPCLayer()` and `GetPlayerAndGOLayer()` had identical if/else branches: both the map-mismatch and zone-mismatch paths set `outNpcLayer = 0` (or `outGoLayer = 0`) and returned `true`. The else-branch (zone mismatch) should return the layer as `0` without pretending the lookup matched. Both functions now correctly return `outNpcLayer = 0` / `outGoLayer = 0` for the mismatch path, making the fallback behavior explicit.

#### uint16 Truncation in SavePersistentLayerAssignment()
`SavePersistentLayerAssignment()` cast `mapId` and `layerId` to `uint16` via `static_cast<uint16>()` before writing to the DB. While current values fit, this was a latent data-loss bug. The casts have been removed, and a DB migration widens the `map_id` and `layer_id` columns from `SMALLINT UNSIGNED` to `INT UNSIGNED`.

#### MapUpdater Shutdown Race & Memory Leak
- `MapUpdater::deactivate()` called `wait()` before `_queue.Cancel()`, meaning worker threads could block forever waiting for new work that never arrives. The fix calls `_queue.Cancel()` first.
- `MapUpdater::update_finished()` used `memory_order_relaxed` on a counter read by multiple threads; changed to `memory_order_acq_rel`.
- `WorkerThread()` did not `delete request` on cancellation, leaking the `PartitionUpdateRequest`. It now always frees the request.

### Medium-Severity Fixes

#### Phase Check Missing on WorldObjectListSearcher
All 5 `WorldObjectListSearcher::Visit()` overloads (Player, Creature, Corpse, GameObject, DynamicObject) were missing `InSamePhase(i_phaseMask)` checks, allowing objects from incompatible phases to appear in search results. Phase filtering is now enforced on all overloads.

#### Relay Queue Drop Logging
All 13 `QueuePartition*()` functions now emit `LOG_WARN("maps.partition", ...)` when a relay is dropped due to the queue being full (capacity = 1024). Previously, drops were completely silent, making it impossible to diagnose lost cross-partition events.

### Database Migration Required
Run `2026_02_06_01_layer_assignment_fix_bloat.sql` on the **characters** database after applying these code changes. This migration:
- Restructures the table from `PK(guid, map_id, zone_id)` to `PK(guid)` — one row per player instead of one per zone visited
- Widens `map_id` and `layer_id` from `SMALLINT UNSIGNED` to `INT UNSIGNED`
- Keeps only the latest assignment per player, dropping all stale rows
- Purges orphaned stresstest GUIDs not in the `characters` table
- Replaces the cleanup event: now runs hourly with 24h retention + orphan cleanup

---

## Blizzard-Style Migration (2026-06)

### Architecture Change: Zone-Based → Map-Wide Layering

The layering system was migrated from zone-based to Blizzard-style map-wide (continent-wide) layering. This eliminates the zone-boundary NPC/GO "pop" effect that occurred when players crossed zone lines.

**Key Changes:**
- `_layers` data structure: `[mapId][zoneId][layerId] → set<player>` → `_layers[mapId][layerId] → set<player>`
- `AtomicLayerAssignment`: `[mapId:16][zoneId:16][layerId:32]` → `[mapId:32][layerId:32]`
- All public API signatures: dropped `zoneId` parameter from ~25 functions
- Zone-change auto-assign: **removed** (layers only assigned on map entry)
- Party sync: Now cross-zone (only requires same mapId)
- NPC/GO assignment: Keeps zoneId for spawn tracking, but drops zone check from visibility matching
- DB schema: `zone_id` column writes 0 (legacy preserved for compatibility)
- Rebalancing: Wired into `LayerManager::Update()` with configurable per-map intervals

**Files Modified:** LayerManager.h, LayerManager.cpp, Player.h, PlayerUpdates.cpp, Object.cpp, Map.cpp, Group.cpp, Creature.cpp, GameObject.cpp, Unit.cpp, GridObjectLoader.cpp, cs_dc_partition.cpp, cs_dc_stresstest.cpp, cs_misc.cpp, PartitionConstants.h

---

## Future Improvements

### Potential Enhancements
1. **Metrics Dashboard**: Real-time visualization of partition loads and handoff rates.
2. **Smart Grid Sizing**: Auto-calculate grid size based on map topology (e.g., simpler grid for oceans).
3. ~~**Hysteresis / Gradual Merging**~~: ✅ Implemented (Phase 7) — warm-up/cooldown delays prevent oscillation.
4. ~~**Soft Layer Transfers**~~: ✅ Implemented (Phase 8) — rebalancing moves queued for next loading screen.
5. ~~**Per-Map Layer Capacity**~~: ✅ Implemented (Phase 7) — `CapacityOverrides` config per continent.
6. **Configurable Relay Queue Limit**: Expose `kPartitionRelayLimit` (currently compile-time 1024) as a config option for tuning on high-pop servers.
