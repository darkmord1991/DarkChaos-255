# Downported-zone flight paths — Mount Hyjal (750) & Plaguelands (751)

Adds a working taxi (flight master) network to the two downported continents.
Both zones already had flight-master NPCs spawned, but **no taxi nodes existed
on continents 750/751**, so the flight map was empty. This work adds the DBC
taxi graph plus a small convenience script.

## What was added

### 1. DBC data (the flight network) — `Custom/CSV DBC/`
Taxi is entirely DBC-driven in AzerothCore (there is **no** world-DB table for
it), so the data lives in the CSV-DBC sources that the external tool compiles
into both the server `dbc/` and the client patch.

- **`TaxiNodes.csv`** — 17 new nodes, one per flight master, snapped to the matched
  retail Cata taxi node (name + position).
- **`TaxiPath.csv`** — 152 paths, a full mesh within each map (every node → every
  other node on the same continent). Path ids **9500–9651**.
- **`TaxiPathNode.csv`** — 5888 waypoints, ids **48000–53887**. These are
  **Blizzard's real Cata flight-path waypoints**, not hand-authored — they follow
  the actual terrain. Where Cata connected two nodes directly, that path's
  waypoints are used verbatim; where it did not (106 of 152 pairs), the cheapest
  chain of direct Cata segments through our own nodes is concatenated, so every
  pair still flies a real Blizzard route without leaving the zone.

**Why this is real Blizzlike data:** both DC maps are coordinate-preserving copies
of the retail continents (Hyjal = continent 1, Plaguelands = continent 0) — every
flight master matches a Cata taxi node within ~2–7 yds. So the retail Cata
`TaxiPathNode` chains drop straight in, only remapping `ContinentID` (1→750,
0→751) and the node/path ids into our ranges. Source DBCs were extracted from the
**Cata 4.3.4 client** (`K:/Cata/Data/enUS/locale-enUS.MPQ`, build 15595).

Regenerate/extend with `scripts/gen_taxi.py` (kept with this doc, alongside the
extracted `cata_dbc/` source DBCs). It is idempotent — it strips the id ranges
above and re-emits them in the CSV dialect (fully-quoted fields, **dot decimal
separator**, LF, no BOM).

> **Decimal format note.** `TaxiNodes.csv`/`TaxiPathNode.csv` were originally
> stored with German decimal *commas* (`-8851,658`). WDBX Editor parses a comma
> as a thousands separator and silently drops the fraction (`-8851,658` →
> `-8851658`), corrupting every coordinate. They have been converted to dot
> decimals (`-8851.658`) to match the rest of `Custom/CSV DBC/` (e.g.
> `CreatureModelData.csv`) and what WDBX/DBC tooling expects. Keep new rows dot-
> decimal.

Caveat: taxi data was read from the base locale MPQ;
the v4 `patch-base-15595` MPQs are unreadable by `mpyq`, but Hyjal/Plaguelands
taxi data was stable across Cata patches so the base version is authoritative.

#### Node allocation (name/coords = matched Cata node)
| id  | map | node name (Cata)                    | cata id | flight master        | mounts (H/A) |
|-----|-----|-------------------------------------|---------|----------------------|--------------|
| 421 | 750 | Grove of Aessina, Hyjal             | 558     | Elizil Wintermoth    | 3837 / 3837  |
| 422 | 750 | Sanctuary of Malorne, Hyjal         | 781     | Ranela Featherglen   | 3837 / 3837  |
| 423 | 750 | Shrine of Aviana, Hyjal             | 557     | Dinorae Swiftfeather | 3837 / 3837  |
| 424 | 750 | Nordrassil, Hyjal                   | 559     | Fayran Elthas        | 3837 / 3837  |
| 425 | 750 | Gates of Sothann, Hyjal             | 616     | Althera              | 3837 / 3837  |
| 426 | 751 | Chillwind Camp, Western Plaguelands | 66      | Bibilfaz Featherwhistle | 3574 / 541 |
| 427 | 751 | Light's Hope Chapel, E. Plaguelands | 68      | Khaelyn / Georgia    | 3574 / 541   |
| 428 | 751 | Acherus: The Ebon Hold              | 315     | Grimwing             | 3574 / 541   |
| 429 | 751 | Thondroril River, E. Plaguelands    | 383     | Frax Bucketdrop      | 3574 / 541   |
| 430 | 751 | Eastwall Tower, E. Plaguelands      | 86      | Richard Trueflight   | 3574 / 541   |
| 431 | 751 | Light's Shield Tower, E. Plaguelands| 630     | Devon Manning        | 3574 / 541   |
| 432 | 751 | Crown Guard Tower, E. Plaguelands   | 87      | Janice Myers         | 3574 / 541   |
| 433 | 751 | Plaguewood Tower, E. Plaguelands    | 84      | William Kielar Jr.   | 3574 / 541   |
| 434 | 751 | Andorhal (Forsaken), W. Plaguelands | 649     | Rhonda Molver        | 3574 / 541   |
| 435 | 751 | Andorhal (Alliance), W. Plaguelands | 650     | Ginny Goodwin        | 3574 / 541   |
| 436 | 751 | The Menders' Stead, W. Plaguelands  | 651     | Marge Heffman        | 3574 / 541   |
| 437 | 751 | Hearthglen, W. Plaguelands          | 672     | William Henderson    | 3574 / 541   |

