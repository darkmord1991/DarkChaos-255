# DarkChaos Item Appearance Downport â€” Sizing & Capacity Plan

*Appearance-only downport (names + displayid, no stats/spells) of the retail armor+weapon catalog. Source: retail 11.1.7 / 12.0.5 DB2 â†’ 3.3.5a stock DBC + WraithEngine. All counts below are tagged **[measured]** (decoded from DB2 / read from compiled DBC headers) or **[estimate]** (scaled / projected).*

---

## 1. Headline counts

| Table | 11.1.7 ground truth | 12.0.5 measured | Î” | Notes |
|---|---:|---:|---:|---|
| Item | ~193,395Â¹ | 209,928 | +8.5% | Â¹enUS baseline. Local deDE dump's 52,090 is a partial-locale artifact â€” **ignore it**. |
| ItemSparse | 158,487 | 172,014 | +8.5% | Local deDE 158,492 reliable (matches). True record count (raw CSV lines inflated ~111 by embedded newlines). |
| **ItemAppearance** | **57,450** | **63,150** | **+9.9%** | **Unique visuals â€” this is the table that sizes the displayid band.** maxID climbs 117,369 â†’ 130,443. |
| ItemModifiedAppearance | 140,365 | 156,749 | +11.7% | itemâ†’appearance link rows. NOT the appearance count. |
| ItemDisplayInfo | ~153,770Â¹ | 173,098 | +12.6% | Â¹enUS baseline. Local deDE 63,130 is a partial artifact â€” ignore. |

**The one number that matters:** retail has **~63,150 unique item appearances** at 12.0.5 (effectively current â€” 12.0.7 adds only +204). That is the theoretical ceiling of displayids to mint. The *realistic* downport target is far lower (see Â§2).

---

## 2. What we are NOT downporting

The catalog collapses in three stages:

- **209,928 Item ids / 172,014 ItemSparse rows** â†’ most are stat/quest/server/deprecated duplicates of the same visual. We key off **appearances**, not items, so this whole layer collapses away.
- **63,150 ItemAppearance rows** â†’ but only **49,465 are actually referenced** [measured] by any ItemModifiedAppearance link at 11.1.7 (scaling +9.9% â†’ ~54k referenced at 12.0.5). The unreferenced ~8,234 are internal/unused visuals that **will not downport**.
- **Equippable armor + weapon only** â†’ neck/finger/trinket/bag/ammo/quiver (inv 2/11/12/18/24/27) are not appearance slots and are excluded.

**Realistic Track totals** (11.1.7 matched ground truth, with full-catalog scaled estimate):

| Track | Matched [measured] | Full-catalog [estimate] |
|---|---:|---:|
| **Track A** (model / Wraith) | 8,069 | ~24,750 |
| **Track B** (texture / stock composite) | 7,975 | ~24,460 |
| N/A (excluded) | 82 | ~252 |
| **Equippable A+B** | **16,044** | **~49,465** |

The split is **near 50/50**. The design doc's "~100k unique equippable appearances" figure conflated the 140k IMA *link* rows â€” **revise it down to ~49.5k** (or ~54k scaled to 12.0.5). Each track must produce roughly **24â€“25k displayids** at full catalog.

---

## 3. Per-slot planning grid

Counts are **11.1.7 matched [measured]** / **scaled full-catalog [estimate]**. "Cols populated" = which `ItemDisplayInfo.dbc` fields the row writes.

