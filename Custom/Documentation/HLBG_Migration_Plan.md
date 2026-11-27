# HLBG Migration Plan (Archived)

Updated: 2026-05-19

> Historical note: this document describes the pre-cutover OutdoorPvPHL migration plan.
> HLBG runtime ownership has since moved to BattlegroundHLBG and HLBGService.
> Treat file references to OutdoorPvPHL and the old split helper files as archived context,
> not current implementation guidance.

## Goal

Define a concrete migration path for Hinterland BG (HLBG) so it can support
parallel matches on custom map 1411 instead of the current single-instance
OutdoorPvP design.

## Recommendation

Use **Battleground conversion** unless there is a strict product requirement to
preserve HLBG as an OutdoorPvP system.

Reason:

- Battlegrounds already support queueing, invites, instance creation, player
  lifecycle, and cleanup.
- HLBG already uses battleground type `20` in the battlemaster bridge, so the
  concept is already present in the codebase.
- This repository already contains a custom battleground implementation,
  `BattlegroundBFG`, which can be used as the nearest working template.
- The current OutdoorPvP implementation is explicitly single-instance and tied
  to one controller per zone.

## Current Architecture Anchors

### Existing HLBG OutdoorPvP entry points

- `src/server/scripts/DC/HinterlandBG/hlbg_battlemaster_hook.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_queue.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_state_machine.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_rewards.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_reset.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_join_leave.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_affixes.cpp`

### OutdoorPvP single-instance constraints

- `src/server/game/OutdoorPvP/OutdoorPvPMgr.h`
  - `m_OutdoorPvPMap` is keyed by `zoneid`, not by instance.
- `src/server/game/OutdoorPvP/OutdoorPvPMgr.cpp`
  - `HandlePlayerEnterZone` routes by zone only.
- `src/server/scripts/OutdoorPvP/OutdoorPvPHL.cpp`
  - `SetupOutdoorPvP()` binds HLBG to `CreateBaseMap(OutdoorPvPHLMapId)`.
  - It asserts that the bound map is not instanceable.

### Battleground infrastructure anchors

- `src/server/game/Handlers/BattleGroundHandler.cpp`
  - Battlemaster hello/join flow.
- `src/server/game/Battlegrounds/BattlegroundMgr.cpp`
  - Template registration, queue mapping, live battleground creation.
- `src/server/game/Battlegrounds/BattlegroundMgr.h`
  - Battleground manager APIs.
- `src/server/game/Maps/MapInstanced.cpp`
  - `CreateBattleground()` creates isolated battleground instances.
- `src/server/game/Battlegrounds/Zones/BattlegroundAB.*`
  - Good stock pattern for a resource race battleground.
- `src/server/scripts/DC/Gilneas/BattlegroundBFG.*`
  - Existing custom battleground example in this repo.

## Option A: Battleground Conversion

### Summary

Convert HLBG from `OutdoorPvPHL` into a real battleground implementation,
`BattlegroundHLBG`, and let `BattlegroundMgr` create a fresh instance of map
1411 for each match.

### Why this is the recommended path

- Natural support for multiple concurrent matches.
- Existing AzerothCore lifecycle already handles invites, joins, map instances,
  leave behavior, and cleanup.
- Lower shared-core risk than changing OutdoorPvP manager semantics.
- The repo already demonstrates custom battleground integration through BFG.

### Phase 0: Freeze behavior before migration

Document the current HLBG feature contract before moving logic.

Use these files as the source of truth:

- `src/server/scripts/DC/HinterlandBG/hlbg_queue.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_state_machine.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_rewards.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_reset.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_join_leave.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_affixes.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_hlbg.cpp`

Capture at least:

- queue rules
- warmup timing
- resource depletion rules
- NPC kill/resource rules
- affix rules
- AFK policy
- reward policy
- addon HUD payload fields
- admin command surface

Stage gate:

- Every current player-visible rule has an explicit target in the battleground
  design.

### Phase 1: Bootstrap HLBG as a battleground type

Create a new battleground implementation, tentatively:

- `src/server/scripts/DC/HinterlandBG/BattlegroundHLBG.h`
- `src/server/scripts/DC/HinterlandBG/BattlegroundHLBG.cpp`

Model it after:

- `src/server/scripts/DC/Gilneas/BattlegroundBFG.h`
- `src/server/scripts/DC/Gilneas/BattlegroundBFG.cpp`
- `src/server/game/Battlegrounds/Zones/BattlegroundAB.h`
- `src/server/game/Battlegrounds/Zones/BattlegroundAB.cpp`

Core registration work:

