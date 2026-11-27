# Map 751 — Lordaeron Extension (8 zones, level band 130–160)

Extends DC Plaguelands from the two Plaguelands zones to the whole of northern
Lordaeron, and turns it into a real multi-zone leveling continent.

Status file. Started 2026-08-19. Companion docs: `00_README.md` (the original
2026-07 import), `../HyjalCata/` (map 750, the reference implementation).

---

## 1. Zone allocation — FIXED, do not renumber

| DC zone | AreaBit | ExplLvl | band | source zone | terrain chunks |
|---|---|---|---|---|---|
| 4924 Eastern Plaguelands | 1941 | 152 | 152–158 | 139 | 7,416 |
| 4932 Western Plaguelands | 2449 | 148 | 148–153 | 28 | 3,520 |
| 4933 Tirisfal Glades | 2450 | 130 | 130–136 | 85 | 7,808 |
| 4934 Undercity | *reserved* | — | sanctuary | 1497 | none (WMO-only) |
| 4935 Silverpine Forest | 2452 | 134 | 134–140 | 130 | 4,767 |
| 4936 Hillsbrad Foothills | 2453 | 138 | 138–144 | 267 | 6,039 |
| 4937 The Hinterlands | 2454 | 145 | 145–150 | 47 | 6,624 |
| 4938 Arathi Highlands | 2455 | 142 | 142–147 | 45 | 7,714 |
| 4939 Ruins of Gilneas | 2457 | 130 | 130–136 | 4706 | 3,728 |

The band ladder follows Blizzard's own Cata level ordering for these zones
(average source level: Gilneas 9.4 → Silverpine 14.1 → Tirisfal 16.3 →
Hillsbrad 24.2 → Arathi 28.2 → Hinterlands 33.8 → WPL 39.2 → EPL 46.7), mapped
onto 130–160 with ~2 levels of overlap, exactly like `dc_map750_band`.

**AreaBit ceiling is 4095.** `PLAYER_EXPLORED_ZONES_1` is 128 uint32 = 4096 bits
(`UpdateFields.h:357`). Eight pre-existing AreaTable rows already exceed it
(4888, 4894, 5088–5094) and can never be explored — unrelated latent bug.

### Entry-offset bands for the new import

| content | offset | resulting range |
|---|---|---|
| creatures | **+4,100,000** | 4,100,000–4,155,808 |
| gameobjects | **+4,600,000** | 4,600,000–4,810,112 |

Both bands verified empty on 2026-08-19. Existing 751 content stays at
+3,600,000. **Import templates/quests/SmartAI from `cata_world` only** — nelt's
ids reach 1,337,016 and would overflow the band; use `nelt_world` purely for the
addon/movement layer matched onto already-imported spawns.

---

## 2. Done

1. **Terrain baked** from retail 12.0.7 —
   `node tools/downport-map.js Azeroth --bbox 27,25,42,36 --no-register`
   → `K:\Dark-Chaos\retailextracts\dc_plaguelands_ext_335` (1.3 GB; 192 ADT,
   3,245 M2, 1,600 WMO, 6,013 BLP). `--dbc` and `--light` deliberately NOT passed.
2. **Terrain is pre-blight Cata-era**, proven not assumed: MCNK area ids resolve
   to `153 Ruins of Lordaeron` / `85` / `159 Brill`, never the BFA variants
   (13983/13979/13980). Retail keeps the blight on its own map
   **1931 LordaeronBlight** as a phased terrain swap.
3. **Heights are byte-identical to the live map** on all three shared tiles
   sampled (37,120 vertices, max |dz| = 0.0000) → **the 4,433 existing spawns
   keep their z; no re-snap needed.**
4. **Area retag applied** — 47,616 chunks over 186 tiles restamped to the 8 DC
   zones; verified with `adt-retag-area.js --histogram` (8 ids, no strays).
5. **6 foreign border tiles dropped** (files + WDT present bits): `31_36 32_36
   33_36` Wetlands, `35_25 36_25` Eversong, `42_25` Zul'Aman. Rule: drop a tile
   with <64/256 target chunks; inside kept tiles fold buffer chunks into that
   tile's dominant target.
6. **`Custom/CSV DBC/AreaTable.csv`** 3,283 → 3,290 rows: 7 new zone rows, and
   4924 retitled `Plaguelands (130-160)` → `Eastern Plaguelands (152-158)`
   (ExplLevel 80→152, Ambience 0→37). Backup `.pre-751ext.bak`.
7. **Client staging tree** at `K:\Dark-Chaos\retailextracts\_stage_dcplaguelands_ext`
   (278 MB): `World/Maps/DCPlaguelands/DCPlaguelands_<col>_<row>.adt` ×186 + WDT
   + WDL, `textures/Minimap/DCPlaguelands/` ×186, and a ready
   `md5translate.DCPlaguelands.block.trs` passthrough block.
8. **`61_zone_split.sql`** — splits the legacy single zone across the 8 real
   zones using the retagged terrain (140 uniform tiles + 11,776 chunks for the
   46 mixed tiles), with a `dc_map751_zone_backup` rollback table and
   verification queries.

---

## 2b. Client DEPLOYED 2026-08-19 (verified from a fresh process)

| what | where | verification |
|---|---|---|
| 195 ADT + WDT + WDL | patch-4 | re-opened archive: WDT declares **195** tiles |
| 195 minimap BLP | patch-4 | sampled hashes match staging |
| `md5translate.trs` | patch-4 | **514 blocks** (unchanged), DCPlaguelands 60 → **195** lines, md5 `5802aa2b…` |
| `AreaTable.dbc` 3,290 rows | patch-4 + **patch-enGB-3** + `Custom/DBCs/` | all 8 zone ids read back from the archive |
| 689 Cata-era assets | patch-4 | 649 + 40 packed; **4,712 ADT-referenced assets → 4,712 present, 0 missing** |

> **Crash post-mortem (fixed).** The first pass shipped terrain without its Cata-era
> art because the asset probe was parsed wrongly (`-> NOT FOUND` also starts with
> `->`, so misses were counted as hits) *and* checked the wrong direction (files the
> baker emitted, rather than files the terrain references). Result: ERROR #132 at
> `0x0047BF36` on map 751. `Logs\wxl-core.log` named the culprits — read that file
> first on any custom-map crash. Correct check is `scratchpad/adt_refs.py`: parse
> `MTEX`/`MMDX`/`MWMO` from the ADTs and add derived `<m2>00.skin` / `<tex>_s.blp`.

Backups: `patch-4.MPQ.pre-mpq-patch.bak`, `AreaTable.dbc.pre-751ext.bak`,
`AreaTable.csv.pre-751ext.bak`, `*.adt.prearearetag`, `azeroth.wdt.pretiledrop`.

**The new land is not walkable yet.** The client now has 195 tiles but the server
still has the old 60, so anyone entering the new zones falls through. The server
extractors below are the real gate.

## 3. Remaining deploy — this sequencing is not optional

`Map.dbc AreaTableID` for 751 **must stay 4924 until the retagged terrain ships,
and must flip to 0 in the same deploy.** A nonzero AreaTableID hard-binds the
whole map to one zone; flipping early breaks the live map, flipping late means
every new zone still reports as 4924.

~~1–3. Client packing~~ **done, see §2b.**

4. **Copy `Custom/DBCs/AreaTable.dbc` to the server's `data/dbc`.** The live
   server still reports 3,283 records; it needs the 3,290-row build.
5. **Server: re-run `mapextractor` / `vmap4extractor` / `mmaps_generator`** against
   the MPQ-backed Data tree, for all 195 tiles. Until this runs the new land has no
   server-side terrain and players fall through it.
6. **Then, and only then, flip `Map.csv` 751 `AreaTableID` 4924 → 0**, recompile
   `Map.dbc`, and deploy to patch-4 + patch-enGB-3 + the server `data/dbc`
   **together**. This is the switch that makes 751 multi-zone; doing it before
   step 5 leaves players resolving to area 0.
7. Apply `61_zone_split.sql`, then check its two verification SELECTs.
8. Full client exit + relaunch (DBCs are read at launch, not at relog).

---

## 4. Next

- ~~Column 43 gap~~ **CLOSED.** A second bake (`--bbox 43,25,43,36`) recovered
  EPL's eastern edge *and five full Hinterlands tiles* the first bbox had clipped:
  12 tiles baked, 9 kept, 3 dropped (43_25 Zul'Aman, 43_35/43_36 Twilight
  Highlands). **The map is now 195 tiles** and `61_zone_split.sql` was regenerated.
