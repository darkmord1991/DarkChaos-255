# Dark Chaos Native Client Module via WotLK-Extensions

## Document Purpose

This document captures a long-term design direction for combining:

- Dark Chaos server-side addon systems
- `DC-AddonProtocol`
- `AddonExtension`
- the external `WotLK-Extensions` client patch project

The goal is to define a practical path toward a dedicated Dark Chaos client
module inside `WotLK-Extensions` that can massively improve transport
efficiency, client-side capabilities, and overall handling of large or
high-frequency DC addon features.

This is intended as a future reference and architecture memo, not as a final
implementation spec.

---

## Executive Summary

Dark Chaos has already pushed the stock addon-channel model far beyond its
normal intended use.

Today the existing stack already supports:

- a unified DC addon protocol
- large JSON payloads
- heavy chunking
- request/response tracking
- per-module routing
- live telemetry and diagnostics

That work has been valuable, but it also shows the limit of the approach.

The next major improvement should not be another round of addon-channel tuning.
It should be a **separate Dark Chaos native client module inside
`WotLK-Extensions`**.

That module should turn the architecture into a hybrid model:

- `DC-AddonProtocol` remains the compatibility layer, fallback lane, and
  control-plane handshake.
- `WotLK-Extensions` becomes the high-performance native lane for heavy,
  high-frequency, or client-runtime-sensitive features.
- Custom DBCs become the storage path for large static catalogs that should not
  be shipped repeatedly at runtime.

In short:

**Use addon protocol for coordination. Use native extension transport for real
work. Use custom DBCs for static data.**

---

## Current Verified Baseline

### Current DC transport model

The current DC server transport still emits addon traffic using addon/chat
packet framing rather than a native custom message path.

Important observed characteristics:

- server send path still builds addon whisper packets
- large responses are chunked
- client reassembles chunked payloads in Lua
- JSON is the standard high-level envelope for many DC features
- request/response lifecycle is tracked in Lua and on the server
- telemetry tables track protocol usage, errors, and per-module stats

This means the architecture is already disciplined, but it is still constrained
by the shape of addon transport.

### Current DC protocol limits already in use

Observed in the current repo:

- `DC.MAX_CHUNKS_PER_MESSAGE = 2048`
- `DC.MAX_JSON_PAYLOAD_SIZE = 524288`
- chunked sending and reassembly are already core behavior

This is an important design signal:

If a system already needs 2048 chunks and 512 KB JSON support, the problem is
not that the stock addon model was tuned too little. The problem is that the
workload has outgrown the transport.

### Current WotLK-Extensions capabilities already available

From the current external repo snapshot, `WotLK-Extensions` already supports:

- custom packet handling above stock opcode range
- client-side custom Lua function registration
- graphics and view-distance related patches
- optional GlueXML integration hooks
- custom DBC loading
- Large Address Aware patching via the patcher
- some DC-adjacent features already implemented, including breaking news and a
  mixed spell-tooltip enrichment path

### Current custom opcode range in the external client patch repo

Observed custom opcodes currently start at the stock boundary:

- `NUM_ORIGINAL_MSG_TYPES = 1311`
- `SMSG_UPDATE_CUSTOM_COMBAT_RATING = 1311`
- `CMSG_TELEPORT_GRAVEYARD_REQUEST = 1312`
- `CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 1313`
- `SMSG_SPELL_TOOLTIP_ENRICHMENT = 1314`
- `SMSG_BREAKING_NEWS = 1315`

This is enough to prove that the extension already has a functioning native
custom-packet path. The missing part is not the base mechanism. The missing part
is a Dark Chaos-specific transport and feature layer built on top of it.

---

## Why A Separate DC Module Is The Right Move

### The core problem

The DC addon stack is increasingly serving systems like:

- wardrobe and collection UIs
- dynamic tooltip enrichment
- Mythic Plus features
- spectator and battleground overlays
- QoS and navigation features
- breaking news and richer client experiences

These systems create three classes of pressure:

1. Large payload pressure
2. High-frequency update pressure
3. Client-runtime capability pressure

Addon chat can be stretched to carry those, but it remains a string-based,
chunk-heavy, Lua-centric transport with awkward limits and more client work than
necessary.

### What a separate DC module changes

A Dark Chaos module inside `WotLK-Extensions` changes the question from:

"How do we make addon transport tolerate more work?"

to:

"Which workloads should move off addon transport, and which should remain on
it only for control, fallback, or low-volume paths?"

That is the right framing because the target architecture is hybrid, not
"everything native."

### High-level architectural shift

#### Before

- server serializes large text payloads
- server chunks responses
- client receives addon packets
- Lua reassembles strings
- Lua parses JSON
- Lua updates UI state

#### After

- server negotiates native capability at session start
- heavy modules send native packets when supported
- static data moves to custom DBCs where appropriate
- Lua receives smaller, more targeted, more native-friendly data
- addon protocol remains as fallback for unpatched or downgraded clients

This reduces work on both sides and makes the system easier to extend.

---

## Design Goals

### Primary goals

- Reduce transport overhead for heavy DC features
- Reduce Lua string churn and JSON parsing pressure
- Reduce server chunking and addon-packet bookkeeping pressure
- Preserve compatibility through a fallback path
- Expose richer native client capabilities to DC addons
- Enable larger and richer UIs without making addon transport the bottleneck
- Create a clean foundation for future Dark Chaos-specific client/runtime work

### Secondary goals

- Improve observability and client capability reporting
- Make feature rollout incremental instead of all-or-nothing
- Support revision-based caching and invalidation
- Centralize client QoS and graphics profile control

