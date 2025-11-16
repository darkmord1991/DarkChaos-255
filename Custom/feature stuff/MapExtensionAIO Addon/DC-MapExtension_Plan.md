# DC-MapExtension Rebuild Plan (3.3.5a)

_Last updated: 2025-11-15_

## 1. Objectives
- Deliver a **clean-room rewrite** of the DC-MapExtension addon that plays nicely with Blizzard's default world map while exposing DarkChaos-specific content (custom zones, dungeons, hotspots).
- Provide **accurate GPS/POI overlays** for Azshara Crater, Hyjal, and future custom maps using server-fed data instead of hardcoded guesses.
- Integrate **dungeon maps (Vanilla/TBC/Wrath)**, custom battlegrounds, and Mapster-style navigation without forcing users into custom maps unintentionally.
- Surface **server-driven systems** (Hotspots, GPS, DC addons) through a consistent UI, with toggles for every layer.

---

## 2. Server-Side Capabilities Summary
### 2.1 Command Scripts (`src/server/scripts/Commands`)
- `cs_dc_addons.cpp`: consolidated `.dc` command root.
  - `.dc send`, `.dc sendforce`, `.dc grant`, `.dc difficulty`, etc. provide hooks for addon messaging and dungeon difficulty control.
  - Existing commands already broadcast XP snapshots and difficulty info we can consume in the addon (optional future feature: show dungeon difficulty/buffs).
- `cs_gps_test.cpp`: `.gpstest` dumps real-time normalized coords and sends GPS payloads over AIO. Useful for QA and for validating addon math.
- Core commands like `cs_list`, `cs_go`, `cs_instance`, etc., remain unchanged but give GMs the ability to debug spawn positions while testing maps.

### 2.2 DC Script Modules (`src/server/scripts/DC`)
Key folders impacting the addon:
- `MapExtension/PlayerScript_MapExtension.cpp`: pushes GPS updates via Rochet's AIO (payload includes normalized coords, combat state, speed, etc.).
- `Hotspot/ac_hotspots.cpp`: builds map bounds from DBC, spawns XP zones, sends `HOTSPOT_ADDON|...` payloads that clients listen to.
- `Hotspot/spell_hotspot_buff_800001.cpp`: ensures XP buff icon/spell data exist for UI display.
- `Hotspot/HotspotConstants.h`: shared spell IDs, GO entries, fallback icons (useful for default textures in addon).
- Other DC subsystems (MythicPlus, ChallengeMode, HinterlandBG, etc.) supply future POI layers but are not required for v1.

**Implication:** The addon must subscribe to both AIO GPS events and `HOTSPOT_ADDON` messages to stay in sync with server features. Map bounds can be exported from the server (via Hotspot module) to keep client coordinates precise.

---

## 3. Client Library Inventory (`Custom/Client addons needed/DC-MapExtension/libs`)
Available building blocks (Wrath-compatible, already shipped in repo):
- **Ace3** (core framework, configuration, profiles).
- **LibStub / CallbackHandler** (Ace prerequisites) bundled inside Mapster/GatherMate.
- **Mapster 1.3.9** – scaling, fog removal, cursor coords, group icons; becomes our default UI layer.
- **WDM 1.0.6** – dungeon textures/metadata for Vanilla/TBC/Wrath plus localization support.
- **GatherMate v1.25** – POI datastore + import/export (herb/mine/fish/gas/treasure) we can adapt for trainers/vendors.
- **!Astrolabe 0.5** (Trimitor fix build) – normalized coord math for world/minimap pins.
- **LibMapData-1.0** + `LibMapData_CustomZones.lua` – authoritative map bounds, including DarkChaos-only entries.
- **Atlas + AtlasLoot** family – boss layouts/loot tables for reference; treat as optional data sources.
- **MetaMap suite** (MetaMap, MetaMapBLT/BWP/etc.) – legacy overlays worth mining for POI formats, but we avoid loading them simultaneously to prevent taint.
- **ZoneLevelInfo 1.1** – level range overlay, slash command `/zli`, SavedVariable `ZoneLevelInfoSettings` (details §4).

