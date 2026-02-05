# Map Partitioning & Layering System

## Overview
The **Map Partitioning System** is a high-performance scalability feature designed to parallelize map updates and manage high-population density through layering. It splits large game maps into smaller, independent update units ("partitions") that can be processed concurrently by worker threads.

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
  - Teleport 3 players to the same zone.
  - **Result**: Players 1 & 2 should be in Layer 0. Player 3 should be in Layer 1.
  - **verify**: Players 1 & 2 see each other. Player 3 sees NO ONE (except service NPCs).

### 5. Relocation Safety
- **Test**: Player mounts and runs *quickly* across multiple partition boundaries.
- **Verify**: No disconnects, no "desyncs" (teleporting back), and position saves correctly on logout.

---

## Technical Implementation

### Grid Partitioning Logic
The map is spatially divided into a generic grid of **N x N** partitions based on the `MapPartitions.GridSize` configuration.
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
| `_layerLock` | `mutex` | Protects layer assignments |
| `_boundaryLock` | `mutex` | Protects boundary object sets |
| `_relocationLock` | `mutex` | Protects relocation transactions |
| `_overrideLock` | `mutex` | Protects partition overrides and ownership |
| `_visibilityLock` | `mutex` | Protects visibility sets |
| `_handoffLock` | `mutex` | Protects handoff counters |

### Automatic Cleanup
- **Relocation Cleanup**: Timed-out relocations are auto-rolled back via `CleanupStaleRelocations()`
- **Boundary Cleanup**: Objects leaving boundary zones are unregistered to prevent memory leaks
- **Override Cleanup**: Expired partition overrides are cleaned via `CleanupExpiredOverrides()`

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

## Layering System

The layering system functions as a sub-system of the partition manager. It solves the problem of "too many players in one area" by creating virtual copies of the zone logic.

### How it Works
1. **Assignment**: When a player enters a zone, `PartitionManager::AutoAssignPlayerToLayer` determines their layer.
   - If current layers are full (>= `Layer.Capacity`), a new layer is created.
   - Preference is given to filling existing layers (0, 1, 2...).
2. **Stickiness**: Players prefer to stay in their assigned layer when moving between sub-zones to prevent "phasing" flicker.
3. **Visibility Filtering**:
  - `WorldObject::CanSeeOrDetect` checks layer compatibility.
  - **Rule**: Players can only see other players in the **same layer**.
  - **NPCs**: If NPC layering is enabled and multiple layers exist in the zone, NPCs are only visible to players on the same layer.
4. **Logout Cleanup**: `ForceRemovePlayerFromAllLayers()` ensures proper cleanup on disconnect.

### Performance Optimization
The visibility check uses `GetLayersForTwoPlayers()` for **single-lock layer comparison** instead of two separate lookups.

### GPS Integration
The `.gps` command shows detailed debug info:
- **Map Partition**: Current spatial partition ID.
- **Layer**: Current population layer ID.

### Dynamic Layer Switching
Layer assignment is evaluated **when players enter a map** and **on zone change**:
- `Map::AddPlayerToMap` assigns a layer on map entry.
- `Player::UpdateZone` re-evaluates the layer on zone change.

**Stickiness** applies within the same zone. Players are not continuously rebalanced while moving inside a zone. Party sync can move members to the leader’s layer when `AutoAssignPlayerToLayer` is called.

When NPC layering is enabled (`MapPartitions.Layers.IncludeNPCs = 1`), **each layer is a completely independent world copy** (like retail WoW layering):
- **World spawns** (creatures/gameobjects) are deterministically distributed across layers
- **Player-owned NPCs** (pets/guardians/charmed) are synced to the owner's layer on assignment
- **Complete isolation**: Players can only see other players and NPCs on the same layer

**Service NPCs** (questgivers, guards, vendors, trainers, bankers, flight masters) are treated as cross-layer to prevent critical interaction loss during switches.

**Layer creation rebalancing**: when a new layer is created for a zone, NPCs previously assigned to layer 0 are redistributed across active layers for that zone.

**Dynamic layering**: new layers are created only when a player joins/gets assigned and all existing layers are at capacity, up to `MapPartitions.Layers.Max`.

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

# Overlap distance for boundary detection (yards)
MapPartitions.BorderOverlap = 20.0

# Zones excluded from partitioning (cities, hubs)
MapPartitions.ExcludeZones = "1519,1637,4395,3703"

