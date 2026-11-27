# Cataclysm Shadowfang Keep — map 825 clone

The Cataclysm 4.3.4 Shadowfang Keep revamp (Baron Ashbury, Lord Walden, Lord Godfrey +
the reworked Silverlaine and Springvale), downported onto **its own map id 825**.

**Classic Shadowfang Keep on map 33 is not modified by any file here.** That was the whole
reason for the separate map: Cata SFK reuses two stock creature entries — **3887** Baron
Silverlaine and **4278** Commander Springvale — that classic SFK also spawns and drives
with SmartAI. Binding Cata scripts to those rows would have changed classic SFK. Every
entry is offset instead, and every statement in this directory is scoped to map 825 or to
an id band verified empty first.

## Locked IDs

| Asset | Value |
|---|---|
| Map | **825**, Directory `Shadowfang` (shared with map 33 — **no new client art, no extractor run**) |
| MapDifficulty | **9352** normal / **9353** heroic / **9354** mythic |
| AreaTable | *none allocated* — see "Why there is no AreaTable row" |
| AreaTrigger | **6960** entrance (map 751) / **6961** exit (map 825) |
| LoadingScreen | 204 (map 33's, reused) |
| instance_template script | `instance_sfk_cata` |
| dungeon_access_template | **158** / **159** / **160** |
| game_tele | **10667** `dcsfk` (stock 833 `SFK` → map 33 is left alone) |
| creature_template + creature_equip_template | **+5,000,000** |
| gameobject_template | dense from **5,400,000** (43 entries) |
| waypoint_data | dense from **5,200,000** (23 paths, 311 points) |
| creature spawn guids | **16,730,000** + 0..504 (dense) |
| gameobject spawn guids | **16,510,000** + 0..189 (dense) |

## Apply order

| # | File | What it does |
|---|---|---|
| 01 | `01_sfk_cata_spells.sql` | 56 Cata spells → `spell_dbc` **(already applied)** |
| 01b | `01b_sfk_cata_aura_spells.sql` | 2 cosmetic auras the addon layer needs (88198 Disease Cloud, 57718 Harpoon Loot Sparkles) |
| 01c | `01c_sfk_ashbury_missing_spells.sql` | **4 spells the original extraction missed** — see below |
| 01d | `01d_sfk_smartai_spells.sql` | **21 spells the SmartAI trash casts**, absent from the server Spell.dbc |
| 02 | `02_map825_registration.sql` | `instance_template`, `dungeon_access_template`, `game_tele` |
| 03 | `03_templates.sql` | 97 creature_template + 43 gameobject_template (dense) + equip |
| 04 | `04_spawns.sql` | 505 creature + 190 gameobject spawns, dense guid remap |
| 05 | `05_spawn_support.sql` | 249 creature_addon + 20 gameobject_addon + 81 formations + 311 waypoints |
| 06 | `06_scriptnames.sql` | the ScriptName / spell_script_names bindings |
| 07 | `07_creature_text_and_extras.sql` | **86 creature_text** + 1 spellclick + 2 summon groups |
| 08 | `08_smartai.sql` | 42 smart_scripts rows across 20 trash entries |
| 09 | `09_quests.sql` | the 8 quests → band **90100-90107**, levels left at Cata values |
| 10 | `10_entrance.sql` | the walk-in door: AreaTrigger 6960 in / 6961 out |
| 11 | `11_creature_models.sql` | **the display layer — without it the instance is EMPTY** |

Outside SQL:

1. **Map.dbc + MapDifficulty.dbc — DONE.** `add_sfk825_dbc_rows.py --apply` added map 825
   and MapDifficulty 9352/9353/9354 (ID-set diff: 0 rows lost, only the intended 4 added);
   both compiled with `csv2wdbc.py`, round-trip verified (825 present, stock 33 unchanged),
   written to `patch-4.MPQ` (byte-identical verify) and synced to all three WarcraftXLHost
   candidate dirs. **Still to do: copy `Custom/DBCs/Map.dbc` + `MapDifficulty.dbc` to the
   Linux server's `data/dbc`** — without the Map.dbc row the server asserts in
   `MapMgr::CreateBaseMap` the first time anyone enters.
2. **Server terrain — NOT DONE.** `clone_map33_files_to_825.sh <server>/data --apply`
   (64 files: 25 `.map`, 1 `.vmtree`, 12 `.vmtile`, 1 `.mmap`, 25 `.mmtile`). Pure
   rename-copy; the map id lives only in the filename.
   Note `K:/Dark-Chaos/Server/data` is **not** the live server data dir — it has map 33 but
   no 750/751/2921 at all, so it is a stale partial extract. Point the script at the real one.
3. **Client Spell.dbc — DONE.** 26 spells (21 SmartAI + 4 Ashbury + Disease Cloud)
   appended to the 234-field fork `Spell.dbc` with `spell-dbc-append.py`, verified against
   the previous file (54027 → 54053 rows, **0 removed, 0 pre-existing rows altered**, all
   26 carrying real names), then written to `patch-4.MPQ` and synced to the three candidate
   dirs. Backup at `Custom/DBCs/Spell.dbc.pre-sfk825.bak`.
   `build_sfk_spell_csv.py` produced the 232-column CSV offline, reconstructing the rows
   from 01b/01c/01d plus the table defaults (every numeric column defaults to 0, every
   string to NULL — checked, so the reconstruction is exact). `export_sfk_spells_to_spell_csv.py`
   does the same from the live DB and is the cross-check if you ever have DB access.
   57718 was excluded: already in the fork Spell.dbc under the same name.

   **`Custom/CSV DBC/Spell.csv` was updated too** (`--sync-spell-csv`). It is the source of
   truth for this table and was *exactly* in sync with Spell.dbc at 54,027 ids before this
   import — appending to the .dbc alone would have silently made the CSV the stale copy.
   Both now hold 54,053 ids and the id sets match. The merge rewrites the file through
   csv.reader/writer rather than appending text, because Spell.csv has fields with embedded
   newlines (descriptions) that a line-append cannot see; verified afterwards by ID-set
   diff — 0 lost, 26 added, 0 pre-existing rows altered, header and dialect unchanged.
   Backup: `Spell.csv.bak` alongside `Spell.dbc.pre-sfk825.bak`.

   Watch this whenever you add spells: a `.dbc`-only append leaves the pair divergent, and
   nothing warns you.
   **Never run `csv2wdbc.py` on Spell.dbc** — it is a 234-field fork layout and csv2wdbc
   would rewrite it as 168 and destroy it.
4. **Entrance — client side DONE.** AreaTrigger.dbc rows 6960/6961 compiled and deployed
   (round-trip verified; stock 145/194 unchanged). Apply `10_entrance.sql` for the server half.
5. A worldserver carrying `src/server/scripts/DC/ShadowfangKeepCata` — **already built**.

Between the rebuild and step 06 the worldserver logs `Script named '…' is not assigned in
the database.` once per script at boot. That is expected, not an error.

## The four spells the first pass missed

Ashbury's two signature abilities are declared as macros rather than `enum Spells` members:

```cpp
#define SPELL_STAY_OF_EXECUTION  DUNGEON_MODE<uint32>(93468, 93705)
#define SPELL_PAIN_AND_SUFFERING DUNGEON_MODE<uint32>(93581, 93712)
```

so the id sweep that produced `01_sfk_cata_spells.sql` never saw them and all four were
absent from `spell_dbc`. Found by sweeping *every* numeric literal in the ported C++
against the table rather than checking the ids the script names implied. `01c` supplies
them. The same sweep is what confirmed the other 65 ids resolve — 10 of which are stock
3.3.5 spells that live in `Spell.dbc` and are legitimately absent from the `spell_dbc`
overlay (7038-7042, 7054, 7074, 23224, 61401, 67803), not gaps.

Related: the spell-script bindings in `06` were read back out of each script's
`Validate()`/`Register()` body, because several do **not** match what the script name
suggests — `spell_sfk_forsaken_ability` is stock **7054**, not a 93xxx id, and
`spell_ashbury_pain_and_suffering` binds the aura (93581/93712), not the dummy it casts
(93605).

## Why there is no AreaTable row

Every other DC clone map (820, 823, 824) allocated one, but for this one it would be inert.
Map 825 shares map 33's terrain files and its WMO, and both area lookups derive from those:
the GridMap area bytes baked into the `.map` files, and `WMOAreaTable` for interiors —
which has **no map column at all**. Both keep returning stock area **209 "Shadowfang Keep"**
regardless of what `ContinentID` a new row claims. 209 is also the name we want here.

To get a genuinely distinct zone name the WMO has to be cloned under a new `wmoID`, the way
Naxxramas 533 → 2921 was done. Worth re-checking whether BFD's AreaTable **16103** is
actually reachable in game or inert for exactly this reason.

## Deliberately not done

- **Loot.** `lootid` / `pickpocketloot` / `skinloot` are zeroed, per "everything except
  quest items can be skipped and scaled up later". Zeroing beats pointing at a loot
  template that does not exist, which logs a warning per kill.
- **`creature_template_movement`.** `movementId` is zeroed for the 10 entries that had one:
  cata_world's copy of that table is missing 5 of AC's 8 columns (Ground, Swim, Flight,
  Rooted, Chase), so it is not safe to copy blind.
- **Level re-tune.** Spawns import at their Cata levels (1..85) and
  `dungeon_access_template` carries placeholder gates (80 / 85 / 85). Pick a band.

## SmartAI — the deferral was wrong, and `08` lands it

The first pass deferred `smart_scripts` on the grounds that this fork puts SmartAI range
parameters in `event_param5/6`, so a blind copy would be unsafe. Checking the actual rows
disproved it:

```
rows with event_param5 <> 0 ............ 0
```

Not one of the 50 rows uses it — every event is a timer, a lifecycle hook, or a data/link
trigger. Every opcode was then checked against `SmartScriptMgr.h` and all 9 event types,
7 action types and 7 target types exist here with the **same numeric values**. The two
columns cata_world lacks (`event_param6`, `target_param4`) are unused and fall to defaults.

What the pass *did* find: the 50 rows cast 40 distinct spells, and **21 were missing from
the server's `Spell.dbc`** — those casts would have silently failed. `01d` supplies them.

Two entries are excluded, both deliberately:

- **3887 Baron Silverlaine** — 06 binds the C++ boss and clears `AIName`, so its one
  SmartAI row would be dead weight. (The classic-era trash 3873/3877 are *not* excluded:
  the Cata adds are separate entries 50615/50613, which is what 06 binds.)
- **23837 "ELM General Purpose Bunny"** — a generic world trigger that happens to be
  spawned here. Its 7 rows are global content referencing Alystros the Verdant Keeper
  (27249) and "You Reap What You Sow", none of which exist in this instance.

50 − 1 − 7 = **42 rows across 20 entries**. `08` also clears `AIName` on anything left
without scripts, so the boot log stays clean.

## Quests — cloned to 90100-90107, levels deliberately untouched

Two 4-quest chains, one per faction, linked through `quest_template_addon.PrevQuestID`:

| new | source | title | objective |
|---|---|---|---|
| 90100 | 27917 | Sniffing Them Out | Baron Ashbury |
| 90101 | 27920 | Armored to the Teeth | Silverlaine + Springvale |
| 90102 | 27921 | Fighting Tooth and Claw | Lord Walden |
| 90103 | 27968 | Fury of the Pack | Lord Godfrey |
| 90104 | 27974 | This Land is Our Land | Baron Ashbury |
| 90105 | 27988 | Plague…Plague Everywhere! | Silverlaine + Springvale |
| 90106 | 27996 | Orders Are For the Living | Lord Walden |
| 90107 | 27998 | Sweet, Merciless Revenge | Lord Godfrey |

Alliance chain from Packleader Ivar Bloodfang (47006), Horde from 47293 — both spawned
inside (6 each) and both remapped into the clone band. Every objective is an NPC kill and
**none of the eight has an item objective**, so the deferred loot layer does not block them.

Carried across: `quest_template` (101 shared columns of 105), `quest_template_addon`,
`quest_offer_reward`, `quest_request_items`, the giver bindings, and 18 + 18 POI rows
(`MapID` rewritten to 825; `WorldMapAreaID` 764 kept, since 825 reports map 33's area).

The `quest_template` column list is **generated at runtime from `information_schema`**
rather than typed out — transcribing 101 names by hand is how you get a silent one-column
shift, and this way the statement survives future schema drift on either side.

### Levels are still Cata — that is the deferred half

`QuestLevel` 18-21, `MinLevel` 16, exactly as shipped. They are meant to be re-leveled in
the general rescaling pass, alongside the creature levels (still Cata 1-85) and
`dungeon_access_template`'s placeholder gates (80/85/85). Everything that needs touching
then is in one place per quest:

```sql
UPDATE quest_template SET QuestLevel = -1, MinLevel = <gate>,
       RewardXPDifficulty = <n>, RewardMoney = <n>
WHERE ID BETWEEN 90100 AND 90107;
```

`QuestLevel -1` means "scale to player" on this fork. The BFD-820 clone is the worked
precedent (`QuestLevel -1` + `MinLevel 90` + a token reward in the first free slot).

**One thing to decide at that point:** `AllowableRaces` is one of the four columns
cata_world does not have, so it defaults to 0 = every race. Faction separation currently
rests entirely on the givers' factions (47006 is 2173, 47293 is 68), which is how it
behaves in practice — but both givers stand in the same instance with no phasing on 3.3.5,
so both chains are visible to everyone even though only one is takeable. Set
`AllowableRaces` explicitly if that matters. Note the custom worgen/goblin playable races
mean a hand-written Alliance/Horde mask would exclude them unless it accounts for both.


## The display layer — why the dungeon came up empty

First live test: both normal and heroic completely unpopulated. Errors.log, once per
spawn attempt:

```
Creature (Entry: 5023837) has no model defined in table `creature_template_model`,
can't load.
```

AzerothCore does not read the display id off `creature_template` — it lives in a separate
`creature_template_model` table, and **ObjectMgr refuses to load a creature that has no
row there**. `03_templates.sql` imported the templates and never the models, so all 505
spawns failed at load. Nothing about the spawn data was wrong, which is why every other
check passed: spawnMask, phaseMask, pooling, positions, `instance_template` all clean.

A creature display needs three layers here, and only two are SQL:

| layer | table / file | status |
|---|---|---|
| 1 | `creature_template_model` — CreatureID → DisplayID | `11` supplies it (152 rows, all 97 entries) |
| 2 | `creature_model_info` — DisplayID → bounding box | `11` supplies the 44 missing |
| 3 | `CreatureDisplayInfo.dbc` — DisplayID → the model | **44 still missing, art job** |

76 distinct display ids are used. 32 already exist — stock 3.3.5 creatures the Cataclysm
revamp reused. The other 44 are Cata-only and were absent from *both* `creature_model_info`
and the client DBC. After `11`, everything **loads**; the 32 stock-display creatures render
normally and the 44 Cata-only ones spawn, fight and are targetable but stay **invisible**
until layer 3 is downported:

```
30054 30056 30057 30210 30211 30212 33986 33987 33988 33989 34162 34610 34611 34612
34713 34714 34728 35574 35868 36256 36329 36374 36837 36848 36849 36850 36851 37287
37288 37289 37290 37291 37292 37294 37296 37297 37298 37299 37300 37301 37302 37358
37373 37374
```

`creature_model_info` is keyed on the GLOBAL DisplayID, so `11` uses `INSERT IGNORE` — a
blanket DELETE+INSERT there would reach outside this dungeon and rewrite stock creatures
that share a display.

### Layer 3, part 1 — 12 of the 44 are DONE (no art needed)

`downport_sfk_displays.py` added the **12 displays whose `ExtendedDisplayInfoID` is 0** —
plain creature models with no character customisation. They needed no art at all: all 13
models the 44 displays reference already exist in this client, and the three Mastiff
displays were re-pointed from Cata's model 3190 to **501054**, the id an earlier DC
retroport already registered for `CREATURE\MASTIFF\MASTIFF.M2` (in patch-H.MPQ). Texture
variations spot-checked present.

Cataclysm's CreatureDisplayInfo has 17 fields to 3.3.5's 16 — it inserted
`PortraitCreatureDisplayInfoID` after `PortraitTextureName`. The script drops field 10 and
**verifies that mapping at runtime** against 400 displays present in both clients (400/400
agreement on ModelID/Scale/Alpha) rather than trusting it; it refuses to write below 90%.
CreatureDisplayInfo.dbc compiled, round-trip verified, deployed to patch-4 and all three
candidate dirs. ID-set diff: 0 lost, 12 added, 0 pre-existing rows altered.

### Layer 3, part 2 - the 32 character-based displays are DONE

`downport_sfk_char_displays.py` finished the set. All 44 displays now resolve end to end
(verified: 44 checked, **0 broken links** across CreatureDisplayInfo -> CreatureModelData
-> CreatureDisplayInfoExtra -> bake).

These are Human / Scourge / Worgen bodies driven by a `CreatureDisplayInfoExtra` row plus a
**baked composite body texture**. The bake is what makes them tractable: it is a
pre-composited skin+armour sheet, so the NPC renders correctly even when individual gear
pieces do not resolve.

* **31 bake textures** extracted from the Cata client `art.MPQ` and deployed to
  **patch-7.MPQ** - the archive `dc_mpq_layout.dest_for()` routes baked NPC textures to.
  31/31 written, byte-identical verify; all 32 referenced bakes confirmed present in the
  live client afterwards. BLP2/DXT with `hasMips = 1`, not the `2` that renders green.
* **31 CreatureDisplayInfoExtra rows** + **32 CreatureDisplayInfo rows** added. The Extra
  table is a straight 21 -> 21 field copy (unlike CreatureDisplayInfo 17 -> 16), verified
  at runtime against 400 rows present in both clients - 98.8% agreement.
* **Gear: 163 of 217 slots resolve; 54 were Cata-only and are ZEROED** rather than left
  dangling, so the client is never asked for an ItemDisplayInfo id that does not exist.
  Those 54 cost a 3D attachment - a weapon, shoulder or helm - not the NPC.

Every boss now has a model: Baron Ashbury, Baron Silverlaine, Commander Springvale,
Lord Walden, Lord Godfrey, plus the Tormented Officers and Wailing Guardsmen.

**Client restart required** - WarcraftXLHost reads these DBCs off disk at process start.

## Two remaps, and why gameobject_template is not a flat offset

`creature_template` uses a flat **+5,000,000**. That is safe *because it was checked*: the
full import set tops out at source entry 53,488, so every row lands inside the single
5.0M-5.1M band that was verified empty.

`gameobject_template` cannot work that way. Its 43 entries span **18,895..208,524**, so a
flat +5,100,000 scatters them from 5,118,895 to 5,308,524 — across three 100k bands, only
the first of which was verified. It collided on the first run with DC's own **5,301,906
"Rocket Delivery System"** (25 live rows sit in 5.2M-5.4M), and because the companion
`DELETE` was scoped to 5.1M-5.2M it could not even clean up after itself on a retry.

Both GO tables are therefore **densely remapped** through a kept mapping table, the same
way spawn guids are: 43 source entries become 43 consecutive ids from 5,400,000, and the
width of the source range stops mattering. Verified that no `gameobject_template.Data*`
slot points at another map-33 GO entry and that no imported SmartAI row uses
`SMART_ACTION_SUMMON_GO`, so there are no GO-entry cross-references left to rewrite.

**The general lesson for the next clone:** verify the band against
`MAX(source_entry) + offset`, not against the offset alone.

## Schema drift, and why every column is listed explicitly

`cata_world` and `acore_world` disagree on both the column *set* and the column *order*:
`creature.phaseMask` is ordinal 7 in acore and 8 in cata; `creature.equipment_id` is 8 vs
13. `SELECT *` or any positional insert would silently scramble every row. Verified per
table before writing the import:

| table | verdict |
|---|---|
| `gameobject_template`, `creature_equip_template`, `gameobject_addon`, `waypoint_data` | clean 1:1 |
| `creature` | 3 acore columns absent upstream (dynamicflags, CreateObject, Comment) → defaults |
| `creature_template` | 6 absent (exp, speed_swim, speed_flight, detection_range, dynamicflags, CreatureImmunitiesId) → defaults |
| `creature_addon` | **real translation** — Cata split the packed byte fields; `bytes1`/`bytes2` are re-packed in 05 |
| `creature_formations` | column *renames* (FollowDistance→dist, InversionPoint1→point_1, …) |
| `smart_scripts` | 2 absent (event_param6, target_param4) — deferred anyway, see above |

## Creature addon auras

225 of the 249 addons carry an aura, across only 4 distinct spells. All four now resolve —
which matters, because importing an aura whose spell does not exist is what makes NPCs
vanish or spam the log:

| spell | uses | status |
|---|---|---|
| 88198 Disease Cloud | 200 | downported in **01b** — dummy aura, visual only |
| 29266 Permanent Feign Death | 12 | already present |
| 58506 Stealth | 11 | already present |
| 57718 Harpoon Loot Sparkles | 2 | downported in **01b** — dummy aura, visual only |

`05` re-checks all of them in its report block. Run **01b before 05**.

## Guid pressure — worth knowing

AzerothCore hard-caps spawn ids at `0xFFFFFF` (16,777,215) in `ObjectMgr.cpp:7669/7679`,
and live `MAX(creature.guid)` was already 16,721,765 before this import, leaving roughly
**55,000 creature guids in total** on this fork. This import takes 505 of them. The source
guids span 248,826 for those 505 rows, which is why they are renumbered densely rather
than offset — a flat offset would have needed five times the entire remaining space.

Never insert into `creature` or `gameobject` without an explicit guid here: the
AUTO_INCREMENT counters sit above `0xFFFFFF` and a guid-less INSERT bricks startup with
TCE00007.

## Helper tables

`03`–`05` create `dc_sfk825_ct_set`, `dc_sfk825_cguid`, `dc_sfk825_gguid` and
`dc_sfk825_wpmap`. They are kept rather than TEMPORARY so later steps can join them and so
a clone guid can be traced back to its `cata_world` source during debugging. Safe to drop
once everything verifies.
