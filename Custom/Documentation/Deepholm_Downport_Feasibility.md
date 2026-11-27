# Deepholm (Cataclysm map 646) → DarkChaos AzerothCore 3.3.5a — Complete Downport Feasibility

**Status:** Definitive feasibility report
**Scope:** Full open-world Deepholm zone port (Stonecore 5-man dungeon explicitly OUT of scope unless noted)
**Date:** 2026-06-26
**Source map:** `cata_world` map 646 (`Deephome` dir / `Deepholm` display) → `acore_world` + `Custom/DBCs` + client patch MPQ

---

## 1. Executive Verdict

A **partial-but-substantial** port is realistic and worth doing; a **literally-complete** ("everything retail had") port is **not** realistic on a phasemask-only WotLK core. The honest framing:

- **The map can exist and be walkable** with low/medium effort — terrain conversion tooling exists, and the DBC map/area registration is already ~85% authored and compiled in this fork (map 646 is in `Custom/DBCs/Map.dbc`, 39 sub-areas in `AreaTable.dbc`, a `game_tele` row is live). **Zero C++ engine changes** are required for map registration.
- **The ambient zone + leveling content is largely deterministic-automatable** — creature/GO/quest/loot ETL from `cata_world` is mechanical column-projection with conflict-free retail IDs.
- **The storyline (World Pillar) is where "complete" dies.** The 7-phase progression is driven by client `Phase.dbc` + Cata quest-reward-spell flow that **does not exist in any world-DB table to copy**, and AC's `SPELL_AURA_PHASE` semantics (OR-and-replace) make the multi-stage Temple-of-Earth sequence engine-impossible to reproduce via `spell_area`. Plus the 24 Molten Front "dailies" the cata dump parked on map 646 are Firelands endgame content that cannot function without currency 416 + buildable-camp phasing.

### Overall feasibility tier

| Outcome | Tier | Rough effort |
|---|---|---|
| Stand in / fly over a populated, ambient Deepholm with working leveling quests | **HIGH (do it)** | ~3–5 weeks (model assets are the long pole) |
| Faithful World Pillar storyline (phased hubs, rebuilding Temple) | **LOW (degrade or descope)** | +2–4 weeks bespoke C++/SmartAI, fidelity loss guaranteed |
| Molten Front dailies + Therazane rep-daily grind | **LOW (descope)** | Blocked on currency + phased-hub systems absent in core |
| **Net "complete everything"** | **MEDIUM-LOW** | Not recommended as a literal goal; ship the HIGH tier + a linear storyline compromise |

### Single biggest risk

**The storyline phasing trigger logic has no portable source.** The adversarial review verified that on map 646 the `spell_area` phase auras (83322 / 84117 / 84955) fire **simultaneously and unconditionally** (`quest_start=0, quest_end=0, aura_spell=0`); `phase_area` / `phase_definitions` are empty and no `conditions` rows reference them. The "which Temple stage do I see" decision lives in client `Phase.dbc` + the Cata quest-reward-spell chain. AC's `HandlePhase`/`GetPhaseByAuras` ORs all active phase-aura misc values and **replaces** the player phasemask wholesale — so concurrent area auras stack all three Temple stages on top of each other and drop the base bit. There is nothing to copy and the naive `spell_area` workaround is engine-impossible; a degraded linear progression must be **hand-authored** with bespoke single-aura add/remove on quest completion.

---

## 2. Scope Table (measured content counts)

