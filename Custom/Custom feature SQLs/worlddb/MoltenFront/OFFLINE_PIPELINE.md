# Molten Front — offline pipeline (terrain carve + client repack)

The SQL in this folder is inert until the Molten Front terrain pocket exists on
map 750. These are the **offline** steps (run on your machine — they need the
retail client + the DC toolchain; I can't run them). Do them in order.

All tools live in `K:\Dark-Chaos\wow.export-main\tools\`; the baker binary is
`K:\Dark-Chaos\dc-wotlkextensions\build\downport\Release\wxl-baker.exe`
(invoked for you by `downport-map.js`).

---

## 1. Register + downport map 861 (its own map)

The Molten Front is a **separate map (id 861)** — its own coordinate frame
(ground z ≈ −93..235), NOT a corner of Mount Hyjal. So it is registered as a new
DC map and its terrain downported independently; the `02` spawns then align on it
verbatim. (Map id 861 is currently **free** in `Custom/CSV DBC/Map.csv`.)

**1a. Terrain source — RESOLVED + verified.** Cata Map.dbc row **861 = `FirelandsDailies`**
(InstanceType 0). Its terrain ships in the **Cata 4.3.4 client**
`K:\UntouchedClients\Cata\Data\expansion3.MPQ` under `World\Maps\FirelandsDailies\`.
Parsed WDT: **80 tiles, X 27–36 / Y 25–32**. Split ADTs (root/_obj0/_tex0/_tex1) all in
expansion3.MPQ. MPQ has no listfile for them, so extract by **exact name** (hash-resolved),
not glob-list. **wxl-baker verified working** on these ADTs (tile 31_28 downported cleanly).

**1b. Downport — one command.** A driver automates the whole extract→bake→MISS-dep→re-bake
loop for the Cata MPQ source: `Custom/Documentation/scripts/downport_firelandsdailies.py`:
```
python downport_firelandsdailies.py \
  --cata "K:/UntouchedClients/Cata/Data" \
  --extract "K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py" \
  --baker  "K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe" \
  --work   "K:/Dark-Chaos/retailextracts/dc_moltenfront_861"
```
Output: `<work>/baked/world/maps/firelandsdailies/*` (the 3.3.5 ADT set). Manual equivalent:
`wxl-baker.exe --in <src> --out <baked> --tiles FirelandsDailies 27 25 36 32 --deps --no-update`,
extracting each `MISS` name from the Cata MPQs and re-baking. For terrain light run
`light-downport.js` on the baked map. Keep the map Directory `FirelandsDailies` (matches
the `Map.csv` row already added).

**1c. Register the map.** Add a `Custom/CSV DBC/Map.csv` row: `861, DCMoltenFront,
InstanceType 0, MapName "The Molten Front", AreaTableID <new>` + an `AreaTable.csv`
row for its zone, recompile, pack into patch-4 (see step 3). Set the spawns' zone
via that AreaTable (the `02` spawns currently use zoneId/areaId 0 → engine resolves
from the map's area data once registered).

> **VERIFY after carve:** `.go xyz 1021 394 42 861` (the MF hub) and confirm the
> ground is there and the spawns stand on it.

## 2. Regenerate server collision/pathing for the new tiles

The new ADTs need server-side `maps/vmaps/mmaps` (same extractors you used for the
main block — they read the **client** data, so do step 3's map/minimap packing
first, or point the extractors at the staging ADT tree):

```
mapextractor        -> 0861XXYY.map   (map 861 tiles)
vmap4extractor + vmap4assembler -> vmaps\0861*
mmaps_generator 861                   -> mmaps\0861*
```

Deploy the new `0861*` files into the **live** `Server\data\{maps,vmaps,mmaps}`.
Map 750's files are untouched (MF is a separate map now).

## 3. Repack the client patches — the RULES

**Never use MPQEditor `/console new` + wildcard `add`** — it corrupts the archive
to orphaned `File000xxx` entries in seconds (this destroyed patch-B..E once).
MPQEditor console is safe ONLY for single-file `delete`/`add`/`flush`.

Use the StormLib python tools instead:
- `mpq_stormlib_patch.py --set-file` — set individual files into an existing patch
  (byte-verified). Best for the DBC + a handful of files.
- `mpq_stormlib_pack.py` — pack a whole staging tree → a fresh V1 MPQ (atomic, verified).
  Best for the ADT + minimap tile set.

**Patch layout** (which archive gets what):
- **patch-4** — `World\Maps\DCMountHyjal\*` (the new ADTs), `textures\Minimap\DCMountHyjal\*`
  (the new minimap tiles) + the **merged** `textures\Minimap\md5translate.trs`, and any
  `DBFilesClient\*.dbc` you recompile (AreaTable/Map/Light/etc.).
- **patch-A** — `Interface\*` (WorldMap overlay art, loading screens) if you touch those.
- Do **not** shadow: the `enGB` locale patch chain outranks base patches for DBC/locale,
  so if a DBC also lives under `Data\enGB\patch-enGB-3.MPQ` it must be updated there too.

**md5translate.trs**: merge the new `DCMountHyjal` block into the cumulative master
(via `minimap-downport.js`'s merge, not a per-map overwrite) or you shadow every
other map's minimaps.

> After a large `mpq_stormlib_patch.py` write the ~1GB patch-4 can transiently fail
> to open for a few seconds (AV/indexer lock, not corruption) — just retry.

## 4. Client DBC niceties (optional, same as the main-zone immersion pass)

`downport-map.js --light` handles the terrain light. If you also want the MF pocket
to read as its own sub-area (its own name on the map / minimap), that's an
`AreaTable` sub-row under 4923 + a `WorldMapArea` entry — part of the separate
client-immersion DBC pass (ZoneMusic/AmbienceID/loading-screen/overlay), not required
for the pocket to be playable.

---

**Bottom line:** step 1 (`downport-map.js --map 750 --bbox 30,16,42,32 --light`)
is the "what do I do" — it drives wxl-baker for you. Then regen server map data
(step 2) and repack via the StormLib tools into patch-4 (step 3). The verify note
in step 1 is the one thing to eyeball before trusting the spawn alignment.