### Non-goals

- Removing `DC-AddonProtocol` entirely
- Making a patched client mandatory for every DC feature on day one
- Migrating every feature at once
- Raising arbitrary client limits without a clear product or performance reason

---

## Recommended High-Level Architecture

### 1. Control plane: DC-AddonProtocol

Keep `DC-AddonProtocol` as the control plane for:

- handshake and capability negotiation
- compatibility with unpatched clients
- lightweight request/response flows
- diagnostics and fallback routing
- lower-priority or low-volume feature traffic

This avoids breaking the current addon ecosystem and preserves an operationally
safe fallback lane.

### 2. Native data plane: DC module inside WotLK-Extensions

Add a new Dark Chaos-specific subsystem inside the client DLL for:

- custom packet send/receive
- compact structured payload handling
- feature gating and capability flags
- local runtime caches
- fast-path UI-facing data delivery

This is where the real performance gains come from.

### 3. Static reference plane: custom DBCs

Move large, mostly-static catalogs out of runtime protocol traffic.

Candidates include:

- collection definitions
- wardrobe source metadata
- map overlay descriptors
- static Mythic Plus dungeon metadata
- teleport catalog metadata
- large client lookup tables used by DC features

The more static data lives in DBCs, the less runtime sync pressure hits the
protocol.

### 4. Glue and pre-login plane

Use GlueXML and glue Lua hooks for features that should exist before world entry.

This is especially valuable for:

- breaking news
- seasonal announcements
- maintenance messages
- launcher-like status information
- account-facing notices

---

## Proposed DC Module Shape Inside WotLK-Extensions

The extension project is currently a single DLL with feature gates rather than a
hot-loadable plugin architecture. The DC module should fit that reality.

Recommended approach:

- add a dedicated compile-time feature flag such as `DC_PATCH` or
  `DC_NATIVE_MODULE`
- add a dedicated source subtree for DC functionality
- keep DC registration centralized in the existing startup hooks

### Suggested source layout in the external repo

```text
WotLKExtensions/
  src/
    DC/
      DCModule.cpp
      DCModule.hpp
      DCProtocol.cpp
      DCProtocol.hpp
      DCLua.cpp
      DCLua.hpp
      DCCache.cpp
      DCCache.hpp
      DCGraphicsProfiles.cpp
      DCGraphicsProfiles.hpp
      DCGlue.cpp
      DCGlue.hpp
      DCTelemetry.cpp
      DCTelemetry.hpp
      Data/
        DCOpcodes.hpp
        DCFeatureFlags.hpp
        DCPayloadKinds.hpp
```

### Suggested integration points

- `Main::Init()`
  - initialize DC runtime state
  - register packet handlers
  - register Lua functions
- `CNetClient::SetCustomHandlers()`
  - register DC opcodes
- `CustomLua::Apply()`
  - expose DC client APIs to Lua
- `CGlueMgr::Apply()` and related glue registration
  - expose DC glue-facing APIs where needed

---

## Proposed Internal Subsystems

### DCProtocol

Purpose:

- own DC-native packet opcodes
- provide request/response and push-message handling
- manage binary or structured payload framing
- negotiate feature masks and protocol versioning

Responsibilities:

- packet registration
- envelope encoding/decoding
- optional compression handling
- session capability flags
- fallback routing decisions

### DCLua

Purpose:

- provide the Lua surface exposed to DC addons
- hide raw packet details behind stable Lua APIs

Responsibilities:

- expose feature-specific helper functions
- expose capability checks
- expose client revision and build fingerprint info
- expose cache state and diagnostic counters

### DCCache

Purpose:

- hold native-side caches that should not live purely in addon Lua tables

Responsibilities:

- revisioned payload caches
- invalidation handling
- prewarmed reference data
- rate-limit aware request suppression

### DCGraphicsProfiles

Purpose:

- centralize graphics and QoS profile application for DC

Responsibilities:

- profile application from Lua or native packet updates
- safe clamping of extended client settings
- optional mode-based profiles for BGs, cities, raids, open world, and custom
  events

### DCGlue

Purpose:

- support login and character-select features

Responsibilities:

- breaking news
- pre-login notices
- future splash panels or server notices

### DCTelemetry

Purpose:

- give better client-side insight than generic Lua logging alone

Responsibilities:

- native transport counters
- packet rejection reasons
- capability mismatch tracking
- compression and cache hit statistics

---

## Suggested Capability Split

The system should intentionally split responsibilities by transport.

| Layer | Best Use | Why |
|------|----------|-----|
| `DC-AddonProtocol` | Handshake, fallback, lightweight coordination | Already deployed, compatible, flexible |
| Native DC packets | Heavy or high-frequency live data | Lowest transport overhead, strongest control |
| Custom DBCs | Static reference data | Zero runtime sync for stable catalogs |
| Glue-side APIs | Pre-world UX | Available before addon world init |
| Pure client-local Lua/native logic | Rendering, local calculations, QoL helpers | No server roundtrip required |

---

## What Can Be Handled Via This Option Now

This section is intentionally split into three groups.

### A. Things the current extension already proves are possible

#### 1. Native custom packet transport

Already demonstrated by the existing custom opcode handling.

What this enables immediately in principle:

- native DC request/response flows
- native DC push events
- compact structured packets instead of addon strings
- lower-Lua-overhead routing for hot features

#### 2. Native spell tooltip enrichment path

The extension already contains a mixed tooltip enrichment packet path.

Why this matters:

