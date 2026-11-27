-- Castle Nathria (map 2296) — full map registration + content downport.
-- Run against acore_world:  SOURCE apply_all.sql;
-- Then restart worldserver (instance_template + dc_teleporter are read at startup),
-- or `.reload game_tele` for just the .tele command; spawns/templates/loot/text are read
-- on-demand from the DB so a plain worldserver restart is sufficient for all of it.
--
-- Content is transcoded from the shadowcore Shadowlands-era source (self-consistent with a
-- future C++ boss-script port — ScriptNames are pre-wired to the entries a port would bind to),
-- supplemented by world09.sql for loot gaps. Single baseline difficulty tier only (no 10/25/
-- heroic stat-variant split yet — difficulty_entry_1/2/3 = 0 everywhere; dungeon_access_template
-- still declares all 4 access slots since that's an access gate, not a stat variant).
--
-- The C++ instance/boss AI (src/server/scripts/DC/CastleNathria/) has since been ported and needs
-- a worldserver rebuild to take effect (ScriptNames here are pre-wired to match it exactly).
-- 14/15/16 populate the `spell_dbc` table the boss AI's spells actually execute from (this fork's
-- sSpellStore merges the binary Spell.dbc file with this SQL table at load -- see
-- src/server/game/DataStores/DBCStores.cpp's LOAD_DBC macro); the matching client-side Spell.dbc
-- (Custom/DBCs/Spell.dbc) has already been compiled+deployed to patch-4 + patch-enGB-3 separately,
-- since this SQL table only affects the SERVER's copy of the spell store, not the client's.
-- Order matters throughout: templates before spawns/instance_encounters before loot; 14 before 15
-- (15 is spells missed by 14's original id list) before 16 (16 overrides 12 of 14/15's rows to be
-- real ground-hazard persistent-area-auras, and needs one of 15's spells as a trigger target).

SOURCE 00_map_registration.sql;
SOURCE 01_entrance_teleporter.sql;
SOURCE 02_creature_model_info.sql;
SOURCE 03_loot_item_stats.sql;
SOURCE 04_creature_model_info_batch2.sql;
SOURCE 05_creature_templates.sql;
SOURCE 06_gameobject_templates.sql;
SOURCE 07_creature_spawns.sql;
SOURCE 08_gameobject_spawns.sql;
SOURCE 09_creature_text.sql;
SOURCE 10_loot.sql;
SOURCE 11_instance_encounters.sql;
SOURCE 12_loot_journal_supplement.sql;
SOURCE 13_reverberation_stalker.sql;
SOURCE 14_boss_spells_dbc.sql;
SOURCE 15_boss_spells_dbc_addendum.sql;
SOURCE 16_ground_hazards.sql;
SOURCE 17_boss_text_gaps.sql;
SOURCE 18_loot_trigger_cleanup.sql;
SOURCE 19_summoned_adds.sql;
SOURCE 20_boss_spells_dbc_audit_gap.sql;
SOURCE 21_script_bindings.sql;
SOURCE 19_trash_loot.sql;
SOURCE 20_missing_trash_items.sql;
SOURCE 22_creature_text_supplement.sql;
SOURCE 23_loot_supplement_audit.sql;
SOURCE 24_creature_equipment.sql;
SOURCE 25_addon_aura_spells_dbc.sql;
SOURCE 26_creature_addons.sql;

SOURCE 27_vehicle_loot_and_type_gaps.sql;
