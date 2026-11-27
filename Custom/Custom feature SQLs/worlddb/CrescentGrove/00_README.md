# Crescent Grove (map 823) — 5-man dungeon

Turtle WoW custom dungeon, imported 2026-08-09. **Client side is fully built and deployed;
the SQL in this folder has NOT been applied.**

The full implementation record — asset provenance, the area-id collision that forced a
retag, the height sampler, and every locked id — lives in
[`Custom/TurtleDungeons/00_README.md`](../../../TurtleDungeons/00_README.md). Read that
first; this file is only the apply order.

## Apply order

1. `01_instance_template.sql` — register map 823 as a dungeon
2. `02_game_tele.sql` — `.tele dccrescentgrove` / `dccrescentgrovegate`
3. `03_areatrigger_teleport.sql` — the walk-in entrance (6927)
4. `../_shared/dungeon_entrance_npcs.sql` — Gatekeeper 3999005 / Warden 3999006, and the
   seven other entrance NPCs; re-runnable, so applying it again is safe
5. `04_dungeon_access.sql` — level gate (min_level 88, a tuning choice)

## Before any of it works

* the seven changed DBCs must reach the worldserver's `data/dbc`
  (`Map`, `AreaTable`, `WorldMapArea`, `LoadingScreens`, `MapDifficulty`, `AreaTrigger`,
  `AreaPOI` — already compiled into `Custom/DBCs/` and deployed client-side)
* `mapextractor` / `vmap4extractor` + assembler / `mmaps_generator` must be run for map 823
  (16 tiles). The 27 WMO placements are open elf ruins you can walk into, so vmaps matter.

## Known-empty

Zero creature and gameobject spawns exist on map 823. Once the extractors run it is a
walkable, correctly-lit dungeon with nothing in it.
