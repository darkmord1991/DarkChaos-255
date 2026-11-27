# WotLK-Extensions Custom DBC Opportunities For Dark Chaos

## Document Purpose

This document captures a deeper research pass on:

- what `WotLK-Extensions` custom DBC support already does
- which recent upstream commits materially changed the custom DBC story
- which Dark Chaos systems are strong candidates for additional custom DBC work
- where stock DBC edits are already sufficient and a new custom schema is not
  needed
- where the assets should live in the Dark Chaos repository and in the final
  client patch payload
- which non-DBC stock WotLK client limits are still worth patching

This is a companion note to the broader architecture memo in
`WOTLK_EXTENSIONS_DC_MODULE_ARCHITECTURE.md`.

---

## Executive Summary

The main conclusion from this research is:

**Dark Chaos should use three separate data lanes, not one.**

1. **Stock DBC edits** for client systems that already have a fitting Blizzard
   table.
2. **Custom `.cdbc` files via `WotLK-Extensions`** for client features that are
   currently hardcoded or completely absent from stock 3.3.5a.
3. **Native packet or runtime cache fallback** for data that is large,
   DC-specific, and not safe to make a hard client dependency.

The biggest mistake would be to force everything into one bucket.

For Dark Chaos specifically:

- map, dungeon, currency, travel, visual, and many spell presentation problems
  should continue to use stock DBC edits first
- world lighting, occluders, extended spell-client flags, and other hardcoded
  client behaviors are a good fit for custom `.cdbc`
- collection, wardrobe, quest map metadata, and some Mythic Plus UI metadata
  are strong candidates for new DC-owned custom `.cdbc` schemas if you want to
  reduce addon payloads and runtime Lua tables

---

## Verified Current State

## Current custom DBC surface in WotLK-Extensions

The current external `WotLK-Extensions` repo ships support for these custom
`.cdbc` definitions:

- `LFGRoles.cdbc`
- `SpellAttributesExtended.cdbc`
- `ZoneLight.cdbc`
- `ZoneLightPoint.cdbc`
- `OcclusionVolume.cdbc`
- `OcclusionVolumePoint.cdbc`

These are not theoretical. They are wired into the current client patch code.

That proves the extension already supports this pattern:

- custom file loaded from `DBFilesClient`
- typed native struct definition in the DLL
- client patch logic consuming the loaded rows
- optional Lua-facing behavior layered on top

## Recent upstream commit history that matters

The following commits are the most relevant recent milestones:

### `de81636` on 2026-05-15

Key changes:

- added `ReloadCDBC`
- added `ReloadDBC`
- updated the DBC registration path
- added proper custom DBC unload and reload plumbing

Implication:

- local iteration is now better
- this improves developer workflow and diagnostics
- this does **not** turn DBCs into a network distribution channel

### `8d6a751` on 2026-04-28

Key changes:

- added `OcclusionVolume.cdbc`
- added `OcclusionVolumePoint.cdbc`
- added occluder world-data support
- added `ToggleOccluders`

Implication:

- this is a strong example of a hardcoded stock client behavior being moved into
  data
- it expands the "world presentation can be data-driven" story significantly

### `73cfde5` on 2026-04-15

Key changes:

- added `SpellAttributesExtended.cdbc`
- extended client-side spell tooltip and missile-related behavior
- added more spell-client-side control flags

Implication:

- this is one of the most useful patterns for Dark Chaos
- it shows that custom DBCs can extend client-side spell interpretation without
  abusing addon runtime logic for everything

### `d3b5426` on 2026-02-17

Key changes:

- refactored the custom DBC loader
- moved definitions into clearer per-table classes
- improved maintainability of adding new CDBC types

Implication:

- adding more custom CDBC types is cheaper now than it was earlier
- this lowers the cost of creating a DC-specific custom DBC suite

### Earlier foundation commits

- `24ec40a`: `ZoneLight` dehardcoding
- `d141bfd`: first working custom DBC manager with `LFGRoles`

Implication:

- the pattern has already moved from a one-off experiment into a growing client
  data layer

---

## What The New Reload Support Actually Means

The new `ReloadCDBC` and `ReloadDBC` functions are important, but they should be
interpreted correctly.