- **Column 26 (Greymane Manor) — ADDED 2026-11-09, test client only.** The first bbox
  started at column 27, but `gilneas_manor.wmo` (uid 5939067, on 27_34) reaches world
  Y 2667 = the old west edge, so the manor stood on the cut line with no ground west of
  it. Third bake `node tools/downport-map.js Azeroth --bbox 26,31,26,36 --no-register
  --work .../_work_dc_plague_col26 --out .../dc_plaguelands_col26_335` (90 s, 6 tiles).
  All 6 kept for a straight edge: 26_34/26_35 carry the manor's western grounds (48/37
  land chunks, the same manor uid), 26_32/26_33 coast, 26_31/26_36 open sea. Areas
  retagged by continuing column 27 (each chunk takes the area of the chunk in the same
  row on 27's west edge, edge positions verified): 26_31/32 → 16748, 26_33..36 → 4939;
  no AreaTable change. Dead depth from stage 13 fixed (`mh2o_depth_repair.py`, 1,081
  instances), then the source's own under-scaled depths (395 instances, ratio < 0.98,
  `_mh2o_depth_scale_repair_20261109\col26\`). All 37 referenced assets were already
  in the client. The WDL needed nothing (byte-identical to the bake's full-EK WDL, which
  already has heights for column 26). WDT 195 → **201** tiles; `md5translate.trs` built
  from the live patch-4 copy, 562 blocks, DCPlaguelands 195 → 201 lines. Staging tree
  `K:\Dark-Chaos\retailextracts\_stage_dcplaguelands_col26\` (setfile included);
  backups `patch-4.MPQ.pre-greymane-col26-20261109.bak` / `.pre-depth98-col26-20261109.bak`.
  **Server data DEPLOYED 2026-11-09** (worldserver stopped), single-map recipe from a
  hardlinked copy of the TEST client: the 117 identical + 81 MH2O-depth-only tiles proved the
  two clients equal for the extractors. The 195 existing `.map` files came out
  byte-identical to the server's; only the 6 `75131..3626.map` files added. vmaps: full
  set (751.vmtree + 176 vmtiles, 4 new: 26_32..26_35) + new `Cobblestones08.m2.vmo`;
  the filtered run's empty `GameObjectModels.dtree` NOT shipped. mmaps: full fresh set
  (195, 4 new, 5 existing changed: the header and column-27 border tiles). Backups and
  a list of the added files are in `K:\tmp\_extract751\server_backup_pre-col26-20261109\`.
  **Still open:** the live client. No cata_world spawns exist west of column 28, so
  there is no content import to do.
- **Stray spawns to clean up:** 10 × `3608297 Magronos the Unyielding` (a Twilight
  Highlands NPC) sit at x −11507 / y −2819 — tile 37_53, far outside any 751
  footprint. A pre-existing bad import, not caused by this work; delete or
  relocate them. `61_zone_split.sql`'s off-map query reports exactly these.
- Spawn/quest/loot/SmartAI import for the 7 new zones from `cata_world`
  (9,671 creatures, 3,636 GOs, 1,127 entries, 412 SmartAI, 152 questgivers),
  addon+movement layer from `nelt_world` (4,662 addon rows, 115 paths).
- `dc_map751_band` + re-level (copy the `HyjalCata/233_` machinery) and quest
  `QuestLevel = -1` scaling — 0 of 197 quests are scaled today.
- Graveyards (1 row today vs 51 on map 750) from Cata `WorldSafeLocs.dbc`.
- Flight masters — **only 40 taxi node ids remain ≤448**: 338, 368–374, 378,
  385–391, 396–403, 406–420, 448. Non-renewable; do not waste them.
- WorldMapArea row + `Interface\WorldMap\<zone>` art per zone; square the
  WorldMapContinent taxi box (currently 3200×5333) before baking `TaxiMap751.blp`.
- C++: `zone_western_plaguelands.cpp:64` `switch (me->GetAreaId())` cauldron gate
  needs the belt-and-braces DC area id (pattern: `zone_darkshore_cata.cpp`);
  `OutdoorPvPEP.h` and `scourge_invasion.cpp` are hard-bound to map 0 / stock zone ids.
- Dungeons: MoP revamps **Scarlet Halls 1001 / Scarlet Monastery 1004 /
  Scholomance 1007** — spawns from `bfa_world` (84/179/335 rows), templates from
  `skyfire_world`+`bfa_world`, WMOs from retail; use the BFD-820 instance-clone
  recipe. Stock SM 189 / Scholo 289 / Strat 329 / Naxx 533 are already live and
  need no downport (Stratholme can take Cata's +14 quests).

---

## 5. Post-import defects — from the first server start (2026-08-19)

### 5a. Vehicles — CLOSED

17 imported templates carry a `VehicleId` and Vehicle.dbc held **none** of the 12
distinct ids. An unresolved VehicleId hangs the client, so this was a hard blocker.

- **Apply `75_vehicle_dbc.sql`** (12 `vehicle_dbc` + 33 `vehicleseat_dbc` rows).
  Generated by `Custom/Documentation/scripts/gen_map751_vehicle_dbc.py` from the
  real Cata 4.3.4 client; re-run the generator rather than hand-editing.
- Client side is **already deployed**: the same rows were appended to
  `Custom/CSV DBC/Vehicle.csv` (496 → 508) and `VehicleSeat.csv` (871 → 904),
  recompiled, and written to **both** `patch-4.MPQ` and `patch-enGB-3.MPQ`
  (enGB-3 shadows patch-4 for DBCs, so both are required), then synced to the
  three WarcraftXLHost candidate dirs. Verified from a fresh process: 508 / 904 in
  both archives, 0 pre-existing rows lost.
- **Still needed from you: copy `Custom/DBCs/Vehicle.dbc` and `VehicleSeat.dbc` to
  the server's `data/dbc`.** The SQL alone also works server-side (`LOAD_DBC` really
  does merge the `*_dbc` table over the file), so this is belt-and-braces — but the
  server's own copies are otherwise a patch behind.
- `vehicle_template_accessory` being empty for the band is **not** a defect: Cata has
  one accessory row for this creature set and its accessory creature was not imported.

### 5b. Creature models — 260 templates failed to load — DONE

`Creature (Entry: 41xxxxx) has no model defined in creature_template_model` does not
mean the table is empty. Every one of the 1,127 templates has model rows; the core
**discards** rows whose `CreatureDisplayID` is absent from CreatureDisplayInfo.dbc,
and a template left with no surviving model reports this per spawn. So "0 creatures
without a model row" was a true check that measured the wrong thing.

323 display ids >30000 are referenced; 20 exist, **303 are missing**. They resolve to
only **70 distinct model paths**, and probing the DC client for each gives:

| | paths | displays |
|---|---|---|
| model file **already in the DC client** | 64 | 292 |
| model file absent — needs an art downport | 6 | 11 |

The six that need art: `CataclysmCrocodile`, `DruidBearWorgen`, `Ettin`, and
`HumanTurnip0{1,2,3}`.

Work splits into three parts, best done together — fixing only the first leaves the
error log just as loud:

1. **65 plain displays** (`ExtendedDisplayInfoID = 0`) — bounded and safe. Needs a
   CreatureDisplayInfo row each, **8 new CreatureModelData rows**
   (UnboundAir/WaterElemental, NastySpiderEgg, OM_Stonehenge_03,
   StormwindMagePortal01, BallAndChain01, DuskwoodWardrobe01, BrillCoffins), and
   creature_model_info. 68 distinct TextureVariation strings are referenced.
2. **238 displays with `ExtendedDisplayInfoID != 0`** — baked character NPCs on
   `CHARACTER\...` models. CreatureDisplayInfoExtra's `NPCItemDisplay` entries point
   at Cata item display ids that mostly do not exist here, so this is the baked
   character-NPC recipe, not a row copy. Copying them naively yields naked NPCs.
3. **11 displays** behind the 6 missing models.

When matching Cata paths against DC's CreatureModelData, **strip the extension** —
DC stores some as `.mdx` where Cata says `.m2`, and raw string comparison invents
about 35 phantom "missing" rows.

#### Shipped 2026-08-19 — all three parts

Generator: `Custom/Documentation/scripts/gen_map751_creature_displays.py`.
**Apply `76_creature_displays.sql`** — 14 `creaturemodeldata_dbc` + 204
`creaturedisplayinfoextra_dbc` + 303 `creaturedisplayinfo_dbc` overlay rows, and
303 `creature_model_info` rows.

The client half is **already deployed and verified**:
- `CreatureDisplayInfo.csv` 28,717 → 29,020, `CreatureDisplayInfoExtra.csv`
  16,575 → 16,779, `CreatureModelData.csv` 2,973 → 2,987; recompiled and written to
  patch-4 **and** patch-enGB-3, then synced to the three candidate dirs. Fresh-process
  read-back confirms all six copies, 0 pre-existing rows lost, field counts unchanged.
- 238 bake textures → `textures\BakedNpcTextures\` in patch-7 (272 destinations, the
  extra 34 being worgen model-dir copies). All were present in the Cata client.
- 6 downported models + deps → patch-6/8/D/G (194 files), routed by
  `dc_mpq_layout.dest_for()`.

**Still needed from you:** copy `Custom/DBCs/CreatureDisplayInfo.dbc`,
`CreatureDisplayInfoExtra.dbc` and `CreatureModelData.dbc` to the server's
`data/dbc`, and restart the client fully (DBCs are read at launch, not at relog).

Verification already run: re-reading the SHIPPED DBCs out of the client archives
resolves **303/303** model chains, 204 bakes and 99 texture routes with **0**
problems; and against the live DB, **0** templates in the band would still lack a
display in `creature_model_info` once `76_` is applied (241 do today).

Three notes worth keeping if this is ever redone:
- The Cata display ids were reused **verbatim** — none collided — so
  `creature_template_model` needed no remap. Only Extra id 21831 was reallocated.
- Race 22 (worgen, 34 displays) has no ChrRaces row in the server's *or* the
  client's table, so those bypass the Extra route entirely: they bind onto the DC
  WorgenNPC models 500961/500962 with the bake in TextureVariation_1 and the
  skin/cape values in TV_2/TV_3, and the bake is packed next to the model as well —
  a MONSTER slot never reads BakedNpcTextures.
- `wxl-baker --deps` does **not** follow TextureVariation textures (they are
  runtime-bound, not referenced by the M2). The two CataclysmCrocodile skins were
  missed by the bake and packed separately; only the end-to-end verifier caught it.
- The overlay table `creaturedisplayinfoextra_dbc` spells its item columns
  `NPCItemDisplay1`..`11` — **no underscore** — where the CSV header uses
  `NPCItemDisplay_1`. The other two tables match their CSVs. Generated column lists
  must be checked against INFORMATION_SCHEMA, not against the CSV header.
- The generator is **not** idempotent across its own CSV append: re-running it takes
  its baseline from the `.pre_map751_displays.bak` files (and honours `SQL_ONLY=1`),
  otherwise every Cata Extra id collides with itself and gets reallocated, silently
  putting the SQL out of step with the DBCs already shipped.

### 5c. Horde Hauler / Horde Coffin Hauler rendering in fragments — FIXED

Entries 4144731 / 4144764, both display 31290, which is faithful to Cata. Not a
geoset problem: the skin's 6 submeshes are all geoset id 0, so `CreatureGeosetData = 0`
is correct and must not be "fixed". The M2 references its textures by **bare
filename**, resolved against the model's own directory, and
`Creature\HordeCaravan\SMOOTHREFLECT.BLP` was never packed — so the submeshes using
that environment map did not draw. Packed into patch-G (3,916 B, verified).
`smoothreflect.blp` is a **per-model** texture that ships beside dozens of models.

**The whole downport was swept for the same defect and is otherwise clean.** All
1,622 DC custom-band models (CreatureModelData ID >= 500000) had their M2 read and
every hardcoded texture resolved: exactly one other miss,
`world\expansion04\doodads\pandaren\corruption_scroll.blp` used by
`Creature\greaterslime\greaterslime_corrupted.m2`, also packed into patch-G. Both
verified present from a fresh process.

One unrelated pre-existing find, **not** fixed because it is not blind-fixable:
CreatureModelData ids **500101-500108** point at `Creature\pandaren\Panda{Male,Female}.M2`,
which exists in no archive. The real Pandaren models are at
`Character\Pandaren\{Male,Female}\Pandaren{Male,Female}.M2` in patch-7, but those are
baked-character models needing CreatureDisplayInfoExtra — the original intent was
probably a MONSTER-slot bake copied into `Creature\pandaren\` that never got packed.

### 5e. Post-deploy state — verified 2026-08-19 after SQL + server DBCs + restart

Model and vehicle errors are **closed**. The live DB reports **0** templates in the
band without a resolvable display (241 before `76_`), all 12 vehicles and 33 seats
are in the overlay tables, and the server's own DBCs read back at
CreatureDisplayInfo 29,020 / Extra 16,779 / ModelData 2,987 / Vehicle 508.

**`Errors.log` accumulates across restarts** — it is a history, not the current boot.
It still shows ~50 "has SmartAI enabled but no SmartAI entries" lines for band
entries that demonstrably have their rows now; those predate `66_`. Confirm any log
line against the database before acting on it.

**Apply `77_cauldron_lord_smartai.sql`** — one line WAS current, and it came from
`74_`: cloning the Cauldron Lords with `SELECT *` carried `AIName` across, but
11076's four `smart_scripts` rows were not cloned, so 3611076 Razarch booted with
SmartAI enabled and no script and lost his combat behaviour entirely. `77_` clones
the four rows plus his `creature_text` (keyed by CreatureID, so the clone needs its
own). 3611075/3611077 are fine — empty `AIName`, and stock has no SmartAI for them.

Note for future clones: **a `SELECT *` template clone obliges you to clone
`smart_scripts`, `creature_text` and the other entry-keyed side tables too, or to
clear `AIName`.**

Left alone deliberately, all minor:
- 7 SmartAI CAST rows use Cata-only spells (80170/80171 cosmetic "Zap!" on Apothecary
  Surlis; 93446 "Raise Undead" on Aradne). AC skips the action and runs the rest.
  Downporting them means touching Spell.dbc, which risks the effect-id ≥165 boot
  abort — not worth it for cosmetics.
- 3611078 Soulwrath has 2 authored SmartAI rows (spells 80132/85800, both absent) but
  an empty `AIName`, so they never run. Pre-existing; enabling it would only add two
  more errors.
- 12 `SMART_ACTION_WP_START` rows pass `action_param1 = 0`, which legitimately means
  "use the creature's own path".

### 5f. Cata shader batches — why downported models render in pieces (2026-08-19)

The Horde Haulers were never a texture or model problem. **A 3.3.5 client silently
drops any M2 `.skin` batch whose `shader_id` has the 0x8000 bit set** (Cataclysm's
newer combiner encoding) — no error, no placeholder, the batch just never draws. The
Haulers' four body batches are 2-texture Cata batches (diffuse + SMOOTHREFLECT
env-map); only their two 1-texture batches survived, which is the pair of floating
panels in the screenshots.

This is **systemic, not local**. Sweeping all 1,636 DC custom-band models:

| | count |
|---|---|
| clean | 535 |
| **affected** | **1,066** |
| batches dropped | 4,287 across 1,439 `.skin` files |

Some are 100% dropped and therefore fully invisible: `koboldmale` 48/48,
`azsharanaga` 46/46, `drogbar` 27/27, `gargoyle2` 26/26, `abominationsmall` 24/24.

Fixer: `Custom/Documentation/scripts/fix_cata_shader_batches.py --scan|--fix <dir>`.
Per affected batch it sets `shader_id -> 0`, `textureCount -> 1`, and clears the
0x80 flag bit. Blend mode comes from the batch's `materialIndex`, not the shader id,
so transparency and additive glows are preserved — only the combiner changes.

**SWEPT AND CLOSED 2026-08-19.** All 1,428 affected `.skin` files repaired and packed
back into the archive each was read from (patch-D 1, patch-G 724, patch-H 703):
**4,245 batches fixed, 0 problems**. Fresh-process re-scan reports **0 models
affected, 1,619 clean** (was 539). Write each file back to the archive it was READ
from, not to a routing default, or the repair lands in a shadowed layer.

**`wxl-baker --native-m2` does not fix this** — it finalizes the M2 header but copies
`.skin` files verbatim (they show under "copied" in the bake log). Run the fixer after
every bake.

### 5g. Factions — 7 missing FactionTemplate ids

18 imported templates referenced FactionTemplate 2166, 2207, 2261, 2293, 2294, 2322,
2357, none of which existed here, so the Bloodfang worgen pack, the Revantusk and
Wildhammer NPCs, High Warlord Cromush, Captain Crudbeard and the Blight Slime all
fell back to a default faction — wrong hostility and PvP behaviour.

**Apply `78_factions.sql`.** Generated by `gen_map751_factions.py` from the Cata
client. FactionTemplate.dbc is 14 fields in both versions with the same order, so
those rows copy verbatim. Only one parent Faction was missing (1179 "Slime",
ReputationIndex −1, so no reputation bar); the other six point at factions this
client already has. Faction.dbc DOES differ (Cata 26 fields with single-string
name/description vs our 57 with 16-locale blocks), so the name is written into
`Name_Lang_enUS` with the locale mask copied from existing rows.

Client side already deployed and verified: FactionTemplate.csv 897→904,
Faction.csv 411→412, recompiled and written to patch-4 and patch-enGB-3.

### 5h. Flight map — `TaxiMap751.blp` now exists

The flight-master gossip worked but the map was blank: the taxi frame draws
`Interface\TaxiFrame\TaxiMap<mapId>.blp` and **only map 750 had one**.

Baked by `Custom/Documentation/scripts/bake_taximap751.js` from the 12
`Interface\WorldMap\Plaguelands\Plaguelands<n>.blp` tiles — 512×512 DXT1 with a full
mip chain, byte-for-byte the same shape as TaxiMap750.blp (175,948 B).

**The geometry change matters and the two must ship together.** The taxi frame
positions pins by linearly mapping WorldMapContinent's Taxi box onto a square image,
and map 751's box was 3200 (world X) × 5333 (world Y) — not square, so terrain would
have been badly distorted. `WorldMapContinent` id 10 is now squared to 5333×5333 by
widening the X range symmetrically about its centre (`TaxiMinX` 533 → −534,
`TaxiMaxX` 3733 → 4799), and the art is placed at the 60% of the image height it
actually occupies, letterboxed with the map's own edge tone.
Remember the axis convention: **world X is the image's VERTICAL extent** (top = higher
X), world Y the horizontal — so it is the X range that gets padded, not the Y.

`WorldMapContinent` is client-only (the worldserver never loads it), so there is no
SQL for this — just the DBC, deployed to patch-4 + patch-enGB-3 + the candidate sync,
and `TaxiMap751.blp` into patch-5 alongside 750's.

### 5i. The Haulers are rideable transports — `npc_spellclick_spells` was never imported

**Apply `79_hauler_transport.sql`.** Generated by `gen_map751_hauler_transport.py`.

`4144731` Horde Hauler is a free self-driving passenger wagon on the Silverpine road
(Forsaken High Command → The Sepulcher → The Forsaken Front); `4144764` Horde Coffin
Hauler is the corpse-wagon going the other way. Blizzard's conductor dialogue is
already in our `broadcast_text` (44796/44797/44788/44790). The **player is a
passenger, not the driver** — no seat of Vehicle 1048/1049 has
`VEHICLE_SEAT_FLAG_CAN_CONTROL` (0x800).

**Why they were inert, and it is systemic:** `npcflag = 16777216` (0x01000000) is
`UNIT_NPC_FLAG_SPELLCLICK` (UnitDefines.h:346), **not** PLAYER_VEHICLE (0x02000000,
:347). `ObjectMgr.cpp:8633-8636` strips the flag from any template that has it with
no `npc_spellclick_spells` row, after which the bit never leaves the server — no
cursor, no boarding. **The import copied ZERO spellclick rows for the entire
`entry >= 4,000,000` band** while cata_world has them. Six templates are affected:
the two haulers plus 4138933 Briny Sea Cucumber, 4144776 Sharpbeak, 4153517 Squirming
Slime Mold, 4153526 Brightwater Snail. **Check `npc_spellclick_spells` on every
future creature import.**

`79_` transposes TrinityCore's own implementation
(`zone_silverpine_forest.cpp` `npc_silverpine_horde_hauler`, plus
`sql/old/9.x/world/22082_2022_11_20/2022_10_01_01_world.sql`) and covers: the 2
spellclick rows, 7 `vehicle_template_accessory` crew rows, 4 `vehicle_seat_addon`
rows, the 63-node route as `waypoint_data` 447310, `creature_addon.path_id` +
`MovementType=2` on the one real spawn, 4 `creature_text` rows for the conductor, and
`CombatReach` 1.5 → 4 on display 31290.

Five things worth knowing before touching this again:
- Cata's click spell **86807 does not exist in 3.3.5**; `79_` substitutes **46598**
  "Ride Vehicle Hardcoded". That is only safe because both entries have a real
  `VehicleId` — `HandleAuraControlVehicle` bails on `!target->IsVehicle()`, so 46598
  on a non-vehicle is a silently dead click. **Do not apply it to the other four.**
- `vehicle_template_accessory` rows are **rejected unless the entry already has a
  spellclick row** (ObjectMgr.cpp:4101-4106), so section 1 must land before section 2.
- TC's seat-2 accessory row has `accessory_entry = 0` (the player's slot); ObjectMgr
  rejects a 0 accessory, and omitting it leaves seat 2 free — which is where the
  player ends up anyway.
- **The route needs no coordinate transform.** TC node 5
  (1376.23, 828.832, 48.75095) is byte-identical to our spawn guid 16719448. 63
  nodes, 2,163 yards, delays on nodes 11/35/60 are the three stops.
- **Do not set `AIName='SmartAI'`** — it would displace the `VehicleAI` these already
  run (`CombatAI.cpp:334-340`, `CreatureAISelector.cpp:63-65`). A DB path is started
  by `Motion_Initialize` (Creature.cpp:1114) *before* AI selection (:1116), so no AI
  change is needed at all.

Section 8 of `79_` is a **commented-out** DELETE for four of the five hauler spawns:
they are sniffer captures of one moving wagon (guid 16719448 sits exactly on route
node 5, and each faces the travel heading), so left in place you get five wagons
where there should be one. Uncomment only if you want the route rather than scenery.

Not included, and optional: TrinityCore's C++ script adds the stop yells and a
one-way despawn at the terminus. Without it the wagon simply cycles the route, which
is arguably better for a live server — but it needs a worldserver rebuild, so it is
left out.

### 5j. The rest of the spell-click damage — `80_spellclick_repair.sql`

The Hauler investigation exposed the same failure in two other places. **Apply
`80_spellclick_repair.sql`.**

- **map 750 substitutions.** Its import DID bring the 55 spellclick rows across, but
  five of their spells are Cata-only and absent here, so those rows are rejected at
  load. Two of the affected creatures have a real `VehicleId` and can safely take
  46598: **3636437 Rocketway Rat** (VehicleId 519, 7 spawns — currently unrideable)
  and **3640250 Treetop** (VehicleId 734).
- **8 redundant rows dropped.** Flame Protection Rune (3652884-3652890, 3653887)
  carries both 97773 (exists) and 97885 (does not). The 97773 row already keeps the
  flag alive, so these work — removing the 97885 rows is purely cosmetic.
- **4 map-751 props de-flagged.** Briny Sea Cucumber (38 spawns), Sharpbeak,
  Squirming Slime Mold (43), Brightwater Snail (34) need Cata spells 73123 / 94120 /
  99325 / 99356, none of which exist, and none has a `VehicleId` so 46598 is not a
  valid substitute. The core already strips their flag every boot, so clearing it in
  the DB changes no behaviour — it just stops four error lines. **Leaving them
  unclickable is deliberate:** the three gatherables carry SmartAI that despawns the
  node on click, so a click without the real spell would consume the node and grant
  nothing, which is worse than an inert prop.

Left unfixed on purpose, both still logging: **3639619 Twilight Recruit** (8 spawns)
needs spell 90102 and **3652177 Child of Tortolla** needs 96504. Neither has a
`VehicleId`, so there is no safe substitute, and clearing the flag would hide a real
content gap on a creature with live spawns.

Downporting any of those spells means reassembling from the Cata client, where
Spell.dbc is **48 fields split across SpellEffect/SpellMisc/etc** versus our
234-field single table — and the effect-id >= 165 boot abort applies.

### 5k. Flight masters showed an empty gossip — the C++ node table

**Requires a worldserver rebuild** (as does `AddSC_dc_western_plaguelands`).

DC does not use the client taxi map on custom continents:
`src/server/scripts/DC/AC/dc_downport_taxi.cpp` (`npc_dc_downport_flightmaster`)
lists destinations as gossip and flies with `ActivateTaxiPathTo`. `CurrentNode()`
resolves the departure node by matching the creature's position against its own
hardcoded `kNodes` table within `MAX_NODE_DISTANCE = 100` yards, returning nullptr
beyond that — which yields an empty gossip list and no error anywhere.

The 19 Lordaeron nodes (368-374, 378, 385-391, 396-399) were added to TaxiNodes.dbc
with the extension but never to `kNodes`, so **19 of the 32 map-751 flight masters
resolved to nullptr** — Karos Razok sat 2,965 yards from the nearest listed node.
The 19 rows are now added; measured 32/32 resolve. Table is 58 entries (27 on
map 750, 31 on 751).

**Adding a taxi node to the DBCs is only half the job on maps 750/751.** The DB and
DBC side was entirely healthy here and cost a long detour to rule out: npcflag,
gossip_menu_option 4281/0, conditions, node distance, mount ids, `sTaxiNodesMask`,
TaxiPath/TaxiPathNode coverage and the character's taximask all checked out.

Note this also means `TaxiMap751.blp` and the squared WorldMapContinent box from
§5h are not what drives these flight masters — they matter only if the native taxi
frame is ever used instead of the gossip list.

### 5l. Hauler crew doubled / wagon not moving — `81_hauler_spawn_cleanup.sql`

Both are consequences of leaving the sniffer captures in place, and both are
expected rather than new bugs:

- **Doubled crew.** Every captured wagon position carries its OWN loose crew cluster
  (Engineer + 5 Troopers + Ettin). Once `79_` seats a crew as vehicle accessories on
  the surviving wagon, the loose copy standing beside it is a second set — the two
  stacked "Subdued Forest Ettin" nameplates.
- **Not moving.** Only guid **16716000** received `MovementType = 2` + `path_id`;
  the other four are parked captures, so whichever wagon you stand next to is most
  likely one of those.

**Apply `81_hauler_spawn_cleanup.sql`** — it deletes the four captured wagons, their
four crew clusters, the redundant crew beside the survivor, and the orphaned cluster
at (-60.9, 1184.4) that sits 205 yards from any wagon. After it there is exactly one
Horde Hauler, driving route 447310 with its crew in the seats. It supersedes the
commented-out section 8 of `79_`.

### 5m. Lighting, subzones and water — the three follow-ups (2026-08-19)

**Lighting / skybox — DONE.** `gen_map751_lighting.py`. Map 751 went from **2 Light
rows to 73**, transplanted from Cata continent 0 with coordinates untouched (751 is
a coordinate-preserving EK copy): 71 lights, 19 new LightParams, +342 LightIntBand,
+114 LightFloatBand. The only skybox in this footprint is `StratholmeSkybox` —
Lordaeron has no distinctive skies the way Hyjal did, so the visible win is per-zone
colour and fog. No LightSkybox rows or art needed (already id 1; ships stock).
Note `csv2wdbc.py` **cannot** build LightIntBand/LightFloatBand — neither table is in
the WDBX definitions, which is why earlier light work edited DBCs in place and
drifted from the CSVs. Use `append_band_dbc.py`, which keeps the CSV authoritative.

**Subzones / exploration — DONE.** `gen_map751_subzones.py`. **8 AreaTable rows ->
223** (8 zones + **215 subzones**), **191 ADTs retagged, 29,442 chunks**. Ids
16604-16818, AreaBits 2458-2758. WorldMapOverlay was a red herring — map 750 has
zero overlay rows too; what it has is 204 subzones.
Key points: Cata's `Azeroth_<x>_<y>.adt` is coordinate-aligned with ours so the
layout reads straight off it; 161 of 215 already existed as stock EK subzones and
were cloned for their technical fields; but the **name always comes from Cata**,
because 10 were renamed by the Shattering (stock "Southshore" is Cata "Ruins of
Southshore", "Hillsbrad Fields" is "The Sludge Fields").
**Copy `Custom/DBCs/AreaTable.dbc` to the server's `data/dbc`** — the worldserver
resolves zone/area ids from its own copy.

**Water — investigated, NOT a map-751 defect.** 8,481 of 17,775 liquid chunks carry
a uniform depth byte of 255, but recomputing every one from its own MCVT rewrote
only **30** — the rest genuinely are >=31 yd deep, where the byte saturates. Map 750
has the same profile (65% uniform-255 vs 751's 48%) and has never been reported as
wrong, so the MH2O depth channel is not what makes the shorelines look opaque. The
30 real fixes were packed. If it still looks wrong, investigate LiquidType material
or client water settings, not the terrain data.

### 5d. Wandering — healthy, just thinner than it could be

Map 751 sits at **37.3%** `MovementType = 1`, with **0** rows that have MT=1 and a
zero wander distance and only 2 harmless MT=0-with-distance rows. Nothing is broken.
The dip is a source choice: the spawn import took movement from `cata_world` (31.6%
for these zones) while `nelt_world` has **54.9%**. The legacy 751 content is near 50%
because `277_` enriched it from nelt. Running the same position-matched enrichment
over the new spawns would bring the new zones to parity — optional polish.

### 5n. Second error pass — `86_smartai_repairs.sql` + `87_data_table_gaps.sql`

Read from the boot after the 85_ restart. Two more tables turned out never to have
been imported, which is now a confirmed *pattern* rather than a coincidence:
`npc_spellclick_spells` (80_), `creature_text` (82_), and now `waypoints` and
`creature_equip_template`. **Any future import of this shape should be checked
table-by-table against what `creature`/`creature_template` reference, not just
spot-checked for errors.**

Volume in the last 2000 log lines: 984 equipment, 171 SmartAI, 11 pool, 9
gameobject, 8 battlemaster, 4 loot, 1 OutdoorPvP.

**Apply `86_smartai_repairs.sql`** — clears ~45 of the 171 SmartAI errors.

- **`waypoints` was never imported.** Action 53 validates against
  `sSmartWaypointMgr` = the **`waypoints`** table, *not* `waypoint_data` (which is
  what `70_` and `79_` populate — two systems, confusingly similar names). The path
  id is **`action_param2`**, not param1. 14 paths / 214 points, imported at
  **+4,100,000** rather than verbatim because 5 of the 14 ids already exist as
  *stock* paths (5662, 5697, 6176, 36217, 61760). For 6176 ours is 7 points and
  Cata's is 14 — that creature has been walking a stock route with **no error
  logged at all**.
- **The half that is easy to miss:** the escort *events* (40/55/56/57/58) carry the
  same path id in **`event_param2`**, compared at runtime against `GetPathId()`.
  Remap the action without the events and every "on waypoint N reached" trigger
  silently stops firing — strictly worse than the original bug. 15 rows.
  Events 108/109 and 34 also hold a path id but theirs is `GetWaypointPath()`
  (`waypoint_data`) — do **not** remap those. Event 39 is excluded: the core
  compares its param2 against the *point* id (`SmartScript.cpp:4631`).
- **A Cata/WotLK param-layout divergence**, found via the "pct value above 100"
  row. AC's `SMART_EVENT_FRIENDLY_HEALTH_PCT` (74) is
  `{min, max, repeatMin, repeatMax, hpPct, radius}`; Cata's is shifted one slot.
  Stock AC carries the same row for the un-remapped creature, so the correct
  values were copied rather than guessed. Only 1 event-74 row exists in the band —
  but had the shifted value landed under 100 it would have passed validation and
  been **silently wrong**. Worth remembering for other event types.
- 19 rows rejected wholesale for a stray param the event's struct does not cover
  (`CheckUnusedEventParams` is a pure `sizeof` check, `SmartScriptMgr.cpp:609-732`).

**Apply `87_data_table_gaps.sql`** — clears ~1010 lines, most of the log.

- **`creature_equip_template` was never imported** for map 751: 2,499 spawns /
  547 entries standing around empty-handed. Map 750 is unaffected. Schemas are
  identical, and all 230 referenced item ids already exist, so it is a clean copy
  with no follow-on errors.
- 9 Undercity elevator GOs were **skipped entirely** (not spawned) for `state = 24`,
  a Cata GOState. The same nine entries exist in stock WotLK at `state 1 /
  animprogress 100`; those values were copied, not invented.
- 8 battlemasters with the flag and no `battlemaster_entry`. 6 map to BGs this core
  runs and are wired up (**behaviour change** — they become functional); 2 map to
  Cata's Rated BG (120), which has a DBC row but no core implementation, so their
  flag is cleared instead.
- Loot 4101531 >100%: the 100% Wispy Cloak is **stock AC's own data**; the import
  only added 5 reference rows that can never be reached behind it. Deleted.
- Pool 130008297 is a fully orphaned Hyjal leftover.

### 5o. The spell downport and the missing creatures — `88_` + `89_`

Both of the classes 5n left open are now closed. **Apply in order: 88_ then 89_**
(89_'s scripts cast two spells 88_ adds).

**`88_spell_dbc.sql` — 144 Cata spells.** Generated by
`Custom/Documentation/scripts/gen_map751_spell_dbc.py`, adapted from
`Deepholm/tools/spell_downport.py`.

**IT IS A DB CHANGE, NOT A CLIENT REBUILD** — the earlier note that this "needs the
Spell.dbc downport, not a DB change" had it backwards. This fork's worldserver loads
spells from **`acore_world.spell_dbc`**, a 234-column runtime table merged over the
file (`LOAD_DBC` → `DBCStorage::LoadFromDB` → `DBCDatabaseLoader::Load`), which is
exactly what `50_`/`51_`/`53_`/`59_` already use. The client half (tooltips, cast
bars) is emitted to `k:/tmp/map751_spells_review.csv` for the next DBC rebuild but is
**not** applied — these are NPC abilities, and the damage comes from the server.

- **Finding every spell reference took reading the core, not the log.** `spell` is
  field 1 of its struct in each case. Actions: **11, 28, 75, 85, 86, 134, 218**
  (`action_param1`). Events: **8 SPELLHIT, 16, 23, 24** (`event_param1`) and
  **13 VICTIM_CASTING** (`event_param3`). Plus `creature_template_spell.Spell`,
  `npc_spellclick_spells.spell_id`, and the space-separated `auras` strings on
  `creature_addon` / `creature_template_addon` — the auras columns alone held 42 of
  the 144.
- **ACTION 80 IS NOT A SPELL ACTION.** It is `CALL_TIMED_ACTIONLIST` and its param1
  is an action-list id (entry×100). The log reads *"Action 80 uses non-existent Spell
  entry 73108"* because the message prints the ACTION type while the spell came from
  the row's EVENT. Treating param1 as a spell puts ids like `410154300` in the list —
  which is how the mistake was caught. Same for actions 37/41.
- Clean boundary: everything ≤ 70846 already existed; the missing set starts at
  70956 and is entirely Cata-era.
- **Two clamps stop a boot crash** (effect ≥165 → 0, aura ≥317 → 0; only 2 rows hit
  them: 81140 aura 319, 91683 effect 167). Index fields (CastTimes/Duration/Range/
  Radius) are remapped **by value**, not by id — the clients renumber those tables.
- Column mapping verified against a spell an earlier step already loaded:
  `spell_dbc` = `csv[0:13] + '0' + csv[13] + '0' + csv[14:]`, so CSV col N → col N+2
  for N ≥ 15. `Effect_1` is at 72, the name at 137 (`Name_Lang_enUS`, not
  `Name_Lang_enGB`), and the aura column is **`EffectAura_1`**, not
  `EffectApplyAuraName_1`.

**`89_missing_referenced_creatures.sql` — 44 templates + their side tables.**
The class turned out to be far bigger than the 5 first found: **49 more are
referenced by quest objectives**, same root cause `46_` documented — the import joins
on static spawns and 41 of these have none in Cata.

- **Imported at PLAIN Cata ids, not +4,100,000** — the opposite of `86_`, deliberately.
  Every reference already uses the plain id (6 quest rows point at 44175, none at
  4144175), and the band's quest layer is already mixed (75 quests remapped, 38
  plain). All 44 ids were verified free.
- Our `creature_template` is **55 columns to Cata's 84** — no `SELECT *`. The 6
  columns Cata lacks take the value all 1,127 existing band templates use.
- **Four guards, written as CASE expressions** so the rows are never briefly wrong:
  AIName kept only if scripts actually exist (**blanks exactly 1** — the `77_` trap),
  ScriptName blanked (Cata names TC scripts this core lacks), VehicleId dropped
  unless in `vehicle_dbc`, loot ids dropped unless the template exists.
- Side tables brought along, because that is the lesson of this whole pass:
  `creature_template_model` (62), `creature_template_addon` (44),
  `creature_equip_template` (8), `creature_text` (18), `smart_scripts` (24).
  `creature_template_addon` needed repacking — Cata stores StandState/AnimTier/
  VisFlags/SheathState/PvPFlags separately where 3.3.5 packs `bytes1`/`bytes2`;
  verified against 1,000+ imported rows that `bytes2 = SheathState + (PvPFlags << 8)`
  (Cata SheathState 2 → our 258).
- **5 displays were absent, all belonging to credit/proxy bunnies** (44175, 45495,
  and the six PvG credits) — substituted with **11686**, this core's canonical
  invisible-trigger display. That substitution is exactly sufficient: the displays
  lacking a `creature_model_info` row are precisely those five.
- **9 real NPCs are deferred** because their display needs the retroport pipeline
  first — Spirit of Devlin Agamand, Shadra, Lord Godfrey, Garrosh Hellscream, Orc
  Crate, Hillsbrad Worgen, Johnny Awesome, Kingslayer Orkus, Valdred Moray. Same
  reason `46_` deferred "Mobus". Their display ids are listed in the file; add them
  to the id lists and re-run once staged.

### 5p. The 9 deferred NPCs — `90_creature_displays_batch2.sql`, art DEPLOYED

`89_` held back 9 real NPCs whose displays were missing. All 12 of those displays now
ship, and `89_` has been rewritten to import **53** templates instead of 44.
**Apply order: 88_ → 90_ → 89_** (89_'s creatures need 90_'s displays).

Generator: `Custom/Documentation/scripts/gen_map751_creature_displays_batch2.py`,
planner `scratchpad/plan_displays2.py`. It is a SEPARATE script on purpose:
`gen_map751_creature_displays.py` takes its baseline from the
`.pre_map751_displays.bak` copies it wrote, so re-running it with a new plan would
rewrite the CSVs as baseline+12 and **destroy the 303 rows 76_ appended**.

**The worgen route from 76_ was unnecessary.** 76_ rebound its 34 worgen onto the DC
WorgenNPC model copies (500961/500962) with the bake in TextureVariation_1, because
Cata's `DisplayRaceID = 22` has no ChrRaces row. But **WotLK's ChrRaces already has an
NPC worgen race at id 12**, and DC's own worgen NPCs use it — displays 32722/36154
(male) and 33679/36161 (female) sit on stock models 3141/3142 with `DisplayRaceID = 12`
and render correctly today. Batch 2 just remaps **22 → 12** and keeps the stock model:
no rebinding, no MONSTER-slot bake copy, no white-render risk. Worth applying to 76_'s
34 if they ever look wrong.

**model_info is now derived by scale, not by first-non-zero sibling.** The relationship
is linear — on the giant-spider model BoundingRadius equals the display scale exactly
(15928: 8.7/8.7/20.01, 16462: 1.4/1.4/3.22, 17180: 3.48/3.48/8.004) — so batch 2 picks
the sibling whose scale is NEAREST and rescales both values. Identical to 76_'s result
for the scale-1.0 humanoids; different for Shadra (8.0 → 8.0/18.4), the Hillsbrad
Worgen (2.0 → 0.812/3.0) and the Orc Crate (0.5 → 0.27/0.5).

**11 of 12 needed no art at all** — they reuse models the DC client already ships.
All 8 bakes were present in the Cata client and all TextureVariation .blp files were
already in DC.

**Garrosh was the one exception.** `CREATURE\GARROSH\GARROSH.M2` is absent from DC
(the existing DC Garroshes are baked orc characters on model 51, not the Cata
Warchief model). Staged 53 files from the Cata client — M2, 2 skins, 3 textures,
47 `.anim` — and baked with
`wxl-baker --deps --native-m2` to MD20 **v264**. Notes:
- 6 `.anim` files it asked for do not exist in the Cata client either; same
  "ships nowhere" class 76_ hit with 18 of its 182.
- globalFlags `0x80` — the `0x8` combiner-combos crash bit is not set.
- **7 of its 11 `.skin` batches carried Cata's `0x8000` shader ids**, which a 3.3.5
  client silently drops; repaired with `fix_cata_shader_batches.py --fix` (0 remain).
  Without that Garrosh would have rendered in pieces.

**Deployed and verified from a fresh process:**
- patch-G: 52 files (Garrosh tree; `OrbReflect.blp` skipped, already in patch.MPQ)
- patch-7: the 8 bakes, all readable as BLP2
- patch-4 + patch-enGB-3: CreatureDisplayInfo 29032, Extra 16787, ModelData 2988
- crosschecked `90_`'s SQL against the SHIPPED patch-enGB-3 DBCs: **0 mismatches**,
  all 4 worgen extras confirmed on race 12

The server half is the `*_dbc` overlay in `90_` — no server-side file copy needed.

**Still open.**

- Quest validation errors referencing Cata **items** — a separate downport.
- 38 band quests still reference creatures by plain Cata id where the creature was
  imported at +4,100,000. Not errors today (`89_` covers the ones that were), but the
  mixed convention is worth normalising someday.
- `OutdoorPvP` type ID 8 has no `outdoorpvp_template` row (1 line, pre-existing).

### 5q. Vendors, trainers, quest POIs, rares — `91_`, `92_`, `93_`

**`91_vendors_and_trainers.sql`** — 1,969 `npc_vendor` rows across 142 vendors;
43 trainers imported at +410,000; 1,997 `trainer_spell`; 82 `creature_default_trainer`;
the Adam Hossack npcflag strip.

Two traps, both caught before shipping:

- **Class trainers need `Requirement` 1..MAX_CLASSES.** Cata's rows carry
  `Requirement = 0` for `Type = 0`, which our core rejects with *"Table `trainer` has
  invalid class requirement for trainer {}"* — 17 of the 43. The fix is an explicit
  `CASE` deriving the class from the creature subname, not a copy of the source value.
- **67 vendor rows were dropped** because they sell Cata items we did not have.
  `94_` builds those items; the 67 rows are worth a re-run afterwards.

**`92_quest_poi.sql`** — 857 blobs / 2,994 points for the 402 quests exclusive to
map 751. `quest_poi` had **zero** rows for MapID 751. Two things shape the file:

- `quest_poi` is keyed by QuestID with no per-map variant, so a quest can only have
  **one** set of POIs. 337 map-751 quests are also handed out by stock Eastern
  Kingdoms NPCs and are deliberately **left alone** — repointing them would move the
  marker off the stock copy.
- The zone is decided by **the centroid of each blob's own points** against the eight
  zone boxes, smallest box first. Cata renumbered WorldMapArea, so translating ids was
  not an option; a centroid test is self-checking — a blob outside Lordaeron simply
  does not import.
- Column trap: cata `quest_poi` has both `BlobIndex` and `Idx1` and **they differ on
  100 rows inside this selection**. Our `id` must come from `Idx1`, which is what
  `quest_poi_points.Idx1` joins against. Taking `BlobIndex` orphans every point.

**`93_rare_spawn_tracking.sql`** — there is no rare-POI table to regenerate. Rares are
handled by the C++ `RareSpawnAnnounce` system, and the real blocker is one config line:
`RareSpawn.Announce.Maps` defaults to `"750,37"`, so map 751 is invisible to it.

```
RareSpawn.Announce.Maps = "750,751,37"
```

The optional UPDATE in the file raises 51 rares from 300s to 14400s so they clear the
announcer's 3600s floor. That 300 is **faithful to Cata**, not an import defect, so it
is fenced off as tuning rather than folded in.

### 5r. The item downport — `94_item_template.sql`

184 of the 185 missing Cata items (68647 is absent from Item-sparse and was not built).
This clears the ~200 quest-validation lines and unblocks `91_`'s 67 dropped vendor rows.

**No database has these items.** `cata_world` has no `item_template`, `nelt_world` has
2 of the 185, `cata_hotfix` 1, `bfa_hotfixes` 0. The source is the Cata 4.3.4 **client**:
`Item.db2` (64,771 recs, 8 fields) + `Item-sparse.db2` (54,082 recs, 133 fields), read
with a WDB2 reader in `gen_map751_item_template.py`.

**The Item-sparse layout was derived empirically, then validated against the live DB.**
The check that matters: 149 items present in *both* the Cata client and our 3.3.5
`item_template`, compared field by field on the values that should not drift across
expansions —

| field | agreement |
|---|---|
| InventoryType | 149/149 |
| itemset | 149/149 |
| startquest | 149/149 |
| bonding | 148/149 |
| stackable | 144/149 |
| Material | 118/149 |
| MaxDurability | 77/149 |

`Quality`/`ItemLevel`/`RequiredLevel`/`SellPrice` are deliberately excluded — Cata
re-levelled and re-priced old items, so disagreement there is content drift, not a
layout error.

The two low rows were both run down rather than accepted:

- **Material** — the only two mismatch classes are `cata 0 → live -1` (28) and
  `cata 4 → live -1` (3). The client writes `0` where 3.3.5 conventionally writes `-1`.
  **Not remapped**: live rows use both `0` and `-1` for the same client value, so there
  is no safe rule, and Material only picks the pickup/drop sound.
- **MaxDurability** — field 114 was the wrong guess; it reads 0 for all 54,082 records.
  Probing all 133 fields found **no** durability field at all: the only fields non-zero
  for every armour piece and zero for every quest item are BuyPrice, SellPrice,
  InventoryType and Material, all already mapped. **Cata's item-sparse genuinely has no
  durability**, same as armor and weapon damage — 4.3.4 computes them from scaling DBCs.

So `94_` ends with **two** UPDATEs, both deriving from our own stock curve rather than
importing Cata's (which is not the curve a WotLK gear economy sits on): each piece takes
the value of stock 3.3.5 items with the same class/subclass/slot/quality at the nearest
item level. Verified deterministic — `min == max` for every group in range. The
`s.<col> > 0` filter is self-selecting, so cloaks/rings/necks correctly keep 0.
In this batch armor touches 26 pieces and durability exactly 2 (59253, 59295).

**76 of the item-carried spells were not in `88_`** — the 88003–88047 cooking-recipe
block plus on-equip and consumable effects. Without them the recipes teach nothing and
the core logs *"Item (Entry: N) has wrong spellid"*. They were folded into `88_`, which
is now **220 spells, not 144** — re-apply it if the 144-spell version was already run.

**Client-side half deliberately NOT done here**: 77 of the 142 distinct displayids are
missing from our `ItemDisplayInfo`, so those items show a default icon until the display
rows and their icon BLPs are ported. The server side is independent — the quests become
completable either way. This is the next piece of item work.

#### 5r-fix. Three apply-time failures in the first `94_`, and what they taught

The first `94_` was handed over with a validated field map and still failed at apply.
All three are worth keeping, because the first one was caused by a *correct* discovery.

**1264 Out of range for column `Map` at row 169.** Establishing that Item-sparse has no
`MaxDurability` was right — but the map still *listed* one at field 114, and the fix for
"no durability" was to emit 0, not to remove the entry. So every field below 114 stayed
shifted by one: `Area`'s value shipped as MaxDurability, and `BagFamily`'s bitmask (4096,
32768) shipped as `Map`, a signed smallint. **A field that does not exist must be deleted
from the map, not zero-filled** — zero-filling keeps the shift and hides it, because the
phantom field reads plausibly (114 is `Area`, which is 0 on almost every item).

Re-derived against live ground truth. The tail is uniformly one lower than assumed:

| column | was | is |
|---|---|---|
| Area | 115 | **114** |
| Map | 116 | **115** |
| BagFamily | 117 | **116** |
| TotemCategory | 118 | **117** |
| SocketColor | 119 | **118** |
| SocketContent | 122 | **121** |
| SocketBonus | 125 | **124** |
| GemProperties | 126 | **125** |
| ArmorDamageModifier | 127 | **126** |
| Duration | 128 | **127** |
| ItemLimitCategory | 129 | **128** |
| HolidayId | 130 | **129** |

Everything at or below field 113 was re-checked at the same time and is correct — the
few sub-perfect scores are single-item Cata content drift with no better-scoring
alternative field. The confirmation that the shift was the whole story: `4096`/`32768`
now land in `BagFamily`, which is exactly the kind of value that column holds.

**1093 You can't specify target table 't' for update in FROM clause** (both UPDATEs).
MySQL forbids a correlated subquery over the table being updated. Rather than contort it
into a materialised derived table, the 23 needed `(class, subclass, slot, quality, ilvl)`
combos were resolved once and **baked into the INSERT as literals** (`CURVE` in the
generator). Both UPDATEs are gone. This is better anyway: the numbers are reviewable in
the diff and do not depend on DB state at apply time. Only 18 rows get armor and 2 get
durability. Rings and necks stay excluded — a few stock rings carry a stray armor value
and copying one would invent armor on a slot that has none.

**The guard that now exists.** `check_ranges()` holds `item_template`'s real column types
and refuses to write the file if any value exceeds its column — verified by injection.
This class of bug shipped twice; a validated *field map* does not imply a *valid row*.

**`95_item_dbc.sql` — the server-side Item.dbc half, new.** The live server `Item.dbc`
has 153,540 records and none of the 184. `item_dbc` is a runtime overlay merged over the
file at load, exactly like `spell_dbc`, and its 8 columns are Item.dbc's 8 — which
Item.db2 also carries. So this is a straight copy in SQL, with no DBC rebuild and no risk
of plain-copying over the server file. Cross-checked: `94_` and `95_` agree on all eight
shared fields for all 184 rows.

**Still client-side, still open**: the client reads its own `Item.dbc` (patch-4.MPQ) and
`ItemDisplayInfo` for icons; 77 of the 142 displayids have no `ItemDisplayInfo` row. And
`88_`'s 220 spells are server-side only — the client Spell.dbc rows for tooltips are
emitted as a CSV appendix (`k:/tmp/map751_spells_review.csv`) and not applied.

### 5s. Client DBC deploy for the item + spell downport — DONE 2026-08-20

Three tables rebuilt and deployed. `Custom/CSV DBC/*.csv` and `Custom/DBCs/*.dbc` are
both updated and agree row-for-row.

| table | before | after | change |
|---|---|---|---|
| Spell | 53,799 | **54,016** | +217 added, 3 replaced in place (71354, 89157, 89158) |
| Item | 153,540 | **153,724** | +184 |
| ItemDisplayInfo | 96,815 | **96,892** | +77 |

**`csv2wdbc.py` must NOT be used for Spell.** Its layout comes from the WDBXEditor
definitions, whose WotLK `Spell` table expands to **168 fields**. This fork's Spell.dbc is
a **234-field** custom layout and no definition file in dc-wdbx describes it (all 23
checked). Compiling would have silently rewritten a 234-field table as 168 and destroyed
it. `Item` (8) and `ItemDisplayInfo` (25) do match their definitions.

So Spell got a dedicated tool, `wow.export-main/tools/spell-dbc-append.py`, which appends
into the existing binary. The CSV↔DBC mapping it uses is the same one `88_` uses for the
SQL overlay and was proven before use — `dbc234 = csv[0:13] + [0] + csv[13] + [0] +
csv[14:]`, round-tripped over 7 stock spells for **0 of 1638 field disagreements**.

**ItemDisplayInfo turned out to be far smaller than flagged.** Cata 4.3.4's
`ItemDisplayInfo.dbc` is a plain WDBC with the *same* 25 fields / 100-byte records, so it
is a 1:1 row copy (validated: 200 shared ids, 98.86% field agreement, disagreements spread
thinly across 16 different fields = content drift, not a layout error). All 77 missing
displayids exist there, and — the useful part — **all 70 icons they reference are already
in the live client**, so no BLP extraction was needed at all.

**Every rebuild was verified to preserve the originals byte-for-byte**: 0 pre-existing
records changed or lost in any of the three. The pipeline's QA invariant holds — our 184
items contribute **0** dangling DisplayInfoIDs (5 pre-existing violations are unrelated).

**Deployed to both winning archives**, `patch-4.MPQ` and `patch-enGB-3.MPQ` — enGB shadows
root for DBCs, so patching only patch-4 would have changed nothing. Re-read from a fresh
process afterwards (MPQ writes can lie): both report 54,016 / 153,724 / 96,892.
`sync-dbc-deploy.js` run for the three WarcraftXLHost candidate dirs. End-to-end chain
checked out of the deployed archive: all 184 items resolve item → displayid →
ItemDisplayInfo row → a real icon.

**Server side.** The live server's `Spell.dbc` (53,799 / 234 / 936 / stringblock 2,535,080)
and `Item.dbc` (153,540) were **byte-identical to the baselines these were built from**, so
the rebuilt files are clean supersets and safe to copy to `data/dbc`. Doing so also makes
the question of whether `spell_dbc` / `item_dbc` are genuine runtime merges moot for these
two tables. ItemDisplayInfo is client-only.

Client restart required.

### 5t. Quest references pointing at things we do not have — `96_`

68 more validation lines, four groups. Three are fixed by making the data honest rather
than inventing content; each was traced to its source before deciding.

**Item 68647 — real fix.** The one item `94_` could not build. It is absent from the Cata
client's `Item-sparse.db2`, but it IS in `nelt_world.item_template` as a full 3.3.5 row:
"Dousing Agent", class 12, displayid 55112 — which our `ItemDisplayInfo` already has, so
no client art work. It blocks quest 29377 twice (StartItem + ItemDrop2). **Schema trap:
both tables have 138 columns but only 110 share a name**, so `SELECT *` would misalign;
the 110 are named explicitly and the 28 ours-only are zero-defaulted armor/damage/resist
fields meaningless to a quest item.

**ZoneOrSort — real fix, remap to the parent zone.** `4706 = Jintha'Alor` (11 quests) and
`5287 = Darkspear Strand` (1) are genuine Cata AreaTable rows 3.3.5 lacks. Rather than add
AreaTable rows — a DBC rebuild plus an AreaBit, and they would be the band's only subzone
sorts — they take their parents: 4706 → **47 The Hinterlands**, 5287 → **14 Durotar**. That
matches the convention already in force: every other map-751 quest sorts under a plain
stock zone id (47 ×67, 267 ×50, 45 ×38, 85 ×36, 130 ×19). 4706 was the only invalid one and
47 is where its 67 siblings already sort.

**RewardSpell — split.** Of 15 missing spells, **10 exist in the Cata 4.3.4 client** and were
added to `88_` (now **230 spells** — re-apply). The other five — 89550, 89669, 89781, 94710,
95818 — **do not exist in the 4.3.4 client at all**; they were removed before 4.3.4, so the
`cata_world` snapshot predates its own client. Nothing to downport, so the 7 affected
quests get `RewardSpell = 0`, which is what the core already does with an invalid id. They
are cosmetic/despawn helpers, not player abilities.

**RewardNextQuest — honest fix, 38 chains zeroed.** All 38 targets exist in `cata_world`
*and* have a questgiver there, so importing them was considered and rejected: **not one of
those questgivers has a spawn on map 751**, and 30 of 38 are absent from our
`creature_template` entirely. They live in Orgrimmar (Grezz Ragefist, Ormak Grimshot,
Zevrost, Master Pyreanor, Sunwalker Atohmo, Shadow-Walker Zuru), Moonglade (Loganaar),
Ragefire Chasm and Stranglethorn — Cata "report to your class trainer" follow-ups, i.e.
capital-city content. Importing them would have produced 38 quests nobody can pick up, and
grafting Cata quests onto stock Orgrimmar NPCs is what this project deliberately avoids
(same reason `92_` leaves 337 shared quests alone). Zeroing is behaviourally identical to
today and makes the data true.

Checked while there: quests **13980 and 14435 are not stock-content stomps** — 13980 is a
Molten Front quest and 14435 Cata Azshara; both match `cata_world` exactly. Low ids,
Cata content.

**Client DBCs re-deployed** for the 10 new spells and item 68647: Spell 54,016 → **54,026**,
Item 153,724 → **153,725**, in `Custom/CSV DBC/`, `Custom/DBCs/`, `patch-4.MPQ` and
`patch-enGB-3.MPQ`, re-read from a fresh process, `sync-dbc-deploy.js` run.

### 5u. Gameobject displays — `97_`, the GO half of the display gap

`Gameobject (... Entry 4808816 GoType: 3) has an invalid displayId (10615), not loaded.`
**146 spawns over 49 gameobject entries on map 751 never loaded at all.**

The pasted log was truncated, so the set was taken from the DB rather than the log:
every displayId used by a map-751 gameobject, tested against the live server DBC.
**Exactly 18 are missing** — 9140, 9141, 9146, 9342, 9374, 9375, 9376, 9539, 9667, 9883,
9943, 10014, 10216, 10237, 10238, 10241, 10414, 10615 — which matches the log's distinct
set, so nothing was hidden. **No gameobject on any other map uses them**, so the change
cannot disturb existing content.

**Layout: ours is Cata's first 19 fields.** Cata's `GameObjectDisplayInfo.dbc` is 21
fields / 84 bytes, ours 19 / 76. Verified rather than assumed, over 150 ids present in
both clients: fields 0–11 (ID, ModelName, Sound×10) and 18 (ObjectEffectPackageID) agree
**100%**; only the GeoBox floats (12–17) differ, on ~10% of rows — Blizzard recalculating
bounds between expansions. A layout error fails ~100% on specific fields; this is drift.
New rows take Cata's GeoBox since there is no stock value to preserve.

**No model work was needed.** All 18 referenced models — including the Cata-only
`expansion03` worgen and deepholm doodads — are **already in the live client** from earlier
downport passes. Confirmed by probing every live archive for each path as both `.mdx` and
`.m2`. That is the second time this pass that the art half turned out to be already done
(the 70 item icons were too); **check the assets before scoping asset work**.

Three halves shipped, because a display id has to exist in all three places:
`97_gameobject_displays.sql` (the `gameobjectdisplayinfo_dbc` overlay),
`Custom/CSV DBC/GameObjectDisplayInfo.csv`, and `Custom/DBCs/GameObjectDisplayInfo.dbc`
(46,910 → **46,928**, originals byte-identical). Deployed to `patch-4.MPQ` and
`patch-enGB-3.MPQ`, re-read from a fresh process, `sync-dbc-deploy.js` run.

**The overlay alone will not fix this.** The server reads its binary
`data/dbc/GameObjectDisplayInfo.dbc` to decide whether a spawn loads — proven for
CreatureDisplayInfo on 2026-08-02. **`Custom/DBCs/GameObjectDisplayInfo.dbc` must reach
the server's `data/dbc`**; the client patches only gate rendering.

### 5v. Exploration, zone selection and the flight map — one root cause (2026-08-20)

All three symptoms — no exploration paint, zone dropdown showing the wrong art, taxi pins
off — came down to **the WarcraftXLHost candidate dirs serving STALE worldmap DBCs** off
disk at client start, bypassing every MPQ deploy, plus one genuine data gap.

**What the client was actually reading** (all three candidate dirs, vs Master):

| table | candidates | Master | consequence |
|---|---|---|---|
| WorldMapContinent | old taxi box (-4281,-6319)-(5488,3450) | (-2667,-6400)-(3733,2667) | pins projected through the old box onto new art |
| WorldMapArea | 262 rows, 08-18 — map 751 = **1 zone** ("Plaguelands", 2-zone rect); rows 1268–1274 absent | 269 rows | engine cannot switch to any of the 7 new zones — the addon-populated dropdown changes, the view stays on the continent art (the old EK crop with the baked "WESTERN PLAGUELANDS" label = the screenshot) |
| WorldMapOverlay | 1505 rows | 1432 | see below |
| Map | 08-10 | 08-19 | stale map metadata |

Proven the honest way first: nodes, box and art were each individually verified correct
(client TaxiNodes identical to server; patch-4+enGB-3 both carry the new box; the deployed
TaxiMap751.blp is the current bake, single copy; a rendered projection of all 31 nodes
through the deployed box lands every pin on its named terrain). Only then did the
candidate-dir check reveal the split-brain.

**The overlay regression (found because of the row-count mismatch):** Master's
WorldMapOverlay had LOST the 73 map-750 exploration-paint clones (ids 4100–4172) — CSV and
DBC both. The candidate dirs were the only surviving copy. Syncing without noticing would
have destroyed map 750's exploration paint. Recovered into Master CSV+DBC first.

**The genuine gap: zero WorldMapOverlay rows for all nine 751 WMAs.** Without overlay
pieces nothing can ever paint as explored, regardless of server state. Built 109 clones
(ids 4200–4308) from the stock EK overlay rows of the 7 shared zones: MapAreaID → our WMA,
AreaID_1..4 remapped **by name** (stock AreaTable → our map-751 subzones), textures = the
stock art the zones already use. A 9-entry alias table covers Cata renames (Southshore →
Ruins of Southshore, Hillsbrad Fields → The Sludge Fields, Ruins of Andorhal → Andorhal,
Undercity → Ruins of Lordaeron, Hiri'watha → Hiri'watha Research Station, …); the 3 pieces
whose subzone no longer exists fall back to the parent zone id, lighting on first zone
entry rather than never. Gilneas gets none on purpose — its custom minimap-baked art is
full-detail with nothing to unblank. WorldMapOverlay: 1432 → **1614** rows (73 recovered +
109 new), originals byte-identical, deployed to patch-4 + patch-enGB-3, and
`sync-dbc-deploy.js` run for the full worldmap set. All candidates verified identical.

**Server side is already right**: AreaTable fresh (3505 rows, all 4924–4939 + 16xxx
present), AreaBits 1941–2758 all valid (< 4096), ExplorationLevel 130–152, zero collisions;
this morning's extraction covered map 751 (191 mmap tiles, 0 empty). If discovery toasts
still fail after the client restart, the one unverified link is whether the freshly
extracted `751*.map` files reached the Linux server — `.gps` in a subzone (area id should
read a 16xxx id) settles it in seconds.

**Still open, deliberately untouched**: WMA 1267 (continent row) rect + the
`Interface\WorldMap\Plaguelands\` continent tiles are a *consistent old pair* — both still
describe the 2-zone footprint. Fixing the rect without rebaking the art (or vice versa)
would make the continent view worse. The rebake should use the same labeled minimap
composite as the taxi map and set 1267's rect to the same box, giving continent view, taxi
view and WMC one coherent geometry. That is the next piece of this work.

**Requires a full client exit + relaunch** — WarcraftXLHost reads its DBCs at process start.

### 5w. Continent overview rebaked — art + WMA 1267 rect as one change (2026-08-20)

`bake_worldmap751_continent.py` rebuilt `Interface\WorldMap\Plaguelands\Plaguelands{1..12}.blp`
from the same 195-tile minimap composite as the taxi map (same sepia grade, same zone
labels, supersampled 2x), replacing the old stock-EK 2-zone crop. The art maps the world
rect onto the **top-left 1002x668 of the 1024x768 grid** per the engine-window convention —
never the full grid.

**The new WMA 1267 rect** — chosen to contain every zone WMA rect (envelope Y 3450..-6319,
X 3838..-2631) and every terrain tile, at the window's exact 3:2 aspect so terrain is not
stretched (stock Kalimdor's continent row uses the same exact ratio):

```
L = 3500   R = -6400   T = 3866.667   B = -2733.333     (Y span 9900, X span 6600)
```

The script patches the rect into WorldMapArea DBC + CSV itself, so art and rect cannot
ship separately — the same coupling that bit the taxi map's first attempt.

Deployed and fresh-process-verified: 12 tiles into patch-5 (byte-identical),
WorldMapArea.dbc into patch-4 + patch-enGB-3 (row 1267 confirmed from both archives; diff
vs baseline shows **only** row 1267 changed, string block untouched), candidates synced
(all three md5-identical to Master).

**User actions**: full client exit + relaunch; copy `Custom/DBCs/WorldMapArea.dbc` to the
server's `data/dbc` (keeps `sWorldMapAreaStore` in lockstep — low-impact since 1267 is the
AreaID-0 row, but lockstep is the rule).

**Follow-up (addon)**: DC-QOS ZoneLabels has no 751 continent entries yet — adding
click-labels for the 8 zones (projected through the NEW 1267 rect) is what gives the
continent overview zone navigation, since engine hover/click is dead on custom continents.

### 5x. Zone navigation on the 751 continent overview — DC-QOS ZoneLabels

Engine hover/click is dead on **every** custom continent (measured on 750 and Pandaria —
`UpdateMapHighlight` returns nil everywhere), so navigation has to be a Lua layer.
`DC-QOS/Modules/ZoneLabels.lua` now carries the eight map-751 zones.

**These are TEXT-FREE click targets, unlike map 750's.** Map 750 borrows stock Kalimdor art
whose baked names are the *wrong* zones, so its entries draw the correct name. Map 751's
tiles were baked for this map in 5w and already carry the eight names — drawing them again
would double every one. So the 751 entries mark a click box over the painted name and add
a soft gold hover wash as the affordance. Players without DC-QOS still see the labels and
simply do not get the click-through.

Implementation: a new `cw`/`ch` pair on a `CONTINENT_ZONES` entry (click-box size as canvas
fractions) switches a label into silent mode — `btn.silent`, empty text, explicit size,
hover texture. Map 750 / Deepholm / Azshara Crater entries have no `cw`/`ch` and are
untouched.

Coordinates are the zone WMA rect centroid projected through continent rect **1267**
(L 3500, R -6400, T 3866.667, B -2733.333) — the identical arithmetic the bake used to
place the painted text, so box and paint cannot drift. `cw`/`ch` are the painted name's
measured extent plus padding. **Regenerate all sixteen numbers if rect 1267 changes or the
art is rebaked.**

Verified: `luac -p` clean; all eight keys string-match the live `AreaTable` names exactly
(what `GetMapZones` returns) and carry the right raw WMA id; the nine pre-existing entries
remain text-bearing. Deployed to `Interface/AddOns/DC-QOS/Modules/ZoneLabels.lua` after
diffing the live copy for local edits (none — only the lines this change replaced).

Clicking routes through the existing `NavigateToZone`, which tries `SetMapByID(rawWmaId)`
first and confirms with `GetCurrentMapAreaID() == rawWmaId + 1` — the two-id-space trap
that once made "click Hyjal" land on the Plaguelands.

### 5y. Two follow-up defects from the first pass, both fixed (2026-08-20)

**Doubled zone names on the continent overview.** The 751 ZoneLabels entries were meant to
be text-free click targets over the baked names, but `BuildContinentZoneList` rebuilds each
entry as `{n, x, y, w}` and **silently dropped `cw`/`ch`** — the very fields that mark an
entry silent. So `btn.silent` was always false and the addon drew a second label over every
baked one. One-line fix: carry `cw`/`ch` through. A flag consumed in a different function
from where it is declared needs the plumbing checked, not just the consumer.

**The flight map "still does not fit" — it was ASPECT, not placement.** Verified first that
placement was fine: all 31 nodes sit on real minimap tiles, and a render of the deployed art
with pins projected through the shipped box reproduced the user's screenshot exactly.

The real fault came from Blizzard's own frame: `TAXI_MAP_WIDTH = 316`,
`TAXI_MAP_HEIGHT = 352` (TaxiFrame.lua), and the `TaxiMap` texture and `TaxiRouteMap` frame
are both 316x352 at the same anchor in TaxiFrame.xml — so art and pins share one box, but
that box is **portrait, 0.898 wide-to-tall**. The terrain-tight taxi box was 9067 (E-W) x
6400 (N-S) — **landscape, 1.417**. Mapping landscape onto portrait squashed the continent to

    (316 / 9067) / (352 / 6400) = 0.634 of its true width

37% too narrow. Pins were squashed identically, so they stayed on their landmarks — the
picture was just the wrong shape, which is exactly what "does not fit" described.

Blizzard's own taxi boxes are square (Azeroth and Kalimdor are 28800 on both axes) and so
only ever take the frame's inherent 316:352. The new box goes further and matches the frame
aspect exactly, for **zero** distortion:

```
TaxiMinX -4516   TaxiMaxX 5583   TaxiMinY -6400   TaxiMaxY 2667
```

i.e. the N-S axis padded 6400 -> 10100 (1850 each side, centred on the terrain), E-W left
terrain-tight. Terrain fills 100% of the width and 63% of the height with sea above and
below — which is how Blizzard's continent taxi maps look. **Filling the frame edge to edge
was never the goal; drawing the land in its real proportions is.** All 31 nodes remain
inside the box.

`bake_taximap751_minimap.py` now **writes the box into WorldMapContinent id 10 (DBC + CSV)
itself**, the same coupling the continent bake got in 5w — printing it for a human to copy
is how art and box shipped out of step the first time. Verified: only WMC row 10 changed,
CSV BOM preserved, both winning archives read the new box from a fresh process, art
byte-identical to the bake, candidates synced.

Note the BLP stays 512x512 square: the texture always fills 316x352 whatever its pixel
dimensions, so stored aspect is a sharpness question, not a geometry one — and
`blp-codec.makeBlpMips` takes a single dimension, so square is also the safe choice.

### 5z. Beige holes filled, and the taxi box made SQUARE (2026-08-20)

**Beige blocks on the world map — filled by continuation.** The minimap tile grid is not
a rectangle: ~10 of the 17x12 slots have no tile, so the composite left flat background
blocks punched out of the continent (15.1% of the canvas). `mapbake_inpaint.py` adds
push-pull (pyramid) hole filling — push the image down a pyramid carrying a coverage
weight so each level averages only real pixels, then pull back up taking the coarser value
wherever a pixel is unknown, with a light blur on the seam ring only. The holes now
continue the surrounding terrain and coastline instead of showing beige. Applied to the
continent tiles, and to the taxi map for gaps *inside* the tile grid (outside stays sea).

**The taxi box is now SQUARE — and that is a correctness fix, not a cosmetic one.**

Previous round set it to the frame's 0.898 aspect to kill the horizontal squash. The pins
then landed visibly wrong in-game. Diagnosing that turned up something worth writing down:

> **Every stock Blizzard taxi box is square.** Azeroth and Kalimdor are 28800 on both axes;
> Outland and Northrend are square to within a rounding unit. Because both spans are equal,
> **it is impossible to tell from stock data which range the client pairs with which screen
> axis** — `taxiMinX/MaxX` with the horizontal, or with world X and therefore the vertical.
> A non-square box is the first thing that depends on the answer.

So the 0.898 box was betting on an unverifiable assumption, and lost. A square box makes
the question moot: both ranges are identical, so every pairing gives the same result.

```
TaxiMinX -4000   TaxiMaxX 5067   TaxiMinY -6400   TaxiMaxY 2667      (9067 x 9067)
```

Terrain fills 100% of the width and 71% of the height with sea above and below, taking
only the frame's own 316:352 stretch — exactly what every Blizzard continent map takes.

Worth recording that placement was ruled out first, twice: all 31 nodes sit on a real
minimap tile, and sampling the raw minimap pixel under each node returned **land for all
31** — so no node was ever "in the sea" geographically. The fault was always the projection.

Also noted: DC's other custom continents (Pandaria 870, 2706, Deepholm 646, Azshara Crater
1451) all carry aspect-1.500 boxes, i.e. landscape boxes in a portrait frame. They are
squashed the same way and were the precedent this followed. They can be squared the same
way if their taxi maps ever matter.

Deployed and fresh-process verified: taxi art + 12 continent tiles into patch-5
(byte-identical), WorldMapContinent + WorldMapArea into patch-4 and patch-enGB-3 (both read
the square box back), all three candidate dirs md5-identical to Master.

## 6. Open items as of 2026-08-20 (state verified, not remembered)

Everything below was checked against the live DB, the live server `data/dbc`, and the
deployed archives rather than carried forward from notes.

### Closed — confirmed applied and live

| item | evidence |
|---|---|
| `88_`–`97_` SQL | all applied; item 68647 present, zone remaps done, 0 dead reward spells, **0 broken quest chains left**, 18 GO displays in the overlay |
| `91_`'s 67 dropped vendor rows | **0** `npc_vendor` rows now reference a missing item |
| GO display gap | **0** of the 41 map-751 GO displays ≥8500 missing from the shipped DBC |
| plain-id vs +4.1M creature refs | **0** band quests still reference a creature that only exists at the offset — the old "38 quests" note is stale |
| `outdoorpvp_template` type 8 | table has no type-8 row and the core no longer complains; treat as closed |
| server `data/dbc` | Spell 54,026 · Item 153,725 (incl. 68647) · GameObjectDisplayInfo 46,928 · WorldMapArea 269 — all the new rows present |

### Open — needs you

1. **Confirm exploration in-game.** Every input is verified good (AreaTable 3505 rows,
   AreaBits 1941–2758 all valid, ExplorationLevel set, fresh `751*.map`, 182 overlay rows).
   Walk into a subzone: a "Discovered" toast + XP means done. If not, the one unverified
   link is whether the freshly extracted `751*.map` reached the Linux server — `.gps` in a
   subzone should report a **16xxx** area id.
2. **`RareSpawn.Announce.Maps` on the live server.** The repo template now reads
   `"750,751,37"` (updated just now); the live `worldserver.conf` still needs it, then a
   restart. Until then map 751's 65 rares are invisible to the announcer.
3. **Worldserver rebuild.** Two DC scripts are source-only on this checkout —
   `dc_downport_taxi.cpp` (its `kNodes` table already lists all 31 map-751 nodes) and
   `AddSC_dc_western_plaguelands`. There is no local `build/`, so whether the running
   binary predates them is unknown from here.

### Open — deliberate, low priority

4. **Continent zone hover.** Engine hover/click is dead on every custom continent, so
   navigation is DC-QOS ZoneLabels click-labels. That works; a hover *glow* would be a Lua
   feature, and full-zone hit rects were tried on map 750 and removed by choice.
5. **Other custom continents' taxi boxes.** Pandaria 870, 2706, Deepholm 646 and Azshara
   Crater 1451 all carry aspect-1.500 boxes — landscape boxes in the portrait 316x352 frame,
   squashed exactly as 751 was. Squaring them is the same one-line fix plus a rebake, if
   those taxi maps ever matter.
6. **AreaTable hygiene (pre-existing, server-wide).** 51 rows carry AreaBit ≥ 4096, which
   can never be explored and warns if visited; 177 rows share AreaBit 0. None are map 751's.
7. **20 duplicate ids in ItemDisplayInfo** (the minted `8,000,000+IconFileDataID` band) and
   **5 stock items with a dangling DisplayInfoID** — both pre-existing and unrelated to this
   import, found while validating it.

### 6a. Item-display hygiene — `98_`, plus the DBC dedupe (2026-08-20)

Two pre-existing, server-wide defects found while validating the map-751 import; neither
caused by it.

**20 duplicate ItemDisplayInfo ids (21 redundant rows — one id appeared three times).**
All in the minted `8,000,000 + IconFileDataID` band from the retail item downport, i.e. the
mint ran twice for those icons. **19 of the 20 pairs are byte-identical**; the twentieth
(8132761, `inv_crate_01`) differs only in `GroupSoundIndex`, 7 vs 0.

Deduped keeping the **LAST** occurrence of each id — deliberately. A DBC loader indexes
records by id as it reads, so the last row is the one the client already resolves; keeping
it makes this a pure hygiene change with **zero behavioural difference**, 8132761 included.
Keeping the "richer" row instead would have silently changed one item's pickup sound.
96,892 → **96,871** records; distinct id set unchanged, every kept row proven equal to the
baseline's last occurrence, string block untouched.

**5 items pointing at a display that does not exist.** Displays 63765 and 134 are in
**neither** the Cata 4.3.4 client nor the stock 3.3.5 client — nothing to downport, those
rows always pointed at nothing and the items rendered with no icon. Repointed at the
closest real analogue already in the table rather than anything invented:

| item | | new display | analogue |
|---|---|---|---|
| 63682/63683/63684 | Helm of the Forlorn Vanquisher/Conqueror/Protector | **41441** | Helm of the Lost Conqueror/Protector/Vanquisher (40616–40618) — the exact WotLK equivalents of these Cata tier-helm tokens |
| 64663 | Bile-Etched Brass Key | **6710** | Small Brass Key (2719) |
| 71716 | Soothsayer's Runes | **11180** | Runes of Summoning (6284) |

**Deliberately not changed**: those three tokens are class 0 (Consumable) where the stock
tokens are class 15 (Miscellaneous). Changing an item's class affects bag filtering, so it
is left alone and noted.

`98_item_display_repairs.sql` carries the `item_template` + `item_dbc` side.
ItemDisplayInfo and Item .dbc/.csv updated and deployed to patch-4 + patch-enGB-3 +
candidates. Verified from a fresh process: **0 items anywhere now point at a missing
display**, and no id is duplicated.

### 6b. Zone hover glow on the continent overview

Engine hover is dead on custom continents, so the glow is Lua — but hung off the **label**,
not a zone rect. That is what makes it safe: the earlier map-750 experiment covered each
zone with its own hit rect plus a permanent glow and was removed because the glow drowned
the POI icons and the rects sat between the cursor and them. Hovering a *name* introduces
nothing between cursor and pins, and the glow is transient and deliberate. The glow frame
also sits at **parent+1**, far below QuestMapPins (parent+8), so pins draw over it.

One shared texture, repositioned to whichever label is hovered. Art is stock
`Interface\WorldMap\<Zone>\<Zone>Highlight.blp` — a 128×128 whose top-left 128×85.333 is
the lit silhouette, hence texcoord `0,1,0,0.6667`; ADD-blended, warm tint, alpha 0.55.
**7 of the 8 zones have a stock mask**; Ruins of Gilneas is Cata-only and ships none, so its
entry simply omits `hl` and `ShowGlowFor` no-ops — the label still clicks.

Rects are the zone WMA rect projected through continent rect 1267, the same arithmetic as
the labels. All eight come out square in normalised terms, which confirms the zone rects are
3:2 in pixels — exactly what the mask expects.

**Plumbing audited this time**, because dropping `cw`/`ch` in `BuildContinentZoneList` is
precisely how the doubled-label bug happened: every field declared on an entry is now
verified to survive the copy into the list and to be read in `Refresh` — declared 10,
copied 10, dropped **0**.

### 6c. The "Loading Items..." block — `99_`, and patch-4 hitting the MPQ ceiling

**The 114-line group is NOT from the map-751 import, and the log line is misleading.**

```
Item (Entry: 52199) does not have a correct display id (800047), must be 0.
```

reads like a missing display. It is not. The check is `ObjectMgr.cpp:3534`

```cpp
if (itemTemplate.DisplayInfoID != dbcitem->DisplayInfoID)
```

— `item_template` disagreeing with **Item.dbc** — and the core then *overwrites*
`item_template` with the DBC value. "must be 0" means the DBC side reads 0, so **114 DC
custom items (entries 52199–59520) were being stripped of their icon at every boot.**

The 0 comes from the **`item_dbc` overlay**, which is merged *over* the binary Item.dbc at
load. 114 of its rows carry `DisplayInfoID = 0` while both `item_template` *and* the shipped
Item.dbc carry the real 800xxx value. The overlay is the outlier and it wins.

Verified before picking a direction: all 114 exist in Item.dbc with a non-zero display,
every one of those displays exists in ItemDisplayInfo, and **`DisplayInfoID` is the only
column that disagrees** — ClassID, SubclassID, Sound_Override_Subclassid, Material,
InventoryType and SheatheType match on every row. So `99_` is a one-column `UPDATE … JOIN`.

The rest:

- **PageText** — 3745 is in `cata_world` and chains 3745→3746→3747→3748→3749→0, so the whole
  chain is imported for item 64666 (schemas match, 4 columns both sides). 3708/3718/3722
  exist in *no* source we have, so those three items get `PageText = 0`.
- **Faction 1168 = Cataclysm's GUILD reputation**, confirmed from the Cata client's own
  Faction.dbc ("Guild reputation is your personal standing with your guild"). 3.3.5 has no
  guild rep, so the requirement is *unenforceable*, not merely missing — there is no rank a
  player could reach. Zeroed on the six Cata guild banners.
- **Spell 96022** ("Dousing Agent", item 68647's `spellid_1`) IS in the Cata client, so it
  goes into `88_` — now **231 spells** — rather than being stripped.
- **Bag family bit 15** → `ItemBagFamily` id 16, which Cata calls **"Fishing Supplies"** —
  exactly what the five items carrying it are (Stag Eye, Corpse Worm, Corpse-Fed Pike,
  Giant Flesh-Eating Tadpole, Severed Abomination Head), one of them pre-existing. Row added
  rather than the bit stripped. **The Cata row could not be copied**: Cata collapsed the
  locale block to 2 fields / 8 bytes where 3.3.5 has 18 / 72, so it was rebuilt in our shape
  (name in the enUS slot, mask 16711934, matching every existing row). Note bit 12 → id 13
  is valid and its 179 items were never in error.

**patch-4.MPQ is full — 3.951 GB against the 4 GB MPQ v1 ceiling.** The Spell.dbc write to
it failed for that reason (a 53 MB replace appends and orphans the old copy; ~49 MB free).
`SFileCompactArchive` no-ops here (returns true, 0 bytes, 0.0s), so the space cannot be
reclaimed in place.

**Nothing is broken by this**: patch-4 kept its previous valid Spell.dbc (54,026 records)
and **patch-enGB-3 shadows patch-4 for DBCs**, so the client reads the current 54,027-record
file. Integrity re-verified afterwards — all six DBCs in patch-4 still read cleanly and the
archive is byte-for-byte its pre-compact size.

**This will recur on the next large DBC write to patch-4.** The real fix is to rebuild
patch-4 from a staging tree (`mpq_stormlib_pack.py`) to drop the accumulated orphans, or to
move the large DBCs to a newer patch letter. Worth doing before the next item/spell pass.

### 6d. patch-4.MPQ rebuilt — 3.951 GB → 1.254 GB (2026-08-20)

The archive was 49 MB from the 4 GB MPQ v1 ceiling, so a 53 MB Spell.dbc replace could not
fit. `SFileCompactArchive` is useless here (returns TRUE, reclaims 0 bytes, in 0.0s — never
trust its return value, measure the file). So it was rebuilt from a staging tree.

**Why the rebuild was safe to attempt.** Surveyed first rather than assumed: the internal
`(listfile)` holds **10,490 entries and all 10,490 were readable** — a complete listfile, so
nothing could be silently lost. Live content was **2.91 GB uncompressed** against a 3.951 GB
archive, so most of the gap was orphaned blocks from years of in-place replaces (an MPQ
replace appends and orphans the old copy; it never reclaims).

**Sequence**: extract all 10,490 with `--preserve-paths` → refresh the staged DBCs from
Master → `mpq_stormlib_pack.py` (V1, zlib, atomic .building → rename) → full verify →
swap → re-run the write that had failed.

**One thing deliberately reverted.** Refreshing staged DBCs from Master flagged *two*
differences: Spell.dbc (the failed write, genuinely stale) and **BattlemasterList.dbc** —
same 17 records but different bytes, and nothing to do with this work. It was restored from
patch-4's own copy. **A rebuild must preserve the archive's contents, not quietly import
unrelated changes**; Spell.dbc is the only deliberate content change in the new archive.

**Verification** — not the packer's 60-sample default:

| check | result |
|---|---|
| all listed files present + byte-identical to staging | **10,490 / 10,490**, 0 missing, 0 mismatched |
| live archive after swap, 9 key DBCs | all read, Spell 54,027 with 96022 present |
| the write that previously failed | **2/2 ok, verify 2/2 byte-identical** |
| post-write spot check vs staging | 400 sampled, 400 identical |

**Result: 1.254 GB with ~2.8 GB of headroom.** Large DBC deploys to patch-4 work again.

Two backups remain, ~7.8 GB total — `patch-4.MPQ.pre-rebuild` (3.951 GB, the exact pre-swap
state) and `patch-4.MPQ.pre-mpq-patch.bak` (3.808 GB, older). Both can be deleted once a
client session confirms the rebuilt archive; left in place rather than removed unilaterally.

### 6e. Undercity elevators, spell-summoned creatures, and Silverpine's stillness

**The Undercity elevators — an OFFSET-BAND trap, and it explains BOTH reported symptoms.**

```
StaticTransport::Create: No AnimationInfo was found for GameObject entry (4620651)
```
×9, and in-game "the platforms are not there, also the doors are not there". The nine are
exactly that: 3 × `Undervator` (the platforms) + 6 × `upperLdoor`/`lowerLdoor` (the doors),
one complete elevator assembly ×3.

`TransportAnimation.dbc` is keyed by **GameObject ENTRY**, not displayId — the error message
says so ("for GameObject entry"). The table already carried frames for **20649–20657**, the
stock Undercity elevator entries, but the import re-homed those objects to
**4,600,000 + base**. Keyed by entry, the lookup found nothing and the transports never
spawned. Nothing else was wrong: templates exist (type 11), spawns exist, and `87_` had
already fixed their state/animprogress. Only the animation link was severed by the offset.

Fixed by cloning each frame to `TransportID = base + 4,600,000`, preserving
TimeIndex/X/Y/Z/SequenceID: **54 frames in, 54 frames out**, stock rows untouched so anything
still using the unoffset entries keeps working. TransportAnimation 5,503 → **5,557**,
deployed to patch-4 + patch-enGB-3 + candidates and read back per-entry. **`StaticTransport`
is server-side, so `Custom/DBCs/TransportAnimation.dbc` must also reach the server's
`data/dbc`** — that is what actually makes the elevators run.

**`100_` — the spell → creature dependency, one level below the item → spell one.** The
runtime errors (`Creature::Create() … entry 50374 does not exist`, and the transform aura
wanting 50380 "only need its modelid") come from creatures that are **not spawned, not
SmartAI-summoned, not in creature_summon_groups and not vehicle accessories** — all four
checked. They are summoned by the spells `88_` downported, via `EffectMiscValue` on
SUMMON/SUMMON_PET/TRANS_DOOR/SUMMON_OBJECT and on SPELL_AURA_TRANSFORM. Auditing every such
reference: **75 missing ids, 68 in `cata_world`, 66 named by a spell `88_` added** — imported
at plain Cata ids, because a summon effect names that id and cannot be remapped to the
+4,100,000 band without editing the spell.

**Applied and hit MySQL 1137, `Can't reopen table`** — a TEMPORARY table may be referenced
only ONCE per query, and the verification UNION reads the snapshot three times. Switched to
a regular `_dc_missing_summons` table, dropped at the end of the file. The snapshot itself is
not optional: the predicate is "not yet in creature_template", which the INSERT makes false,
so recomputing it afterwards would return an empty set and the verification would silently
report zero of everything.

Column list derived from `INFORMATION_SCHEMA`, not guessed — the first attempt hardcoded
`scale` (absent from ours) and `InhabitType` (absent from **both**). `AIName`/`ScriptName`
are deliberately excluded: importing a Cata script name this core does not register makes a
creature fail to load rather than merely misbehave.

**Display coverage is NOT claimed.** The import stops the errors; whether the summons are
*visible* needs the third layer, and only 5 of the 66 models appear in the
`creaturedisplayinfo_dbc` overlay — which is an audit source, not the authority. `100_` ends
with a query that lists what still needs display work. Expect a display pass to follow, as
after every previous creature import.

**`102_` — Silverpine's stillness, where the first answer was "nothing is wrong".**
Silverpine on 751 has 591 wandering spawns of 4,026, and `cata_world` has **exactly the same
591** — the import copied its source faithfully. What exposed it was the neighbour: Tirisfal
on the same map runs **48% wandering against Silverpine's 15%**, and `cata_world` is a known
MovementType-stripped source. Cross-checking every static 751 spawn against `nelt_world` by
creature entry finds **3,068 spawns — 1,502 of them in Silverpine — whose entry demonstrably
wanders in nelt but is pinned here.**

Restored only where all four hold: currently static with no wander distance; the base entry
wanders in nelt with `spawndist > 0`; **not** in a `creature_formation` (moving one member
breaks the group); and no waypoint path of its own nor a SmartAI waypoint action, so nothing
scripted is overridden. `wander_distance` takes nelt's mean for that entry clamped to 3..15,
so one odd source value cannot send a mob across the zone. The verification block asserts
zero formation members and zero waypoint spawns were caught.

## 7. Undercity — falling through the elevators, and the missing city map (2026-08-21)

Three symptoms reported together: *"i fall through the platform like on blackwing descent -
and in undercity it still shows the ruins of lordareron area and the worldmap is not showing
undercity as well"*. They are **two bugs and one non-bug**, and it is worth keeping them
apart because the middle one repeatedly looks like a defect and is not.

### 7a. `103_` — falling through the elevators: the flags side table was never imported

The transports themselves were fixed in `101_` (TransportAnimation, keyed by GO **entry**, so
the `+4,600,000` offset severed it). That fix is live and verified: the server DBC carries
5,557 records and `StaticTransport::Create` no longer appears in `Errors.log` at all. The
elevators now exist and render — you just fall through them.

**AzerothCore does not keep a gameobject's `flags` and `faction` in `gameobject_template`.**
Both live in the side table `gameobject_template_addon`. The map-751 import cloned the base
table onto the `+4,600,000` band and never touched the side table, so every one of those
gameobjects comes up with `flags = 0`. Bit `0x08` is `GO_FLAG_TRANSPORT` — *"Object can
transport (elevator, boat, car)"* — and it is what makes an object a ride rather than scenery:

| entries | flags |
|---|---|
| stock `20649..20654` | `40` = `0x08 TRANSPORT` &#124; `0x20 NODESPAWN` |
| stock `20655..20657` | `2088` = `0x800` &#124; `0x08` &#124; `0x20` |
| map-751 `4620649..4620657` | **no row at all** |

Third instance of the same offset-band family, after the creature `+4,100,000` gaps and
TransportAnimation. It is not confined to the elevators: **838 distinct map-751 templates in
that band have no addon row against a stock counterpart that does.**

**The scope was cut twice, and both cuts are load-bearing** — the naive "subtract the offset
and copy" would have written wrong data:

- **The `+4,800,000` band is excluded entirely.** Only 34 of its 168 templates have any entry
  at `id - 4,800,000`, and **not one of the 34 matches on name, displayId and type**. They are
  numeric coincidences: `4802563 "Mailbox"` vs `2563 "Altar of the Tides - Focused"`,
  `4802681 "Bench"` vs `2681 "Hammerfall"`, `4804120 "Cache of Shadra"` vs `4120 "Mulgore"`.
  That band was not minted by offsetting a stock id, so it has no stock source.
- **Seven rows in the `+4,600,000` band are skipped** — those where the import changed the
  object, so stock flags no longer describe it (`4601586` type 3 vs 2, `4658626`
  *"Archaeology"* vs *"Cartography"*, `4780437` *"Wickerman Ashes"* vs *"Wickerman Ember"*, …).
  Five of the seven have stock `flags = 0` and `faction = 0`, so nothing is lost.

831 rows survive all three field checks; 138 carry a real value, 9 carry the transport bit.
No `mingold`/`maxgold` and no artkits are involved — every matched source row is zero in all
six. The `+3,600,000` band was already correct (378/378 have rows); only `+4,600,000` dropped
them.

### 7b. "it still shows the ruins of lordaeron" -- WAS a defect. Earlier call was wrong.

**This section previously said "NOT A DEFECT, do not chase it again". That was wrong**,
and the reason it was wrong is worth keeping: the analysis read the *source* extract
(`dc_plaguelands_ext_335/world/maps/azeroth/azeroth_31_29.adt`) instead of the tile
actually shipped in patch-4. They are the same byte size, which made them look
interchangeable. They are not -- the deployed tiles have had a subzone retag pass the
source never received:

    DCPlaguelands_31_29   source   areas {4933: 110, 4935: 103, 4936: 43}
                          deployed areas {16606: 110, 16705: 42, 16641: 43, ...}

`16606` is "Ruins of Lordaeron". So the terrain under Undercity really was reporting
that name, and the conclusion drawn from the source file -- that the name could only be
coming from the WMO and was therefore stock-correct -- did not hold for what shipped.
**Read the deployed asset, not the staging copy, before calling something correct.**

The WMO chain itself was fine, and everything measured about it still stands: the tile
places `world/wmo/lorderon/undercity/undercity.wmo` (uid 239598), root `wmoID` 1150
matches what `WMOAreaTable` keys on, the placement nameSet was 1 for which rows exist,
and 215 of 216 group ids match. The break was at the far end -- **`AreaTable` 1497 has
`ContinentID = 0`.** An area belongs to exactly one continent, so map 751 cannot adopt
it, the WMO override is discarded, and the terrain area 16606 wins.

That is also the asymmetry that made it look so odd: the importer *could* retag terrain
(hence 16606, 4933, 16705 with `ContinentID` 751) but *could not* retag the WMO, because
`WMOAreaTable` is keyed by `(wmoID, nameSet, groupId)` with **no map component at all**.

### 7c. The world map — one appended `WorldMapArea` row, applied to the DBC

Genuinely broken. The client picks which map to draw by looking up `WorldMapArea` on
**(current MapID, current AreaID)**. Undercity's only WMA row was id `382` with `MapID = 0`,
so on 751 nothing ever matched and the map fell back to the continent.

Map 0 and map 751 **share the same coordinate frame for this tile** — the elevators sit at
exactly `(1596.15, 291.80)`, `(1595.26, 188.64)`, `(1544.24, 240.77)` on both, to the last
decimal — so stock's rect transfers with no transform. Added as WMA **id 1275**, a verbatim
clone of 382 with `MapID = 751`:

    L 873.1926   R -86.1824   T 1877.945   B 1237.841   DisplayMapID -1   ParentWorldMapID 0

`AreaName` stays `Undercity`, which repoints the map tiles at the stock
`Interface\WorldMap\Undercity\` art the client already ships. The string-block offset is
reused, so the file grows by exactly one 44-byte record and the string block is untouched
(asserted on read-back, along with the originals being byte-identical).

**Two WMA rows for one AreaID is a supported shape, not a hack** — AreaID `268`
(AzsharaCrater) already has rows on maps 37 and 1451 in these very files, and stock Blizzard
ships AreaID `2257` (DeeprunTram) twice on map 369.

**No overlay rows are needed**: stock Undercity has **zero** `WorldMapOverlay` rows — cities
are drawn fully revealed, there is no exploration fog to clear.

Deployed to `patch-4.MPQ`, `enGB/patch-enGB-3.MPQ` (which shadows patch-4 for DBCs) and all
three WXL candidate dirs; all four verified at 270 records carrying both `(382, map 0)` and
`(1275, map 751)`.

### 7d. `104_` — the same bug in Blackwing Descent, which the report had already named

*"like on blackwing descent"* was not loose phrasing, it was the same defect. A server-wide
sweep for type-11 templates with no `gameobject_template_addon` row returns **twelve, and only
twelve**:

| entries | where | covered by |
|---|---|---|
| 9x `4620649..4620657` | map 751 Undercity | `103_`, from the stock source |
| `203716` | map 669 **Blackwing Descent Elevator** | `104_` |
| `207834` | map 669 `Doodad_BlackWingV2_Elevator_Onyxia01` | `104_` |
| `327444` | `Doodad_9CAS_Castle_ElevatorPlatform001` (Castle Nathria, unspawned) | `104_` |

The three in `104_` are Cata/Shadowlands imports with no stock counterpart, so `flags` is set
directly to **40**. That value comes from the data, not habit: of the 90 type-11 templates that
do have an addon row, **89 carry `0x08` and 74 use exactly 40**.

**Both BWD elevators already had their animation** — 13 frames for `203716`, 14 for `207834` —
so unlike map 751 these were spawning correctly all along and the missing flag was the entire
bug. `327444` is included but will not work yet, deliberately: it has zero animation frames and
zero spawns, so `StaticTransport::Create` rejects it on the AnimationInfo check whatever the
flag says. The row is there so the template is right when Castle Nathria's transports land.

Baselines confirmed against the live DB before writing: 11 spawned type-11 templates are
currently not rideable and 12 have no addon row; both go to **0** once `103_` and `104_` are
applied.

### 7e. The actual fix — nameSet 2, Blizzard's own mechanism for this exact problem

`WMOAreaTable` is keyed by `(wmoID, nameSet, groupId)`. There is no map column, so the
only lever for "same WMO, two maps, two different areas" is **nameSet** — and that is
precisely what Blizzard uses it for. **52 stock WMOs already resolve to different
continents depending on nameSet.** The cleanest is `wmoID 59`:

    nameSet 1 -> areas on continent 0
    nameSet 2 -> areas on continent 609   (Scarlet Enclave)
    nameSet 3 -> areas on continent 0

Worth noting for future custom continents: **not one `WMOAreaTable` row in this whole
install pointed at a custom-continent area before this change** — every one resolved to
a stock map. Pandaria 870, map 750 and map 751 are all terrain-tagged only. So any
downported WMO *interior* on a custom map has this bug latent, and Undercity is simply
the first one with a city map attached to make it visible.

What was written:

| file | change |
|---|---|
| `AreaTable` | **4940** `Undercity` — continent 751, parent 0, AreaBit 2759, ExplorationLevel 130<br>**4941** `Elevator` — continent 751, parent 4940, AreaBit 2761 (cloned from stock 4617, used by 3 of the WMO rows for the lift shafts) |
| `WMOAreaTable` | the 229 rows for (1150, nameSet 1) cloned to **nameSet 2**, AreaTableID remapped 1497→4940, 4617→4941, 0→0 |
| `WorldMapArea` | row 1275 repointed from area 1497 to **4940** |
| 4 ADTs | MODF `NameSet` 1 → 2 for uid 239598 |

Both new rows are cloned field-for-field from the stock originals, so flags, ambience,
sound and all 16 localized names carry over, and every interior subzone name is
preserved — War Quarter, Trade Quarter, Canals, Sewers and the 53 "Ruins of Lordaeron"
surface groups. **Fresh AreaBits rather than stock 685/2690**: sharing a bit would make
exploring Undercity on 751 also flag the map-0 one as explored. Both are below 4096, the
size of the client's explored-zones bitmask.

**Stock is untouched**: nameSet 1 still maps to 1497 on continent 0 via WMA 382.

Two traps worth carrying forward:

- **Four tiles, not one.** A WMO is duplicated into every ADT its footprint overlaps.
  Undercity appears in `30_28`, `30_29`, `31_28` and `31_29`, all with uid 239598.
  Retagging one would have left an invisible, position-dependent area boundary.
- **The staging tree is stale and must not be re-packed.** `_stage_dcplaguelands_ext`
  still holds the pre-subzone-retag tiles at identical byte sizes. The fix therefore
  extracts the live tiles from patch-4, edits those, and writes them back; staging gets
  the same two-byte edit so a future rebake keeps it, but is never pushed.

Deployed to `patch-4.MPQ`, `enGB/patch-enGB-3.MPQ` and the three WXL candidate dirs, then
verified end-to-end by reading the chain back out of the deployed archives:
ADT nameSet 2 -> 229 WMOAreaTable rows -> area 4940 on continent 751 -> WMA 1275.

**STILL OUTSTANDING: map 751's vmaps must be re-extracted.** The server resolves areas
through the same triple — `vmap4_extractor` writes `MODF.NameSet` into the vmap dir file
(`wmo.cpp:584`) and `Map::GetAreaId` calls
`GetWMOAreaTableEntryByTripple(rootId, adtId, groupId)`. Until the vmaps are rebuilt the
server looks up nameSet 1, misses, and falls back to the terrain area. That is graceful
degradation rather than breakage — the client will show Undercity correctly — but server
and client will disagree about the player's area, which affects anything area-gated.

### 7f. OPEN — the server honours the retag, the client does not

`.gps` at 10:00 returns `Zone: 4940 (Undercity) Area: 4940 (Undercity)` on map 751. That
value is only reachable through `GetWMOAreaTableEntryByTripple(rootId, adtId=2, groupId)`,
so **the server side of 7e is proven working end to end**. The client, standing at the same
spot, still reports:

    GetZoneText()        "Tirisfal Glades (130-136)"   <- AreaTable 4933
    GetSubZoneText()     "Ruins of Lordaeron"          <- AreaTable 16606 (terrain)
    GetMinimapZoneText() "Ruins of Lordaeron"
    GetCurrentMapAreaID() 1270                         <- WMA 1269 (Tirisfal) + 1

i.e. the client is using the **terrain** area and never applies the WMO override. Confirmed
taken after the client restart and after the fresh extracts.

**Everything the client reads has been verified correct, from the archives it actually
reads.** Recording it so none of it is re-checked:

| link | verified |
|---|---|
| ADT `31_28` (patch-4, the only archive with it) | `nameSet = 2`, MODF rot y=179.5, single hash entry, locale 0 |
| WMO (patch-9 — **it shadows common-2/patch-2/patch**) | root `wmoID` 1150, 216 groups, MOGI consistent with the group files (0 interior-bit mismatches), portals internally consistent (287 / 574 refs) |
| the player's exact group | 3D bbox test -> gid **6607 / 3221**, both `INTERIOR` |
| `WMOAreaTable` (patch-enGB-3) | `(1150, nameSet 2, 6607/3221)` -> area **4940** 'Magic Quarter'; the `group = -1` whole-WMO fallback row also -> 4940 |
| `AreaTable` (patch-enGB-3) | 4940 = ContinentID **751**, parent 0, AreaBit 2759 |
| `WorldMapArea` | 1275 = map 751 -> area 4940 -> Undercity art |
| structure | `dbc-verify` 0 errors on all three tables |
| timing | all writes 09:17-09:20; client booted 09:45:41 and again 09:59:12 |

**Ruled out, do not re-chase:** MPQ duplicate/orphan hash entries (one entry per file,
locale 0); the WXL host cache (RAM-only, 60 s TTL, cannot survive a restart); the WXL
terrain-phase loader (only redirects when `SetTerrainPhase` has run, which logs
`phase '%s' active over base` -- absent); the `modern-adt` transform (host reports 0 loose
roots); the three WXL candidate DBC dirs (byte-identical to Master); a group-id mismatch in
patch-9's downported WMO (215/215 of its group ids have rows).

**The one thing not yet tested is whether this is map-751-specific at all.** The client's
WMO-area override failing is equally consistent with it being broken **globally** on this
install -- in which case stock Undercity on map 0 would also read "Tirisfal Glades", the
defect would predate every change in section 7, and the fix belongs in the client/WMO layer
rather than in the DBCs. Test before doing anything else: go to Undercity on **map 0** and
run the same `/dump`. If it says "Undercity" the problem is map-751-specific; if it says
"Tirisfal Glades" the WMO-area path is broken install-wide.

### 7g. The WMO clone — map 751 owns its Undercity outright

The nameSet approach in 7e is **server-correct and client-inert**: `.gps` reports
`Zone 4940 / Area 4940`, which is only reachable through the triple lookup with
`adtId = 2`, yet the client kept using the terrain area with every input verified
correct. Rather than keep hunting a client behaviour that cannot be observed from
outside, map 751 was given **its own copy of the building** — which is also the right
answer architecturally, since it ends the sharing that forced the nameSet trick in the
first place.

| | |
|---|---|
| new WMO | `world/wmo/dc/undercity751/undercity751.wmo` + 216 group files, root `wmoID` **1150 → 66901** |
| cloned from | **patch-9's** copy — a 216-group Cata downport that shadows common-2's 206-group stock file and is what the client actually loads. So the rendered building is unchanged. |
| `WMOAreaTable` | the 229 nameSet-2 rows on 1150 **removed**; 229 rows added on `(66901, nameSet 1)` → 4940 / 4941 / 0 |
| ADTs (all 4) | `MWMO` → the new path, `MODF.NameSet` **2 → 1** |
| `md5translate.trs` | 456 minimap entries cloned into `dir: WMO\dc\undercity751`, pointing at the **same md5 blps** |

**wmoID 1150 is back to pristine stock** — zero nameSet-2 rows remain — so map 0's
Undercity is untouched whatever happens next. Map 751 now uses **nameSet 1**, the
ordinary configuration every stock WMO uses.

Four traps, each of which would have failed silently:

- **The new path is exactly 42 characters, same as the old.** `MWMO` is a fixed-size
  chunk of NUL-separated strings with `MWID` byte offsets into it; same-or-shorter can
  be written in place with NUL padding, leaving the chunk size, `MWID` and every `MHDR`
  offset untouched. Longer would mean rebuilding both chunks and re-patching `MHDR`.
- **Clone from the archive that actually wins.** patch-9, not stock common-2 and not
  our retail extract — otherwise the building's appearance changes.
- **The interior minimap is path-keyed.** Renaming without cloning the trs block turns
  the Undercity minimap black. And the block **mixes separators** — 228 entries with
  `\` and 228 with `/`, both live — so each entry has to be rewritten in its own style.
- **All four tiles**, as ever.

Deployed to `patch-4` (222 files: 217 WMO + 4 ADT + trs; archive 1.25 → 1.29 GB) and
`WMOAreaTable` to `patch-4`, `enGB/patch-enGB-3` and the three candidate dirs. Verified
end to end out of the deployed archives: ADT → new path + nameSet 1 → wmoID 66901 →
groups 3221/6607 (interior) → area 4940 'Magic Quarter'.

**Map 751's vmaps must be re-extracted again** — the vmap stores the root WMO id, now
66901, and the `.vmo` files are named after the WMO. Until then the server misses the
triple and falls back to terrain, the mirror image of the client's previous state.

### 7h. CONFIRMED WORKING — and two follow-ups the clone exposed

The clone in 7g works. In-game the minimap header reads **"Trade Quarter"**, which can only
come from the cloned WMO's `WMOAreaTable` rows: the Undercity world map opens, and the
elevators still work. `wmoID 1150` stays pristine, so map 0 is untouched.

**7h-1. DC-Mapupgrades map-751 bounds were stale — FIXED.**
`Libs/HotspotDisplay_Astrolabe.lua` carried `[751] = {minX 630, maxX 3500, minY -6140,
maxY -810}` with the comment *"no WorldMapArea row yet, so this is an APPROXIMATION from
the server spawn footprint"*. That premise is obsolete — WMA **1267** (map 751, AreaID 0
"Plaguelands") exists and covers the whole continent. The old box was derived from the
Eastern Plaguelands band alone and **excluded most of the map**: Undercity at
(1614, 258) fell outside its `minY..maxY` entirely, so hotspot pins there could not be
normalised at all.

Replaced with the real continent rect, in the same form as the stock `[0]/[1]/[530]/[571]`
entries. The convention was verified against those rows rather than assumed —
`minX = LocBottom, maxX = LocTop, minY = LocRight, maxY = LocLeft`, which reproduces the
existing `[750]` entry from WMA 1216 exactly:

    [751] = { minX = -2733.333, maxX = 3866.667, minY = -6400, maxY = 3500 }

Deployed to the live client. **Map 750's entry was deliberately left alone** — its caveat
is real (row 1216 only covers the Hyjal Frontier band) and widening it needs extra
WorldMapArea rows plus map art per band, not a number change.

**7h-2. The Undercity interior minimap art is mismatched — PRE-EXISTING, not from 7g.**
The minimap tiles are keyed by **group INDEX** (`<base>_<NNN>_<x>_<y>.blp`), and
`md5translate.trs` carries indices **0..205 — the stock 206-group Undercity**. But the
client loads **patch-9's 216-group Cata downport**, where index N is a different room:
patch-9's `undercity_092` is group 3118 where stock's is 3176. So the tiles that exist
draw the wrong rooms, and indices 206-215 (plus 8 and 75) have no tile at all.

That is what "hard to read" is, and it predates every change in section 7 — patch-9's WMO
has been shadowing common-2 all along. 7g reproduced it faithfully, which was the right
call (the goal there was to change no visuals), but it is the real minimap defect. Two
ways out, neither started:

- **Re-render the minimap tiles** for the 216-group WMO (`wmo-minimap-downport.js`) and
  point the cloned trs block at the new blps. Keeps patch-9's geometry.
- **Clone from common-2's 206-group stock WMO instead.** The trs indices would then match
  exactly and the minimap would be correct with no re-rendering — at the cost of map 751
  rendering the stock building rather than the Cata downport.

**Still open:** minimap POI icons (mailbox envelopes and similar) drift with the player
inside Undercity. They are not DC-Mapupgrades pins — that path returns `nil` when it
cannot normalise, so its pins would simply not draw. Most likely native client object
blips, in which case 7h-2 is a strong suspect: if the interior minimap cannot establish a
correct frame for the room, correctly-placed world-space blips have nothing coherent to
sit against.

### 7i. `105_` — flying NPCs falling, and why "again" was the right word

**This fork has no `creature_template.InhabitType`.** It was replaced by
`creature_template_movement` (Ground / Swim / Flight / Rooted / …). The source
`nelt_world` still carries `InhabitType`, so an importer has to **translate** it. Every
earlier import did. The map-751 extension import, on the `+4,100,000` band, did not:

| map | band | air creatures | missing a movement row |
|---|---|---|---|
| 750 | 3.6M | 59 | 0 |
| 751 | 3.6M | 10 | 0 |
| 861 | 3.6M | 21 | 0 |
| **751** | **4.1M** | **19** | **19 — all of them** |

With no row `Flight` defaults to 0, gravity applies, and anything the source calls "air"
falls. Fourth instance of the same family this session, after TransportAnimation (`101_`)
and the gameobject flags (`103_`/`104_`): **base table cloned onto the band, side table
left behind.** The scoping query is worth keeping — it finds this class anywhere.

Who was falling: Silverpine's Val'kyr **Agatha, Arthura, Daschla**, the **Fallen Human**
bodies they raise, **Soaring Razorbeak**, **Belfry Bat**, **Forsaken Bat**, the Headless
Horseman fire effect, and a pile of invisible stalkers/bunnies whose fall is unseen but
breaks whatever they anchor. 19 entries, **188 spawns**.

The mapping is copied from the band that works rather than invented — every 3.6M row on
this map follows one rule:

    InhabitType 4 (air)        -> Ground 0, Swim 0, Flight 1   Invisible Stalker (Floating)
    InhabitType 5 (ground|air) -> Ground 1, Swim 0, Flight 1   Monstrous Plaguebat

so Ground/Swim come from bits `0x1`/`0x2` and Flight is 1. `Rooted`/`Chase`/`Random`/
`InteractionPauseTimer` are 0 in every working row. **`Flight = 1` is DisableGravity** —
what stops the fall, and what the working band uses uniformly; `Flight = 2` (CanFly) is
deliberately not used, since granting real flight changes pathing rather than posture.

One entry, `4144592` "Fallen Human", has `InhabitType 7` (ground|water|air) and so gets
`Swim = 1`. No 3.6M row on this map sets bit `0x2`, so that single value follows the bit
definition rather than a local precedent — flagged rather than hidden.

Source validated by **name**, as in `103_`: 1,119 of the 1,121 entries in the band match
their `(id - 4,100,000)` counterpart; the 2 that do not are excluded.

**Not changed:** `creature_addon.bytes1` animTier. Only 2 of the 10 working air creatures
set it, so it is not what holds them up — the movement row is. If a Val'kyr ends up
hovering but mis-posed, that is the follow-up.

### 7j. `106_` — the 130-160 band was re-leveled but never re-scaled

Reported from a level 142 rare showing **16,136 health and 40,484 mana** — less health
than its own mana pool, against the 39,396 a level-131 player carries.

**Two layers were already fine and are not the problem.** `creature_classlevelstats` is
populated to level 255 with a smooth curve, and `dc_map751_band` already mapped every
zone onto its segment (Tirisfal 130-136 … EPL 152-158) with the creatures carrying those
levels. **Only the stat half was never done**: each creature kept whatever
`HealthModifier` its level 1-50 source mob happened to have, so the effective curve is
flat and noisy rather than banded — level 136 averages 24,014 HP while 137 averages
14,981; 142 gives 24,814 while 145 gives 14,319.

The reported NPC reproduces exactly: `basehp0 10757 × 1.5 = 16,136`,
`basemana 20242 × 2 = 40,484`.

**The headline number is the floor, not the average.** There are level 130-160 normal
mobs sitting on **3 health**, and others at 345 / 361 / 1,634 — inherited straight from
their classic source mobs.

**The trap in the obvious fix.** 1,456 of 1,472 entries have `exp = 0`, which is why they
read `basehp0` (the classic column) at all. Flipping `exp` to 2 lifts HP 2.6× and fixes
mana in one column change — and **also switches the damage column**, because `exp`
selects `damage_base`/`damage_exp1`/`damage_exp2` as well. At level 142 that is
88.6 → 416.0, a **4.7× damage jump on every mob on the continent**. `exp` is left alone.

**The design.** Stats become a function of `(level, class, rank)` instead of an inherited
per-mob accident. Since levels already come from the band table, a level-indexed curve is
band-derived by construction:

    target effective HP = basehp2(level, class) × rank_factor

`basehp2` is the reference on purpose — smooth, level-indexed, already in the DB, and at
level 142 it gives 41,321, almost exactly the observed level-131 player's 39,396. So the
rank factor reads directly as "how many players' worth of health".

| rank | factor | entries | old avg HP → new | raised / unchanged |
|---|---|---|---|---|
| 0 normal | 0.50 | 1235 | 20,108 → 23,907 | 996 / 239 |
| 4 rare | 2.50 | 57 | 25,377 → **105,110** | 57 / 0 |
| 1 elite | 5.00 | 154 | 401,177 → 518,958 | 119 / 35 |
| 2 rare elite | 8.00 | 4 | 673,249 → 927,045 | 3 / 1 |

**Rares are the one rank that changes character.** They were uniformly 1×-3× with **no
outliers** — a silver dragon that died faster than the player's own health bar — while
elites already averaged 28× (skewed by 38 entries above 10× and one at 1200×).

**Nothing is nerfed.** Every modifier is `GREATEST(original, target)`, so hand-tuned
outliers survive and the two rank-3 bosses are excluded outright. Only mobs below the
curve are lifted onto it. That does mean zone *averages* stay uneven; the guarantee is
the **floor**, monotone in level.

**Mana is capped, not scaled** — `basemana` is a single curve while HP uses the weakest
of three columns, which is why casters overtake their own health. The HP lift alone fixes
5 of the 71 cases; the rest need `ManaModifier <= new_HP / basemana`. Mana is never raised.

**Reversible and idempotent**: `dc_map751_stat_snap` freezes the originals via
`INSERT IGNORE` and every calculation derives from that snapshot, so re-running cannot
ratchet. Tunables live in `dc_map751_rank_scale` — edit and re-run. A rollback UPDATE is
in the file footer.

### 7k. `107_` — "the Forsaken Front looks static": the scripts are fine, the layer under them is not

**Answer to the question as asked: yes, the scripts were ported, completely.** Measured for
Silverpine (zone 4935) against `cata_world`, entry for entry:

| layer | ours | cata source |
|---|---|---|
| `AIName = 'SmartAI'` | 50 | 50 |
| `smart_scripts` rows | 50 | 50 |
| `creature_text` | 12 | 12 |
| C++ `ScriptName` | 3 | 3 |
| SmartAI rows with a dead AIName | **0** | — |

Nothing was skipped. Three *other* things make it feel dead, and they are separate:

**1. The `creature_addon` animation layer is empty for the whole `+4,100,000` band.**
Silverpine: ours **emote 0 / auras 0**, nelt **emote 25 / auras 222**. `emote` and `bytes1`
are what make a camp look inhabited — kneeling, working, sitting, weapon drawn, combat
stance. With both zero every NPC stands in the default idle pose, which reads exactly as
"lots of NPCs, nothing happening". Fifth instance of the same family as `101_`/`103_`/
`105_`. The older `+3,600,000` band DID get it — all 92 emotes / 79 poses / 542 auras
live on map 751 today are in that band, which is why only the new zones feel dead.
Recoverable from nelt at entry level: 50 emotes, 40 poses, 72 aura sets, **1,207 spawns**.

**2. Patrols are thin** — 7 waypoint spawns in Silverpine against 17 in source, and
**`102_` (the 3,068-spawn wander restore) is still unapplied**.

**3. The Forsaken Front is a phased Cata event and cannot be ported by SQL.** Its drama —
Sylvanas raising the Val'kyr, the battle staging — lives in Cata C++ zone scripts plus
phasing that do not exist on this core; `cata_world` has SmartAI for only 50 entries and
the event logic is not among them. Worth knowing: the `npc_lady_sylvanas_windrunner`
ScriptName that IS bound resolves to `EasternKingdoms/zone_undercity.cpp` — the **Undercity
throne-room "Lament of the Highborne"** script, not the Silverpine one. It binds without
error, so she simply stands there. Making the Forsaken Front actually play out is a C++ job.

#### The trap in `107_`: importing auras blind HIDES NPCs

Checked against `spell_dbc` rather than assumed, and the risk is real in this exact data:

| spell | name | entries |
|---|---|---|
| 29266 / 84386 | **Permanent Feign Death** — lies down as a corpse | 8 |
| 49414 / 49415 | **Generic Quest Invisibility 1/2** — invisible outside its phase | 8 |
| 80636 | Feigned | 1 |
| 89702 | Camouflage | 1 |

Those are excluded. **Not** excluded despite matching a naive name filter: `18950`
"Invisibility and Stealth **Detection**" — it detects stealth, it does not hide the caster,
and dropping it would break stealth-detecting guards. Everything else is cosmetic or
combat flavour (Frost Armor, Shadowform, poisons, Retribution Aura, fire visuals).

`path_id` is never touched: 2,935 map-751 spawns already have a `creature_addon` row whose
only content is the waypoint link, so the file UPDATEs animation columns on existing rows
and INSERTs only for spawns that have none. Values are taken **per entry** (most common
non-zero, ties to the lower value) because an emote is a property of what the NPC is, not
of where it stands — the same approach `102_` used. Every write is conditional on our
column being empty, so hand-set values survive.

### 7l. `108_` — my miss in `107_`: auras were filtered for HIDING but never for EXISTING

`107_` produced ~250 boot errors:
`Creature (GUID: ...) has wrong spell '87972' defined in 'auras' field in 'creature_addon'.`

It filtered auras for spells that would hide the NPC and never checked the spells exist.
Worse, **the audit that informed it used an inner `JOIN spell_dbc`**, which silently listed
only the auras that were present and hid every one that was not — the gap was invisible in
exactly the query meant to find it. An existence check has to be a LEFT JOIN counting the
misses, never an inner join listing the hits.

#### `spell_dbc` IS NOT THE SPELL STORE — it is a sparse overlay

This is the reusable lesson. Validating against the table reports **22** missing aura
spells; validating against the binary `Spell.dbc` (54,027 rows) reports **11** — and the 11
match the server log *exactly*. The other eleven — 5301, 12782, 13730, 13886, 16245, 18847,
26000, 32783, 38232, 42648, 61573 — are real, working spells that simply are not mirrored
into the overlay. **Stripping those would have destroyed working data.** Always resolve
spell existence against the DBC.

The 11 genuinely absent are Cata-era cosmetic/flavour auras that were never downported:

| spell | on | spawns |
|---|---|---|
| 87972 / 87973 | Hillsbrad Foreman / Miner / Sentry | 56 |
| 78677 | Stormpike Trainee | 33 |
| 80365 | Worgen Renegade | 30 |
| 91154 | Stormpike Soldier | 24 |
| 89281 | Foothill Stalker | 22 |
| 90080 | Mudsnout Gnoll / Shaman | 20 |
| 80681 | SI:7 Operative | 10 |
| 88964 | Generic Bunny - PRK | 7 |
| 64086 | Romo's Half-Size Bunny | 4 |
| 102371 | Fahrad | 1 |

The server already refuses to apply them, so stripping costs nothing that works today. It
is also **not a permanent verdict** — these are exactly what `88_` downports; add them via
`spell-dbc-append.py` (the fork's Spell.dbc is a custom 234-field layout, `csv2wdbc` would
destroy it), delete the row from the block list, and re-run `107_` to restore the aura.

#### The second defect, found while fixing the first

`UPDATE ... JOIN` applies **one** matched join row per target row, so a single pass strips
only ONE bad spell from an aura string holding several. **56 spawns carry both 87972 and
87973** — one pass would have left half the job done with no error and no log line. `108_`
therefore uses one explicit UPDATE per spell, and `107_`'s hider strip now runs four passes.
Verified on the worst case: `"87969 87972 87973"` -> `"87969"`, keeping the valid Paralytic
Poison and dropping only the two unresolvable ids.

### 7m. `109_` — boot-log triage: one real bug, two cosmetics, and ~50 lines to ignore

**The ~50 "deprecated flags_extra" lines are NOT an error.** `IMMUNITY_KNOCKBACK (0x40000000)`
and `NO_TAUNT (0x100)` announce the core's *own* planned migration to `creature_immunities`.
Nothing is broken, the immunities still apply, and hand-migrating now would fight the
upgrade that is coming. They are also almost all stock/Cata entries (51456-51461,
49973-49987, …), not map-751 content. **Deliberately not touched — do not "fix" these.**

**The only gameplay bug in the whole log**: two map-751 NPCs are spawned with a real gossip
menu but no `UNIT_NPC_FLAG_GOSSIP`, so a player walks up and gets no conversation:
`4102239 Drull` (menu 262, npcflag 0) and `4136517 Aleric Hawkins` (menu 10813, npcflag 2).
The bit is OR-ed, not assigned, so Aleric keeps QUESTGIVER.

**Two non-existing faction templates**, both on unspawned creatures: `39038 Lilian Voss`
(2237 → 1665) and `42597 Revantusk Drums Credit Bunny` (2273 → 35). Log noise today, but an
unresolvable faction makes a creature hostile to everything if it is ever summoned.

**29 creatures with a display the client does not have — the follow-up `100_` predicted.**
When `100_` imported the 66 spell-summoned creatures it explicitly did not claim display
coverage; this is that pass. All 29 have **zero spawns** and exist only as summon targets
(verified: 28 appear in `Spell.dbc` `EffectMiscValue_1/2`), so "can crash the client" is
real but only fires if the summoning spell is cast. They are guild-perk props, companion
pets and event visuals.

**Repointed, not downported.** 27 of the 29 display ids are missing from our own
CreatureDisplayInfo.dbc too, so a proper fix means downporting 27 models plus
CreatureModelData and client M2s — for content not obtainable here. Repointing at an
existing analogue removes the crash risk now and reverses trivially if the models ever land.

#### The overlay trap, hit a second time in one session

Substitutes were verified against the **binary** `CreatureDisplayInfo.dbc`, not the
`creaturedisplayinfo_dbc` table. A candidate query joined through that table returned only
**2 of 16** keyword groups, because — exactly like `spell_dbc` in `108_` — it is a sparse
overlay, not the store. **Any "does this id exist" question about a DBC must go to the
binary file.** All 18 substitutes were then confirmed present, and every one of the 32
UPDATEs was confirmed to match a live row before hand-off (29 / 2 / 2, plus spot checks
that 36774 really is Risen Dead 50374 and 36575 really is a Brazie).

### 7n. Full C++ / SmartAI port audit of map 751 — and `110_`

Asked directly: *is everything ported from the C++ and SmartAI side?* **Almost.** The port
is in good shape; three real gaps, one of which cannot be closed with data.

| | band 4.1M (1,121 entries) | band 3.6M (359 entries) |
|---|---|---|
| `smart_scripts` rows | 412 | 162 |
| `AIName = 'SmartAI'` | 412 | 134 |
| **dead (rows, no AIName)** | **0** | **28** |
| missing vs cata source | 0 | 0 |
| `creature_text` | 99 (0 missing) | 35 (0 missing) |
| C++ `ScriptName` | 25 (**1** missing) | 7 (0 missing) |

**All 12 script names resolve** — 10 creature (`npc_stable_master`, `npc_training_dummy`,
`npc_innkeeper`, `npc_chicken_cluck`, `npc_dc_scourge_cauldron`, `npc_doctor`,
`npc_garments_of_quests`, `npc_lady_sylvanas_windrunner`, `npc_prof_leather`, `npc_wg_queue`)
and 2 gameobject (`go_flames`, `go_heat`). **Check for the registration macro, not a quoted
literal** — `RegisterCreatureAI(x)` stringifies the class name, so a grep for `"x"` reports
false MISSING; two of the twelve looked absent until re-checked that way.

`DC/Plaguelands/zone_western_plaguelands_dc.cpp` exists, is wired into `dc_script_loader.cpp`
once (no double registration) and is **live on the running server** — the boot log shows
`>> Plaguelands Downport (map 751) / [OK] AddSC_dc_western_plaguelands`. That closes the
cauldron breakage the earlier audit flagged.

#### What `110_` fixes

**28 creatures + 8 gameobjects whose SmartAI never runs** — rows present, `AIName` empty,
so `FactorySelector` never builds a SmartAI and **62 rows are inert**. All 28 are in the
older 3.6M band; the new import got this right. None carries a `ScriptName` (verified 0),
which matters because `FactorySelector::SelectAI` resolves ScriptName *before* SmartAI — on
a template carrying both, setting `AIName` would be a silent no-op.

**One timed action list called but never imported.** `3610817` Duggan Wildhammer calls list
`1081700`; cata_world has its 9 rows, the import took the creature's script and left the
list behind. It is the only one of the 48 action lists map 751 calls that is missing.

**Re-homed to `361081700`, not imported at `1081700` — the load-bearing detail.** Action-list
ids follow `entry * 100`, so `1081700` belongs to **stock entry 10817, which exists here, is
spawned 4 times and has 13 scripts of its own**. Writing a Cata list into that id would hand
stock Duggan a script he never had. `3610817 * 100` keeps it in our band and the caller is
repointed. Column lists are explicit because our `smart_scripts` has `event_param6` and
`target_param4` and cata_world has neither — `SELECT *` would misalign everything after
`event_param5`.

#### The one gap data cannot close

`4107806` **Homing Robot OOX-09/HL** (Hinterlands escort) is the single entry whose source
carries a ScriptName we lack: `npc_oox09hl`. There is **no OOX script of any kind** in our
core, and neither our template nor the cata source has SmartAI rows or a waypoint path —
the source relies entirely on that C++ script. The escort needs a C++ script or a SmartAI
re-implementation with waypoints; assigning the name would only create a dead reference.

Preflighted before hand-off: 28 / 8 / 9 / 1 matches, target id empty, 62 rows going live.

### 7o. `111_` — the audit in 7n used the wrong oracle. Corrected.

Asked "what about nelt_world and source?" — and it was the right question. **7n compared map
751 against `cata_world` only.** That comparison is not wrong, it is just not the one that
decides whether content works. Map 751's creatures are **offset clones of entries that
already live in this database**, so the question is not "does cata have a script" but:

> does OUR OWN stock entry (`id − 4,100,000` / `− 3,600,000`) have a script the clone lost?

Against our own stock, matched on entry **and** name:

| lost vs our stock | 4.1M | 3.6M |
|---|---|---|
| ScriptName | 4 | 0 |
| SmartAI | 27 (69 rows) | 1 |
| `creature_text` | 23 (31 rows) | 1 |

#### nelt_world was checked too — and needs a CORRECTION

I first wrote that nelt is a TrinityCore-lineage **3.3.5** DB. **That is wrong.
`nelt_world` is a 4.3.4 Cataclysm database** — its source is
`K:\Dark-Chaos\cata stuff\Project-Neltharion-4.3.4-Cataclysm`.

The measurement stands; the explanation was wrong. nelt reports **110** entries missing
SmartAI and **37** missing ScriptNames, and **only 3 of the 25 distinct names exist in our
core** — so acting on that list would still have written 22 dead ScriptNames. But the
reason is not “AC converted them to SmartAI”; it is simply that **they are Cata-core C++
scripts and this is a 3.3.5 core**. That makes them a **porting backlog, not a data gap** —
and the source is on disk (see section 7p).

Where nelt and our stock disagree on the *name*, **our stock is right**: nelt says
`npc_halloween_fire` / `npc_halloween_orphan_matron`, AC calls them
`npc_hallows_end_train_fire` / `npc_costumed_orphan_matron`.

#### This corrected a wrong conclusion in 110_

110_ recorded the **OOX-09/HL escort** as needing C++, since cata drives it with
`npc_oox09hl` and no such script exists here. Wrong. Our own stock **7806** has
`AIName = SmartAI`, 7 script rows, **30 waypoints** and 5 text rows — AC rebuilt that escort
as SmartAI, so cloning the stock layer makes it work with no C++. (nelt spells it
`npc_00x09hl` with **zeros**, cata with letter O — which is why the grep looked conclusive.)
110_'s section has been rewritten rather than left to mislead.

#### Why verbatim cloning is safe here — classified, not assumed

Cloning `smart_scripts` across an offset band normally risks params pointing at the wrong
band. All 69 rows were classified first: **24 are action_type 11 (CAST), where param1 is a
SPELL id, not an entry**; the only entry-shaped target is `target_type 12, param1 = 1` on
the OOX robot, where param1 is a flag; and **9 rows across 6 entries call timed action lists
that already exist at their stock ids** — a list executes against its invoker, so the clone
calling the stock list is correct. That is the *opposite* of 110_, where list `1081700` did
not exist locally and had to be re-homed because its id belonged to a live stock entry.

`creature_text` is cloned in the same file on purpose: several scripts use action_type 1
(TALK) whose param1 is a text GroupID — clone the script without the text and the NPC plays
the whole sequence silently. `AIName` is set last, for the reason 110_ exists at all.

Preflighted: clone-map 28, **0 conflicts** with the 4 ScriptName entries, **0 overlap** with
110_'s set (those have rows and no AIName; these have no rows at all), and no clone already
carries a shadowing ScriptName. The two files are disjoint and order-independent.

### 7p. `K:\Dark-Chaos\cata stuff` — the C++ source IS on disk. Survey.

Correcting 7n/7o: **`nelt_world` is a 4.3.4 Cataclysm DB**, from
`cata stuff/Project-Neltharion-4.3.4-Cataclysm`. So "our core does not have nelt's
ScriptNames" is not an import defect — they are **Cata-core C++ scripts on a 3.3.5 core**.
They are a porting backlog, and the source exists. Six trees are present:

    CataTC        TrinityCore 4.3.4
    Project-Neltharion-4.3.4-Cataclysm    <- the source of nelt_world
    mangos-cata   M3ScriptDev3   m3database   m3server

**19 of the 22 unresolved ScriptNames have source available** (absent: `npc_demonic_trainer`,
`npc_calvin_montague`, `npc_astor_hadren`). Zone coverage for our eight zones, with the
better tree per zone:

| zone file | Neltharion | CataTC |
|---|---|---|
| **silverpine_forest** | **243,701 B / 35 scripts** | 4,032 B / 1 |
| hillsbrad_foothills | — | **47,051 B / 5** |
| hinterlands | **28,361 B / 5** | 7,757 B / 2 |
| western_plaguelands | **16,017 B / 5** | 5,394 B / 2 |
| undercity | 10,526 B / 3 | 11,462 B / 2 |
| eastern_plaguelands | **6,103 B / 4** | — |
| arathi_highlands | **5,251 B / 1** | — |
| tirisfal_glades | 837 B / 0 | 871 B / 0 |

#### The Forsaken Front answer, finally complete

7k concluded the Forsaken Front was "a phased Cata event that cannot be ported by SQL",
which was true as far as it went — the data layer was faithfully ported and the drama is in
C++. **That C++ exists**: Neltharion's `zone_silverpine_forest.cpp`, **6,051 lines / 35
scripts**, and it is the whole questline —

    npc_sylvanas_cities_in_dust      npc_sylvanas_rise_godfrey_scene
    npc_agatha1_silverpine           npc_arthura_ruins / _flight_escape / _flight_sepuchler
    npc_godfrey_/ ashbury_/ walden_battlefront_guardian
    npc_veteran_forsaken_trooper     npc_cowering_trooper
    npc_fallen_human_silverpine      npc_horde_hauler_north_south / _south_north
    npc_horde_cannon_45263           npc_no_escape_controller (Fenris Isle)
    npc_warchief_cometh_controller   npc_lorna_majesty
    npc_forsaken_bat_vs_murlocs_vehicle  npc_armoire_vehicle  go_7th_legion_telescope

**This is a real project, not a copy-paste.** It is 4.3.4 → AC 3.3.5: different script API,
and heavy use of Cata **phasing** and **vehicles**, which is exactly what made the area look
static in the first place. The map-750 precedent for this is `DC/MountHyjal/` (~113 script
objects across 10 files, ~8,000 lines); map 751 currently has one file. Scope it as its own
piece of work per script, starting with the pieces that need no phasing.

**Nothing in 7n–7o changes**: `110_` and `111_` are still correct and still worth applying —
they fix the data layer, which has to be right underneath any C++ port anyway.

### 7q. Starting the Silverpine port — the first slice is a SPELL downport, not a script

I proposed the haulers/cannons as a first slice. **Both were bad picks, and finding out why
is the useful part.**

**The haulers are already done, and done better than the source.** `79_` added the
`npc_spellclick_spells` rows that were the actual blocker, `83_` built the coffin wagon's
return trip by reversing path 447310 (**TrinityCore never scripted 44764 at all**), and `84_`
added the crew plus `IGNORE_PATHFINDING` for bridges our mmaps lack. Live state: VehicleId
1048/1049, spellclick set, 7 and 5 accessories, **63 waypoint_data rows each**. Crucially
TC's script **despawns** the wagon at the end of its run; ours **loops** on waypoints, which
is right for a persistent world. **Porting the C++ would regress it. Do not.**

**The cannon is not self-contained**: `npc_horde_cannon_45263` summons 7 worgen at hardcoded
entry ids and coordinates and needs a companion `SetData` AI for them — hardcoded entries
being the offset-band trap for C++ ports.

#### The triage that should have come first

35 scripts, 5,851 lines. **19 have zero phasing, zero vehicle and zero SetData** — and
`SetPhaseMask` appears only **3 times in the whole file**, so phasing is a far smaller
obstacle than assumed. The lowest-dependency scripts are exactly the reported cluster:

| script | lines | phase / veh / data |
|---|---|---|
| `npc_veteran_forsaken_trooper` | 66 | 0 / 0 / 0 |
| `npc_cowering_trooper` | 121 | 0 / 0 / 0 |
| `npc_fallen_human_silverpine` | 130 | 0 / 0 / 0 |
| `npc_arthura_ruins` | 144 | 0 / 0 / 0 |
| `npc_ashbury_battlefront_guardian` | 178 | 0 / 0 / 0 |
| `npc_walden_battlefront_guardian` | 180 | 0 / 0 / 0 |
| `npc_godfrey_battlefront_guardian` | 183 | 0 / 0 / 0 |

**The API translation is a solved problem in this repo.** `CastWithDelay`, `MoveSmoothPath`
and `SPLINE_MOTION_TYPE` do not exist on AC — and `DC/MountHyjal/` already documents the
replacement for each: TaskScheduler, a local `DoMoveSmoothPath()` helper
(`zone_azshara_cata.cpp:85`), and a documented workaround in `zone_molten_front.cpp`. The
map-750 port paved this road.

#### The actual blocker: 77 of 107 spells do not exist here

`npc_fallen_human_silverpine` is the perfect first script — the Val'kyr raise, 130 lines,
zero heavy dependencies, and it builds straight on `105_` (its float needs the DisableGravity
that file restores). It cannot work: **all 10 spells it needs are absent from Spell.dbc**,
including `83173 SPELL_RISE_FORSAKEN` — the cast that triggers the whole sequence.

Across the file: **107 distinct spell constants, 77 missing.** Also 62 NPC and 14 quest
constants to map onto the `+4,100,000` band.

The 77 split into two very different problems:

- **~68 real Cata spells** (`74279`-`93199`) — downportable with the existing `88_` /
  `spell-dbc-append.py` pipeline. The Cata client is on disk at
  `K:\UntouchedClients\Cata\Data\enUS\`, which is the same source `88_` used. **Remember the
  fork's Spell.dbc is a custom 234-field layout — `csv2wdbc` would destroy it.**
- **9 ids at 151111+** (`151111 151235 151316 151318 151319 151321 151332-151335`) — above
  the retail Cata range, so almost certainly **Neltharion-custom**. They are not in any
  client and would have to be authored or substituted.

**So the first slice is the spell prerequisite, not a script.** Nothing in the Forsaken
Front cluster can be tested before it lands. Sequence: downport the ~68 → author/substitute
the 9 → then the 7 zero-dependency scripts in the table, `npc_fallen_human_silverpine` first
because `105_` already prepared its ground.

### 7r. `112_` — the 67-spell downport, the first slice of the Silverpine port

**Feasibility answered first, as it should be.** Extracted the Cata client's
`Spell.dbc` / `SpellEffect.dbc` and checked the 77 ids the port needs:

- **67 are in the retail 4.3.4 client** — downported here, **101 SpellEffect rows**,
  and **none of the 67 lacks effects**
- **10 are NOT in the client at any id** — `151111 151235 151316 151318 151319 151321
  151332-151335`. Far above the retail Cata range, so **Neltharion-custom**: they must be
  authored or substituted, and `112_` deliberately does not invent them.

Both source row counts came back **73,232 × 48** and **97,356 × 27**, matching the recorded
calibration exactly, so the `HyjalCata/194_` column map still applies to this extract.

#### The calibration was re-verified, not assumed

Validated the 4.3.4 column map against `Spell.csv` (name-indexed and self-consistent) for
spells present in both versions: **44 fields matched, 5 differed**, and every difference is
a real Blizzard change between expansions rather than a mapping error — Fireball's range and
duration rework, Power Word: Shield's duration, Mind Blast's range, one icon. **46598, the
designated disambiguator, matches on DurationIndex 21 and RangeIndex 152 exactly.**

**A trap found on the way: `Spell.csv` has 232 columns while `Spell.dbc` has 234 fields.**
CSV column index is therefore NOT the DBC field index for Spell — an earlier calibration
attempt using CSV positions produced 31 false mismatches. It does not affect `112_`, which
writes to `spell_dbc` by **named** column and only reads the binary for the ID existence
check (field 0, unambiguous), but any positional read of that file needs its own calibration.

#### What the file does

The DieSides transform is the one that matters: 3.3.5 computes an effect as
`BasePoints + rand(1..DieSides)` and Cataclysm dropped DieSides, so every effect is written
as `DieSides = 1, BasePoints = (cata − 1)`. Verified on `83173`: Cata BasePoints 0 →
written `-1 / 1` → resolves to 0.

Escaping uses **SQL-standard apostrophe doubling, not backslashes** (backslash escaping is
wrong under `NO_BACKSLASH_ESCAPES`), with an assert on backslashes. This batch contains zero
of either across all 67 names and descriptions, so it is a no-op today and correct if the
generator is ever re-run on different spells.

Safety: `spell_dbc` is an **overlay that wins over the binary**, so a row for a spell that
already resolves would override stock globally. All 67 were confirmed absent from the
**binary** Spell.dbc (54,027 rows) — the binary is the oracle, the table is sparse and gives
false positives (the `108_` lesson).

**Server-side only.** This unblocks the scripts, which is the point. The client shows no icon
or tooltip until `Spell.dbc` itself is rebuilt with **`spell-dbc-append.py`** — never
`csv2wdbc`, which would destroy the fork's custom 234-field layout.

**Next after this lands:** decide the 10 Neltharion-custom spells, then the seven
zero-dependency scripts from 7q, `npc_fallen_human_silverpine` first.

#### `112_` shipped broken once — the comment trap, and the gate that now blocks it

The first generated file failed at apply with a 1064. The rows were emitted as

    (74279, ...)   -- Shoot,
    (76520, ...

i.e. the row separator was written AFTER the trailing comment, so the comma lived inside
the comment, MySQL never saw the separator, and the next `(` read as a new statement. The
error even points at the SECOND row (line 3) while the real fault is the end of the first.

This is trap #1 in the project's own SQL-generator notes, walked into anyway. Nothing was
lost — the DELETE ran, the INSERT failed atomically, and 0 of the 67 ended up in the table,
verified afterwards.

Fixed by emitting `),` / `);` immediately after the closing paren, before the comment. The
generator now also refuses to write at all unless three checks pass:

1. no line has a `,` or `;` inside a trailing comment (the bug above), file-wide
2. every VALUES row ends in `,` or `;` after its closing paren
3. every VALUES row is paren-balanced on the code side

Checks 2 and 3 are scoped to the VALUES block on purpose — run file-wide they fire on every
line of a multi-line verification SELECT, which is exactly what happened on the first
attempt at writing the gate.

Final shape: 67 rows, 66 ending `),`, 1 ending `);`, 0 commas inside comments, 0 unbalanced
rows, 0 double semicolons.

## 8. 2026-11-09 — graveyards, corpse runs, the Undercity teleporter, and the Silverpine C++ port

Nothing in this section has been built or run. All SQL is in `data/sql/updates/pending_db_world/`; the user
applies it. New `.cpp` files: re-run `cmake .` in `build/` before the worldserver build (LNK2019 otherwise).

### 8a. Dead players stay on 751 — `rev_1794229205267802000.sql`

- **Undercity zone 4940 had no `graveyard_zone` row**, so a death inside Undercity fell back to the faction
  default graveyard on another continent. Linked like stock 1497: Horde 15101, Alliance 15122.
- The dungeon copies keep stock zone ids (821 → 2017, 822 → 2057, 825 → 209), which linked map-0 graveyards
  only. Linked 15127 / 15139 / 15137. `GetClosestGraveyard` prefers a graveyard on the instance's Map.dbc corpse
  map, so stock 329/289/33 (corpse map 0) are unaffected.
- **Map.dbc 825 corpse map 0 → 751** (821/822 already were): server `data/dbc`, `Custom/DBCs`, `Map.csv` and the
  test client's `patch-4` (backup `patch-4.MPQ.pre-graveyards-20261109.bak`). Live client not updated.
- **Corpse runs were impossible on all three**: their walk-in trigger creatures react in `MoveInLineOfSight`,
  which the grid notifier never calls for a non-alive unit (`GridNotifiers.cpp` `CreatureUnitRelocationWorker`).
  `src/server/scripts/DC/dc_portal_trigger_ghosts.h` + a 500 ms poll in each entrance trigger's `Reset()` now
  sends released ghosts whose corpse is in that instance through the door.

### 8b. Undercity as the Horde capital — `rev_1794230911578182200.sql`

User decision 11-09: Horde only, no Alliance hub, DarkChaos services = the teleporter only. Teleporter menu row
509 "Undercity (Lordaeron)" under Custom Locations, faction 1, arriving at `game_tele` 10649 `dcundercity`
(Trade Quarter lower floor, z -62.08); Teleporter NPC 800002 at guid 9025010, 3 yd in front of it. The Forever
model, HD textures, doodads and minimap were already done on 10-04 (`wow-forever-ruins-of-lordaeron` memory);
area 4940 carries stock Undercity's capital/rest flags. Zone 4934 stays unused (4940 is the Undercity).

### 8c. The Silverpine port — `src/server/scripts/DC/Plaguelands/Silverpine/`

Ported from Neltharion's `zone_silverpine_forest.cpp` in six slices (shared header `silverpine_dc.h`), all
passing `cl /Zs` and the linters, wired in `dc_script_loader.cpp`. Haulers deliberately not ported (7q).

| slice / file | ported | not ported (why) | SQL |
|---|---|---|---|
| `silverpine_dc_high_command.cpp` | Warchief Cometh scene (on Mortuus 4144615), fallen humans 4144592/93, trooper transform 83149, orc crate 83837, webbed victim 4144941, sea dog 44942 | bat vs murlocs, armoire, exsanguinate, sea pup (quests/NPCs/spells/vehicles missing) | `rev_1794231370760034900` |
| `silverpine_dc_fenris_isle.cpp` | Agatha 44951, refugee credit hook, No Escape controller 4174952 + camera, resummon controller 4174951, Sylvanas horse ride | — (stock vehicles 532/747/636 stand in for missing 1070/1075-1077) | `rev_1794231912675445000` |
| `silverpine_dc_sepulcher.cpp` | Horde cannon 4145263 + worgen 45270 AI, 7th Legion telescope (Bind Sight camera) | Forteski, veteran trooper, Arthura sepulcher flight (quest 27195/27290 and NPCs missing) | `rev_1794231014906273700` |
| `silverpine_dc_ruins.cpp` | Arthura/Belmont guardians, guardian-summon PlayerScript, flight escape (needs vehicle 1119), Rise Godfrey scene, Ataeric 4102120 | — (flight and scenes blocked by data) | `rev_1794231424479070000` |
| `silverpine_dc_battlefront.cpp` | Godfrey/Walden/Ashbury battlefront guardians, cowering trooper 4145910, Lorna 4145997 + 23 spawns | — | `rev_1794230792108074800` |
| `silverpine_dc_cities_in_dust.cpp` | mutant bush chicken 44935, Cities in Dust scene (private per player via visibleBySummonerOnly) | — | `rev_1794230771559692400` |

Central fixes found by the port:
- **SummonProperties** `rev_1794231896144905400.sql`: 22 Cata rows (2987-3162) that 43 `spell_dbc` summon spells
  name and nothing provided; flags masked to 0xFFFF, Cata faction 10608 → 0.
- **EffectRadiusIndex** — Cata stores many area radii in EffectRadiusMaxIndex, the downport generators copied only
  EffectRadiusIndex, so the effect hit nobody. `rev_1794231870185590000.sql` = the 8 Silverpine spells (Raise
  Forsaken 83173 ...); `rev_1794231871391082300.sql` = 186 other spells incl. **Blackwing Descent / Firelands boss
  abilities — a behaviour change, apply on purpose**. Generator `retailextracts/_spellradius_fix_20261109/_scripts`.
  The same bug exists in `gen_silverpine_spell_downport.py` and the HyjalCata generators: copy col 16 when col 15 is 0.

### 8d. What still blocks the Silverpine story (next data round, not started)

- **Quests missing from `quest_template`** (cata_world has them; the 751 import skipped quests whose giver had no
  spawn): 27096's ender, 27097-27099, 27180, 27195, 27290, 27472-27475, 27484, 27512, 27518, 27542, 27547, 27594,
  27601, 26998; 27045 has no giver/ender; 27438 needs SpecialFlags 2; 27406/27423 objectives unobtainable.
- **NPCs**: Lady Sylvanas 45617 (Forsaken Front giver), 44365 as a quest NPC (high_command imports only a summon
  template), 45525, 46124, 45318, 45228/45225/45236/45237/74948, 44821, 44893/44883/44884/74953, 44914, 44369 spawn,
  4102120 spawn. Do not port 45617's quest-accept SmartAI (cities_in_dust starts the scene in C++) and do not
  summon Sylvanas's horse from her (fenris_isle does it on accepting 27098).
- **Vehicles** (client + server Vehicle/VehicleSeat.dbc): 1060, 1100, 1105, 1119 (then 45555 VehicleId 1119), seat 1170.
- **Spells absent everywhere** (substituted or skipped): 84575/84574/84563, 84468, 84695/84691, 98707, 91166, 79848,
  85073, 85150, 83752/83753/83763/83764, 83838, 84128, 83990/83996, 84180/84199, 83998-84005, 84054-84061, 84094-84099.
- **Displays** (stand-ins used): 34520 Lorna, 34161 Crowley, 30735 Ashbury, 30730 Walden, 35323, 32698, 34008, 34179,
  34205; trooper female set 33991-33994. Voice kits 20459-20504 missing (texts carry Sound 0).
- 44942 / 45270 are still at source level (11-13), outside the 134-140 band.
