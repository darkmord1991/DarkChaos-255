# DC SQL Drift Report

Date: 2026-05-21

## Scope

This pass compares live `dc_` tables in `acore_world` and `acore_chars`
against active runtime references in:

- `src/**`
- `Custom/Eluna scripts/**`

SQL files, schema snapshots, docs, and comment-only mentions were not counted
as active runtime use.

Ambiguous matches were manually verified before being classified below.

## Summary

The live database currently contains three distinct drift classes:

1. Schema-duplicate tables where only one schema copy is actively used.
2. Live base tables with no active runtime consumer in current code.
3. Live derived views/reporting objects that are present but not queried by the
   current runtime.

Some tables were intentionally excluded from the drift set because they are
still active, or because they are only low-frequency/archive/diagnostic paths
and need an explicit owner decision before removal.

## Confirmed Schema-Duplicate Drift

These names exist live in both schemas, but current runtime code uses only one
side as the effective authority.

| Table | Live Rows | Active Authority | Drift Assessment |
|---|---:|---|---|
| `dc_seasons` | world=`0`, chars=`0` | `acore_world` | `acore_chars.dc_seasons` is a legacy duplicate. `SeasonalSystem.cpp` reads and writes `dc_seasons` through `WorldDatabase`. |
| `dc_player_seasonal_chests` | world=`0`, chars=`395` | `acore_chars` | `acore_world.dc_player_seasonal_chests` is an unused duplicate. `SeasonalRewardSystem.cpp` uses `CharacterDatabase` for chest state. |
| `dc_player_seasonal_stats` | world=`0`, chars=`2525` | `acore_chars` | `acore_world.dc_player_seasonal_stats` is an unused duplicate. `SeasonalRewardSystem.cpp`, `dc_addon_seasons.cpp`, and leaderboards read the chars table. |
| `dc_player_seasonal_stats_history` | world=`0`, chars=`0` | `acore_chars` | `acore_world.dc_player_seasonal_stats_history` is an unused duplicate. Archive writes happen on the chars side. |
| `dc_player_weekly_cap_snapshot` | world=`0`, chars=`5813` | `acore_chars` | `acore_world.dc_player_weekly_cap_snapshot` is an unused duplicate. Weekly snapshot writes happen in `SeasonalRewardSystem.cpp` on `CharacterDatabase`. |
| `dc_mplus_dungeons` | world=`17`, chars=`16` | `acore_chars` | Current addon/runtime queries hit the chars table via `CharacterTableExists("dc_mplus_dungeons")` and chars-side joins. The world copy looks like a stale seed/legacy mirror. The row-count mismatch (`17` vs `16`) is drift evidence. |
| `dc_item_upgrade_costs` | world=`21`, chars=`5` | `acore_world` | Item upgrade cost lookups run through `WorldDatabase` in `ItemUpgradeManager.cpp` and `dc_addon_upgrade.cpp`. The chars copy is a stale duplicate with fewer rows. |

### Explicitly Excluded Duplicate

| Table | Live Rows | Reason Excluded |
|---|---:|---|
| `dc_collection_shop` | world=`23`, chars=`23` | Current collection code intentionally supports either schema. `dc_addon_collection.cpp` prefers the chars table and falls back to world. This is dual-home behavior, not confirmed drift. |

## Confirmed Live Base Tables With No Active Runtime Consumer

These tables are present live but have no verified active runtime read/write
path in current code.

### World

| Table | Type | Live Rows | Notes |
|---|---|---:|---|
| `dc_collection_achievement_defs` | BASE TABLE | `0` | SQL-defined collection metadata table with no current runtime consumer. |
| `dc_heirloom_stat_packages` | BASE TABLE | `0` | Present in schema and SQL views/export logic, but not used by current runtime code. |
| `dc_item_upgrade_synthesis_inputs` | BASE TABLE | `0` | World-side synthesis input catalog; no active runtime consumer found. |
| `dc_item_upgrade_synthesis_recipes` | BASE TABLE | `4` | World-side synthesis recipe catalog; no active runtime consumer found. |
| `dc_mplus_affix_pairs` | BASE TABLE | `2` | Present live and seeded in SQL, but no current runtime reference. |
| `dc_mplus_spec_npcs` | BASE TABLE | `0` | Spectator support table with no verified current consumer. |
| `dc_mplus_spec_positions` | BASE TABLE | `31` | Spectator support table with no verified current consumer. |
| `dc_mplus_spec_strings` | BASE TABLE | `10` | Spectator support table with no verified current consumer. |
| `dc_mplus_teleporter_npcs` | BASE TABLE | `4` | Present and seeded, but no verified current runtime reference. |
| `dc_mplus_weekly_affixes` | BASE TABLE | `12` | No verified consumer in current runtime. |
| `dc_seasonal_chest_rewards` | BASE TABLE | `7` | Seasonal reward config table not queried by the active seasonal runtime. |
| `dc_seasonal_reward_multipliers` | BASE TABLE | `4` | Only surfaced in source comments/SQL; no active runtime consumer verified. |

### Characters

