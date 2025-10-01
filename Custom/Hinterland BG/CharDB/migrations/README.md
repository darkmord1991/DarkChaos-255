This folder contains character DB migrations for the Hinterland BG addon only.

Apply these on the characters database (same DB used for player characters):
- 2025-10-01_add_season_column.sql — adds `season` column and index to `hlbg_winner_history`
- 2025-10-01_create_hlbg_seasons.sql — creates `hlbg_seasons` table to name/describe seasons, and links `hlbg_winner_history.season` via a foreign key

Notes:
- Scripts are idempotent and safe to run multiple times.
- If you have not created the `hlbg_winner_history` table yet, run `Custom/Hinterland BG/CharDB/hlbg_winner_history.sql` first.
