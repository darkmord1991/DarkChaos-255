# Deepholm Downport — World DB migration set (map 646)

Deterministic content downport of the Cataclysm zone **Deepholm (map 646)** from the
TrinityCore 4.3.4 dump (`cata_world`) into this fork's `acore_world`.

The terrain + client map/area DBC registration is already done (map 646 loads, `.tele deepholm`
works). These files port the **content** on top of it, in dependency order:

| File | Layer | Status |
|---|---|---|
| `01_creature_templates.sql` | creature_template + model/model_info/spell/addon/movement/equip | **this set** |
| `02_gameobject_templates.sql` | gameobject_template + gameobject_template_addon | **this set** |
| `03_item_templates.sql` | **53 missing items** (45 quest + 8 vendor); class/name/quality from retail Item.csv+ItemSparse, **`displayid` resolved from Cata `Item.db2`** (real icons) | **this set** |
| `03b_itemdisplayinfo_additions.csv` | **17 `ItemDisplayInfo` rows** (the item icons not already in `ItemDisplayInfo.csv`) — already appended to `Custom/CSV DBC/ItemDisplayInfo.csv` | **this set** |
| `03c_loot_extra_items.sql` | **100 loot + extra quest items** (TradeGoods/Recipe/Misc/Consumable/Quest/Key) that Deepholm loot/quest tables referenced but `item_template` lacked → fixes "references non-existent item" load errors | **this set** |
| `03d_itemdisplayinfo_loot_additions.csv` | **31 `ItemDisplayInfo` rows** for the 03c item icons — already appended to `Custom/CSV DBC/ItemDisplayInfo.csv` | **this set** |
| `03_items_and_spells_MANIFEST.md` | remaining spell work list (items now done in `03_item_templates.sql`) | manifest |
| `04_spawns.sql` | creature + creature_addon + gameobject + gameobject_addon spawns (guid offset + PhaseId→phasemask) | **this set** |
| `05_waypoints.sql` | waypoint_data (3 paths referenced by 04) | **this set** |
| `06_assets_manifest.md` | model bakes (creature/GO display), FactionTemplate/Lock/Vehicle DBC rows | asset track |
| `07_creature_text.sql` | creature_text (149 rows / 67 NPCs; drop SoundType) | **this set** |
| `08_loot.sql` | creature/skinning/pickpocketing/gameobject/reference loot (drop IsCurrency, no stock-ref clobber) | **this set** |
| `09_gossip.sql` | gossip_menu + gossip_menu_option (3-table denormalize) + npc_text (only new) | **this set** |
| `10_conditions.sql` | loot + gossip conditions, scoped by exact loot id / menu (identical schema) | **this set** |
| `11_quests.sql` | quest_template + addon/offer/request/details + giver links + quest_poi/points (128 quests) | **this set** |
| `12_smart_scripts.sql` | SmartAI (19 creature lines; +event_param6/+target_param4) | **this set** |
| `13_spell_area.sql` | area auras for Deepholm sub-areas (15 rows; Cata flags→autocast; excl. 5042) | **this set** |
| `14_areatriggers.sql` | areatrigger_teleport (entry) + involvedrelation + scripts (ids 6194/6126/6221) | **this set** |
| `15_script_npcs.sql` | restore Xariona ScriptName + import summon-only wyvern/fissure templates (pairs with the C++) | **this set** |
| `16_spell_script_names.sql` | links the `spell_deepholm_twilight_buffet_targeting` SpellScript to spell 95385 (apply with the spell authoring) | **this set** |
| `17_quest_objective_npcs.sql` | imports 28 summon-only quest-objective/kill-credit NPC templates the quests reference but `01` didn't spawn | **this set** |
| `18_quest_credit_logic.sql` | authored credit-granting for the determinable quest objectives (2 talk SmartAI + 1 kill credit; rest flagged) | **this set** |
| `19_spell_dbc_additions.csv` | **12 Deepholm spells** downported from the Cata 4.3.4 client into 3.3.5 `Spell.csv` format (Xariona kit 93544-93556, Twilight Buffet 95385, summon/quest spells) — already appended to `Custom/CSV DBC/Spell.csv` | **this set** |
| `20_supplemental_spawns.sql` | **Terborus** (50060 rare elite) — template from cata_world + authored spawn at the Neltharion coords (TDB shipped the template but 0 spawns) | **this set** |
| `21_quest_credit_scripts.sql` | **85 quest-credit smart_scripts** (+ timed actionlists) ported from Neltharion 4.3.4 (29→31 col remap) — the credit logic the TDB lacked; supersedes the flagged placeholders in 18 | **this set** |
| `22_credit_spell_dbc_additions.csv` | **23 trigger/cast spells** the credit scripts need (70354, 82747, the Therazane-ping chain…), downported from the Cata client — already appended to `Custom/CSV DBC/Spell.csv` | **this set** |
| `23_gameobject_densify.sql` | **31 GO placements** (30 decoration + 1 new type) from Neltharion to fill the world (excludes custom/seasonal/shared-functional); new guid block 9,330,001+ | **this set** |
| `24_spell_dbc_server.sql` | **REQUIRED server-side spells** — INSERTs the 35 Deepholm spells into `acore_world.spell_dbc` (the 234-col runtime table the worldserver actually reads). `19`/`22` (`Spell.csv`) are CLIENT-only (tooltips/visuals); without `24` the server cannot cast/resolve them. | **this set** |
| `25_spell_dbc_range_fix.sql` | live fix for `LoadSpellInfoStore` boot crash: neutralizes spell 93425's Cata-only `Effect_1=170` (> 3.3.5 `TOTAL_SPELL_EFFECTS=165`). The generator now clamps Effect≥165 / Aura≥317 → 0, so re-imports of `24` are already clean; this file only patches a DB already loaded with the pre-clamp `24`. | **this set** |
| `tools/spell_downport.py` | the reusable Cata-4.x→3.3.5 `Spell.dbc` reassembler (parses Cata Spell.dbc+SpellEffect.dbc, remaps cast/dur/range/radius indices, emits `Spell.csv` rows) | tool |