| Table | Type | Live Rows | Notes |
|---|---|---:|---|
| `dc_character_layer_assignment` | BASE TABLE | `0` | Live but unused by current runtime code. Cleanup event exists in schema only. |
| `dc_character_partition_ownership` | BASE TABLE | `3602` | Significant live residue with no active runtime consumer found. Strong drift candidate that needs backup before any purge. |
| `dc_cross_system_config` | BASE TABLE | `8` | Current `CrossSystemManager.cpp` only contains a placeholder comment for this table. |
| `dc_cross_system_events` | BASE TABLE | `0` | Present in schema and SQL views, but no active runtime read/write path found. |
| `dc_group_finder_spectators` | BASE TABLE | `0` | Schema present, no current runtime consumer verified. |
| `dc_item_upgrade_missing_items` | BASE TABLE | `0` | Diagnostics table defined in SQL, but no current runtime writer found. |
| `dc_item_upgrade_state` | BASE TABLE | `3` | Live state table with no active runtime consumer verified. |
| `dc_item_upgrade_synthesis_cooldowns` | BASE TABLE | `0` | Chars-side synthesis support table with no verified current consumer. |
| `dc_item_upgrade_synthesis_log` | BASE TABLE | `0` | Chars-side synthesis log table with no verified current consumer. |
| `dc_player_cross_system_stats` | BASE TABLE | `0` | Present in schema/views, but no active runtime producer/consumer verified. |

## Live Views And Reporting Objects Not Used By Current Runtime

These objects are live, but current runtime code does not query them.

| Object | Type | Notes |
|---|---|---|
| `dc_guild_leaderboard` | VIEW | Reporting/analytics view only. |
| `dc_item_upgrade_missing_items_summary` | VIEW | Derived diagnostics view over `dc_item_upgrade_missing_items`. |
| `dc_player_progression_summary` | VIEW | Derived summary view not queried by runtime code. |
| `dc_player_upgrade_summary` | VIEW | Derived upgrade summary view not queried by runtime code. |
| `dc_recent_upgrades_feed` | VIEW | Feed view present live but not used by current runtime. |
| `dc_top_upgraders` | VIEW | Reporting view only. |
| `dc_upgrade_speed_stats` | VIEW | Derived analytics view over `dc_item_upgrade_log`. |

## Low-Confidence Or Limited-Use Tables

These were not placed in the confirmed drift set because they still have some
runtime visibility, but the usage is limited enough that they deserve owner
review.

| Table | Live Rows | Current Evidence |
|---|---:|---|
| `dc_character_dungeon_npc_respawn` | `0` | Referenced by `DungeonQuestSystem.cpp` only through startup table validation. No verified active read/write path beyond existence checks. |
| `dc_heirloom_collection` | `0` | Referenced in `cs_dc_stresstest.cpp` test/diagnostic paths, not in core collection runtime logic. |
| `dc_hlbg_match_history` | `0` | Historical note: this table belonged to the retired `HLBGSeasonalParticipant.cpp` path and is superseded by the 2026-05-23 HLBG seasonal-table drop migration. |

## Explicitly Not Drift

These tables appeared in the initial automated candidate pass but were
manually confirmed as active.

| Table | Reason |
|---|---|
| `dc_item_upgrade_log` | Active through `ITEM_UPGRADE_LOG_TABLE` in `ItemUpgradeManager` and related upgrade flows. |
| `dc_mplus_hud_cache` | Active in `dc_mythicplus_run_manager.cpp` and `dc_addon_mythicplus.cpp`. |

## Recommended Cleanup Order

1. Resolve schema-duplicate drift first.
   - Remove or archive the inactive copies of `dc_seasons`, the world-side seasonal player tables, world `dc_mplus_dungeons`, and chars `dc_item_upgrade_costs`.
   - Do this only after exporting data where row counts are non-zero or where historical rollback may matter.

2. Review non-consumed world config tables as a single product decision.
   - `dc_mplus_affix_pairs`
   - `dc_mplus_spec_*`
   - `dc_mplus_teleporter_npcs`
   - `dc_mplus_weekly_affixes`
   - `dc_collection_achievement_defs`
   - `dc_heirloom_stat_packages`
   - `dc_item_upgrade_synthesis_*`
   - `dc_seasonal_chest_rewards`
   - `dc_seasonal_reward_multipliers`

3. Review chars-side dormant systems separately.
   - Layering/partition remnants
   - Cross-system remnants
   - Group finder spectator remnants
   - Unwired item-upgrade synthesis state/log tables

4. Keep low-confidence archive/diagnostic tables until the owning feature is
   explicitly confirmed dead.

## Practical Conclusion

The most important live drift today is not a single missing table. It is the
existence of multiple schema copies where current runtime code has already
settled on one side.

The highest-value cleanup targets are therefore:

- `acore_chars.dc_seasons`
- `acore_chars.dc_item_upgrade_costs`
- `acore_world.dc_player_seasonal_chests`
- `acore_world.dc_player_seasonal_stats`
- `acore_world.dc_player_seasonal_stats_history`
- `acore_world.dc_player_weekly_cap_snapshot`
- `acore_world.dc_mplus_dungeons`

Those are the clearest duplicate or legacy live tables that current runtime
code does not actively use.