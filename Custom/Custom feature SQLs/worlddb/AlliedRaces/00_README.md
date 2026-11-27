# Allied races — Vulpera (24), Zandalari Troll (25), Kul Tiran (26)

Second batch after the Pandaren port, built with the same pipeline and the same donor
(`K:\ascension_live\Data\patch-CHA.MPQ` art + `patch-M.MPQ` DBCs). Read
`../Pandaren/00_SCOPE.md` first — every trap documented there applies here.

Apply with `mysql acore_world < apply_all.sql` from this folder. **Worldserver rebuild
required** (`SharedDefines.h` race enum).

| Race | id | Faction | Language | Donor | Displays | Models |
|---|---|---|---|---|---|---|
| Vulpera | 24 | Horde (2) | Orcish | Ascension 19 | 503912 / 503913 | 503902 / 503903 |
| Zandalari Troll | 25 | Horde (2) | Orcish | Ascension 12 | 503914 / 503915 | 503904 / 503905 |
| Kul Tiran | 26 | Alliance (1) | Common | Ascension 16 | 503916 / 503917 | 503906 / 503907 |

Racemask bits: Vulpera `0x800000`, Zandalari `0x1000000`, Kul Tiran `0x2000000`.
Running all-races mask is now **58720256 | 4095 | 6291456 = 62914559**.

## Donor validation (all six models passed the Pandaren acceptance gate)

MD20 v264, one skin, texture types ≤ 8, 192–222 bones. Animation coverage is far better
than Pandaren's (which was missing 112):

| | external declared | missing |
|---|---|---|
| Vulpera M/F | 56 | 8 |
| Zandalari M/F | 253 / 226 | 23 / 16 |
| Kul Tiran M/F | 229 / 213 | 17 / 15 |

Harvest: 2,316 files → `retailextracts/allied_races/files`, all present, all 1,355 BLPs
valid (BLP2, hasMips=1). All 1,346 CharSections textures resolve on disk.

**One donor defect, fixed automatically.** Ascension's Zandalari male section-4 rows name
7 `zandalaritrollmalenakedtorsoskin*` textures that exist in no client (155 rows referenced
them). The generator clears dangling references rather than copying them — and that is
exactly right here: every stock male race has pelvis-only underwear with the torso slot
empty, so clearing reproduces the correct stock shape. Verified against Human/Orc/Troll/Tauren.

## Files

| File | Purpose |
|---|---|
| 01_playercreateinfo.sql | 30 start rows (3 races × 10 classes) at Azshara Crater, map 37 zone 268 |
| 02_player_race_stats.sql | Base stats — Vulpera agile, Zandalari strong, Kul Tiran heavy |
| 03_playercreateinfo_skills.sql | Both-faction skill rows opened to the new bits |
| 04_playercreateinfo_spell_custom.sql | Class spells = human ∩ orc, plus faction languages |
| 05_playercreateinfo_action.sql | Action bars cloned from the faction's base race |
| 06_race_mask_sweeps.sql | quest/item `AllowableRace(s)`; sentinels pinned first |
| 11_dbc_overlay.sql | The five server-loaded DBC stores as world-DB overlay rows |
| 13_language_skills.sql | Language **skills** (chat gates on the skill, not the spell) |

`tools/gen_allied_race_dbcs.py` builds every client DBC row and is **parameterised** — the
`RACES` table at the top is the whole configuration, so a fourth race (Earthen is the
obvious candidate; its donor is equally complete) is a data edit plus a harvest.
`tools/gen_allied_dbc_overlay.py` emits the server overlay SQL.

## Client state (deployed and byte-verified)

- **patch-7**: 2,316 art files.
- **patch-4 + enGB-3 + WXL candidates**: 9 DBCs (ChrRaces, CharSections, CharHairGeosets,
  CharacterFacialHairStyles, CharBaseInfo, CharStartOutfit, CreatureModelData,
  CreatureDisplayInfo, SkillRaceClassInfo). Zero pre-existing rows changed in any table.
- **patch-5**: `MAX_RACES` 14 → **17**, race buttons 15–17, lore/ability strings, glue-scene
  substitutes, camera entries, regenerated customization swatches, and the widened race atlas.

### The race icon atlas was widened to 1024×256

The old 512×256 atlas is 8 columns × 4 rows, where a column holds one Alliance race
(rows 0/2) and one Horde race (rows 1/3) — so it caps at 8 + 8 races and was full. It is now
**16 columns**: Kul Tiran + Vulpera share col 7, Zandalari takes col 8, leaving 7 free
columns (14 races) for the Tier-1 reskins.

