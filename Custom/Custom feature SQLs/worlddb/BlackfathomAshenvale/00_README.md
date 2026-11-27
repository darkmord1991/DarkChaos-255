# Blackfathom Deeps (Ashenvale) — map 820

A full clone of map 48 re-tuned for the map-750 Ashenvale band, with the Cataclysm NPC layer
that AzerothCore never imported. **Map 48 is never touched** — the original 20-24 dungeon
keeps working for low-level characters.

The clone shares map 48's `Blackfathom` terrain directory, so there is **no new client art
and no extractor run**: two Map.dbc rows may point at one directory (precedent: maps
1411/1412 both use `HinterlandBGTest`), and the server-side files are a rename-copy.

## Levels

| Difficulty | Creature levels | How |
|---|---|---|
| Normal | **92-96** | baked into the cloned templates by `01` (`+72` on the source's 20-24) |
| Heroic | **129** (Lorgus Jett 130) | `dc_dungeon_mythic_profile.heroic_level_*` |
| Mythic / M+ | **130** | `dc_dungeon_mythic_profile.mythic_level_*` |

Ashenvale on map 750 is an 88-98 zone, so a 92-96 dungeon sits near the top of the band
without exceeding it. Heroic and Mythic land on the 130 cap as intended.

`MythicDifficultyScaling::CalculateCreatureLevel` picks the column by **rank**: rank 3/2 →
`*_level_boss`, rank 1 → `*_level_elite`, else `*_level_normal`. BFD follows AzerothCore's
convention where 5-man bosses are plain **rank 1**, identical to their trash (only Lorgus
Jett is rank 2), so heroic sends nearly everything to 129 and mythic to 130. Ranks were
deliberately **not** raised to 3 — that would also swap in the world-boss HP/damage rate
multipliers and flag them as world bosses.

Health and damage come from `creature_classlevelstats`, which covers levels 1-255 here, so
the level change alone rescales every stat. The profile multipliers are therefore modest
(**1.35 / 1.2**, matching the WotLK dungeons) — the vanilla dungeons' 3.0/2.0 exists to
compensate for a 24→80 jump applied to level-24 base stats, and stacking that on top of a
+34 level jump would be brutal.

## Locked IDs

| Asset | Value |
|---|---|
| Map | **820**, Directory `Blackfathom`, InstanceType 1, MaxPlayers 5 |
| AreaTable | **16103** "Blackfathom Deeps (92-96)" |
| WorldMapArea | **1264** |
| MapDifficulty | **9341** normal / **9342** heroic / **9343** mythic |
| LoadingScreen | 196 (map 48's, reused) |
| AreaTrigger | **6925** entrance (map 750) / **6926** exit (map 820) |
| game_tele | **10644** `dcbfd` (live id; map 750 cave mouth, measured in game) |
| dungeon_access_template | **147** / **148** / **149** |
| creature_template + creature_loot_template | **+3,900,000** |
| gameobject_template + gameobject_loot_template | **+4,400,000** |
| spawn guids, gameobject | **16,340,000** + 0..49 (dense) |
| spawn guids, creature | **16,620,000** + 0..211 (dense) |
| spawn guids, Cata layer | **16,621,000** + 0..30 (dense) |
| level offset | **+72**, clamped to 96 |

Free-space checked before allocating: `creature_template` and `creature_loot_template` had
**0 rows** in 3.8M-4.2M; `gameobject_template` is occupied through 4.1M so the GO block sits
at 4.4M; creature guid max was 16,614,473 and gameobject guid max 16,331,741.

**Spawn guids are 24-BIT.** `ObjectMgr::GenerateCreatureSpawnId()` and
`GenerateGameObjectSpawnId()` both stop the server at startup once the highest guid reaches
`0xFFFFFF` = **16,777,215**. Template entry ids have no such limit, which makes it easy to
assume guids don't either. They are therefore allocated **densely** (50 + 212 + 31 guids)
rather than by a constant offset -- see the traps section.

## Files

| File | What |
|---|---|
| `01_templates.sql` | creature + gameobject templates, re-levelled |
| `02_support_tables.sql` | models, equip, addons, spells, texts, SmartAI, summon groups |
| `03_spawns.sql` | 212 creature + 50 gameobject spawns onto map 820 |
| `04_loot.sql` | forked loot tables + Ashenvale themed ref 750088 + Upgrade Token |
| `05_cata_npc_layer.sql` | the Cataclysm NPCs (6 new templates, 31 spawns) |
| `06_registration.sql` | instance_template, access gates, entrance/exit, `.tele dcbfd` |
| `07_dc_difficulty.sql` | `dc_dungeon_setup`, mythic profile, M+ registry, entrance |
| `08_quests.sql` | the 11 Blackfathom quests, cloned and re-levelled |
| `apply_all.sql` | sources all eight in order |

Everything is **self-deriving** (source ids read from the live tables at run time) and
**re-runnable**.

## The Cataclysm layer

Our map 48 carries the WotLK population: 212 spawns of 28 entries. Both BFA (HavenCore) and
Shadowlands (DekkCore `world09`) spawn **41 entries** in the same rooms — the extra 13 are
the Cataclysm quest/ambience layer. `05` adds them to the clone:

* **7 already had 3.3.5 templates** and are cloned by `01`: Murkshallow Softshell, Aku'mai
  Servant, Aqua Guardian, Morridune, Je'neu Sancrea, Baron Aquanis, Summon Enabler Stalker.
* **6 exist in no 3.3.5 DB we have** and are built from scratch: Ashelan Northwood, Relwyn
  Shadestar, Sentinel Aluwyn, Sentinel-trainee Issara, Zeya, Flaming Eradicator.
* **4 of those 6 used Cata-only display ids** (28520/28528/28529/28530) — genuinely absent
  from 3.3.5 (28518-28523 and 28527-28530 are all gaps in our table). These have now been
  **downported from the 4.3.4 client**, so the Sentinels wear their real Cata appearance.
  See "Display downport" below.
* Morridune and Baron Aquanis are deliberately **not** statically spawned — the Altar of the
  Deeps and the Fathom Stone summon them, so a static copy would double them up.

## Display downport (the four Cata Sentinels)

`Custom/BlackfathomAshenvale/downport_sentinel_displays.py` pulls three tables out of the
4.3.4 client. Every layout was **verified before any row was copied**, not assumed:

| Table | Cata | Ours | Handling |
|---|---|---|---|
| `CreatureDisplayInfo` | 17 fields | 16 | cross-correlated all fields over 5,114 shared rows — the i→i diagonal wins outright, so Cata's extra column is **appended at index 16** and dropped |
| `CreatureDisplayInfoExtra` | 21 fields | 21 | identical, copied verbatim |
| `ItemDisplayInfo` | 25 fields | 25 | identical, copied verbatim |

Rows added: displays **28520 / 28528 / 28529 / 28530**, extended info **18924 / 18925 /
18930 / 18931**, item displays **57939** (gloves) and **57941** (shirt).

Everything they reference was checked against our data first:

* models **55 / 56** (NightElfMale/Female) already exist in `CreatureModelData`
* 18 of the 20 referenced item displays already existed; the 2 that didn't are copied in, and
  every texture *they* name (`MAIL_B_06BLACK_GLOVE_*`, `Leather_C_02White_*`, …) is already
  in our MPQs — so no art had to be extracted for them
* all 16 `CharSections` lookups (skin / face / hair / facial hair) resolve in 3.3.5
* the 4 baked NPC textures were extracted from Cata's `art.MPQ` (BLP2, DXT, 256×256,
  `hasMips=1`) and deployed to patch-7; 7,012 stock rows already use the same
  `CreatureDisplayExtra-NNNNN.blp` naming, so this matches existing convention
* `05_cata_npc_layer.sql` adds the matching `creature_model_info` rows (0.306 / 1.5, gender
  per sex) — the server half of a display

**The trap that nearly shipped:** `CreatureModelScale` is stored in the CSV as float *text*
("1", "2.5"), not as the raw uint32 from the DBC. Writing the raw word gives a scale around
1e9. The script now derives per-column encoding (string / float / signed) from the CSV's own
existing values rather than guessing, and the four scales verify as 1 / 1.1 / 0.95 / 1
against the Cata source.

## Entrances and exits

Each instance has a **visible gossip NPC at both ends** — one outside to get in, one just
inside to get out. Click, pick the single option, get teleported.

| NPC | Entry | Stands | Sends you to |
|---|---|---|---|
| Blackfathom Gatekeeper | 3999001 | map 750, Zoram Strand ~(4250, 745, -25) | map 820 |
| Blackfathom Warden | 3999003 | map 820, ~7 yd from the arrival | map 750 |
| Timbermaw Gatekeeper | 3999002 | map 750, furbolg camp ~(7004, -2120, 588) | map 819 |
| Timbermaw Warden | 3999004 | map 819, ~7 yd from the arrival | map 750 |

All four live in `Custom/Custom feature SQLs/worlddb/_shared/dungeon_entrance_npcs.sql`.

**The exit AreaTriggers had a teleport loop.** 6924 and 6926 were each centred exactly on
their own instance's arrival point, so arriving put you inside the trigger that sends you back
out. Their `areatrigger_teleport` rows are now deleted, making the boxes inert; the wardens
are the exit. The two ENTRANCE triggers are left working.

**Correction:** custom AreaTriggers *do* fire — 6923 was verified in game. An earlier note
here blamed the old 607000+ ID range (stock stops at 6961). That note was half right: the
range WAS fatal -- the 3.3.5 client keeps areatrigger ids in a 16-BIT table, so anything
above 65535 indexed out of bounds and crashed with ERROR #132 -- but it was not what kept
607004 silent. The whole band was moved to 6921-6930 by
`_shared/renumber_areatrigger_ids.sql`; the ids above are the post-renumber ones.
Blackfathom's entrance
trigger 6925 is still silent for a different, still-open reason: its coordinates come from
map 1's **vanilla** terrain while map 750's Zoram Strand is **Cata** terrain, so the cave mouth
may not be in the same place. The outside NPC makes that moot.

## Quests

`08_quests.sql` clones the 11 real Blackfathom quests into ids **90001-90011**, sets
`QuestLevel = -1` (player-scaled, the convention 234_ used across map 750) with
`MinLevel 90`, and adds **30 Upgrade Tokens** to each — the Ashenvale band rate, dropped into
the first free `RewardItem` slot. Quests 26894 / 26898 are excluded: they are the Dungeon
Finder call-to-arms entries, not content.

Cloning was necessary rather than just attaching the originals. The originals are level 22-27
and quest 6565's kill objective names creature **12902** — the Lorgus Jett on map 48 — so
killing the clone would award no credit.

What did **not** need remapping, checked rather than assumed: ten of the eleven have pure
**item** objectives (5359, 5879, 5881, 5952, 16784, 16790, 16762), and `04_loot.sql` forked
the loot tables with the same `Item` values, so the clone's own mobs already drop every quest
item. Only 6565's `RequiredNpcOrGo` needed the creature offset.

Givers mirror the original layout rather than dumping everything on one NPC:

| NPC | Role |
|---|---|
| **Blackfathom Gatekeeper** 3999001 (outside) | the quests that were handed out in the world |
| **Argent Guard Thaelrid** 3904787 (inside) | ends "In Search of Thaelrid", starts both "Blackfathom Villainy" |
| **Je'neu Sancrea** 3912736 (inside) | the Horde chain — his clone is spawned by `05` |

Letting the gatekeeper end "In Search of Thaelrid" would have allowed completing it without
ever entering the dungeon, so that one stays on Thaelrid.

`1275`'s prerequisite (3765, an Ashenvale quest with no clone) is zeroed — left in place it
would make the clone permanently unobtainable. Faction gating is untouched: `AllowableRaces`
3149 / 946 still splits the Alliance and Horde sets, and the gatekeeper is faction 35 so both
sides can use it.

**Known wart:** item 16790 carries `startquest = 6564` in `item_template`. That column belongs
to a shared item and cannot be repointed without breaking the original dungeon, so looting it
inside the clone also offers the original level-22 quest. Harmless, but it can leave a stray
low-level quest in the log.

## Map markers

Both entrances are marked in **two** layers:

* **Native `AreaPOI`** — rows **2515** (Blackfathom, zone 4931 Ashenvale) and **2516**
  (Timbermaw, zone 4927 Felwood) on continent 750, added by
  `Custom/BlackfathomAshenvale/add_dungeon_map_pois.py`. Icon **7** is not a style choice:
  every stock instance entrance in 3.3.5 uses it (verified against Maraudon 1148, Onyxia's
  Lair 1094, Wailing Caverns 1068). Already compiled and deployed.
* **DC MPOI pins** — new `dungeon` (blue) and `raid` (green) types on the world map *and*
  the minimap, with their own settings checkboxes. Server side in `dc_addon_mappois.cpp`,
  client side in `DC-QOS/Modules/MapPOIData.lua`. **Needs a worldserver rebuild and a
  DC-QOS redeploy.**

The gatekeepers are matched by **exact entry** (3999001 / 3999002) in `kInstanceEntrances`,
not by script name or name text — they run on SmartAI and carry no ScriptName, and the file
already documents why name matching is a trap. Adding a future entrance is one line there
plus one entry in the client registry.

**Why the blue/green pins are addon-only:** 3.3.5 ships no dungeon/raid portal art.
`Interface\Minimap\Dungeon` and `\Raid` do not exist (probed against the locale archive),
and the saturated blue/green cells in `POIIcons` are PvP tower and flag art. The pair is
therefore made by tinting `Spell_Arcane_PortalStormwind`, a path already proven present by
the existing `teleporter` type — an unknown texture path draws nothing and raises no error,
so a guessed icon would be a silently invisible pin.

## Traps this build had to handle

* **Spawn guids are 24-bit and a constant offset blows the budget.** The first version of
  `03` used `source_guid + 16,700,000`. Map 48's gameobject guids are sparse and reach
  268,936, so the clone landed at **16,968,936** — past `0xFFFFFF` (16,777,215) — and the
  worldserver aborted at startup with `TCE00007 GameObject spawn id overflow`. The creature
  side squeaked under the cap but left only 17,185 free creature guids for the whole server.
  A constant offset costs as much guid space as the SOURCE range is *wide*, not as many rows
  as you insert. Guids are now allocated **densely** from a base, with the mapping rebuilt
  identically in `02` and `03` (both derive it from map 48's own spawn table via
  `ROW_NUMBER() OVER (ORDER BY guid)`, so the two files agree without sharing state).
  If you hit this, run `00_HOTFIX_guid_overflow.sql`, then re-apply `02`, `03`, `05`.
* **The instance script is nailed to map 48.** `InstanceMapScript("instance_blackfathom_deeps",
  MAP_BLACKFATHOM_DEEPS)` bakes the map id into the constructor, so the clone can never
  inherit it. `src/server/scripts/DC/BlackfathomAshenvale/instance_bfd_ashenvale.cpp` is a
  port bound to map 820 with the offset ids, registered in `dc_script_loader.cpp`.
  **Worldserver rebuild required** — without it the Portal of Aku'Mai never opens and the
  final boss is unreachable.
* **Four creatures have no spawn row.** 4977/4978 (fire-event adds), 6729 Morridune and
  12876 Baron Aquanis only ever appear as summons. Cloning just the spawned set would leave
  the gate event dragging level-24 originals into a level-96 dungeon.
* **The fire event summons through `creature_summon_groups`**, not through SmartAI params —
  14 rows keyed by gameobject entry, cloned in `02`.
* **Two SmartAI rows target gameobjects by SPAWN GUID** (`target_type` 14: param1 = guid,
  param2 = entry) — guid 32610 → Shrine of Gelihast, 32935 → Altar of the Deeps. Left alone
  they would reach out of the clone and manipulate the *original* dungeon's objects.
* **`action_type` 12 rows carry creature entries** (Altar → Morridune, Fathom Stone → Baron
  Aquanis) and must be offset; `action_type` 34 carries an instance-data *index* and must
  not be.
* BFD's SmartAI was audited first: 65 creature rows, **all `action_type` 11 (cast)**, no
  timed action lists (`source_type` 9). That is why there is no action-list remap here.
* Map 48 has **no `GAMEOBJECT_TYPE_MO_TRANSPORT`**, so the HLBG 1411→1412 clone crash does
  not apply — but `03` filters type 15 anyway so a future edit can't reintroduce it.
* **A clone map with no WorldMapArea row shows whatever map was loaded last** (seen on HLBG
  1412), hence row 1264.
* **`dc_dungeon_mythic_profile` is a FOREIGN KEY parent**, which is not obvious from the
  table names — both `dc_dungeon_setup.map_id` and `dc_dungeon_entrances.dungeon_map`
  reference it `ON DELETE CASCADE` (so does `dc_mplus_featured_dungeons.map_id`). Insert the
  profile row **first** or you get `SQL error 1452`. `07` deletes children→parent and inserts
  parent→children for exactly this reason. `dc_mplus_dungeons` has no FK and is independent.

## Apply order

1. **Client DBCs — already done.** Eight tables in total, all recompiled with **0 rows lost**
   (verified by ID-set diff) and deployed to `patch-4.MPQ` and all three WarcraftXLHost
   candidate dirs:
   * `add_bfd820_dbc_rows.py` → Map 820, AreaTable 16103, WMA 1264, MapDifficulty 9341-9343,
     AreaTrigger 6925-6926
   * `downport_sentinel_displays.py` → CreatureDisplayInfo, CreatureDisplayInfoExtra,
     ItemDisplayInfo (ItemDisplayInfo compiles via `dbc-compile.py`, not `csv2wdbc.py`)
   * 4 baked NPC textures deployed to `patch-7.MPQ` and confirmed readable from the live
     client (the deploy tool's "no new entries" warning was a false alarm — verified with
     `mpq_stormlib_locate.py`)
2. **Apply the SQL**: `mysql -u <user> -p acore_world < apply_all.sql`.
3. **Copy the server terrain**: `Custom/BlackfathomAshenvale/clone_map48_files_to_820.sh
   /path/to/data --apply`. Dry-runs by default. No extractor run needed.
4. **Deploy the five DBCs to the server's `data/dbc`** — without the Map.dbc row the server
   asserts in `MapMgr::CreateBaseMap` on first entry.
5. **Rebuild the worldserver** (new instance script).
6. **Restart** worldserver and client.
7. **Verify with `.gps`**: the two map-750 positions in `06` are provisional —
   entrance trigger 4252.37 / 756.97 / -23.06 (stock trigger 257's own position, so the X/Y
   are right; only Z needs confirming against map 750's terrain) and exit target
   4285 / 775 / -20. The exit is deliberately ~35 yards clear of the entrance trigger's
   12-yard radius; land inside it and the player teleports straight back in forever.

## Tuning knobs

* Band: `@LVL := 72` in `01` (and the `LVL_CAP` used by `05`).
* Heroic/Mythic levels: the six `*_level_*` columns in `07`.
* Difficulty feel: `base_health_mult` / `base_damage_mult` in `07`.
* Gates: `min_level` in `06` (90 / 125 / 130).
* Loot generosity: `ref_chance` and `tok_min`/`tok_max` in `04`'s boss table.