| Dimension | Templates | Spawns / rows | Notes |
|---|---|---|---|
| **Creatures** | 313 templates | 6,522 spawns | entry 6491–53894, conflict-free |
| **GameObjects** | 101 templates | 947 spawns | zero problematic GO types |
| **Quests** | — | 128 quests | id 26244–29338; **only ~43 genuine one-time leveling** |
| ↳ daily/pool quests | — | 85 of 128 | 83 repeatable dailies (incl. 24 Molten Front endgame) |
| **Spells (enumerated)** | — | 33 distinct ids | 7 present / 26 Cata-era absent |
| **Items (quest-ref)** | — | 144 distinct | 95 already in `item_template`, 49 missing functional |
| **Creature display IDs** | — | 174 distinct | **130 missing** (129 Cata-new, modelid≥30000) |
| **GO display IDs** | — | 86 distinct | **44 missing** (need DBC rows + model bake) |
| **Factions** | — | 42 distinct | 24 Cata FactionTemplate ids absent |
| **Creature loot rows** | 87 templates | ~21,934 rows | 720 distinct items |
| **GO loot rows** | 18 templates | 86 rows | 63 distinct items |
| **Gossip menus / npc_text** | 48 menus | 51 npc_text | denormalize 3-table → flat; low-id collisions |
| **creature_text** | 67 NPCs | 149 rows | Type values pass through unchanged |
| **Vendors** | 2 NPCs | 14 rows | trainers: 0; pools touching 646: 0 |
| **Storyline C++** | — | 294 lines | 1 boss AI + 1 vehicle + 1 spell script |
| **Phased spawns (non-base)** | 101 templates | 1,232 creatures + 96 GOs | 7 PhaseIds, no terrain swaps |
| **ADT terrain tiles** | — | 32 carry spawns (~32–49 real) | cols 26–33 × rows 27–34 bake superset |

---

## 3. Track A — "Make The Map Exist" (foundation)

This must work before any content matters. Ordered hard-dependency chain:

```
Terrain assets (ADT/WMO/M2/BLP)  →  MPQ pack  →  DBC rows (Map/Area/Liquid/Light)
        →  server map/vmap/mmap extraction  →  server map registration  →  player entry
```

### A.1 Terrain & client assets — feasibility MEDIUM (downgraded from "high")

| Step | Tool / file | Status |
|---|---|---|
| RAW-dump Deephome from retail 12.x | wow.export | not run |
| Bake ADT/WMO/M2 → 3.3.5 | `wxl-baker --deps --tiles Deephome 26 27 33 34` | tool exists, proven on **1 Pandaria tile only** |
| Liquid re-type (lava + Temple water) | `RewriteMH2O` (heuristic) | **risk: self-admitted guess on liquid-heavy zone** |
| WDT MAIN prune to on-disk tiles | `TrimWdtMain` | exists |
| Terrain holes (crystal pillars/caves) | `--flatten-holes` | conditional |
| **Pack baked tree → MPQ** | StormLib/mpqcli, e.g. `patch-D.MPQ` | **UNWRITTEN GLUE — hard gate** |
| Extract collision | `vmap4extractor` → `vmaps/646*.vmtree/.vmtile` | **NEVER RUN, even on POC** |
| Extract nav | `mmaps_generator` → `mmaps/0646*.mmtile/.mmap` | **NEVER RUN, even on POC** |

**Corrected verdict (vs. "proven end-to-end"):** Per the toolchain's own README line 149, the Pandaria 870 POC fed exactly **one** geometry tile and never ran vmap4extractor or opened Noggit. The **entire server-side collision + navigation half** — which is in this track's scope — is unvalidated. The geometry translators (incl. the mature WMO path that preserves MOPY/MOVI/MOVT/MOBN/MOBR/MLIQ collision chunks and maps lava=7) are sound and well-built, but the in-game verification loop (water, holes, untextured doodads, skybox) is the long pole, not the conversion. Hard new glue: the **MPQ-pack step** — confirmed both the AC extractors (`System.cpp` `gOpenArchives`) and the live client read MPQ **only**, no loose-`Data/` fallback.

**Real effort:** 2–3 focused days is the optimistic floor; budget +several days of iteration for the never-run vmap/mmap pass and broken-liquid/hole/skybox fixes.

### A.2 DBC layer — feasibility MEDIUM (registration done; correctness defects live)

