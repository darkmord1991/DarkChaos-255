-- Character-creation cross-race fixes (run from this folder: mysql acore_world < apply_all.sql)
-- Apply AFTER the per-race folders (Worgoblin, Pandaren, AlliedRaces, Tier1Reskins).
SOURCE 01_custom_race_racemask_gaps.sql;
SOURCE 02_dedupe_playercreateinfo_item.sql;
SOURCE 03_custom_racials_skilllineability.sql;
