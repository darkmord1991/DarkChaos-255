# HLBG Chars Migration Rollout Checklist

Updated: 2026-05-23

This checklist is for applying the HLBG chars-schema cleanup on a populated realm.

Scope:
- `Custom/Custom feature SQLs/chardb/2026_05_23_00_dc_hlbg_state_drop.sql`
- `Custom/Custom feature SQLs/chardb/2026_05_23_01_dc_hlbg_seasonal_tables_drop.sql`

## Stage 0: Maintenance Gate

Goal: prevent writes while the chars schema is being changed.

Checks:
- Stop new realm logins or place the realm in maintenance mode.
- Stop `worldserver` before running the SQL.
- Confirm you are connected to `acore_chars` on the intended realm.

Stop if:
- Players are still entering HLBG or writing leaderboard data.
- You are not sure the target database is the production chars DB.

## Stage 1: Backup Gate

Goal: preserve rollback copies before destructive drops.

Recommended backup set:
- `dc_hlbg_state`
- `dc_hlbg_season_config`
- `dc_hlbg_player_season_data`
- `dc_hlbg_player_history`
- `dc_hlbg_match_history`
- any `dc_hlbg_season_%_matches` tables

Suggested SQL:

```sql
USE acore_chars;

CREATE TABLE dc_hlbg_state_backup_20260523 AS
SELECT * FROM dc_hlbg_state;

CREATE TABLE dc_hlbg_season_config_backup_20260523 AS
SELECT * FROM dc_hlbg_season_config;

CREATE TABLE dc_hlbg_player_season_data_backup_20260523 AS
SELECT * FROM dc_hlbg_player_season_data;

CREATE TABLE dc_hlbg_player_history_backup_20260523 AS
SELECT * FROM dc_hlbg_player_history;

CREATE TABLE dc_hlbg_match_history_backup_20260523 AS
SELECT * FROM dc_hlbg_match_history;
```

Wildcard discovery for legacy season tables:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'acore_chars'
  AND table_name LIKE 'dc_hlbg_season\_%\_matches' ESCAPE '\\';
```

Stop if:
- Any backup `CREATE TABLE ... AS SELECT` fails.
- Row counts in backup tables do not match the source tables.

## Stage 2: Preflight Gate

Goal: record what exists before changes.

Suggested SQL:

```sql
USE acore_chars;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'dc_hlbg_state',
    'dc_hlbg_season_config',
    'dc_hlbg_player_season_data',
    'dc_hlbg_player_history',
    'dc_hlbg_match_history',
    'dc_hlbg_match_participants',
    'dc_hlbg_player_stats',
    'dc_hlbg_winner_history',
    'v_hlbg_player_seasonal_stats',
    'v_hlbg_player_alltime_stats'
  )
ORDER BY table_name;
```

Expected active survivors after rollout:
- `dc_hlbg_match_participants`
- `dc_hlbg_player_stats`
- `dc_hlbg_winner_history`
- `v_hlbg_player_seasonal_stats`
- `v_hlbg_player_alltime_stats`

Stop if:
- The unified survivor tables or views are already missing.

## Stage 3: Apply Migration 00

Goal: drop the dead `dc_hlbg_state` table first.

Run:
- `2026_05_23_00_dc_hlbg_state_drop.sql`

Expected result:
- `PRECHECK` shows `table_exists = 1` on old realms or `0` if already clean.
- `POSTCHECK` shows `table_exists = 0`.

Stop if:
- `POSTCHECK` is not `0`.

## Stage 4: Apply Migration 01

Goal: drop the retired HLBG seasonal/archive tables.

Run:
- `2026_05_23_01_dc_hlbg_seasonal_tables_drop.sql`

Expected result:
- `PRECHECK` lists only the legacy tables that still exist.
- `POSTCHECK` returns no rows.

Stop if:
- `POSTCHECK` still lists any legacy table.

## Stage 5: SQL Verification Gate

Goal: verify the surviving HLBG views and leaderboards still resolve.

Suggested SQL:

```sql
USE acore_chars;

SELECT COUNT(*) AS seasonal_rows
FROM v_hlbg_player_seasonal_stats
WHERE season_id = 1;

SELECT guid, player_name, current_rating, wins, losses
FROM v_hlbg_player_seasonal_stats
WHERE season_id = 1
ORDER BY current_rating DESC
LIMIT 10;

SELECT COUNT(*) AS alltime_rows
FROM v_hlbg_player_alltime_stats;

SELECT guid, player_name, total_wins, total_kills, overall_kd_ratio
FROM v_hlbg_player_alltime_stats
ORDER BY total_wins DESC, total_kills DESC
LIMIT 10;
```

Expected result:
- Seasonal view returns rows for populated realms with HLBG participant history.
- All-time view returns rows for populated realms with `dc_hlbg_player_stats` data.
- Queries succeed without referencing dropped tables.

Stop if:
- Either view errors.
- Seasonal or all-time row counts unexpectedly drop to zero on a realm that previously had HLBG data.

## Stage 6: Realm Verification Gate

Goal: verify the server and addon surfaces after the chars schema cleanup.

Server checks:
- Start `worldserver` and confirm there are no startup SQL/view errors.
- Run `.hlbg history 5` and confirm recent match history still loads.

Addon/UI checks:
- Open `DC-Leaderboards` → `Hinterland BG`.
- Verify seasonal tabs load: `Season Rating`, `Season Wins`, `Win Rate %`, `Games Played`.
- Verify all-time tabs load: `Total Kills`, `All-Time Wins`, `Resources Captured`.

Stop if:
- `worldserver` logs view or table errors.
- HLBG seasonal tabs fail to load.
- HLBG all-time tabs fail to load.

## Stage 7: Drift Check Gate

Goal: make sure season selection is aligned after rollout.

Current runtime contract:
- HLBG runtime season now resolves through the unified DarkChaos season helper.
- `dc_addon_leaderboards.cpp` and `HLBGService.cpp` should both use the same active season source.

Recommended config check:
- Keep `DarkChaos.ActiveSeasonID` aligned with the intended live HLBG season.
- Remove any old HLBG-specific season override from realm configs or treat it as legacy-only if it is still present for reference.

Stop if:
- The leaderboard season and live HLBG season appear to differ after restart.

## Rollback Trigger

Rollback if any of the following happen:
- The post-drop checks fail.
- `v_hlbg_player_seasonal_stats` or `v_hlbg_player_alltime_stats` stop resolving.
- HLBG leaderboard views load empty or error on a realm with known data.

Rollback path:
- Stop `worldserver`.
- Restore the backed-up legacy tables.
- Reapply the previous schema snapshot if views were altered separately.
- Re-run the verification queries before reopening the realm.