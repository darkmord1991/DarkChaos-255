# Stratholme — DarkChaos clone on map 821

Stock Stratholme (map 329) is a shared map. Anything placed inside it to make the exit land
on the DC Lordaeron extension, or to re-level it to 130–160, changes the dungeon for every
player on the realm. This clones it onto a private map id instead, so **both ends are ours
and stock is provably untouched**.

The client-side cost is **nil**: `Map.dbc` row 821 keeps `Directory = "Stratholme"`, so the
client loads the WMO it already has. The map id appears only in server-side terrain
*filenames*, which is why the terrain step is a plain rename-copy with no extractor run.

---

## Apply order

| # | File | What it does |
|---|------|--------------|
| 01 | `01_map821_registration.sql` | `instance_template`, `dungeon_access_template`, `.tele dcstrat` |
| 02 | `02_id_maps.sql` | builds the six `dc_strat821_*` remap tables everything else joins to |
| 03 | `03_templates.sql` | `creature_template` + `creature_template_model`, `gameobject_template` + `gameobject_template_addon`, equip |
| 04 | `04_spawns.sql` | 468 creatures, 188 gameobjects |
| 05 | `05_spawn_support.sql` | 112 addons, 338 formation rows, 520 waypoints |
| 06 | `06_behaviour.sql` | SmartAI (4 row sets) + 37 `creature_text` + the cross-map teleport fix |
| 07 | `07_portals.sql` | 3 walk-through entrances, 1 exit |

Each file ends with a self-check report. Every branch is numeric and `CAST(... AS CHAR)` —
a bare literal in a `UNION` takes the connection collation while `ScriptName`/`comment`/`name`
are `utf8mb4_unicode_ci`, and MySQL raises **1271 Illegal mix of collations**.

### Outside SQL — all three are required

```bash
# 1. DBC rows: Map 821 + MapDifficulty 9355/9356/9357   (ALREADY APPLIED to the CSVs)
python Custom/StratholmeDC/add_strat821_dbc_rows.py --apply
#    then compile and deploy Map.dbc + MapDifficulty.dbc to
#      patch-4.MPQ  AND  enGB/patch-enGB-3.MPQ   (enGB shadows patch-4 for DBCs)
#      all three WarcraftXLHost candidate dirs   (sync-dbc-deploy.js)
#      the SERVER's own dbc directory            (worldserver reads its own copy)

# 2. Terrain — without this players fall through the world
./Custom/StratholmeDC/clone_map329_files_to_821.sh /path/to/server/data --apply

# 3. Worldserver rebuild. Run `cmake .` in build/ FIRST — AutoCollect.cmake:28 globs
#    sources without CONFIGURE_DEPENDS, so new .cpp files are invisible until you do,
#    and the build fails at link with `undefined symbol: AddDCStratholmeScripts()`.
```

---

## Id allocation

Dense (`ROW_NUMBER` over the sorted source ids), **not** a fixed offset. Stratholme's
entries span 10381–351097 and 153464–182072; a flat `+N` over spans that wide scatters the
clone across unrelated bands, which on this realm is not hypothetical — the same approach on
Shadowfang produced a live collision (duplicate entry 5301906).

| What | Band | Count |
|---|---|---|
| `creature_template` | 5500000+ | 66 |
| `gameobject_template` | 5600000+ | 114 |
| `creature.guid` | 16740000+ | 468 |
| `gameobject.guid` | 16520000+ | 188 |
| `waypoint_data.id` | 8210000+ | 29 |
| action lists | 8220000+ | 13 |
| portal triggers | 5520000–5520003, guids 16741000–16741003 | 4 |

Spawn ids stay under `0xFFFFFF` — `ObjectMgr.cpp:7669/7679` rejects anything at or above it
and startup dies with TCE00007. Every guid here is explicit for the same reason: the
AUTO_INCREMENT counters on this realm sit *above* the cap.

---

## The traps this port actually hit

**Runtime-only entries are invisible to a spawn-based import.** 11 creatures and 2
gameobjects never appear in the `creature`/`gameobject` tables — they only exist as summons.
Seeding from spawned entries alone omits them silently, and the failure shows up much later
as a boss summoning something that does not exist. The set was built by unioning SmartAI
summons (`action_type` 12 and 50), every `NPC_*`/`GO_*` id in `stratholme.h`, and the
Jarien/Sothos event.