# Layering Configuration (Enabled by Default)
MapPartitions.Layers.Enabled = 1
MapPartitions.Layers.Capacity = 200   # Players per layer before creating a new one
MapPartitions.Layers.Max = 4          # Maximum number of layers per zone
MapPartitions.Layers.IncludeNPCs = 0   # Assign NPCs to layers (0=Disabled)

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
*   **Handling**: Fully partitioned.
*   **Reason**: These maps are massive and host the majority of the population. Partitioning is essential here.
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
*   **Config**: `MapPartitions.ExcludeZones` (IDs: 1519=Stormwind, 1637=Orgrimmar, etc.).

---

## Architecture

### 1. PartitionManager (Singleton)
- **Registry**: Tracks all partitioned maps and their grid configurations.
- **Layering Store**: Maintains `MapId -> ZoneId -> LayerId` mappings for player distribution.
- **Boundary Management**: Handles the registration/unregistration of boundary "ghost" objects.
- **Relocation Transactions**: Thread-safe state machine for cross-partition relocations.

### 2. Map & MapUpdater
- `Map::Update` detects if partitioning is enabled.
- Uses `MapUpdater` thread pool to schedule `PartitionUpdateRequest` tasks.
- **Legacy Fallback**: If partitioning is disabled, standard `Map::Update` runs sequentially.

### 3. PartitionUpdateWorker
- Thread-safe worker that executes the update loop for a single partition.
- Handles:
  - Object/Grid updates.
  - Visibility processing.
  - Boundary detection and cleanup.
  - Relocation queue processing (moving objects between partitions).

---

## Commands

### Player Commands:
- `.dcpartition status` — View partition and layer info for your current map.
- `.dcpartition layer <id>` — Manually switch to a specific layer (GM mode).
- `.dcpartition diag <on|off|status>` — Toggle runtime diagnostics for layer assignment logging.
- `.dcpartition config` — Display current partition and layer configuration settings.

All commands are under `.dc partition` (requires GM permissions).
| Command | Description |
|---------|-------------|
| `.gps` | Displays detailed position info including Partition ID and Layer ID. |
| `.stresstest partition [iterations]` | Runs performance benchmarks on partition logic. |

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

### 3. Persistent Layering
- **Purpose**: Keep players in their assigned layer (e.g., "Layer 2") even after logout/login.
- **Storage**: `dc_character_layer_assignment` table.

### 4. Cross-Layer Party Sync
- **Purpose**: Prevent "I can't see you" issues in parties.
- **Logic**: When joining a party or entering a zone, players automatically switch to the leader's layer if possible.

### 5. NPC Layering
- **Purpose**: Allow different NPCs to exist in different layers (e.g., for phased events).
- **Toggle**: `MapPartitions.Layers.IncludeNPCs`.
- **Default distribution**: Static world spawns without an owner are deterministically distributed across existing, non-empty layers (prefers non-zero layers when available).

---

## Notes & Performance Considerations
- **Layer choice is not continuous**: players only change layers on map entry or zone change (plus party sync), not on every movement tick.
- **Static NPC distribution** is deterministic per spawn, avoiding cross-layer duplication while keeping load balanced.
- **Dynamic resizing cost**: resizing triggers a rebuild of partitioned assignments; throttling prevents frequent churn.
- **Empty layer cleanup**: empty layers are pruned when the last player leaves, preventing stale layer ids.
- **Persistent layer restore**: layer restore only succeeds if the target layer still exists; otherwise normal auto-assign applies.
- **NPC visibility**: when multiple layers exist in a zone, NPCs are layer-isolated; layer `0` is not global in multi-layer zones.

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
- **Command**: `.dc partition join <player>`
- **Anti-Exploit**:
  - Combat/death checks (cannot switch in combat or while dead).
  - Escalating cooldowns: 1min → 2min → 5min → 10min max.
  - Social requirement: Must be friends, guildmates, or groupmates.

### 8. Layer Rebalancing (Phase 6)
- **Purpose**: Automatically consolidate sparse layers to prevent "ghost" layers.
- **Mechanism**:
  - `EvaluateLayerRebalancing()` runs periodically (every 5 minutes per zone).
  - Uses coefficient of variation to detect imbalance.
  - `ConsolidateLayers()` migrates players with in-game notifications.
- **Config**:
  - `MapPartitions.Layers.Rebalancing.Enabled = 1`
  - `MapPartitions.Layers.Rebalancing.CheckIntervalMs = 300000`
  - `MapPartitions.Layers.Rebalancing.MinPlayersPerLayer = 5`
  - `MapPartitions.Layers.Rebalancing.ImbalanceThreshold = 0.3`

---

## Future Improvements

### Potential Enhancements
1. **Metrics Dashboard**: Real-time visualization of partition loads and handoff rates.
2. **Smart Grid Sizing**: Auto-calculate grid size based on map topology (e.g., simpler grid for oceans).
3. **Cross-Shard Layering**: Integration with cross-realm technology for larger populations.