**Already present & compiled (rebuilt Jun 24–26 2026):**
- `Map.csv:196` + `Map.dbc`: id 646, `Directory=Deephome`, `InstanceType=0`, `ExpansionID=2`.
- `AreaTable.dbc`: 39 continent-646 areas, parent **4922**, AreaBits 1766–1937 (all <4096, no collision).
- `WorldMapContinent` id 7, `WorldMapArea` id 1215, 6 `Light` rows + LightParams 912/954/957/906.

**Live defects that block "everything correct" (adversarial-verified):**

| Defect | Detail | Severity |
|---|---|---|
| Out-of-range sound ids on **all 39** AreaTable rows | ZoneMusic 897–900 (dbc has 369), AmbienceID 639/2129 (dbc 206), IntroSound 798–803 — `csv-area` does **not** clamp (`CsvGen.cpp:192`) | **major — silent garbage index, already shipped** |
| Map 646 `AreaTableID=268` | 268 = "Azshara Crater" (continent 37) — wrong default-zone pointer | major |
| `WorldMapOverlay` 29 rows but **hollow stubs** | empty TextureName, zero dims (research wrongly said 0 rows) | major (29 textures to author) |
| Missing `LightSkybox` row 360 | referenced by LightParams 912; csv max 200 | minor — cavern sky won't render |
| Zone-id aliasing 5042 vs 4922 | retail spawns carry zoneId 5042; 5042 here = "Camp Nooka Nooka" (continent 745); 179 spawns in bare areaId 5042 | **major cross-dim** |
| `csv-area` re-parents verbatim to 5042 | the 4922 fix is a **manual hand-edit**; re-running the tool reintroduces broken parents | fragile, not automated |
| Stale `acore_dbc` mirror | max map 724, no 646, max area 4987 | minor — re-import after rebuild |

**The 5042 reconciliation is the load-bearing cross-dim decision** (see §5/§6): if the baked ADT MCNK area-ids carry retail 5042, open terrain resolves to the wrong continent/zone (broken zone name, exploration, rested state, area auras). The DBC layer alone cannot fix this — it needs a terrain-side area-id remap **or** a 5042-on-646 alias.

### A.3 Server map registration — feasibility HIGH (zero C++)

- The only engine gate is `MapMgr::CreateBaseMap` `ASSERT(sMapStore.LookupEntry(646))` then `entry->Instanceable()==false → new Map(...)`. `InstanceType=0` already satisfies this. **No hardcoded map-id allow/deny list** exists (`grep` of `src/server/game/Maps` found only the `MAP_OUTLAND==530` liquid hack).
- `instance_template` is **optional** for a continent (only required when `entry->IsDungeon()`).
- **Hard precondition:** the deployed `worldserver` must load the 151-record custom `Map.dbc`, not a stale stock 724-max copy, or `CreateBaseMap(646)` **crashes**. Verify on the live box before anyone enters.

### A.4 Player entry

| Mechanism | Status | Recommendation |
|---|---|---|
| `game_tele` row id 10611 `deepholm` map 646 | **LIVE** | GM `.tele deepholm` works today (once terrain deployed) |
| Player-facing portal | none in 3.3.5 client/DBC (retail Temple-of-Earth portal is a Cata areatrigger) | **Portal GO + SmartAI `SMART_ACTION_TELEPORT`** (no client DBC change) — simpler than custom AreaTrigger.dbc row |

---

## 4. Track B — Content Port

Ordering (each depends on the prior for references to resolve):

```
[Track A map exists]
   → creature_template + sibling tables → creature spawns
   → gameobject_template + spawns
   → items (item_template) ──┐
   → spells (Spell.csv)      ├─→ loot tables resolve, quest rewards function
   → quests (quest_template) ┘
   → supporting (gossip/npc_text/vendors/movement/creature_text/conditions)
```

### B.1 Deterministic-automatable (SQL/Python ETL — write once, run)

