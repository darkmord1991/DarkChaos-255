-- Blackfathom Deeps (Ashenvale), map 820 -- apply the whole clone in order.
--
--   mysql -u <user> -p acore_world < apply_all.sql
--
-- Every step is re-runnable, so a partial run can simply be repeated.
-- Order matters: 02/03/04 all read the templates 01 creates.

SOURCE 01_templates.sql;
SOURCE 02_support_tables.sql;
SOURCE 03_spawns.sql;
SOURCE 04_loot.sql;
SOURCE 05_cata_npc_layer.sql;
SOURCE 06_registration.sql;
SOURCE 07_dc_difficulty.sql;
-- The gatekeeper must exist before 08: creature_queststarter/questender rows are
-- validated against creature_template at load, and a missing entry is logged and dropped.
-- Path is relative to the mysql client's working directory -- run from THIS folder.
SOURCE ../_shared/dungeon_entrance_npcs.sql;
SOURCE 08_quests.sql;