1. Add the new class include to `src/server/game/Battlegrounds/BattlegroundMgr.cpp`.
2. Register HLBG in these maps:
   - `bgToQueue`
   - `queueToBg`
   - `bgtypeToBattleground`
   - `bgTypeToTemplate`
3. Reserve a battleground queue slot that does not collide with the existing
   custom BFG slot `13`.
4. Reconcile `BattlegroundTypeId(20)` in
   `src/server/scripts/DC/HinterlandBG/hlbg_battlemaster_hook.cpp` with the new
   battleground registration.

Important note:

- `MAX_BATTLEGROUND_QUEUE_TYPES` is `20`, so the chosen queue ID must remain
  within the current limit unless the queue space is intentionally expanded.

Stage gate:

- Battlemaster hello opens the HLBG battleground list.
- Battlemaster join places the player into the normal battleground queue.
- No HLBG gameplay is live yet; this phase is queue/bootstrap only.

### Phase 2: Create the first empty instanced HLBG match

Add or verify battleground template data for type `20` so it points to map
1411 and correct faction start positions.

Implement the minimum battleground methods:

- constructor/destructor
- `Init()`
- `SetupBattleground()`
- `AddPlayer()`
- `RemovePlayer()`
- `StartingEventCloseDoors()`
- `StartingEventOpenDoors()`
- `FillInitialWorldStates()`
- `PostUpdateImpl()`
- `HandleAreaTrigger()`
- `EndBattleground()`

Relevant battleground lifecycle anchors:

- `src/server/game/Battlegrounds/BattlegroundMgr.cpp`
- `src/server/game/Maps/MapInstanced.cpp`
- `src/server/game/Battlegrounds/Battleground.h`

Stage gate:

- Two different groups can produce two distinct HLBG battleground instance IDs
  on map 1411.
- Players land in their own instance instead of sharing one base map.

### Phase 3: Port HLBG match state and scoring

Move core match state from `OutdoorPvPHL` into `BattlegroundHLBG` fields.

Port from:

- `src/server/scripts/DC/HinterlandBG/hlbg_state_machine.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_rewards.cpp`

State to move:

- alliance/horde resources
- warmup timer
- live match timer
- finished/cleanup state
- affix timer and active affix
- per-player score
- per-team player kill counters
- per-team NPC kill counters

Implementation direction:

- Use battleground-owned timers in `PostUpdateImpl()`.
- Keep state instance-local.
- Remove any reliance on the OutdoorPvP singleton for authoritative match data.

Stage gate:

- A single battleground instance can start, progress, end, and reset itself
  using only battleground-owned state.

### Phase 4: Port NPC and GO spawn/reset ownership

This is the critical migration step.

Current HLBG reset logic scans area actors off a shared map:

- `src/server/scripts/DC/HinterlandBG/hlbg_reset.cpp`

That must become battleground-owned spawn/setup logic so each instance carries
its own NPCs and gameobjects.

Implementation direction:

- Spawn and track HLBG-specific objects through battleground object containers.
- Spawn and track HLBG creatures as battleground-owned units per instance.
- Move any one-shot reset logic into battleground start/cleanup hooks.

Stage gate:

- Two concurrent HLBG matches have isolated NPC and GO state.
- Resetting one match cannot alter the other.

### Phase 5: Port player lifecycle, AFK, and rewards

Port from:

- `src/server/scripts/DC/HinterlandBG/hlbg_join_leave.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_rewards.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_groups.cpp`

Replace OutdoorPvP concepts with battleground concepts:

- zone enter -> battleground add/join
- zone leave -> battleground leave/remove
- battleground raid helpers -> battleground team membership
- queue teleport -> battleground invite/enter flow

Specific policies to port:

- AFK warnings and punishments
- deserter/reward eligibility rules
- player kill handling
- NPC kill handling
- win/loss rewards
- team-based end-of-match rewards

Stage gate:

- AFK behavior and rewards work entirely inside a battleground instance.
- No reward-critical path depends on OutdoorPvPHL zone scans.

### Phase 6: Rewire addon transport to battleground state

Current addon transport anchors:

- `src/server/scripts/DC/AddonExtension/dc_addon_hlbg.cpp`
- `Custom/Client addons needed/DC-HinterlandBG/HLBG_Handlers.lua`
- `Custom/Client addons needed/DC-HinterlandBG/HLBG_HUD_Modern.lua`

Migration requirement:

- The addon must bind to battleground instance state, not OutdoorPvP zone state.
- Include battleground instance ID in native/live payloads where needed.
- Keep the compact HUD payload compatible where practical.

Stage gate:

- Two simultaneous HLBG matches each show correct local timer, resources,
  players, affix, and kill counters in the addon.

### Native platform dependencies after Phase 6