- tooltip enrichment is request-heavy
- tooltip display is latency-sensitive
- tooltip UX directly exposes transport stalls or timeouts

This should be the first pilot migration.

#### 3. Breaking news and pre-world payload handling

The extension already demonstrates cached breaking-news payload handling for the
glue environment.

This proves the general concept of:

- pre-world state caching
- glue-side Lua accessors
- UI behavior driven by native packet state

#### 4. Client-side navigation and ping helpers

The extension already exposes functions for:

- cursor world target resolution
- mouseover target resolution
- ping payload encoding/decoding
- GUID position resolution
- waypoint and super-tracking helpers

This means a lot of navigation and map UX can become client-driven or
client-assisted rather than server-heavy.

#### 5. Extended graphics and view-distance controls

The extension already exposes helpers for:

- farclip
- camera distance
- horizon scale
- environment detail
- fog distance
- nameplate distance
- texture quality helpers
- render flag helpers

These are immediate levers for QoS and profile systems.

### B. Things that need only a small DC-specific extension patch

#### 1. Generic DC native packet bridge

This is the highest-value next step.

Instead of adding many one-off custom packets, add a compact DC packet layer for:

- request/response
- push events
- bulk syncs
- invalidation messages
- client capability negotiation

#### 2. Native cache invalidation messages

Instead of resending full catalogs, use revision and invalidation packets.

Examples:

- wardrobe data revision changed
- collection category cache invalidated
- Mythic Plus seasonal metadata revision changed
- map overlays updated

#### 3. Native QoS profile packets

The server could push profile recommendations or defaults that the client then
applies locally via native helpers.

Examples:

- raid profile
- battleground profile
- city profile
- open-world exploration profile
- low-end hardware safe profile

#### 4. Native feature probes

Expose a stable client capability report for addons and the server.

Examples:

- extension build fingerprint
- feature bitmask
- graphics patch availability
- glue capability
- custom DBC availability

### C. Things that are bigger but strategically excellent

#### 1. Static catalog migration to custom DBCs

This is a larger content pipeline investment, but it may remove the largest
source of bulky addon payloads.

#### 2. Native live-state transport for Mythic Plus, spectator, and HLBG

These features are much better suited to compact typed packets than to addon
chat strings.

#### 3. Richer client-local UI services

Examples:

- native cache-backed tooltip lookup helpers
- native minimap or map-pin support helpers
- client-side spatial queries for DC overlays
- native frame-state or navigation-state helpers for complex UI modules

---

## What Is Still Missing

The missing pieces are mostly not "another random feature bridge."

They are the structural gaps and the still-hybrid systems that keep the overall
architecture from behaving like one coherent native platform.

### 1. Generic DC native envelope

This is the biggest remaining gap.

Right now the rollout is still a growing set of feature-by-feature bridges.
That works for proving value, but it is not the same as having one shared
native request/response/push/invalidate layer.

Without that shared layer:

- feature migrations keep inventing their own packet shapes
- cache policy stays fragmented
- fallback policy keeps drifting feature by feature
- native rollout costs stay higher than they should be

### 2. Shared native cache invalidation

The client already reports native build fingerprint and installed data
revisions.

What is still missing is a first-class invalidation model that lets the server
say:

- this cache is still valid
- this cache must be invalidated
- this feature may use runtime fallback cache
- this feature must be disabled until client content is updated

Until that exists, refresh behavior remains fragmented by feature instead of
becoming one disciplined native cache system.

### 3. Native QoS and graphics profile pushes

This is one of the clearest product slices that still belongs on the native
side.

Why:

- it is client-runtime-sensitive
- the client patch already exposes the underlying controls
- it creates immediate user-facing value
- it fits the long-term goal of Dark Chaos owning a real client-runtime
  strategy

### 4. Spectator control plane is still hybrid

Live spectator snapshots are already on the native lane, but the control plane
is still addon-only for:

- list runs
- start spectating
- stop spectating
- spectator HUD settings

That means the hot path is improved, but the overall feature still behaves like
a hybrid system rather than a clean native-first slice.

### 5. Mythic Plus activation and portal flows are still addon or AIO JSON

The keystone activation flow and seasonal portal selector are still delivered
through addon or AIO-style JSON payloads.

These are real remaining gaps, but they are not the highest-value native moves
because they are low-frequency UI flows rather than high-cadence feeds.

### 6. Some UI shells are intentionally still addon-forced

The item-upgrade UI shell and the HLBG UI shell are still explicitly kept on
addon transport.

That is not necessarily wrong today.

It simply means the platform is still intentionally hybrid in those areas, and
that should be described honestly instead of treating every native capability
bit as if the entire feature is already native.

---

## What Really Makes Sense To Move

Not every remaining addon path deserves native work next.

The mandatory or near-mandatory moves from here are the ones that improve the
whole platform rather than adding another isolated bridge.

### 1. Generic DC native transport envelope plus invalidation model

This is the foundational move.

It is the single change that makes every later migration cheaper, more
coherent, and easier to reason about.

This should include:

- one shared envelope model
- one shared capability and revision-aware routing model
- one shared invalidate and refresh story
- one disciplined distinction between native content, runtime cache fallback,
  and disabled state

### 2. QoS and graphics profile application

This is high user-facing value with low conceptual risk.

It also uses a client-native surface that already exists, which means it is a
better next move than inventing more one-off feature bridges.

### 3. Spectator control-plane cleanup

This should happen after the generic transport work, not before it.

Reason:

