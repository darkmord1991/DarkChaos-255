# Item Tooltip Replacement, Performance, and CDBC Strategy

**Date:** May 23, 2026  
**Status:** Architecture and performance investigation  
**Scope:** Determine how Dark Chaos should use custom DBCs, native tooltip bridges, caching, and server-side validation to support a high-performance item-upgrade tooltip system that can scale better with more players.

---

## Executive Summary

The best-performing design is **not** to push upgraded item stats into custom DBCs.

The best design is a three-lane model:

1. **Stock DBCs / stock client data** for normal item definitions and anything Blizzard already models well.
2. **Small custom `.cdbc` files** only for static Dark Chaos metadata that is shared by all clients and rarely changes.
3. **A negotiated native item-tooltip bridge** for per-item, per-instance, upgraded stat snapshots.

For the item-upgrade system specifically:

- custom DBCs are useful only for **static display metadata**, not for live upgraded stats,
- the current native item-upgrade bridge is only a **metadata bridge**, not a full tooltip replacement,
- the current server hover path still performs **SQL per request** in `dc_addon_qos.cpp`,
- the current client DLL cache is only a **bag/slot cache**, with no revisioning and no bounded eviction,
- and `CGTooltip::SetItemEx` in `WotLK-Extensions` is still a **pass-through**, so the client does not yet replace stock stat rows.

If the goal is to save resources as player count grows, the highest-return changes are:

1. stop doing per-hover SQL for item-upgrade tooltip requests,
2. stop keying the native bridge only by bag/slot,
3. move from hover-request-only flow to **revisioned cache plus invalidation/push**,
4. render the upgraded stat block in native client code instead of append-only Lua lines,
5. use custom CDBCs only for small static presentation metadata, not dynamic item state.

---

## Short Answer To The Main Questions

### What should be done with custom DBCs?

Use them for **static, shared, low-churn metadata**.

Do **not** use them for:

- per-player upgrade state,
- per-item instance upgraded stat values,
- rapidly changing tooltip payloads,
- session or hover traffic.

### What should be done for performance and client/server sync?

Use a **revisioned native tooltip snapshot cache** with server-side invalidation and client-side bounded caches.

### What is needed for a full blown item tooltip replacement?

`CGTooltip::SetItemEx` must stop being a pass-through and must gain a proper item-tooltip replacement pipeline that can render upgraded stat rows from a native packet cache.

### What is the best caching strategy?

Cache by **item GUID + revision + context**, not by bag/slot alone.

### What server checks matter most?

- ownership / visibility validation,
- capability negotiation validation,
- request rate limiting,
- stale-response protection,
- strict invalidation on any change that affects the item snapshot.

---

## Hard Findings From The Current Code

## 1. The current native item-upgrade bridge exists, but it is limited

The current server/client native bridge already exists end to end:

- server capability bit: `ITEM_UPGRADE_NATIVE`
- server native opcode: `SMSG_ITEM_UPGRADE_TOOLTIP`
- client packet handler in `CNetClient.cpp`
- Lua exports:
  - `RequestNativeItemUpgradeTooltip`
  - `GetNativeItemUpgradeTooltipData`

However, the current payload only carries scalar metadata:

- bag
- slot
- itemId
- tier
- upgradeLevel
- maxUpgrade
- statMultiplierBasisPoints
- baseEntry
- currentEntry
- baseIlvl
- upgradedIlvl
- error

That is enough to append informational lines, but it is **not** enough to replace the actual stat block in the tooltip.

## 2. `CGTooltip::SetItemEx` is still effectively stock behavior

`WotLKExtensions/src/Client/CGTooltip.cpp` does hook item tooltip call sites into `SetItemEx`, but `SetItemEx` immediately returns to the original stock client function.

That means:

- the hook point exists,
- but no item stat replacement logic is active,
- and the current tooltip enrichment remains append-style behavior from Lua rather than full replacement from native code.

This is the most important client-side finding.

## 3. The client DLL cache is too weak for a scalable solution

The current client runtime cache in `CNetClient.cpp` is:

- a plain `unordered_map<uint32_t, ItemUpgradeTooltipData>`
- keyed by `(bag << 16) | slot`
- with no TTL,
- no LRU bound,
- no revision field,
- no pending-request coalescing in the DLL,
- and no context dimension for compare/inspect/trade/mail/chat-link cases.

It is cleared on player initialization, but otherwise it is just a simple slot cache.

That is fine as a bridge bootstrap, but it is not the right long-term architecture.

## 4. The Lua tooltip layer already shows the correct direction for fallback behavior

`Custom/Client addons needed/DC-QOS/Modules/Tooltips.lua` already provides several useful ideas:

