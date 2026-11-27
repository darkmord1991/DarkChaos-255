# Worldforged pickups on maps 750 / 751

Ascension CoA's "worldforged" pickups (a sack, crate, corpse... named after the one item it holds, lootable
once per character) transplanted onto DC's 80-160 levelling continents, with every item cloned and
re-levelled to the DC zone band it lands in.

| | |
| --- | --- |
| Spawns | 643 on maps 750 (Kalimdor copy) and 751 (Eastern Kingdoms copy), CoA X/Y kept, height from DC's terrain or CoA's structure height (guids 6900001-6900715; 72 retired) |
| Props | 16 decoration props beside 5 pickups (guids 9028001+, templates 5001001+, type 5, no script or loot), from CoA's restored Ascension props |
| Items | 704 clones (504001+), ilvl 278-454 / RequiredLevel = zone band low, 309_/312_ stat model, Cata armor/damage curves |
| Objects | 704 chest templates (5000001+), lock 1689 (Open), non-consumable, one loot row each |
| Displays | 135 new ItemDisplayInfo rows (200001+), 124 new GameObjectDisplayInfo rows (200001+); 347 asset files from the Ascension client |
| Rule | `src/server/scripts/DC/Worldforged/dc_worldforged_pickups.cpp`: one bit per spawn guid in the character's `dc-worldforged` character_settings row; claimed pickups are hidden from that character. A prestige with `Prestige.FreshStart = 1` clears the row (`DCWorldforged::ResetClaims`), like it hands the zone quests back |
| Bots | loot pickups like players (one claim per bot character) when their loot strategy passes one; `mod-playerbots` `LootObject::IsLootPossible` skips objects a bot cannot see, so a claimed pickup drops off its loot list |

## Files

| File | Role |
| --- | --- |
| `gen_worldforged_750_751.py` | the generator: replay -> placement -> items -> pinned ids -> SQL + client DBC rows |
| `coa_replay.py` | replays CoA's ~40 worldforged migrations into SQLite (the final state exists in no single file) |
| `dc_terrain.py` | reads `K:/Dark-Chaos/Server/data/maps/*.map` exactly like `GridTerrainData` (area, height, holes, liquid) |
| `wdbc.py`, `mpqset.py` | DBC reader; read-only StormLib access to a whole client |
| `validate_sql.py` | arity / token / id-block / reference checks on the generated SQL; a `--delta` file is checked against the shipped state, and the state it leaves is checked whole |
| `stage_assets.py` | resolves every file the new displays need; stages what DC lacks from the Ascension client |
| `apply_client_dbc.py` | appends the new rows to `Custom/CSV DBC` + `Custom/DBCs` (Item, ItemDisplayInfo compiled; GameObjectDisplayInfo appended to the binary) |
| `data/allocation.csv` | **pinned id allocation - append-only.** The spawn guid is the claim key; renumbering a spawn hands every character's claim to a different pickup |
| `data/witness_results.json` | DC creature/GO spawns near each off-surface CoA spot (cave floors, buildings), queried read-only via ACMCP: `[coa guid, near, within 4 yd of its height, closest dz, highest such z, x, y, z]`. The last three are the spot the row answers for; once CoA moves the pickup the row no longer counts |
| `data/position_overrides.csv` | positions pinned by spawn guid (x, y, z, facing, area): in-game checks, and spots where a CoA height is wrong on DC's terrain. A re-run keeps them |
| `data/excluded_spawns.csv` | CoA pickups DC does not place (`coa_guid,note`): a same-item twin CoA left spawned, and the like |
| `data/retained_spawns.json` | placements DC keeps although CoA dropped the spawn (frozen as last placed, with the reason). Used only while CoA's current data does not place that spawn itself |

Inputs outside the repo: CoA checkout `K:/Dark-Chaos/Ascension COA/azerothcore-wotlk-coa` (the shipped data
follows CoA through commit f2b8382283, 2026-11-27), Ascension client
`K:/UntouchedClients/ascension_live`, Cata curve DBCs `K:/tmp/cata-itemcurves`, server maps
`K:/Dark-Chaos/Server/data/maps`. The work dir needs Ascension's DBCs in `asc_dbc/`:

    python K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py --mpq "K:/UntouchedClients/ascension_live/Data/patch-M.MPQ" --out <work>/asc_dbc --file "DBFilesClient\ItemDisplayInfo.dbc" --file "DBFilesClient\GameObjectDisplayInfo.dbc" --file "DBFilesClient\Item.dbc"