| InvType | Label | Track | Matched | Scaled | ItemDisplayInfo cols populated |
|---:|---|:--:|---:|---:|---|
| 1 | Head | A | 1,085 | ~3,328 | ModelName[0], ModelTexture[0], InventoryIcon |
| 3 | Shoulder | A | 897 | ~2,751 | ModelName[0,1] (L+R), ModelTexture, Icon |
| 13 | Weapon 1H | A | 2,134 | ~6,546 | ModelName[0], ModelTexture, Icon **(largest slot â€” ship first)** |
| 14 | Shield | A (armor class) | 470 | ~1,442 | ModelName[0], ModelTexture, Icon |
| 15 | Ranged (bow/gun) | A | 253 | ~776 | ModelName[0], ModelTexture, Icon |
| 17 | 2H Weapon | A | 1,683 | ~5,162 | ModelName[0], ModelTexture, Icon |
| 21 | Weapon Main-hand | A | 379 | ~1,163 | ModelName[0], ModelTexture, Icon |
| 22 | Weapon Off-hand | A | 165 | ~506 | ModelName[0], ModelTexture, Icon |
| 23 | Holdable (off-hand) | A | 422 | ~1,294 | ModelName[0], ModelTexture, Icon |
| 25 | Thrown | A | 54 | ~166 | ModelName[0], ModelTexture, Icon |
| 26 | Ranged-right (wand) | A | 527 | ~1,617 | ModelName[0], ModelTexture, Icon |
| 28 | Relic | A | 0 | ~0 | (none in dump â€” skip unless any appear) |
| 4 | Shirt/Body | B | 131 | ~402 | Texture[0..7] (composite), Icon |
| 5 | Chest | B | 1,056 | ~3,239 | Texture[0..7], Icon |
| 6 | Waist | B | 986 | ~3,024 | Texture[0..7], Icon |
| 7 | Legs | B | 1,071 | ~3,285 | Texture[0..7], Icon |
| 8 | Feet | B | 1,070 | ~3,282 | Texture[0..7], Icon |
| 9 | Wrist | B | 951 | ~2,917 | Texture[0..7], Icon |
| 10 | Hands | B | 1,602 | ~4,914 | Texture[0..7], Icon (highest-variance; scale may overstate) |
| 16 | Cloak | B (degenerate) | 533 | ~1,635 | Icon only â€” cape geoset/region, no Texture[8], no model |
| 19 | Tabard | B | 99 | ~304 | Texture[0..7], Icon |
| 20 | Robe (long chest) | B | 476 | ~1,460 | Texture[0..7], Icon |
| 2/11/12/18/24/27 | Neck/Finger/Trinket/Bag/Ammo/Quiver | **skip** | 82 | ~252 | â€” not appearance slots |

**Track A rows** set `ModelName` (the M2 path Wraith renders) + `ModelTexture` + icon. **Track B rows** leave ModelName empty and fill the 8-element `Texture[]` array with component-region BLP names composited by the stock client.

---

## 4. ID band sizing