- pending request tracking,
- timeout recovery,
- TTL cache for upgrade metadata,
- native-first with addon fallback,
- active tooltip polling for native results,
- negotiation gating via capability bits.

That is good scaffolding.

But the current item-upgrade rendering still only adds lines such as:

- upgrade level,
- total stat bonus,
- upgraded item level,
- upgraded entry.

It does not replace the base stat lines.

## 5. The current server hover path is more expensive than it should be

`dc_addon_qos.cpp` currently queries the databases on hover for item-upgrade tooltip metadata:

- `SELECT tier_id, upgrade_level FROM dc_item_upgrades WHERE item_guid = ...`
- `SELECT max_upgrade_level, stat_multiplier_max FROM dc_item_upgrade_tiers WHERE tier_id = ...`

That means every cache miss can become live SQL work.

This is exactly the wrong place to spend database budget when many players are hovering items.

## 6. The upgrade manager already has the cache shape we should be reusing

The active upgrade manager already maintains runtime caches including:

- `item_state_cache`
- `tier_definitions`
- `item_to_tier`
- artifact and cost caches

So the tooltip path should reuse the manager instead of bypassing it with fresh SQL.

This is the single most immediate server-side performance improvement.

## 7. The existing custom DBC research already points in the right direction

The current `WOTLK_EXTENSIONS_CUSTOM_DBC_OPPORTUNITIES.md` research explicitly warns against using custom CDBCs for:

- rapidly changing live state,
- player-specific owned-state,
- session telemetry.

Per-item upgrade stats are exactly that kind of data.

So the correct answer is consistent with the existing research: **do not put live upgraded item state into CDBCs**.

---

## Where Custom DBCs Actually Help

## Good candidates

Custom CDBCs are good for static metadata that all clients can share and that changes only when the client patch changes.

For the item-upgrade / tooltip space, the best candidates are small helper tables such as:

### 1. `DCItemUpgradeTierVisual.cdbc`

Purpose:

- tier label
- tier color
- icon id / atlas key
- display priority
- optional tooltip header format key

Benefit:

- removes duplicated Lua constants,
- avoids shipping repeated string tables in addon code,
- gives the client a stable static presentation table.

### 2. `DCItemTooltipRule.cdbc`

Purpose:

- static presentation rules by item class / subclass / inventory type / quality
- section ordering flags
- whether to show upgrade section
- whether to show tier line / ilvl delta / source metadata

Benefit:

- centralizes static formatting policy,
- avoids hardcoding too many display rules in Lua.

### 3. `DCItemStatPresentation.cdbc`

Purpose:

- stat classification metadata
- ordering groups
- color/style policy
- optional “replace stock row vs append row” hints

Benefit:

- helps the native client renderer classify rows consistently,
- avoids locale-fragile Lua heuristics.

## What custom DBCs should not try to carry

Do not create CDBCs for:

- item GUID keyed upgrade snapshots,
- live upgraded stat numbers,
- bag/slot current state,
- compare-target-specific values,
- inspect-session item payloads,
- rolling tooltip cache snapshots.

Those belong in the native packet/runtime cache lane.

---

## Best Performance Strategy

The performance problem has two different layers.

## 1. Baseline memory / startup cost

This is dominated by the clone-based item footprint.

Existing investigation already showed:

- massive clone-range `item_template` counts,
- huge item-tier mapping loads,
- large proc association loads.

If the long-term goal is overall resource savings at scale, dynamic upgrades still matter because they eventually let you retire the clone-heavy content pipeline.

That is the **big baseline win**.

## 2. Per-player runtime tooltip traffic

This is dominated by:

- hover-triggered requests,
- repeated bag/slot requests,
- per-request SQL,
- duplicate client caching layers,
- addon JSON fallback traffic.

That is the **live session win**.

Both need to be addressed, but the runtime tooltip path is the one that most directly improves scalability when more players are online and actively using the UI.

---

## Recommended End-State Tooltip Architecture

## A. Split the system into static and dynamic lanes

### Static lane

Use:

- stock DBCs,
- optional small custom CDBCs,
- optional `ITEMMODEXT_PATCH` only for new static mod categories.

Store only:

- labels,
- icons,
- formatting rules,
- tier visuals,
- static display metadata.

### Dynamic lane

Use:

- negotiated native packets,
- client DLL cache,
- server snapshot cache,
- addon fallback only for unsupported clients or send failures.

Store:

- per-item upgraded stat rows,
- effective upgraded item level,
- current upgrade level,
- dynamic stat replacements,
- compare-context payloads if needed.

---

## B. Replace bag/slot identity with item GUID + revision

