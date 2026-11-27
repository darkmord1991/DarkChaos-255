# Collection preview: models rendering flat green

## Symptom

A mount or pet in the DC Collection preview renders as **solid flat green** (see the
Black Falcosaur Mount, display 500216). The silhouette is correct — only the surface is
wrong.

## Root cause

**Flat green is this client's "geometry loaded, texture did not" state.** It is the same
failure that turned map 861's terrain neon green, where the cause was missing `_s.blp`
tileset companions: when a texture reference resolves to nothing, the layer rasterises as
lit flat green rather than showing an error texture.

Every DC preview model is a **per-display baked M2** (`falcosaurosmount_500216.m2`) whose
textures are baked in as **type-0 hardcoded filenames** rather than being supplied at
runtime from `CreatureDisplayInfo.TextureVariation_*`. Display 500216's model asks for:

```
tex[0] type=0  creature/falcosauros/falcosaurosmount_black.blp
tex[1] type=0  creature\falcosauros\orbreflectbright.blp
tex[2] type=0  creature/falcosauros/falcosaurosmountsaddle_black.blp
```

None of the three ship in any client archive, so all three sample as nothing → flat green.

> Mixed `/` and `\` separators in those baked paths are **not** the bug. MPQ name hashing
> upper-cases and converts `/` to `\`, so both resolve identically. 11,445 of the baked
> refs use forward slashes and the overwhelming majority load fine.

## Scope (audited, not assumed)

Parsed the type-0 texture table of **all 2,153** preview M2s under
`retroport_tools/patch_g_staging/{mountpreview,petpreview}` and resolved every reference
against the full client archive chain in `K:\WoW_3.3.5a_ 255 Fun\Data`:

| | |
|---|---|
| preview M2s parsed | 2,153 (0 unparseable) |
| unique type-0 texture refs | 7,517 |
| refs **missing** from every archive | **35** |
| preview models affected | **29** of 2,153 (~1.3%) |

So this is a narrow asset gap, not a systemic pipeline failure.

### Affected models

| Family | Preview models | Missing textures |
|---|---|---|
| `falcosauros` (mounts) | 500216, 500217, 500218, 500219 | 9 |
| `bloodknightcharger` | 501857, 501858, 501859 | 4 |
| `treasuregoblinpet` | 503312 | 4 |
| `bloodgolem` | 503108 | 3 |
| `shahauntpride` | 503372 | 3 |
| `alliancelionmount` | 502406 | 2 |
| `babyarathilynx` | 502230–502234 | 1 |
| `babyhorse2`, `babynaga2`, `baneling`, `cranegodpet`, `jeweledgnome`, `mantid`, `shahaunt`, `shredder`, `stbernarddogpet` | 12 models | 1 each |

## ✅✅ RESOLVED — 35 of 35 packed, falcosaur model shipped (2026-07-27)

Retail client at `K:\UntouchedClients\World of Warcraft 12.07` (12.0.7.68887) supplied the 15 textures that had no
local source, plus the falcosaur mount model itself.

**Final audit: 0 of 7,517 preview texture refs missing.** All 29 affected models render.

Extracted with `tools/casc-extract.js` and packed into **`patch-G.MPQ`**:

| Batch | Files | Notes |
|---|---|---|
| 20 locally-sourced textures | 20 | first pass, see below |
| 15 retail textures | 15 | all DXT1/DXT5, ≤512×512, mipmapped — **3.3.5-native, no conversion needed** |
| `creature\falcosauros\` model folder | 42 | mount + pet M2s, skins, anims, all colour textures |

All verified byte-identical after write, all verified absent from the stock archives first,
and all mirrored into `retroport_tools/patch_g_staging`.

### Two things that would have gone wrong silently

* **Retail stores `babyhorse2_bastion_blue .blp` with a trailing space** before the
  extension, while the M2 references it without. Extracted under the retail name, packed
  under the name the model actually asks for.
* **The falcosaur mount ships as raw MD21 on purpose.** Retail's model uses texture types
  **11/12** (monster skin 1/2), so `CreatureDisplayInfo.TextureVariation_1/_2` supply the
  colour and one model serves all four variants. Do **not** substitute a preview M2 for the
  in-world model: previews bake the colour in as type-0, which is exactly why there are four
  of them (500216-500219) — using one in-world would make every colour render black.
  Shipping raw MD21 is the established pattern here (`downport-creature.js`: *"Models are
  shipped as-is (MD21) and rendered by WarcraftXL / Wraith"*), and is safe because
  `creature\falcosauros\` does not exist in any stock archive. The packer's guard correctly
  rejected the 8 Legion+ `_lod*.skin` files, which 3.3.5 cannot read; they were dropped.

---

## Status of the first pass — 20 of 35 packed

The 20 sourceable textures were extracted, validated and written into **`patch-G.MPQ`**
(where the preview models themselves already live), 20/20 byte-verified against source, and
mirrored into `retroport_tools/patch_g_staging` so the archive stays reproducible. A
`patch-G.MPQ.pre-mpq-patch.bak` was taken automatically.

Re-audit after packing: **35 → 15 missing.**

| Preview models | Result |
|---|---|
| **20 fully fixed** | Blood Knight Charger ×3, Baby Arathi Lynx ×5, Baby Naga ×3, Baneling, Blood Golem, Crane God, Mantid, Sha Haunt ×2, Shredder, St. Bernard, Treasure Goblin |
| **5 partial** | Falcosaur ×4 and Sha Haunt (Pride) — 1 of 3 textures resolved, still green |
| **4 unchanged** | Alliance Lion Mount, Baby Horse ×2, Jeweled Gnome |

All 20 were verified **absent from every stock archive** (`common`, `common-2`, `expansion`,
`lichking`, `patch`, `patch-2/3`, `enGB/patch-enGB-3`) before writing, so nothing shadows a
stock asset — the failure mode that previously broke 175 files. All are valid BLP2, DXT1 or
DXT5, with mipmaps.

> Textures need only the one archive. The "write into **both** patch-4 and
> `enGB/patch-enGB-3`" rule applies to **DBCs and locale files**, not art.

### Source availability

Of the 35 missing textures, **20 have a source file elsewhere on disk** and were packed;
**15 have no source anywhere**, including all 8 falcosaur mount textures:

```
creature\falcosauros\falcosaurosmount_{black,green,red,white}.blp
creature\falcosauros\falcosaurosmountsaddle_{black,green,red,white}.blp
creature\alliancelionmount\alliancelion.blp
creature\alliancelionmount\alliancelionarmor.blp
creature\babyhorse2\babyhorse2_bastion_{blue,yellow}.blp
creature\clockworkgnome\jeweledgnome.blp
creature\shaboss_pride\shahauntflakes01_blue.blp
creature\shaboss_pride\shahauntsplatter01_pride.blp
```

`creature\falcosauros\orbreflectbright.blp` **is** sourceable — the identical file ships
under other creature folders (e.g. `MPQ ascension april 26\Creature\LavaHorse\`).

## 🔴 The falcosaur mounts are worse than green — they have no in-world model at all

`CreatureModelData` 500207 points at `Creature\falcosauros\falcosaurosmount.m2`, and
**nothing under `creature\falcosauros\` ships**: no `.m2`, no `.skin`, no `.blp`. Only the
`mountpreview\falcosauros\*.m2` preview geometry was ever packed (patch-6 and patch-G).

So fixing the textures fixes the *preview* only. Summoning the mount in the world would
still fail to find a model. The falcosaur family needs a full asset ship — model, skins and
textures — not just a texture top-up.

The only falcosaur art present locally is the **pet** set
(`WoW Boost MPQ extract\Creature\Falcosauros\`: `Falcosauros.m2`, `Falcosauros_Black.blp`,
`OrbReflectBright.blp`). That is a different model from the mount and does not carry the
saddle texture.

## Reproducing the audit

```
python <scratch>/audit_preview_textures.py      # parse every preview M2's type-0 refs
python tools/mpq_stormlib_locate.py --dir "K:\WoW_3.3.5a_ 255 Fun\Data" \
       --list-file K:\tmp\preview_tex_all.txt    # resolve them against the client chain
```

Gotchas that cost time here:

* `mpq_stormlib_locate.py --dir` globs **`patch-*.MPQ` only** — it does not scan
  `common.MPQ` / `expansion.MPQ` / `lichking.MPQ` or the `enGB` subfolder. Pass those with
  repeated `--mpq` if a stock asset is in question.
* Build listfiles with Python, not `printf` — `printf` interprets `\f` in
  `creature\falcosauros\...` as a formfeed and silently produces garbage paths that all
  report NOT FOUND.
* Matching source files by **basename** collides: `armorreflect4.blp` is referenced from two
  different creature folders, so a naive basename map under-reports sourceable files by one.
