# Dynamic Item Upgrades Implementation Investigation

**Date:** May 16, 2026  
**Status:** Deep technical investigation, no code changes applied  
**Scope:** Assess the current DarkChaos item upgrade architecture and determine the effort, risks, migration path, and side effects of replacing the clone-based item identity model with a dynamic per-item upgrade model.

---

## Executive Summary

A fully dynamic item upgrade implementation is feasible in this codebase.

The most important finding is that the current system is already **hybrid**, not purely clone-driven:

- The core server-side upgrade runtime already stores upgrade progress per item GUID.
- Stat multipliers, upgraded item level, currency spending, and proc scaling already work from dynamic state.
- The remaining hard dependency on clones sits mostly in:
  - the standard addon upgrade request path,
  - the addon protocol payload shape,
  - client-visible item identity,
  - tooltip rendering,
  - and the clone generation / Item.csv pipeline.

That means the migration is **not** a rewrite of upgrade math. It is primarily a rewrite of **item identity presentation and transport**.

The highest-risk area is the client. The WotLK-Extensions client patch repository already contains:

- a hook point for item tooltips,
- an optional expanded item-mod table patch,
- and a complete spell tooltip enrichment example built on custom packets.

However, it does **not** already implement a dynamic item tooltip system. The current item tooltip hook is still a pass-through to the original client function. The spell tooltip enrichment path is the best template for how to implement dynamic item tooltip enrichment safely.

The item set question is also important: a dynamic model is the cleaner long-term answer for mixed upgraded sets. The current clone model cannot fit all set-upgraded variants into `ItemSet.dbc`, and the current standard upgrade flow destroys and recreates the item rather than mutating the equipped instance in place. A dynamic model removes that identity explosion and makes mixed-upgrade sets logically coherent.

---

## Short Answers

### Is a dynamic implementation technically possible?

Yes.

### Is the current runtime already partly dynamic?

Yes. The server-side upgrade state, stat scaling, item level scaling, currency handling, and proc scaling are already largely dynamic.

### Is the current system still materially clone-dependent?

Yes. The active standard upgrade flow, addon payloads, addon caches, tooltip handling, and data pipeline still depend on clones.

### Does WotLK-Extensions already solve the client side?

No. It provides the necessary insertion points and a proven spell-tooltip enrichment pattern, but item tooltip enrichment is not implemented yet.

### Would a dynamic implementation help with item sets?

Yes.

It is not a magic guarantee that every current item-set bug disappears instantly, but it removes the two structural problems the clone model introduces:

1. mixed upgrade variants do not fit cleanly into static `ItemSet.dbc` membership lists,
2. the current standard upgrade flow replaces the item entry instead of mutating the equipped item in place.

---

## Investigation Scope and Sources

The investigation covered four main surfaces:

### 1. Core server-side item upgrade runtime

Primary files reviewed:

- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeMechanicsImpl.cpp`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeStatApplication.cpp`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeProcScaling.cpp`

### 2. Addon extension bridge and protocol contract

Primary files reviewed:

- `src/server/scripts/DC/AddonExtension/dc_addon_upgrade.cpp`
- `src/server/scripts/DC/AddonExtension/dc_addon_namespace.h`
- `Custom/Client addons needed/DC-ItemUpgrade/Core.lua`
- `Custom/Client addons needed/DC-ItemUpgrade/DarkChaos_ItemUpgrade_Retail.lua`
- `Custom/Client addons needed/DC-QOS/Modules/Tooltips.lua`

### 3. Clone generation and client DBC/CSV pipeline

Primary files reviewed:

- `apps/item_upgrade/generate_upgrade_clones.py`
- `tools/update_item_csv.py`

### 4. WotLK-Extensions client patch repository

Primary files reviewed in the external client patch repo at `K:\Dark-Chaos\dc-wotlkextensions\WotLK-Extensions`:

- `WotLKExtensions/src/Client/CGTooltip.cpp`
- `WotLKExtensions/src/Client/Misc.cpp`
- `WotLKExtensions/src/Client/Misc.hpp`
- `WotLKExtensions/CMakeLists.txt`
- `Docs/README.md`

Additional investigation also included item set handling in AzerothCore core files:

- `src/server/game/Entities/Item/Item.cpp`
- `src/server/shared/DataStores/DBCStructure.h`
- `src/server/game/Globals/ObjectMgr.cpp`
- `src/server/game/Handlers/ItemHandler.cpp`

---

## Current Architecture: What Exists Today

## 1. Core Runtime State Is Already Dynamic

The current upgrade manager stores upgrade state by item GUID, not by clone entry.

Key current state model fields include:

- `item_guid`
- `player_guid`
- `item_entry`
- `tier_id`
- `upgrade_level`
- `tokens_invested`
- `essence_invested`
- `base_item_level`
- `upgraded_item_level`
- `stat_multiplier`
- `season`

Current backing table constants in the active code are:

- `dc_item_upgrades`
- `dc_item_upgrade_log`

Important implication:

The current runtime already knows how to represent an upgraded item as:

- one persistent item instance,
- plus upgrade metadata,
- plus derived stat and item-level values.

That is exactly the shape a dynamic implementation needs.

### What the manager already does dynamically

The manager already supports:

- loading tier definitions,
- loading upgrade cost matrices,
- loading item-to-tier mappings,
- persisting upgrade level per item,
- calculating stat multiplier per level,
- calculating upgraded item level,
- tracking invested currency,
- logging upgrade events,
- forcing a player stat refresh after changes.

The `UpgradeItem` path in the manager increments level and recalculates the state; it does not itself perform an item entry swap. That is a strong indicator that the clone dependency lives elsewhere.

---

## 2. Tier Resolution Is Hybrid, Not Fully Clone-Based

`GetItemTier(item_id)` works in three layers:

1. explicit mapping through `dc_item_templates_upgrade`,
2. clone lookup fallback through `dc_item_upgrade_clones`,
3. item-level-based fallback.

`LoadUpgradeData()` explicitly excludes clone-range entries from the in-memory `item_to_tier` cache and only loads base items there.

Important implication:

- clone entries are already treated as a compatibility layer in the manager,
- not as the authoritative definition of upgradeable content.

This is one of the strongest signals that a dynamic migration is realistic.

---

## 3. Proc Scaling Is Already Dynamic Enough To Keep

The proc scaling subsystem builds a spell-to-item registry from upgradeable **base** item entries only.

It does not treat clone items as the primary source of truth.

Important implication:

A dynamic migration does **not** need a major proc-scaling redesign. This is one of the lower-risk areas.

---

## 4. The Addon Bridge Is Still Clone-Shaped

The active addon bridge for upgrades is `dc_addon_upgrade.cpp`.

The upgrade opcodes currently include:

- `CMSG_GET_ITEM_INFO`
- `CMSG_DO_UPGRADE`
- `CMSG_LIST_UPGRADEABLE`
- `CMSG_GET_COSTS`
- heirloom-specific opcodes

Responses still expose clone-oriented fields such as:

- `baseEntry`
- `currentEntry`
- `cloneMap`
- `newEntry`

### Current item info behavior

For standard items, the bridge:

- checks whether the current entry is a clone,
- resolves the base entry,
- looks up upgrade state,
- rebuilds a `cloneMap` string for the client,
- returns both `baseEntry` and `currentEntry`.

Even the heirloom shirt special case, which does not use normal clones, still fabricates a `cloneMap` because the client currently expects it.

Important implication:

The current payload contract is clone-biased even when the runtime underneath is not.

---

## 5. The Standard Upgrade Flow Is Still a Clone Swap

This is the single biggest remaining server-side clone dependency.

The active standard upgrade request path in `dc_addon_upgrade.cpp`:

1. resolves the base entry from the current item,
2. computes the target level,
3. looks up the target clone in `dc_item_upgrade_clones`,
4. consumes currency,
5. destroys the current item,
6. stores a newly created clone item,
7. copies or rebuilds upgrade state for the new GUID,
8. returns success with `newEntry`.

This means the live user-facing standard upgrade path is **still a replacement flow**, not an in-place mutation flow.

Important implication:

A dynamic implementation must replace this path. As long as this path exists, the system remains clone-driven in practice, even if the manager is not.

---

## 6. The Client Addon Uses Clone Identity Heavily

The current addon-side logic still depends on clone identity for several behaviors.

### In `DC-ItemUpgrade`

The addon:

- parses `cloneMap`,
- stores `baseEntry` and `currentEntry`,
- consumes `newEntry` from upgrade results,
- uses entry comparisons to match server responses back to bag slots and equipment slots,
- builds cached `cloneEntries[level]` maps,
- uses clone entries in tooltip and preview logic.

### In `DC-QOS`

The QoS tooltip module also caches:

- `baseEntry`
- `currentEntry`
- `baseIlvl`
- `upgradedIlvl`
- `statMultiplier`

and displays `Upgraded Entry: <id>` when current and base entries diverge.

Important implication:

Addon migration is not just a field rename. It is a real state-model change.

---

## 7. The Clone Pipeline Is Large and Real

The clone generator currently:

- reads base item templates,
- generates clone `item_template` rows,
- generates `dc_item_upgrade_clones` rows,
- generates `dc_item_templates_upgrade` rows for the clone entries,
- updates `Custom/CSV DBC/Item.csv` so the client can display clone item entries.

Current clone rules from the generator:

- Tier 1 clone range starts at `2,000,000`
- Tier 2 clone range starts at `2,500,000`
- clone rows are regenerated into `item_template`
- clone rows are written into `Item.csv`
- numeric stats are scaled by `+3%` per level relative to base in the generator

`tools/update_item_csv.py` also explicitly rewrites clone-range rows in `Item.csv`.

Important implication:

Any serious dynamic migration that intends to retire clones must also retire this pipeline.

---

## 8. WotLK-Extensions Gives Hook Points, Not a Finished Solution

The client patch repository is promising, but it does not already provide dynamic item upgrades out of the box.

### What already exists

#### `CGTooltip::SetItemEx` hook

The client patch already hooks item tooltip creation at many call sites and redirects them to `SetItemEx`.

#### `CGTooltip::SetSpellEx` mixed implementation

The spell tooltip path already has a robust protocol-based enrichment design:

- context hash per request,
- stale-response rejection,
- pending state display,
- timeout fail-open behavior,
- session kill-switch behavior documented in the repo.

#### `ITEMMODEXT_PATCH`

The patch can expand the client item-mod tables so additional static item mods can be defined and displayed.

#### `TOOLTIPID_PATCH`

This can display IDs in tooltips, but it is documented as work in progress and is not a dynamic upgrade system.

### What does not exist yet

The item tooltip implementation currently still returns immediately to the original client function.

In plain terms:

- the item tooltip hook point exists,
- but the item tooltip enrichment behavior is not implemented.

Important implication:

The spell enrichment path is the blueprint. The item path still has to be built.

---

## What Can Be Kept In A Dynamic Upgrade System

Several parts of the existing architecture should be retained.

## 1. Per-item GUID upgrade state

This is already the correct core abstraction.

Keep:

- `dc_item_upgrades`
- item GUID keyed progression
- invested currency tracking
- season tracking
- upgrade logging

## 2. Upgrade cost tables and tier tables

The world DB cost and tier metadata remain useful.

Keep:

- `dc_item_upgrade_costs`
- `dc_item_upgrade_tiers`
- base-item rows in `dc_item_templates_upgrade`

Potentially retire or repurpose:

- clone-target rows in `dc_item_upgrade_clones`
- clone-only rows in `dc_item_templates_upgrade`

## 3. Stat and item-level calculation logic

The mechanics layer already provides:

- stat multiplier calculations,
- tier-aware scaling,
- upgraded item level calculations,
- cumulative cost helpers.

Keep the logic, but ensure the formulas in the report are treated as current implementation behavior, not always as intended design doctrine. Some older comments still reference legacy tier numbering and prior design phases.

## 4. Proc scaling architecture

Keep it with minimal changes.

## 5. Force stat refresh pattern

The current `ForcePlayerStatUpdate()` approach is still useful after a dynamic upgrade.

---

## What Must Change For A Real Dynamic Migration

## 1. Standard upgrade execution must become in-place

The current clone swap must be replaced.

Target behavior:

- keep the same item instance when possible,
- mutate upgrade state on the existing GUID,
- refresh derived stats,
- notify client and addon without changing the item entry,
- preserve equipped state.

This is the most important server-side change.

## 2. The addon protocol must become guid-centric, not clone-centric

Current payload shape is built around entry replacement.

Dynamic payload shape should instead center on:

- `itemGuid`
- `baseEntry`
- `upgradeLevel`
- `maxUpgrade`
- `tier`
- `baseIlvl`
- `upgradedIlvl`
- `statMultiplier`
- optionally derived preview values
- optionally item set status if desired

Fields that should eventually disappear from the standard path:

- `cloneMap`
- `currentEntry` as a dynamic identity signal
- `newEntry`

A temporary compatibility phase can still expose them, but only as transitional fields.

## 3. Addon-side caching and tooltip matching must stop using current item entry as identity

Today the addon frequently matches responses back to UI slots by comparing `currentEntry` and `baseEntry` to bag or equipment links.

That is fragile even in the clone model and becomes unnecessary in a dynamic model.

The better identity is:

- item GUID,
- plus slot/location when needed,
- plus a request id or query context.

## 4. Item tooltip enrichment has to be implemented on the client

This is the major client workstream.

A dynamic system without clone entries needs a way to present upgraded stats and level in the item tooltip.

The most promising path is to implement an **item** analogue of the spell tooltip mixed-enrichment model already present in WotLK-Extensions.

### Recommended client design pattern

Add new custom packet support for item tooltip enrichment:

- client request: item GUID, item entry, context hash
- server response: status + enrichment lines or structured values
- client cache keyed by item GUID + context hash
- fail open on timeout so native tooltip still works

This should copy the spell path's safety model:

1. context gate,
2. stale-response rejection,
3. timeout fail-open,
4. session kill-switch.

## 5. The clone generator and Item.csv updater must be retired or downgraded to migration-only tools

If the end state is fully dynamic, the normal build/deploy flow should not regenerate millions of clone-like item rows.

---

## Why `ITEMMODEXT_PATCH` Is Not The Main Solution

`ITEMMODEXT_PATCH` is useful infrastructure, but it does not solve the main problem.

### What it helps with

- adding extra static item mod types,
- enabling additional mod labels on tooltips,
- potentially supporting custom combat ratings when paired with other systems.

### What it does not solve

- per-item GUID progression,
- per-instance upgrade levels,
- mixed tooltip values for identical base entries owned by different players,
- runtime item-specific enrichment without entry replacement.

A single item entry still maps to one static definition unless additional runtime tooltip work is done.

Conclusion:

Use `ITEMMODEXT_PATCH` only if the dynamic design also needs extra client-readable static mod types. Do not mistake it for a complete dynamic item upgrade solution.

---

## Item Set Investigation And Why Dynamic Helps

This topic deserves a dedicated section because it affects both correctness and player trust.

## 1. How AzerothCore actually applies item set bonuses

Server-side set bonus application is centered on the item's `ItemSet` id, not on matching the exact item entry against the item list in `ItemSet.dbc`.

The flow is:

- read `proto->ItemSet`,
- look up the set definition by set id,
- increment item count for that set,
- apply threshold spells when `item_count` reaches the configured thresholds.

Important implication:

Mechanically, if a clone retains the same `ItemSet` value, the server can still count it toward the set.

## 2. Why the clone model is still bad for sets

Even if server-side counting works, the clone model still creates two structural issues.

### Problem A: `ItemSet.dbc` membership cannot represent all clone variants

`ItemSetEntry` has a fixed `MAX_ITEM_SET_ITEMS = 10` item id slots.

That is enough for a normal set, but not for:

- the base set,
- plus every upgraded variant of every set piece,
- plus mixed upgrade combinations.

So the clone approach cannot ever scale cleanly in the DBC layer.

### Problem B: the current standard upgrade flow replaces the item entry

The standard upgrade bridge destroys the current item and stores a new clone item.

For equipped set pieces, that is a fragile behavior:

- it can temporarily break equip state,
- it can move the replacement item into inventory rather than restoring the exact equipped context,
- it makes set identity dependent on successful recreation and re-equipping rather than stable item continuity.

## 3. Why dynamic upgrades are the cleaner answer for item sets

A dynamic implementation keeps:

- the base item entry,
- the same set id,
- the same stable client-facing item identity,
- and only changes the attached upgrade state.

That means:

- mixed upgrade levels across one set become natural,
- no clone-set DBC combinatorics are needed,
- item set membership remains conceptually anchored to the original base set piece,
- equip continuity is much safer.

## 4. Important nuance

A dynamic migration will likely solve the **structural** set issue, but it is not proof that every current live item-set bug is caused solely by clones.

If there is a specific current broken set bonus, a data audit is still worth doing because:

- invalid `ItemSet` ids are zeroed by load validation,
- bad clone data could still have stripped or corrupted `ItemSet` values,
- client display issues and server mechanical issues are not always the same bug.

---

## Deep Dive: Current Tables And Their Likely Fate

## Tables to keep in a dynamic design

### Character DB

- `dc_item_upgrades`
- `dc_item_upgrade_log`
- any current currency persistence tables still actively used by the deployed branch
- progression / season tables that are independent of clone identity

### World DB

- `dc_item_upgrade_costs`
- `dc_item_upgrade_tiers`
- base-item rows in `dc_item_templates_upgrade`

## Tables to retire or narrow

### `dc_item_upgrade_clones`

Current purpose:

- map base item + tier + level to a clone entry,
- resolve clone entry back to base entry and level,
- feed addon clone maps,
- drive standard clone-swap upgrade execution.

Dynamic future:

- temporary migration helper,
- optional rollback support during staged rollout,
- ultimately removable from the runtime hot path.

### Clone-range rows in `dc_item_templates_upgrade`

Current purpose:

- duplicate clone-tier rows for clone entries.

Dynamic future:

- not needed in the steady state.

### Clone `item_template` rows and Item.csv clone rows

Dynamic future:

- removable from steady-state content generation.

---

## Recommended End-State Architecture

A clean dynamic architecture in this codebase would look like this:

## Server

### Base identity

- item keeps its original base entry
- item keeps its original set id and normal client cache identity
- upgrade level is attached as runtime state by item GUID

### Derived state

- multiplier
- upgraded item level
- derived stat bonus
- derived tooltip lines
- proc scaling bonus
- optional set- or specialization-aware preview info

### Persistence

- one row per upgraded item in `dc_item_upgrades`
- one audit row per upgrade event in `dc_item_upgrade_log`

### Upgrade execution

- in-place state mutation
- currency deduction
- stat refresh
- client/addon notification

## Addon protocol

### Standard item query response

Should describe:

- which item instance is being discussed,
- what upgrade level it is at,
- what the derived result is,
- what the next costs are,
- what the preview values are.

It should not need a clone ladder.

## Client patch

### Tooltip behavior

Use the native tooltip as baseline and append enrichment lines from the server asynchronously.

This is the safest pattern in a legacy client.

---

## Recommended Migration Plan

## Stage 0: Baseline And Instrumentation

Before changing runtime behavior, gather a controlled baseline.

Capture:

- existing clone counts,
- item set behavior on upgraded pieces,
- addon tooltip behavior,
- relog behavior,
- equip behavior,
- inspection and trade-window behavior,
- proc behavior.

Goal:

Know exactly which current behaviors must remain valid after the migration.

## Stage 1: Server In-Place Upgrade Path

Replace the standard clone swap flow with a true in-place upgrade flow.

Target outcomes:

- no `DestroyItem` + `StoreNewItem` for standard upgrades,
- existing equipped item remains the same item instance,
- upgrade level on the same GUID changes,
- stat refresh occurs immediately.

This is the stage most likely to improve item set stability immediately.

## Stage 2: Transitional Protocol Compatibility

Introduce a versioned or compatibility-aware protocol phase.

For a short period, the server may still send:

- `baseEntry`,
- `currentEntry`,
- `cloneMap`,
- `newEntry`

but internally stop relying on them.

Recommended approach:

- keep `baseEntry` for display/debug use,
- keep `currentEntry = baseEntry` for standard items during transition,
- send empty or synthetic clone data only if needed by old addon code,
- move addon internals toward item GUID identity.

## Stage 3: Addon Refactor

Update the addon to:

- key caches by item GUID,
- stop using `cloneEntries[level]` as authoritative state,
- stop matching server responses back to items by entry whenever a GUID or request id is available,
- build UI previews from numerical upgrade state instead of clone lookups.

## Stage 4: Client Tooltip Enrichment

Implement item tooltip enrichment in WotLK-Extensions.

Recommended design:

- new custom packet request/response pair for item tooltip enrichment,
- client cache keyed by item GUID + context hash,
- native tooltip remains intact if enrichment fails,
- appended lines render upgrade level, upgraded item level, and bonus summary.

Optional future enhancement:

Return structured fields instead of only one concatenated line if the item tooltip enrichment subsystem grows more complex.

## Stage 5: Data Migration

Migrate existing clone items back to base entries.

Likely migration steps:

1. scan live item instances whose entry is in clone range,
2. resolve base item id and level via `dc_item_upgrade_clones`,
3. rewrite item entry back to base item id,
4. ensure `dc_item_upgrades` contains the correct level for that GUID,
5. preserve invested currency and timestamps,
6. validate equipped state and item set behavior,
7. keep rollback snapshots.

## Stage 6: Retire Clone Runtime Dependencies

After successful migration:

- remove clone-path lookups from normal runtime flows,
- retire clone generation from the normal content pipeline,
- keep conversion tools only if desired for legacy recovery.

---

## Effort Estimate

## Conservative estimate for one experienced engineer

### 1. Server-side in-place upgrade conversion

Estimate: 2 to 4 working days

Includes:

- replacing clone swap execution,
- preserving current upgrade math,
- refreshing equipped item effects safely,
- validating set and equip behavior.

### 2. Addon and protocol migration

Estimate: 2 to 5 working days

Includes:

- payload redesign,
- addon cache redesign,
- tooltip cache redesign,
- compatibility cleanup.

### 3. Client tooltip enrichment in WotLK-Extensions

Estimate: 4 to 8 working days

This is the highest-risk and least prebuilt part.

### 4. Data migration and clone retirement

Estimate: 2 to 4 working days

Includes:

- SQL/data migration scripts,
- clone to base conversion,
- validation and rollback planning.

### 5. Regression and live validation

Estimate: 3 to 5 working days

Includes:

- equipped items,
- relog,
- mail/trade,
- inspect,
- tooltips,
- set bonuses,
- proc behavior.

## Total practical ranges

### Partial dynamic migration (server + addon, tooltip still transitional)

Estimate: about 1 week

### Full dynamic migration with native item tooltip enrichment and clone retirement

Estimate: about 2 to 3 weeks

### If the engineer is new to WotLK client patching

Estimate: 3 to 4 weeks

---

## Major Risks

## 1. Client tooltip ambiguity for identical base entries

If two items share the same base entry but have different upgrade levels, the tooltip layer must always identify the correct item instance.

This is why GUID-aware or context-aware enrichment is required.

## 2. Legacy addon assumptions are widespread

The addon currently assumes clone entry identity in several places. Missing one of those assumptions can produce subtle UI bugs even if server mechanics are correct.

## 3. Equip-state correctness during migration

A dynamic in-place upgrade flow is conceptually cleaner, but it still has to trigger all the right refresh paths for:

- stats,
- ratings,
- visible item fields,
- tooltips,
- set bonuses,
- inspect/trade windows.

## 4. Existing data quality may already be inconsistent

Some current clone rows may have inconsistent metadata in live databases. Migration scripts must validate, not blindly trust, every clone entry.

## 5. Older documentation contains outdated naming and older schema assumptions

Some existing markdown documents reference prior table names or older architecture stages. The current code should be treated as the source of truth.

---

## Open Questions Before Implementation Starts

These are the questions that should be answered before any real implementation work begins.

1. Should the dynamic implementation preserve base item entry permanently, or is there still a separate use case for cosmetic clone entries?
2. Do inspect, trade, and mail tooltip contexts all expose enough identity information for GUID-aware enrichment, or are extra client-side heuristics needed?
3. Does the addon need per-slot preview values for future upgrade levels, or is current-state-only enough in phase one?
4. Are any other systems outside the upgrade addon depending on clone entry ranges for gameplay logic or analytics?
5. Should the item tooltip enrichment packet return freeform text lines, structured fields, or both?
6. Is there any need to keep `ITEMMODEXT_PATCH` in scope for phase one, or can it be deferred until after dynamic identity is working?
7. Is heirloom handling going to stay on its own special path, or should the dynamic architecture absorb it under one unified model?

---

## Recommended Stage Gates

The user preference in this repo is to use explicit stage gates with clear validation checks. The migration should follow that discipline.

## Gate 1: Server Mechanics

Must be true before moving on:

- standard upgrades no longer destroy and recreate items,
- stats refresh correctly,
- equipped upgraded items stay equipped,
- proc scaling still matches expected damage/value deltas,
- no currency regression.

## Gate 2: Item Sets

Must be true before moving on:

- mixed-upgrade set pieces still count toward set bonuses,
- relog preserves set bonuses,
- equip and unequip transitions apply and remove set bonuses correctly,
- no set loss when upgrading an equipped piece.

## Gate 3: Addon/UI State

Must be true before moving on:

- addon no longer requires `cloneMap` to function for standard items,
- cache lookups work by GUID or request context,
- upgrade preview still works,
- no stale slot matching.

## Gate 4: Client Tooltip Enrichment

Must be true before moving on:

- base tooltip always renders even if enrichment fails,
- stale responses are rejected,
- timeouts fail open,
- session kill-switch behavior works,
- tooltip lines always match the correct item instance.

## Gate 5: Data Migration

Must be true before removing clone runtime dependencies:

- all live clone items migrate cleanly,
- rollback path exists,
- no orphaned upgrade states,
- no broken set items,
- no broken inspect/trade/mail tooltips.

---

## Validation Checklist

## Server Mechanics

- [ ] Upgrade a non-equipped item in inventory and verify state persistence
- [ ] Upgrade an equipped item and verify it remains equipped
- [ ] Verify stats update immediately after upgrade
- [ ] Relog and verify stats remain correct
- [ ] Verify item level displays stay coherent in UI and server state
- [ ] Verify currency consumption matches expected cost tables

## Proc Scaling

- [ ] Equip upgraded proc item and validate proc scaling output
- [ ] Re-equip / relog and validate same result
- [ ] Validate no clone lookup dependency remains in proc path

## Item Sets

- [ ] Equip mixed upgrade levels of one item set
- [ ] Verify set bonus thresholds still fire
- [ ] Upgrade one equipped set piece and verify set bonus does not drop unexpectedly
- [ ] Relog and verify set bonus still applies
- [ ] Inspect another player with mixed-upgrade set pieces

## Addon

- [ ] Query an item and verify item GUID keyed cache path works
- [ ] Upgrade then re-query without entry-change assumptions
- [ ] Tooltip preview still works for bags and equipped slots
- [ ] No stale response matches to the wrong item

## Client Tooltip Enrichment

- [ ] Tooltip loads normally if server enrichment is disabled
- [ ] Tooltip loads normally if server enrichment times out
- [ ] Correct upgrade line appears when enrichment succeeds
- [ ] Two identical base items with different upgrade levels show correct independent tooltips
- [ ] Inspect/trade/mail contexts behave correctly

## Data Migration

- [ ] Clone entry to base entry conversion preserves upgrade level
- [ ] Conversion preserves invested currencies and timestamps
- [ ] No orphaned rows remain in upgrade state tables
- [ ] No broken item set pieces after migration

---

## Final Assessment

A dynamic item upgrade implementation is practical here and is technically justified.

The current system already contains most of the server-side mechanics needed for a dynamic model. The major missing pieces are:

- replacing the standard clone swap execution path,
- redesigning the addon protocol around item GUID identity,
- implementing client-side item tooltip enrichment,
- retiring the clone generation pipeline after migration.

The migration is worth doing because it directly addresses the structural weaknesses of the current clone model:

- huge clone data footprint,
- clone-shaped addon and tooltip logic,
- awkward item identity semantics,
- item set variant explosion that does not fit cleanly in static DBC structures,
- and fragile equip behavior caused by destroy-and-recreate upgrade execution.

If the implementation is staged correctly, the codebase can move to a much cleaner end state without discarding the working parts of the current upgrade runtime.

---

## Implementation Recommendation

If this work proceeds, the best order is:

1. convert standard upgrades to in-place state mutation,
2. refactor addon protocol and caches away from clone identity,
3. implement item tooltip enrichment in WotLK-Extensions using the spell enrichment model as template,
4. migrate live clone items back to base entries,
5. retire clone generation from the normal pipeline.

That order attacks the real boundary first and keeps rollback options available until the client presentation layer is stable.

---

## Notes

- This report is analysis-only. No code changes, SQL changes, or client patch changes were applied while preparing it.
- No build, compile, or runtime validation was executed for this report.
- Existing older markdown files in this repository may reference earlier table names or older design assumptions; current code paths should be treated as the source of truth.