Bag/slot is not good enough for a full tooltip system because it breaks or becomes awkward for:

- compare tooltips,
- inspect tooltips,
- trade windows,
- mail,
- item references,
- moved/swapped items.

The correct primary identity is:

- `itemGuid`
- `entry`
- `revision`
- `contextKind`

Where:

- `itemGuid` identifies the actual item instance,
- `revision` changes whenever tooltip-relevant item state changes,
- `contextKind` distinguishes bag/equipment/inspect/trade/mail/link if needed.

Bag/slot can remain a temporary routing hint, but should not remain the real cache key.

---

## C. Move from scalar metadata to structured snapshot packets

The current item-upgrade native packet is too small.

The next packet should return a structured tooltip snapshot, for example:

- `requestId`
- `itemGuid`
- `entry`
- `revision`
- `contextKind`
- `status`
- `upgradeLevel`
- `maxUpgrade`
- `tier`
- `baseIlvl`
- `upgradedIlvl`
- `replaceStatRows[]`
- `appendRows[]`
- `flags`

Each row should look closer to the spell-tooltip structured line model:

- `left`
- `right`
- `kind`
- `classification`
- optional colors / style bits

This is the cleanest path because the spell-tooltip system already proved that structured rows work better than one big concatenated text blob.

---

## D. Let native client code own the final render

The tooltip replacement should happen in the client patch, not in a heavy Lua afterthought.

Best practical model:

1. intercept `CGTooltip::SetItemEx`,
2. let stock tooltip populate header/basic sections when appropriate,
3. identify the mutable stat section,
4. clear or suppress the stock stat rows,
5. inject server-provided upgraded stat rows from the native cache,
6. append upgrade metadata lines after the replaced stat block,
7. fail open to the stock tooltip if native data is missing.

This keeps the client fast and reduces Lua churn.

If needed, phase one can be a hybrid model:

- native code replaces only the stat block,
- stock client keeps name, quality, flavor, equip/use text,
- server snapshot supplies the upgraded numeric rows.

That is much safer than trying to rebuild the entire tooltip from scratch on day one.

---

## Best Caching Strategy

## 1. Server cache

### Canonical source

Use the `UpgradeManager` runtime state as the authoritative source.

Do **not** query SQL on normal hover requests.

### Add a dedicated tooltip snapshot cache

Recommended key:

- `itemGuid`
- `revision`
- optionally `contextKind`

Recommended contents:

- prebuilt structured rows
- upgraded ilvl
- upgrade level
- tier
- stat block replacement rows
- render flags

Recommended policy:

- bounded LRU cache
- revision invalidation, not time-based correctness
- optional short idle eviction for memory discipline

### Invalidate on these events

- item upgraded
- item downgrade / refund if supported
- enchant changed
- socket/gem changed
- permanent stat-affecting modifier changed
- clone migration to base item during future dynamic migration
- season/tier config reload affecting display values
- item destruction

### Optional prepush events

Push or precompute snapshots on:

- login for equipped items,
- equipment change,
- successful upgrade,
- inspect target open if that feature is added.

This reduces hover-time cold misses.

## 2. Client DLL cache

Replace the current slot cache with a bounded cache keyed by:

- `itemGuid`
- `revision`
- `contextKind`

Also keep a tiny alias map:

- `bag/slot -> itemGuid`

Recommended policy:

- LRU bound, for example 1000 to 4000 live snapshots
- no duplicate pending requests for the same key
- stale result rejection when the active tooltip no longer matches the same key
- optional TTL only as a safety cleanup, not as the correctness model

## 3. Lua fallback cache

Keep Lua caching only as a compatibility layer.

Once native tooltip replacement is stable, Lua should stop being the primary cache for upgraded items.

Lua should do only:

- capability checks,
- fallback requests,
- telemetry,
- light compatibility rendering for unpatched clients.

That will lower CPU churn in the tooltip module.

---

## Best Sync Strategy

## Current problem

The current pattern is mostly hover-driven:

- hover item
- request item-upgrade data
- wait for response
- append lines

That scales poorly when many players are active and repeatedly mouse over items.

## Better model

Use **revisioned sync**:

### On mutation

When the server changes an item in a tooltip-relevant way:

- increment snapshot revision,
- invalidate server cache entry,
- optionally push the fresh snapshot to the client immediately if the owner is online.

### On hover

Client does:

- check local native cache,
- if matching revision exists, render immediately,
- if missing, send one native request,
- dedupe repeated requests until response or timeout,
- fall open to stock tooltip.

### On login / inventory warmup

Optionally prefetch:

- equipped items,
- visible bag items after bag open,
- compare target items when a compare tooltip opens.

