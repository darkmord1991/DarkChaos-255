# Retail Item Downport — Pipeline & Operations (v2, 2026-07-03)

**Status:** OPERATIONAL. The catalog is deployed (~104k appearance-shell items, Blizzlike ids). This doc
describes the implemented pipeline, the standard runbooks, and the failure classes we actually hit — it
supersedes the June 2026 design draft (v1) that planned a Python toolchain and a 6M+ custom id band;
neither shipped. History of the v1 design (two-track analysis, adversarial verification) is in git.

---

## 1. What is deployed

- **~104k appearance-only items** (names + appearances, no stats) covering the retail (12.0.5) class-2/4
  equippable catalog, **Blizzlike ids**: `item_template.entry` = retail `Item.ID`,
  `displayid` = retail `ItemDisplayInfo.ID`. Stock/custom rows are never touched (skip-existing).
- **Track A** (weapons/shields/head/shoulder/ranged/…): standalone `.m2` bone-attached via
  `ItemDisplayInfo.ModelName`. **Track B** (chest/legs/hands/…): body-composited `Texture_1..8` region BLPs.
  **Track C** (neck/ring/trinket): icon-only rows.
- **Client**: patch-B..E.MPQ (assets), patch-4.MPQ (`DBFilesClient\Item.dbc` + `ItemDisplayInfo.dbc`).
- **Server**: `Server/data/dbc/Item.dbc` (CSV catalog **merged with the 231,417 ItemUpgrade clone
  records**, entries 2,000,000–2,578,764 — never deploy a plain CSV compile to the server or the upgrade
  system breaks) + `ItemDisplayInfo.dbc`; `acore_world.item_template`; overlay tables
  `item_dbc`/`itemdisplayinfo_dbc` (rows there OVERRIDE the file at startup — keep them in sync or empty).
- **Source of truth**: `Custom/CSV DBC/Item.csv` (151,060 rows) + `ItemDisplayInfo.csv` (94,254 rows).
  Everything else (binary DBCs, SQL, wardrobe CDBC) is generated from these.

## 2. Toolchain (all under `K:\Dark-Chaos\wow.export-main\tools\`)

