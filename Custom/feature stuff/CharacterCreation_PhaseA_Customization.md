# Phase A — Enhanced Character Creation (Authoring Reference)

Goal: add more appearance options (skin tones, faces, hair, facial hair) to the existing
playable races on the 3.3.5a client. This is the data + art side; the create-screen UI reskin
is Phase B and is independent.

> **Custom DBC vs. stock DBC — read first.** The client's built-in character renderer reads the
> **stock** `CharSections.dbc` / `CharHairTextures.dbc` / `CharHairGeosets.dbc` /
> `CharacterFacialHairStyles.dbc` directly from the engine. It does **not** read the
> WotLK-Extensions custom `.cdbc` tables. Custom CDBCs (confirmed working: `LFGRoles`,
> `ZoneLight`, `DCCollection*`, …) are for **new** DLL/Lua-driven features — they cannot feed the
> native creation screen. **Phase A therefore extends the stock tables**, not a CDBC. (A future
> retail-style customization UI driven entirely by Lua + DLL geoset control could use a CDBC, but
> that is a much larger Phase-B+ project.)

---

## Where things live (deployment)

| Artifact | Location | In repo? |
|----------|----------|----------|
| Editable source | `Custom/CSV DBC/CharSections.csv` | ✅ yes |
| Compiled DBC | `Custom/DBCs/CharSections.dbc` (CSV→DBC external tool) | ✅ yes |
| Companion DBCs | `Custom/DBCs/CharHairTextures.dbc`, `CharHairGeosets.dbc`, `CharacterFacialHairStyles.dbc` | ⚠️ compiled only — **no CSV source**; edit with a DBC editor |
| BLP textures + final MPQ | external (OneDrive `Patch-A`/`Patch-4`, see `Custom/Client patches needed/information.txt`) | ❌ not in repo — your extraction/downport tooling |

`Patch-A` already = "AllRaces All Classes", so client-side race/class gating is lifted.

---

## CharSections.csv schema

Columns: `ID, RaceID, SexID, BaseSection, TextureName_1, TextureName_2, TextureName_3, Flags, VariationIndex, ColorIndex`

- **RaceID** 1–11 = playable; **12–21** = reskin/creature races already partly wired (Fel Orc, Naga,
  Broken, Vrykul, Tuskarr, Forest Troll, Ice Troll…).
- **SexID** 0 = Male, 1 = Female.
- **BaseSection** (the appearance axis):

