# Naxxramas (map 2921) — evaluation pass

Season of Discovery zone, downported from the `wow_classic_era` client (build 1.15.8.67156) via
the same pipeline as Karazhan Crypts (map 2875). This is an **exploration/evaluation deployment**
— client assets and a `.tele` point are live so the zone can be walked and judged, not a committed
feature yet. See the tile-by-tile survey done before this downport: the zone is built from
`ld_stratholme`/Eastern-Plaguelands-Scourge/Duskwood-ruin WMO kit pieces (not a standalone
"floating necropolis" aesthetic), with a distinct `frostwyrm_final01.wmo` complex + dedicated
`naxxramas_frostwyrm_birth`/`slimefall` VFX doodads in the NE corner (tiles 41-42,24-25) as the
apparent final/boss area. Candidate use: Plaguelands-adjacent raid/event space, given the shared
asset language with `DCPlaguelands` (map 751) — not yet decided.

## Locked IDs

| Asset | Value | Notes |
|---|---|---|
| Map ID | **2921** | directory `2921`, InstanceType=1 (dungeon-flagged despite raid-scale content, same as the source client) |
| AreaTable ID | **16394** | `Naxxramas` (source data's own row is literally named "Naxxrammas", typo) |
| WorldMapArea ID | **1223** | |
| Light ID | **3584** | next sequential after Karazhan Crypts' 3583, no collision |
| LoadingScreenID | **197** | **collides with the existing stock WotLK Naxxramas (map 533) loading screen** — the merge correctly skipped overwriting it, so this zone currently shows the old Northrend Naxxramas loading screen as a fallback (harmless, arguably fitting; a genuinely new SoD-art loading screen would need a different free id if wanted) |
| game_tele ID | **10616** | next free after Karazhan Crypts' 10615 |
| MapDifficulty ID | **9334** | Normal/5-player, same recipe as Karazhan Crypts' 9333 fix — added proactively this time so entry isn't blocked |

## Client side (deployed this session)

* Terrain: 24 ADT tiles, fully self-contained bake (475 M2, 166 WMO, 721 BLP, 0 missing deps).
* DBC rows merged into `Custom/CSV DBC/` master, compiled to `Custom/DBCs/*.dbc`.
* Packed into `patch-4/5/6.MPQ` at `K:\WoW_3.3.5a_ 255 Fun\Data\` (1874 files, byte-verified).
* Synced to the 3 WarcraftXLHost candidate dirs **and** copied directly into the live worldserver's
  own `K:\Dark-Chaos\Server\data\dbc\` (Map/AreaTable/WorldMapArea/Light family) — **worldserver
  restart still required**, DBCs only load at boot.

## Still open

1. Apply `01_instance_template.sql` + `02_game_tele.sql` if you want to walk it in-game.
2. No `maps`/`vmaps`/`mmaps` generated yet — terrain height/collision won't work until the AC
   extractors are run against the updated `Data\` tree and the output copied into
   `K:\Dark-Chaos\Server\data\`.
3. This is explicitly NOT wired into any quest/instance/content system — evaluate first, decide
   what (if anything) to build on top.
