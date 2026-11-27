# Item Upgrade Native Tooltip Implementation Backlog

**Date:** May 23, 2026  
**Status:** Implementation backlog and packet design  
**Scope:** Turn the item-upgrade tooltip strategy into a concrete backlog with exact server/client file targets, concrete packet changes, cache design, and rollout order.

---

## Current Delta

The first high-ROI server-side cleanup is already done in the current repo state:

- `src/server/scripts/DC/AddonExtension/dc_addon_qos.cpp` no longer does direct hover SQL against `dc_item_upgrades` and `dc_item_upgrade_tiers`.
- The QoS item-upgrade tooltip paths now read through `UpgradeManager` state.
- `ItemUpgradeState` now tracks whether the state came from a persisted upgrade row.
- `worldserver` builds successfully in `RelWithDebInfo` after that change.

This means the next steps should focus on:

1. promoting that snapshot logic into a first-class manager/service API,
2. adding revisioned invalidation,
3. adding a versioned native tooltip replacement packet,
4. teaching `CGTooltip::SetItemEx` to replace stat rows.

---

## Primary Goal

Deliver a patched-client path where:

- stock item headers still render safely,
- upgraded stat lines replace the stock stat block,
- tooltip data is served from cached server snapshots,
- the client uses a bounded native cache,
- addon JSON fallback remains only for unpatched clients or native send failures.

---

## Backlog Order

## Phase 1: Server Snapshot API

### Outcome

Move the current ad hoc snapshot building into `UpgradeManager` so tooltip producers do not duplicate item-upgrade projection logic.

### Exact file targets

- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_qos.cpp`

### Changes

Add a first-class snapshot type to the manager layer, for example:

```cpp
struct ItemUpgradeTooltipSnapshot
{
    uint32 itemGuid = 0;
    uint32 itemEntry = 0;
    uint32 baseEntry = 0;
    uint32 currentEntry = 0;
    uint32 tierId = 0;
    uint32 upgradeLevel = 0;
    uint32 maxUpgrade = 0;
    uint32 statMultiplierBasisPoints = 10000;
    uint32 baseIlvl = 0;
    uint32 upgradedIlvl = 0;
    uint32 revision = 0;
    bool hasPersistedState = false;
    bool canUpgrade = false;
};
```

Add manager API such as:

```cpp
virtual bool BuildTooltipSnapshot(Item* item,
    ItemUpgradeTooltipSnapshot& out) = 0;
```

Then simplify `dc_addon_qos.cpp` to call the manager API instead of owning its own projection rules.

### Notes

- No DB schema change is required for this phase.
- Keep the current `SMSG_ITEM_UPGRADE_TOOLTIP` packet shape unchanged in phase 1.

---

## Phase 2: Revisioned Invalidation

### Outcome

Make tooltip snapshots invalidation-driven instead of hover-query-driven.

### Exact file targets

- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_upgrade.cpp`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeExchangeImpl.cpp`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAdvancedImpl.cpp`

### Changes

Add runtime-only revision tracking in the manager, for example:

```cpp
std::unordered_map<uint32, uint32> tooltip_revision_by_item;
LRUCache<uint32, ItemUpgradeTooltipSnapshot> tooltip_snapshot_cache{20000};
```

Add manager APIs such as:

```cpp
virtual uint32 GetTooltipRevision(uint32 item_guid) = 0;
virtual void InvalidateTooltipSnapshot(uint32 item_guid) = 0;
```

### Invalidate on these events

- successful upgrade
- any direct upgrade-level mutation
- token/stat multiplier mutation that changes displayed values
- clone-to-base migration work in future dynamic upgrade rollout
- item destruction or item GUID handoff paths

### Recommended rule

If a code path mutates one of these fields, it must invalidate the tooltip snapshot:

- `tier_id`
- `upgrade_level`
- `stat_multiplier`
- `base_item_level`
- `upgraded_item_level`
- `item_entry`

### Notes

- Keep revisions runtime-only first.
- Do not add a DB column for `revision` unless cross-restart persistence becomes necessary later.

---

## Phase 3: New Native Packet Pair For Full Tooltip Replacement

### Outcome

Introduce a v2 item-tooltip packet instead of mutating the current v1 metadata packet.

### Why additive instead of in-place mutation?

The current `1316/1317` bridge is already consumed by Lua and native compatibility code. A versioned packet avoids breaking that lane while the native `SetItemEx` replacement path is being developed.

### Exact server file targets

- `src/server/game/Server/Protocol/Opcodes.h`
- `src/server/game/Server/Protocol/Opcodes.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_namespace.h`
- `src/server/scripts/DC/AddonExtension/dc_addon_protocol.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_qos.cpp`