## Re-running

    python gen_worldforged_750_751.py --work K:/tmp/worldforged_build            # dry run + report
    python gen_worldforged_750_751.py --work K:/tmp/worldforged_build --write    # SQL, rows, allocation
    python validate_sql.py <the rev_..._worldforged_750_751.sql> K:/tmp/worldforged_build
    python stage_assets.py --work K:/tmp/worldforged_build --write
    python apply_client_dbc.py --work K:/tmp/worldforged_build --apply           # idempotent

`--write` alone rewrites the full `rev_*_worldforged_750_751.sql`. That file is applied and archived in
`Custom/Custom feature SQLs/worlddb/worldforged/`, so changes ship as deltas: `--write --delta <name>` replays the
archived files (plus any pending worldforged file) and writes only what differs as
`pending_db_world/rev_<ns>_worldforged_<name>.sql`: retired spawns deleted, moved and new spawns re-inserted
whole, new or changed templates, loot, items and display overlays. Item rows are never deleted (characters
hold them). `--note <file>` puts the reasons on top of the generated header.

## Following a CoA update

CoA keeps re-placing its pickups. Folding one of its commits in (4c444c986 on 2026-10-07; 29f4e9fe1 on
2026-10-28 as `rev_1793176972459952000_worldforged_coa_29f4e9fe.sql`; b39aa8618 on 2026-11-08 as
`rev_1794127168116483000_worldforged_coa_b39aa861.sql`; 354580d8b on 2026-11-11 as
`rev_1794427019919664200_worldforged_coa_354580d8.sql`; 4e63153edd on 2026-11-23 as
`rev_1795427429705115800_worldforged_coa_4e63153e.sql`, the first with props; 43cd939a51 on 2026-11-24 as
`rev_1795529671189503200_worldforged_coa_43cd939a.sql`; 0954ce1d28 on 2026-11-27 as
`rev_1795771994570467600_worldforged_coa_0954ce1d.sql`; f2b8382283 on 2026-11-27 as
`rev_1795804795776340400_worldforged_coa_f2b83822.sql`):

1. In the CoA checkout, `git archive <commit> modules/mod-worldforged-pickups/data/sql/db-world
   data/sql/updates/pending_db_world | tar -x -C <extract>`, then
   `python coa_replay.py <work>/coa_wf_<commit>.sqlite <extract>`. Keep the old `<work>/coa_wf.sqlite` as
   `coa_wf_<old commit>.sqlite` and copy the new replay over it.
2. Dry run. Where a spawn's height depends on a witness and no row answers for its current spot, the generator
   stops and writes `<work>/witness_query.sql`: run it read-only (ACMCP `query_database`, world), save the
   `j` array as JSON and pass it to `--merge-witness`, then dry-run again.
3. Check each witnessed height before keeping it: a creature standing on DC's own ground 15-25 yd away on a
   slope is not a floor. Compare CoA's height with DC's terrain at the witness's own spot, and read the CoA
   migration that set it (its comment usually names the floor). Pin judgment calls in
   `data/position_overrides.csv`.
4. Spawns CoA no longer places in a DC zone are retired by the delta unless `data/retained_spawns.json` keeps
   them. 29f4e9fe kept the 155 wrong-zone copies whose item had no other DC pickup and retired the 64 whose
   item did.
5. `--write --delta coa_<commit> --note <file>`, then `validate_sql.py` on it, `stage_assets.py --write` into an
   empty `<work>/assets_stage` (move the previous one aside first; it is not cleared) and
   `apply_client_dbc.py --apply`.

## Placement rules