What they do well:

- reload local files for development and verification
- shorten iteration time while testing DBC edits
- reduce full-client-restart loops while working on data

What they do **not** do:

- distribute new DBCs to players
- replace packaging or patch deployment
- make stale clients magically current

So the correct model remains:

- **build and ship client data updates normally**
- use reload only as a local dev convenience and debug tool

---

## Placement Recommendation For Dark Chaos

Dark Chaos already has a usable structure for stock DBC content.

Observed current layout:

- editable CSV exports live under `Custom/CSV DBC/`
- compiled stock `.dbc` binaries live under `Custom/DBCs/`
- final client patch payloads live under
  `Custom/CDBCs/` (deployed to patch-4)

That is a good base. I would keep the same shape and make the roles explicit.

## Recommended canonical layout

### 1. Editable stock DBC sources

Keep using:

- `Custom/CSV DBC/`

Purpose:

- human-editable source CSVs for stock Blizzard DBC tables
- generation inputs for scripts and conversions

### 2. Canonical compiled stock DBC binaries

Keep using:

- `Custom/DBCs/`

Purpose:

- built stock `.dbc` files used as the canonical binary outputs in the repo

### 3. Recommended editable custom CDBC sources

Add a dedicated subfolder rather than mixing custom schemas into the stock CSV
pool.

Recommended:

- `Custom/CSV DBC/CDBC/`

Purpose:

- human-editable source files for `WotLK-Extensions`-owned custom schemas
- avoids mixing Blizzard stock tables and extension-only tables in one directory

### 4. Recommended canonical compiled custom CDBC binaries

Add a dedicated folder for generated `.cdbc` files.

Recommended:

- `Custom/CDBCs/`

Purpose:

- canonical compiled custom DBC artifacts for Dark Chaos
- keeps `.cdbc` assets separate from stock `.dbc` binaries
- makes it obvious which data depends on the extension DLL

### 5. Final client payload location

Ship the final files into the actual client patch bundle path:

- `Custom/CDBCs/` (deployed to patch-4)

Why this matters:

- the extension loads custom files from `DBFilesClient`
- your existing patch bundle already carries stock DBC payloads there
- putting `.cdbc` files in that same final deployment path matches runtime
  behavior

### 6. Upstream external repo reference location

In upstream `WotLK-Extensions`, example `.cdbc` binaries currently live under:

- `Docs/Custom DBCs/`

That is useful for reference and samples, but it is not the best canonical
production location for Dark Chaos assets.

## Recommended workflow summary

1. Author stock DBC sources in `Custom/CSV DBC/`
2. Author custom CDBC sources in `Custom/CSV DBC/CDBC/`
3. Generate stock binaries to `Custom/DBCs/`
4. Generate custom binaries to `Custom/CDBCs/`
5. Copy the shipping subset into
   `Custom/CDBCs/` (deployed to patch-4)
6. Package and distribute the patch bundle

---

## Where Stock DBCs Are Already The Right Tool

Do **not** create new custom schemas just because you can. Dark Chaos already
has a lot of useful stock DBC leverage.

## High-value stock DBC families already present in this repo

### World and map presentation

Use stock DBCs first:

- `Map.dbc`
- `MapDifficulty.dbc`
- `WorldMapArea.dbc`
- `WorldMapOverlay.dbc`
- `AreaPOI.dbc`
- `DungeonMap.dbc`
- `DungeonMapChunk.dbc`
- `WorldSafeLocs.dbc`
- `TaxiNodes.dbc`
- `TaxiPath.dbc`
- `TaxiPathNode.dbc`

Dark Chaos systems that benefit:

- Giant Isles and custom map work
- quest map normalization and zone-bound lookups
- custom battleground and dungeon map presentation
- teleport destinations and travel UX
- hotspot overlays and map pins

Important note:

For many overlay and map problems, `WorldMapOverlay` and `AreaPOI` should be
tried before inventing a custom CDBC.

### Dungeon, battleground, and queue UI

Use stock DBCs first:

- `BattlemasterList.dbc`
- `WorldStateUI.dbc`
- `LFGDungeons.dbc`
- `LFGDungeonGroup.dbc`
- `MapDifficulty.dbc`

