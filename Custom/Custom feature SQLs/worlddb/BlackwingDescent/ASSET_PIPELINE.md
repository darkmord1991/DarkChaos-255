# Blackwing Descent (map 669) — asset pipeline status & checklist

Server-side (C++, SQL, load-critical DBCs) is complete and compiling. This tracks the **client asset
pipeline** (PHASE 4): terrain/collision/nav, boss + GO models, and the MPQ pack.

## ✅ Terrain — BAKED (the long pole)
`node tools/downport-map.js 669 --package` completed against retail **12.0.7.68275**:
- Output project: `K:\Dark-Chaos\retailextracts\blackwingdescent_335` (client-patch layout `_patch4/_patch5/_patch6`).
- Contents: **18 ADT, 168 M2, 34 WMO, 414 BLP** — last bake `112 downported, 270 copied, 0 missing` (fully self-contained).
- Interior WMO `world/wmo/dungeon/blackwingv2/blackwingv2.wmo` + 452 doodads baked & relit.
- Elevators baked as **M2 doodads**: `world/blackwingv2/passivedoodads/blackwingv2_elevator01.m2` and
  `..._elevator_onyxia.m2` (retail ships them as M2, not the WMO-transport path in EXTRACTED_DBC_VALUES —
  repoint GODI 10363/10407 to these M2 paths, or bake the WMO-elevator separately if the transport needs it).
- Minimap: 9 tiles → `textures/minimap/BlackwingDescent/`. Loading screen id 260. World-map art: 12 BLPs.
- Auto-merged into the DC master `Custom/CSV DBC`: LoadingScreens +1 (260), WorldMapArea +1 (**removed** — it
  duplicated my 1220 which has the AreaTable 5788 link; kept 1220). Map.csv 669 kept InstanceType=2 (raid).

### Remaining terrain steps (deploy)
1. **MPQ pack**: pack `blackwingdescent_335` (`world/`, `textures/`, `dbfilesclient/`, `_patch*`) into a 3.3.5
   patch MPQ via `tools/mpq_stormlib_pack.py`. Deploy to the live client `Data\`.
2. **AC collision/nav**: point the AzerothCore extractors at that MPQ-backed Data tree —
   `map_extractor` → `669*.map`, `vmap4_extractor` + assembler → `669*.vmtree/.vmtile`,
   `mmaps_generator` → `669*.mmtile`. Deploy to `Server\data\{maps,vmaps,mmaps}\`. **Never validated
   end-to-end on a DC Cata map — budget iteration** (lava = liquid type 7; interior WMO is the bulk).

## ✅ Boss creature models — 7 M2 BAKED (DBC rows: CreatureModelData 501631-501638, CreatureDisplayInfo)
All 7 unique models exist in **retail 12.0.7** (the display *ids* renumbered, but the model *paths* are stable).
Baked via `casc-extract creature/<name>/ → wxl-baker --in <dir> --file ... --deps --native-m2` and folded into
`blackwingdescent_335/creature/`:
- onyxiaundead, lavaworm_02, chimerabeast, golemdwarven — 0 missing deps.
- dragonnefarianzombified, dragonatramedes — a few missing deps = **stock 3.3.5 shared textures**
  (`spells/clouds8x8`, `bloodspurtsmall01`, ICC/Northrend particle BLPs) already in the base client.
- dragonman (Maloriak) — 7 `.anim` sequences are `notinroot` in retail 12.0.7 (backfill from K:\Cata if a
  specific animation is needed; the model renders + has its main anims).

The original K:\Cata note below is retained as an alternate source if a retail asset is ever missing.

| Display | Model (501xxx) | Cata M2 path | in retail 12.0.7? | Textures |
|---|---|---|---|---|
| 32569 Onyxia | 501631 | creature\onyxiaundead\onyxiaundead.m2 | no (K:\Cata only) | (base) |
| 32716 Nefarian | 501632 | creature\dragonnefarianzombified\dragonnefarianzombified.m2 | yes | DragonNefarianZombified1/2/3 |
| 33186 Maloriak | 501633 | creature\dragonman\dragonman.m2 | yes (as `dragonman_var1.m2`) | DragonManBodyRed/ArmorRed/Potions |
| 34547 Atramedes | 501634 | creature\dragonatramedes\dragonatramedes.m2 | yes | DragonAtramedesHead/Wing/BodyYellow |
| 32679 Magmaw | 501635 | creature\lavaworm\lavaworm_02.m2 | no (K:\Cata only) | (base) |
| 32687/85/88/84 Omnotron | 501636 | creature\golemdwarven\golemdwarven.m2 | yes | GolemDwarven_{Purple,Red,Blue,Green}(+_Glow) — 4 CDI variants, 1 model |
| 33308 Chimaeron | 501637 | creature\chimerabeast\chimerabeast.m2 | no (K:\Cata only) | (base) |
| 33716 Finkle | 501638 | character\gnome\male\gnomemale.m2 | **STOCK 3.3.5 — no bake** | (stock) |

Watch the white-model / empty MONSTER-texture issue: fill `CreatureDisplayInfo.TextureVariation_1..3` with
the extracted skin basenames (already done in the CDI rows above).

## GO models (GameObjectDisplayInfo 9683/9946/10138/10139/10363/10407/10463)
5 M2 doors (gong, portcullises, growth chambers) ship as-is from the terrain bake's model set; the 2 elevators
are baked as M2 (see above). Verify each GODI ModelName resolves to a baked path in the MPQ.

## MPQ pack (final)
One patch MPQ containing: the terrain project + the 7 baked boss M2s (+ textures) + the client Spell.dbc /
Item.dbc / CreatureModelData.dbc / CreatureDisplayInfo.dbc / DungeonEncounter.dbc / VehicleSeat.dbc recompiled
from the updated `Custom/CSV DBC` (via `csv2wdbc.py`). Deploy to the live client `Data\`.
