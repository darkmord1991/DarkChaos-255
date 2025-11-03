# Dungeon Quest Dataset

This directory contains normalized datasets generated from the raw quest list provided during iteration on 2025-11-03.

## Files

- `dungeon_quests_clean.csv` – canonical quest list with one row per quest. Columns:
  - `quest_id`: Blizzard quest identifier
  - `level_type`: classification parsed from the raw level column (Dungeon / Heroic / Raid / Group / Unknown / Life)
  - `level_value`: numeric component of the level column (if available)
  - `level_raw`: original level string for traceability
  - `dungeon`: dungeon or raid grouping label from the raw data
- `dungeon_quests_summary.csv` – per–dungeon aggregation generated from the clean list. Provides total quest counts and per level-type breakdowns.

## Notes

- The raw spreadsheet included multiple formatting quirks (extra spaces, inconsistent prefixes, and non-dungeon categories such as `Group`, `Raid`, and `Life`). The normalization pass preserves the original values while making the data easier to consume programmatically.
- All 435 quests from the supplied CSV are present. No filtering has been applied: raid, heroic, and group quests remain in scope per the latest requirement.
- Future steps: join this dataset with map metadata, generate SQL for `dc_dungeon_quest_mapping`, and teach the dungeon quest scripts to consume the mapping instead of hard-coded ID ranges.
