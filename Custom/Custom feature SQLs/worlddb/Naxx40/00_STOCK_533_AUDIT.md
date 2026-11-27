# Audit: what these scripts do to STOCK WotLK Naxxramas (map 533)

Method: every DELETE / UPDATE / REPLACE in the 9 files was extracted with `SET @var`
values resolved (342 statements, 50 tables), ids outside the naxx40 reserved ranges
were flagged, and each flagged set was intersected against the LIVE database.

**Verdict: NO, not clean. Stock Naxxramas is modified in 9 places.**

## Confirmed modifications to stock content

| # | file | statement | what it hits (verified against live DB) |
|---|---|---|---|
| 1 | `06_quests` | 72x `quest_offer_reward`, 72x `quest_request_items`, 15x `quest_template_addon`, 24x questgiver DELETEs, `disables` DELETE of 92 rows | **91 stock Naxxramas quests** (QuestSortID **3456**) + 2 in EPL (sort 139). Rewrites reward/completion text and prerequisite chains. |
| 2 | `02_creatures` | `UPDATE creature_immunities ci JOIN creature_template ... WHERE ct.entry IN (351054, 16158)` | `CreatureImmunitiesId -385` is **shared by 4 stock templates** (16156 Dark Touched Warrior, 16157 Doom Touched, 16158 Death Touched, 29833). ORs charm+disorient immunity into all four. |
| 3 | `02_creatures` | ~21 `creature_template` UPDATEs + locale/addon/model/movement/spell/text/smart_scripts | **19 stock Naxx templates**: 16157, 16158, **16211 Naxxramas Combat Dummy (spawned on 533)**, 16365 Omarion, 16381 Tarsis, 16448 Plagued Deathhound, 16449 Spirit of Naxxramas, 16451-16453, 16697 Void Zone, 16775-16778 Horsemen spirits, 16861, **16998 Mr. Bigglesworth (spawned on 533)**. Most are summoned at runtime by core's WotLK bosses, so "no `creature` rows" does not mean unused. |
| 4 | `01_naxx40` | `areatrigger_scripts` rewrite for **5191-5194** + **5196-5199**, `areatrigger_teleport` DELETE of **5196-5199 + 4156** | Stock Dragonblight entrances and the in-Naxx exits on map 533/571. |
| 5 | `03_gameobjects` | `DELETE FROM gameobject WHERE id = 181056`; `DELETE FROM transports WHERE guid = 21 AND entry = 181056`; `UPDATE gameobject_template SET Data1=1, Data6=0 WHERE entry = 181056` | **181056 = "Naxxramas"**, the floating necropolis transport in Dragonblight. |
| 6 | `03_gameobjects` | `DELETE FROM gameobject_template WHERE entry = 193166`; `DELETE FROM gameobject WHERE id=193166 AND map=0` | **193166 = Meeting Stone** — deletes a stock template outright. |
| 7 | `03_gameobjects` | `UPDATE gameobject SET spawnMask = 3 WHERE id IN (202277, 202278)` | Orb of Naxxramas, 2 stock spawns on map 533. |
| 8 | `07_omarion` / `08_tarsis` | 5x `broadcast_text`, 2x `npc_text` UPDATEs; `gossip_menu`/`gossip_menu_option` DELETEs for 7222-7233 | 5 + 2 + 3 existing stock rows (emote fields on Omarion's and Tarsis' stock gossip). |
| 9 | `02_creatures` / `08_tarsis` | `DELETE FROM creature_model_info WHERE DisplayID IN (16608,16609)`; `conditions` DELETEs for SourceEntry 27892-28732 and SourceGroup 7228 | 2 + 14 existing stock rows. |

## Cleared - flagged by id scan, safe on inspection

- **`spell_script_names`, ~190 stock healing spell ids** - every DELETE is qualified
  `WHERE ScriptName = 'isAllowedToCastSpell'`, so stock rows are untouched. (The
  INSERTs do add that script to ~190 healing spells server-wide - Loatheb's
  Corrupted Mind - which is a separate scope question, not a stock-533 edit.)
- `reference_loot_template` 240160-314800, `pool_template` 47850/47870,
  `transports` entry lookups - **0 existing rows**, these are new module data.
- The `DamageModifier`/`HealthModifier`/`ArmorModifier` UPDATE is scoped
  `WHERE entry IN (SELECT id FROM creature WHERE map = 533 AND spawnMask = 4)` -
  spawnMask 4 is naxx40 only (stock Naxx is 3), and all three multipliers are 1.00.
  **Note it must run before `99_` moves those spawns to 2921, which the 01-08/99
  ordering already guarantees.**
- Large id lists in `creature_formations`, `waypoint_data`,
  `creature_template_resistance`, `creature_loot_template` are `@GUID`/`@CENTRY`
  offsets, not stock ids.

## Why some of this cannot simply be scoped

Quests, creature_templates, broadcast_text, gossip and gameobject_templates are
**global** - they are not per-map. There is no way to give map 2921 vanilla quest
text or vanilla add behaviour while map 533 keeps the WotLK version, because both
maps read the same rows. For those categories it is genuinely either/or.

Items 4, 5, 6, 7 are different: they are pure stock damage with **no benefit** to
the 40-man, because map 2921 has its own areatrigger clones (6931-6954), its own
entrance teleporter GO (361001) and its own gameobject layer (cloned in `99_`).

---

# APPLIED 2026-08-22: stock-533 guard (v3)

Policy chosen: **keep the quest layer, skip everything else that touches stock.**

Applied by `_guard.py` (statement-aware) and checked by `_validate.py`. Both are kept
in this folder - they will be needed again for the clone pass.

