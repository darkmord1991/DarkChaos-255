# Molten Front (map 750, area 4923) — dedicated content folder

The **Molten Front** is the Firelands daily-campaign hub. In the source it is a
**self-contained map with its own coordinate frame** (ground z ≈ −93..235), NOT a
corner of Mount Hyjal (whose terrain sits at z ≈ 880..1929). So on DarkChaos it is
its **own map — id 861** (free in `Map.csv`), reached from Hyjal (map 750) through a
**portal** (exactly like retail). It is still **wired into the 80-130 leveling
chain + item/token economy** (quests group under the Hyjal zone, MF mobs drop the
same curated gear + Emberwood Sap) — a connected sub-map, not a siloed island.

Source: `nelt_world` map **861** (Project-Neltharion 4.3.4). Clone scheme matches
HyjalCata: **dc_entry = nelt_id + 3,600,000**. Spawns keep their native nelt coords
(they align on map 861's own terrain).

This folder is applied **after** `../HyjalCata/apply_all.sql`. It **supersedes** the
two partial MF spawn layers in HyjalCata (`32_molten_front_phased.sql`,
`51_molten_front_spawns.sql`) — `02_mf_spawns.sql` deletes their guid blocks and
lays down the complete curated set, so remove those two `SOURCE` lines from
`../HyjalCata/apply_all.sql` (or accept that this folder must run last). The MF
template/spell/text backfills already in HyjalCata (`74`–`84`) stay put — this
folder's `INSERT IGNORE` clones complement them.

## Phase curation — the "fully-unlocked end-state"

nelt map 861 is **phased** across 21 mutually-exclusive Firelands campaign states
(assault → construction → built hubs). 3.3.5 has no phasing, so we collapse to one
coherent snapshot. Chosen state: **fully-unlocked** (all daily hubs built + the
persistent enemy forces), via `phaseMask IN (2047, 8, 16, 128)`:

| phaseMask | spawns | role | why included |
|---|---|---|---|
| 2047 (0x7FF) | 405 | permanent "always-visible" world | core questgivers (15) + persistent enemy forces, all 12 sub-areas |
| 8 | 592 | main unlocked daily **combat** layer | the enemy Firelands army you fight, 7 sub-areas |
| 16 | 14 | built **vendor** hub | the only phase with real vendors (3) + 7 questgivers |
| 128 | 107 | extra hub gossip/questgiver NPCs | fleshes out the settled hubs, 7 sub-areas |

**Excluded:** the 1/2/4 progression triad (185/148/148 — three states of the SAME
areas 5738/5739/5745; 2047 already covers them, including all three would
triple-stack), and all small transient/QA masks (12/13/14/32/64/96/512/1945/2048/
16384/32768/32769/65535).

**Result:** **1,118 creature spawns (101 entries) + 241 GO spawns (37 entries).**

> This phase set is a **tunable design choice**. If in-world the hubs look
> over/under-populated or an enemy pack overlaps a friendly hub at identical
> coords, adjust the `phaseMask IN (...)` list in `01`/`02` and re-apply.

## Terrain prerequisite (offline)

Map 861 needs to be registered + its terrain downported. Full command detail is in
`OFFLINE_PIPELINE.md`; in short: add a `Map.csv` row for 861 (Directory e.g.
`DCMoltenFront`, InstanceType 0), downport its ADTs with `wxl-baker`/`downport-map.js`,
regen server `maps/vmaps/mmaps` for 861, register client Map/AreaTable, and pack.

> **Terrain source — RESOLVED.** Cata Map.dbc row 861 = `FirelandsDailies`; its
> terrain ships in the Cata 4.3.4 client (`K:\UntouchedClients\Cata\Data\expansion3.MPQ`,
> `World\Maps\FirelandsDailies\`). Downport it with wxl-baker (MPQ source). See
> OFFLINE_PIPELINE.md §1.

Until map 861 has terrain the spawns load into an empty map (inert) — harmless.

## File order (`apply_all.sql`)

1. `01_mf_templates.sql` — clone the 101 creature + 37 GO templates (+3.6M) with
   model/movement/loot/text/creature-spells (self-deriving from the curated phase set; `INSERT IGNORE`).
2. `02_mf_spawns.sql` — supersede 32_/51_; port the 1,118 cr + 241 GO spawns into
   guid blocks 15,300,000+ (cr) / 15,200,000+ (GO).
3. `03_mf_quests.sql` — MF quests + queststarter/ender, `QuestSortID=616` (the Cata
   "Mount Hyjal" zone the other 169 map-750 quests use, so MF groups with the zone).
4. `04_mf_portal.sql` — entry/exit portal (GO + areatrigger_teleport) from the main Hyjal hub.
5. *(no separate file needed)* — MF is tied into the 80-130 economy by the
   self-deriving HyjalCata files, which both cover `map IN (750,861)`:
   `99_zone_gear_statfill.sql` (real Cata stats on MF drop gear) +
   `100_zone_token_economy.sql` (Emberwood Sap on MF mobs). An optional Hyjal→MF
   breadcrumb quest can be added later; the portal (`04`) is the functional link.

## Known follow-ups (documented, not silent)

- **Referenced custom spells**: MF creature spells (nelt `spell1-8` → `creature_template_spell`)
  and script-cast Cata spells may need `spell_dbc` rows not yet present — audit after apply
  (same pattern as HyjalCata `76`/`80`) and port via `gen_spell_dbc_sql.py`.
- **Missing loot items**: 18 loot item refs don't exist in `item_template` — `01` filters
  them out of the loot clone (kept: reference-loot rows). Backfill later if those drops matter.
- **Creature display ids**: any new MF display id must exist client-side (CreatureDisplayInfo.dbc);
  audit new `modelid` values vs the client after apply.