Node names/positions are the matched Cata nodes. The two Andorhal flight points
share one name in Cata (phased Alliance/Forsaken pair); they are disambiguated
here for the shared gossip list.

### 2. Gossip flight master — `src/server/scripts/DC/AC/dc_downport_taxi.cpp`
The `CreatureScript` **`npc_dc_downport_flightmaster`** drives every flight master
on both maps. On talk it resolves the current node from the creature's position,
lists the map's other nodes as gossip options (with fare), and starts the flight
with `ActivateTaxiPathTo` — which does **not** require the destination to have
been discovered and does **not** use the client taxi-map UI. This is the same
mechanism the custom leveling-camp masters use (`ac_flightmasters.cpp`), and it
is deliberately chosen over the standard taxi map because the client may not have
`WorldMapContinent` bounds for these custom continents, so the map dots may not
render. Registered in `dc_script_loader.cpp` as `AddSC_dc_downport_taxi`.

Bind it to the NPCs with `creature_template.ScriptName = 'npc_dc_downport_flightmaster'`
via `HyjalCata/60_flightmaster_scripts.sql` (map 750) and
`Plaguelands/47_flightmaster_scripts.sql` (map 751) — both scope by spawn map +
FLIGHTMASTER flag and are idempotent. `ScriptName` preempts the default taxi-map
gossip; the SmartAI on a few of these NPCs has no gossip events, so there is no
conflict.

> **Required: the GOSSIP npcflag (0x1).** A pure flight master (`npcflag = 8192`,
> FLIGHTMASTER only) makes the *client* send the taxi-map query instead of
> gossip-hello, so our `OnGossipHello` never fires and the blank custom-continent
> taxi map opens — the NPC appears to "not reply". The binding SQL therefore also
> sets `npcflag = npcflag | 1`. All Hyjal FMs were 8192 (broken); Plaguelands had
> 8193/8195 (worked) plus 8192 Frax/Rhonda/Marge (also broken until this).
> `npcflag` changes only take effect on **respawn/worldserver restart**.

### Mounts (verified)
The flight mounts resolve to valid stock displays present in this fork's
`CreatureDisplayInfo.csv`: **3837** Riding Hippogryph → display 1936 (both slots,
Mount Hyjal), **3574** Riding Bat → display 1566 (Horde, Plaguelands), **541**
Riding Gryphon → display 6852 (Alliance, Plaguelands). `ActivateTaxiPathTo` picks
the team slot via `GetTaxiMountDisplayId`; both slots are set on every node so it
always resolves.

## Hard constraint: node ids must be ≤ 448
`TaxiMaskSize = 14` (`std::array<uint32,14>` in `DBCStructure.h`) → the taxi
bitmask holds **448 bits**, and node id `i` uses bit `i-1`. `GetNearestTaxiNode`
skips any node whose bit falls outside the mask (`field >= TaxiMaskSize`), and
the same mask is persisted per character. Expanding it would touch the client,
the server, and every saved character mask, so **stay within 1–448**. Stock max
node id is 445; the ids used here (421–437) are previously-free gaps. Ids
**350–359** are informally reserved by the Hyjal *Frontier* zone stub and were
avoided. Ids **441–445** are the custom leveling-camp nodes (`ac_flightmasters.cpp`).

## How the core wires up (verified)
- The gossip path (`ActivateTaxiPathTo`) only needs the `TaxiPath` to exist in
  DBC — it does not gate on the player's discovered-node mask, so no per-node
  discovery is required.