- the hot path is already native
- the remaining value is reducing the hybrid split
- a shared native envelope makes this cleanup much cheaper than doing it as a
  bespoke control-plane bridge

### 4. Tighten the patched-client path for already-landed native slices

Several slices already have meaningful native delivery but still carry extra
duplicate addon codepaths for patched clients.

That is the right place to be more aggressive once adoption and telemetry are
good enough.

Candidates include:

- tooltip family
- collection wave1
- collection transmog state
- collection item sets
- Mythic Plus HUD
- spectator live snapshots

The important point is this:

Once a native slice is mature, the goal should not be to preserve duplicate
patched-client addon fallback forever.

The goal should be:

- fallback for unpatched clients
- native-first behavior for patched clients
- eventual removal of duplicate patched-client addon paths when telemetry shows
  that it is operationally safe

---

## Fallback Cleanup Guidance

Fallback removal should be feature-specific, not ideological.

### Good candidates to keep fallback longer

- low-frequency administrative tooling
- debug surfaces
- compatibility paths for unpatched clients
- UI shells that are intentionally still addon-owned today

### Good candidates to tighten sooner for patched clients

- mature high-volume native bridges
- mature native snapshot feeds
- static-data paths that already moved to custom DBCs and revisioned native
  accessors

### Best-practice rule

Do not ask whether fallback should be removed globally.

Ask instead:

- is the feature already native-complete for patched clients
- does telemetry show the native path is stable
- is the remaining addon path only duplicating cost without product value
- would retaining fallback create long-term drift between two authorities

---

## Where The Biggest Performance Wins Are

### 1. Stop chunking bulky DC payloads through addon transport

This is the most obvious gain.

Benefits:

- fewer string splits and joins
- less chunk bookkeeping
- less reassembly timeout logic
- lower Lua garbage pressure
- lower server work for giant responses

### 2. Stop shipping static data at runtime

If a catalog changes rarely, it should not be serialized on demand through addon
messages every time a user opens a UI or logs in.

Benefits:

- dramatically smaller session startup payloads
- fewer cache misses during panel open
- less server CPU spent preparing repeated bulk JSON
- simpler version-based invalidation

### 3. Reduce Lua JSON usage for hot paths

JSON is convenient, but expensive when used repeatedly on high-frequency or
large-volume paths.

Benefits of native transport or typed payloads:

- less text expansion
- fewer temporary strings
- faster decode paths
- less Lua memory churn

### 4. Make the client compute more locally

If the client can already resolve a target, waypoint, ping receiver, projection,
or cached reference entry, the server should not be queried for that every time.

Benefits:

- fewer requests
- lower perceived latency
- more responsive UI
- cleaner separation between authoritative state and client presentation state

### 5. Use native revisioned caches

Many DC systems should become:

- cached locally
- invalidated by revision
- refetched only when needed

This is more scalable than re-requesting whole data blobs from Lua because a
frame opened or a tooltip refreshed.

### 6. Move high-cadence live feeds off addon protocol

Systems that update often suffer more from transport cadence than from raw size.

Examples:

- spectator state
- battleground state
- Mythic Plus timer or status feeds
- live party and raid navigation markers

These should be among the first candidates for native transport.

---

## Client Limitations That Can Be Raised Or Reworked

This section must be read carefully because not every raised limit improves
performance. Some improve visibility or capability while increasing render cost.

### Already supported in the current extension snapshot

#### View and environment limits

- extended farclip up to the patched maximum
- extended camera distance
- higher horizon farclip scale
- higher environment detail cap
- fog distance override

#### UI and visibility related limits

- extended nameplate distance

#### Texture and rendering controls

- texture quality helper values
- texture cache size tuning
- render flag helpers for specular, shadows, footprints, object fade, and LOD

#### Process memory ceiling improvement

- Large Address Aware patching is already part of the patcher flow

This is especially useful when a client build has:

- larger UI packages
- more custom data
- heavier custom maps or assets
- broader cached addon state

### What these limits are good for

#### Good uses

- creating DC-defined QoS profiles
- improving readability for navigation and open-world systems
- making large custom zones feel less claustrophobic
- improving target visibility or UI context in group content

#### Misuses to avoid

- enabling maximum values globally for all users regardless of hardware
- assuming a visual increase automatically equals a performance improvement
- pushing more render distance while ignoring world clutter and object count

Recommended interpretation:

These are **profile tools**, not universal defaults.

---

## Suggested DC Graphics and QoS Profile Model

Rather than applying raw values ad hoc, define named profiles.

Examples:

#### `DC_PROFILE_SAFE`

- conservative farclip
- normal camera distance
- standard environment detail
- shorter nameplate distance
- reduced texture cache footprint

#### `DC_PROFILE_WORLD`

- extended farclip
- extended camera distance
- slightly increased horizon scale
- moderate nameplate distance

#### `DC_PROFILE_RAID`

- practical nameplate distance
- lower world clutter where helpful
- stable camera distance
- conservative fog behavior

#### `DC_PROFILE_BATTLEGROUND`

- stronger nameplate distance
- visibility-friendly fog settings
- tuned camera distance
- performance-minded environment detail

#### `DC_PROFILE_SHOWCASE`

- high visual settings for exploration, showcases, and content capture

The key point is this:

`WotLK-Extensions` allows Dark Chaos to manage these profiles as part of a real
client-runtime strategy instead of leaving them to disconnected user tweaks.

---

## Best Migration Candidates

### Tier 1: First moves

#### 1. Spell tooltip enrichment

Why first:

- native path already partly exists
- clear request/response model
- easy to measure latency improvement
- low blast radius compared to larger systems