| file | statements disabled | INSERT rows disabled |
|---|---|---|
| `01_naxx40.sql` | 5 | 0 |
| `02_naxx40_creatures.sql` | 46 | 6 |
| `03_naxx40_gameobjects.sql` | 10 | 0 |
| `04_naxx40_frozen_runes.sql` | 1 | 0 |
| `05_naxx40_spells.sql` | 1 | 0 |

**Fourth bug (found after 01-05 were run):** spawn tables are keyed by `guid`, not by
the template `id`. Keying `creature`/`gameobject` INSERTs on `id` wrongly disabled
**149 frozen-rune gameobjects** and **112 creature spawns** whose guids are
module-owned - they are NEW spawns of stock templates, not edits to stock rows.
`OWNER` now lists `['guid', 'id']` for both tables and only the FIRST present column
is tested. The frozen-rune `UPDATE gameobject SET spawnMask = 4 WHERE id = 181287`
was likewise re-scoped (`AND guid BETWEEN 5330300 AND 5330508`) rather than disabled -
it must run, because those rows are inserted with `spawnMask = 2` (25-man normal) and
would otherwise be visible inside stock Naxxramas.

Files `07_naxx40_omarion.sql` and `08_naxx40_archmage_tarsis.sql` are renamed
`*.SKIPPED-stock533` - they exist **only** to bolt gossip/SmartAI onto stock NPCs
16365 (Omarion) and 16381 (Tarsis).

Also disabled, both introduced by the DC retarget itself:
- `UPDATE creature_template SET ScriptName='npc_tesla_40' WHERE entry = 16218`
- `UPDATE gameobject SET map = 751 WHERE map = 0 AND id IN (181056, 193166)`

**Deliberately left live:** `DELETE FROM conditions ... SourceEntry IN (27892,...)
AND ConditionValue3 BETWEEN @CGUID AND @CGUID+3`. It mentions stock spell ids but is
already narrowed to the module's own trigger guids, so it only removes rows the
module itself inserted (verified: 12 module rows vs 12 genuine stock rows for those
spells, which it leaves alone). Listed in `SAFE_SCOPED` in `_guard.py`.

## Three bugs the first guard attempt had - worth remembering

1. **Disabling a DELETE without its INSERT is worse than doing nothing.** The
   matching `INSERT ... VALUES` rows still wrote and collided:
   `SQL-Fehler (1062) Duplicate entry '13-1-28732-...' for key conditions.PRIMARY`.
2. **Scanning only the FIRST column of a VALUES row misses most stock keys.** For
   `conditions` the owner is `SourceEntry` (col 3), for `transports` it is `entry`
   (col 2). `_guard.py` now resolves the owner column **by name** from the INSERT's
   column list (see `OWNER`).
3. **Commenting the line that holds `VALUES` is not the same as disabling the
   statement.** Multi-line column lists left `INSERT INTO gameobject (id, map, ...`
   live and un-terminated, which swallowed the next statement:
   `SQL-Fehler (1064) ... near 'INSERT INTO transports'`.

Plus two parser traps that made the guard silently skip statements: MySQL
**backslash-escaped quotes** (44 in `02_`, 17 in `06_`) and **`--` comments inside
multi-line statements** whose apostrophes flipped the string-state tracker. Both are
handled by `scan_line()` now.

## State of the database after the failed partial run

Checked against `acore_backup` (world_reference): **no stock rows were damaged.**
`creature_template` values for 16157/16158/16211/16365/16381/16448/16449/16451/16775
are all still stock, `creature_template_addon` for 16448/16449/16453 matches the
reference exactly (`auras NULL`, `vdt 3`), and `transports`/`gameobject` 181056 and
`creature_text` 29941 are 0 in the reference too, so those zeros are pre-existing and
not deletions. The only rows the partial run added were module-owned; the corrected
files re-DELETE them, so a clean re-run from `01_` is safe.

Rollback: `*.pre-stockguard.bak` next to each file.

## After the 01-05 run with the over-aggressive guard

Stock was verified untouched (below), but the module's own data came in short and
left orphans:

| symptom | count |
|---|---|
| `pool_gameobject` rows pointing at a missing `gameobject` | 149 |
| naxx40 creature spawns missing (of 1061) | 112 |
| `creature_addon` rows with no `creature` | 12 |
| `creature_formations` members with no `creature` | 82 |

**Re-running 01-05 with the corrected files fixes all four** - the DELETE+INSERT pairs
for module data are intact, so the files are idempotent.
## What the 40-man loses until the clone pass

These all come from the module reusing **stock** entries rather than owning its own:

| lost | stock id(s) | effect on map 2921 |
|---|---|---|
| add tuning + SmartAI | 16157, 16158, 16448, 16449, 16451, 16452, 16453, 16697, 16775-16778, 16861 | Void Zone, Horsemen spirits, Plagued Deathhound, Necro Stalker/Guardian, Death Knight Understudy etc. run with **WotLK** stats and AI |
| Tesla Coils | 16218 | default AI during Thaddius - killable, evades. Repoint `NPC_TESLA_COIL` in `boss_thaddius_40.cpp` to a cloned entry to fix |
| Combat Dummy / Mr. Bigglesworth | 16211, 16998 | WotLK tuning |
| Omarion | 16365 | no vanilla gossip / Frostmourne-shard flow |
| Archmage Tarsis | 16381 | whole questline NPC absent |
| Meeting Stone, Naxx transport | 193166, 181056 | none - the 40-man has its own entrance teleporter (GO 361001) |
| creature_model_info | 16608, 16609 | two display bounding boxes stay stock |

**"Complete independence" therefore means cloning ~19 creature entries and 2
gameobject entries into DC id space and repointing the summon constants in the
`boss_*_40.cpp` files.** That is the scaled-up pass to do later.
