# Playable Pandaren — port scope

Status: **BUILD COMPLETE (2026-08-27) — everything staged, user actions remain.** SQL set + racials + C++ done (see `00_README.md`). To go live: (1) copy `dbc_server/` to the Linux worldserver dbc dir, (2) `mysql acore_world < apply_all.sql`, (3) rebuild worldserver. Modelled 1:1 on the Worgoblin port
(`../Worgoblin/00_README.md`), which is the only working precedent on this server.

Decision taken up front: **two ChrRaces rows**, Pandaren (Alliance) and Pandaren (Horde).
Costs 2 of the 10 remaining race slots, leaves 8.

---

## 1. Donor — verified, self-contained

Everything comes from **`K:\ascension_live\Data`**. Nothing needs converting; Ascension already
did the offline MD21 → v264 conversion that has never worked in-house
(see `hd-character-model-replacement` — raw retail MD21 = T-pose).

### Art — `patch-CHA.MPQ`, `Character\Pandaren\` (1,089 files)

| | male | female |
|---|---|---|
| model | `PandarenMale.m2` | `PandarenFemale.m2` |
| skin | 1 (`nViews=1`) | 1 |
| BLP | 438 | 335 |
| `.anim` | 101 | 210 |

`PandarenMale.m2`: **MD20 v264**, 208 bones, 326 sequences, texture types `[0,1,2,8]`.
All types ≤ 13, so nothing samples white on the LK client — the exact acceptance test from
the July HD harvest. `PandarenFemale.m2`: v264, 334 sequences.

One stray file sits at the race root, `eyes00_00_3513030.blp` — a retail FileDataID artifact,
referenced by nothing. Drop it.

### DBC rows — `patch-M.MPQ` (Ascension race id **20**)

| DBC | rows for race 20 | layout |
|---|---|---|
| `ChrRaces` | 1 (`Pandaren`, prefix `Pa`, M `141687` / F `141688`) | 69 fields — **identical to ours** |
| `CharSections` | **1,364** | 10 fields — identical to ours |
| `CharHairGeosets` | 37 | 6 fields — identical |
| `CharacterFacialHairStyles` | 111 | 8 fields — identical (**not** the 9-field HD variant) |
| `CreatureDisplayInfo` | 141687, 141688 | → `CreatureModelData` 112929 / 112930 → the two `.m2` |

CharSections breakdown — male 17 base skin / 357 face / 374 hair / 17 underwear;
female 17 / 340 / 225 / 17.

`CharComponentTextureLayouts` and `CharComponentTextureSections` are **not shipped** by
Ascension, which means Pandaren reuses a stock composite layout. No new layout row is needed —
this was the biggest open risk and it is closed.

---

## 2. Validation already run

- **Zero dangling textures.** All 761 distinct texture paths referenced by the 1,364
  CharSections rows resolve inside `patch-CHA.MPQ`. This is the check that produced 877 dangling
  refs on the HD harvest; Pandaren is clean.
- **Male "hair" rides the type-8 slot.** Male section-3 rows point at
  `pandamaleskinextra##_##.blp`, not a hair texture family — there is no `pandamalehair*`. That is
  the same type-8 skin-extra binding already proven working on our client
  (`hd-character-harvest-ascension`). Female hair uses a normal `pandafemalehair_##.blp` family (15).
- **`ascension_ptr` has no Pandaren at all** — `patch-CHA.MPQ` is the only donor in existence here.

### The one real gap: missing male animations

| | external sequences declared | `.anim` files present | **missing** |
|---|---|---|---|
| male | 213 | 101 | **112** |
| female | 225 | 210 | 15 |

Missing ids skew high — 804–942, i.e. emotes, dances and specials — plus 136, 199, 208, 209, 210.
There is no fuller donor, so **Ascension's own Pandaren males have this same gap**. Options are
accept it, or hand-author fallbacks later. It does not block the port and it will not T-pose the
idle/combat set, but expect dead emotes.

---

