-- ---------------------------------------------------------------------------
-- Cata Hyjal 80-130 -- ordered runner
-- ---------------------------------------------------------------------------
-- Run against acore_world. Every file is idempotent / re-runnable.
--
-- PREREQUISITES, in this order:
--   1. data/sql/updates/pending_db_world/rev_*.sql   (creature_classlevelstats
--      repair, levels 84-255) -- ships separately, applies via the DB updater.
--   2. Custom/Custom feature SQLs/worlddb/HyjalCata/apply_all.sql
--      (includes the new 148_ areatrigger fix and 149_ gear armor/damage)
--   3. Custom/Custom feature SQLs/worlddb/MoltenFront/apply_all.sql
--
-- Then this file.
-- ---------------------------------------------------------------------------

SOURCE 10_faction_bases.sql;
SOURCE 11_graveyards.sql;
SOURCE 30_entry_points.sql;

-- --- classic faction starts (80-130 band project; needs HyjalCata 231-241) --
SOURCE 40_faction_starts.sql;
SOURCE 41_start_services.sql;
SOURCE 42_graveyards_curated.sql;
SOURCE 43_breadcrumbs.sql;
SOURCE 44_azshara_crater_portals.sql;