Expected gains:

- lower addon-transport usage
- lower timeout sensitivity
- cleaner stale-response handling

#### 2. Generic DC native packet bridge

Why second:

- unlocks almost every later optimization
- avoids one-off protocol growth
- creates a stable transport abstraction

### Tier 2: High-value next wave

#### 3. QoS and graphics profile application

Why:

- immediate user-facing value
- low conceptual risk
- uses already available extension capabilities

#### 4. Breaking news and pre-login notices

Why:

- already aligned with current extension direction
- improves the overall platform feel
- makes DC feel more like a complete product rather than only a world-session
  addon stack

### Tier 3: Biggest data-volume wins

#### 5. Collection and wardrobe static-data migration

Why:

- likely the best way to kill repeated large runtime syncs
- better long-term than endlessly tuning JSON and chunk limits

#### 6. Mythic Plus, spectator, and HLBG live state

Why:

- these are strong candidates for compact typed packets
- they benefit heavily from lower latency and lower update overhead

### Tier 4: Broader runtime platform work

#### 7. Native caches and invalidation framework

#### 8. Richer navigation, map, and overlay services

#### 9. Additional client-local helper APIs for complex DC UIs

---

## Systems That Should Likely Stay On Addon Protocol

Not everything needs native transport.

Good candidates to remain on addon protocol:

- lightweight settings sync
- one-off debug tools
- low-frequency administrative messages
- compatibility paths for users without the patched client
- feature requests where implementation cost outweighs performance benefit

This matters because the best architecture is not "everything native." It is
"the right layer for the right workload."

---

## Proposed Native Packet Model

The best next step is likely not dozens of feature-specific opcodes. It is a
small Dark Chaos transport envelope carried over custom opcodes.

### Suggested concept

#### Session/control opcodes

- `CMSG_DC_HELLO`
- `SMSG_DC_HELLO_ACK`
- `CMSG_DC_CAPS`
- `SMSG_DC_CAPS_ACK`

#### Data opcodes

- `CMSG_DC_REQUEST`
- `SMSG_DC_RESPONSE`
- `SMSG_DC_PUSH`
- `SMSG_DC_INVALIDATE`
- `SMSG_DC_BULK`
- `SMSG_DC_ERROR`

#### Optional telemetry or debug opcodes

- `CMSG_DC_DIAGNOSTICS`
- `SMSG_DC_DIAGNOSTICS`

### Suggested envelope fields

- protocol version
- feature mask
- module id
- opcode id
- request id
- flags
- payload kind
- revision
- payload length
- payload bytes

### Suggested payload kinds

- typed binary payload
- compact key/value payload
- JSON payload for transitional cases
- compressed blob for large bulk sync

Recommendation:

Use JSON only where it keeps iteration speed high and the cost is acceptable.
Do not make JSON the default forever for a native transport layer.

---

## Suggested Feature Flag Model

At minimum, define compile-time and runtime gates.

### Compile-time gate

Example:

- `DC_NATIVE_MODULE`

### Runtime capability bits

Examples:

- `DC_CAP_NATIVE_PROTOCOL`
- `DC_CAP_TOOLTIP_NATIVE`
- `DC_CAP_BREAKING_NEWS`
- `DC_CAP_GLUE`
- `DC_CAP_GRAPHICS_PROFILES`
- `DC_CAP_NATIVE_CACHE`
- `DC_CAP_CUSTOM_DBC_DATA`

The server should not assume that every patched client exposes every feature.

---

## Server-Side Companion Work Required

The client module alone is not enough. A clean server companion is required.

Recommended server responsibilities:

- capability negotiation during session initialization
- routing heavy features to native transport when supported
- preserving addon fallback behavior
- revision tracking for cached feature sets
- invalidation events instead of repeated full re-syncs
- telemetry split by transport type

Good implementation direction on the server side:

- keep `dc_addon_protocol.cpp` as the compatibility and control anchor
- add a transport abstraction above concrete wire format
- let feature modules request `best available transport` rather than hardcoding
  addon chat everywhere

That keeps future migrations from becoming copy-paste transport forks.

---

## Caching Strategy Recommendations

Caching is one of the biggest opportunities unlocked by a native client module.

### What should be cached natively

- tooltip enrichment results keyed by request context and revision
- collection and wardrobe metadata keyed by revision
- map overlay or hotspot metadata keyed by map and revision
- Mythic Plus static descriptors keyed by season or ruleset revision
- breaking news payload and applied revision state

### Cache design rules

- always attach revisions where feasible
- support invalidation packets
- avoid unbounded native caches
- distinguish static reference data from session state
- prefer coarse cache invalidation over overcomplicated fine-grained mutation on
  first implementation

### What should remain dynamic

- live match state
- rapidly changing timers
- group state and transient navigation cues
- per-session diagnostics

---

## Custom DBC Distribution And Stale-Client Fallback Model

This section clarifies an important boundary:

**Custom DBCs should be treated as versioned client content, not as a transport
that is silently replaced at runtime.**

That does not mean there is no fallback story. It means the fallback story must
be designed per feature.

### How the current custom DBC loader works

In the current `WotLK-Extensions` implementation, custom DBCs are loaded from
`DBFilesClient` during client DBC registration at startup.

Practical implications:

- the files are expected to exist locally in the client data set
- file signature and row layout must match what the loader expects
- missing files or schema mismatches are fatal for enabled custom DBC features
- this is a packaged-content path, not a built-in live hot-update channel

So the primary model should be:

