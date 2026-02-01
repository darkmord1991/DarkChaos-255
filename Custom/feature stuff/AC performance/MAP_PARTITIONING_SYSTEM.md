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

### 2. Boundary Testing
- **Setup**: Find a partition boundary using `.gps` (coordinate where partition ID changes).
- **Test**: Two players stand on opposite sides of the line (e.g., 20 yards apart).
- **Verify**:
  - Players can see each other.
  - Chat/Emotes work.
  - Spells can cast across the line.
  - Duel can start across the line.

### 3. Layering Stress Test
- **Setup**: Set `MapPartitions.Layer.Capacity = 2` (low limit for testing).
- **Test**:
  - Teleport 3 players to the same zone.
  - **Result**: Players 1 & 2 should be in Layer 0. Player 3 should be in Layer 1.
  - **verify**: Players 1 & 2 see each other. Player 3 sees NO ONE.

### 4. Relocation Safety
- **Test**: Player mounts and runs *quickly* across multiple partition boundaries.
- **Verify**: No disconnects, no "desyncs" (teleporting back), and position saves correctly on logout.

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

## Dynamic Visibility

One of the complex challenges of partitioning is handling visibility across boundaries. If Player A is in Partition 1 and Player B is in Partition 2, but they are standing 5 yards apart (across the line), they must see each other.

### Boundary Detection
The system defines a `BorderOverlap` zone (configurable, e.g., 20 yards) along the edges of every partition.
- **Boundary Objects**: When an entity enters this overlap zone, it is flagged as a "Boundary Object".
- **Dual Registration**: The entity remains owned by its home partition but is **temporarily registered** as a "Ghost" in the adjacent partition's visibility system.

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
   - **Exception**: NPCs/GameObjects are currently visible across layers unless specifically phased.

### GPS Integration
The `.gps` command shows detailed debug info:
- **Map Partition**: Current spatial partition ID.
- **Layer**: Current population layer ID.

---

## Configuration

Control the system via `worldserver.conf`:

```ini
# Enable or disable the entire partitioning system
MapPartitions.Enabled = 1

# Comma-separated list of Map IDs to partition (e.g., 0,1,530)
MapPartitions.Maps = "0,1"

# Number of grid cells per partition side (default 8 = 64x64 grids)
MapPartitions.GridSize = 8

# Overlap distance for boundary detection (yards)
MapPartitions.BorderOverlap = 20.0

# Layering Configuration
MapPartitions.Layers.Enabled = 1
MapPartitions.Layer.Capacity = 200  # Players per layer before creating a new one
```

---

## Architecture

### 1. PartitionManager (Singleton)
- **Registry**: Tracks all partitioned maps and their grid configurations.
- **Layering Store**: Maintains `MapId -> ZoneId -> LayerId` mappings for player distribution.
- **Boundary Management**: Handles the registration/unregistration of boundary "ghost" objects.

### 2. Map & MapUpdater
- `Map::Update` detects if partitioning is enabled.
- Uses `MapUpdater` thread pool to schedule `PartitionUpdateRequest` tasks.
- **Legacy Fallback**: If partitioning is disabled, standard `Map::Update` runs sequentially.

### 3. PartitionUpdateWorker
- Thread-safe worker that executes the update loop for a single partition.
- Handles:
  - Object/Grid updates.
  - Visibility processing.
  - Relocation queue processing (moving objects between partitions).

---

## Commands

| Command | Description |
|---------|-------------|
| `.dc partition status` | Shows active partitions, player counts, and memory usage. |
| `.gps` | Displays detailed position info including Partition ID and Layer ID. |
| `.stresstest partition` | Runs performance benchmarks on partition logic. |