### Exact client file targets in external repo

- `WotLKExtensions/src/Data/Enums.hpp`
- `WotLKExtensions/src/Client/CNetClient.hpp`
- `WotLKExtensions/src/Client/CNetClient.cpp`
- `WotLKExtensions/src/Client/CustomLua.hpp`
- `WotLKExtensions/src/Client/CustomLua.cpp`
- `WotLKExtensions/src/Client/CGTooltip.hpp`
- `WotLKExtensions/src/Client/CGTooltip.cpp`

### New capability bit

Add a separate negotiated capability for the full replacement path instead of reusing `ITEM_UPGRADE_NATIVE`:

```cpp
constexpr uint32 ITEM_TOOLTIP_REPLACEMENT_NATIVE = 0x00200000;
```

`0x00100000` is already occupied in the current server tree by the generic
native envelope capability, so the tooltip-replacement capability must use the
next free bit.

This allows:

- old patched clients to keep using the current metadata bridge,
- new patched clients to opt into full stat-line replacement.

### Proposed new opcode ids

The original draft assumed `1334/1335`, but the live server tree already uses
`0x536` / `1334` for `SMSG_DC_NATIVE_ENVELOPE`.

Use the next free pair in the current server range:

- `CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT = 1335` / `0x537`
- `SMSG_ITEM_TOOLTIP_SNAPSHOT = 1336` / `0x538`

### Request packet format

Recommended request fields:

```text
int32 requestId
int32 itemGuidLow
int32 knownRevision
int32 itemEntry
int32 contextHash
int8  contextKind
int8  bag
int8  slot
int8  flags
```

### Request field notes

- `requestId`: correlation and stale-response rejection
- `itemGuidLow`: authoritative item-instance identity for owned/visible items
- `knownRevision`: lets the server answer `NOT_MODIFIED`
- `itemEntry`: sanity/diagnostic hint only
- `contextHash`: compare-context disambiguation if needed later
- `contextKind`: bag, equipped, compare, inspect, trade, mail, link
- `bag/slot`: compatibility routing hints for owner inventory and current UI refresh
- `flags`: future use such as `FORCE_REFRESH`, `WANT_DEBUG_ROWS`, `PREFER_TEXT_ROWS`

### Suggested `contextKind` values

```text
0 = bag
1 = equipped
2 = compare
3 = inspect
4 = trade
5 = mail
6 = link
```

### Response packet format

Recommended response fields:

```text
int32 requestId
int32 itemGuidLow
int32 revision
int32 status
int32 itemEntry
int32 baseEntry
int32 currentEntry
int32 tierId
int32 upgradeLevel
int32 maxUpgrade
int32 statMultiplierBasisPoints
int32 baseIlvl
int32 upgradedIlvl
int32 rowCount
repeat rowCount times:
  cstring left
  cstring right
  cstring kind
  cstring classification
cstring error
```

### Suggested status values

```text
0 = OK
1 = NOT_MODIFIED
2 = ITEM_NOT_FOUND
3 = NOT_VISIBLE
4 = UNSUPPORTED_CONTEXT
5 = SERVER_ERROR
```

### Why structured rows first?

For the first real `SetItemEx` replacement, structured rows are the best cost/benefit point:

- compact compared to JSON
- direct to render in native code
- avoids rebuilding a full text blob in Lua
- does not require a full typed stat engine in phase one

### Row meaning

- `kind`: `replace-stat`, `append-meta`, `separator`, `body`
- `classification`: `armor`, `stat`, `socket`, `proc`, `upgrade`, `warning`, `debug`

This is enough for the client to replace the stock stat section while still rendering custom meta rows below it.

---

## Phase 4: Native Client Cache Redesign

### Outcome

Stop caching by bag/slot only.

### Exact client file targets

- `WotLKExtensions/src/Client/CNetClient.hpp`
- `WotLKExtensions/src/Client/CNetClient.cpp`

### Changes

Replace the current slot cache with:

```cpp
struct ItemTooltipSnapshotCacheEntry
{
    uint32_t itemGuid = 0;
    uint32_t revision = 0;
    uint32_t itemEntry = 0;
    uint8_t contextKind = 0;
    std::vector<ItemTooltipLineData> rows;
    uint32_t receivedAtMs = 0;
};
```

Recommended primary key:

- `itemGuidLow`
- `revision`
- `contextKind`

Recommended alias map:

- `bag/slot -> itemGuidLow`

Recommended cache policy:

- bounded LRU cache
- dedupe in-flight requests by primary key
- stale-response rejection by `requestId + itemGuid + revision`
- TTL only as cleanup, not as correctness