1. build or export the custom DBCs
2. package them with the client patch bundle
3. patch and ship the updated client build
4. let the extension load them at startup

### Collection shop loader shape

The current collection static offload already maps well to three custom DBCs:

- `DCCollectionCategory.cdbc` -> `GetDCCollectionCategories()`
- `DCCollectionSource.cdbc` -> `GetDCCollectionSources()`
- `DCCollectionSet.cdbc` -> `GetDCCollectionSets()`

To remove addon-bundled `ShopStatic.lua` from the steady-state path, add a
fourth file dedicated to shop metadata rather than trying to overload
`DCCollectionSource`:

- `DCCollectionShop.cdbc` -> `GetDCCollectionShop()`

Recommended native row contract:

- struct name: `DCCollectionShopRow`
- first field: `m_ID` as the authoritative `shopId`
- integer fields:
  - `m_collectionType`
  - `m_entryID`
  - `m_itemID`
  - `m_spellID`
  - `m_appearanceID`
  - `m_displayID`
  - `m_creatureID`
  - `m_mountType`
  - `m_rarity`
  - `m_priceTokens`
  - `m_priceEmblems`
  - `m_discountPercent`
  - `m_featured`
  - `m_enabled`
  - `m_stockRemaining`
- string fields:
  - `m_availableFrom`
  - `m_availableUntil`
  - `m_name`
  - `m_icon`
  - `m_sourceType`
  - `m_sourceName`
  - `m_sourceText`

`collectionTypeName` does not need to be stored redundantly in the CDBC row.
The Lua bridge can derive it from `m_collectionType` and still expose the same
addon-facing key that the generated Lua file uses today.

Recommended Lua return shape for `GetDCCollectionShop()`:

```lua
{
    shopId = row.m_ID,
    collectionType = row.m_collectionType,
    collectionTypeName = "mount" | "pet" | "heirloom" | "title" | "transmog",
    entryId = row.m_entryID,
    itemId = row.m_itemID,
    spellId = row.m_spellID,
    appearanceId = row.m_appearanceID,
    displayId = row.m_displayID,
    creatureId = row.m_creatureID,
    mountType = row.m_mountType,
    rarity = row.m_rarity,
    priceTokens = row.m_priceTokens,
    priceEmblems = row.m_priceEmblems,
    discount = row.m_discountPercent,
    featured = row.m_featured,
    enabled = row.m_enabled,
    stock = row.m_stockRemaining,
    availableFrom = row.m_availableFrom,
    availableUntil = row.m_availableUntil,
    name = row.m_name,
    icon = row.m_icon,
    sourceType = row.m_sourceType,
    sourceName = row.m_sourceName,
    sourceText = row.m_sourceText,
}
```

That shape is intentionally aligned with the existing generated
`ShopStatic.lua` rows so the addon can prefer `GetDCCollectionShop()` when the
export exists and fall back to bundled Lua only for older patch builds.

Expected touch points inside `WotLK-Extensions`:

- `src/Data/Structs.hpp`: add `DCCollectionShopRow`
- `src/CDBCMgr/CDBCDefs/DCCollectionShop.hpp/.cpp`: loader class and row fixup
- the central DC/custom-DBC manager: register the new table and expose
  `GetDCCollectionShopRows()`
- `src/Client/CustomLua.hpp/.cpp`: declare, implement, and register
  `GetDCCollectionShop()`

Once that exists, the addon-side shop authority switch can treat native shop
rows exactly like the current generated Lua data and stop bundling the large
shop metadata table inside the addon package.

### Collection transmog loader shape

Wardrobe appearance definitions are the next large static catalog that should
stop flowing over addon transport.

The authoritative server variant model already derives from `item_template`
using the key `(displayId, inventoryType, class, subclass)`. That means the
client patch can load the same generated catalog from a dedicated custom DBC:

- `DCCollectionTransmog.cdbc` -> `GetDCCollectionTransmog()`

Recommended native row contract:

- struct name: `DCCollectionTransmogRow`
- first field: `m_ID` as a stable row id for reload/debug purposes
- integer fields:
  - `m_displayID`
  - `m_inventoryType`
  - `m_itemClass`
  - `m_itemSubClass`
  - `m_visualSlot`
  - `m_canonicalItemID`
  - `m_rarity`
  - `m_itemLevel`
  - `m_itemIDsTotal`
- string fields:
  - `m_name`
  - `m_icon`
  - `m_itemIDs`

Recommended Lua return shape for `GetDCCollectionTransmog()`:

```lua
{
    id = row.m_ID,
    displayId = row.m_displayID,
    inventoryType = row.m_inventoryType,
    class = row.m_itemClass,
    subclass = row.m_itemSubClass,
    visualSlot = row.m_visualSlot,
    itemId = row.m_canonicalItemID,
    canonicalItemId = row.m_canonicalItemID,
    rarity = row.m_rarity,
    itemLevel = row.m_itemLevel,
    name = row.m_name,
    icon = row.m_icon,
    itemIdsTotal = row.m_itemIDsTotal,
    itemIds = row.m_itemIDs,
}
```

The addon should rebuild the variant key locally from
`displayId:inventoryType:class:subclass` and treat the export as authoritative
definition data. Only owned-state, favorites, outfits, and other player state
should remain dynamic.

Expected touch points inside `WotLK-Extensions`:

- `src/Data/Structs.hpp`: add `DCCollectionTransmogRow`
- `src/CDBCMgr/CDBCDefs/DCCollectionTransmog.hpp/.cpp`: loader class and row
  fixup