Dark Chaos systems that benefit:

- HLBG and battleground UI work
- Mythic Plus dungeon presentation
- custom portal or queue labeling
- difficulty and dungeon-browser presentation

### Currency, item, and progression display

Use stock DBCs first:

- `CurrencyTypes.dbc`
- `CurrencyCategory.dbc`
- `Item.dbc`
- `ItemDisplayInfo.dbc`
- `ItemExtendedCost.dbc`
- `Achievement.dbc`
- `Achievement_Category.dbc`
- `Achievement_Criteria.dbc`
- `ScalingStatValues.dbc`
- `ScalingStatDistribution.dbc`
- `PowerDisplay.dbc`

Dark Chaos systems that benefit:

- seasonal tokens and currencies
- item-upgrade and reward display
- custom progression tracks
- level 255 scaling and stat presentation

### Spell presentation and visuals

Use stock DBCs first:

- `Spell.dbc`
- `SpellDescriptionVariables.dbc`
- `SpellIcon.dbc`
- `SpellMissile.dbc`
- `SpellMissileMotion.dbc`
- `SpellVisual.dbc`
- `SpellVisualEffectName.dbc`
- `SpellVisualKit*.dbc`
- `SpellItemEnchantment.dbc`

Dark Chaos systems that benefit:

- custom spells and passives
- item-upgrade visuals
- custom mounts and effects
- tooltip clarity and spell-client behavior

### World atmosphere and environment

Use stock DBCs first:

- `Light.dbc`
- `LightParams.dbc`
- `LightFloatBand.dbc`
- `LightIntBand.dbc`
- `LightSkybox.dbc`
- `LiquidType.dbc`
- `GroundEffectTexture.dbc`
- `GroundEffectDoodad.dbc`
- `LoadingScreens.dbc`

Dark Chaos systems that benefit:

- zone atmosphere and custom regions
- dungeon ambience
- loading-screen polish
- better zone identity for custom content

---

## Best New Custom CDBC Opportunities For Dark Chaos

These are the highest-confidence candidates where a **new custom schema** is
more justified than another stock DBC edit.

## Tier 1: Strong custom CDBC candidates

### 1. `DCQuestWaypoint.cdbc` and `DCQuestWaypointPoint.cdbc`

Why it is compelling:

- Dark Chaos already has Questie-style quest pins generated offline into Lua
- WotLK lacks native retail-style quest POI behavior
- current quest pin data is effectively a large static reference dataset
- the existing extension already has waypoint, map transform, and navigation
  helper APIs

What it could store:

- quest ID
- map ID
- normalized map coordinates
- objective vs turn-in vs start markers
- optional priority, icon style, and display flags
- optional grouped point data for multi-point objectives

Why custom instead of stock:

- the exact data shape is DC-owned
- stock 3.3.5a does not provide the retail quest map feature set you actually
  want
- you can tune it around the existing DC-QOS navigation stack

Dark Chaos systems that benefit:

- `DC-QOS` quest map pins
- custom quest navigation
- world map waypoint helpers

Fallback suitability:

- good runtime-cache fallback candidate

### 2. `DCCollectionCategory.cdbc`, `DCCollectionSource.cdbc`, and optionally `DCCollectionSet.cdbc`

Why it is compelling:

- collection and wardrobe static reference data is one of the clearest bulky
  addon payload classes in Dark Chaos
- the dynamic part is ownership and revisioning, not the static catalog itself
- moving static metadata out of addon sync reduces payload volume and Lua JSON
  cost immediately

What it could store:

- category metadata
- display ordering
- icon IDs or icon strings
- source type
- transmog family or mount/pet/title grouping metadata
- shop categorization or unlock presentation hints
- rarity or promotion flags

Why custom instead of stock:

- this is DC-owned UI metadata, not Blizzard content
- forcing it into unrelated stock DBCs would create maintenance debt

Dark Chaos systems that benefit:

- `DC-Collection`
- wardrobe
- shop categorization
- collection overview screens

Fallback suitability:

- excellent runtime-cache fallback candidate

### 3. `DCDungeonUi.cdbc` and `DCPortalDestination.cdbc`

