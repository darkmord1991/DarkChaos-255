# Naxxramas art split: map 533 (WotLK) vs map 2921 (SoD)

Done 2026-08-21. Purpose: give map 2921 its own Naxxramas building so the
`mod-vanilla-naxxramas` 40-man "special edition" is visually distinct from
stock WotLK Naxxramas on map 533, and so its interior areas resolve to a
map-2921 AreaTable row instead of a map-533 one.

## The problem

`WMOAreaTable` has no map column - the client resolves an interior area from
`(WMOID, nameSetID, groupID)` alone, and it ignores nameSet for the purpose of
picking between two maps. Map 533 and map 2921 both placed
`world/wmo/dungeon/ld_stratholme/stratholme_raid.wmo` (wmoID 4489) at the
identical origin `3005.78, -3434.35, 300.97`, both with `nameSet = 1`, so both
resolved to `AreaTable 3456 "Naxxramas"` whose `ContinentID` is **533**. Same
failure mode as the Undercity clone ([[wmo-interior-area-nameset]]).

Separately, `patch-9` was shadowing the stock WMO with the Classic-Era/SoD
build (73 groups vs stock 65), so map 533 was already rendering SoD art.

## What was done

**Client assets** (staging kept at `k:/tmp/naxxsod_stage`, 100 files):

| clone | from | new wmoID | groups |
|---|---|---|---|
| `Naxxramas_SoD01.wmo` | patch-9 `stratholme_raid.wmo` (SoD) | 66902 | 73 |
| `Frostwyrm_SoDRaid.wmo` | patch-9 `frostwyrm_final01.wmo` (SoD) | 66903 | 11 |

- Group files are plain copies; only `MOHD.wmoID` (payload offset +32) was patched.
- New names were chosen to be **the same byte length** as the originals
  (`stratholme_raid` 19 -> `naxxramas_sod01` 19; `frostwyrm_final01` 21 ->
  `frostwyrm_sodraid` 21) so the 13 map-2921 ADTs could be patched by in-place
  byte replacement in `MWMO` - no `MWID`/`MHDR`/`MCIN` offset math, ADT sizes
  unchanged, MODF placements verified identical afterwards.

**DBC** - `Custom/CSV DBC/WMOAreaTable.csv`, 162 rows appended (ids 110896-111057):
- 148 rows cloning `(4489, nameSet 1)` -> WMOID 66902, `AreaTableID 3456 -> 16394` on 73 of them
- 14 rows cloning `(4491, nameSet 1)` -> WMOID 66903, all remapped to 16394
- `AreaTable 16394 "Naxxramas" ContinentID 2921 AreaBit 1945` already existed, and
  map 2921's terrain was already retagged (6141 of 6144 MCNK chunks carry areaid 16394)
- All 8 SoD-only groups (19876, 19878, 19882, 19891, 19894, 19895, 19912, 19915)
  already had Blizzard WMOAreaTable rows and came across in the clone
- Verified: ignoring the `ID` column, 0 rows lost, exactly 162 added

**Minimap** - 616 lines added to `textures\Minimap\md5translate.trs` (308 source
tiles x 2 slash spellings), pointing at the existing md5 BLPs. Map 2921's MWMO
uses **forward slashes** and trs lookup is case-insensitive but NOT
slash-insensitive, so both `WMO\Dungeon\...` and `wmo/dungeon/...` keys are emitted.

**Deployed:**
- patch-9: +86 new WMO files; **-86** old `stratholme_raid*` / `frostwyrm_final01*`
  overrides so map 533 falls back to the stock 65-group build in patch-2
- patch-4: 13 patched ADTs, md5translate.trs, WMOAreaTable.dbc (remove-then-set,
  per the duplicate-hash-entry trap)
- `sync-dbc-deploy.js --files WMOAreaTable.dbc` -> all 3 WarcraftXLHost candidate dirs

All writes re-verified by extracting in a **fresh process** and comparing md5.

## Still open

- **Server DBC not deployed** - live server still reports `recordCount 23362`.
  Copy `Custom/DBCs/WMOAreaTable.dbc` to the Linux server's `data/dbc/`.
- **vmaps** - regenerate for map 533 (now 65 groups again) and generate for map
  2921 (73 groups); 2921 has never had maps/vmaps/mmaps extracted at all.
- Groups 065-072 of the SoD build have **no minimap tiles** in the trs (Blizzard
  never shipped any); those 8 restored rooms will show blank minimap.
- `stratholme_a.wmo` / `stratholme_c.wmo` are **still** shadowed by patch-9 with
  Classic-Era variants (same wmoID/group counts, 204 vs 218 and 39 vs 42 doodads).
  Left alone deliberately - out of scope, and they affect map 329 + the outdoor city.

## Rollback

`patch-4.MPQ.pre-mpq-remove.bak`, `patch-9.MPQ.pre-mpq-remove.bak`,
`Custom/CSV DBC/WMOAreaTable.csv.pre-naxxsod.bak`,
`Custom/DBCs/WMOAreaTable.dbc.pre-naxxsod.bak`.
