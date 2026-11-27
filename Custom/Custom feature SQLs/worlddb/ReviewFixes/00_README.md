# DB review fixes — Hyjal (750) + Plaguelands (751)

Generated from a full DB review (spawns vs nelt_world, movement, flying, loot/quest items, integrity).
All counts verified read-only against the live acore_world. Apply to acore_world, **in this order**,
then `.reload` (or restart) so the server picks up creature_template_movement / creature_addon /
waypoint_data / smart_scripts.

## Apply order
1. **review_zone_items.sql** — PART A only is pure SQL (7 missing items cloneable from nelt_world,
   unblocks 5 quests). PART B/C are NOT SQL — see "Item gap" below. **The 140 other missing items are
   the main blocker (94 break quests).**
2. **review_flying_npcs.sql** — restores `creature_template_movement` Flight (the clone created 0 rows;
   all flight was lost). Idempotent. ~8 acore-stock + ~42 nelt-derived flyers.
3. **review_npc_movement.sql** — the PROPER waypoint fix: re-ports 59 cata paths (927 points) under
   collision-free path ids (+100,000,000) + 59 creature_addon rows for the 61 idle waypoint NPCs.
4. **review_data_integrity_750_751.sql** — run **AFTER** #3. Clears AIName on 2 stray GO templates;
   its waypoint **demotion** stop-gap is guarded to touch ONLY the 2 NPCs with no path in any source.
   ⚠️ **Do NOT apply the demotion to the 59 NPCs fixed in #3 — the two remedies are mutually exclusive.**
5. **review_hyjal_nelt_gap.sql** — OPTIONAL enrichment (Neltharion-only Hyjal content). USER DECISION on
   tier (see below). Apply LAST and only at the chosen tier.

## Item gap (the blocker — needs the item pipeline, not SQL)
140 of 147 missing item ids exist only in the 4.3.4 **client** Item DB2/DBC (cata_world has no
item_template). Fix = run `tools/downport-item.js` against the K:\Cata 4.3.4 client Item DBCs to emit
item_template rows + the matching client Item DBC + icons (same pipeline used for the 15.5k-item downport).
94 of these are quest StartItem/RequiredItem → those questlines can't be completed until imported.
Also rebuild 10 missing reference_loot_template entries.

## Manual / by-hand
- 5 `smart_scripts` rows (entryorguid 3638913/3638915/3638926/3643427) use target_type=11 with a CATA
  entry instead of an acore guid — repoint each to the +3.6M clone (or target_type=19 closest_creature).
- 2 waypoint NPCs (dc guid 9832309 / 9832405) have no path even in cata — leave idle or demote.