- `MountCreatureID[team]` (Horde = index 0 / `MountCreatureID_1`, Alliance =
  index 1 / `MountCreatureID_2`) is set on **both** slots of every node so
  `GetTaxiMountDisplayId` always resolves a mount.
- Flight cost is the summed Cata fare of the route (50–2000 copper), reduced by
  the reputation discount at fly time.
- The `TaxiPath` mesh also puts every node in `sTaxiNodesMask`, so the standard
  taxi map still works as a fallback **if** the client can render it for these
  continents — the gossip menu does not depend on that.

## Deploy checklist
1. Recompile `TaxiNodes.csv`, `TaxiPath.csv`, `TaxiPathNode.csv` (CSV → DBC via
   the usual external tool).
2. Copy the rebuilt `TaxiNodes.dbc` / `TaxiPath.dbc` / `TaxiPathNode.dbc` into the
   **server** `data/dbc/` (they must exist for the flight routes + mount lookup).
3. Apply the SQL: `HyjalCata/60_flightmaster_scripts.sql` +
   `Plaguelands/47_flightmaster_scripts.sql` (already sourced by each zone's
   `apply_all.sql`).
4. Rebuild worldserver (adds `npc_dc_downport_flightmaster`) and restart.
5. (Optional, for the visual taxi map) pack the three DBCs into the client patch.
6. In-game: talk to any flight master → pick a "Fly to …" gossip option.

## 2026-11-22 audit and fix (map 751, also affects 750)

Report: "sometimes you fly through a tree or get dismounted at some height in strange spots".

**What is Blizzlike:** every shared route flies Blizzard's Cata 4.3.4 waypoints, and 751's ground and
trees are Cata's: the heightmap matches Cata under all 136 paths (median diff 0.00 yd), and 63,637 of
63,912 doodads sit at a Cata position. Blizzard's routes brush some treetops (Hinterlands, Tirisfal
canopy trees), and the Undercity routes run underground through the bat tunnel. Both look the same in
Cata and stock 3.3.5.

**What was not, and the fix in `scripts/gen_taxi.py`:**
1. **Every flight landed 10 yd in the air.** Both path ends were snapped to node z + 10. AzerothCore
   (`FlightPathMovementGenerator::DoFinalize`) dismounts the player at the last spline point and does
   not put them on the ground, so each landing dropped the player 10 yd. Blizzard ends paths about
   2 yd above the node. Now a hop flown from the node's own binding keeps Blizzard's end point, and
   any other end snaps to node z + 2 (`ENDPOINT_KEEP`, `ENDPOINT_LIFT`). Landings are now
   −0.6..+4.2 yd on 751 and −0.1..+5.0 yd on 750.
2. **11 routes were stitched chains** (9 on 751, 2 on 750). Dijkstra picked a cheaper chain even
   where a direct Blizzard path exists, and kept the intermediate landings. Tarren Mill → The Bulwark
   went through the Undercity tunnel and landed at Brill on the way (133 waypoints instead of 21).
   Adjacency pairs now fly their direct edge. These 9 TaxiPath fares on 751 rose to Blizzard's
   direct fare: 9613, 9648, 9650, 9659, 9661, 9682, 9683, 9691, 9711.
3. **The 12 Alliance-only routes (nodes 400-402) flew through tree crowns.** LEADIN cleared only the
   heightmap, and the Alterac and Silverpine pines are 50-230 yd tall. The new tool
   `scripts/taxi_forced_lift.py` reads the client's map-751 ADTs and doodad/WMO meshes, then raises
   each forced path over the obstacles under the flown Catmull-Rom spline. Where one tree would cost
   more than 20 yd of climb, it bends the route up to 60 yd sideways instead. Results go to
   `scripts/taxi_forced_lift.json` with a fingerprint per path. In-object flight on these routes fell
   from 61 yd per 1000 yd flown to 0. The only clips left are single trees beside the Stormpike and
   Refuge Pointe flight masters, inside the take-off/landing slope cap (0.8).

**Regenerating:** `python taxi_forced_lift.py`, then `python gen_taxi.py`. gen_taxi refuses to run
when a forced path has no lift entry or a stale one, which happens whenever LEADIN, ROUTE_ALT,
CUSTOM_NODES, the end rule or the Cata data moves a forced polyline. Stock TaxiPath and TaxiPathNode
rows, all TaxiPath ids and all TaxiNodes rows were unchanged by this fix.