## 3. ID allocation (ours)

| Asset | Allocation | Current ceiling |
|---|---|---|
| `ChrRaces` | **22** Pandaren (Alliance, FactionID 1) · **23** Pandaren (Horde, FactionID 2) | 21 rows used |
| racemask bits | bit 21 `0x200000` (A) · bit 22 `0x400000` (H) — combined `0x600000` | uint32, hard wall at race 31 |
| `CreatureModelData` | **503900** (M), **503901** (F) | client CSV max 503824 |
| `CreatureDisplayInfo` | **503910** (M), **503911** (F) | client CSV max 503881 |
| `CharSections` | **920000+** (race 22) / **925000+** (race 23) — 2,728 rows | client max 911363 (HD rows; server copy stops at 900410) |
| `CharHairGeosets` | **563–636** — 74 rows (37 × 2) | max 562 |
| `CharacterFacialHairStyles` | 222 rows (111 × 2); race-keyed, no ID column | 306 rows |
| `CharBaseInfo` | +20 rows (2 races × 10 classes) → 140 | 120 rows |
| client MPQ | **`patch-I.MPQ`** — first free slot (2–9, A–H all taken) | — |

The customization DBC rows duplicate because the race id is part of the key. That is the whole
marginal cost of the two-row decision; it is scripted, not hand-work. Models, displays and every
BLP are shared between the two rows.

**Give it its own MPQ slot.** patch-9 (Worgoblin) was silently clobbered twice by other pipelines
before it got a dedicated archive; do not co-tenant this into patch-G/H.

---

## 4. Client-side work