| Sec | Meaning | TextureName_1 / _2 | Create-screen slider |
|-----|---------|--------------------|----------------------|
| 0 | Skin | body skin | **Skin Color** = `ColorIndex` |
| 1 | Face | FaceLower / FaceUpper | **Face** = `VariationIndex` (one texture per skin `ColorIndex`) |
| 2 | Facial Hair | FacialLowerHair / FacialUpperHair (shared `Character\<Race>\` folder) | **Facial Hair** = `VariationIndex` (recolored by hair `ColorIndex`) |
| 3 | Hair | **empty** — mesh is a geoset, recolored via `CharHairTextures.dbc` | **Hair Style** = `VariationIndex`; **Hair Color** = `ColorIndex` |
| 4 | Underwear | NakedPelvisSkin | follows skin `ColorIndex` |

- **VariationIndex** = which shape/style on that axis (face #, hair style #, beard #).
- **ColorIndex** = which color slot (skin color for sec 0/1/4; hair color for sec 2/3).
- **Flags** (empirical): `17` = standard player option (skin/facial/hair/underwear); `1` = standard
  face; bit `0x4` (`5`,`6`) = **Death-Knight-gated** (the pale/glow sections). New player-selectable
  rows should copy the stock flag of the same section (`17`, or `1` for faces). Don't set `0x4`
  unless intentionally DK-only.
- **ID**: must be unique. Current **max ID = 14078**. Allocate new rows from a reserved block —
  recommend **`900000+`** (obviously custom, clear of retail DB2 ids) — incrementing per row.

Tooling — `Custom/CSV DBC/charsections_inventory.py`:
- `inventory [--all|--race N]` — current counts + next-free indices on any race.
- `gen-skin --race N --count K [--apply] [--manifest PATH]` — generate the rows for K new skin
  tones (both genders): skin + underwear + one face recolor per existing face variation. Texture
  paths are derived from real template rows (color suffix rewritten), IDs from `900000+`, flags
  copied from the template. Dry-runs to stdout unless `--apply`; always writes a BLP manifest.
  DK-flagged face variations reuse base face art, so the manifest dedupes to far fewer textures
  than rows.

---

## What it costs to add each option (art is the gate)

| Add | Tables to edit | Textures needed | Cost |
|-----|----------------|-----------------|------|
| **Skin tone** | `CharSections` sec 0,1,4 (only) | 1 body skin + 1 underwear + **one FaceLower+FaceUpper per existing face** + body region BLPs (torso/legs) | medium (CharSections-only ✅) |
| **Face** | `CharSections` sec 1 (only) | FaceLower+FaceUpper **per existing skin color** | medium (CharSections-only ✅) |
| **Hair color** | `CharSections` sec 2,3 + `CharHairTextures.dbc` | 1 hair recolor texture set + facial-hair recolors per beard | medium (needs binary DBC) |
| **Hair style** | `CharSections` sec 3 + `CharHairGeosets.dbc` + **model geoset in race M2** | hair mesh geoset + textures | **high** (M2 edit) |
| **Facial hair** | `CharSections` sec 2 + `CharacterFacialHairStyles.dbc` (+ geoset if new) | FacialLower/Upper hair textures | medium–high |

**Cleanest repo-side wins = skin tones and faces** (touch only `CharSections.csv`). Hair/facial-hair
also require editing the binary companion DBCs (no CSV source) and, for new styles, an M2 geoset
edit (your downport tooling).

---

## Worked example — add 1 new face to Human Male

Human Male currently has faces var 0–23 (next free `VariationIndex = 24`) across skin colors 0–14.
A new face = **15 rows** (one per skin color), reusing the next-free var across all colors:

```
"900001","1","0","1","Character\Human\Male\HumanMaleFaceLower24_00.blp","Character\Human\Male\HumanMaleFaceUpper24_00.blp","","1","24","0"
"900002","1","0","1","Character\Human\Male\HumanMaleFaceLower24_01.blp","Character\Human\Male\HumanMaleFaceUpper24_01.blp","","1","24","1"
...
"900015","1","0","1","Character\Human\Male\HumanMaleFaceLower24_14.blp","Character\Human\Male\HumanMaleFaceUpper24_14.blp","","1","24","14"
```

Then supply matching BLPs at those 30 paths (15 lower + 15 upper). After CSV→DBC compile and MPQ
repack, the "Face" arrow on Human Male gains one more option.

---

## Per-batch checklist

1. Pick race / gender / axis / count; run the inventory tool for next-free indices.
2. Extract/downport source art → BLP at the convention paths (`Character\<Race>\<Sex>\...`).
3. Add `CharSections.csv` rows (unique IDs from the reserved block; copy section flag).
4. For hair color/style or facial hair: also edit the binary companion DBC.
5. (Phase C) mirror new hair/facial-hair into `BarberShopStyle.dbc` so it's changeable at the barber.
6. Compile CSV→DBC → copy into the patch `DBFilesClient` → repack MPQ.
7. Verify in client (see roadmap plan): the new option cycles and renders for that race+gender.

---

## Best first-batch candidates (most headroom, CharSections-only)

- **Scourge/Undead**: only 6 skin tones (M+F) — add skin tones.
- **Night Elf**: 12 skin tones, 18 faces — add skin tones and/or faces.
- **Gnome**: 10 skin tones, 14 faces — add either.
- Already-saturated (lower priority): Dwarf (22), Tauren (25), Blood Elf (19) skins.

---

## Tooling (texture verification)

- `charsections_check_textures.py [--csv X] [--exclude-id-min 900000]` — quick present/missing
  count of referenced textures vs the export tree.
- `charsections_reconcile.py [--csv X] [--prefix P]` — classifies every reference as PRESENT /
  RELOCATED (same file under a wrong sub-path, e.g. shared facial-hair/scalp put under `Male/Female`
  but the DBC wants race-root) / ABSENT (needs re-export). Writes `<prefix>_relocated.txt` (move
  list) and `<prefix>_absent.txt` (re-export checklist) with original DBC casing. Race-scoped
  matching (generic names like `FacialLowerHair00_00.blp` recur per race, so cross-race matches are
  not treated as relocations).

## Reference table found with the art

`CharSectionsasc.csv` (24,634 rows, same schema) is a different lineage: base races 1–11 identical
to ours, **adds** full Goblin (race 9) + allied/HD-variant races (Human2=51, Orc2=52, Vulpera…) that
match the extra export folders, but **lacks** our WotLK creature reskins (Naga 13, Broken 14, Tuskarr
17, ForestTroll 18, IceTroll 21) and uses a conflicting race-ID scheme. Merge source for new races,
not a drop-in replacement.

## Batch log

- **Undead/Scourge skin tones 6–9** — generated then **REVERTED** (rows `900000–900175` removed).
  The export confirmed the source has no complete extra Undead tones (only a partial color-6); ASC
  also keeps Undead at 6. Skin-tone expansion needs hand-recoloring, not extraction.