- creatures: 10387, 10394, 10439, 10441, 10461, 10536, 11030, 16101–16104
- gameobjects: 176747 Small Barracks Flame, 181083 Sothos and Jarien's Heirlooms

**`spell_target_position` hardcodes map 329.** Ten spells cast in this dungeon carry a DB
teleport destination whose map id is applied *absolutely* for `SPELL_EFFECT_TELEPORT_UNITS`
(`Spell.cpp:1403-1409`). On the clone that is a cross-map teleport. All of them target
creatures, so `SpellEffects.cpp:1240` catches it — no player escapes into stock Stratholme —
but Baron Rivendare stops repositioning, the Thuzadin Acolytes stop teleporting to their
ziggurats, and the error log fills. Fixed by rewriting the 9 SmartAI casts as native
`SMART_ACTION_TELEPORT` (62), which takes the map id as a plain parameter. **No new spells,
no Spell.dbc work, no client deploy.** (The 10th spell belongs to a gameobject that is not
spawned in Stratholme, so nothing can fire it.)

**Four SmartAI row sets, not one.** Per-entry (304), per-*spawn* keyed on negated guid (35),
gameobject (54), and timed action lists (47 rows / 13 lists, keyed by `entry*100` and not by
any creature id at all). Missing any set is silent.

**Parent tables import fine while the table that governs behaviour is skipped.** This shape
cost the most time on Shadowfang, four separate times. `creature_template_model` missing →
ObjectMgr refuses to load the creature at all (empty dungeon). `gameobject_template_addon`
missing → door flags lost, everything stands open. Both are in the *same file* as their
parent here, with report lines that fail loudly.

**`spawnMask` is 7, not 1.** DC already gave stock Stratholme heroic and mythic
(MapDifficulty 9130/9131). Cloning the spawns without cloning all three MapDifficulty rows
gives a working normal mode and two silently empty ones.

**Gameobject `AIName`.** Only `''` and `'SmartGameObjectAI'` are legal. `'SmartAI'` is the
*creature* registry; `FactorySelector::SelectGameObjectAI` (`CreatureAISelector.cpp:108`) has
no null guard and segfaults the worldserver the instant a player walks into the grid.

**Areatriggers do not work here.** New areatriggers provably never fire on this fork's
custom maps — built end-to-end for Shadowfang, deployed everywhere, and the client sends no
`CMSG_AREATRIGGER` even from 2 yards away. The portals are invisible trigger *creatures*
hooking `MoveInLineOfSight`. Their `ScriptName` is load-bearing: `Creature.cpp:2631` would
otherwise disable that hook for anything carrying the trigger flag.

---

## Deliberate exclusions and inherited quirks

- **351097 "Naxx40 Strath Entrance Trigger"** is not cloned. It belongs to the naxx40 module
  and teleports to map 2921; copying it would give the clone a second Naxxramas entrance.
- **Loot is reused, not zeroed.** 47 entries keep their `lootid`. Because this is a
  same-database clone those loot templates already exist and are correct — the opposite of
  the Shadowfang port, where loot came from `cata_world`, did not exist locally, and had to
  be dropped.
- **One `SMART_ACTION_SUMMON_CREATURE_GROUP` row references a `creature_summon_groups` entry
  that does not exist upstream either.** A pre-existing stock gap, inherited, not import
  damage. The report records it so it is not mistaken for one.

## Still open

- **The 130–160 re-level.** Nothing here changes levels; creatures are at stock values and
  `dungeon_access_template` id 161 carries stock's `min_level` 45. That row is the single
  place the entry gate lives — the portal triggers deliberately carry no level check of
  their own, because `Player::TeleportTo` already runs `MapMgr::PlayerCannotEnter`
  (`Player.cpp:1575`) against it and sends the standard message.
- **Front-gate exits.** Stock has three entrances and one exit (at the back), and the clone
  mirrors that exactly. Adding exits at the front gates needs care: an exit trigger placed on
  a front-gate *arrival* point teleports players straight back out as they arrive.
