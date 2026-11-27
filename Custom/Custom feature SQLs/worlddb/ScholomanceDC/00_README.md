# Scholomance — DarkChaos clone on map 822

Stock Scholomance (map 289) is a shared map. Anything placed inside it to make the exits
land on the DC Lordaeron extension, or to re-level it to 130–160, changes the dungeon for
every player on the realm. This clones it onto a private map id instead, so **both ends are
ours and stock is provably untouched**.

Same recipe as the Stratholme clone (821), which is the working reference. The client-side
cost is **nil**: `Map.dbc` row 822 keeps `Directory = "SchoolofNecromancy"`, so the client
loads the WMO it already has.

---

## Apply order

| # | File | What it does |
|---|------|--------------|
| 01 | `01_map822_registration.sql` | `instance_template`, `dungeon_access_template`, `.tele dcscholo` |
| 02 | `02_id_maps.sql` | builds the six `dc_scholo822_*` remap tables |
| 03 | `03_templates.sql` | `creature_template` + `creature_template_model`, `gameobject_template` + `gameobject_template_addon`, equip |
| 04 | `04_spawns.sql` | 399 creatures, 62 gameobjects |
| 05 | `05_spawn_support.sql` | 182 addons, 3 formations, 16 waypoint paths |
| 06 | `06_behaviour.sql` | SmartAI (entry / gameobject / action list) + 30 `creature_text` |
| 07 | `07_portals.sql` | 1 walk-through entrance, 4 exits |
| 08 | `08_fix_pathless_waypoint_movement.sql` | silences 2 inherited pathless waypoint movers |

Each file ends with a self-check report. Every branch is numeric and `CAST(… AS CHAR)` — a
bare literal in a `UNION` takes the connection collation while `ScriptName`/`comment`/`name`
are `utf8mb4_unicode_ci`, and MySQL raises **1271 Illegal mix of collations**.

### Outside SQL

```bash
# 1. DBC rows -- ALREADY APPLIED AND DEPLOYED (Map 822, MapDifficulty 9358-9360,
#    DungeonMap 769-772, DungeonMapChunk 6818-6843, WorldMapArea 1278)
python Custom/ScholomanceDC/add_scholo822_dbc_rows.py --apply

# 2. Terrain -- without this players fall through the world
./Custom/ScholomanceDC/clone_map289_files_to_822.sh /path/to/server/data --apply

# 3. Worldserver rebuild. Run `cmake .` in build/ FIRST -- AutoCollect.cmake:28 globs
#    sources without CONFIGURE_DEPENDS, so new .cpp files are invisible until you do.

# 4. Copy Map.dbc + MapDifficulty.dbc to the SERVER's data/dbc, or map 822 will not load.
```

---

## Id allocation

Dense (`ROW_NUMBER` over sorted source ids), **not** a fixed offset.

| What | Band | Count |
|---|---|---|
| `creature_template` | 5700000+ | **47** |
| `gameobject_template` | 5800000+ | 62 |
| `creature.guid` | 16750000+ | 399 |
| `gameobject.guid` | 16530000+ | 62 |
| `waypoint_data.id` | 8230000+ | 16 |
| action lists | 8240000+ | 1 |
| portal triggers | 5720000–5720004, guids 16751000–16751004 | 5 |

---

## The traps this port hit

**Runtime-only entries come in THREE kinds, not two.** Six creature entries never appear in
the `creature` table:

- **summoned by SmartAI** — 16118 Kormok
- **summoned from C++** — 10506 Kirtonos, 11598 Risen Guardian, and 16119/16120 via Spell.dbc
- **`UpdateEntry()` morph targets** — 10472 Occultist and **11284 Dark Shade**

That last kind is new. Dark Shade is neither spawned nor summoned: the Occultist *morphs*
into it at 30% health. A scan for spawned entries misses it and so does a scan for summon
targets — an earlier draft of this port left it out entirely, which would have morphed the
clone's occultists into the **stock** creature and dropped them out of this map's id band.
Adding it also shifted four ids that sort above it, so the C++ header had to be re-read from
the mapping tables.

**Gandling's room shuffle is a real cross-instance leak.** Six spells carry
`spell_target_position` rows hardcoded to MapID 289, and `Spell.cpp:1403-1409` applies that
map id absolutely. Unlike Stratholme's equivalent (creature-targeted, so the core caught it
and only logged), these are cast on a **player** — on the clone they teleport them into stock
Scholomance. Fixed in `boss_darkmaster_gandling_dc.cpp` by teleporting directly to the same
coordinates. No Spell.dbc work, no client deploy.

**Kormok's adds come from Spell.dbc, which is shared.** 27690-27693 carry
`EffectMiscValue 16119`, so even on the clone the spells produce the **stock** adds — stock
level, stock loot. `boss_kormok_dc.cpp` catches them in `JustSummoned` and re-summons the
clone entry at the same position, so the spell still chooses where each add appears.

**Spell-bound scripts are NOT cloned.** The two aura scripts in the instance file and the two
spell scripts in Kormok's bind to *spell ids* via `spell_script_names`. Spell.dbc is shared,
so the stock registrations already cover map 822 — cloning them would attach two scripts to
the same spells.

**`target_type 11` (CREATURE_DISTANCE)** is used here and was not in the Stratholme data. It
carries a creature entry; unhandled, those three rows would hunt for a stock creature.

---

## Portals

One entrance, four exits, matching stock. Radii are per-portal in
`npc_scholomance_dc_portal_trigger.cpp`:

| Portal | Radius | Nearest arrival | Margin |
|---|---|---|---|
| entrance (751) | 5.5 | 9.21 yd | +3.71 |
| porch A/B/C (822) | 12.0 | 130–144 yd | +118 … +132 |
| main door (822) | 6.0 | 18.43 yd | +12.43 |

**The entrance is the constrained one — the reverse of Stratholme.** The main-door exit drops
players on 751 only 9.21 yd from the entrance trigger. The porch trio is sized for coverage:
B and C sit 36.9 yd apart with A between them, and 12.0 makes the chain B–A–C continuous
(10.0 leaves 1.4 and 0.3 yd dead strips).

## Inherited stock defects

**Two spawns carry `MovementType = 2` with no path** — Ras Frostwhisper and Lord Blackwood.
No `creature_addon` row, no `waypoint_data` keyed by their guid. Their stock counterparts are
in the identical state and log the identical error; 28 spawns realm-wide share the shape. The
clone reproduces it because `04` copies `MovementType` verbatim, which is correct for a clone.
Harmless — `WaypointMovementGenerator.cpp:72-76` logs and returns before setting the roaming
state, so they just stand still — but it repeats on every respawn, so `08` sets them to idle
on **map 822 only**. Stock is left alone.

## Still open

- **The 130–160 re-level.** `dungeon_access_template` id 162 carries stock's `min_level` 45
  and is the single place the entry gate lives.
- Loot is reused from stock (38 entries keep their `lootid`) — correct for a same-database
  clone, but those templates are shared with stock Scholomance.