- the central DC/custom-DBC manager: register the new table and expose
  `GetDCCollectionTransmogRows()`
- `src/Client/CustomLua.hpp/.cpp`: declare, implement, and register
  `GetDCCollectionTransmog()`

With that path in place, transmog definitions can become patch-native and the
runtime addon protocol no longer needs to page the full wardrobe catalog.

### What SQL can and cannot do here

SQL can absolutely be a canonical authoring or export source.

Examples:

- a world table can be the source of truth for generating a custom DBC export
- internal tools can diff SQL-backed content and regenerate `.cdbc` files
- the server can store per-revision metadata for what DBC package the client is
  expected to have

But SQL does **not** automatically patch the client's DBC state.

Important distinction:

- server-side `_dbc` SQL tables in AzerothCore load data into **server memory**
  and can override or add server-side DBC entries there
- they do not magically push entries into the client's native DBC tables
- the stock client and the current `WotLK-Extensions` custom DBC loader do not
  have a generic "download row from SQL and inject into DBC table at runtime"
  mechanism

So if by "SQL fallback" the idea is "the client is missing a DBC row, so the
server sends that SQL row and the client pretends the DBC was updated", that is
**not a general existing behavior**.

### The correct fallback model

There should be two distinct classes of custom DBC-backed systems.

#### Class A: hard client-content dependencies

These are systems where the client executable or patched native code expects the
DBC file to exist and uses it as part of native logic.

Examples:

- dehardcoded role tables
- zone light polygon data
- occlusion volume data
- extended spell-attribute data used by patched native consumers

For these systems, the correct policy is:

- require the correct client DBC package
- detect revision mismatch early
- disable the feature or reject the client cleanly if the required revision is
  missing

Do **not** try to hide stale content here with an improvised runtime row sync.

#### Class B: DC-owned presentation or reference data

These are systems where the client can be explicitly taught to consume either:

- packaged DBC data when available
- or a runtime native cache populated from the server when the packaged data is
  stale or absent

Examples:

- wardrobe reference metadata for DC-owned UIs
- collection catalogs
- map overlay descriptors used only by DC systems
- teleport catalogs
- other large reference tables used by Lua or DC-native UI helpers rather than
  by untouched stock client systems

For these systems, a runtime fallback is realistic.

### How a real runtime fallback should work

The server should not send raw SQL to the client.

Instead:

- SQL or another authoring source remains on the server side
- the server exports or serializes the needed rows into a transport-friendly
  format
- the DC native packet bridge sends either a revision delta or a compact bulk
  payload
- the client extension stores the result in a native cache
- Lua or patched DC-native helpers read from that cache when the packaged DBC
  revision is missing or outdated

This is effectively a **runtime cache fallback**, not literal SQL transfer.

### Recommended revision model

Each custom DBC-backed DC feature should have:

- a `requiredRevision`
- an `installedRevision`
- a `fallbackAllowed` flag
- a `fallbackSource` policy

Example policies:

- `required-client-update`
- `allow-runtime-cache-fallback`
- `disable-feature-on-mismatch`

### Suggested handshake flow

At session start:

1. client reports extension build fingerprint and installed DC data revisions
2. server compares them against required revisions
3. for each feature, server chooses one of:
   - native DBC path is valid
   - runtime fallback cache may be used
   - feature must be disabled
4. server publishes the effective feature mask to the client

### Recommended runtime states

For each feature:

- `OK_NATIVE_DBC`
- `OK_RUNTIME_CACHE`
- `DISABLED_STALE_CLIENT_DATA`
- `DISABLED_UNSUPPORTED_CLIENT`

That makes diagnostics and support much easier.

### When fallback is a good idea

Runtime fallback is a good idea when all of the following are true:

- the feature is mostly DC-owned
- the UI does not rely on untouched stock DBC consumers
- the data is read-heavy and changes occasionally
- a stale packaged client should still get a degraded but usable experience

### When fallback is a bad idea

Runtime fallback is a bad idea when:

- the client executable expects the DBC file during startup patch logic
- the data feeds patched native paths that do not consult a runtime cache
- behavior must exactly match a specific client content revision
- silent mismatch could corrupt rendering or gameplay-facing interpretation

### Best-practice recommendation

Use this three-tier model:

1. **Primary:** packaged custom DBCs for required native content
2. **Secondary:** runtime native-cache fallback for DC-owned reference data
3. **Last resort:** disable the feature rather than guessing when required
   client content is missing

### Practical conclusion

Yes, you can design a stale-client fallback for some custom DBC-backed systems.
But the fallback should not be thought of as "push SQL to the client".

It should be thought of as:

- version check
- capability decision
- optional runtime data sync into a DC-managed native cache
- explicit disable for truly required client-content mismatches

That is the safe way to combine custom DBCs with graceful degradation.

---

## Operational Benefits Beyond Raw Performance

This project is not only about faster transport.

It also improves handling quality.

Examples:

- clearer capability detection
- more predictable UX for large UIs
- less fragility around giant payload timing
- less dependence on addon chat semantics for non-chat systems
- better staging for premium-feeling client features
- cleaner separation between fallback compatibility and first-class features

---

## Risks And Tradeoffs

### 1. Patched client distribution and support burden

A native client module increases operational responsibility.

Costs:

- packaging
- version skew management
- support for mismatched client and server builds
- patcher rollout discipline

### 2. Multiple transport paths increase complexity

During migration there will be at least two paths:

- addon fallback
- native transport

That requires:

- careful capability gating
- good telemetry
- explicit fallback policy

