# Timbermaw Hold (map 819) — 20-man raid

Turtle WoW custom raid, taken from the already-upported 3.3.5 asset pack at
`K:\UntouchedClients\twow upport\` (`patch-4.MPQ` assets + `patch-5.MPQ` DBCs).

**No conversion was needed.** Unlike Hyjal Frontier / Deepholm / Karazhan Crypts, this pack was
already upported by whoever built it: every file verifies as a native 3.3.5 format —
WMO `MVER 17`, ADT/WDT/WDL `MVER 18`, M2 `v264`, textures `BLP2`. Nothing went through
`downport-map.js` or the `wxl-baker` pipeline.

The source client `K:\UntouchedClients\twmoa_1180` does **not** contain this dungeon — it has no
`World\Maps\Timbermaw\`, no Timbermaw row in either of its `Map.dbc` copies, and only a single
`timbermaw_exterior_closedgate` gate prop. The upport pack is the only source.

## Locked IDs

| Asset | Value | Where |
|---|---|---|
| Map ID | **819** | `Custom/CSV DBC/Map.csv`, Directory `Timbermaw`, InstanceType 2 (raid), MaxPlayers 20 — cloned from Zul'Gurub (309), the only stock 20-man raid |
| AreaTable ID | **5640** "Timbermaw Hold" + **5641** "Windhorn Canyon" | the ids the map's own ADT chunks reference — see the area-id trap below |
| WorldMapArea ID | **1263** | `Custom/CSV DBC/WorldMapArea.csv`, AreaName `Timbermaw`, AreaID 5640 |
| LoadingScreens ID | **640** | `LoadScreenTimbermaw.blp` |
| MapDifficulty ID | **9340** | difficulty 0, `RAID_DIFFICULTY_20PLAYER`, 3-day lockout |
| AreaTrigger IDs | **6923** (entrance, map 750) / **6924** (exit, map 819) | next free after Karazhan Crypts' 6921/6922 |
| game_tele IDs | **10643** `dctimbermaw` (live id, added in game) / **10641** `dctimbermawgate` | 10633-10639 are reserved by the pending map-750 round-51 batch |
| dungeon_access_template ID | **146** | `id` is tinyint — live max was 145 |

## Geometry (derived from the assets, not guessed)

The whole raid is one WMO — `timbermaw_instance.wmo`, 20 groups, 21 portals, 4150 doodad
instances — placed at MODF `(20519.94, 218.81, 25177.63)` with zero rotation on all 9 ADTs
(tiles 37-39 × 45-47). That resolves to a WMO origin in server coordinates of
**X -8110.960, Y -3453.271, Z 218.810**, with a footprint of X -8190…-7237, Y -3969…-2992.

Group names map the raid out, and name the final boss:

| Wing | Groups |
|---|---|
| Entrance | `DungeonEntryHall`, `EntranceMeetingRoom02`, `DungeonBackdoorEntrance`, `DungeonLeftCorner` |
| Furbolg village | `Village01/02`, `VillagePassage`, `VillageInteriorA/B`, `VillageSkyCeiling` |
| Corruption wing | `CorruptionWIngEntrance`, `Corruption01_Lower/Upper`, `Corruption02`, `SatyrRoom` |
| Final | `UrsocRoomPath01/02`, **`UrsocRoom`** |

## Already done

* **Client assets deployed.** 142 files routed through `dc_mpq_deploy.py` (never pick a patch
  letter by hand) → patch-4 (80: terrain + minimaps + `md5translate.trs`), patch-5 (13: world-map
  art + loading screen), patch-6 (3), patch-8 (2), patch-9 (44: the WMOs). Staging tree kept at
  `Custom/TimbermawHold/clientstage/`, manifest at `Custom/TimbermawHold/tm_manifest.txt`.
* **Dependency closure verified complete.** Walking ADT → WMO → M2 → BLP against a
  595,767-path inventory of our own client left **0 unresolved references**. Only 5 assets beyond
  the map/WMO set were actually missing from our client (`timbermawbear.blp`,
  `timbermawblob.blp`, `timberwaterfall.blp`, `timbermawwaterfall.m2` + its skin) — the dungeon
  otherwise reuses stock Timbermaw/Maraudon/Wailing Caverns tilesets we already ship.
* **DBC rows added and compiled.** `Custom/TimbermawHold/add_timbermaw_dbc_rows.py` (idempotent,
  writes `.pre-timbermaw.bak`) then `csv2wdbc.py` for the six changed tables. ID-set diff against
  the previous `.dbc` shows **0 rows lost** and exactly the intended additions in each.
* **Deployed to patch-4 and all three WarcraftXLHost candidate dirs** (`mpq_stormlib_patch.py`
  verify pass 6/6 byte-identical, then `sync-dbc-deploy.js`).
* **Minimap `md5translate.trs`** gained a 68-row `dir: WMO\Dungeon\KL_TimbermawDungeon` block
  (dir line 31 chars, under the 39-char limit). The append is idempotent.

## The area-id trap (cost a log flood)

The worldserver spammed `Player ... discovered unknown area (... map: 819)` once per movement
packet. `Player::CheckAreaExploreAndOutdoor()` reads the area id baked into the terrain and
looks it up in AreaTable.dbc; a miss logs that line and returns.

**A custom map does not get to choose its own area id — the ADTs already did.** Map 819's
chunks reference **5640** (2,303 of 2,304) and **5641** (1). The first pass invented a fresh
area 16102 and pointed Map.dbc at it, but nothing in the terrain ever asks for 16102, so every
lookup missed. Fixed by `Custom/TimbermawHold/fix_timbermaw_area_ids.py`: create 5640/5641,
repoint Map.dbc and WorldMapArea at 5640, delete 16102.

Two details worth keeping:

* **Do not copy the source `AreaBit`.** Cata's 1567 / 1535 are already held here by The
  Scalding Pools (3947) and Goldenbough Pass (3912) — reusing them marks those Outland zones
  explored whenever anyone walks through Timbermaw. Free bits 3000 / 3001 are used instead,
  both under the 4096 ceiling `PLAYER_EXPLORED_ZONES_SIZE * 32` imposes.
* 5641 is "Windhorn Canyon", which in the source belongs to *Turtle's* map 820 — unrelated to
  our Blackfathom clone that happens to share that number. It is imported with ContinentID 819
  because in our deployment that one chunk is part of the Timbermaw map.

`WMOAreaTable` has **no rows** for the Timbermaw WMOs (7078 / 7079), so the interior does not
override the area — 5640 governs the whole map, inside and out.

To check any future custom map before deploying it: parse the MCNK header at +0x34 in each
ADT and confirm every distinct area id exists in AreaTable.

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

## Still to do

1. **Apply the SQL** in this folder, in order: `01` instance_template, `02` game_tele,
   `03` areatrigger_teleport, `04` dungeon_access.
2. **Deploy the six DBCs to the server** — copy `Custom/DBCs/{Map,AreaTable,WorldMapArea,
   LoadingScreens,MapDifficulty,AreaTrigger}.dbc` to the worldserver's `data/dbc`. Without the
   Map.dbc row the server asserts in `MapMgr::CreateBaseMap` the moment anyone zones in.
3. **Run the extractors** against the deployed client `Data/` tree:
   `mapextractor` → `maps/819_37_45.map` … `819_39_47.map` (9 files),
   `vmap4extractor` + `vmap4assembler` → `vmaps/819*`, `mmaps_generator` → `mmaps/819*`.
   The WDT is a normal 9-tile ADT map (`MPHD` flags `0x0A`, no global-WMO bit), so the standard
   invocation works. **vmaps matter most here** — the entire raid is WMO interior, so without
   them there is no floor and no walls.
4. **Restart** the worldserver and the client (WarcraftXLHost rereads DBCs off disk at start).
5. Anchor points:
   * **player arrival — MEASURED, confirmed working both ways.** `-8153.15, -3456.87, 222.4`
     o `0.306` on 819. Used by areatrigger 6923 and by the Timbermaw Gatekeeper's gossip.
     My earlier value (`-8165.96, -3459.75, 221.0`, derived from WMO group 1
     `EntranceMeetingRoom02` whose bbox floor reads 219.5) was **below the floor** and dropped
     players through it. GroundZ here is 42.4 and FloorZ is 222.36 — the raid is WMO interior
     suspended ~180 yd above the terrain, so no Z inferred from terrain or a group bbox is
     usable. Only `.gps` inside the WMO is.
   * GM shortcut `.tele dctimbermaw` (game_tele 10643) → `-7902.56, -3434.49, 250.701`. Added
     in game; deliberately a different spot from the arrival point above.
   * world gate `.tele dctimbermawgate` → `7015.0, -2145.0, 587.0` on map 750. Still derived
     (mean ground height of the 31 spawns already in that camp, 565.55–617.58, mean 587.44) —
     `.gps` it if anyone lands badly.

## Open design decisions

* **The raid is an empty shell.** The upport pack is client assets only — no world DB. There are
  currently **zero creature and gameobject spawns on map 819**, so once the extractors run it is a
  walkable, correctly-lit, correctly-collided raid with nothing in it. Trash, bosses, loot and
  quests all still have to be authored. `UrsocRoom` is the obvious final-boss arena and the wing
  layout above is a ready-made encounter outline.
* **20-man raid vs 5-man dungeon.** Kept as the source authored it (InstanceType 2, MaxPlayers 20).
  Converting to a 5-man is a two-field change: `Map.csv` InstanceType 2→1 / MaxPlayers 20→5, and
  `MapDifficulty.csv` row 9340 → `MaxPlayers` 5, `Difficultystring` `DUNGEON_DIFFICULTY_5PLAYER`,
  `RaidDuration` 0. That would also make it eligible for `dc_dungeon_setup` /
  `dc_dungeon_mythic_profile` / `dc_mplus_dungeons`, which only carry 5-man content today.
* **min_level 110** in `04_dungeon_access.sql` is a tuning choice, placing it just above the
  Winterspring band (104-115) — Timbermaw Hold physically sits on the Felwood/Winterspring border
  on map 750. Change freely.
* **The exterior gate WMO is shipped but not placed.** The source design put
  `timbermaw_exterior.wmo` in Azshara (its group names say so: `AzsharaEntranceGate_Exterior`,
  `AzsharaExitPassage01-03`). We use the real Timbermaw Hold camp on map 750 instead, which is
  already populated with the correct furbolgs (Gorn One Eye 3711555, Kernda 3711558,
  Meilosh 3711557, Salfa 3711556, Timbermaw Mystic 3711552). The exterior WMO plus its
  closed-gate variant are on disk if you later want a proper gate structure there.
* **`Interface\WorldMap\TimbermawEntrance\` and `TimbermawTunnels\`** art (12 tiles each) exists
  in the upport pack but was deliberately **not** shipped. Both would need WorldMapArea rows on
  map 1, and a second WMA row for an AreaID that already has one breaks the zone client-side
  three ways (duplicate dropdown entries, dead fog-of-war, vanished POIs).

## Traps worth remembering

* World-map `Loc` bounds in WorldMapArea row 1263 are the **source pack's own values**
  (-2991 / -4416 / -7195 / -8157), not the WMO bounding box I derived (-2992 / -3969 / -7237 /
  -8191). The `Timbermaw1-12.blp` tiles were painted against the former; bounds must travel with
  the art or the player arrow and every POI misplace.
* WMO local space is **Z-up** while MODF placement is **Y-up**. With rotation 0 the mapping is
  `serverX = 17066.667 - (modf.Z + local.X)`, `serverY = 17066.667 - (modf.X + local.Y)`,
  `serverZ = modf.Y + local.Z`. Getting this wrong puts the entrance a few hundred yards into rock.
* WMO `MODN` doodad blocks still spell filenames `.mdx`; the files on disk are `.m2`. Any
  dependency walker must rewrite the extension *before* the "do we already have it?" lookup, or it
  reports ~111 phantom missing assets.