This gives the best user-perceived performance without spamming the server for every possible item.

---

## Server Checks And Safety Rules

## 1. Capability checks

Always verify:

- client advertised `ITEM_UPGRADE_NATIVE`
- capability was actually negotiated
- session is version-compatible

The repo already has transport-policy infrastructure for this. Keep using it.

## 2. Ownership / visibility checks

For item instance requests:

- player must own the item,
- or the item must be visible through a supported context such as inspect/trade/mail,
- or the request should be rejected.

Do not expose arbitrary item-instance snapshots by GUID with no visibility guard.

## 3. Stale-response checks

Responses should echo the identity key:

- `requestId`
- `itemGuid`
- `revision`
- `contextKind`

Client should only apply a response if the active tooltip still matches that same key.

## 4. Rate limiting

Use a lightweight token bucket or per-session short interval guard for native item-tooltip requests.

Goal:

- prevent hover spam from becoming packet spam,
- preserve responsiveness for real UI usage,
- avoid accidental floods during addon bugs.

## 5. Fail-open behavior

If native item snapshot is not available in time:

- show the stock tooltip,
- do not block hover,
- do not leave the user with an empty tooltip.

The spell-tooltip bridge already established the correct philosophy here.

---

## What To Do With `ITEMMODEXT_PATCH`

`ITEMMODEXT_PATCH` is useful, but it is not the main solution.

Use it only if Dark Chaos needs:

- new static item mod ids,
- new native labels for custom stat families,
- better built-in client formatting for new stat categories.

Do not treat it as a replacement for dynamic item tooltip snapshots.

It helps with **static interpretation**, not per-instance runtime values.

---

## Recommended Rollout Plan

## Phase 1: Immediate performance cleanup

High ROI, low risk.

1. Stop per-hover SQL in `dc_addon_qos.cpp` item-upgrade tooltip handlers.
2. Route those lookups through `UpgradeManager` and its caches.
3. Add server-side snapshot building and bounded cache.
4. Keep current append-only client behavior temporarily.

This alone reduces server load.

## Phase 2: Native snapshot redesign

1. Replace bag/slot-only payloads with GUID + revision snapshots.
2. Add structured line payloads.
3. Add bounded DLL cache with request dedupe.
4. Keep addon fallback for older clients.

This reduces sync chatter and stale-cache bugs.

## Phase 3: Full tooltip stat replacement

1. Implement active item stat-section replacement in `CGTooltip::SetItemEx`.
2. Inject upgraded stat rows from native cache.
3. Keep fail-open stock fallback.
4. Limit Lua to fallback and telemetry.

This is the real user-visible upgrade.

## Phase 4: Optional CDBC polish

Only after the runtime path is working:

1. add `DCItemUpgradeTierVisual.cdbc` if shared static metadata justifies it,
2. optionally add `DCItemTooltipRule.cdbc` / `DCItemStatPresentation.cdbc`,
3. keep them small and static.

This is polish, not the core solution.

## Phase 5: Dynamic item upgrade migration

If the broader dynamic upgrade migration proceeds:

1. keep base item identity,
2. use the new tooltip snapshot path as the display layer,
3. retire clone-driven tooltip expectations,
4. eventually retire clone-heavy data generation.

That gives the best long-term resource savings.

---

## Highest ROI Recommendations

If the goal is maximum benefit for minimum wasted work, do these in order:

### 1. Do not invest heavily in a big item-upgrade CDBC for live stats

It would solve the wrong problem.

### 2. Replace the current SQL hover path with manager-backed cached snapshots

This is the easiest immediate server win.

### 3. Redesign the native item-upgrade packet around GUID + revision + structured rows

This is the right transport contract for scale.

### 4. Implement native stat-block replacement in `CGTooltip::SetItemEx`

This is required for a true tooltip replacement.

### 5. Keep Lua as compatibility and telemetry, not the main renderer

That reduces client overhead and keeps the complex logic in one authoritative native path.

### 6. Use small custom CDBCs only for static presentation metadata

That is where custom DBCs actually help.

---

## Final Assessment

If Dark Chaos wants the most benefit from this work, the best design is:

- **dynamic runtime snapshots for upgraded item stats**
- **native client rendering for the tooltip stat block**
- **revisioned caches with invalidation**
- **very small custom CDBCs only for static display metadata**
- **no per-hover SQL**

That gives the best outcome across all three goals:

1. lower server cost under active player load,
2. lower client Lua churn and less addon transport noise,
3. a real full-blown tooltip replacement that shows upgraded values instead of only appending metadata.

---

## Notes

- This report is analysis only.
- No code changes were applied to the runtime systems while preparing it.
- No build or runtime tests were run for this document.