* Map 1 -> 750 and map 0 -> 751 keep X/Y (both DC maps are coordinate-preserving). Only CoA spawns whose
  stock source zone DC represents are used: buffer chunks folded into a DC band (Durotar -> Azshara,
  Barrens/Stonetalon -> Ashenvale, Wetlands -> Arathi) stay empty, as DC's own spawns do.
* Height: where DC kept the stock terrain (both within 0.1 yd) and CoA's height is above it -> CoA's height
  (a floor, table, crate or tower; CoA snapped its floating pickups to the terrain in 10-06 and checks the rest
  in game - adopted 2026-11-08, 123 pickups moved up). The same holds over a hole in the terrain that both maps
  share (a castle floor model; since 2026-11-24). Otherwise: on DC terrain within 3 yd -> terrain; a DC
  creature/GO within 25 yd at the same height (+/-4) ->
  CoA's height (a cave or floor that still exists); otherwise snapped to the surface (up to 12 yd below it)
  or onto a shallow sea floor (<= 6 yd of water). Deep water (Cata's flooded coasts), caves nothing confirms
  and terrain holes are dropped.
* Props: since 2026-11-12 CoA restores Ascension's decoration props beside some pickups (its guid block
  6976000-6979999, type 5). A prop belongs to the nearest spawned pickup within 15 yd and is placed only beside a
  pickup DC places from CoA's current data (not a retained copy, not a pinned one). It moves with its pickup's
  height change, or keeps its height above the ground where DC changed the terrain under it. Props use their
  own id blocks, outside the pickup block: the C++ sizes every account's claim words by the highest guid there.
* A pickup is a type-3 template with ScriptName `worldforged_pickup` whose spawn row names the same script or none
  (an empty spawn ScriptName takes the template's; CoA writes some new spawns that way since 2026-11-25).
* A spawn CoA hides (`spawnMask` without bit 1, or `phaseMask` 0) counts as dropped: since 2026-11-07 CoA hides
  misplaced duplicates that way instead of deleting them.
* Gear only: bags, food, recipes, pets, grey/white items and statless jewelry are left out (their effects were
  Ascension-only spells). Ascension's "PvE/PvP Power" spells and scripted procs are dropped; only spells that
  exist identically in DC (Fishing +5, Find Fish) are kept.

## Deploying (user-side steps)

1. **World DB**: apply `data/sql/updates/pending_db_world/rev_*_worldforged_750_751.sql`. It carries
   `item_dbc` / `itemdisplayinfo_dbc` / `gameobjectdisplayinfo_dbc` overlay rows, so the server side works
   without the DBC files. `EnablePlayerSettings = 1` is required (the startup log errors otherwise).
2. **Worldserver**: re-run CMake (new folder `src/server/scripts/DC/Worldforged/`) and rebuild.
3. **Client DBCs**: `Custom/DBCs/Item.dbc`, `ItemDisplayInfo.dbc`, `GameObjectDisplayInfo.dbc` into
   `Data/patch-4.MPQ`, `Data/enGB/patch-enGB-3.MPQ` and `Data/enGB/patch-enGB-4.MPQ` (all three held identical
   copies before this change), e.g. with `mpq_stormlib_patch.py --set-file` (add `--off-layout` for the enGB
   archives); `node sync-dbc-deploy.js --files Item.dbc,ItemDisplayInfo.dbc,GameObjectDisplayInfo.dbc`.
4. **Client assets**: `python K:/Dark-Chaos/retroport_tools/dc_mpq_deploy.py --stage K:/tmp/worldforged_build/assets_stage --data "K:/WoW_3.3.5a_ 255 Fun/Data" --apply`
   (337 files -> patch-5/6/8/9/B/D/H, all new paths). Close the client first.
5. **Server DBC files** (optional, the overlays cover it): copy the same three DBCs to the server's `data/dbc`.

A delta deploys the same way: its pending file in step 1, steps 3-5 when it adds items or displays (step 4 with
that run's `assets_stage`, which holds only the new files), step 2 only when the C++ changed.

Test: as a GM every pickup is visible; as a player an unclaimed pickup sparkles, opens once, then disappears
for that character only. To reset a character (offline):
`DELETE FROM character_settings WHERE guid = <character guid> AND source = 'dc-worldforged';`