Why it is compelling:

- Mythic Plus and DC dungeon UX need more than what stock dungeon tables alone
  express cleanly
- custom portal selectors and dungeon metadata are DC-owned presentation layers
- some static metadata should stop riding addon payloads

What it could store:

- dungeon map ID
- UI map relationships
- portal icon metadata
- display ordering
- seasonal tags
- category flags
- DC-specific labels and short descriptions
- default difficulty presentation metadata

Why not stock only:

- `LFGDungeons`, `MapDifficulty`, and `DungeonMap` are still useful, but they do
  not express all DC-specific UI needs cleanly

Dark Chaos systems that benefit:

- Mythic Plus portal selector
- Endless Dungeon or future custom dungeon browsers
- Group Finder or dungeon info panels

Fallback suitability:

- good runtime-cache fallback candidate

### 4. `DCTeleportCatalog.cdbc`

Why it is compelling:

- teleport metadata is mostly static
- teleport UIs often need icon, category, sort, location, and tag metadata that
  is not naturally part of stock client content
- this avoids large hardcoded Lua tables or repeated runtime syncs

What it could store:

- destination ID
- map ID and coordinates
- icon or display info reference
- category and subcategory
- faction or class restrictions
- cost and requirement presentation flags
- recommended level range

Dark Chaos systems that benefit:

- DC teleport or QoL travel UIs
- world-event travel panels
- admin or GM convenience interfaces

Fallback suitability:

- excellent runtime-cache fallback candidate

## Tier 2: Good candidates if the static dataset grows

### 5. `DCWorldEventOverlay.cdbc`

Why it is interesting:

- Dark Chaos appears to have recurring or large custom world features
- event overlay metadata is often static but visually rich
- this can complement, not necessarily replace, stock `WorldMapOverlay` and
  `AreaPOI`

Good use cases:

- invasion regions
- seasonal event markers
- rotating feature zones
- event-specific map labels or icon clusters

When to prefer stock DBC instead:

- when stock `WorldMapOverlay` and `AreaPOI` already cover the needed semantics

### 6. `DCNavigationAnchor.cdbc`

Why it is interesting:

- the extension already exposes navigation helpers, but DC may eventually want
  native anchor metadata beyond quest-only use cases

Good use cases:

- fixed world tour routes
- lore or exploration markers
- tutorial breadcrumbs
- DC-defined world guidance flows

This is a lower priority than quest and collection data.

## Tier 3: Prefer extending existing custom schemas first

### 7. More spell-client flags before inventing a new spell metadata CDBC

The presence of `SpellAttributesExtended.cdbc` is a signal.

Recommendation:

- if the need is truly spell-client behavior flags, extend
  `SpellAttributesExtended` first
- only introduce a new spell-related custom CDBC if the new behavior cannot be
  expressed as sparse per-spell flags

That keeps the spell-client data model simpler.

---

## Where New Custom CDBCs Should Probably Not Be Used

Avoid custom CDBCs for:

- rapidly changing live match state
- player-specific owned-state data
- session or combat telemetry
- anything that already maps cleanly to an existing stock DBC and only needs row
  additions
- temporary server announcements or rotating short-lived data

Those belong in:

- stock DBCs
- native packets
- runtime cache layers
- or plain addon/server messaging depending on frequency and importance

---

## Other Stock WotLK Client Limits Still Worth Improving

Not all valuable client work is about DBCs.

These are the strongest remaining stock-client limit categories.

## 1. Addon transport limits and string-heavy protocol handling

This remains the biggest architectural bottleneck for heavy DC addon traffic.

Best direction:

- native custom packets instead of more addon-channel inflation

## 2. Quest map and navigation UX gap versus later expansions

WotLK still lacks modern quest map and super-tracking behavior.

Best direction:

- continue the native navigation and waypoint API work
- consider custom quest waypoint CDBCs for static data

## 3. Hardcoded world presentation data

Recent commits already show success here.

Still promising areas:

- more atmosphere or world-visual tables if hardcoded client behaviors are found
- more data-driven environmental and regional presentation

## 4. Spell-client behavior gaps

Current extension work already started this with `SpellAttributesExtended`.

