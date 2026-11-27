-- Blackwing Descent (map 669) — world DB apply runner.
-- Run from a MySQL client connected to the world DB (acore_world), with the
-- source schemas `cata_world` and `nelt_world` present on the same host.
--
--   SOURCE apply_all.sql;
--
-- Files are applied in dependency order (creature_templates first — loot/quests/
-- achievements reference their entries). Each file is idempotent (scoped DELETE
-- before INSERT). See 00_README.md for the full runbook incl. the DBC + manual
-- pipeline steps that live outside this SQL apply.

SOURCE 01_creature_templates.sql;
SOURCE 02_gameobject_templates.sql;
SOURCE 04_spawns.sql;
SOURCE 05_groups.sql;
SOURCE 06_text.sql;
SOURCE 07_model_movement.sql;
SOURCE 08_bindings.sql;
SOURCE 09_loot.sql;
SOURCE 10_items.sql;
SOURCE 11_instance.sql;
SOURCE 12_quests.sql;
SOURCE 13_achievements.sql;
SOURCE 14_trash_ai.sql;
SOURCE 15_spells.sql;
SOURCE 16_boss_displays.sql;
SOURCE 17_spells_helpers.sql;
SOURCE 18_missing_summons.sql;
SOURCE 19_spell_dbc_additions.sql;
SOURCE 20_missing_creature_templates.sql;
SOURCE 21_summon_group_creature_templates.sql;
SOURCE 22_trash_loot.sql;
SOURCE 23_spellclick.sql;
SOURCE 24_gameobject_display_fix.sql;
SOURCE 25_difficulty_variants.sql;
SOURCE 26_vehicle_dbc_fix.sql;
SOURCE 27_gameobjectdisplayinfo_resync.sql;
SOURCE 28_creature_model_placeholder_fix.sql;
SOURCE 29_spellclick_pincer_wyvern.sql;
SOURCE 30_difficulty_variants_round2.sql;
SOURCE 31_questtype_regression_fix.sql;
SOURCE 32_finkle_quest_sign_fix.sql;
SOURCE 33_missing_marker_creatures.sql;
SOURCE 34_conditions_sourcegroup_fix.sql;
SOURCE 35_creature_text_sound_silence.sql;
SOURCE 36_spell_dbc_additions_round12.sql;
SOURCE 37_chimaeron_heroic_family_fix.sql;