| Tool | Role |
|---|---|
| `downport-item.js` | The orchestrator: DB2 decode → appearance resolve → icon/asset extract → **wxl-bake** → CSV/SQL generate → patch-tree package. Modes: `--after-wotlk --new-only --merge-csv --convert` (incremental update), `--icons-from-dbc` (icon backfill), `--fix-names` (de-space), `--fix-disp0` (mint icon-only displays), `--bake <dir>` (bake staged trees in place). |
| `dbc-compile.py` | Compiles `Item.csv`/`ItemDisplayInfo.csv` → binary WDBC. **`--verify` diffs a .dbc against its CSV** — run it after every compile AND against deployed files when hunting drift. Replaces the external German-locale CSV→DBC tool for these two tables. |
| `audit-items.py` | QA gate: cross-checks every ModelName / ModelTexture / Texture_1..8 / InventoryIcon in the live CSV against a full client MPQ listing (`mpq-extract.js list`), honouring helm race/gender and `_u/_m/_f` suffix rules; also finds `DisplayInfoID=0` items. Run before and after every deploy. |
| `package-items.js` | Staging clean-up + fold planning (junk-strip, icon fold, per-patch manifests). |
| `mpq_stormlib_pack.py` | **The MPQ builder** (2026-07-03): staging dir → fresh V1 archive via StormLib, zlib-compressed, sample byte-verified, atomic rename. Use this — NOT MPQEditor `/console new`+wildcard-`add`, which silently corrupts archives (see §5.6). MPQEditor console remains fine for single-file `delete`+`add`+`flush` (how patch-4's DBCs are replaced). |
| `casc-extract.js` / `db2-decode.js` / `blp-downscale.js` / `mpq_stormlib_extract.py` | CASC asset pull, modern DB2 → CSV, BLP clamp (mip promotion), exact-name MPQ probe/extract. |
| **wxl-baker + wxl-skinfix** (`K:\Dark-Chaos\dc-wotlkextensions\build\{downport,wraith32}\Release\`) | The WarcraftXL offline M2 tooling: de-chunk MD21→MD20 and **re-inline TXID texture FileDataIDs as path strings** (byte-identical code to the live engine's `wxl-modern-m2`), then rebuild the skin contract. **This replaced M2Mod.exe `--txid-remove` entirely.** |

The old Python generators (`retroport_tools/dc_item_enum.py`, `dc_item_gen_batch.py`) are superseded;
keep them only as reference.

## 3. Bake policy — models ship SELF-CONTAINED (the 2026-07-03 change)

Item M2s used to ship as raw chunked **MD21** and relied on the WarcraftXL runtime to de-chunk and
resolve TXID texture FileDataIDs via mounted `TextureFilePath.db2`/`ModelFilePath.db2`. Any gap in that
runtime chain (resolver miss, stale db2 mount, alias not yet implemented) rendered **green (untextured)
or invisible items**, and it made every failure a live-client debugging session.

Since 2026-07-03 every item model in patch-B..E (61,135 M2s) is **baked offline**: wxl-baker de-chunks to
MD20 and inlines the texture paths, wxl-skinfix rebuilds skins (boneCount==0 ERROR#132 guard). The WXL
runtime still translates modern geometry at load, but **texture resolution no longer depends on runtime
FDID lookups**, and bake logs (`_bake_log.txt`, `wxl-baker: N downported, X missing`) surface unresolved
textures at build time. **Never ship an unbaked MD21 item model again** — `--convert` is part of the
standard run, and `--bake <staging-dir>` retrofits any tree (idempotent: MD20 files are skipped).

## 4. Runbooks

### 4.1 Incremental catalog update (new retail build)
```
# 0. refresh DB2 CSV extracts (wago.tools or db2-decode vs an unencrypted build) into K:/Dark-Chaos/retailextracts
# 1. add new post-WotLK items + assets + icons, bake models, merge rows into the live CSVs:
node tools/downport-item.js --classes 2,4 --dbc-src K:/Dark-Chaos/retailextracts --after-wotlk --new-only --merge-csv --convert --label upd_<date> --out K:/Dark-Chaos/retailextracts/_items_upd_<date>
# 2. compile + verify the DBCs:
python tools/dbc-compile.py && python tools/dbc-compile.py --verify
# 3. client: fold <out>/item + interface/icons into patch-E staging, then rebuild the touched patches:
#      python tools/mpq_stormlib_pack.py --dir <staging>/patch-E --mpq "<Data>/patch-E.MPQ"   (repeat per patch)
#    replace the two DBCs in patch-4 via MPQEditor /console: delete -> add -> flush
#    (add alone does NOT replace reliably — DELETE FIRST, then verify with mpq_stormlib_extract.py)
# 4. server: python merge_server_item_dbc.py-style merge (CSV compile + preserved 2.0M–2.58M upgrade clones)
#    -> Server/data/dbc/Item.dbc; copy ItemDisplayInfo.dbc verbatim
# 5. apply sql/item_template_upd_<date>.sql + sql/dbc_overlay_upd_<date>.sql to acore_world (HeidiSQL; acmcp is read-only)
# 6. regen wardrobe catalog: tools/generate_dc_collection_cdbc.py (repo) after refreshing the item_template dump
# 7. QA: python tools/audit-items.py  (fresh mpq-extract listing first)
```

### 4.2 Fix modes (idempotent, run any time)
- Question-mark icons on an already-deployed catalog: `node tools/downport-item.js --icons-from-dbc --skip-client "K:/WoW_3.3.5a_ 255 Fun/Data"` then pack the icons.
- Items with `DisplayInfoID=0` (icon-less Track C): `--fix-disp0` (needs `--dbc-src`); mints displayid `8,000,000 + IconFileDataID` (band is disjoint from stock ≤70k and retail ≤~800k, deterministic across runs), rewrites the live CSVs, extracts icons, emits UPDATE SQL.
- Space-mangled texture names (green items): `--fix-names` (add `--dry-run` first).
- Unbaked models anywhere: `--bake <dir>`; verify `_bake_failed.txt` is absent and the log ends `0 missing`.

## 5. Failure classes — root causes actually found (2026-07-03 postmortem)

1. **Wrong/missing models & icons on ~ALL downported items (client)** — the deployed
   `patch-4` `Item.dbc` was **row-shifted vs its own CSV** (old external-tool compile; 583k field diffs
   from entry ~45479 up), so the client read the wrong `DisplayInfoID` for nearly every downported item.
   ⇒ Detection now exists: `dbc-compile.py --verify` against the deployed file. Compile drift = the first
   thing to check when "everything is broken at once".
2. **Items never loading (server)** — the server `Item.dbc` predated the downport (46k stock + 231k
   upgrade clones, only 65 retail-band rows) and the `item_dbc` overlay held just 11,860 of ~94k needed
   rows ⇒ `sItemStore` rejected/degraded the rest. Server deploy is a **merge**, not a copy (see §4.1
   step 4), and the overlay tables must stay consistent (they override the file).
3. **Question-mark icons** — two causes: (a) icon BLPs were named in the DBC but never extracted
   (fixed June 22 via `--icons-from-dbc`); (b) 7,939 Track-C items shipped `DisplayInfoID=0` because
   their retail appearance chain resolves to nothing (fixed via `--fix-disp0` minting, 2,220 icon-only
   displays + icons; SQL: `worlddb/dc_item_downport_2026_07_03_fixes.sql`).
4. **Green (untextured) items** — (a) raw MD21 + runtime TXID resolution gaps (fixed by the §3 bake
   policy); (b) 144 rows with space-mangled texture names from an early generator bug (`--fix-names`);
   (c) oversize/`has_mips=2` BLPs render solid green on 3.3.5 (mostly terrain; item BLP census was clean —
   only 3 bad flags — but `blp-downscale.js` exists if it recurs).
5. **Stock-name references that don't exist in retail** — 636 "still missing" Track-B textures turned out
   to reference old-era component names deleted from modern CASC; they exist in the stock 3.3.5 MPQs and
   were false positives of a staging-only check. Trust `audit-items.py` (checks the full client) instead.
6. **MPQEditor `/console` bulk rebuild corrupts archives** — `new <mpq> 262144 v2` fails to parse
   ("Too many parameters"), the following wildcard `add` then mangles the EXISTING archive: it can
   "finish" in seconds and leave a shell with a handful of orphan `File000xxx.xxx` entries. This
   destroyed patch-B..E on 2026-07-03 (rebuilt losslessly from staging). Bulk packing goes through
   `mpq_stormlib_pack.py` only; always probe a known file with `mpq_stormlib_extract.py` after ANY
   archive write.
7. **Blue ErrorCube on the head of every Vulpera / Kul Tiran / Zandalari (2026-09-07)** — the client
   composes a helm model as `<ModelName>_<ChrRaces.ClientPrefix><M|F>.m2` (WotLK spelling, e.g.
   `Helm_Plate_D_04_VuM`). Retail names the same variant `helm_plate_d_04_vu_m` (BfA+ spelling) and the
   downport keeps retail paths, so 1,125 Vulpera / 1,132 Kul Tiran / 1,151 Zandalari variants sat in
   patch-C/D unreachable by the stock loader; Pandaren worked only because MoP-era files use the old
   spelling. The Wraith host has a `_vum` -> `_vu_m` alias but it did not rescue the character
   compositor's load in practice, so native names are the rule. Fixed by deploying compact-spelled
   copies (11,302 files, `dc_mpq_deploy.py`); the pipeline now normalizes on the way in
   (`normalizeHelmRaceVariants` / `--fix-helm-suffixes`) and `audit-items.py` reports per-race gaps.
   Stock races are NOT exposed the same way: 0 bare-stem head displays depend on the retail spelling
   (5,029 have compact variants). The 392 stems that exist only as `_hu_m`/`_be_f`/... are unreferenced
   per-race variants of single-variant displays — dead weight (18,119 files, 1.27 GB), not a defect.
   What every race DOES depend on is the host's strip alias for the 2,823 head displays whose ModelName
   already carries a suffix (`helm_x_be_m.mdx`): the client composes `helm_x_be_m_HuM`, misses, and only
   the WXL host can land it on `helm_x_be_m.m2` (2,823 in `Head\`, the remaining 298 live in other
   ObjectComponents folders). Spot-check one of those in-game on a stock race.
8. **Blue ErrorCube on the head of every Zandalari FEMALE (2026-09-08)** — a *different* cause from
   §5.7, and the compact-spelling fix could not have covered it: the art does not exist under either
   spelling. Retail `ChrRaces` carries `{Male,Female}ModelFallbackRaceID`/`Sex`, and **Zandalari Troll
   (race 31) has `FemaleModelFallbackRaceID = 8` (Troll), `FemaleModelFallbackSex = 1`** — so Blizzard
   never authored per-stem Zandalari-female helm meshes (110 in the whole retail listfile vs 1,175
   `_za_m`) and the retail client silently renders the **Troll female** mesh instead. The 3.3.5 client
   has no fallback of any kind: it composes `<stem>_ZaF.m2`, misses, and draws `Spells\ErrorCube.m2`.
   Every one of the 283 bare-stem head displays cubed on a Zandalari female; nothing was wrong with the
   item, the DBC or the host. Fixed by copying the `_TrF` model + `NN.skin` family under `_ZaF` names for
   the 794 head stems that had a Troll-female variant and no Zandalari-female one (1,659 files, 33.2 MB,
   `dc_mpq_deploy.py` -> patch-C 139 / patch-D 1,520; backups `patch-{C,D}.MPQ.pre-zafhelm.bak`).
   `audit-items.py` now prints the fillable count per model fallback, so a race whose "no variant at all"
   number is an outlier can no longer be mistaken for the harmless dead weight described above.
   **Generalise: before writing off a "no variant at all" count, check retail's model-fallback fields.**
   Zandalari female is the only playable race here with a fallback (Pandaren 25/26 -> 24 shares the `Pa`
   prefix, so it is a no-op); Kul Tiran and Vulpera have none, which is why they ship full art.

## 6. QA gates (run all before calling a deploy done)

1. `python tools/dbc-compile.py --verify` — CSV ⇄ binary 0-diff (also probe the *deployed* patch-4 copy
   with `mpq_stormlib_extract.py` and hash-compare).
2. `node tools/mpq-extract.js list --data <client Data> > listing.txt` + `python tools/audit-items.py` —
   missing-asset counts for downported rows should be ~0 (stock-band noise is expected).
3. Bake logs: every `_bake_log.txt` ends `... 0 missing`; no `_bake_failed.txt`.
4. MPQ sizes < 4.0 GB each (v1 client cap; `flush` compacts — verify after flush).
5. In-game spot check: one weapon (attached, textured), one armor piece (body regions), one ring
   (icon), one wardrobe browse; check `Errors\` and `DLL_Logs\` for M2/texture load errors.
6. `audit-items.py` "helm race/gender variants" block: `underscore-only` must be 0 for every playable
   prefix (Hu Or Dw Ni Sc Ta Gn Tr Go Be Dr Wo Pa Vu Za Kt) — a non-zero count is a guaranteed ErrorCube
   for that race on that helm. `no variant at all` must be **flat across all 32 prefix/sex pairs** (~24-27
   stems, the handful of helms nobody has art for): an outlier is a race-wide ErrorCube, not dead weight
   — `zaf` read 283 while every other pair read 24-27 until 2026-09-08 (§5.8). The block's follow-up line
   names any pair that could be filled from its retail model fallback; it must print nothing.

## 7. Open items / future work

- **12.0.7 delta**: local extracts are 12.0.5 (live client DB2s are TACT-encrypted; keys lag). Refresh
  from wago.tools when available and run §4.1 — expected yield a few hundred new appearances.
- 87 Track-A models + 68 model textures referenced by stock-band rows don't resolve in either client or
  retail listfile (43 recovered 2026-07-03 into patch-E); the rest are pre-existing stock oddities.
- The wardrobe exposure policy (`DCCollection.Transmog.SkipUnlockCheck` vs bulk-seed
  `dc_transmog_collection`) is still a policy decision, not a pipeline task.
- `item_template.sql` (the 41 MB HeidiSQL dump the CDBC generator parses) drifts from the DB after SQL
  fix passes — re-dump before regenerating `DCCollectionTransmog`.
- Helm/shoulder on-body geoset fidelity (`GeosetGroup`/`HelmetGeosetVis` still 0) and per-race Track-B
  texture fan-out remain v1 accepted losses.
- **Suffixed-ModelName head displays rely on the WXL host strip alias** (2,823 rows, `helm_x_be_m.mdx`
  style, see §5.7) — no native fallback exists for any race. If an in-game spot check cubes, the fix is a
  CSV rewrite to the bare stem plus compact-spelled per-race copies (the variants already ship, 1.27 GB
  of them, but patch-D is at 3.48 GB: rename in place or repack, do not append).
