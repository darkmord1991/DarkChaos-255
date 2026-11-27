# DarkChaos client patch layout

Canonical map of which asset lives in which `Data\patch-*.MPQ`. Rebuilt 2026-08-04 from the
previous 17-archive layout, which had grown to 32.4 GB with roles smeared across archives.

The machine-readable source of truth is `K:\Dark-Chaos\retroport_tools\dc_mpq_layout.py`.
**Deploy pipelines should call `dest_for(path)` from that module instead of hardcoding a letter.**

## The archives

| Patch | Role | Contents | Files | On disk |
|---|---|---|---|---|
| `patch-4` | CORE | `DBFilesClient\`, `World\Maps\`, `textures\Minimap\` (incl. `md5translate.trs`) | 10,922 | 1.40 GB |
| `patch-5` | UI + ICONS | `Interface\`, including `Interface\Icons\` | 22,463 | 0.25 GB |
| `patch-6` | MISC | `Sound\`, `tileset\`, `xtextures\`, `wxlheight\`, `models\`, `spells\`, `dungeons\`, `environments\`, unclassified | 9,806 | 0.93 GB |
| `patch-7` | CHARACTER | `character\`, `textures\BakedNpcTextures\` | 41,646 | 1.40 GB |
| `patch-8` | WORLD 1/2 | `World\` — WMO, doodads, `expansionNN`, continents, environment | 38,394 | 1.42 GB |
| `patch-9` | WORLD 2/2 | (continues alphabetically from `world\lordaeron\lordaeron_stat01.blp`) | 11,752 | 1.36 GB |
| `patch-A` | PREVIEW | `mountpreview\`, `petpreview\` | 6,895 | 2.68 GB |
| `patch-B` | ITEMOBJ 1/3 | `Item\ObjectComponents\` | 49,777 | 2.76 GB |
| `patch-C` | ITEMOBJ 2/3 | (from `…\collections\collections_cloth_revendreth_d_01_hu_m00.skin`) | 73,410 | 2.90 GB |
| `patch-D` | ITEMOBJ 3/3 | (from `…\head\helm_cloth_nzothraid_d_01_go_m00.skin`) | 110,174 | 3.32 GB |
| `patch-E` | ITEMTEX | `Item\TextureComponents\` + other `Item\` / `items\` leftovers | 62,540 | 1.51 GB |
| ~~`patch-F`~~ | — | retired 2026-09-19, icons merged into `patch-5` — **delete it from client installs** | — | — |
| `patch-G` | CREATURE 1/2 | `creature\` | 13,891 | 2.51 GB |
| `patch-H` | CREATURE 2/2 | (from `creature\kalecgos2\kalecgos200.skin`) | 13,420 | 2.52 GB |
| | | **total** | **464,844** | **24.99 GB** |

Counts and sizes verified 2026-09-03 (patch-5 row 2026-09-19). `patch-D` at 3.32 GB is still the
closest to the 4 GB MPQ cap — watch it when adding item models.

**2026-09-19 changes:**
- **patch-F merged into patch-5.** `dest_for()` now sends `Interface\Icons\` to patch-5. patch-F
  loads *after* patch-5, so a stale patch-F left on a player's client would override the icons in
  patch-5. The client distribution has to delete `Data\patch-F.MPQ`.
- **All custom archives are now MPQ format 2** (44-byte header), like Blizzard's own. StormLib 9.x,
  and so Ladik's MPQ Editor, treats a format-1 archive whose tables sit past 2 GB as malformed and
  ignores its `(listfile)`, which is why patch-A/B/C/D/G/H showed `File0000xxxx` names.
  `retroport_tools/dc_mpq_to_v2.py` converts; the pack/rebuild tools now create format 2.

Every archive carries a `(listfile)`, so any MPQ reader shows real paths rather than
`File00xxxxx.xxx` placeholders.

## Rules that keep it this way

1. **One role, one contiguous letter run.** A role spans more than one letter only because of the
   4 GB MPQ v1 archive cap, never because of content. `patch-8`/`patch-9` are one WORLD set;
   `patch-B`/`C`/`D` are one ITEMOBJ set; `patch-G`/`H` are one CREATURE set.
2. **Multi-letter roles split alphabetically, at boundaries recorded in `SHARD_BOUNDS`.** That makes
   the destination a pure function of the path — a pipeline re-emitting an asset lands in the archive
   that already holds its neighbours, with no manifest lookup and no drift.
3. **No path exists twice in the custom layer.** Root load order is therefore irrelevant to
   correctness within the custom patches. (It still matters against the Blizzard base chain: every
   custom patch outranks every base archive.)
4. **Nothing byte-identical to Blizzard stock is shipped.** The base chain already supplies it.
5. **Never edit an archive in place.** `SFileRemoveFile` marks a file gone but does not reclaim its
   bytes — that is how the old `patch-4` came to occupy 5.03 GB while holding 2.49 GB of live files.
   Always rebuild the archive from a staging tree.

## The enGB chain — the root chain outranks it (corrected 2026-08-06)

`Data\enGB\locale-enGB.MPQ` + `patch-enGB`/`-2`/`-3` sit **below** the custom root patches. This file
previously claimed the opposite ("the enGB chain outranks all of this"), and that was wrong.

**The evidence.** 307 paths exist in both `patch-5.MPQ` and the enGB chain, 217 of them with different
content — so one side is dead. Two of those decide it:

* `Interface\GlueXML\CharacterSelect.lua` — patch-5 has 29,361 bytes carrying the expanded character
  list (`CharacterSelect_HasExpandedCharacterList`, `EnsurePaginationControls`, `GetMaxScrollOffset`,
  `ChangeScroll`). `patch-enGB-3`'s copy is 17,840 bytes and has none of them. The live client shows
  "Characters: 21/25" with a working scrollbar; stock WotLK caps at 10 and has no scroll.
* `Interface\GlueXML\GlueParent.xml` — only patch-5's copy calls `DCBreakingNews_OnUpdate`.

So `dest_for()` sending `Interface\` to `patch-5` is correct **even for locale-resident paths** such as
`Interface\GlueXML\` and `Interface\Glues\`. A custom root patch beats `locale-enGB.MPQ` and every
`patch-enGB-N`. Note the enGB chain still outranks the Blizzard *base* archives, which is why a file
placed only in `patch-enGB-3` (with no root copy) does take effect — that is what made the old rule
look true for so long.

Practical consequence: **put Interface overrides in `patch-5` only.** Copies in the enGB chain are at
best redundant and at worst stale shadows that quietly diverge — several of the 217 differing paths are
exactly that. The enGB chain was not touched by the 2026-08-04 rebuild.

## Tooling

All in `K:\Dark-Chaos\retroport_tools\`:

| Script | Purpose |
|---|---|
| `dc_mpq_layout.py` | **The layout itself.** `role_of(path)`, `dest_for(path)`, shard bounds, size caps. |
| `dc_mpq_inventory.py` | Path-level inventory of a set of archives (listfile + sizes). |
| `dc_mpq_analyze.py` | Duplicate / base-overlap / category report from an inventory. |
| `dc_mpq_base_identical.py` | MD5s custom files against the stock copy to find droppable redundancy. |
| `dc_mpq_plan_rebuild.py` | Emits `build_plan.csv` — every surviving file's source and destination. |
| `dc_mpq_rebuild.py` | Executes the plan: extract → pack → byte-verify, into a staging output dir. |
| `dc_mpq_verify_rebuild.py` | Proves the result complete, non-overlapping, and layout-conformant. |

Rebuild from scratch:

```sh
python dc_mpq_inventory.py       --data "<Data>" --out inv.csv --summary inv_sum.csv
python dc_mpq_analyze.py         --inv inv.csv --out-dir report/
python dc_mpq_base_identical.py  --overlap report/base_overlap.csv --data "<Data>" --out report/base_identical.csv
python dc_mpq_plan_rebuild.py    --inv inv.csv --identical report/base_identical.csv --out-dir plan/
python dc_mpq_rebuild.py         --plan plan/build_plan.csv --data "<Data>" --stage "<scratch>" --out-dir "<built>"
python dc_mpq_verify_rebuild.py  --plan plan/build_plan.csv --built "<built>" --data "<Data>"
```

`dc_mpq_rebuild.py` never writes into the live `Data\` directory — it reads the old archives and
writes new ones elsewhere, so deployment stays an explicit, reversible copy step.

## 2026-08-04 rebuild result

| | Before | After |
|---|---|---|
| Archives | 18 | 14 |
| File entries | 476,311 | 423,837 |
| On disk | 32.46 GB | 21.24 GB (**−11.22 GB, −35%**) |
| Shadowed duplicates | 24,611 files / 4.30 GB | **0** |
| Archives without a listfile | 0 | 0 |

Removed: 24,611 shadowed duplicate files (4.30 GB) whose copy the client never read, 27,863 files
byte-identical to Blizzard stock (0.93 GB), and the unreclaimed dead space left by in-place removes
(old `patch-4` alone held 2.49 GB of live files in a 5.03 GB archive). Four archives disappeared
entirely, their content absorbed into the role layout: `patch-I`, `patch-J`, `patch-secretpets`, and
the 0-file `patch-empty - Kopie`.

Also deleted `Data\backup\` and `Data\backup2\` — 59.3 GB of stale snapshots sitting inside the client
directory (inert; the client never scans `Data\` subdirectories).

Verified after publish: all 423,837 files present exactly once, correctly sized, each in the archive
`dest_for()` predicts, 600 randomly sampled files byte-identical to their pre-rebuild originals, and
every archive carrying a complete `(listfile)`.

Rollback point: `K:\WoW_3.3.5a_ 255 Fun - Kopie`. A second copy of the rebuilt set is in
`K:\tmp\dc_mpq_built` (21 GB) — deletable once the client has been confirmed in-game.

## 2026-09-03 audit

Full re-check of the custom chain (`patch-4` … `patch-H`) against this document.

**Listfiles.** All 14 custom archives (plus the three enGB patches) carry a complete internal
`(listfile)` — 464,844 named entries, **0 unknown**. No repair was needed; an MPQ editor shows real
paths for every file in every archive.

**Layout conformance.** 1,049 files had drifted into the wrong archive since the 2026-08-04 rebuild,
and 45 paths existed in two archives at once (44 byte-identical, 1 differing —
`world\skillactivated\containers\treasurechest01hd.m2`, where the higher-priority `patch-9` copy was
already the correct one). Drift by source:

| From | To | Files | What |
|---|---|---|---|
| `patch-4` | `patch-9` / `patch-8` | 804 | `world\` doodad textures written into CORE |
| `patch-4` | `patch-6` | 102 | `dungeons\textures\`, `xtextures\` |
| `patch-D` | `patch-B` / `patch-C` | 60 | `Item\ObjectComponents\cape\`, `…\collections\` — before the shard bound |
| `patch-D` | `patch-8` / `patch-9` / `patch-6` | 64 | `world\`, `spells\` swept in with an item batch |
| `patch-8` | `patch-9` / `patch-6` | 17 | across the WORLD shard bound |
| `patch-G` | `patch-8` | 1 | a `world\` doodad in CREATURE |

Repaired by extracting each file, re-deploying through `dc_mpq_deploy.py` (which routes on
`dest_for()`), then removing the old copy. Result: **0 misplaced, 0 duplicate paths.**

**Compaction.** The chain was already close to compact — replace-writes had stranded only 0.19 GB.
`patch-4` (−120 MB), `patch-6` (−5 MB), `patch-D` (−10 MB) and `enGB\patch-enGB-3` (−61 MB) were
compacted and verified in a fresh process (300 sampled SHA-1s each).

**Why the counts grew.** Everything above the 2026-08-04 numbers is real content added since:
`patch-7` +34,673 (character/HD model work), `patch-F` +7,300 (pet icon backfill), `patch-4` +3,296
(DBC and map work), `patch-A` +2,088 (mount/pet previews). `patch-D` is 11,931 *lower* — item object
components pruned. Role purity is exact: every archive now holds files of one role only.

**Left alone.** 15.86 GB of `*.pre-*.bak` rollback copies sit in `Data\` and `Data\enGB\`. They are
inert (the client only loads `patch-*.MPQ`), but they are stale snapshots, not part of the layout —
delete once the client has been confirmed in-game.