Further potential:

- more castbar behavior flags
- more tooltip visibility and formatting flags
- more client-side special-case spell presentation rules

## 5. Item stat and tooltip presentation limits

Known relevant patches already exist or partly exist:

- item mod table expansion
- spell description variable expansion

Dark Chaos could benefit from continuing this direction for richer item systems.

## 6. Render, visibility, and debugging limits

Current extension work already improved:

- farclip
- camera distance
- horizon scale
- environment detail
- nameplate distance
- fog control

Still useful:

- profile-driven graphics control integrated into DC-QOS
- more debug and visibility toggles for development builds

## 7. Glue and pre-world extensibility

This is still underexploited.

Strong opportunities:

- character-select notices
- feature banners
- onboarding hints
- patch-news surfaces
- account-level alerts

## 8. Class, race, and resource system hard limits

Known existing improvements already show the pattern:

- more than 21 races crashfix
- more than 12 classes in LFD
- combo-point and custom combat-rating support

Further work here depends on Dark Chaos product direction, but the client patch
route is proven.

---

## Best Dark Chaos Priorities From This Research

## Priority A: Use stock DBCs harder where you already have them

Especially:

- world map and overlay tables
- dungeon and battleground UI tables
- travel and teleport-related stock tables
- visual and environmental stock tables

This is lower risk than inventing new schemas.

## Priority B: Add a small set of high-value DC custom CDBCs

Best first candidates:

1. quest waypoint metadata
2. collection and wardrobe static metadata
3. dungeon or portal UI metadata
4. teleport catalog metadata

## Priority C: Treat runtime fallback as selective, not universal

Best fallback candidates:

- collection metadata
- teleport catalogs
- some dungeon UI metadata
- some event overlay metadata

Poor fallback candidates:

- hard native world-presentation tables like occlusion volumes or required zone
  lighting data

## Priority D: Keep extending native client limits beyond DBCs

Best next non-DBC areas:

- native transport
- quest map and navigation
- spell-client flags
- glue and pre-world UX
- richer graphics profile control

---

## Concrete Placement Recommendation

If Dark Chaos starts adding new `WotLK-Extensions` custom DBC content, the most
coherent repo layout would be:

```text
Custom/
  CSV DBC/
    ... stock dbc csv sources ...
    CDBC/
      DCQuestWaypoint.csv
      DCQuestWaypointPoint.csv
      DCCollectionCategory.csv
      DCCollectionSource.csv
      DCDungeonUi.csv
      DCPortalDestination.csv
      DCTeleportCatalog.csv

  DBCs/
    ... compiled stock .dbc files ...

  CDBCs/
    LFGRoles.cdbc
    SpellAttributesExtended.cdbc
    ZoneLight.cdbc
    ZoneLightPoint.cdbc
    OcclusionVolume.cdbc
    OcclusionVolumePoint.cdbc
    DCQuestWaypoint.cdbc
    DCQuestWaypointPoint.cdbc
    DCCollectionCategory.cdbc
    DCCollectionSource.cdbc
    DCDungeonUi.cdbc
    DCPortalDestination.cdbc
    DCTeleportCatalog.cdbc

  Client patches needed/
    patch-4/
      DBFilesClient/
        ... shipping subset of .dbc and .cdbc files ...
```

This keeps:

- stock and extension data clearly separated
- source and binary artifacts clearly separated
- final shipping payload in the path the client actually expects

---

## Final Assessment

The recent upstream `WotLK-Extensions` custom DBC commits are meaningful.

They show that the project is no longer just experimenting with one custom file.
It now has:

- a reusable loader
- multiple real custom schemas
- hot-reload support for development
- a stronger pattern for dehardcoding stock-client behaviors

For Dark Chaos, the best next step is not to create dozens of new custom CDBCs.
It is to be selective and disciplined:

- use stock DBCs where they already fit
- add new custom CDBCs only where the stock client is truly hardcoded or lacks
  the needed data shape
- keep player-specific and fast-changing state out of DBCs
- use final patch bundles under `patch-4/DBFilesClient/` for deployment

If you do that, custom DBCs become a strong force multiplier instead of another
maintenance burden.