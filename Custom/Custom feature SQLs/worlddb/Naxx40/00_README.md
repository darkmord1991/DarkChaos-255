# Naxxramas 40 ("special edition") - map 2921

Ported out of `mod-vanilla-naxxramas` (sogladev, commit 5e6f54f) into the DC tree.
C++ lives in `src/server/scripts/DC/Naxx40/`, loaded via `AddDCNaxx40Scripts()`
from `dc_script_loader.cpp`. There is no module any more, so **this SQL is not
applied automatically** - run the files in numeric order, by hand.

| file | what |
|---|---|
| `01_naxx40.sql` | map/difficulty registration, DBC override tables, areatrigger scripts |
| `02_naxx40_creatures.sql` | 93 creature templates (351000-351092) + 1066 spawns |
| `03_naxx40_gameobjects.sql` | entrance teleporter + props |
| `04_naxx40_frozen_runes.sql` | 209 frozen-rune GOs (guids 5330300-5330508) |
| `05_naxx40_spells.sql` | 16 `spell_script_names` rows for the `_40` spell scripts |
| `06_naxx40_quests.sql` | attunement + class quests |
| ~~`07_naxx40_omarion.sql`~~ | **SKIPPED** - only modifies stock NPC 16365 |
| ~~`08_naxx40_archmage_tarsis.sql`~~ | **SKIPPED** - only modifies stock NPC 16381 |
| **`99_retarget_naxx40_to_map_2921.sql`** | **run LAST** - moves everything from 533 to 2921 |

## Why 99_ has to run last

The upstream SQL is written for map 533. `99_` moves the spawns onto 2921 by
keying on the module's own reserved id ranges. **Never search-replace "533" in
these files** - it also matches coordinates (`-3533.4387`) and guid prefixes
(`5330450`).

## Changes made to the upstream SQL

`01_naxx40.sql` had five UPDATEs that mutate **stock** Naxxramas on map 533
(mass `spawnMask` rewrites on its creatures and gameobjects, plus the Orb of
Naxxramas). They are commented out - the 40-man has its own map now, and
`99_` clones what it needs instead. Upstream copy: `01_naxx40.sql.upstream.bak`.

Map ids in `disables`, `mapdifficulty_dbc`, `dungeon_access_template`,
`lfgdungeons_dbc` and the 15 `dungeonencounter_dbc` rows were retargeted to 2921.

## Deliberately NOT changed

The 12 spell/aura scripts that share a name with core's Naxxramas scripts keep
those names, so they replace AzerothCore's handlers globally. That is the
"vanilla mechanics everywhere" behaviour: each one branches internally, giving
vanilla values at `RAID_DIFFICULTY_10MAN_HEROIC` and falling through to the
WotLK behaviour on every other difficulty.

## Stock-533 guard

Every statement that would modify stock WotLK Naxxramas has been disabled - see
`00_STOCK_533_AUDIT.md` for the full list, what the 40-man loses as a result, and
the clone work needed to get it back. `06_naxx40_quests.sql` is the deliberate
exception: it rewrites the 91 stock Naxxramas quests (QuestSortID 3456), which was
kept on purpose because quests are global rows and cannot be scoped per map.