The HLBG transport slice sits inside a broader Dark Chaos native rollout.
Phase 6 should reuse the current native/live work where it already exists, but
it should not assume the surrounding platform is finished.

#### Still missing at the platform level

- A generic DC native envelope is still missing. Current rollout is still a set
  of feature-specific bridges instead of one shared request/response/push/
  invalidate layer.
- Shared native cache invalidation is still missing as a first-class system.
  The protocol already carries native build fingerprint and data revisions, but
  invalidation and refresh policy is still fragmented by feature.
- Native QoS and graphics profile pushes are still missing as a product slice.
  Those are strong native candidates because they are client-runtime-sensitive
  and the client patch already exposes the underlying controls.
- Spectator is still hybrid. Live spectator snapshots are native in
  `src/server/scripts/DC/MythicPlus/dc_mythicplus_spectator.cpp`, but the
  control plane in
  `src/server/scripts/DC/AddonExtension/dc_addon_spectator.cpp` is still addon
  only for list/start/stop/settings.
- Mythic+ activation and portal flows are still addon or AIO JSON in
  `src/server/scripts/DC/MythicPlus/dc_mythicplus_font_of_power.cpp` and
  `src/server/scripts/DC/MythicPlus/dc_mythicplus_portal_selector.cpp`.
  Those are still hybrid, but they are lower priority because they are
  low-frequency UI flows.
- The item-upgrade UI shell and HLBG UI shell are still intentionally addon
  forced in `src/server/scripts/DC/AddonExtension/dc_addon_upgrade.cpp` and
  `src/server/scripts/DC/AddonExtension/dc_addon_hlbg.cpp`.

#### Native moves that actually make sense

The short list of mandatory or near-mandatory native work from here is:

1. Generic DC native transport envelope plus shared invalidation model.
   This is the foundational move that makes later feature migrations cheaper
   and more coherent.
2. QoS and graphics profile application.
   This has high user-facing value, low conceptual risk, and a strong native
   fit.
3. Spectator control-plane cleanup, but only after the generic transport work.
   The hot path is already native; the remaining gain is reducing the hybrid
   split.
4. Tighten the patched-client path for already-landed native slices.
   That means fewer duplicate addon codepaths for tooltip family, collection
   wave1/transmog/item sets, Mythic+ HUD, spectator live, and HLBG live.

HLBG-specific interpretation:

- Do not block battleground conversion on the generic envelope work.
  HLBG already has a native live snapshot bridge, so the battleground
  conversion should first rebind that bridge to battleground-owned state.
- After battleground parity is stable, fold HLBG live transport into the
  future shared DC native envelope instead of keeping a permanent one-off path.
- Keep the HLBG UI shell addon-based until battleground parity is verified and
  patched-client adoption data says native-only UI is operationally safe.

#### Fallback policy

Do not remove fallbacks globally. Remove them per feature based on maturity and
live adoption.

- Keep HLBG live native only.
  The current selector in
  `src/server/scripts/DC/AddonExtension/dc_addon_hlbg.cpp` already treats the
  live snapshot as native-only, which is the correct direction for the
  high-cadence match feed.
- Keep the HLBG UI shell on addon transport for now.
  That preserves compatibility while match-state migration and battleground
  parity are still being proven.
- Remove duplicate addon fallback first for mature native slices on patched
  clients, not as a blanket policy across all DC systems.
- Use capability and transport audit data before retiring fallbacks.
  Relevant live tables already exist in characters DB:
  `dc_addon_client_caps`, `dc_addon_client_caps_history`, and
  `dc_addon_feature_transport_audit`.

### Phase 7: Cut over and retire the OutdoorPvP bridge

Final cutover steps:

1. Remove or feature-flag HLBG interception in
   `src/server/scripts/DC/HinterlandBG/hlbg_battlemaster_hook.cpp`.
2. Repoint admin commands from the OutdoorPvPHL singleton to active HLBG
   battleground instances.
3. Disable HLBG runtime entry through the OutdoorPvP controller.
4. Leave the old OutdoorPvP implementation behind a temporary migration flag
   until parity is confirmed.

Stage gate:

- Production HLBG traffic no longer depends on `OutdoorPvPHL`.
- All live matches are battleground instances.

### Battleground conversion risks

- Highest effort item is per-instance NPC and GO ownership.
- Addon assumptions about zone-based presence must be updated to instance-based
  presence.
- Admin tooling that assumes a singleton HLBG controller must be rewritten.

### Estimated effort

- Queue/bootstrap: low
- First empty instanced match: medium
- Gameplay parity: high
- Full cutover: high

Overall: **medium-high effort, lower architectural risk** than OutdoorPvP
refactor.

## Option B: OutdoorPvP Refactor

### Summary