**Apply order:** `01 → 02 → 04 → 05 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 14 → 15` then `16` (with spell 95385). 06 = asset track; items/spells = extraction.

**Empty / N-A for Deepholm (no file needed):**
- Spawn pools (`pool_creature`/`pool_gameobject`): 0 Deepholm pools, and `cata_world` lacks the membership tables anyway.
- `vehicle_template_accessory`: 0 rows (the 10 vehicles carry no DB-defined passengers; rider setup is in Vehicle/VehicleSeat DBC — asset track).
- Quest-rotation pools (`quest_pool_*`): exist in `cata_world` but tie to the daily quests — deferred with the daily refinement.

## Remaining after this set (true phase 4 / storyline)
- **AreaTrigger.dbc** rows for 6194/6126/6221 (ContinentID 646 + coords) — client + `acore_dbc`; otherwise the `14_` rows are inert.
- **Storyline phasing redesign** — re-author the phase auras with correct 3.3.5 phasemask **bits** (per the PhaseId→bit map above); a straight `spell_area` import does not drive the bit-mapped storyline spawns.
- **C++ scripts** — DONE: `src/server/scripts/DC/Deepholm/zone_deepholm.cpp` (Xariona boss + Twilight Fissure + intro wyvern + Twilight Buffet SpellScript), registered in `dc_script_loader.cpp`; ScriptNames wired by `15_script_npcs.sql`. **Needs a worldserver rebuild.** The referenced spells (93544-93556, 95385) are now downported in `Custom/CSV DBC/Spell.csv` (see `19_spell_dbc_additions.csv`); the wyvern/fissure display models remain on the bake track.
- **Extraction track** — DONE (verified present in the CSV-DBC sources; the `acore_dbc` mirror was stale and over-reported gaps): 24 factions, 7 locks, 3 spellfocus, 10 vehicles, ~181/183 creature displays. Items DONE (`03_item_templates.sql`). 12 core spells DONE (`19_spell_dbc_additions.csv`). **Remaining:** ~130 creature + 44 GO model bakes; the full ~26-spell set beyond the 12 core (quest-reward / creature-aura / smart-cast spells) — addable with the same `tools/spell_downport.py` pipeline.
- **Spell downport caveats** — sourced from the Cata 4.x split DBCs whose sub-tables were unavailable in the streamed `K:\cata` client, so: `SpellVisualID = 0` (no original cast visuals) and the cooldown/level/proc/interrupt/target-restriction/category fields are defaulted (the boss AI controls cadence, so spells are functional). Effects, school, cast/duration/range/radius indices are exact.

### Spawn GUID blocks (reserved)

| Table | Cata guid range (map 646) | Fixed offset | New block |
|---|---|---|---|
| `creature` / `creature_addon` | 340743–396407 | `+9059257` | **9,400,000 – 9,460,000** |
| `gameobject` / `gameobject_addon` | 200868–224294 | `+9099132` | **9,300,000 – 9,330,000** |

### PhaseId → phasemask bit map (used by 04 and again in the P3 storyline)

