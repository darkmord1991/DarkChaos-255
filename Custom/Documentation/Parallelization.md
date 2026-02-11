# Parallelization Systems and Next Candidates

## Goal
This document summarizes the server's current parallelization model and highlights the next best candidates for thread-safety review. It focuses on whole-server runtime systems (excluding tools and network stacks), with a high-level shortlist and rationale.

## Current Parallelized Systems (Overview)

### Map Partitioning Model
The core parallelization approach is partitioned map updates. A map can run multiple partition workers that update player and non-player object buckets in parallel. Key pieces:
- Partition update workers update subsets of objects in parallel.
- Each worker operates with an active partition context.
- Cross-partition interactions are redirected through relay queues.

### Relay System (Cross-Partition Safety)
Relays are used to execute operations on the owning partition thread. The pattern is:
1) The caller detects that the target unit/object belongs to a different partition.
2) It enqueues a relay item into a per-partition queue.
3) The owning partition drains and processes relays in its update loop.

Relay queues exist for multiple systems (threat, proc, aura, movement, assist, taunt, combat start, combat state, attack, evade, loot/tap, dynamic objects, and passenger relocation). Each relay queue is guarded by striped locks and has a fixed size limit to prevent overload.

### Object Update Mask and Field Updates
Object field updates are tracked with update masks and per-object update lists. Races can occur if multiple threads modify the same field in read-modify-write patterns. Recent fixes include locking for flag RMW operations to prevent lost-bit updates.

### Aura and Combat System
Auras and combat calculations are heavily accessed in parallel contexts. Recent fixes moved list iteration to snapshot copies for safe traversal during concurrent modifications.

### Visibility Defer and Map Update Lists
Visibility updates and map update lists use dedicated locks to ensure safe changes during multi-threaded updates.

## Known Safety Patterns
- Use snapshot copies when iterating lists that can be modified concurrently.
- Gate cross-partition work with relays when the target belongs to another partition.
- Lock read-modify-write operations on shared fields.
- Keep lock scopes small and avoid locking during external callbacks where possible.

## Completed Systems (Current Branch)
- Script scheduling and execution guarded for cross-thread access; map script schedule cleared under lock on destruction.
- Movement generators and motion state relays added for cross-partition movement commands, including transport enter/exit and passenger relocation.
- Object update list races reduced with atomic update-state and locked list mutations.
- Visibility deferral enforced for partition workers (non-players via deferred queue; players via forced-update request).
- Combat AI state transitions relayed for cross-partition entry, attack, and evade operations.
- Loot/tap ownership updates relayed to the owning partition before mutating loot recipients.
- Pet/controlled relationships align charmer/minion partitions during charm/minion updates to avoid cross-thread mutations.
- Dynamic object removals relayed to the owning partition when invoked cross-partition.
- Combat aura iteration stabilized by snapshotting aura effect lists.
- Flag RMW operations on object update fields protected to avoid lost-bit races.

## Next Candidates for Thread-Safety Review (High-Level)

The items below are prioritized by the likelihood of cross-thread access and the potential impact if races occur.

| Priority | System | Risk | Rationale | Suggested Next Step |
|---|---|---|---|---|
| Done | Script scheduling and execution | High | Scripts may touch world state during partition updates; shared structures risk data races if accessed off-thread. | Guard scheduler access and prevent cross-thread execution. |
| Done | Movement generators and motion state | High | Movement states are frequently modified during AI and combat. Cross-thread updates can corrupt movement state or cause invalid transitions. | Added relays for cross-partition movement. |
| Done | Object update list and visibility deferral | High | Update list mutations occur during parallel updates. Any missing lock can cause update list corruption. | Added atomic update state and visibility deferrals. |
| Done | Combat AI state transitions | Medium | AI state flags may be updated during parallel combat events. Inconsistent transitions can lead to stuck or invalid AI. | Relayed combat state, attack, and evade operations to owning partitions. |
| Done | Loot and tap ownership | Medium | Loot/tap state can be updated by multiple sources in combat. Races can mis-assign loot or tap flags. | Relayed loot recipient updates to the owning partition. |
| Done | Pet/controlled unit relationships | Medium | Ownership chains and controlled unit sets are shared across AI/combat. These have known contention points. | Aligned charmer/minion partitions during control updates. |
| Done | Dynamic object / game object interactions | Medium | Objects are updated in parallel and interact with units. Races can appear in object life-cycle state. | Relayed dynamic object removals to owning partitions. |
| Low | Map scripting hooks around instance state | Low | Instance scripts typically run in map thread, but may be invoked by cross-thread events. | Confirm the thread context of instance script invocations and guard if needed. |

## Recommended Audit Strategy
1) Identify all code paths reachable from partition worker threads.
2) For each path, check for:
   - Shared lists/containers without locks
   - RMW patterns on shared fields
   - Cross-partition access without a relay
3) Prioritize items that can cause state corruption or crashes.
4) Implement fixes using consistent patterns (snapshot, locks, relays).

## Notes for Future Fixes
- Prefer relays over locks when the operation touches large or complex state.
- Use fine-grained locks for short critical sections that only update simple fields.
- Avoid calling AI callbacks while holding locks to prevent deadlocks.
- Visibility updates called from partition workers should be deferred to the map thread using `QueueDeferredVisibilityUpdate` for non-players.
- Player visibility updates should short-circuit in partition workers by setting `bRequestForcedVisibilityUpdate` and returning.
- Vehicle transport exit spline work should be routed through the motion relay to run on the passenger's owning partition thread.
- Passenger relocation during vehicle movement uses a dedicated relay action to update position on the owning partition thread.
- MovementGenerators execute inside the owning unit's update context; they are generally exempt from relays unless invoked cross-partition.

## Appendix: Relay Pattern Checklist
- Confirm map is partitioned and a partition context exists.
- Ensure relays are not processed recursively (guard against re-entry).
- Use per-partition queue with size limit.
- Process relays in owning partition update and record latency metrics.