1. Harvest `Character\Pandaren\` from `patch-CHA.MPQ` → stage → pack to **`patch-I.MPQ`**.
2. DBC edits (both the client `Custom/DBCs/` set **and** `Server/data/dbc/`):
   `ChrRaces`, `CharSections`, `CharHairGeosets`, `CharacterFacialHairStyles`, `CharBaseInfo`,
   `CreatureModelData`, `CreatureDisplayInfo`, `CharStartOutfit`.
3. Mirror the changed DBCs into the **enGB-3 shadow** — enGB shadows DBCs, and a stale mirror is
   what reverted Worgoblin to "Too many races!" after the July Light-DBC rebuild.
4. GlueXML: `MAX_RACES` 12 → **14**, plus create-screen button layout and two entries in the
   racial icon atlas. The layout is the part that gets ugly — 14 buttons is past what the stock
   frame was laid out for.

## 5. Server-side work — the Worgoblin 14-file set

`SharedDefines.h`: `RACE_PANDAREN_ALLIANCE = 22`, `RACE_PANDAREN_HORDE = 23`.
Racial script under `src/server/scripts/DC/Races/` (Worgoblin's is 67 lines).

SQL set mirrors `../Worgoblin/` file-for-file:

| File | Notes |
|---|---|
| `01_playercreateinfo.sql` | 20 rows (2 races × 10 classes) at the DC universal start — Azshara Crater, **map 37 zone 268**, same coords as Worgoblin |
| `02_player_race_stats.sql` | base stats |
| `03_playercreateinfo_skills.sql` | racial + weapon skill lines |
| `04_playercreateinfo_spell_custom.sql` | class spells per race mask + racials + languages |
| `05_playercreateinfo_action.sql` | action bars, incl. ARAC clones for off-class combos |
| `06_race_mask_sweeps.sql` | open quest/item `AllowableRace(s)` for bits 21+22 — **pin ARAC's mask first**, that ordering bug bit Worgoblin |
| `07`–`08` | mount items / display + creature metadata |
| `09_spell_script_names.sql` | Quaking Palm needs a script |
| `10_spell_dbc.sql` | server-side spell rows, generated 1:1 from the client Spell.dbc |
| `13_language_skills.sql` | **Pandaren** language for both rows, plus Common (A) / Orcish (H) |
| `14_starting_gear_stats.sql` | backfill if the outfit items come in stat-less |

Racials to source: Epicurean, Gourmand, Inner Peace, Bouncy, Quaking Palm.
**Do not hand-write spell ids** — read them out of the donor Spell.dbc, and remember the fork's
`Spell.dbc` is the **234-field** layout, so `csv2wdbc` would destroy it. Use `spell-dbc-append.py`.

---

## 6. Blocker to clear first

**`Custom/Worgoblin/` is gone again.** It held `DEPLOY.md`, the staged `dbc/` set and
`deploy/*.setfile` — i.e. the exact client-side deployment recipe this port needs to copy. It is
not in any of the three checkouts and it is **not recoverable from the recycle bin** (scanned all
`$I*` metadata records, zero hits). It was already lost once in July and recovered from the bin;
that escape hatch is closed now.

What survives: this SQL half (`../Worgoblin/`, 14 files + README) and the deployed artefacts
themselves — `patch-9.MPQ` in the live client and the current `Custom/DBCs/`. So the recipe is
reconstructible from the deployed state, but it has to be redone by reading the archive rather
than a document.

---

## 7. Build state 2026-08-27 (what is already done)

- **Art harvested**: 1,088 files (stray root blp dropped) → `K:\Dark-Chaos
etailextracts\pandaren_playableiles\Character\Pandaren\`. All 773 BLPs valid BLP2/hasMips=1; all 761 CharSections-referenced textures verified present on disk.
- **Donor DBCs staged permanently**: `retailextracts/pandaren_playable/donor_dbc/` (7 tables from ascension patch-M).
- **Client DBC rows built** via `tools/gen_pandaren_dbcs.py` (idempotent, `.pre-pandaren.bak` backups):
  - CSVs appended + compiled with csv2wdbc: CharSections (+2,728), CharHairGeosets (+74, ids 563–636), CharacterFacialHairStyles (+222, csv ids 307–528), CreatureModelData (+2), CreatureDisplayInfo (+2).
  - Binary appends: ChrRaces (+22/+23), CharBaseInfo (+20: classes 1–9,11 ×2), CharStartOutfit (+40, ids 243–282: human rows→22, orc rows→23).
  - Verified: **zero pre-existing rows changed** in any recompiled table (semantic diff vs .bak).
- **Server DBC variants staged** (NOT yet copied to `Server/data/dbc`): `retailextracts/pandaren_playable/dbc_server/` — all 8 tables, appended onto the server's own (older) copies so the server does not inherit the client-only HD CharSections rows.
- **Two traps hit and fixed during the build**:
  1. The WDBX defs give `CharacterFacialHairStyles` a 9th (ID) column; the live client DBC is 8-field. csv2wdbc output was post-processed to drop the synthetic ID. Any future recompile of this table must do the same.
  2. `CreatureDisplayInfo.csv` had 9 pre-existing rows (39812–39819, 39823) whose `CreatureModelScale` cell held the raw float BIT PATTERN (`1065353216` instead of `1`) — a stale export bug that would corrupt those scales on any recompile. Cells fixed to `1` / `1.75`.
- **ChrRaces row detail**: cloned from our Worgen row (locale masks preserved); flags=4, cinematic=0, explorationSound inherited (4143), f13 side=0/1, baseLanguage 7/1, facial-hair customization labels NORMAL/EARRINGS/NORMAL (donor), requiredExpansion=0.

Deploy recipe to follow: `../Worgoblin/DEPLOY_RECONSTRUCTED.md` (written 2026-08-27 after the
Custom/Worgoblin source loss — note the live layout moved: char art in patch-7, DBCs in patch-4
+ enGB-3 shadow, GlueXML in enGB-3, patch-9 repurposed for Lordaeron world art).

## 8. Client deploy 2026-08-27 (done, all byte-verified)

The patch-I idea was dropped: the 2026-08-04 role-partitioned layout + `dc_mpq_deploy.py`
routing IS the anti-clobber mechanism — never pick a patch letter by hand.

| What | Where | How |
|---|---|---|
| 1,088 art files | **patch-7** (CHARACTER role) | `dc_mpq_deploy.py --apply` — replaced the raw Ascension pandaren tree the July HD harvest had shipped there |
| 8 DBCs | **patch-4** + **patch-enGB-3** mirror | `mpq_stormlib_patch.py`, 8/8 byte-verified each |
| GlueXML (`CharacterCreate.lua/.xml`) + race atlas | **patch-5** (root outranks enGB) | MAX_RACES 12→14; buttons 13/14 appended to both columns |
| WXL candidate dirs | all 3 checkouts | `sync-dbc-deploy.js` |

**Race icons**: Blizzard's own — the MoP-Classic glue atlas
(`WoW 11.2.5 PTR interface extract/glues/charactercreate/ui-charactercreate-races.blp`) carries
PANDAREN_MALE at `{0.750, 0.875, 0, 0.25}` / FEMALE at `{0.750, 0.875, 0.5, 0.75}` — exactly the
free column of our atlas (same HD icon lineage). Cells transplanted by encoding just those 682
DXT3 blocks and splicing them in; every untouched block stays byte-identical (our file is DXT3,
MoP's is DXT5 — no raw block copy possible). Same tcoords added to our lua.

Everything client-side is **inert until the server offers races 22/23** (GetAvailableRaces is
server-driven), so nothing changes in-game until the SQL + C++ half lands.

## 9. Create-screen integration fixes (2026-08-27, after first in-client test)

Pandaren appeared on the create screen (server DBCs live) and broke it in four places —
all fixed in staging (`Custom/Client patches needed/Interface/GlueXML/`) + deployed to patch-5:

1. `CharacterCreate.lua:285` nil-concat → `RACE_INFO_PANDAREN` + `ABILITY_INFO_PANDAREN1..5`
   added to `GlueStrings.lua` (now also carried in staging; it previously lived only in the archive).
2. Race grid scrambled → `DCCharCreateLayout.lua` faction split now resolved per index via
   `GetFactionForRace` (was fixed 1-6/7-12), loops to `MAX_RACES`, re-layout on OnShow,
   horde crest follows via the new `hordeCrest` upvalue. Buttons 13/14 also now hide in the
   customize stage (they lingered over the panel).
3. Face zoom framed the torso → `DCGlueCamera.lua` `EYE_HEIGHT[22]/[23]` = 2.10 M / 1.95 F
   (MoP-Classic camera targets); `FACE_TUNE` trim pending in-client review.
4. Grey swatches → `DCCharCustomizeData.lua` regenerated with races 22/23 (132 sampled colors).
   The generator survives ONLY as `__pycache__` pycs (`gen_charcustomize_data` +
   `charsections_inventory`, sources deleted); run sourceless with
   `charsections_inventory.RACE_NAMES[22/23]` patched at runtime. See memory
   `new-race-create-screen-checklist`.

All five edited lua files pass `luac -p`; deploys byte-verified.

### Round 2 (same day, after the grid fix went in)

5. **Whole 3D scene black + broken character models** - with the line-285 error gone,
   `SetCharacterRace` reached `SetBackgroundModel`, which derives
   `Interface\\Glues\\Models\\UI_Pandaren\\UI_Pandaren.m2` from the ClientFileString. No such
   model exists in 3.3.5 (Worgoblin shipped downported UI_Worgen/UI_Goblin to patch-5; Ascension
   has no UI_Pandaren either) and a missing glue scene blanks background AND character. Fixed at
   the single choke point (`GlueParent.lua SetBackgroundModel`, covers create + select):
   Pandaren remaps to the NightElf scene (ambience/lighting/camera follow the name). Proper fix
   later: downport MoP's UI_Pandaren (Wandering Isle) through the model pipeline.
6. **Race panel too tall** - 7 races per faction at 3 columns = 3 rows each, pushing the class
   grid off-screen. `RACE_COLUMNS` 3 -> 4 (each faction back to 2 rows).
