# DC Random Enchants

## Overview

The DC Random Enchants subsystem applies up to three random enchantments to
newly acquired armor and weapon items.

This implementation is an integration port of
`azerothcore/mod-random-enchants` into the native DC script stack.

## Integration points

- Script: `src/server/scripts/DC/RandomEnchants/dc_random_enchants.cpp`
- Loader: `src/server/scripts/DC/dc_script_loader.cpp`
- Build registration: `src/server/scripts/DC/CMakeLists.txt`
- Config section: `Custom/Config files/darkchaos-custom.conf.dist`
- SQL seed: `Custom/Custom feature SQLs/worlddb/RandomEnchants/2026_04_09_00_dc_random_enchants.sql`

## Configuration

Primary config prefix:

- `DC.RandomEnchants.*`

Legacy compatibility prefix (still read as fallback):

- `RandomEnchants.*`

Default quality gate:

- `DC.RandomEnchants.MinQuality = 2`
- `DC.RandomEnchants.MaxQuality = 5`

This means random enchants apply to uncommon+ gear by default.

## Data source

The system reads from:

- `dc_item_enchantment_random_tiers`

Rows are cached at config load/reload for runtime lookup.

## Behavior notes

- Enchants are applied in `PROP_ENCHANTMENT_SLOT_0..2`.
- This avoids collisions with permanent, temporary, and bonus enchant slots.
- Existing random-property/suffix items are skipped by default.
- Enchant rolls are chained: roll #2 requires #1 success, roll #3 requires #2.

## Hook sources

- Looted item
- Created item
- Quest reward item
- Group roll reward item

All hooks are controlled by config toggles.

## Upstream issues fixed in DC port

- Fixed invalid SQL filter logic from upstream implementation.
- Removed fragile `item->IsInWorld()` gate that could skip valid items.
- Avoided permanent/temp slot collisions by using dedicated random-property slots.
- Added config clamping and stronger runtime validation.
- Added duplicate-enchant prevention per item roll.
- Added startup cache loading and diagnostics.

## Reroll service

Players can pay to change their lines from the **Random Enchants** panel of
the item upgrade window (button above Items / Tiers, or `/dcenchants`):

- **Reroll** one line: a new enchant from the same tier pool, never one the
  item already holds. The other lines are kept.
- **Reroll All**: every line at once, priced as rerolling them one by one.
- **Add**: fills the first empty line, up to `MaxEnchantsPerItem`, without the
  chance roll.

Price (`DC.RandomEnchants.Reroll.*`): the item's upgrade currency by default
(Upgrade Tokens for tiers 1/2, Emberwood Sap for the Hyjal tiers). A line costs
`Cost + CostIncrease x earlier rerolls of this item`, capped at `MaxCost`;
adding costs `AddCost x lines after the add`. Both are multiplied by
`QualityCostFactor`, and optional gold (`MoneyCost`, `AddMoneyCost`) is
charged on top. Rerolls are refused in combat (`BlockInCombat`), and items
with a random suffix are never eligible.

Each item can have `MaxRerolls` lines rerolled in its lifetime (default 15,
0 = unlimited). Reroll All uses one per line and is refused when fewer are
left; adding a line uses none. The panel shows how many are left.

Every request carries the lines the panel showed. If they changed meanwhile,
nothing is charged. New lines are rolled before anything is charged. The
currency, gold, enchants, reroll count and log row are written in one
characters-DB transaction.

- Service: `src/server/scripts/DC/RandomEnchants/dc_random_enchants_reroll.cpp`
  (API in `dc_random_enchants.h`)
- Protocol: `src/server/scripts/DC/AddonExtension/dc_addon_enchant_reroll.cpp`,
  module `UPG`: `0x22` / `0x23` requests, `0x33` / `0x34` answers
- Panel: `Custom/Client addons needed/DC-ItemUpgrade/EnchantReroll.lua`
  (test: `_tests/test_enchantreroll.lua`)
- Tables (characters DB): `dc_item_random_enchant_rerolls` (count per item),
  `dc_item_random_enchant_log` (lines before and after, price)

## Tooltip verification checklist

1. Acquire a qualifying item (weapon/armor, quality within configured range).
2. Confirm green enchant lines appear on the item tooltip.
3. Confirm permanent enchants (if any) remain unaffected.
4. Confirm items with existing random suffix/property are skipped when
   `DC.RandomEnchants.SkipIfRandomPropertyPresent = 1`.
5. Enable `DC.RandomEnchants.Debug = 1` and verify load/apply logs.
