# Hyjal Frontier (Level 80–130)

Open-world leveling zone running on a **cloned Mount Hyjal raid tileset** as a
new custom continent map. Concept/design lives in
`Custom/feature stuff/Hyjal leveling/EVALUATION_hyjal_zone.md`.

## Locked IDs

| Asset | Range / Value | Notes |
|---|---|---|
| Map ID | **1410** | `Hyjal130` directory, InstanceType=0 (continent), Flags=16 |
| Zone root | **6100** `Hyjal Frontier` | new row in AreaTable.dbc |
| Sub-zones | 6101 Foothills, 6102 Scorched Groves, 6103 Summit, 6104 Nordrassil Roots, 6105 Jaina's Encampment, 6106 Thrall's Vanguard | |
| Sunwell event map | **1408** `Sunwell130` (already registered) | populated later |
| Creature entries | `830000–830999` | 830000–830017 legacy Hyjal Summit reskins, 830020–830024 starter service NPC templates, 830030–830100 zone population + quest chains (including map-534-themed variants; side-quest variants are manual-spawn), 830110–830134 mini-dungeon enemy packs and bosses (manual-spawn) |
| Gameobject entries | `830000–830999` | |
| Item entries | **400000-400999** | `400000` token, `400001-400010` vendor, `400011-400040` quest rewards + elite loot drops, `400041-400124` leveling gear sorted strictly by required level (Foothills through Nordrassil, ilvl 300->398), `400125-400149` mini-dungeon signature rewards + boss loot pools, `400200-400229` endgame PvE signature (ilvl 412), `400230-400324` endgame PvE Ascendant tier-set block (ilvl 412), `400325-400447` endgame PvE ICC gear block (ilvl 412), `400500-400707` endgame PvP Wrathful gear block (ilvl 412) |
| Quest IDs | `81000–81500` | 81200–81223 used by `10_NPCs_Quests.sql`; 81230–81234 used by `11_Mini_Dungeons.sql` |
| Gossip menu IDs | `83000–83099` | |
| Graveyard IDs | `15000–15019` (world_safe_locs) | |
| game_tele IDs | `1495–1510` | |
| areatrigger IDs | `15000–15020` | edge triggers and entry triggers |
| Taxi node IDs | `350–359` | one per hub |
| ScriptName prefix | `npc_hyjal_*` / `go_hyjal_*` | source in `src/server/scripts/DC/HyjalFrontier/` |

## Client side

* ADT folder: `World\Maps\Hyjal130\` (32 files renamed from `HyjalPast_*`).
* DBC rows appended to `Custom/CSV DBC/`:
  * `Map.csv` → `1410 Hyjal130 / Hyjal Frontier`
  * `AreaTable.csv` → rows `6100–6106`
  * `WorldMapArea.csv` → row `1202`
  * `LoadingScreens.csv` → reuses id `212` (HyjalPast loading screen)
* Still to do once terrain edits are final:
  * Re-run the DBC exporter to regenerate the binary `.dbc` files.
  * Re-run the map/vmap/mmap extractors against `World\Maps\Hyjal130\`
    to produce `maps/1410_<x>_<y>.map`, `vmaps/1410*`, `mmaps/1410*`.
  * Ship the new ADTs + DBCs in a `patch-H.MPQ` (or append to an existing
    DC client patch).

## Build order (server side)

1. Apply `01_Instance_template.sql` — registers map 1410 in `instance_template`.
2. Apply `02_Graveyards.sql` — `game_graveyard` + `graveyard_zone` rows.
3. Apply `03_Game_tele.sql` — 5 teleport points.
4. Apply `04_Areatriggers.sql` — edge-of-map return triggers.
5. Apply `05_Start_NPCs.sql` — service NPC templates for the two starter hubs
  plus the Emberwood Sap Quartermaster.
6. Apply `06_Quest_Items.sql` — quest-reward and elite-loot item templates
  for the 80-130 route (`400011-400040`) plus three
  `reference_loot_template` pools that Hyjal creatures can reuse.
7. Apply `07_Leveling_Items.sql` — consolidated leveling gear and vendor
  surface: the Emberwood Sap token plus first Quartermaster page
  (`400000-400010`), and the full class-core + slot-coverage leveling
  catalog (`400041-400124`) sorted strictly by required level across
  Foothills/Scorched/Summit/Nordrassil (ilvl 300 -> 332 -> 372 -> 398).
  Every tier is buffed above live Wrath endgame (ICC25H ilvl 277, LK25H
  ilvl 284) so starter pieces outclass standard level-80 raid loot.
8. Apply `08_Endgame_PvE.sql` — consolidated PvE endgame catalog at ilvl
  412, contiguous through `400200-400447`: 30 signature items per talent
  tree (`400200-400229`), 95 Ascendant tier-set analogues
  (`400230-400324`), and 123 ICC raid-drop analogues including Ashen
  Verdict Endless rings and the Lich King endpoint weapons plus
  Shadowmourne (`400325-400447`).
9. Apply `09_Endgame_PvP.sql` — 208 equippable Wrathful Gladiator
  analogues at ilvl 412 in `400500-400707`, cleanly separated from the
  PvE endgame ranges above. Sets, weapons, shields, relics, trinkets,
  rings, cloaks, necks, belts, boots, bracers and the tabard are all
  included; the Frost Wyrm mount is intentionally excluded.
10. Apply `NPCs.sql` after re-targeting existing 830xxx spawns to map 1410
  (done below once the first Noggit pass fixes coordinates).
11. Apply `10_NPCs_Quests.sql` — spawns the 80-130 zone population,
  adds Alliance/Horde quest givers (Alliance starts at Alliance Base,
  Horde starts at Horde Encampment), and registers quest chains 81200-81223.
  Side-quest variant templates (e.g. 830042/052/062/073 and 830091-830100)
  are objective-ready but intentionally left for manual spawn placement.
12. Apply `11_Mini_Dungeons.sql` — adds five manual-spawn mini-dungeon packs
  for levels 90, 100, 110, 120 and 125, plus their created reward items,
  boss loot pools and standalone quests 81230-81234. Existing Hyjal
  commanders hand out the quests; dungeon creature placement is manual.
13. Script folder `src/server/scripts/DC/HyjalFrontier/` is wired into the
   DC loader (`dc_script_loader.cpp`) and builds with the rest of the core.

## Caveats

* ADT filename rename is enough for the client to *load* the new map, but a
  full Noggit "Save All" pass on the renamed ADTs is recommended so
  any internal path strings (if present) are rewritten cleanly.
* The existing `830000–830017` creature templates still force
  `minlevel=maxlevel=130` and use factions `1716/1718/1719`. Those will
  need to be rebalanced per-tier once spawns are redistributed.
* Creature `830005 Tyrande Whisperwind` and `830003 Ancient Wisp` reference
  `ScriptName='npc_tyrande_whisperwind'` and `'npc_ancient_wisp'`. Neither
  script exists in the core — set those to `''` or implement the stubs
  in `HyjalFrontier/hyjal_frontier_leaders.cpp` (not yet created).
* Raid map `534 HyjalPast` is **untouched**; the CoT Battle for Mount Hyjal
  raid continues to work.
