# BWD DBC values extracted from K:\Cata (4.3.4, build 15595)

Extracted via `mpq_stormlib_extract.py` from `K:\Cata\Data\enUS\locale-enUS.MPQ` and parsed with a WDBC
reader. These are the exact client values for the remaining DBC transcode-merge (map/area + GODI already
applied to `Custom\CSV DBC\`).

## DungeonEncounter — ✅ DONE (`DungeonEncounter.csv` 618 rows in CSV set + `Custom\DBCs\DungeonEncounter.dbc`)
Binary-patched stock 3.3.5 (612→618); Name expanded from Cata's 1 string → 3.3.5's 16 loc + mask; also
dumped back to `Custom\CSV DBC\DungeonEncounter.csv` so a CSV regen reproduces it. Client-only DBC → pack
into the client patch MPQ (server does not read it). Layout note: Difficulty = -1 (all). Bit = mask index.

| ID | MapID | Difficulty | Bit | Name |
|----|-------|-----------|-----|------|
| 1022 | 669 | -1 | 0 | Atramedes |
| 1023 | 669 | -1 | 1 | Chimaeron |
| 1024 | 669 | -1 | 2 | Magmaw |
| 1025 | 669 | -1 | 3 | Maloriak |
| 1026 | 669 | -1 | 4 | Nefarian's End |
| 1027 | 669 | -1 | 5 | Omnotron Defense System |

## Vehicle + VehicleSeat — ✅ DONE
- **Vehicle** (`Vehicle.csv` 412→420 rows + `Custom\DBCs\Vehicle.dbc`): 4.3.4 Vehicle.dbc = same 40-field layout
  as 3.3.5, so a straight row transcode. 8 rows added: 834/862/863/864/865/891/931/1548.
- **VehicleSeat** (`VehicleSeat.csv` 720→737 rows + `Custom\DBCs\VehicleSeat.dbc`): verified Cata **appended** its
  8 extra fields at the END (first 58 fields byte-identical for shared seats) → clean truncation transcode
  (first 232 bytes of each 4.3.4 record = a valid 3.3.5 record). 17 seat rows added.
- Both compile via `csv2wdbc.py --table Vehicle|VehicleSeat` (WDBXEditor 3.3.5 defs). Deploy to client MPQ
  **and** `Server\data\dbc\` (server reads both for vehicle mechanics). **Still gated on the neutralized C++
  transport/vehicle logic** — the DBC rows are ready; the ride won't function until the C++ rework (PORT_NOTES.md).

(historical mapping below)

| Vehicle | Used by | Referenced VehicleSeat ids |
|---------|---------|----------------------------|
| 834 | Magmaw (head-ride/harpoon) | 7910, 7911, 7936, 8051 |
| 891 | Atramedes | 8052 |
| 931 | Maimgor | 8143 |
| 1548 | Room Stalker | 9677, 9678, 9679, 9680 |
| 863 | Arcanotron | 7970 |
| 862 / 864 / 865 | Electron / Toxitron / Magmatron | (no seat fields populated — verify) |

VehicleSeat ids to extract from the 4.3.4 VehicleSeat.dbc (already extracted to `k:\tmp\bwd_dbc\VehicleSeat.dbc`):
**7910, 7911, 7936, 8051, 8052, 8143, 9677, 9678, 9679, 9680, 7970** — transcode 4.3.4→3.3.5 (seat layout changed).

## GameObjectDisplayInfo — DONE (7 rows added to GameObjectDisplayInfo.csv with these exact model paths)
Cata display ids were free here (no remap). **The 2 elevators are WMO** → must go through `downport-wmo.js` (not the M2 path); the 5 MDX doodads via the standard bake.

| DisplayID | GO | Model (from K:\Cata) | Type |
|-----------|----|-----|------|
| 9683 | Blind Dragon Gong (203295) | world\blackrockv2\passivedoodads\blackrockv2_shieldgong_collision.mdx | M2 |
| 9946 | Inner Chamber Door (205830) | ...\BLACKROCKV2_PORTCULLIS_02.MDX | M2 |
| 10138 | Growth Chamber (206704) | ...\blackrockv2_labroom_bloodvial_breaker01.mdx | M2 |
| 10139 | Large Growth Chamber (206705) | ...\blackrockv2_labroom_bloodvial_breaker02.mdx | M2 |
| 10363 | Onyxia Elevator (207834) | WORLD\WMO\TRANSPORTS\WMO_ELEVATORS\BLACKWINGV2_ELEVATOR_ONYXIA_TRANSPORT.WMO | **WMO** |
| 10407 | BWD Elevator (203716) | WORLD\WMO\TRANSPORTS\WMO_ELEVATORS\BLACKWINGV2_ELEVATOR01.WMO | **WMO** |
| 10463 | Athenaeum Door (208291) | WORLD\BLACKROCKV2\PASSIVEDOODADS\BLACKWING_PORTCULLIS.MDX | M2 |

(GeoBox left 0 in the CSV rows — refine per-model bbox if doors mis-collide.)
