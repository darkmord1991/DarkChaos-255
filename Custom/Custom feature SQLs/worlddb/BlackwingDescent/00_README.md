# Blackwing Descent (map 669) — Cataclysm raid downport

Downport of the Cataclysm raid **Blackwing Descent** (map 669) into the DarkChaos
3.3.5a AzerothCore fork. Companion to the Hyjal (750) / Plaguelands (751) / Deepholm (646)
zone downports, but this is an **instanced raid** (4 difficulties: 10N/25N/10H/25H).

Full design + investigation is in the approved plan; this README is the execution runbook.

---

## Sources (reuse; do NOT touch the broken `K:\Dark-Chaos\MPQ extracts CATA bis SL`)

| Need | Source |
|---|---|
| Boss + instance C++ (PRIMARY) | `K:\Dark-Chaos\cata stuff\CataTC\src\server\scripts\EasternKingdoms\BlackrockMountain\BlackwingDescent\` |
| Boss C++ cross-ref | `K:\Dark-Chaos\cata stuff\Project-Neltharion-4.3.4-Cataclysm\...\BlackwingDescent\` |
| World data (PRIMARY) | MySQL `cata_world` (matched to CataTC ScriptNames + spawn-group ids 400/402/435/436) |
| World data cross-ref / item stats | `nelt_world` (InhabitType for flight; `db_item-sparse_15595` for item stats) |
| Terrain / models | retail `K:\UntouchedClients\World of Warcraft 12.07` (12.0.7) via `K:\Dark-Chaos\wow.export-main\tools\` |
| Missing DBC **rows** | `K:\Cata` 4.3.4 client (build 15595) `Data\enUS\locale-enUS.MPQ` |

## ID conventions
- **Keep retail entry ids verbatim** (Magmaw 41570, Maloriak 41378, Atramedes 41442, Chimaeron 43296,
  Nefarian 41376, Omnotron 42186 + golems 42166/42178/42179/42180, Onyxia 41270).
- **Spawn GUID blocks (verified free — the naive blocks are partly occupied):**
  creature base **>= 9,555,000** (9,500,000–9,554,107 is taken); gameobject base **9,500,000**
  (9,600,000+ is taken; the 9,500,000–9,599,999 GO window is empty). Comment tag `'BWD'`.
  **Re-verify free via acmcp before allocating.**

---

## Build order

### A. Server code (in this repo — no build unless explicitly requested)
- C++ scripts: `src/server/scripts/DC/BlackwingDescent/` (header + instance ported;
  6 boss files + misc/trash file to follow, each registered in `dc_script_loader.cpp`).

### B. World DB SQL (this folder — apply via `apply_all.sql`)
Numbered, idempotent (scoped DELETE before INSERT), InnoDB, 4-space indent; run
`apps/codestyle/codestyle-sql.py` before applying. **Boss creature_templates must load first**
(loot / quests / achievements reference their entries).

| File | Contents |
|---|---|
| `01_creature_templates.sql` | Clone bosses/trash/stalkers from `cata_world`; split `modelid`→`creature_template_model`, `resistance`→`creature_template_resistance`, `spell`→`creature_template_spell`; **down-level 87/88→80-83 + hard-set per-difficulty HP**; set `ScriptName`; include hidden deps 42356 (Blind Dragon Tail), 41767 (Spike Stalker), 49679 (Sonar Pulse Target); **Atramedes 41442 `flags_extra \|= 0x200`** (flight). |
| `02_gameobject_templates.sql` | Doors 205830/208291/402368, elevators 203716/207834, gong 203295, orb 203254, growth chambers 206704/206705, Finkle's Cage 204928/204929, portal doodads. |
| `04_spawns.sql` | Creature + GO spawns from `cata_world` into the reserved GUID block; rewrite PhaseId→phasemask. Carry `MovementType=2` + `creature_addon.path_id` for guids 250050/250116/250117 (patrols). **Do NOT import nelt's Omnotron golems / Onyxia (CataTC summons them) / portcullis / extra gongs.** |
| `05_groups.sql` | `creature_summon_groups`, `creature_formations` (InversionPoint1/2→point_1/2), `creature_addon`, `creature_equip_template`, `waypoint_data` (3 patrol paths). |
| `06_text.sql` | `creature_text` (88 lines / 16 entries from cata; BroadcastTextIds already in acore) + Finkle `gossip_menu`/`_option` (11812). |
| `07_model_movement.sql` | `creature_model_info` (15 missing display-ids) + `creature_template_movement` **flight synthesis** (Bucket-B from `nelt_world.InhabitType IN (4,5,6,7)` → Flight=1: catches 42186/42764/42767/41376; Atramedes = flags_extra+C++, Onyxia = transport, not Flight). Mirror `ReviewFixes\review_flying_npcs.sql`. |
| `08_bindings.sql` | `conditions` (~69), `spell_script_names` (161), `npc_spellclick_spells` (77901/46598), `vehicle_template_accessory` (42356), `areatrigger_scripts` (AT 6583 `at_bwd_intro`), optional `game_tele`. |
| `09_loot.sql` | Boss loot from `cata_world` (Reference schema) → `reference_loot_template` (remap ref ids off item-id space); reassign Omnotron loot to Toxitron 42180; author heroic (10H/25H) tables. |
| `10_items.sql` | ~118 shell→stat UPDATEs (source `nelt_world.db_item-sparse_15595`; **compute armor + weapon dmg** — not in item-sparse). 6 new item_template rows: 63682/63683/63684 (tier tokens), 64663 (quest key), 71716 (misc), 65010 (heroic Ironstar's). |
| `11_instance.sql` | `instance_template (669,0,'instance_blackwing_descent',0)`; `instance_encounters` (DungeonEncounter 1022-1027); `access_requirement` x4; `areatrigger_teleport (6581 → 669 -345.872,-224.344,193.127)`. |
| `12_quests.sql` | **Superseded plan below the line in this file's own header comment** — BWD does NOT use the dungeon-quest-mapping system. Instead: a dedicated questgiver, Emissary Blackscale (creature 700110, spawned at the entrance), with 10 plain `quest_template` rows (ids 700701-700710) via `creature_queststarter`/`creature_questender` — 6 boss-kill quests + 4 flavor quests (entrance spirit-guardian trial, drakonid/construct trash guarding the Magmaw approach, a Finkle Einhorn follow-up gated on the Chimaeron kill, and a no-objective capstone gated on Nefarian's End, both gated via `quest_template_addon.PrevQuestID`). Reward item 71716 (previously unused) is the capstone reward. |
| `13_achievements.sql` | `achievement_reward` / `achievement_criteria_data` for BWD (DBC rows are authored in the CSV DBC set, §C). Category 10011 "Blackwing Descent" (parent 10000). |
| `14_trash_ai.sql` | Merge `nelt_world.smart_scripts` for the 6 trash entries CataTC lacks AI for: 42802 (3), 46083 (15), 42764 (3), 42767 (2), 42768 (7); 42803 → `AIName='AggressorAI'`. Exclude nelt's spawn rows (spawns come from cata). |

### C. Client + server DBC (edit `Custom\CSV DBC\`, rebuild `.dbc`, deploy to client MPQ + `Server\data\dbc\`)
Map/area values are taken from the CLIENT (exact), not hand-guessed — the decoded retail 12.0.7 DBCs are
at `K:\Dark-Chaos\retailextracts\_dbc\` (`Map.csv`, `AreaTable.csv`, `UiMapAssignment.csv`, `LoadingScreens.csv`),
and the 4.3.4 client `K:\Cata` supplies anything retail's UiMap system dropped.
- **DONE (authored with exact extracted values):**
  - `Map.csv` 669 — Directory `BlackwingDescent`, InstanceType 2, AreaTableID 0, LoadingScreenID 141,
    ExpansionID 2, **CorpseMap 0 @ (-7541.7676, -1188.8317)** (BWD's own coords from retail Map.csv).
  - `MapDifficulty.csv` 9329-9332 (669 × diff 0/1/2/3, 10/25 players, level 85).
  - `AreaTable.csv` 5788 — ContinentID 669, **AreaBit 3831** (exact retail; retail's own area id 5094 was
    already taken here by Serpent's Overlook, so BWD uses DC-safe 5788 with the real AreaBit).
  - `WorldMapArea.csv` 1220 — map 669 → area 5788, AreaName `BlackwingDescent`, **Loc 174.109 / -675.585 /
    -0.9996 / -567.462** (from retail `UiMapAssignment` Region for UiMap 285; maxY/minY/maxX/minX).
- **TODO — extract from K:\Cata → transcode 4.3.4→3.3.5 → merge rows:** DungeonEncounter 1022-1027,
  Vehicle 834/931/1548/862-865/891, VehicleSeat (its seats). (`mpq_stormlib_extract.py --file DBFilesClient\<name>.dbc`
  or `ad.exe -e 2 -i "K:\Cata"`.) AreaTrigger 6581 (+6583) geometry rows also from the client.
- **TODO — WMOAreaTable:** map the baked BWD WMO group ids → area 5788 (group ids come out of the wxl-baker bake).
- **TODO — GameObjectDisplayInfo (invisible-door fix):** 7 rows (9683/9946/10138/10139/10363/10407/10463) with
  Cata model paths (WMO-type via `downport-wmo.js`); GODI ids >= 100794.
- **TODO — CreatureDisplayInfo/ModelData:** boss retroport bakes on the 500xxx seq (`downport-creature.js`);
  then remap the 01/07 placeholder Cata display ids to these.
- **TODO — Achievement / _Category / _Criteria:** BWD rows (block 11000-12999, category 10011); values in
  retail `Achievement.csv` if extracted.
- **TODO — Spell.csv:** the 161 boss spells + remapped `SpellVisualID` (or DangerZone telegraphs); server rows
  via `Deepholm\tools\spell_downport.py` (clamp Effect>=165/Aura>=317).
- **In-game map = WorldMapArea + art (NOT DungeonMap).** Minimap/world-map art auto via `downport-map.js`.

### D. Manual asset pipeline (run on the Windows host — not automatable from the repo)
The down-converter is **`wxl-baker.exe`** (`K:\Dark-Chaos\dc-wotlkextensions\build\downport\Release\wxl-baker.exe`):
it translates modern (Cata+) split-ADT / MD21-M2 / modern-WMO into real 3.3.5-format ADT/WMO/M2/WDT
(+ copied BLP/skin). `downport-map.js` is the orchestrator that drives wxl-baker; you can also call the
baker directly. Doc: `dc-wotlkextensions\tools\downport\README.md`.

1. **Extract raw modern assets from retail:** `node tools/casc-extract.js --install "K:/UntouchedClients/World of Warcraft 12.07"`
   (map 669 = `world/maps/blackwingdescent/*` + WMO `world/wmo/dungeon/blackwingv2/*` + entrance WMO).
2. **Bake modern → 3.3.5 with wxl-baker** (the actual asset down-convert step). Either the orchestrator
   `node tools/downport-map.js 669 --package` (runs `wxl-baker` + `wxl-skinfix` + WMO fixers + minimap +
   WorldMapArea art), OR the baker directly into a server Data staging tree:
   `wxl-baker --in <wowexport_dir> --out K:\server\Data --deps --tiles blackwingdescent 31 31 33 33`
   (`--deps` walks ADT→WMO(+groups)→M2→textures for a self-contained output; auto-fetches the FDID
   listfile). WMO-type GameObject models (Onyxia elevator, WMO doors) go through `downport-wmo.js`.
3. **Server collision / nav:** run stock AC `map_extractor` / `vmap4_extractor` / `mmaps_generator`
   against the baked Data tree → deploy `669*.{map,vmtile/vmtree,mmtile}` to `Server\data\{maps,vmaps,mmaps}\`.
   **Verify the baked WDT MODF placement vs the 4.3.4 WMO before importing spawns** (coord-alignment
   guard) — this collision/nav half has never been completed on a DC Cata map.
4. **Boss + GO display models:** `node tools/downport-creature.js --mode creature` bakes the Cata boss
   models → 3.3.5 (`CreatureDisplayInfo`/`CreatureModelData` on the 500xxx seq); fill
   `CreatureDisplayInfo.TextureVariation_1..3` (white-model fix). Then remap the 01/07 placeholder Cata
   display ids (in `creature_template_model` + `creature_model_info`) to these 500xxx ids.
5. **Client MPQ patch:** `mpq_stormlib_pack.py` (baked terrain + DBCs + minimap/world-map art + models)
   → live client `Data\`.
6. **Build (only when explicitly requested):** `game` + `scripts` targets; then in-game QA per the plan's
   verification checklist (map loads, no fall-through, pathing, per-boss mechanics, loot, quests, achievements).

---

## Apply
```sql
-- from a MySQL client connected to the world DB (acore_world), with cata_world + nelt_world present:
SOURCE apply_all.sql;
```