| Work | Mechanism | Volume | Effort |
|---|---|---|---|
| `creature_template` + `_model`/`_resistance`/`_spell` split | 1:1 column projection; modelid1-4→`_model`, scale→`DisplayScale` | 313 templates | 1–2 days for whole creature generator |
| creature spawns | new GUID block, map=646, **PhaseId→phasemask-bit rewrite (critical)** | 6,522 | included |
| `creature_addon`/`creature_template_addon` | `waypointPathId→path_id`, drop AnimKits, **filter 60 missing Cata auras** | 313 + 6,519 | included |
| `creature_equip_template` | straight copy — **0 missing items** | 151 rows | trivial |
| `gameobject_template` + `_addon` | Data0-23 1:1, no template uses Data24-31 | 101 | 0.5–1 day for whole GO generator |
| GO spawns | new GUIDs, drop PhaseId/PhaseGroup/terrainSwap | 947 | included |
| `quest_template` (+ addon) | 131→105 col projection; drop 29 cols, 1 rename, relocate AllowableRaces/TimeAllowed, **race-mask 24→12-bit remap** | 128 (≈43 viable) | 1–1.5 days |
| `quest_offer_reward`/`request_items`/`details`/`quest_poi`/`poi_points` | near-identical schemas, straight copy (drop BlobIndex) | 252 POI + 793 pts | included |
| loot (`creature_loot_template`/`gameobject_loot_template`) | flat copy, drop all-zero `IsCurrency` | ~22k rows | included in supporting |
| gossip | denormalize 3-table LEFT JOIN → flat `gossip_menu_option` | 20+4 rows | hours |
| `npc_text`/`creature_text`/`npc_vendor`/`waypoint_data`/`conditions` | column-drop straight copies; resolve broadcast-only strings inline | ~270 rows | included |
| missing item_template + Item.dbc | generate 49 functional rows from retail Item.db2 | 49 | 0.5–1 day |

**Recommendation: KEEP RETAIL ENTRY IDS.** Creature entries (6491–53894), GO entries, quest ids (26244+), item ids are all conflict-free in this fork (only 6 benign byte-identical creature dupes, 2 benign GO dupes, 0 quest collisions, nothing in DC custom ranges). Keeping retail ids lets every dimension's cross-references resolve without a global remap table.

### B.2 Hand-work / asset pipeline (the schedule driver)

| Work | Pipeline | Volume | Effort |
|---|---|---|---|
| **129 Cata-new creature display models** | DC retroport: wow.export → M2Mod/Wraith → CreatureModelData+CreatureDisplayInfo CSV on 500xxx seq → DBC → client patch | 129 models | **1–2 weeks** (per-model, some need skin-surgery/Wraith fallback) |
| **44 GO display models** | `wxl-baker --deps` + GameObjectDisplayInfo CSV at id ≥100794 (NOT native cata ids — DC CSV already occupies 10122/10124/10215) | 44 models | 2–3 days incl. M2 texture-bake workaround |
| 24 FactionTemplate.dbc rows | `wxl-dbc` downport OR remap to stock factions | 24 | hours |
| 6 Lock.dbc + 3 SpellFocusObject.dbc rows | hand-add from cata dbc | 9 | trivial |
| 10 Vehicle.dbc / VehicleSeat.dbc rows | downport referenced VehicleIds | 10 | hours |
| **26 Cata spells** (70354–100562) | hand-author `Spell.csv` rows (keep retail ids; no collision vs 300xxx/800xxx) + **substitute WotLK SpellVisual** | 26 | 1–2 days (visual judgement, only Xariona matters) |
| `creature_immunities` FK resolve | distinct (mechanic,school) mask pairs → rows, else 0 | few | hours |
| Xariona + wyvern + targeting spell C++ | port `zone_deepholm.cpp` (294 lines) to AC macros, register via `dc_script_loader.cpp` | 294 lines | ~1–2 days |

**Items/appearance are NOT a bottleneck:** 95/144 reward items already exist; all 53 visible-gear displayids are already in `ItemDisplayInfo.csv` (verify the server loads the CSV-built DBC, not the stale `acore_dbc` snapshot capped at 68742).

---