---

## Phase 5: `CGTooltip::SetItemEx` Stat-Line Replacement

### Outcome

Replace the stock stat block in native code while preserving safe fallback behavior.

### Exact client file targets

- `WotLKExtensions/src/Client/CGTooltip.hpp`
- `WotLKExtensions/src/Client/CGTooltip.cpp`

### Implementation shape

1. Keep the hook at `SetItemEx`.
2. Let the stock tooltip populate first.
3. Resolve active item identity from tooltip context.
4. Look for a valid cached v2 snapshot.
5. If present, remove or suppress the stock replaceable stat rows.
6. Inject `replace-stat` rows in native code.
7. Inject `append-meta` rows after the stat block.
8. If no valid snapshot exists, keep the stock tooltip and optionally issue one request.

### Important rule

Do not block tooltip rendering while waiting for the packet.

The v2 path should always fail open to the stock tooltip.

### Recommended first scope

Replace only these rows first:

- primary stat rows
- secondary stat rows
- armor / weapon damage rows
- upgraded item level row

Keep these stock initially:

- name and quality header
- flavor text
- equip/use/proc text body
- gem/socket art handling
- compare shell behavior

That gives the biggest visible win with the lowest native risk.

---

## Phase 6: Addon/Lua Cleanup

### Outcome

Reduce Lua to fallback, telemetry, and compatibility.

### Exact file targets

- `Custom/Client addons needed/DC-QOS/Modules/Tooltips.lua`
- `Custom/Client addons needed/DC-QOS/Protocol.lua`

### Changes

For negotiated v2 clients:

- stop treating the Lua upgrade cache as the main authority,
- stop appending duplicate stat summary lines when native replacement is active,
- keep only fallback request logic and diagnostics,
- keep bag/slot helpers only for old bridge compatibility.

---

## Packet Compatibility Plan

## Keep existing v1 bridge

Current v1 bridge remains:

- `1316/1317`
- capability `ITEM_UPGRADE_NATIVE`
- metadata only

## Add new v2 bridge

New v2 bridge:

- `1335/1336`
- capability `ITEM_TOOLTIP_REPLACEMENT_NATIVE`
- structured replacement rows

## Routing rule

For patched clients:

- if v2 capability negotiated, use v2
- else if v1 capability negotiated, use current metadata bridge
- else use addon JSON fallback

For unpatched clients:

- stay on addon fallback

---

## DB Schema Changes

## Required now

No new SQL schema is required for the next implementation step.

The current system can build tooltip snapshots from:

- `dc_item_upgrades`
- `dc_item_upgrade_tiers`
- item template data
- runtime manager state

## Optional later

Only consider DB schema changes if one of these becomes necessary:

- cross-restart tooltip revision persistence
- explicit audit rows for v2 tooltip transport
- precomputed static tooltip templates

Recommended default: keep revisions runtime-only first.

---

## Exact Validation Gates

## Gate 1: Server snapshot parity

- `dc_addon_qos.cpp` produces the same v1 fields as before
- no direct hover SQL remains in QoS item-upgrade handlers
- `worldserver` builds cleanly

## Gate 2: v2 packet transport

- custom opcodes register on both server and client
- request/response correlation works
- `NOT_MODIFIED` responses skip row payloads correctly

## Gate 3: native cache correctness

- repeated hovers do not resend duplicate requests unnecessarily
- moving the item invalidates alias mappings correctly
- stale responses do not repaint the wrong tooltip

## Gate 4: `SetItemEx` replacement

- stock tooltip still appears on cold miss or timeout
- upgraded stat rows replace stock stat rows when snapshot is present
- compare tooltip and equipped tooltip remain stable

## Gate 5: fallback cleanup

- patched clients on v2 do not append duplicate Lua stat lines
- unpatched clients still receive the old addon path

---

## Recommended Immediate Next Coding Step

The best next implementation step after the already-landed hover SQL removal is:

1. promote the local QoS snapshot helper into `UpgradeManager`,
2. add revision + invalidation APIs there,
3. keep serving the current `1317` packet until the v2 packet pair is ready.

That keeps the current improvement intact while preparing the right server boundary for `SetItemEx` replacement.

---

## Final Recommendation

Treat the current v1 native item-upgrade bridge as a bootstrap layer.

Do not mutate it into the final protocol.

The clean implementation path is:

1. manager-backed snapshots,
2. revisioned invalidation,
3. v2 structured snapshot packet,
4. bounded native cache,
5. native stat-line replacement in `CGTooltip::SetItemEx`,
6. Lua fallback cleanup.

That is the shortest path to a real full-tooltip replacement without creating another fragile hybrid authority.