`169` base → **1** (visible) · `170`→2 · `187`→4 · `237`→8 · `251`→16 · `252`→32 · `253`→64 · `254`→128 · `257`→256.
Storyline bits (2…256) are hidden from a base player (phasemask 1) until P3 grants the matching phase.

## How these files work (read before importing)

- They are **cross-schema `INSERT ... SELECT FROM cata_world.*`**. The mapping (Cata column →
  this fork's normalized column) is therefore explicit and auditable in the SELECT list itself.
- **Prerequisite: `cata_world` must exist on the same MySQL server at import time.** It is only
  read, never written. After import the rows are materialised into `acore_world` permanently;
  `cata_world` can then be dropped. (To freeze a self-contained dump later:
  `mysqldump acore_world <tables> --where="..."` — not required for normal use.)
- Each statement is **idempotent**: `DELETE` (scoped to the Deepholm-new id set) precedes every
  `INSERT`, so re-running re-imports cleanly. `creature_model_info` uses `INSERT IGNORE` (shared
  display ids with stock — never clobbered).
- Import target is the **world DB**. The MCP SQL endpoint is read-only; apply these with your
  normal world-DB import path (or `mysql acore_world < 01_creature_templates.sql`).

## ID strategy — keep retail ids

Deepholm's retail entry ids are conflict-free in this fork, so they are kept verbatim
(creatures 6491–53894, GOs 191707–208261, quests 26244+, items 58168+). This lets every
cross-reference (loot, quests, spawns) resolve without a remap table.

**Shared/stock rows are excluded from import** so server-wide infrastructure is never overwritten:

- Creatures (6): `6491` Spirit Healer, `23837`/`24110`/`24288`/`25670` ELM bunnies, `28332` Generic Trigger LAB.
- GameObjects (2): `191707`, `204968`.

The Deepholm spawns that reference these will resolve against the existing stock templates.

## Transform decisions (creatures)

| Concern | Decision |
|---|---|
| Inline `modelid1-4` → `creature_template_model` | one row per non-zero slot; `DisplayScale = scale`, `Probability = 1` |
| `creature_model_info` | pulled from `cata_world.creature_model_info` for used display ids, `INSERT IGNORE` |
| Inline `resistance1-6` → `creature_template_resistance` | **0 rows** (no Deepholm creature has resistances) — table untouched |
| Inline `spell1-8` → `creature_template_spell` | 1 row (only one creature carries a template spell) |
| `exp` (expansion) | **`LEAST(exp,2)`** — Deepholm carries `exp=3`; this fork's `creature_classlevelstats` is keyed `(level,class)` with `basehp0/1/2`, where `exp` selects the column. `3` would yield null stats. |
| `speed_swim` / `speed_flight` / `detection_range` | Cata `creature_template` has no source columns → defaults `1 / 1 / 0` |
| Dropped Cata-only columns | `femaleName, exp_unk, trainer_*, type_flags2, *ModifierExtra, mechanic_immune_mask, spell_school_immune_mask` |
| `CreatureImmunitiesId` | set `0` for all. Exactly **1** creature (a boss) had an immunity mask — re-added with the P3 script pass; negligible until then. |
| `creature_template_addon` | `waypointPathId → path_id`; dropped `cyclicSplinePathId, aiAnimKit, movementAnimKit, meleeAnimKit`. `auras` copied verbatim (a few reference Cata spells absent in 3.3.5 → harmless load warnings until `04_spells`). |
| `creature_template_movement` | added `Chase` (default `0`); Cata lacks it |
| `ScriptName` | `npc_stable_master` kept (stock AC); `npc_deepholm_xariona` blanked (custom C++, ported in P3) |

## Known gaps handed to later phases

- **Display models**: ~130 creature + 44 GO display ids are Cata-new and need the retroport
  bake (model file + `CreatureDisplayInfo`/`GameObjectDisplayInfo` DBC rows) before they render.
  Until then those creatures/GOs spawn and are interactable but show a placeholder/error model.
  Tracked in `05_assets_manifest.md`.
- **Factions**: DONE — all 24 Cata `FactionTemplate` ids are present in `Custom/CSV DBC/FactionTemplate.csv` (the `acore_dbc` MySQL mirror is stale and falsely reported them missing).
- **Spells / auras**: 12 core spells DONE (`19_spell_dbc_additions.csv` → `Spell.csv`). The remaining ~14 (quest-reward / aura / smart-cast) are addable via `tools/spell_downport.py` once their ids are enumerated.
- **KillCredit / difficulty_entry**: kept verbatim; any credit-proxy creatures not on map 646 are
  reconciled in the quest phase.