Supporting assets to keep nearby:
- **DC_DebugUtils.lua** (existing) for throttled logging.
- **Archive/DC-HotspotXP** textures + timer UI to modernize for HotspotOverlay.

_Everything above targets Interface 30300 already; no additional backporting unless we intentionally upgrade to newer forks._

---

## 4. ZoneLevelInfo Integration (`libs/ZoneLevelInfo`)
- Provides localized zone level data and a cursor-following tooltip.
- Uses `zones[...] = {minLevel, maxLevel, factionFlag}` per locale; we can extend this table with DarkChaos-specific areas (Hyjal, Azshara, Hinterland BG, etc.).
- Includes slash commands `/zli size <16-24>` and defaults stored in `ZoneLevelInfoSettings`.
- For our addon:
  - Either embed ZoneLevelInfo as a module (respecting its SavedVariables) or convert its DB into a new `LevelInfoProvider` that feeds into our map tooltips.
  - To adjust level ranges for custom zones, edit `ZoneLevelInfo_DB.lua` and repackage with our addon.
   - `ZoneLevelInfo.xml` already defines hover frames we can repurpose, reducing the need for bespoke XML.

---

## 5. Proposed Addon Architecture
```
Interface/AddOns/DC-MapExtension/
 ├─ DC-MapExtension.toc
 ├─ Core.lua (AceAddon bootstrap)
 ├─ modules/
 │   ├─ AtlasManager.lua        (world map + dungeon selection)
 │   ├─ TextureController.lua   (tile stitching, custom map registration)
 │   ├─ POIManager.lua          (layers: towns, vendors, GatherMate, custom)
 │   ├─ HotspotOverlay.lua      (HOTSPOT_ADDON + AIO integration)
 │   ├─ DungeonAtlas.lua        (WDM + Atlas data bridge, boss notes)
 │   ├─ ZoneInfo.lua            (wraps ZoneLevelInfo data)
 │   └─ ConfigUI.lua            (AceConfig options/slash commands)
 ├─ data/
 │   ├─ MapBounds.lua           (exported from server; mapId -> minX/maxX/minY/maxY)
 │   ├─ CustomMaps.lua          (list of DarkChaos maps, textures, floor info)
 │   ├─ POIData.lua             (pre-seeded vendors/trainers/waypoints)
 │   └─ HotspotIcons.lua        (texture/icon references)
 └─ libs/ (symlinks or embedded copies to Ace3, Astrolabe, etc.)
```
**Key behaviors:**
- Default view uses Blizzard map; enhanced Mapster-like window is opt-in.
- Custom maps/dungeons appear under a "DarkChaos" continent tab + filter dropdown.
- Each POI/hotspot layer has its own toggle (with saved state per profile).
- GPS synchronization supports both AIO and fallback (listening to `.gpstest` output for debugging).

---

## 6. Implementation Phases
1. **Bootstrap** (TOC + Core + Config skeleton)
   - Register AceAddon, slash commands (`/dcmap`, `/dcmap debug`).
   - Load SavedVariables (per-account + per-character profiles) with sane defaults for each module.
   - Wire AceConsole + AceConfig skeleton so modules can inject option tables lazily.

2. **Atlas + Texture subsystem**
   - Port stable portions of archived `Core.lua` (map detection, tile stitching, simple state machine).
   - Integrate Mapster 1.3.9 features (Scaling/FogClear/Coords) through hooks or embedded modules.
   - Ingest `MapBounds.lua` exported from server to ensure coordinate accuracy and register custom continents.

3. **POI management**
   - Implement a layer registry (towns, trainers, GatherMate import, hotspots) with `RegisterLayer()`/`ToggleLayer()` APIs.
   - Hook !Astrolabe + LibMapData conversions for accurate world/minimap pin placement.
   - Build toggles in AceConfig + inline toggle buttons attached to the map frame.

