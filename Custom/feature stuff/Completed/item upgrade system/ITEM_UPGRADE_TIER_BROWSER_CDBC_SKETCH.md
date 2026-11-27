# Item Upgrade Tier Browser CDBC Sketch

## Goal

Define the smallest useful custom CDBC mirror for a client-native item-upgrade
tier browser while keeping SQL authoritative for runtime behavior.

This sketch is intentionally narrow. It is not a proposal to move live item
upgrade state, live costs, or season toggles into client data files.

## Decision

Use custom CDBCs only for static browser metadata:

- tier labels and presentation metadata that every client shares,
- optional item-to-tier browse mappings if those mappings are stable enough to
  ship in the patch bundle,
- no live upgrade state,
- no live cost matrix,
- no per-player availability logic,
- no runtime authority transfer from SQL to client data.

## Recommended Files

### 1. `DCItemUpgradeTier.cdbc`

Purpose:

- populate a native tier list,
- drive stable tier labels, icons, color, and sort order,
- avoid duplicating tier display constants in Lua.

Suggested fields:

| Field | Type | Notes |
| --- | --- | --- |
| `ID` | int | Primary row id, usually same as `tier_id` |
| `TierID` | int | Canonical server tier id |
| `Season` | int | Static season grouping for browser filtering |
| `SortOrder` | int | Native list ordering |
| `Flags` | int | Reserved for browser behavior bits |
| `MinItemLevel` | int | Static browse metadata |
| `MaxItemLevel` | int | Static browse metadata |
| `MaxUpgradeLevel` | int | Display only; server still validates |
| `SourceContent` | int | Optional source bucket enum |
| `IsArtifact` | int | `0/1` |
| `IconFileDataID` | int | Optional icon or visual id |
| `ColorARGB` | int | Optional native tint or tag color |
| `Name` | string | Client display label |
| `Description` | string | Client display description |

Notes:

- `Name` and `Description` are the main reason this table is worth shipping.
- `MaxUpgradeLevel` can be mirrored for display, but server SQL still owns the
  truth used by upgrade execution.

### 2. `DCItemUpgradeTierItem.cdbc`

Purpose:

- let the client browse item membership by tier without asking the server for a
  full static catalog,
- support fast native filters such as “show all tier 2 items”.

Suggested fields:

| Field | Type | Notes |
| --- | --- | --- |
| `ID` | int | Stable row id |
| `TierID` | int | References `DCItemUpgradeTier.TierID` |
| `ItemID` | int | Base item entry, not clone entry |
| `SortOrder` | int | Stable browser order |
| `Flags` | int | Reserved bits for future browse-only tags |
| `Quality` | int | Optional denormalized filter helper |
| `InventoryType` | int | Optional denormalized filter helper |
| `ItemLevel` | int | Optional denormalized filter helper |

Notes:

- This table is only worth shipping if the tier-to-item mapping is mostly
  patch-static.
- If the mapping changes often during a season, keep it server-driven instead.
- If `dc_item_upgrade_tier_items` stays mostly a tooling or schema table and is
  not active runtime authority, it is the safest candidate to mirror.

## What Must Stay In SQL

Keep these server-authoritative:

- `dc_item_upgrade_tiers` as the live source for tier definitions used by the
  runtime manager,
- `dc_item_upgrade_costs` as the live source for token and essence cost logic,
- any season activation or deactivation switches,
- any per-player unlock, eligibility, or upgrade state,
- any tooltip snapshot payload derived from the actual item instance.

Why:

- the current runtime loads `dc_item_upgrade_tiers` and
  `dc_item_upgrade_costs` from SQL once per season,
- addon and native upgrade flows still validate against server-side data,
- custom CDBCs ship with the client patch and are not a live sync mechanism.

## Export Model

Recommended source-of-truth flow:

1. Author and review canonical data in SQL.
2. Export stable browser rows into CSV under `Custom/CSV DBC/CDBC/`.
3. Generate `.cdbc` binaries into `Custom/CDBCs/`.
4. Keep the shipped binaries in `Custom/CDBCs/` - their only home - and deploy to patch-4
   with `mpq_stormlib_patch.py --set <file>=DBFilesClient\<name>.cdbc`. Do not mirror them
   into the client staging tree; a second copy just becomes a second source of truth.

Recommended future tool:

- `tools/generate_dc_item_upgrade_cdbc.py`

Recommended outputs:

- `Custom/CSV DBC/CDBC/DCItemUpgradeTier.csv`
- `Custom/CSV DBC/CDBC/DCItemUpgradeTierItem.csv`
- `Custom/CDBCs/DCItemUpgradeTier.cdbc`
- `Custom/CDBCs/DCItemUpgradeTierItem.cdbc`

## Client Usage Boundary

Safe native browser uses:

- populate a browse pane,
- render tier badges and descriptions,
- filter base items by tier locally,
- avoid shipping large repeated static Lua tables.

Unsafe uses that should not be allowed:

- calculating live upgrade affordability,
- deciding upgrade eligibility,
- calculating live item level or stat deltas,
- replacing the server response for the selected item,
- assuming shipped CDBC state is current if SQL changed after the client patch.

## Stage Gates

Use these gates if this moves forward:

1. Confirm whether `dc_item_upgrade_tier_items` is stable enough to ship per
   patch and not expected to change frequently from SQL only.
2. Add client browser code that treats the CDBC tables as optional browse data,
   not as upgrade authority.
3. Keep the current server-native upgrade and tooltip paths authoritative for
   selection, affordability, and execution.
4. Add a clear stale-client fallback: if the CDBC is missing or mismatched,
   disable only the native tier browser and keep the server-driven upgrade flow.

## Recommended Scope

Start with `DCItemUpgradeTier.cdbc` only.

Reason:

- it carries the highest-value static presentation data,
- it has low churn,
- it avoids overcommitting to a shipped item-membership catalog before the
  tier-to-item mapping policy is finalized.

Add `DCItemUpgradeTierItem.cdbc` only after confirming that the tier-item
mapping is patch-static enough to justify client distribution.