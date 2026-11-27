-- Tier-1 reskin races apply-all (run from this folder: mysql acore_world < apply_all.sql)
-- REQUIRES AlliedRaces/apply_all.sql to have been applied first: 01 below updates
-- skilllineability_dbc rows that AlliedRaces/15_ inserts.
SOURCE 01_darkiron_server.sql;
SOURCE 02_darkiron_startoutfit.sql;
SOURCE 03_darkiron_spell_dbc.sql;
-- The racials are GRANTED by ../CharacterCreation/03_custom_racials_skilllineability.sql.
