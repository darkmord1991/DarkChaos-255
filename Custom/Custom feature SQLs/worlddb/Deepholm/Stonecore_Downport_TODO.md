# Stonecore Dungeon — Downport TODO

Stonecore (map 725, accessed from Deepholm map 646) is the dungeon that
accompanies the Deepholm zone.  The overworld C++ (zone_deepholm.cpp) is
**complete**.  Everything below is the remaining Stonecore-specific work.

Source: `K:\Dark-Chaos\cata stuff\catatc\src\server\scripts\Maelstrom\Stonecore\`

---

## C++ files to downport (~2,800 lines total)

All six files share a common header `stonecore.h` that must be created first
(it defines the NPC/GO/spell enums and extern position constants).

| File | Lines | Contents | Key porting notes |
|---|---|---|---|
| `stonecore.h` | ~80 est. | Shared enums: NPC/GO/data ids, boss positions, formation ids | Author from data used across all 6 files; no TC source for this header |
| `instance_stonecore.cpp` | 322 | `InstanceMapScript` for map 725; boss state machine; Corborus/Slabhide respawn on fail; Millhouse event (face/knockback/despawn); Slabhide rock walls; teleporter activation after Slabhide | `SetMeleeAnimKitId` → AC doesn't have this API; `Seconds()` → `s` suffix; `SearchFormation()`/`GetFormation()` → verify AC API exists; `_eventIndex` save/load via `WriteSaveDataMore`/`ReadSaveDataMore` |
| `stonecore.cpp` | 438 | Non-boss NPCs: **Millhouse Manastorm** (Impending Doom channel, shadow spells, flee sequence); misc trash AI | `SetMeleeAnimKitId(ANIM_READY2H)` → AC has no anim kit API; Millhouse movement points are in Stonecore map coords (double-check after vmaps) |
| `boss_corborus.cpp` | 487 | **Corborus** — burrow/emerge cycle, Crystal Barrage (charged boulders), Rupture, RockWyrm adds; intro event | `ADD_GOSSIP_ITEM_EXTENDED` / gossip handling pattern differs in AC; TC's `summon->m_Events.AddEventAtOffset` → use `EventMap` like fissure fix |
| `boss_slabhide.cpp` | 435 | **Slabhide** — air phase (Crystal Storm, Stalactite drops), ground phase (Rock Bore, Lava Fissure); rock wall open/close | `summon->m_Events` → replace with EventMap; `DoSummonFlyer` available in AC |
| `boss_ozruk.cpp` | 305 | **Ozruk** — Shatter + Paralyze combo, Ground Slam, Bulwark; enrage | Straightforward; check `DoCastVictim` vs `DoCastSelf` targets |
| `boss_high_priestess_azil.cpp` | 785 | **High Priestess Azil** (final boss) — Force Grip platform throw, Gravity Well, Seismic Shard, adds phase; two-phase fight | Most complex; check `MoveJump`/`MoveCharge` API differences; gravity pull = custom movement |

**Total lines to port: ~2,850** across 7 files (including the new header).

---

## SQL prerequisites for Stonecore

Before the C++ compiles, the following DB rows are needed:

### `instance_template` (acore_world)
```sql
INSERT INTO instance_template (map, parent, script, allowMount) VALUES
(725, 0, 'instance_stonecore', 0);
```

### `dungeon_encounters` / `lfg_dungeon_rewards` (acore_world)
- 4 boss encounters: Corborus, Slabhide, Ozruk, High Priestess Azil
- Heroic version: map 725 difficulty 2

### `areatrigger_teleport` for 6194 (Stonecore → Deepholm)
- Already in acore_world (target = map 646, pos 1023.72, 644.75, 156.67)
- Needs **AreaTrigger.dbc row 6194** on Stonecore map 725 at the dungeon exit
- Position unknown — requires in-game measurement or Cata DBC extraction
- Map 725 not yet loaded; add after vmaps/mmaps are available

### `gameobject_template` / `gameobject` spawns for map 725
- Corborus rock door (entry from `GAMEOBJECT_CORBORUS_ROCKDOOR`)
- Slabhide rock walls (entry from `GAMEOBJECT_SLABHIDE_ROCK_WALL`)
- Stonecore teleporter creatures (NPC_STONECORE_TELEPORTER_1/2)
- None of these are imported yet (they are on map 725, not 646)

---

## Asset prerequisites

| Asset | Status |
|---|---|
| Map 725 terrain (map/vmap/mmap) | **Not extracted** — need Cata client extract |
| Stonecore boss creature display models (Cata-era) | **Not retroported** — bake track |
| Stonecore GO display models (rock doors, walls) | **Not retroported** |
| DBC rows: Vehicle, VehicleSeat (Crystal Barrage boulders) | **Not extracted** |
| Spell.csv: Corborus/Slabhide/Ozruk/Azil ability spells | **Not downported** |

---

## AreaTrigger.dbc gap

| AT ID | Trigger location | Target | Status |
|---|---|---|---|
| 6126 | Map 646 ≈ (801, -41, -65) | quest 26258 complete | **Added to AreaTrigger.csv** |
| 6221 | Map 646 ≈ (654, -615, 10) | quest 27007 complete | **Added to AreaTrigger.csv** |
| 6194 | Map 725 Stonecore exit (coords unknown) | Map 646 (1023.72, 644.75, 156.67) | **TODO** — add after map 725 is extracted and coordinates are measured |

---

## Suggested porting order

1. Extract Stonecore terrain (map 725 maps/vmaps/mmaps) from the Cata client
2. Port `stonecore.h` (author the shared header from usage in all 6 files)
3. Port `instance_stonecore.cpp` (the state machine glues everything)
4. Port boss scripts in difficulty order: Corborus → Slabhide → Ozruk → Azil
5. Port `stonecore.cpp` (Millhouse + trash)
6. Import instance_template + dungeon_encounters SQL
7. Import boss spawn SQL for map 725
8. Import GO spawn SQL (rock doors, walls)
9. Measure AT 6194 position in-game → add to AreaTrigger.csv → regenerate DBC
10. Port boss ability spells via `tools/spell_downport.py`