### 3. Not every raised limit is a performance improvement

Some settings improve experience while increasing render load.

This is why profile-based application is better than blanket max-value defaults.

### 4. Content pipeline work for DBC migration is real

Moving static catalogs to DBCs is strategically excellent, but it is not free.

It requires:

- schema planning
- export pipeline work
- content revision handling
- client packaging discipline

---

## Recommended Rollout Plan

### Phase 0: Prepare the architecture

- define DC feature flag in `WotLK-Extensions`
- add DC source subtree in the client patch repo
- define native capability bits
- define server transport abstraction goals

### Phase 1: First pilot

- enable a Dark Chaos native packet bridge
- migrate spell tooltip enrichment first
- measure latency, timeout rate, and server transport reduction

Success criteria:

- stable request/response behavior
- lower timeout incidence than addon path
- clear fallback behavior when native path is unavailable

### Phase 2: Immediate product-visible wins

- add DC graphics and QoS profile APIs
- formalize breaking-news and pre-login notices
- expose stable capability and diagnostics APIs to Lua

### Phase 3: Biggest transport savings

- migrate static catalogs to custom DBCs where justified
- move bulky collection and wardrobe data away from runtime sync

### Phase 4: High-cadence runtime migrations

- Mythic Plus live state
- spectator feeds
- HLBG live overlays
- navigation and ping relay improvements

### Phase 5: Mature hybrid platform

- revision-driven invalidation everywhere it matters
- native caches for repeated lookups
- a disciplined separation between control plane, data plane, and static data

---

## Practical Implementation Start

The best practical starting point is not full generic transport and not custom
DBC migration.

It is one narrow vertical slice plus two infrastructure prerequisites that are
already implied by the current repo state.

### Infrastructure prerequisite 1: session-scoped capability state

On the current server side, handshake negotiation already exists in
`dc_addon_protocol.cpp`, but negotiated capabilities are only acknowledged and
stored to `dc_addon_client_caps`.

The next implementation step on the server should be an in-memory per-session
capability registry that feature handlers can query directly.

Without that, no feature can safely choose between:

- addon fallback
- native custom packet path
- disabled state

### Infrastructure prerequisite 2: inbound custom opcode registration

The current AzerothCore server opcode table ends at `NUM_MSG_TYPES = 0x51F`,
and `WorldSocket` rejects client opcodes outside `NUM_OPCODE_HANDLERS` before
script receive hooks run.

That means outbound native packets already work today, but inbound native
`CMSG_*` packets require core-level opcode registration or another explicit
receive bridge first.

This is why the implementation order matters.

### First end-to-end pilot: native spell tooltip enrichment

Once inbound opcode handling exists, spell tooltip enrichment is still the best
first full pilot because:

- the server handler already exists in `dc_addon_qos.cpp`
- bridge opcode ids are already reserved there (`1313` and `1314`)
- addon fallback already exists
- latency and timeout improvements are easy to measure
- the feature is request/response shaped but still low blast radius

Recommended server steps:

1. Keep `HandleRequestSpellTooltipEnrichment()` as the single feature entry
  point.
2. Add a small transport selector so that native-capable clients receive opcode
  `1314`, while other clients keep the current addon JSON response.
3. Add an inbound native request path for opcode `1313` that feeds the same
  tooltip handler logic instead of duplicating feature behavior.
4. Instrument both paths so timeout rate, latency, payload size, and handler
  failures can be compared before broader rollout.

### Safest bootstrap if native `CMSG_*` support is not ready yet

If the server-side custom receive path is not ready yet, use a push-only native
slice first.

Good bootstrap candidates:

- breaking news
- QoS profile pushes
- pre-login notices

The current repo already proves the outbound custom-packet path through the
breaking-news implementation, so this is the lowest-risk way to validate the
new client module wiring before adding custom inbound opcode handling.

### Recommended source starting points

In the current server repo:

- `src/server/scripts/DC/AddonExtension/dc_addon_protocol.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_qos.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_breaking_news.cpp`
- `src/server/game/Server/Protocol/Opcodes.h`
- `src/server/game/Server/WorldSocket.cpp`

In `WotLK-Extensions`:

- `Main::Init()` for DC module bootstrap
- `CNetClient::SetCustomHandlers()` for native opcode registration
- `CustomLua::Apply()` for Lua-facing DC APIs
- glue hooks only after the world-session path is stable

---

## Concrete Recommendation Summary

### Recommended architectural decision

Create a dedicated Dark Chaos module inside `WotLK-Extensions`.

### Recommended transport strategy

- keep `DC-AddonProtocol` as fallback and control plane
- move heavy and high-frequency workloads to native custom packets
- move stable bulk data to custom DBCs

### Recommended first pilot

Native spell tooltip enrichment.

### Recommended second foundational step

Generic DC native packet bridge with capability negotiation.

### Recommended high-impact follow-up

- DC graphics and QoS profiles
- breaking news and glue-side messaging
- collection and wardrobe data offload
- native live-state channels for Mythic Plus, spectator, and HLBG

---

## Final Assessment

If Dark Chaos wants significantly better performance and handling for its addon
ecosystem, the best opportunity is not simply raising more addon-channel limits.

The biggest opportunity is to use `WotLK-Extensions` as a **second client
runtime layer**:

- native packets for heavy data
- native helpers for client-local logic
- custom DBCs for static catalogs
- glue hooks for pre-world UX
- profile-driven client tuning for QoS and visibility

That turns the current system from an increasingly stressed addon transport into
a real hybrid client platform.

That is where the massive improvement potential is.