Keep HLBG as OutdoorPvP but refactor the manager and controller model so one
zone can host multiple concurrent HLBG controller instances, each tied to a map
instance.

### Why this is not recommended

- Requires shared-core manager changes.
- Keeps responsibility for inventing per-instance OutdoorPvP lifecycle in custom
  code.
- Much higher regression risk for other OutdoorPvP systems.

### Phase 1: Make OutdoorPvPMgr instance-aware

Current limitation:

- `src/server/game/OutdoorPvP/OutdoorPvPMgr.h`
  - one `zoneid -> OutdoorPvP*` mapping

Refactor target:

- support either `zoneid + instanceid` lookup, or
- support one zone mapping to a controller registry that can resolve players to
  a match controller.

Files involved:

- `src/server/game/OutdoorPvP/OutdoorPvPMgr.h`
- `src/server/game/OutdoorPvP/OutdoorPvPMgr.cpp`
- `src/server/game/OutdoorPvP/OutdoorPvP.cpp`

Stage gate:

- Existing OutdoorPvP systems still work unchanged after the registry update.

### Phase 2: Split HLBG into lobby and match controllers

Current limitation:

- HLBG state is singleton state on one `OutdoorPvPHL` controller.

Refactor target:

- one lobby allocator/controller owns queueing
- one per-match controller owns live match state

State that must become per-match:

- resources
- timers
- affix state
- tracked players
- NPC kill counters
- player score tables
- rewards state

Stage gate:

- Two HLBG controller instances can coexist in memory without sharing live match
  state.

### Phase 3: Replace base-map ownership with instance-map ownership

Current limitation:

- `src/server/scripts/OutdoorPvP/OutdoorPvPHL.cpp`
  - `CreateBaseMap(OutdoorPvPHLMapId)`
  - asserts non-instanceable map use

Refactor target:

- create or borrow an instance creation path similar to battleground maps,
  without abandoning OutdoorPvP semantics.

Likely related code:

- `src/server/game/Maps/MapInstanced.cpp`
- `src/server/game/Maps/Map.h`
- `src/server/game/Maps/Map.cpp`

Stage gate:

- A second HLBG match can create a second instance of map 1411 and unload it
  safely when empty.

### Phase 4: Make all HLBG lookups instance-aware

Current singleton-style accessors must be removed or replaced.

Known anchors:

- `src/server/scripts/DC/HinterlandBG/hlbg_battlemaster_hook.cpp`
- `src/server/scripts/DC/HinterlandBG/hlbg_utils.cpp`

Requirement:

- No live gameplay path may ask for "the HLBG controller" by zone only.
- All lookups must be player-context or match-context aware.

Stage gate:

- No singleton HLBG live-state accessor remains in active code paths.

### Phase 5: Regression-test all OutdoorPvP users

This is mandatory because the refactor touches shared OutdoorPvP manager
behavior.

Minimum validation scope:

- HLBG
- any other OutdoorPvP zones in the repo/core
- zone entry/leave routing
- worldstate broadcasting
- controller cleanup

Stage gate:

- Existing OutdoorPvP features remain stable before multi-instance HLBG is
  enabled.

### OutdoorPvP refactor risks

- Shared-core regressions outside HLBG.
- High complexity in lifecycle and cleanup.
- Easy to accidentally leave singleton assumptions in utility code.
- Harder to reason about than battleground conversion because the framework is
  not designed around repeated concurrent PvP copies.

### Estimated effort

- Core manager refactor: high
- Per-instance controller lifecycle: high
- Regression testing: high

Overall: **high effort, high architectural risk**.

## Decision Rule

Choose **Battleground conversion** if the goal is:

- one full raid starts a match
- the next raid can start another match on map 1411
- each match gets isolated players, timers, resources, NPCs, and HUD data

Choose **OutdoorPvP refactor** only if the requirement is explicitly:

- HLBG must remain an OutdoorPvP system for product reasons, not just because
  it already exists that way.

## Suggested Implementation Order

If proceeding with battleground conversion, use these four delivery gates:

1. **Queue bootstrap**
   - HLBG battlemaster type is routed into the battleground queue.
2. **Empty instanced map**
   - multiple empty HLBG instances can be created on map 1411.
3. **Gameplay parity**
   - timers, resources, NPCs, rewards, affixes, AFK, and scoreboards match the
     current HLBG rules.
4. **Addon and admin cutover**
   - addon and GM/admin tools use battleground state, and OutdoorPvP HLBG is
     retired or feature-flagged.

## Immediate Next Step

If work starts on this migration, the next artifact should be a **file-by-file
execution checklist for the Battleground conversion path**, including:

- proposed new source filenames
- queue ID choice
- battleground template and data requirements
- addon protocol deltas
- staged rollback points