Pick **N = 65,000** (round-up of the 63,150 unique 12.0.5 appearances, with headroom; the design's full-catalog ceiling). If you allocate by **mirroring source appearance IDs** rather than densely packing, size to **maxID 130,443 â†’ plan to 131,000**, but dense-pack is strongly recommended to keep the client idâ†’record index small.

| Artifact | Band | Notes |
|---|---|---|
| ItemDisplayInfo id | **6,000,000 .. 6,065,000** | Disjoint from stock (â‰¤70,001) and the 500xxx creature display sequence. |
| item_template entry | **1,000,000 .. 1,065,000** | Above the live MAX (~900,123). One shell item per minted appearance. |

If you only downport the **realistic equippable referenced** set (~49.5k @ 11.1.7, ~54k @ 12.0.5), N â‰ˆ **55,000** is enough; the 65k band still holds with room. **Keep allocation contiguous** â€” sparse high ids inflate the client's idâ†’record map and are the real hazard, not row count.

---

## 5. CSV file plan

Both `Custom/CSV DBC/Item.csv` and `Custom/CSV DBC/ItemDisplayInfo.csv` are **single flat appended files** (one header + quoted-int rows). They already round-trip to the compiled DBCs (Item.csv 46,887 data rows = DBC 46,888; ItemDisplayInfo.csv 57,998 = DBC 57,998) [measured].

**Recommendation: KEEP single files, do NOT shard.** Sharding breaks the tool's full-file round-trip.

- **Append only** the 6,000,000+ / 1,000,000+ rows. **Never rewrite** the stock 57,998 / 46,887 rows.
- **Item.csv** columns: `ID,ClassID,SubclassID,Sound_Override_Subclassid,Material,DisplayInfoID,InventoryType,SheatheType`.
- **ItemDisplayInfo.csv**: stock 25-field layout ending `...ItemVisual,ParticleColorID`.
- **Comma gotcha** is low-risk here (both tables are all-integer, no floats, every field already quoted) â€” but **enforce period-normalization and never emit a bare decimal comma** regardless of locale.
- **Idempotency:** maintain a deterministic ledger table (`dc_item_downport_map`) so re-runs don't duplicate. Add a **pre/post row-count assert** (stock 57,998 ItemDisplayInfo / 46,887 Item preserved) before each bulk batch â€” the CSVâ†’DBC tool's own append behavior is still PoC-unverified.

---

## 6. SQL file plan

~58k (use N) item_template appearance-shell INSERTs into `data/sql/updates/pending_db_world/`.

- **~2,000 rows per file â†’ ~30 files** (65,000 / 2,000 â‰ˆ 33; round to ~30â€“33). Each `rev_<ts>.sql` from `create_sql.sh`.
- **Pattern per file** (codestyle-enforced): one `DELETE FROM item_template WHERE entry BETWEEN <lo> AND <hi>` for that file's own 2k band, followed by the multi-row `INSERT`. InnoDB, 4-space indent, trailing newline, no double semicolons.
- Each file stays <~1 MB and each transaction stays bounded â€” file count is driven by **reviewability/transaction size, not DB limits** (58k rows is trivial for MySQL).
- Mirror the same DELETE-before-INSERT pattern for the `item_dbc` / `itemdisplayinfo_dbc` overlay-table upserts **if** the server uses the MySQL overlay channel â€” and reconcile the existing live `item_dbc` row 70001 before bulk insert.

---

## 7. MPQ / asset-volume plan

The **assets are the real driver**, not the DBCs (a ~120k-row, ~18 MB ItemDisplayInfo.dbc is trivial for the client).

**v1 volume estimate (single canonical race/gender = Human male)** [estimate, typical 3.3.5 sizes â€” re-measure against the WowExport "item" folder once populated]:

| Track | Per-appearance | Count | Subtotal |
|---|---|---:|---:|
| A (model) | ~0.3â€“0.6 MB (M2 30â€“150KB + skin(s) + model BLP(s) + icon) | ~20k | ~6â€“12 GB |
| B (texture) | ~0.1â€“0.4 MB (up to 8 region BLPs + icon) | ~38k | ~4â€“15 GB |
| Icons | ~5.5 KB (64Ã—64 DXT5), heavy dedup | ~58k | ~0.3 GB |
| **Total v1** | | | **~10â€“25 GB** |

Per-race/gender fan-out for Track B would multiply by up to ~20Ã— â€” **explicitly deferred**.

**MPQ constraints:** v1 MPQ (the format 3.3.5 uses) hard-caps each archive at **4 GB** (32-bit offsets). The catalog **cannot fit** the existing two-patch convention (Patch-A AllRaces + Patch-4 DC content) â€” **do NOT cram into patch-4.** Split across **~4â€“8 new patch archives**, each <4 GB, shipped in demand-driven waves:

- **patch-5** â†’ Track A models (weapons/shields **first** â€” highest yield, cleanest attach)
- **patch-6 / patch-7** â†’ Track B component BLPs
- **patch-8** â†’ icons

Size each archive's hash table for its file count.

---

## 8. Bottom line

**Yes â€” tractable.** ~58â€“65k appearances is well within proven scale: the DBCs grow to ~120k rows / ~18 MB (trivial; ~12 MB resident RAM), and the SQL/CSV are routine. The only real constraints are (a) **contiguous ID packing** to keep the client idâ†’record index small, and (b) **asset volume â†’ multiple <4 GB MPQ archives** in waves.

**Recommended first concrete batch:** **inv13 Weapon 1H â€” 2,134 appearances [measured]** (largest single slot, Track A, cleanest attach + sheath). Ship it as **one wave**: ~2,134 displayids in band 6,000,000+, ~2,134 item_template shells across **2 SQL files** (2k + 134), one `patch-5.mpq` of models/icons. Validate the full Wraith render + attach + sheath path end-to-end on this slot before scaling to inv17 (2H) and the rest of Track A, then Track B.