## 5. Phasing & Scripting Reality Check (storyline)

### What the World Pillar storyline needs

7 PhaseIds across 5 hubs, **no terrain swaps, no PhaseGroups** (purely spawn-visibility):

| PhaseId | Hub / area | Spawns | Storyline beat |
|---|---|---|---|
| 169 | base "always visible" | 5,290 cre / 851 GO | ambient zone |
| 237 | 5291 Crumbling Depths | 253 | Torunscar/Norsala/Hargoth/Boden |
| 251 | 5350 Stonehearth | 154 | stone-trogg siege |
| 252 | 5297–99 Therazane's Throne | 403 | Throne assault, Therazane |
| 253→254→257 | 5303 Temple of Earth | 115+225+60 | **3-stage rebuilding finale** |
| 170 | Abyssion World Pillar event | 22 | — |

### The honest design compromise (correcting the skeptics where due)

The adversarial verdict downgraded storyline feasibility to **LOW**, and on the load-bearing points it is **correct** — I do not overturn it:

1. **Trigger logic is uncopyable.** Verified: Deepholm `spell_area` auras (83322/84117/84955) are ungated and simultaneous; `phase_area`/`phase_definitions`/`conditions` are empty for these areas. The "which stage" selector lives in client `Phase.dbc` + quest-reward-spell flow — **nothing to copy**, must be reverse-engineered and hand-authored.
2. **AC engine forbids the proposed `spell_area` linear progression.** `HandlePhase`/`GetPhaseByAuras` OR all active phase-aura misc and **replace** the phasemask wholesale → concurrent Temple auras render 253|254|257 simultaneously and drop the base bit. Sequencing stages via area-entry auras is **engine-impossible**; it requires bespoke single-aura **add/remove on quest completion** (SmartAI `SMART_ACTION_SET_PHASE_MASK` / explicit aura apply-remove), not data copy.
3. **Bit space is NOT free.** Phasemask is **global, not per-map**: 4,951 existing creatures use 36 distinct non-base masks (CoT, Old Hillsbrad, Wrathgate consume bits 2/4/8/16/32/64/128/256). DC `PhasedDuels` also allocates bits up to `0x7FFFFFFF` at runtime via `SetPhaseMask` and can stomp static storyline bits. "Find 7 free contiguous bits" is **not satisfiable** as assumed — Deepholm storyline bits must be chosen against the live global allocation, and runtime-allocated duel bits remain a collision hazard.
4. **The intro wyvern is load-bearing, not optional.** `npc_deepholm_wyvern` is the only physical entry path and depends on camera-control 84364 + forcecast-teleport 84093 + vehicle waypoints (all flagged unresolved). Simplest fix: replace the cinematic flight with a **plain teleport + optional vehicle ride** (the `game_tele`/portal-GO path already lands the player).

**Where the research holds and the skeptic over-reached:** the **C++ porting load itself is genuinely small** — 294 lines (Xariona world-boss AI is cosmetic/optional; only the entry needs solving). The `PhaseId→bit` *spawn relabel* transform is real and deterministic. So the storyline is **not impossible**, but a faithful port is out; a **degraded strict-linear progression** (base → 251 → 252 → 253 → 254 → 257, monotonic, never reversible, with hand-authored per-quest aura add/remove and duplicate per-stage questgiver spawns gated by `conditions`) is the only viable shape, at **+2–4 weeks** and guaranteed fidelity loss.

**Critical pipeline rule:** the importer MUST translate `PhaseId→phasemask-bit`, **never copy `phaseMask`** (uniformly 1 in the dump). Copying it verbatim stacks every hub state on phase 1 = unplayable.

### Molten Front correction (quests skeptic — upheld)