Every U coordinate in `RACE_ICON_TCOORDS` is therefore **halved** from the old values.
The existing cells were preserved by copying their original DXT3 blocks byte-for-byte
rather than re-encoding — a naive re-encode drifted the stock icons by up to 54/255.
New icons come from retail `characterframe/temporaryportrait-<sex>-<race>.blp` (64×64,
round) composited into the existing bevel frame.

### Glue scenes

All three have their own glue scene, downported from retail.

**Retail still ships the legacy `UI_<Race>` glue scenes** — the whole set, including races 3.3.5
never had. That is easy to miss, because retail has not *used* that screen since Shadowlands
replaced it, and Ascension ships none of them (422 glue-model files, zero allied races). The
listfile is the check that settles it:

    grep -i "interface/glues/models/" community-listfile.csv | sed 's|.*models/||; s|/.*||' | sort -u

which returns `ui_vulpera`, `ui_kultiran`, `ui_zandalari`, plus `ui_darkirondwarf`,
`ui_highmountaintauren`, `ui_lightforgeddraenei`, `ui_voidelf`, `ui_mechagnome`,
`ui_nightborneelf`, `ui_earthen` — and `ui_troll` and `ui_gnome`, which this client has never had.

Same pipeline as Pandaren: `casc-extract` then `wxl-baker --deps --native-m2`, which converts
MD21 / inner MD20 v274 to v264 and resolves the `TXID` chunk's texture FileDataIDs to type-0 paths.
109 files across the three, all packed into patch-5.

**Run `fix_cata_shader_batches.py --fix` after every bake.** `wxl-baker` finalises the M2 header
but copies `.skin` files verbatim, so Cata-era `shader_id & 0x8000` batches survive the downport —
and 3.3.5 drops those batches silently, with no error and no placeholder, leaving parts of the
scene simply absent. Vulpera had 3 and Zandalari 18; Kul Tiran and Pandaren had none, which is why
Pandaren looked right first time. All now 0.

Two wiring details:

- `SetLighting()` indexes `RaceLights` with the name **after** substitution, so while these races
  borrowed the Orc/Human scenes they were also borrowing those lights. Each now has its own entry
  seeded with the set it was already using, so the real scenes cannot arrive unlit; retune against
  the actual backdrops.
- Zandalari's folder is `UI_Zandalari` but our ClientFileString is `ZandalariTroll`, so
  `DC_GLUE_SCENE_SUBSTITUTE` keeps one entry mapping the name. That is cheaper than renaming the
  `.m2`/`.skin` files, whose internal texture paths point back into `ui_zandalari`.

Ambience stays on stock tracks (`GlueScreenOrcTroll` / `GlueScreenHuman`): no allied-race sound
kits exist in 3.3.5 and `PlayGlueAmbience` errors on an unknown name. `SetBackgroundModel` keys
ambience off the post-mapping name, so Zandalari needs both `ZANDALARI` and `ZANDALARITROLL` keys —
`CharacterSelect_OnShow` indexes the table with the raw race name separately.

## Racials — shipped

Ten spells, in `10_spell_dbc.sql` (server definitions) and `12_racial_spells.sql` (the grants).
Design, templates and the deliberately-omitted list: **`00_RACIALS.md`**.

| Race | Racials |
|---|---|
| Vulpera | Bag of Tricks, Nose for Trouble, Fire Resistance |
| Zandalari Troll | Regeneratin', Pterrordax Swoop, City of Gold |
| Kul Tiran | Haymaker, Child of the Sea, Rime of the Ancient Mariner |

These were deferred at first on the assumption that BfA racials need core work. Nine of the ten are
pure data: `SPELL_EFFECT_KNOCK_BACK` is 98 in 3.3.5 and a spell has three effect slots, so even
Haymaker (damage + knockback + stun) fits in one row. Only **City of Gold** needed core work — a
per-looter +2% in `LootHandler.cpp`, applied after the play-time reduction so a mixed group pays
the bonus only to the trolls in it.

Still not shipped, with reasons, in `00_RACIALS.md`: Make Camp/Return to Camp, Embrace of the Loa,
Jack of All Trades, Brush It Off, Rummage Your Bag.

## Pending

1. `mysql acore_world < apply_all.sql` — now also carries the racial spell rows and grants.
2. Rebuild the worldserver: the race enum, and the City of Gold hook in `LootHandler.cpp`.
3. Camera `BODY_TUNE`/`FACE_TUNE` for 26 is still a first guess. 25 was widened to `back = 2.0`
   after in-client review; 24 and the Pandaren values are settled.
