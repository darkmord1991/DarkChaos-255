# Deepholm Downport — Items & Spells extraction manifest

Unlike creatures/gameobjects, **items and spells cannot be cross-schema `INSERT ... SELECT`
ports**: `cata_world` has **no `item_template`** (Cata items live in the retail
`Item-sparse.db2`, not in the TDB dump), and the Deepholm spells are Cata-era ids absent from the
3.3.5 client `Spell.dbc`. Both go through the **retail DB2 → CSV-DBC** pipeline
(`tools/db2-decode.js` + the `Custom/CSV DBC/` round-trip), not SQL. This file is the work list.

## Items — missing entries (keep retail ids)

**Confirmed missing from `acore_world.item_template`** (quest StartItem + RewardItem1-2 +
RewardChoiceItem1-2 + vendor items; the full set ≈49 once RewardItem3-4 / ItemDrop1-4 /
RewardChoiceItem3-6 are added — re-run the query in this file's commit message to expand):

```
58169, 58177, 58254, 58502, 58884, 58885, 58965, 60266, 60382, 60490, 60501, 60504,
60758, 60773, 60810, 60816, 60831, 60834, 60835, 61437, 61440, 62321, 62333, 62342,
62343, 62344, 62345, 62346, 62347
```

(8 of these are vendor items; the rest quest start/reward/choice items. `creature_equip`
weapon items = **0 missing** — equipped gear already resolves.)

### Recipe
1. `node tools/db2-decode.js --install "<retail>" --table ItemSparse --out ItemSparse.csv`
   (and `Item.csv` for class/subclass/displayid, `ItemDisplayInfo` for appearances).
2. Generate `item_template` rows (3.3.5 schema) for the ids above. Functional fields
   (class, subclass, quality, name, bonding, required level, stackable, flags) map directly;
   3.3.5-removed Cata fields are dropped; `ScalingStatDistribution`/`StatsCount` collapse to the
   fixed `stat_type1-10`/`stat_value1-10` block.
3. **Visible gear** (armor/weapon rewards): appearance via the Wraith item-downport pipeline
   (see `Custom/Documentation/Item_Downport_Wraith_Pipeline.md`); the wardrobe auto-indexes by
   displayid. Functional-only quest items (tokens, fragments) need no display work.
4. Output as `03_item_templates.sql` (plain `DELETE`+`INSERT VALUES`, self-contained — no
   `cata_world` dependency since the source is the DB2).

### Placeholder currency (Molten Front)
3.3.5 `quest_template` has no currency columns, so retail **currency 416 (Mark of the World Tree)**
rewards are dropped on those quests. Per the project decision, substitute a **placeholder item
currency** (a normal `item_template` token) as the reward where a currency was expected. This is a
quest-phase edit; only the ~24 Molten Front dailies use it, and those are descope/optional anyway.

## Spells — missing entries (keep retail ids)

**Quest reward/display spells absent from 3.3.5** (6): `83483, 84069, 84153, 93425, 100168, 100562`.
Plus **1** creature template spell (from `creature_template_spell`) and the
areatrigger/`spell_area`/script-cast spells, which surface in the quest & script phases (the C++
`zone_deepholm` spells, e.g. the Xariona fight, are P3).

### Recipe
1. `cata_world` **has `spell_dbc` (4,433) + `spelleffect_dbc` (2,936)** — check each missing id
   there first (`SELECT * FROM cata_world.spell_dbc WHERE ID IN (...)`); rows found are a ready
   source for the Spell.dbc fields and effects.
2. For ids not in `spell_dbc`, decode from retail: `db2-decode.js --table Spell` (+ SpellName,
   SpellEffect, SpellMisc, SpellVisual).
3. Author rows into the `Custom/CSV DBC/` Spell set (same pipeline as the GT-DBC-255 work); keep
   retail spell ids (no collision with DC's 300xxx/800xxx custom ranges).
4. **SpellVisual caveat:** Cata visual ids don't exist in the 3.3.5 client — substitute the nearest
   WotLK SpellVisual or the effect is silent/invisible. Only player-readable effects (the boss
   fight) need careful visuals; reward "ding" spells can use a generic visual.

## Status

| Item | State |
|---|---|
| Missing item id list | captured above (expand to full ~49) |
| `item_template` SQL generation | **pending DB2 extraction** (external `db2-decode` step) |
| Spell id list | captured above (6 quest + 1 creature; script/AT spells in later phases) |
| `Spell.csv` rows | **pending** (seed from `cata_world.spell_dbc` where present) |