24 of 128 quests (ids 29101–29304, pools 645019–645030) are **Firelands Molten Front endgame dailies**, not Deepholm leveling — the cata dump merely parked their giver NPCs on map 646. They reward **currency 416 (Mark of the World Tree)** — AC 3.3.5 `quest_template` has **no currency columns** (silent loss) — and depend on buildable-camp phasing absent in core. The research's "0 currency quests" and "~11 repeatable" claims are **false**: 85/128 are pooled dailies (83 repeatable). **Descope the 24 Molten Front quests entirely** (naive insert yields accept/abandon-loopable quests that grant nothing and pollute the log). The ~59 Therazane rep dailies depend on faction 1135 (absent) + daily-reset machinery. **Genuine one-time leveling quests ≈ 43** — those are the auto-portable core.

---

## 6. ID / Namespace Strategy

| Namespace | Deepholm range | DC custom range | Collision? | Decision |
|---|---|---|---|---|
| creature_template.entry | 6491–53894 | retroport 3461xxx; AC custom ≥100050 | none (6 benign dupes) | **keep retail** |
| gameobject_template.entry | 191707, 202736–208261 | up to 4002169 | 2 benign byte-identical | **keep retail** |
| quest id | 26244–29338 | — | none | **keep retail** |
| item entry | 58168–66897 | up to 900123 | 95 already present | **keep retail** |
| spell id | 70354–100562 | DC 300xxx + 800xxx | none (range unused) | **keep retail** |
| CreatureDisplayInfo (new) | n/a | 500xxx model/display seq | — | **allocate 500xxx** (do NOT use retail display ids) |
| GameObjectDisplayInfo (new) | 9652–10315 (retail) | housing-decor 100100+ | **DC CSV occupies 10122/10124/10215** | **allocate ≥100794**, remap template.displayId |
| **zone/area id** | retail **5042** | here 5042 = "Camp Nooka Nooka"; Deepholm authored as **4922** | **CONFLICT** | **Decide & apply consistently (see below)** |
| phasemask bits | n/a | 4,951 cre / 36 masks consume 2–256 globally; duel bits runtime | **CONFLICT** | **allocate against live global map, document reserved Deepholm bits** |
| spawn GUID block | — | verify free via acmcp before allocating | — | reserve a fresh DC block |

**Zone-id decision (must be made by owner):** Option A — keep parent **4922**, rewrite every literal **5042** in imported quests/scripts/spell_area to 4922, and ensure baked ADT MCNK area-ids point at sub-areas 5291+ (parent 4922), never bare 5042. Option B — re-author parent as **5042** to match retail (frees the conflict but must relocate "Camp Nooka Nooka"). **Option A is lower-risk and matches the already-compiled DBCs**, but requires a terrain-side audit that no open-terrain tile baked bare 5042 (179 spawns sit in bare 5042 today).

---

## 7. Phased Roadmap

| Phase | Goal | Key deliverables | Effort weight | Gate to next |
|---|---|---|---|---|
| **P0 — Stand in empty Deepholm** | walkable terrain + entry | wow.export dump → `wxl-baker` (client+server) → **MPQ-pack glue** → run `mapextractor`/`vmap4extractor`/`mmaps_generator` → deploy `646_*.map`/vmaps/mmaps; verify deployed `Map.dbc` has 646; `.tele deepholm` | **High (long pole)** | terrain renders, no fall-through, collision+nav verified in-game |
| **P0.5 — DBC correctness** | zone resolves correctly | fix AreaTableID 268→Deepholm; clamp/zero 39 rows' sound ids; add LightSkybox 360; **resolve 5042/4922** + ADT area-id audit; re-import `acore_dbc` | Low–Med | standing on open terrain shows "Deepholm", not "Camp Nooka Nooka" |
| **P1 — Ambient zone populated** | living zone | creature ETL (313 tmpl + base-phase 5,290 spawns); GO ETL (101 + 851 base GO); **129 creature + 44 GO display models**; 24 factions; loot/vendors/gossip/npc_text/creature_text/movement; `creature_immunities` | **High (models drive schedule)** | base-phase NPCs/GOs visible & textured, vendors/gossip work |
| **P2 — Quests playable** | leveling backbone | ~43 one-time leveling quests + quest_poi; 49 item rows; 26 spells (Spell.csv + visuals); WorldMapArea POI render (id 1215/640); SmartAI credit for exploration/talk objectives; **descope 24 Molten Front + 59 rep dailies** | Medium | quest chain accept→complete→reward end-to-end |
| **P3 — Storyline / scripts** | World Pillar (degraded) | `PhaseId→bit` spawn relabel (1,232 cre + 96 GO); duplicate per-stage questgivers gated by `conditions`; **bespoke per-quest phase-aura add/remove** (strict linear 251→252→253→254→257); port `zone_deepholm.cpp` (Xariona/wyvern/spell) to AC macros; entry via teleport+vehicle | **High (bespoke, fidelity loss)** | hub progression playable linearly, no stacked-stage mess |
| **P4 — Polish** | atmosphere & parity | Light/skybox/fog tuning; AreaPOI icons + 29 WorldMapOverlay textures; M2 texture-bake fixes; hole/liquid corrections; optional Xariona world-boss tuning; optional Stonecore dungeon (separate 2,772-line workstream) | Med (open-ended) | — |

