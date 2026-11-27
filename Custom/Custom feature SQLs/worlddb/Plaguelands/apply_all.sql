-- apply_all.sql — ordered runner for the Plaguelands content port (target: acore_world). Run from INSIDE this folder:
--   cd "K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Plaguelands" && mysql acore_world < apply_all.sql
-- Cross-DB INSERT...SELECT (reads cata_world). dc_entry = 3,600,000 + original. Idempotent (INSERT IGNORE).
SOURCE 01_creature_templates.sql;
SOURCE 02_gameobject_templates.sql;
SOURCE 04_spawns.sql;
SOURCE 07_creature_text.sql;
SOURCE 08_loot.sql;
SOURCE 09_gossip.sql;
SOURCE 11_quests.sql;
SOURCE 12_smart_scripts.sql;
SOURCE 13_areas.sql;
SOURCE 14_graveyard.sql;
SOURCE 15_areatrigger.sql;
SOURCE 29_neltharion_templates.sql;
SOURCE 30_neltharion_spawn_layer.sql;
SOURCE 42_creature_model_info.sql;
SOURCE 43_movement_fix.sql;
SOURCE 44_missing_loot_items.sql;
SOURCE 45_reference_loot.sql;
SOURCE 46_missing_referenced_creatures.sql;
SOURCE 47_flightmaster_scripts.sql;
SOURCE 48_quest_sort_fix.sql;
SOURCE 49_gameobject_rotation_fix.sql;
SOURCE 50_spell_dbc_additions.sql;
SOURCE 51_stock_spell_dbc_additions.sql;
SOURCE 52_vehicle_dbc_fix.sql;
SOURCE 53_creature_addon_spell_dbc_additions.sql;
SOURCE 54_faction_dbc_fix.sql;
SOURCE 55_gameobjectdisplayinfo_resync.sql;
SOURCE 56_killcredit_offset_fix.sql;
SOURCE 57_npc_vendor_backfill.sql;
SOURCE 58_reward_spell_null_unresolvable.sql;
SOURCE 59_go_spellcaster_spell_dbc.sql;
SOURCE 60_julak_pool_and_waypoints.sql;
