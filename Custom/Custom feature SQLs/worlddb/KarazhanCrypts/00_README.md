# Karazhan Crypts (map 2875)

Season of Discovery dungeon, downported from the `wow_classic_era` client (build 1.15.8.67156)
via `wow.export`'s `tools/downport-map.js` + the `wxl-baker`/`wxl-skinfix` pipeline — the same
pipeline used for Hyjal Frontier / Deepholm / Blackwing Descent. Full write-up of the downport
process and validation is in the session that produced this folder; this directory only covers
server-side registration.

## Locked IDs

| Asset | Value | Notes |
|---|---|---|
| Map ID | **2875** | `2875` directory (FileDataID-style, from the modern client), InstanceType=1 (dungeon), kept as the retail id per the downport tool's convention (no collision with 3.3.5 map ids) |
| AreaTable ID | **16074** | `KarazhanCrypts` / "Karazhan Crypts", row in `Custom/CSV DBC/AreaTable.csv` |
| WorldMapArea ID | **1222** | `Custom/CSV DBC/WorldMapArea.csv` |
| Light ID | **3583** | `Custom/DBCs/Light.dbc` — next free id after the 2026-07-12 fallback-light batch (3568-3582); LightParams 15393 |
| LoadingScreenID | **639** | `Custom/CSV DBC/LoadingScreens.csv`, `loadscreenkarazhancrypts.blp` |
| AreaTrigger IDs | **6921** (entrance, map 0 Deadwind Pass near Karazhan) / **6922** (exit, inside map 2875) | `Custom/CSV DBC/AreaTrigger.csv`; renumbered from 607000/607001, see `_shared/renumber_areatrigger_ids.sql` -- ids must stay under 65535 |
| game_tele ID | **10615** | next free after BWD's 10614 (live DB checked) |

## Client side (already deployed this session)

* Terrain: 12 ADT tiles (`world/maps/2875/`), fully self-contained bake (977 M2, 155 WMO, 1307 BLP).
* DBC rows merged into `Custom/CSV DBC/` master and compiled to `Custom/DBCs/*.dbc`.
* Packed into `patch-4.MPQ` (DBCs/minimap/maps), `patch-5.MPQ` (character-scale assets),
  `patch-6.MPQ` (world assets) at `K:\WoW_3.3.5a_ 255 Fun\Data\`, and synced to the 3
  WarcraftXLHost candidate dirs.

## Still to do (server side)

1. Apply `01_instance_template.sql` — registers map 2875 as a dungeon instance.
2. Apply `02_game_tele.sql` — `.tele karazhancrypts` GM/player teleport command.
3. Apply `03_areatrigger_teleport.sql` — walk-in entrance near Karazhan's grounds in Deadwind
   Pass (map 0) and a return exit inside the dungeon.
4. Run the AzerothCore extractors (`mapextractor`/`vmap4extractor`/`mmaps_generator`) against the
   deployed `Data/` tree to produce `maps/2875_*.map`, `vmaps/2875*`, `mmaps/2875*` — **not done by
   this session, the user is running this separately.**
5. Coordinates for the entrance/exit triggers and the `game_tele` point are best-effort placements
   based on the dungeon's WorldMapArea bounding box and Karazhan's real-world (map 532) entrance
   position — verify/adjust Z-height and exact placement once maps/vmaps exist and the zone can be
   inspected in Noggit or in-game.