### Recommended minimal first milestone

**Milestone 0 (MVP "it exists"):** Deliver **P0 + P0.5 + the base-phase subset of P1** — i.e. a walkable, correctly-named, ambient Deepholm with the 5,290 base-phase creatures and 851 base GOs visible (accepting placeholder/stock displays for the worst-converting models initially), reachable via `.tele`/portal-GO. This proves the entire toolchain end-to-end (the **never-run vmap/mmap + MPQ-pack glue** is the actual risk), produces a demoable result, and defers the two genuine hard problems (mass model conversion, storyline phasing) until the foundation is proven. Quests and storyline are explicitly out of MVP.

---

## 8. Open Questions / Decisions Needed From Project Owner

1. **Storyline ambition:** accept a degraded strict-linear World Pillar progression (+2–4 weeks bespoke C++/SmartAI, fidelity loss), or descope the storyline to ambient-zone-only? This is the single biggest scope lever.
2. **Molten Front / rep dailies:** confirm descope of the 24 Firelands dailies (currency 416 + phased camp absent) and the 59 Therazane rep dailies (faction 1135 + daily-reset)? Or invest in porting currency + daily systems?
3. **Zone-id 5042 vs 4922:** ratify Option A (keep 4922, rewrite literal 5042 everywhere, audit ADT area-ids) vs Option B (re-author 5042, relocate Camp Nooka Nooka).
4. **Phasemask bit allocation:** which global bits may Deepholm reserve given 36 existing masks + runtime duel-bit allocation? Need a documented reservation to avoid cross-zone phase bleed.
5. **Entry mechanism:** portal GO + SmartAI teleport (no client DBC change) vs custom AreaTrigger.dbc row (matches Hyjal docs)? Recommend the former.
6. **Stonecore 5-man dungeon:** in scope? It is a **separate map** with 2,772 lines of boss C++ + instance infra — doubles the C++ effort.
7. **Display-id fidelity floor:** for the 129 creature + 44 GO models, is a stock 3.3.5 visual-stand-in acceptable as a stopgap for models that crash-convert, or is faithful conversion required before launch?
8. **DBC deploy ownership:** is `acore_dbc` auto-rebuilt from `Custom/DBCs/` on deploy, or a manual step that has lagged since the Jun 24–26 rebuild? And which `ItemDisplayInfo.dbc` does the live worldserver load (CSV-built vs stale snapshot)?
9. **Spell-visual fidelity:** for the 26 Cata spells, is substituted WotLK SpellVisual acceptable (only Xariona readability matters), confirming retail spell ids are kept rather than renumbered to 300xxx?
10. **MPQ patch letter:** which free `patch-X.MPQ` slot for new map content (patch-A is AllRaces)?

---

*Report generated for the DarkChaos project owner. Foundation (Track A) and ambient content (Track B base) are the recommended committed scope; storyline (P3) and endgame dailies are descope/degrade candidates.*
