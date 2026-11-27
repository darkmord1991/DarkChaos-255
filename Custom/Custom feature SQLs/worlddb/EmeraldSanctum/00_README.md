# Emerald Sanctum (map 824) — 20-man raid

Turtle WoW custom raid, imported 2026-08-09. **Client side is fully built and deployed; the
SQL in this folder has NOT been applied.**

The full implementation record — asset provenance, the area-id collision that forced a
retag, the height sampler, and every locked id — lives in
[`Custom/TurtleDungeons/00_README.md`](../../../TurtleDungeons/00_README.md). Read that
first; this file is only the apply order.

## Apply order

1. `01_instance_template.sql` — register map 824 as a raid
2. `02_game_tele.sql` — `.tele dcemeraldsanctum` / `dcemeraldsanctumgate`
3. `03_areatrigger_teleport.sql` — the walk-in entrance (6928)
4. `../_shared/dungeon_entrance_npcs.sql` — Gatekeeper 3999007 / Warden 3999008, and the
   seven other entrance NPCs; re-runnable, so applying it again is safe
5. `04_dungeon_access.sql` — level gate (min_level 113, a tuning choice)

## Check the entrance first

This is the one placement in the import with real uncertainty. Turtle's entrance is in map
1's **vanilla** Hyjal; map 750's Hyjal is the **Cataclysm** zone, rebuilt in place at the
same coordinates but with entirely different geometry. The gate spot
(`4833.10 / -1731.70 / 1196.215`) is on real ground in area 4923 and ~170 yd from the
Nordrassil spawns, so it is in the right neighbourhood — but the doorway Turtle's players
used does not exist on this terrain. `.gps` it and move the Gatekeeper somewhere that looks
deliberate.

The arrival point INSIDE the raid needs no such doubt: it computes to 30.099 against the
shipped terrain where the source pack's own trigger sits at 30.1.

## Before any of it works

* the seven changed DBCs must reach the worldserver's `data/dbc`
* `mapextractor` / `mmaps_generator` for map 824 (4 tiles). The map has **no WMOs at all**,
  so its vmaps are nearly empty and terrain collision alone carries it.

## Known-empty

Zero creature and gameobject spawns exist on map 824.