4. **Hotspot overlay**
   - Reuse logic from `Archive/DC-HotspotXP/Core_wrath.lua` with a proper payload parser (string tokenization → Lua table).
   - Subscribe to `HOTSPOT_ADDON` chat channel and optional AIO events to render pins + timer list UI.

5. **Dungeon Atlas & Mapster integration**
   - Embed WDM textures/metadata and optionally ingest Atlas `_data.lua` for boss callouts.
   - Provide API to register new dungeons (Hinterland BG, Gilneas instances) with floor/fog metadata.

6. **Zone info + Level ranges**
   - Adapt ZoneLevelInfo database for DC specifics (new zones, adjusted brackets) and expose via `ZoneInfo.lua`.
   - Offer overlay tooltip + optional UI component mirroring ZoneLevelInfo but using our styling.

7. **GatherMate import (optional v1.1)**
   - Add importer that reads GatherMate saved data (herb/mine/fish/gas/treasure) into POIManager as custom layers.
   - Provide export command so testers can share POI datasets easily.

8. **Testing & polish**
   - Validate Azshara/Hyjal coordinate accuracy using `.gpstest` and AIO payload logs.
   - Run through dungeon selection flow, POI toggles, hotspot alerts, and Mapster mode across locales.

---

## 7. Required Inputs / Next Steps
- **Map bounds export**: run Hotspot `BuildMapBoundsFromDBC()` and dump to CSV/Lua for client use. (Optional script can dump from server at startup.)
   - Interim option: parse `Custom/CSV DBC/Map.csv` (Map.dbc dump) for each `ID`/`Directory` and combine with the 3.3.5a `WorldMapFrame` sizes from `Archive/3.3.5-interface-files-main` to derive `{left, right, top, bottom}` bounds until server exports are ready.
- **Custom POI lists**: supply CSV or SQL extracts (vendors, portals, trainers) to populate `POIData.lua`.
- **Hotspot icon preference**: confirm default textures/spell icons to display.
- **Zone level adjustments**: provide desired level ranges for custom zones; we'll edit `ZoneLevelInfo_DB.lua` accordingly.
   - Current plan: `Azshara Crater` = levels 1-80, `Hyjal Summit` (renamed from Hyjal) = levels 80-130 to avoid conflicts with stock Hyjal data.
- **Library versions**: confirm we stick with the current bundled Mapster/Astrolabe or if we should update to known forks.

Once these inputs are confirmed, we can begin implementing Phase 1 (bootstrap + atlas core).

---

## 8. Testing Checklist
- [ ] `/dcmap debug` prints current map, normalized coords, and active layers.
- [ ] Switching between Blizzard maps & custom maps is seamless (no forced state).
- [ ] Hyjal/Azshara textures align with GPS markers (verify via `.gpstest`).
- [ ] Hotspot pins appear/disappear on server broadcasts; highlight includes timer + bonus.
- [ ] Dungeon Atlas panel lists Vanilla/TBC/Wrath instances plus custom entries.
- [ ] Zone level overlay shows updated ranges (using ZoneLevelInfo data) for all locales.
- [ ] GatherMate import (optional) successfully displays herb/mining POIs without conflicts.

---

## 9. Implementation Kickoff Items
- [ ] Export baseline map bounds via Hotspot `BuildMapBoundsFromDBC()` and generate `data/MapBounds.lua`.
- [ ] Scaffold addon directories/files from §5 and wire TOC to reuse libs directly from `libs/`.
- [ ] Port archived map-detection logic into `modules/AtlasManager.lua`, replacing globals with Ace modules.
- [ ] Hook !Astrolabe + LibMapData conversions into a `/dcmap debug` command that cross-checks `.gpstest` output.
- [ ] Implement Hotspot payload listener stub (chat + AIO) that currently logs packets via `DC_DebugUtils` for validation.
- [ ] Repackage `ZoneLevelInfo_DB.lua` with DarkChaos custom zones before enabling the overlay.

Keep this document updated as features are delivered. Use section references (e.g., §5.2) when discussing implementation details during code reviews.
